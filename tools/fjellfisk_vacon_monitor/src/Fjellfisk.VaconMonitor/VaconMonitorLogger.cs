namespace Fjellfisk.VaconMonitor;

public sealed class VaconMonitorLogger
{
    private const long MaxLogBytes = 1024 * 1024;
    private const int RetainedArchives = 2;
    private readonly string _logDirectory;
    private readonly object _sync = new();

    public VaconMonitorLogger(string? logDirectory = null)
    {
        _logDirectory = logDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "Fjellfisk",
            "VaconMonitor",
            "logs");
    }

    public void LogFailure(string category)
    {
        var safeCategory = category switch
        {
            "timeout" or "com-error" or "modbus-error" or "invalid-read" or "read-error" => category,
            _ => "read-error",
        };

        Write($"[communication_error] category={safeCategory}");
    }

    public void LogStartup() => Write("[startup] mode=live-read-only");

    public void LogConnectionState(VaconConnectionState state, string? category = null)
    {
        var safeCategory = category switch
        {
            "timeout" or "com-error" or "modbus-error" or "invalid-read" or "read-error" => category,
            _ => null,
        };
        Write($"[connection] state={state.ToString().ToLowerInvariant()}{(safeCategory is null ? string.Empty : $" category={safeCategory}")}");
    }

    public void LogTelemetry(VaconInputRegisterSnapshot reading, string driveId)
    {
        var speed = reading.MotorSpeedRaw is ushort speedRaw ? $" speedRaw={speedRaw}" : string.Empty;
        var current = reading.MotorCurrentRaw is ushort currentRaw ? $" currentRaw={currentRaw}" : string.Empty;
        var fault = reading.ActiveFault?.Code is { Length: > 0 } code ? $" fault={code}" : string.Empty;
        Write($"[telemetry] drive={SanitizeDriveId(driveId)} actualHz={reading.ActualFrequencyHz:0.00}{speed}{current}{fault}");
    }

    public void LogControlAttempt(
        VaconControlAttempt attempt,
        string driveId,
        decimal? actualFrequencyHz)
    {
        var target = attempt.TargetHz is decimal targetHz
            ? $" targetHz={targetHz:0.00}"
            : string.Empty;
        var readback = attempt.ReadbackFrequencyHz is decimal readbackHz
            ? $" readbackHz={readbackHz:0.00}"
            : string.Empty;
        var actual = actualFrequencyHz is decimal actualHz
            ? $" actualHz={actualHz:0.00}"
            : string.Empty;
        var controlWord = attempt.PreparedControlWord is ushort word
            ? $" preparedControlWord=0x{word:X4}"
            : string.Empty;
        var reference = attempt.PreparedReferenceRaw is ushort rawReference
            ? $" preparedReferenceRaw={rawReference}"
            : string.Empty;
        Write($"[control_attempt] drive={SanitizeDriveId(driveId)} mode=live-read-only command={attempt.Command.ToString().ToLowerInvariant()}{target}{actual}{readback}{controlWord}{reference} accepted={attempt.Accepted.ToString().ToLowerInvariant()} acknowledged={attempt.Acknowledged.ToString().ToLowerInvariant()} result={attempt.ResultCode}");
    }

    private void Write(string message)
    {
        lock (_sync)
        {
            Directory.CreateDirectory(_logDirectory);
            var path = Path.Combine(_logDirectory, "vacon-monitor.log");
            RotateIfNeeded(path);
            File.AppendAllText(path, $"{DateTimeOffset.UtcNow:O} {message}{Environment.NewLine}");
        }
    }

    private void RotateIfNeeded(string path)
    {
        if (!File.Exists(path) || new FileInfo(path).Length < MaxLogBytes)
        {
            return;
        }

        for (var index = RetainedArchives; index >= 1; index--)
        {
            var source = index == 1 ? path : $"{path}.{index - 1}";
            var destination = $"{path}.{index}";
            if (File.Exists(destination))
            {
                File.Delete(destination);
            }

            if (File.Exists(source))
            {
                File.Move(source, destination);
            }
        }
    }

    private static string SanitizeDriveId(string driveId)
    {
        var safe = new string(driveId
            .Where(character => char.IsLetterOrDigit(character) || character is '-' or '_')
            .Take(64)
            .ToArray());
        return string.IsNullOrWhiteSpace(safe) ? "vacon" : safe;
    }
}

