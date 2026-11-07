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
    ushort? SimulatedControlWord = null,
    ushort? SimulatedReferenceRaw = null);

public interface IVaconControlGateway
{
    bool IsSimulation { get; }

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
    public bool IsSimulation => false;

    public bool ControlsEnabled => false;

    public VaconControlLimits? Limits => null;

    public string DisabledReason =>
        "Ekte VACON-styring er blokkert: kontrollregistre, kontrollkilde og fysiske driftsgrenser er ikke verifisert.";

    public Task<VaconControlAttempt> ExecuteAsync(
        VaconControlCommand command,
        decimal? targetHz,
        CancellationToken cancellationToken) =>
        Task.FromResult(new VaconControlAttempt(command, targetHz, false, "live-control-blocked"));
}

public sealed class SimulatedVaconDrive
{
    private readonly object _sync = new();
    private readonly VaconControlLimits _limits;
    private decimal _targetHz;
    private bool _running;
    private bool _connectionAvailable = true;
    private VaconActiveFault? _fault;

    public SimulatedVaconDrive(VaconControlLimits? limits = null)
    {
        _limits = limits ?? new VaconControlLimits(0m, 50m, 0.5m, false, "simulator");
        _targetHz = 13m;
        _running = true;
    }

    public VaconControlLimits Limits => _limits;

    public decimal TargetFrequencyHz
    {
        get
        {
            lock (_sync)
            {
                return _targetHz;
            }
        }
    }

    public VaconInputRegisterSnapshot Read()
    {
        lock (_sync)
        {
            if (!_connectionAvailable)
            {
                throw new VaconReadException("com-error");
            }

            var state = _fault is not null
                ? VaconDriveStatus.Fault
                : _running ? VaconDriveStatus.Running : VaconDriveStatus.Stopped;
            var actualHz = _running && _fault is null ? _targetHz : 0m;
            var rpm = state == VaconDriveStatus.Running ? (int)Math.Round(actualHz * 60m) : 0;
            var current = state == VaconDriveStatus.Running ? Math.Round(1.5m + (actualHz * 0.62m), 2) : 0m;
            var statusWord = VaconStatusWord.FromRaw((ushort)(
                0x0001 |
                (state == VaconDriveStatus.Running ? 0x0002 | 0x0020 : 0) |
                (state == VaconDriveStatus.Fault ? 0x0008 : 0)));

            return new VaconInputRegisterSnapshot(
                DateTimeOffset.UtcNow,
                actualHz,
                rpm,
                current,
                state,
                _fault,
                statusWord,
                null,
                true,
                _targetHz);
        }
    }

    public VaconControlAttempt Execute(VaconControlCommand command, decimal? targetHz)
    {
        lock (_sync)
        {
            if (!_connectionAvailable)
            {
                return new VaconControlAttempt(command, targetHz, false, "simulated-connection-unavailable");
            }

            if (_fault is not null)
            {
                return new VaconControlAttempt(command, targetHz, false, "simulated-active-fault");
            }

            switch (command)
            {
                case VaconControlCommand.SetFrequency:
                    if (targetHz is null || targetHz < _limits.MinimumHz || targetHz > _limits.MaximumHz)
                    {
                        return new VaconControlAttempt(command, targetHz, false, "target-out-of-range");
                    }

                    _targetHz = decimal.Round(targetHz.Value, 2, MidpointRounding.AwayFromZero);
                    return new VaconControlAttempt(command, _targetHz, true, "simulated-target-accepted");
                case VaconControlCommand.StartMotor:
                    _running = true;
                    return new VaconControlAttempt(command, null, true, "simulated-start-accepted");
                case VaconControlCommand.StopMotor:
                    _running = false;
                    return new VaconControlAttempt(command, null, true, "simulated-stop-accepted");
                default:
                    return new VaconControlAttempt(command, targetHz, false, "unsupported-command");
            }
        }
    }

    public void SetSimulationFault(VaconActiveFault? fault)
    {
        lock (_sync)
        {
            _fault = fault;
        }
    }

    public void SetSimulationConnectionAvailable(bool available)
    {
        lock (_sync)
        {
            _connectionAvailable = available;
        }
    }
}

public sealed class SimulatedVaconReadOnlyClient : IVaconReadOnlyClient
{
    private readonly SimulatedVaconDrive _drive;

    public SimulatedVaconReadOnlyClient(SimulatedVaconDrive? drive = null)
    {
        _drive = drive ?? new SimulatedVaconDrive();
    }

    public Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken) =>
        Task.FromResult(_drive.Read());
}

public sealed class SimulatedVaconControlGateway : IVaconControlGateway
{
    private readonly SimulatedVaconDrive _drive;

    public SimulatedVaconControlGateway(SimulatedVaconDrive drive)
    {
        _drive = drive;
    }

    public bool IsSimulation => true;

    public bool ControlsEnabled => true;

    public VaconControlLimits Limits => _drive.Limits;

    public string DisabledReason => string.Empty;

    public Task<VaconControlAttempt> ExecuteAsync(
        VaconControlCommand command,
        decimal? targetHz,
        CancellationToken cancellationToken) =>
        Task.FromResult(_drive.Execute(command, targetHz));
}
