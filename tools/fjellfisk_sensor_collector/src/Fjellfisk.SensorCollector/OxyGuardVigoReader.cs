using System.Collections.Concurrent;
using System.Diagnostics;

namespace Fjellfisk.SensorCollector;

// This reader has one purpose: read exact read-only allowlisted scalar values.
// It deliberately does not expose a COM object or any generic member invocation API.
public sealed class OxyGuardVigoReader : ISensorReader, IDisposable, ICollectorSensorReadHealth
{
    private static readonly TimeSpan DefaultReadTimeout = TimeSpan.FromSeconds(10);
    private readonly IClock _clock;
    private readonly IReadOnlySensorAllowlist _allowlist;
    private readonly TimeSpan _readTimeout;
    private readonly ICollectorSensorReadDiagnostics _diagnostics;
    private StaVigoReadExecutor? _executor;

    public OxyGuardVigoReader(
        IClock clock,
        IReadOnlySensorAllowlist allowlist,
        TimeSpan? readTimeout = null,
        ICollectorSensorReadDiagnostics? diagnostics = null)
    {
        _clock = clock;
        _allowlist = allowlist ?? throw new ArgumentNullException(nameof(allowlist));
        _readTimeout = readTimeout ?? DefaultReadTimeout;
        _diagnostics = diagnostics ?? NullCollectorSensorReadDiagnostics.Instance;
        if (_readTimeout <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(readTimeout));
        }
    }

    public string ReaderName => "OxyGuardVigoReader (VIGO.PRO, read-only pilot)";

    // A timeout leaves the one STA worker unsafe for further COM calls. The
    // production host observes this flag and replaces only its worker process.
    public bool IsStalled => _executor?.IsStalled == true;

    public async Task<SensorReadResult> ReadAsync(
        SensorDefinition sensor,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var allowlistedSensor = RequireExactAllowlistedSensor(sensor);
        _executor ??= new StaVigoReadExecutor(_diagnostics);
        var context = new VigoReadOperationContext(
            SourceTypeFor(allowlistedSensor),
            MeasurementFor(allowlistedSensor.Kind));
        return await _executor.ExecuteAsync(
            context,
            () => ReadAllowlistedValue(allowlistedSensor, context, cancellationToken),
            _readTimeout,
            cancellationToken);
    }

    public void Dispose()
    {
        _executor?.Dispose();
    }

    private SensorReadResult ReadAllowlistedValue(
        SensorDefinition sensor,
        VigoReadOperationContext context,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var started = Stopwatch.GetTimestamp();
        using var vigo = new VigoComScalarReadSession();

        context.SetStage("create-com");
        vigo.CreateCom();
        context.SetStage("select-physid");
        vigo.SelectPhysId(sensor.PhysId);
        context.SetStage("read-value");
        var scalarValue = Convert.ToSingle(
            vigo.ReadValue(),
            System.Globalization.CultureInfo.InvariantCulture);
        context.SetStage("read-error-code");
        var errorCode = Convert.ToInt32(
            vigo.ReadErrorCode(),
            System.Globalization.CultureInfo.InvariantCulture);

        return new SensorReadResult(
            sensor,
            scalarValue,
            errorCode,
            PnetDataType: 36,
            DotNetType: "System.Single",
            TimestampUtc: _clock.UtcNow,
            Duration: TimeSpan.FromSeconds(
                (Stopwatch.GetTimestamp() - started) / (double)Stopwatch.Frequency));
    }

    private SensorDefinition RequireExactAllowlistedSensor(SensorDefinition sensor)
    {
        var required = _allowlist.GetRequired(sensor.Key);
        if (!string.Equals(required.PhysId, sensor.PhysId, StringComparison.Ordinal) ||
            required.Kind != sensor.Kind ||
            !string.Equals(required.DeviceId, sensor.DeviceId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("The VIGO reader only accepts its exact read-only sensor allowlist.");
        }

        return required;
    }

    private static string SourceTypeFor(SensorDefinition sensor) =>
        sensor.Key.StartsWith("pacific", StringComparison.OrdinalIgnoreCase) ? "Pacific" :
        sensor.Key.StartsWith("dom", StringComparison.OrdinalIgnoreCase) ? "DOM" :
        "Unknown";

    private static string MeasurementFor(SensorKind kind) => kind switch
    {
        SensorKind.TemperatureC => "temperatureC",
        SensorKind.OxygenMgL => "oxygenMgL",
        SensorKind.OxygenSaturationPct => "oxygenSaturationPct",
        _ => "unknown",
    };

}

// A single background STA thread prevents MTA/COM apartment ambiguity and limits a
// blocked VIGO call to one stalled executor. It does not try to kill or restart VIGO.
internal sealed class StaVigoReadExecutor : IDisposable
{
    private readonly BlockingCollection<ReadWorkItem> _queue = new();
    private readonly Thread _thread;
    private readonly ICollectorSensorReadDiagnostics _diagnostics;
    private int _stalled;
    private bool _disposed;

    public StaVigoReadExecutor(ICollectorSensorReadDiagnostics? diagnostics = null)
    {
        _diagnostics = diagnostics ?? NullCollectorSensorReadDiagnostics.Instance;
        _thread = new Thread(Run)
        {
            IsBackground = true,
            Name = "Fjellfisk-Vigo-ReadOnly-STA",
        };
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.Start();
    }

    public bool IsStalled => Volatile.Read(ref _stalled) == 1;

    public async Task<SensorReadResult> ExecuteAsync(
        VigoReadOperationContext context,
        Func<SensorReadResult> operation,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        if (Volatile.Read(ref _stalled) == 1)
        {
            _diagnostics.RecordStaReaderState(new StaReaderDiagnosticEvent(
                context.SourceType,
                context.Measurement,
                context.Stage,
                AlreadyBlocked: true));
            throw new TimeoutException("The VIGO reader is waiting for a previous timed-out read.");
        }

        var workItem = new ReadWorkItem(operation);
        try
        {
            _queue.Add(workItem, cancellationToken);
        }
        catch (InvalidOperationException)
        {
            throw new ObjectDisposedException(nameof(StaVigoReadExecutor));
        }

        var timeoutTask = Task.Delay(timeout, cancellationToken);
        var completed = await Task.WhenAny(workItem.Completion.Task, timeoutTask);
        if (completed == workItem.Completion.Task)
        {
            return await workItem.Completion.Task;
        }

        cancellationToken.ThrowIfCancellationRequested();
        workItem.MarkAbandoned();
        if (Interlocked.CompareExchange(ref _stalled, 1, 0) == 0)
        {
            _diagnostics.RecordStaReaderState(new StaReaderDiagnosticEvent(
                context.SourceType,
                context.Measurement,
                context.Stage,
                AlreadyBlocked: false));
        }
        throw new TimeoutException("VIGO.PRO read timed out; the collector will back off without restarting VIGO.");
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _queue.CompleteAdding();
    }

    private void Run()
    {
        foreach (var workItem in _queue.GetConsumingEnumerable())
        {
            if (workItem.IsAbandoned)
            {
                continue;
            }

            try
            {
                workItem.Completion.TrySetResult(workItem.Operation());
            }
            catch (Exception exception)
            {
                workItem.Completion.TrySetException(exception);
            }
        }
    }

    private sealed class ReadWorkItem
    {
        private int _abandoned;

        public ReadWorkItem(Func<SensorReadResult> operation)
        {
            Operation = operation;
            Completion = new TaskCompletionSource<SensorReadResult>(
                TaskCreationOptions.RunContinuationsAsynchronously);
        }

        public Func<SensorReadResult> Operation { get; }

        public TaskCompletionSource<SensorReadResult> Completion { get; }

        public bool IsAbandoned => Volatile.Read(ref _abandoned) == 1;

        public void MarkAbandoned() => Interlocked.Exchange(ref _abandoned, 1);
    }
}

internal sealed class VigoReadOperationContext
{
    private string _stage = "queued";

    public VigoReadOperationContext(string sourceType, string measurement)
    {
        SourceType = sourceType;
        Measurement = measurement;
    }

    public string SourceType { get; }

    public string Measurement { get; }

    public string Stage => Volatile.Read(ref _stage);

    public void SetStage(string stage) => Volatile.Write(ref _stage, stage);
}
