namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Keeps command-attempt logging separate from telemetry and communication
/// logging. It receives only safe command metadata.
/// </summary>
public sealed class VaconCommandLogger
{
    private readonly VaconMonitorLogger _logger;
    private readonly string _driveId;
    private readonly bool _simulated;

    public VaconCommandLogger(VaconMonitorLogger logger, string driveId, bool simulated)
    {
        _logger = logger;
        _driveId = SanitizeDriveId(driveId);
        _simulated = simulated;
    }

    public void Log(VaconControlAttempt attempt, decimal? actualFrequencyHz) =>
        _logger.LogControlAttempt(attempt, _driveId, _simulated, actualFrequencyHz);

    private static string SanitizeDriveId(string driveId)
    {
        var safe = new string(driveId
            .Where(character => char.IsLetterOrDigit(character) || character is '-' or '_')
            .Take(64)
            .ToArray());
        return string.IsNullOrWhiteSpace(safe) ? "vacon" : safe;
    }
}
