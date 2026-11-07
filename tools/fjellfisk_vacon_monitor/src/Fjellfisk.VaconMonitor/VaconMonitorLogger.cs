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

    public void LogStartup(bool simulated) =>
        Write(simulated ? "[startup] mode=simulated" : "[startup] mode=live-read-only");

    public void LogControlAttempt(
        VaconControlAttempt attempt,
        string driveId,
        bool simulated,
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
        var controlWord = attempt.SimulatedControlWord is ushort word
            ? $" simulatedControlWord=0x{word:X4}"
            : string.Empty;
        var reference = attempt.SimulatedReferenceRaw is ushort rawReference
            ? $" simulatedReferenceRaw={rawReference}"
            : string.Empty;
        Write($"[control_attempt] drive={driveId} mode={(simulated ? "simulated" : "live-read-only")} command={attempt.Command.ToString().ToLowerInvariant()}{target}{actual}{readback}{controlWord}{reference} accepted={attempt.Accepted.ToString().ToLowerInvariant()} acknowledged={attempt.Acknowledged.ToString().ToLowerInvariant()} result={attempt.ResultCode}");
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
}

