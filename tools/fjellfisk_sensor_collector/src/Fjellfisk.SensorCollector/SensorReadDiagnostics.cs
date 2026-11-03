using System.Text.Json;

namespace Fjellfisk.SensorCollector;

/// <summary>
/// Local-only diagnostics for the read-only VIGO path. Entries deliberately
/// omit PhysIds, exception messages, credentials, pairing codes, and readings.
/// </summary>
public interface ICollectorSensorReadDiagnostics
{
    void RecordMeasurementFailure(SensorReadDiagnosticEvent entry);

    void RecordStaReaderState(StaReaderDiagnosticEvent entry);
}

public sealed record SensorReadDiagnosticEvent(
    string SourceType,
    string Measurement,
    string Classification,
    int? VigoErrorCode = null);

public sealed record StaReaderDiagnosticEvent(
    string SourceType,
    string Measurement,
    string Stage,
    bool AlreadyBlocked);

public sealed class LocalSensorReadDiagnostics : ICollectorSensorReadDiagnostics
{
    private const int DefaultMaximumLogBytes = 2 * 1024 * 1024;
    private const int DefaultMaximumArchives = 2;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    private readonly object _gate = new();
    private readonly IClock _clock;
    private readonly int _maximumLogBytes;
    private readonly int _maximumArchives;

    public LocalSensorReadDiagnostics(
        string logsDirectory,
        IClock? clock = null,
        int maximumLogBytes = DefaultMaximumLogBytes,
        int maximumArchives = DefaultMaximumArchives)
    {
        if (maximumLogBytes <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumLogBytes));
        }

        if (maximumArchives < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumArchives));
        }

        Directory.CreateDirectory(logsDirectory);
        LogPath = Path.Combine(logsDirectory, "sensor-read.log");
        _clock = clock ?? SystemClock.Instance;
        _maximumLogBytes = maximumLogBytes;
        _maximumArchives = maximumArchives;
    }

    public string LogPath { get; }

    public void RecordMeasurementFailure(SensorReadDiagnosticEvent entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        Append(new
        {
            timestampUtc = _clock.UtcNow,
            @event = "measurement-failure",
            sourceType = SafeSourceType(entry.SourceType),
            measurement = SafeMeasurement(entry.Measurement),
            classification = SafeClassification(entry.Classification),
            vigoErrorCode = entry.VigoErrorCode,
        });
    }

    public void RecordStaReaderState(StaReaderDiagnosticEvent entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        Append(new
        {
            timestampUtc = _clock.UtcNow,
            @event = entry.AlreadyBlocked ? "sta-reader-already-blocked" : "sta-reader-blocked",
            sourceType = SafeSourceType(entry.SourceType),
            measurement = SafeMeasurement(entry.Measurement),
            classification = "timeout",
            stage = SafeStage(entry.Stage),
        });
    }

    private void Append(object entry)
    {
        lock (_gate)
        {
            RotateIfNeeded();
            File.AppendAllText(LogPath, JsonSerializer.Serialize(entry, JsonOptions) + Environment.NewLine);
        }
    }

    private void RotateIfNeeded()
    {
        if (!File.Exists(LogPath) || new FileInfo(LogPath).Length < _maximumLogBytes)
        {
            return;
        }

        if (_maximumArchives == 0)
        {
            File.Delete(LogPath);
            return;
        }

        for (var index = _maximumArchives; index >= 1; index--)
        {
            var source = index == 1 ? LogPath : LogPath + "." + (index - 1);
            var destination = LogPath + "." + index;
            if (File.Exists(source))
            {
                File.Move(source, destination, overwrite: true);
            }
        }
    }

    private static string SafeSourceType(string value) => value switch
    {
        "Pacific" => "Pacific",
        "DOM" => "DOM",
        _ => "Unknown",
    };

    private static string SafeMeasurement(string value) => value switch
    {
        "temperatureC" => "temperatureC",
        "oxygenMgL" => "oxygenMgL",
        "oxygenSaturationPct" => "oxygenSaturationPct",
        _ => "unknown",
    };

    private static string SafeClassification(string value) => value switch
    {
        "timeout" => "timeout",
        "com-error" => "com-error",
        "vigo-error" => "vigo-error",
        "invalid-read" => "invalid-read",
        "read-error" => "read-error",
        _ => "read-error",
    };

    private static string SafeStage(string value) => value switch
    {
        "create-com" => "create-com",
        "select-physid" => "select-physid",
        "read-value" => "read-value",
        "read-error-code" => "read-error-code",
        "queued" => "queued",
        _ => "unknown",
    };
}

internal sealed class NullCollectorSensorReadDiagnostics : ICollectorSensorReadDiagnostics
{
    public static readonly NullCollectorSensorReadDiagnostics Instance = new();

    private NullCollectorSensorReadDiagnostics()
    {
    }

    public void RecordMeasurementFailure(SensorReadDiagnosticEvent entry)
    {
    }

    public void RecordStaReaderState(StaReaderDiagnosticEvent entry)
    {
    }
}
