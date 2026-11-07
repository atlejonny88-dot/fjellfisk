using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Fjellfisk.SensorCollector;

/// <summary>
/// A compile-time inventory candidate. Candidates are deliberately explicit:
/// this tool never searches the VIGO namespace or invokes discovery members.
/// </summary>
public sealed record VigoInventoryCandidate(
    string SensorId,
    string DisplayName,
    string SourceType,
    int SourceIndex,
    int ProbeIndex,
    string SourceDevice,
    string SourceChannel,
    int? MeterIndex,
    int? ChannelIndex,
    IReadOnlyList<SensorDefinition> Measurements);

/// <summary>
/// Separates compiled inventory families without exposing arbitrary paths to the
/// reader. Each source can only return its built-in candidate definitions.
/// </summary>
public interface IInventorySensorSource
{
    string SensorFamily { get; }

    IReadOnlyList<VigoInventoryCandidate> Candidates { get; }
}

public sealed class PacificSensorSource : IInventorySensorSource
{
    private static readonly IReadOnlyList<VigoInventoryCandidate> Pacific01Probes =
        Enumerable.Range(1, 4)
            .Select(probeIndex => new VigoInventoryCandidate(
                $"pacific01_probe{probeIndex:00}",
                $"Pacific 01 / Probe {probeIndex:00}",
                "Pacific",
                1,
                probeIndex,
                "Pacific_01",
                $"Probe_{probeIndex:00}",
                null,
                null,
                SensorAllowlist.GetPacific01Probe(probeIndex)))
            .ToArray();

    public string SensorFamily => "Pacific";

    public IReadOnlyList<VigoInventoryCandidate> Candidates => Pacific01Probes;
}

public sealed class DomSensorSource : IInventorySensorSource
{
    private static readonly IReadOnlyList<VigoInventoryCandidate> DomChannels =
        Enumerable.Range(0, 3)
            .SelectMany(meterIndex => Enumerable.Range(0, 6)
                .Select(channelIndex => new VigoInventoryCandidate(
                    $"dom_m{meterIndex}_do{channelIndex}",
                    $"DOM Meter {meterIndex} / DO {channelIndex}",
                    "DOM",
                    meterIndex,
                    channelIndex,
                    $"DO_Meter_{meterIndex}",
                    $"DO_{channelIndex}",
                    meterIndex,
                    channelIndex,
                    SensorAllowlist.GetDomChannel(meterIndex, channelIndex))))
            .ToArray();

    public string SensorFamily => "DOM";

    public IReadOnlyList<VigoInventoryCandidate> Candidates => DomChannels;
}

public static class VigoInventorySources
{
    public static IInventorySensorSource Pacific { get; } = new PacificSensorSource();

    public static IInventorySensorSource Dom { get; } = new DomSensorSource();
}

public sealed record VigoInventoryMeasurement(
    string Key,
    string Label,
    string Unit,
    string PhysId,
    float? Value,
    bool Success,
    int? ErrorCode,
    double DurationMs,
    string? FailureKind,
    string? ErrorMessage);

public sealed record VigoInventoryDevice(
    string SensorId,
    string DisplayName,
    string SourceType,
    int SourceIndex,
    int ProbeIndex,
    string SourceDevice,
    string SourceChannel,
    int? MeterIndex,
    int? ChannelIndex,
    IReadOnlyDictionary<string, VigoInventoryMeasurement> Measurements);

public sealed record VigoInventorySummary(
    int CandidatesTested,
    int ReadableSensors,
    int MeasurementChannels,
    int SuccessfulMeasurementChannels,
    int FailedReads,
    int ComErrors,
    int Timeouts);

public sealed record VigoInventoryReport(
    DateTimeOffset TimestampUtc,
    string Mode,
    string Source,
    string SensorFamily,
    IReadOnlyList<VigoInventoryDevice> Devices,
    VigoInventorySummary Summary);

/// <summary>
/// Performs one sequential, read-only pass through the explicit candidate list.
/// It has no retry loop because retrying unknown or unavailable paths would add
/// load without producing a safer inventory result.
/// </summary>
public sealed class VigoInventoryRunner
{
    private readonly ISensorReader _reader;
    private readonly IClock _clock;

    public VigoInventoryRunner(ISensorReader reader, IClock clock)
    {
        _reader = reader;
        _clock = clock;
    }

    public async Task<VigoInventoryReport> RunAsync(
        IInventorySensorSource source,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(source);
        return await RunAsync(source.SensorFamily, source.Candidates, cancellationToken);
    }

    public Task<VigoInventoryReport> RunAsync(
        IReadOnlyList<VigoInventoryCandidate> candidates,
        CancellationToken cancellationToken)
        => RunAsync("Unknown", candidates, cancellationToken);

    private async Task<VigoInventoryReport> RunAsync(
        string sensorFamily,
        IReadOnlyList<VigoInventoryCandidate> candidates,
        CancellationToken cancellationToken)
    {
        var devices = new List<VigoInventoryDevice>(candidates.Count);
        foreach (var candidate in candidates)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var measurements = new Dictionary<string, VigoInventoryMeasurement>(
                StringComparer.Ordinal);

            foreach (var sensor in candidate.Measurements)
            {
                cancellationToken.ThrowIfCancellationRequested();
                measurements[InventoryFieldName(sensor.Kind)] = await ReadOneAsync(
                    sensor,
                    cancellationToken);
            }

            devices.Add(new VigoInventoryDevice(
                candidate.SensorId,
                candidate.DisplayName,
                candidate.SourceType,
                candidate.SourceIndex,
                candidate.ProbeIndex,
                candidate.SourceDevice,
                candidate.SourceChannel,
                candidate.MeterIndex,
                candidate.ChannelIndex,
                measurements));
        }

        return new VigoInventoryReport(
            _clock.UtcNow,
            "read-only",
            "VIGO.PRO",
            sensorFamily,
            devices,
            CreateSummary(devices));
    }

    private async Task<VigoInventoryMeasurement> ReadOneAsync(
        SensorDefinition sensor,
        CancellationToken cancellationToken)
    {
        try
        {
            var reading = await _reader.ReadAsync(sensor, cancellationToken);
            if (reading.ErrorCode != 0)
            {
                return Failure(
                    sensor,
                    reading.Duration,
                    "vigo-error-code",
                    $"VIGO.PRO returned ErrorCode {reading.ErrorCode}.",
                    reading.ErrorCode);
            }

            if (reading.PnetDataType != 36 ||
                !string.Equals(reading.DotNetType, "System.Single", StringComparison.Ordinal) ||
                !float.IsFinite(reading.Value))
            {
                return Failure(
                    sensor,
                    reading.Duration,
                    "invalid-value",
                    "Expected a finite P-NET type 36 / System.Single scalar value.",
                    reading.ErrorCode);
            }

            return new VigoInventoryMeasurement(
                sensor.Key,
                DisplayLabel(sensor.Kind),
                Unit(sensor.Kind),
                sensor.PhysId,
                reading.Value,
                Success: true,
                ErrorCode: reading.ErrorCode,
                DurationMs: reading.Duration.TotalMilliseconds,
                FailureKind: null,
                ErrorMessage: null);
        }
        catch (TimeoutException exception)
        {
            return Failure(sensor, TimeSpan.Zero, "timeout", exception.Message);
        }
        catch (COMException exception)
        {
            var kind = exception.HResult == unchecked((int)0x80020006)
                ? "path-not-found"
                : "com-error";
            return Failure(
                sensor,
                TimeSpan.Zero,
                kind,
                $"HRESULT=0x{exception.HResult:X8} {SanitizeMessage(exception.Message)}");
        }
        catch (TargetInvocationException exception)
            when (exception.InnerException is COMException comException)
        {
            var kind = comException.HResult == unchecked((int)0x80020006)
                ? "path-not-found"
                : "com-error";
            return Failure(
                sensor,
                TimeSpan.Zero,
                kind,
                $"HRESULT=0x{comException.HResult:X8} {SanitizeMessage(comException.Message)}");
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            return Failure(
                sensor,
                TimeSpan.Zero,
                "read-error",
                SanitizeMessage(exception.Message));
        }
    }

    private static VigoInventorySummary CreateSummary(
        IReadOnlyList<VigoInventoryDevice> devices)
    {
        var channels = devices.SelectMany(device => device.Measurements.Values).ToArray();
        return new VigoInventorySummary(
            CandidatesTested: devices.Count,
            ReadableSensors: devices.Count(device =>
                device.Measurements.Values.Any(measurement => measurement.Success)),
            MeasurementChannels: channels.Length,
            SuccessfulMeasurementChannels: channels.Count(measurement => measurement.Success),
            FailedReads: channels.Count(measurement => !measurement.Success),
            ComErrors: channels.Count(measurement =>
                string.Equals(measurement.FailureKind, "com-error", StringComparison.Ordinal) ||
                string.Equals(measurement.FailureKind, "path-not-found", StringComparison.Ordinal)),
            Timeouts: channels.Count(measurement =>
                string.Equals(measurement.FailureKind, "timeout", StringComparison.Ordinal)));
    }

    private static VigoInventoryMeasurement Failure(
        SensorDefinition sensor,
        TimeSpan duration,
        string failureKind,
        string message,
        int? errorCode = null) =>
        new(
            sensor.Key,
            DisplayLabel(sensor.Kind),
            Unit(sensor.Kind),
            sensor.PhysId,
            Value: null,
            Success: false,
            ErrorCode: errorCode,
            DurationMs: duration.TotalMilliseconds,
            FailureKind: failureKind,
            ErrorMessage: SanitizeMessage(message));

    private static string InventoryFieldName(SensorKind kind) => kind switch
    {
        SensorKind.TemperatureC => "temperatureC",
        SensorKind.OxygenMgL => "oxygenMgL",
        SensorKind.OxygenSaturationPct => "oxygenSaturationPct",
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    private static string DisplayLabel(SensorKind kind) => kind switch
    {
        SensorKind.TemperatureC => "Temperature",
        SensorKind.OxygenMgL => "O2 concentration",
        SensorKind.OxygenSaturationPct => "O2 saturation",
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    private static string Unit(SensorKind kind) => kind switch
    {
        SensorKind.TemperatureC => "°C",
        SensorKind.OxygenMgL => "mg/L",
        SensorKind.OxygenSaturationPct => "%",
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    private static string SanitizeMessage(string message)
    {
        var sanitized = message
            .Replace('\r', ' ')
            .Replace('\n', ' ')
            .Trim();
        return sanitized.Length <= 300 ? sanitized : sanitized[..300];
    }
}

public static class VigoInventoryReportFile
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static async Task PersistAsync(
        string path,
        VigoInventoryReport report,
        CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("Inventory report path has no directory.");
        Directory.CreateDirectory(directory);
        object payload = string.Equals(report.SensorFamily, "DOM", StringComparison.Ordinal)
            ? new DomInventoryJsonReport(
                report.TimestampUtc,
                report.Mode,
                report.Source,
                report.SensorFamily,
                report.Devices,
                report.Summary)
            : report;
        var json = JsonSerializer.Serialize(payload, JsonOptions);
        await File.WriteAllTextAsync(path, json, cancellationToken);
    }

    private sealed record DomInventoryJsonReport(
        DateTimeOffset TimestampUtc,
        string Mode,
        string Source,
        string SensorFamily,
        [property: JsonPropertyName("channels")] IReadOnlyList<VigoInventoryDevice> Channels,
        VigoInventorySummary Summary);
}
