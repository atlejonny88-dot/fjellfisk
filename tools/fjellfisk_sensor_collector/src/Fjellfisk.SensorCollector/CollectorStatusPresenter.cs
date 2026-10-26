using System.Text;

namespace Fjellfisk.SensorCollector;

public static class CollectorApplication
{
    public const string Version = "1.0.0";
}

public static class CollectorStatusPresenter
{
    public static string Create(
        CollectorIdentity identity,
        EnrollmentSnapshot enrollment,
        CollectorRunner runner,
        int? bufferedMeasurementCount = null)
    {
        var status = runner.Status;
        var output = new StringBuilder();
        output.AppendLine("FJELLFISK COLLECTOR STATUS");
        output.AppendLine($"Collector ID: {identity.CollectorDeviceId}");
        output.AppendLine($"Version: {CollectorApplication.Version}");
        output.AppendLine($"Reader: {runner.ReaderName}");
        output.AppendLine($"Enrollment: {enrollment.State}");
        output.AppendLine($"Running: {status.Running}");
        output.AppendLine($"Vigo connectivity: {status.VigoConnected}");
        output.AppendLine($"Last successful measurement: {FormatTimestamp(status.LastSuccessfulReadingUtc)}");
        output.AppendLine($"Last upload: {FormatTimestamp(status.LastSuccessfulUploadUtc)}");
        output.AppendLine($"Buffer count: {bufferedMeasurementCount ?? status.BufferCount}");
        output.AppendLine($"Retry state: {status.CurrentRetryDelay.TotalSeconds:F0}s");
        return output.ToString().TrimEnd();
    }

    private static string FormatTimestamp(DateTimeOffset? timestamp) => timestamp is { } value
        ? value.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss zzz")
        : "Never";
}
