using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Fjellfisk.SensorCollector;

public static class SensorAllowlist
{
    private static readonly IReadOnlyList<SensorDefinition> PacificDefinitions =
        new List<SensorDefinition>
        {
            new(
                "pacific01_temperature",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Temperature.Value",
                SensorKind.TemperatureC),
            new(
                "pacific01_oxygen",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Ppm.Value",
                SensorKind.OxygenMgL),
            new(
                "pacific01_saturation",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Saturation.Value",
                SensorKind.OxygenSaturationPct),
            new(
                "pacific01_probe02_temperature",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_02.Oxygen.Measurement.Temperature.Value",
                SensorKind.TemperatureC),
            new(
                "pacific01_probe02_oxygen",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_02.Oxygen.Measurement.Ppm.Value",
                SensorKind.OxygenMgL),
            new(
                "pacific01_probe02_saturation",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_02.Oxygen.Measurement.Saturation.Value",
                SensorKind.OxygenSaturationPct),
            new(
                "pacific01_probe03_temperature",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_03.Oxygen.Measurement.Temperature.Value",
                SensorKind.TemperatureC),
            new(
                "pacific01_probe03_oxygen",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_03.Oxygen.Measurement.Ppm.Value",
                SensorKind.OxygenMgL),
            new(
                "pacific01_probe03_saturation",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_03.Oxygen.Measurement.Saturation.Value",
                SensorKind.OxygenSaturationPct),
            new(
                "pacific01_probe04_temperature",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_04.Oxygen.Measurement.Temperature.Value",
                SensorKind.TemperatureC),
            new(
                "pacific01_probe04_oxygen",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_04.Oxygen.Measurement.Ppm.Value",
                SensorKind.OxygenMgL),
            new(
                "pacific01_probe04_saturation",
                "pacific-01",
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_04.Oxygen.Measurement.Saturation.Value",
                SensorKind.OxygenSaturationPct),
        }.AsReadOnly();

    private static readonly IReadOnlyList<SensorDefinition> DomDefinitions =
        CreateDomDefinitions();

    private static readonly IReadOnlyList<SensorDefinition> Definitions =
        PacificDefinitions.Concat(DomDefinitions).ToArray();

    // The normal reader remains restricted to the already verified Probe_01.
    // Inventory candidates for Probe_02 through Probe_04 are intentionally
    // separate and are never included in normal pilot or soak cycles.
    private static readonly IReadOnlyList<SensorDefinition> Pacific01Definitions =
        PacificDefinitions.Where(sensor => sensor.Key is
            "pacific01_temperature" or
            "pacific01_oxygen" or
            "pacific01_saturation").ToArray();

    public static IReadOnlyList<SensorDefinition> Pacific01 => Pacific01Definitions;

    public static IReadOnlyList<SensorDefinition> GetPacific01Probe(int probeIndex)
    {
        if (probeIndex is < 1 or > 4)
        {
            throw new ArgumentOutOfRangeException(nameof(probeIndex));
        }

        if (probeIndex == 1)
        {
            return Pacific01Definitions;
        }

        var keyPrefix = $"pacific01_probe{probeIndex:00}_";
        return Definitions
            .Where(sensor => sensor.Key.StartsWith(keyPrefix, StringComparison.Ordinal))
            .ToArray();
    }

    public static SensorDefinition GetRequired(string sensorKey) =>
        Definitions.FirstOrDefault(sensor =>
            string.Equals(sensor.Key, sensorKey, StringComparison.Ordinal))
        ?? throw new InvalidOperationException(
            $"Sensor '{sensorKey}' is not in the collector allowlist.");

    public static IReadOnlyList<SensorDefinition> GetDomChannel(
        int meterIndex,
        int channelIndex)
    {
        if (meterIndex is < 0 or > 2)
        {
            throw new ArgumentOutOfRangeException(nameof(meterIndex));
        }

        if (channelIndex is < 0 or > 5)
        {
            throw new ArgumentOutOfRangeException(nameof(channelIndex));
        }

        var keyPrefix = $"dom_m{meterIndex}_do{channelIndex}_";
        return DomDefinitions
            .Where(sensor => sensor.Key.StartsWith(keyPrefix, StringComparison.Ordinal))
            .ToArray();
    }

    private static IReadOnlyList<SensorDefinition> CreateDomDefinitions()
    {
        var definitions = new List<SensorDefinition>();
        for (var meterIndex = 0; meterIndex <= 2; meterIndex++)
        {
            for (var channelIndex = 0; channelIndex <= 5; channelIndex++)
            {
                var keyPrefix = $"dom_m{meterIndex}_do{channelIndex}";
                var physIdPrefix =
                    $"Commander5:Master_Box_1.DOM.DO_Meter_{meterIndex}.DO_{channelIndex}.Measurement.";
                var deviceId = $"dom-meter-{meterIndex}";

                definitions.Add(new SensorDefinition(
                    $"{keyPrefix}_temperature",
                    deviceId,
                    physIdPrefix + "temperature",
                    SensorKind.TemperatureC));
                definitions.Add(new SensorDefinition(
                    $"{keyPrefix}_oxygen",
                    deviceId,
                    physIdPrefix + "ppm",
                    SensorKind.OxygenMgL));
                definitions.Add(new SensorDefinition(
                    $"{keyPrefix}_saturation",
                    deviceId,
                    physIdPrefix + "saturation",
                    SensorKind.OxygenSaturationPct));
            }
        }

        return definitions.AsReadOnly();
    }
}

public sealed class CompiledSensorAllowlist : IReadOnlySensorAllowlist
{
    public static readonly CompiledSensorAllowlist Instance = new();

    private CompiledSensorAllowlist()
    {
    }

    public SensorDefinition GetRequired(string sensorKey) => SensorAllowlist.GetRequired(sensorKey);
}

public sealed class MockVigoReader : ISensorReader
{
    private static readonly IReadOnlyDictionary<SensorKind, float[]> Values =
        new Dictionary<SensorKind, float[]>
        {
            [SensorKind.TemperatureC] = new[] { 9.52f, 9.53f, 9.51f, 9.54f, 9.50f, 9.55f },
            [SensorKind.OxygenMgL] = new[] { 11.66f, 11.67f, 11.65f, 11.68f, 11.64f, 11.69f },
            [SensorKind.OxygenSaturationPct] = new[] { 101.85f, 101.90f, 101.80f, 101.95f, 101.75f, 102.00f },
        };

    private readonly IClock _clock;
    private long _readCount;

    public MockVigoReader(IClock clock)
    {
        _clock = clock;
    }

    public string ReaderName => "MockVigoReader";

    public Task<SensorReadResult> ReadAsync(
        SensorDefinition sensor,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var readIndex = Interlocked.Increment(ref _readCount) - 1;
        var cycleIndex = (int)(readIndex / SensorAllowlist.Pacific01.Count);
        var values = Values[sensor.Kind];
        var value = values[cycleIndex % values.Length];
        var duration = TimeSpan.FromMilliseconds(13 + (cycleIndex % 5));

        return Task.FromResult(new SensorReadResult(
            sensor,
            value,
            ErrorCode: 0,
            PnetDataType: 36,
            DotNetType: "System.Single",
            TimestampUtc: _clock.UtcNow,
            Duration: duration));
    }
}

public sealed record SensorMeasurement(
    string MeasurementId,
    string CollectorId,
    string DeviceId,
    DateTimeOffset TimestampUtc,
    float TemperatureC,
    float OxygenMgL,
    float OxygenSaturationPct,
    string Status);

public static class MeasurementJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    public static string Serialize(SensorMeasurement measurement) =>
        JsonSerializer.Serialize(measurement, Options);

    public static SensorMeasurement Deserialize(string json) =>
        JsonSerializer.Deserialize<SensorMeasurement>(json, Options)
        ?? throw new InvalidOperationException("Buffered measurement was empty.");
}

public sealed class MeasurementNormalizer
{
    private readonly IClock _clock;

    public MeasurementNormalizer(IClock clock)
    {
        _clock = clock;
    }

    public SensorMeasurement Normalize(
        string collectorId,
        string deviceId,
        IReadOnlyCollection<SensorReadResult> readings)
    {
        if (readings.Count != SensorAllowlist.Pacific01.Count)
        {
            throw new InvalidOperationException("The required allowlisted sensor readings are incomplete.");
        }

        foreach (var reading in readings)
        {
            if (reading.ErrorCode != 0)
            {
                throw new InvalidOperationException(
                    $"Sensor '{reading.Sensor.Key}' returned error code {reading.ErrorCode}.");
            }

            if (reading.PnetDataType != 36 ||
                !string.Equals(reading.DotNetType, "System.Single", StringComparison.Ordinal) ||
                !float.IsFinite(reading.Value))
            {
                throw new InvalidOperationException(
                    $"Sensor '{reading.Sensor.Key}' did not return the expected scalar type.");
            }
        }

        var byKind = readings.ToDictionary(reading => reading.Sensor.Kind);
        return new SensorMeasurement(
            Guid.NewGuid().ToString("N"),
            collectorId,
            deviceId,
            _clock.UtcNow,
            byKind[SensorKind.TemperatureC].Value,
            byKind[SensorKind.OxygenMgL].Value,
            byKind[SensorKind.OxygenSaturationPct].Value,
            "ok");
    }
}

public sealed class CollectorOptions
{
    public static readonly TimeSpan MinimumSamplingInterval = TimeSpan.FromSeconds(10);

    public CollectorOptions(
        string collectorId,
        string deviceId,
        TimeSpan samplingInterval)
    {
        if (samplingInterval < MinimumSamplingInterval)
        {
            throw new ArgumentOutOfRangeException(
                nameof(samplingInterval),
                $"Sampling interval must be at least {MinimumSamplingInterval.TotalSeconds:0} seconds.");
        }

        CollectorId = collectorId;
        DeviceId = deviceId;
        SamplingInterval = samplingInterval;
    }

    public string CollectorId { get; }

    public string DeviceId { get; }

    public TimeSpan SamplingInterval { get; }

    public static CollectorOptions CreateDefault(string stateDirectory) =>
        new("fjellfisk-vigo-pilot-01", "pacific-01", TimeSpan.FromSeconds(15));
}

public sealed class RetryBackoff
{
    private static readonly TimeSpan[] Delays =
    {
        TimeSpan.FromSeconds(15),
        TimeSpan.FromSeconds(30),
        TimeSpan.FromSeconds(60),
        TimeSpan.FromSeconds(120),
        TimeSpan.FromSeconds(240),
        TimeSpan.FromMinutes(5),
    };

    private int _failureCount;

    public TimeSpan RegisterFailure()
    {
        var index = Math.Min(_failureCount, Delays.Length - 1);
        _failureCount++;
        return Delays[index];
    }

    public void Reset() => _failureCount = 0;
}

public sealed record BufferOptions(TimeSpan Retention, long MaxBytes)
{
    public static readonly BufferOptions Default =
        new(TimeSpan.FromHours(24), 5L * 1024L * 1024L);
}

public sealed class LocalJsonlBuffer
{
    private readonly string _path;
    private readonly BufferOptions _options;
    private readonly IClock _clock;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public LocalJsonlBuffer(string path, BufferOptions options, IClock clock)
    {
        _path = path;
        _options = options;
        _clock = clock;
    }

    public async Task EnqueueAsync(SensorMeasurement measurement, CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            await File.AppendAllTextAsync(
                _path,
                MeasurementJson.Serialize(measurement) + Environment.NewLine,
                Encoding.UTF8,
                cancellationToken);
            await TrimLockedAsync(cancellationToken);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<SensorMeasurement?> PeekOldestAsync(CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (!File.Exists(_path))
            {
                return null;
            }

            var line = (await File.ReadAllLinesAsync(_path, cancellationToken))
                .FirstOrDefault(candidate => !string.IsNullOrWhiteSpace(candidate));
            return line is null ? null : MeasurementJson.Deserialize(line);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task RemoveOldestAsync(CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (!File.Exists(_path))
            {
                return;
            }

            var remaining = (await File.ReadAllLinesAsync(_path, cancellationToken))
                .Where(line => !string.IsNullOrWhiteSpace(line))
                .Skip(1)
                .ToArray();
            await File.WriteAllLinesAsync(_path, remaining, Encoding.UTF8, cancellationToken);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<int> CountAsync(CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (!File.Exists(_path))
            {
                return 0;
            }

            return (await File.ReadAllLinesAsync(_path, cancellationToken))
                .Count(line => !string.IsNullOrWhiteSpace(line));
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task TrimLockedAsync(CancellationToken cancellationToken)
    {
        if (!File.Exists(_path))
        {
            return;
        }

        var cutoff = _clock.UtcNow - _options.Retention;
        var validLines = new List<string>();
        foreach (var line in await File.ReadAllLinesAsync(_path, cancellationToken))
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            try
            {
                if (MeasurementJson.Deserialize(line).TimestampUtc >= cutoff)
                {
                    validLines.Add(line);
                }
            }
            catch (JsonException)
            {
                // A malformed local line is discarded rather than retried forever.
            }
        }

        var retainedNewestFirst = new List<string>();
        long byteCount = 0;
        foreach (var line in validLines.AsEnumerable().Reverse())
        {
            var lineBytes = Encoding.UTF8.GetByteCount(line + Environment.NewLine);
            if (lineBytes > _options.MaxBytes)
            {
                continue;
            }

            if (byteCount + lineBytes > _options.MaxBytes)
            {
                break;
            }

            retainedNewestFirst.Add(line);
            byteCount += lineBytes;
        }

        retainedNewestFirst.Reverse();
        await File.WriteAllLinesAsync(
            _path,
            retainedNewestFirst,
            Encoding.UTF8,
            cancellationToken);
    }
}

public sealed record UploadResult(bool Succeeded, string? Error)
{
    public static readonly UploadResult Success = new(true, null);
}

public interface IUploader
{
    Task<UploadResult> UploadAsync(
        SensorMeasurement measurement,
        CancellationToken cancellationToken);
}

public interface ICollectorLogger
{
    void Log(string eventName, string message);
}

public sealed class ConsoleMockUploader : IUploader
{
    private readonly ICollectorLogger _logger;

    public ConsoleMockUploader(ICollectorLogger logger)
    {
        _logger = logger;
    }

    public Task<UploadResult> UploadAsync(
        SensorMeasurement measurement,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _logger.Log("upload_success", MeasurementJson.Serialize(measurement));
        return Task.FromResult(UploadResult.Success);
    }
}

// Soak tests must exercise the local buffer lifecycle without reaching any
// production transport. This acknowledgement is intentionally local-only.
public sealed class LocalOnlyAcknowledgingUploader : IUploader
{
    private int _acknowledgedCount;

    public int AcknowledgedCount => Volatile.Read(ref _acknowledgedCount);

    public Task<UploadResult> UploadAsync(
        SensorMeasurement measurement,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Interlocked.Increment(ref _acknowledgedCount);
        return Task.FromResult(UploadResult.Success);
    }
}

public sealed class RollingFileLogger : ICollectorLogger
{
    private const long DefaultMaxLogBytes = 1024L * 1024L;
    private const int DefaultMaxArchives = 3;
    private readonly string _directory;
    private readonly string _path;
    private readonly bool _writeToConsole;
    private readonly long _maxLogBytes;
    private readonly int _maxArchives;
    private readonly object _gate = new();

    public RollingFileLogger(
        string directory,
        bool writeToConsole = true,
        string fileName = "collector.log",
        long maxLogBytes = DefaultMaxLogBytes,
        int maxArchives = DefaultMaxArchives)
    {
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new ArgumentException("A log directory is required.", nameof(directory));
        }

        if (string.IsNullOrWhiteSpace(fileName) ||
            !string.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal))
        {
            throw new ArgumentException("The log file name must not contain a directory.", nameof(fileName));
        }

        if (maxLogBytes < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(maxLogBytes));
        }

        if (maxArchives < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(maxArchives));
        }

        _directory = directory;
        _path = Path.Combine(directory, fileName);
        _writeToConsole = writeToConsole;
        _maxLogBytes = maxLogBytes;
        _maxArchives = maxArchives;
    }

    public string LogPath => _path;

    public void Log(string eventName, string message)
    {
        var line = $"{DateTimeOffset.UtcNow:O} [{eventName}] {message}";
        if (_writeToConsole)
        {
            Console.WriteLine(line);
        }

        lock (_gate)
        {
            Directory.CreateDirectory(_directory);
            RotateIfNeeded();
            File.AppendAllText(_path, line + Environment.NewLine, Encoding.UTF8);
        }
    }

    private void RotateIfNeeded()
    {
        if (!File.Exists(_path) || new FileInfo(_path).Length < _maxLogBytes)
        {
            return;
        }

        for (var index = _maxArchives - 1; index >= 1; index--)
        {
            var source = $"{_path}.{index}";
            var destination = $"{_path}.{index + 1}";
            if (File.Exists(source))
            {
                File.Move(source, destination, overwrite: true);
            }
        }

        File.Move(_path, $"{_path}.1", overwrite: true);
    }
}

public sealed record CollectorStatus(
    bool Running,
    DateTimeOffset? LastSuccessfulReadingUtc,
    DateTimeOffset? LastSuccessfulUploadUtc,
    bool VigoConnected,
    string? LastError,
    int BufferCount,
    TimeSpan CurrentRetryDelay);

public sealed record CollectorSnapshot(
    CollectorStatus Status,
    SensorMeasurement? LatestMeasurement)
{
    public bool IsConnected =>
        Status.Running &&
        Status.VigoConnected &&
        LatestMeasurement is not null &&
        string.IsNullOrWhiteSpace(Status.LastError);
}

public sealed record CycleResult(bool Success, TimeSpan NextDelay, string? Error)
{
    public TimeSpan ReadDuration { get; init; }

    public int? ErrorCode { get; init; }

    public bool IsTimeout { get; init; }

    public bool IsComError { get; init; }
}

public sealed class CollectorRunner
{
    private readonly CollectorOptions _options;
    private readonly ISensorReader _reader;
    private readonly MeasurementNormalizer _normalizer;
    private readonly LocalJsonlBuffer _buffer;
    private readonly IUploader _uploader;
    private readonly ICollectorLogger _logger;
    private readonly RetryBackoff _backoff = new();
    private SensorMeasurement? _latestMeasurement;
    private DateTimeOffset? _lastSuccessfulUploadUtc;

    public CollectorRunner(
        CollectorOptions options,
        ISensorReader reader,
        MeasurementNormalizer normalizer,
        LocalJsonlBuffer buffer,
        IUploader uploader,
        ICollectorLogger logger)
    {
        _options = options;
        _reader = reader;
        _normalizer = normalizer;
        _buffer = buffer;
        _uploader = uploader;
        _logger = logger;
        Status = new CollectorStatus(
            Running: false,
            LastSuccessfulReadingUtc: null,
            LastSuccessfulUploadUtc: null,
            VigoConnected: false,
            LastError: null,
            BufferCount: 0,
            CurrentRetryDelay: options.SamplingInterval);
        Snapshot = new CollectorSnapshot(Status, null);
    }

    public CollectorStatus Status { get; private set; }

    public CollectorSnapshot Snapshot { get; private set; }

    public string ReaderName => _reader.ReaderName;

    public Task<int> GetBufferedMeasurementCountAsync(CancellationToken cancellationToken) =>
        _buffer.CountAsync(cancellationToken);

    public event Action<CollectorSnapshot>? SnapshotChanged;

    public void StartForegroundRun()
    {
        _logger.Log("collector_start", $"Collector started with {_reader.ReaderName}.");
        MarkStarted();
    }

    public void StopForegroundRun(string reason)
    {
        _logger.Log("collector_stop", reason);
        MarkStopped();
    }

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        StartForegroundRun();

        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var result = await RunCycleAsync(cancellationToken);
                await Task.Delay(result.NextDelay, cancellationToken);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            _logger.Log("collector_stop", "Collector cancelled.");
        }
        finally
        {
            MarkStopped();
        }
    }

    public async Task RunCyclesAsync(int cycleCount, CancellationToken cancellationToken)
    {
        if (cycleCount < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(cycleCount));
        }

        StartForegroundRun();

        try
        {
            for (var cycle = 0; cycle < cycleCount; cycle++)
            {
                var result = await RunCycleAsync(cancellationToken);
                if (cycle < cycleCount - 1)
                {
                    await Task.Delay(result.NextDelay, cancellationToken);
                }
            }
        }
        finally
        {
            MarkStopped();
        }
    }

    public async Task<CycleResult> RunCycleAsync(CancellationToken cancellationToken)
    {
        var readingsSucceeded = false;
        var readings = new List<SensorReadResult>();
        try
        {
            foreach (var sensor in SensorAllowlist.Pacific01)
            {
                var reading = await _reader.ReadAsync(sensor, cancellationToken);
                readings.Add(reading);
                _logger.Log(
                    "sensor_read_ok",
                    $"{sensor.Key} value={reading.Value:F3} durationMs={reading.Duration.TotalMilliseconds:F0} errorCode={reading.ErrorCode}");
            }

            readingsSucceeded = true;

            var measurement = _normalizer.Normalize(
                _options.CollectorId,
                _options.DeviceId,
                readings);
            await _buffer.EnqueueAsync(measurement, cancellationToken);

            var flushResult = await FlushBufferedMeasurementsAsync(cancellationToken);
            if (!flushResult.Succeeded)
            {
                return CompleteFailure(
                    flushResult.Error!,
                    vigoConnected: true,
                    readDuration: SumReadDurations(readings));
            }

            _backoff.Reset();
            var bufferCount = await _buffer.CountAsync(cancellationToken);
            _latestMeasurement = measurement;
            Status = new CollectorStatus(
                Running: Status.Running,
                LastSuccessfulReadingUtc: measurement.TimestampUtc,
                LastSuccessfulUploadUtc: _lastSuccessfulUploadUtc,
                VigoConnected: true,
                LastError: null,
                BufferCount: bufferCount,
                CurrentRetryDelay: _options.SamplingInterval);
            PublishSnapshot();
            _logger.Log("collector_status", $"bufferCount={bufferCount} retryDelay={_options.SamplingInterval.TotalSeconds:F0}s");
            return new CycleResult(true, _options.SamplingInterval, null)
            {
                ReadDuration = SumReadDurations(readings),
                ErrorCode = 0,
            };
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            var error = DescribeException(exception);
            _logger.Log(
                readingsSucceeded ? "collector_cycle_error" : "sensor_read_error",
                error);
            return CompleteFailure(
                error,
                vigoConnected: readingsSucceeded,
                readDuration: SumReadDurations(readings),
                errorCode: readings.FirstOrDefault(reading => reading.ErrorCode != 0)?.ErrorCode,
                exception: exception);
        }
    }

    public async Task<UploadResult> FlushBufferedMeasurementsAsync(CancellationToken cancellationToken)
    {
        while (true)
        {
            var measurement = await _buffer.PeekOldestAsync(cancellationToken);
            if (measurement is null)
            {
                return UploadResult.Success;
            }

            var result = await _uploader.UploadAsync(measurement, cancellationToken);
            if (!result.Succeeded)
            {
                _logger.Log("upload_failure", result.Error ?? "Unknown uploader failure.");
                return result;
            }

            await _buffer.RemoveOldestAsync(cancellationToken);
            _lastSuccessfulUploadUtc = DateTimeOffset.UtcNow;
        }
    }

    private CycleResult CompleteFailure(
        string error,
        bool vigoConnected,
        TimeSpan readDuration = default,
        int? errorCode = null,
        Exception? exception = null)
    {
        var delay = _backoff.RegisterFailure();
        Status = Status with
        {
            VigoConnected = vigoConnected,
            LastError = error,
            CurrentRetryDelay = delay,
        };
        PublishSnapshot();
        _logger.Log("backoff", $"nextRetrySeconds={delay.TotalSeconds:F0} error={error}");
        return new CycleResult(false, delay, error)
        {
            ReadDuration = readDuration,
            ErrorCode = errorCode,
            IsTimeout = GetRelevantException(exception) is TimeoutException,
            IsComError = GetRelevantException(exception) is System.Runtime.InteropServices.COMException,
        };
    }

    private static TimeSpan SumReadDurations(IEnumerable<SensorReadResult> readings) =>
        TimeSpan.FromTicks(readings.Sum(reading => reading.Duration.Ticks));

    private static string DescribeException(Exception exception)
    {
        var relevantException = GetRelevantException(exception) ?? exception;
        return relevantException switch
        {
            System.Runtime.InteropServices.COMException comException =>
                $"hresult=0x{comException.HResult:X8} message={comException.Message}",
            TimeoutException timeoutException => $"timeout message={timeoutException.Message}",
            _ => relevantException.Message,
        };
    }

    private static Exception? GetRelevantException(Exception? exception) => exception switch
    {
        System.Reflection.TargetInvocationException { InnerException: not null } wrappedException =>
            GetRelevantException(wrappedException.InnerException),
        _ => exception,
    };

    private void MarkStarted()
    {
        Status = Status with { Running = true };
        PublishSnapshot();
    }

    private void MarkStopped()
    {
        Status = Status with { Running = false };
        PublishSnapshot();
    }

    private void PublishSnapshot()
    {
        Snapshot = new CollectorSnapshot(Status, _latestMeasurement);
        try
        {
            SnapshotChanged?.Invoke(Snapshot);
        }
        catch (Exception exception)
        {
            _logger.Log("mockup_update_error", exception.Message);
        }
    }
}
