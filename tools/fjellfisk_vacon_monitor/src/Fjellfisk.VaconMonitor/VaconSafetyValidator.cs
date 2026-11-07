namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Prevents commands outside the safe simulator boundary. Future live control
/// requires a deliberately different, reviewed implementation.
/// </summary>
public sealed class VaconSafetyValidator
{
    private readonly bool _isSimulation;
    private readonly VaconControlLimits? _limits;

    public VaconSafetyValidator(bool isSimulation, VaconControlLimits? limits)
    {
        _isSimulation = isSimulation;
        _limits = limits;
    }

    public VaconControlLimits? Limits => _limits;

    public VaconCommandValidation Validate(
        VaconControlCommand command,
        decimal? targetHz,
        bool confirmed)
    {
        if (!_isSimulation)
        {
            return new VaconCommandValidation(false, "live-control-blocked");
        }

        if (!confirmed)
        {
            return new VaconCommandValidation(false, "confirmation-required");
        }

        if (command != VaconControlCommand.SetFrequency)
        {
            return new VaconCommandValidation(true, "simulated-command-approved");
        }

        if (_limits is null)
        {
            return new VaconCommandValidation(false, "frequency-limits-not-configured");
        }

        if (targetHz is null || targetHz < _limits.MinimumHz || targetHz > _limits.MaximumHz)
        {
            return new VaconCommandValidation(false, "target-out-of-range");
        }

        return new VaconCommandValidation(true, "simulated-target-approved");
    }
}
