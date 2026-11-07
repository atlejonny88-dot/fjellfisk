namespace Fjellfisk.VaconMonitor;

public enum VaconDriveStatus
{
    Unknown,
    Running,
    Stopped,
    Fault,
}

public sealed record VaconActiveFault(string Code, string Description);

public sealed record VaconStatusWord(
    ushort Raw,
    bool Ready,
    bool Running,
    bool Fault,
    bool Alarm,
    bool AtReference)
{
    public static VaconStatusWord FromRaw(ushort raw) => new(
        raw,
        IsSet(raw, 0),
        IsSet(raw, 1),
        IsSet(raw, 3),
        IsSet(raw, 4),
        IsSet(raw, 5));

    public VaconDriveStatus DriveStatus => Fault
        ? VaconDriveStatus.Fault
        : Running ? VaconDriveStatus.Running : VaconDriveStatus.Stopped;

    public string ToDisplayText()
    {
        var states = new List<string>();
        if (Ready)
        {
            states.Add("Klar");
        }

        if (Running)
        {
            states.Add("Kjører");
        }

        if (Fault)
        {
            states.Add("Feil");
        }

        if (Alarm)
        {
            states.Add("Alarm");
        }

        if (AtReference)
        {
            states.Add("Ved referanse");
        }

        return states.Count == 0 ? "Ingen aktive statusbiter" : string.Join(" | ", states);
    }

    private static bool IsSet(ushort value, int bit) => (value & (1 << bit)) != 0;
}

public enum VaconControlCommand
{
    SetFrequency,
    StartMotor,
    StopMotor,
}

public sealed record VaconControlLimits(
    decimal MinimumHz,
    decimal MaximumHz,
    decimal DefaultStepHz,
    bool IsFacilityApproved = false,
    string Source = "unspecified");

public sealed record VaconCommandValidation(bool Accepted, string ResultCode);

public sealed record VaconControlAttempt(
    VaconControlCommand Command,
    decimal? TargetHz,
    bool Accepted,
    string ResultCode,
    decimal? ReadbackFrequencyHz = null,
    bool Acknowledged = false,
    ushort? PreparedControlWord = null,
    ushort? PreparedReferenceRaw = null);

public interface IVaconControlGateway
{
    bool ControlsEnabled { get; }

    VaconControlLimits? Limits { get; }

    string DisabledReason { get; }

    Task<VaconControlAttempt> ExecuteAsync(
        VaconControlCommand command,
        decimal? targetHz,
        CancellationToken cancellationToken);
}

/// <summary>
/// Explicit safety boundary for an actual VACON connection. No write register,
/// function code, control word, or remote-control operation is implemented.
/// </summary>
public sealed class BlockedLiveVaconControlGateway : IVaconControlGateway
{
    public bool ControlsEnabled => false;

    public VaconControlLimits? Limits => null;

    public string DisabledReason =>
        "Fysisk VACON-styring er ikke tilgjengelig før elektrisk og prosessmessig idriftsettelse er dokumentert.";

    public Task<VaconControlAttempt> ExecuteAsync(
        VaconControlCommand command,
        decimal? targetHz,
        CancellationToken cancellationToken) =>
        Task.FromResult(new VaconControlAttempt(command, targetHz, false, "control-commissioning-required"));
}
