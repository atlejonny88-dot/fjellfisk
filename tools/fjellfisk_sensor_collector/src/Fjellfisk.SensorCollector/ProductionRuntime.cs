using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Fjellfisk.SensorCollector;

public sealed record CollectorBuildMetadata(
    string ProductVersion,
    string BuildVersion,
    string BuildId)
{
    public static CollectorBuildMetadata Current
    {
        get
        {
            var assembly = Assembly.GetEntryAssembly() ?? Assembly.GetExecutingAssembly();
            var informationalVersion = assembly
                .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
            var productVersion = assembly.GetName().Version?.ToString() ?? "0.0.0";

            return new CollectorBuildMetadata(
                productVersion,
                informationalVersion ?? productVersion,
                informationalVersion ?? "local-development");
        }
    }
}

public sealed record CollectorMeasurementStatus(
    string Field,
    string Status,
    int? ErrorCode,
    long? DurationMilliseconds);

public sealed record CollectorReading(
    string SensorId,
    string SourceType,
    string SourceDevice,
    string SourceChannel,
    float? TemperatureC,
    float? OxygenMgL,
    float? OxygenSaturationPct,
    DateTimeOffset ReadTimestampUtc,
    string Health,
    string? Error,
    IReadOnlyList<CollectorMeasurementStatus> Measurements);

public sealed record CollectorBatch(
    string CollectorId,
    string CollectorVersion,
    string BuildVersion,
    string BuildId,
    DateTimeOffset TimestampUtc,
    IReadOnlyList<CollectorReading> Readings);

public interface ICollectorBatchBuffer
{
    Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken);
}

/// <summary>
/// Local-only batch journal. It is intentionally not an uploader and performs
/// no network I/O; a future HTTPS transport can consume this contract.
/// </summary>
public sealed class LocalCollectorBatchBuffer : ICollectorBatchBuffer
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    private readonly string _path;

    public LocalCollectorBatchBuffer(string path)
    {
        _path = path;
    }

    public async Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(_path)
            ?? throw new InvalidOperationException("Collector batch buffer has no directory.");
        Directory.CreateDirectory(directory);
        await using var stream = new FileStream(
            _path,
            FileMode.Append,
            FileAccess.Write,
            FileShare.Read,
            bufferSize: 4096,
            useAsync: true);
        await using var writer = new StreamWriter(stream);
        await writer.WriteLineAsync(JsonSerializer.Serialize(batch, JsonOptions));
        await writer.FlushAsync();
        cancellationToken.ThrowIfCancellationRequested();
    }
}

/// <summary>
/// Writes one manually requested production read to a standalone local JSON
/// file. This is deliberately a buffer/output implementation, not a transport.
/// </summary>
public sealed class LocalProductionReadOutput : ICollectorBatchBuffer
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    private readonly string _bufferDirectory;

    public LocalProductionReadOutput(string bufferDirectory)
    {
        _bufferDirectory = bufferDirectory ?? throw new ArgumentNullException(nameof(bufferDirectory));
    }

    public string? LastWrittenPath { get; private set; }

    public async Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(batch);
        Directory.CreateDirectory(_bufferDirectory);

        var fileName = $"production-read-{batch.TimestampUtc.UtcDateTime:yyyy-MM-dd_HHmmss}.json";
        var path = Path.Combine(_bufferDirectory, fileName);
        var suffix = 1;
        while (File.Exists(path))
        {
            path = Path.Combine(
                _bufferDirectory,
                $"production-read-{batch.TimestampUtc.UtcDateTime:yyyy-MM-dd_HHmmss}-{suffix++:D2}.json");
        }

        await File.WriteAllTextAsync(
            path,
            JsonSerializer.Serialize(batch, JsonOptions),
            cancellationToken);
        LastWrittenPath = path;
    }
}

public sealed record ProductionReadSummary(
    int PacificSensors,
    int DomSensors,
    int SensorsAttempted,
    int SensorsOk,
    int SensorsDegraded,
    int SensorsFailed,
    int SuccessfulMeasurements,
    int FailedMeasurements,
    int ComErrors,
    int Timeouts)
{
    public static ProductionReadSummary Create(
        ProductionDiscoveryResult discovery,
        CollectorBatch batch)
    {
        ArgumentNullException.ThrowIfNull(discovery);
        ArgumentNullException.ThrowIfNull(batch);
        var measurements = batch.Readings.SelectMany(reading => reading.Measurements).ToArray();
        return new ProductionReadSummary(
            discovery.Sensors.Count(sensor => string.Equals(sensor.SourceType, "Pacific", StringComparison.Ordinal)),
            discovery.Sensors.Count(sensor => string.Equals(sensor.SourceType, "DOM", StringComparison.Ordinal)),
            batch.Readings.Count,
            batch.Readings.Count(reading => reading.Health == "ok"),
            batch.Readings.Count(reading => reading.Health == "degraded"),
            batch.Readings.Count(reading => reading.Health == "failed"),
            measurements.Count(measurement => measurement.Status == "ok"),
            measurements.Count(measurement => measurement.Status != "ok"),
            measurements.Count(measurement => measurement.Status == "com-error"),
            measurements.Count(measurement => measurement.Status == "timeout"));
    }
}

/// <summary>
/// Reads a discovery-generated runtime allowlist serially. It has no polling
/// schedule, service host, uploader, or mapping to Fjellfisk tanks/sections.
/// </summary>
public sealed class ProductionCollectorRuntime
{
    private readonly ISensorReader _reader;
    private readonly RuntimeSensorAllowlist _allowlist;
    private readonly CollectorIdentity _identity;
    private readonly CollectorBuildMetadata _buildMetadata;
    private readonly IClock _clock;
    private readonly ICollectorBatchBuffer _buffer;

    public ProductionCollectorRuntime(
        ISensorReader reader,
        RuntimeSensorAllowlist allowlist,
        CollectorIdentity identity,
        CollectorBuildMetadata buildMetadata,
        ICollectorBatchBuffer buffer,
        IClock? clock = null)
    {
        _reader = reader;
        _allowlist = allowlist;
        _identity = identity;
        _buildMetadata = buildMetadata;
        _buffer = buffer;
        _clock = clock ?? SystemClock.Instance;
    }

    public async Task<CollectorBatch> ReadOneCycleAsync(
        ProductionDiscoveryResult discovery,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(discovery);
        var readings = new List<CollectorReading>(discovery.Sensors.Count);
        foreach (var sensor in discovery.Sensors)
        {
            cancellationToken.ThrowIfCancellationRequested();
            readings.Add(await ReadOneSensorAsync(sensor, cancellationToken));
        }

        var batch = new CollectorBatch(
            _identity.CollectorDeviceId,
            _buildMetadata.ProductVersion,
            _buildMetadata.BuildVersion,
            _buildMetadata.BuildId,
            _clock.UtcNow,
            readings);
        await _buffer.PersistAsync(batch, cancellationToken);
        return batch;
    }

    private async Task<CollectorReading> ReadOneSensorAsync(
        CollectorSensorDescriptor sensor,
        CancellationToken cancellationToken)
    {
        float? temperature = null;
        float? oxygen = null;
        float? saturation = null;
        var failures = new List<string>();
        var measurementStatuses = new List<CollectorMeasurementStatus>(sensor.Measurements.Count);
        var timestamp = _clock.UtcNow;

        foreach (var measurement in sensor.Measurements)
        {
            try
            {
                var allowlistedMeasurement = _allowlist.GetRequired(measurement.Key);
                if (allowlistedMeasurement != measurement)
                {
                    throw new InvalidOperationException("Runtime sensor definition did not match its read-only allowlist.");
                }

                var reading = await _reader.ReadAsync(allowlistedMeasurement, cancellationToken);
                timestamp = reading.TimestampUtc;
                if (reading.ErrorCode != 0 || reading.PnetDataType != 36 ||
                    !string.Equals(reading.DotNetType, "System.Single", StringComparison.Ordinal) ||
                    !float.IsFinite(reading.Value))
                {
                    var status = reading.ErrorCode != 0 ? "vigo-error" : "invalid-read";
                    failures.Add($"{measurement.Kind}:{status}");
                    measurementStatuses.Add(new CollectorMeasurementStatus(
                        ToOutputField(measurement.Kind),
                        status,
                        reading.ErrorCode == 0 ? null : reading.ErrorCode,
                        (long)Math.Ceiling(reading.Duration.TotalMilliseconds)));
                    continue;
                }

                switch (measurement.Kind)
                {
                    case SensorKind.TemperatureC:
                        temperature = reading.Value;
                        break;
                    case SensorKind.OxygenMgL:
                        oxygen = reading.Value;
                        break;
                    case SensorKind.OxygenSaturationPct:
                        saturation = reading.Value;
                        break;
                }

                measurementStatuses.Add(new CollectorMeasurementStatus(
                    ToOutputField(measurement.Kind),
                    "ok",
                    null,
                    (long)Math.Ceiling(reading.Duration.TotalMilliseconds)));
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                var status = ClassifyFailure(exception);
                failures.Add($"{measurement.Kind}:{status}");
                measurementStatuses.Add(new CollectorMeasurementStatus(
                    ToOutputField(measurement.Kind),
                    status,
                    null,
                    null));
            }
        }

        var successes = new[] { temperature, oxygen, saturation }.Count(value => value is not null);
        var health = successes switch
        {
            3 => "ok",
            > 0 => "degraded",
            _ => "failed",
        };

        return new CollectorReading(
            sensor.SensorId,
            sensor.SourceType,
            sensor.SourceDevice,
            sensor.SourceChannel,
            temperature,
            oxygen,
            saturation,
            timestamp,
            health,
            failures.Count == 0 ? null : string.Join(";", failures),
            measurementStatuses);
    }

    private static string ToOutputField(SensorKind kind) => kind switch
    {
        SensorKind.TemperatureC => "temperatureC",
        SensorKind.OxygenMgL => "oxygenMgL",
        SensorKind.OxygenSaturationPct => "oxygenSaturationPct",
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    private static string ClassifyFailure(Exception exception)
    {
        var effective = exception is TargetInvocationException { InnerException: not null }
            ? exception.InnerException
            : exception;
        return effective switch
        {
            TimeoutException => "timeout",
            COMException => "com-error",
            _ => "read-error",
        };
    }

}
