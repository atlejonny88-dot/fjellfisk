namespace Fjellfisk.SensorCollector;

public enum SensorKind
{
    TemperatureC,
    OxygenMgL,
    OxygenSaturationPct,
}

public sealed record SensorDefinition(
    string Key,
    string DeviceId,
    string PhysId,
    SensorKind Kind);

public sealed record SensorReadResult(
    SensorDefinition Sensor,
    float Value,
    int ErrorCode,
    int PnetDataType,
    string DotNetType,
    DateTimeOffset TimestampUtc,
    TimeSpan Duration);

public interface ISensorReader
{
    string ReaderName { get; }

    Task<SensorReadResult> ReadAsync(
        SensorDefinition sensor,
        CancellationToken cancellationToken);
}

public interface IReadOnlySensorAllowlist
{
    SensorDefinition GetRequired(string sensorKey);
}

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

public sealed class SystemClock : IClock
{
    public static readonly SystemClock Instance = new();

    private SystemClock()
    {
    }

    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
