using System.Collections.Concurrent;
using System.Diagnostics;

namespace Fjellfisk.SensorCollector;

// This reader has one purpose: read exact read-only allowlisted scalar values.
// It deliberately does not expose a COM object or any generic member invocation API.
public sealed class OxyGuardVigoReader : ISensorReader, IDisposable
{
    private static readonly TimeSpan DefaultReadTimeout = TimeSpan.FromSeconds(10);
    private readonly IClock _clock;
    private readonly IReadOnlySensorAllowlist _allowlist;
    private readonly TimeSpan _readTimeout;
    private StaVigoReadExecutor? _executor;

    public OxyGuardVigoReader(
        IClock clock,
        IReadOnlySensorAllowlist allowlist,
        TimeSpan? readTimeout = null)
    {
        _clock = clock;
        _allowlist = allowlist ?? throw new ArgumentNullException(nameof(allowlist));
        _readTimeout = readTimeout ?? DefaultReadTimeout;
        if (_readTimeout <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(readTimeout));
        }
    }

    public string ReaderName => "OxyGuardVigoReader (VIGO.PRO, read-only pilot)";

    public async Task<SensorReadResult> ReadAsync(
        SensorDefinition sensor,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var allowlistedSensor = RequireExactAllowlistedSensor(sensor);
        _executor ??= new StaVigoReadExecutor();
        return await _executor.ExecuteAsync(
            () => ReadAllowlistedValue(allowlistedSensor, cancellationToken),
            _readTimeout,
            cancellationToken);
    }

    public void Dispose()
    {
        _executor?.Dispose();
    }

    private SensorReadResult ReadAllowlistedValue(
        SensorDefinition sensor,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var started = Stopwatch.GetTimestamp();
        using var vigo = new VigoComScalarReadSession();

        vigo.CreateCom();
        vigo.SelectPhysId(sensor.PhysId);
        var scalarValue = Convert.ToSingle(
            vigo.ReadValue(),
            System.Globalization.CultureInfo.InvariantCulture);
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

}

// A single background STA thread prevents MTA/COM apartment ambiguity and limits a
// blocked VIGO call to one stalled executor. It does not try to kill or restart VIGO.
internal sealed class StaVigoReadExecutor : IDisposable
{
    private readonly BlockingCollection<ReadWorkItem> _queue = new();
    private readonly Thread _thread;
    private int _stalled;
    private bool _disposed;

    public StaVigoReadExecutor()
    {
        _thread = new Thread(Run)
        {
            IsBackground = true,
            Name = "Fjellfisk-Vigo-ReadOnly-STA",
        };
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.Start();
    }

    public async Task<SensorReadResult> ExecuteAsync(
        Func<SensorReadResult> operation,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        if (Volatile.Read(ref _stalled) == 1)
        {
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
        Interlocked.Exchange(ref _stalled, 1);
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
