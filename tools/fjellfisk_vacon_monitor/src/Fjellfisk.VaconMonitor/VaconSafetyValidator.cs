namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Records the commissioning boundary before any future physical-control
/// implementation is considered. This version never authorizes a command.
/// </summary>
public sealed class VaconSafetyValidator
{
    private readonly VaconControlLimits? _limits;

    public VaconSafetyValidator(VaconControlLimits? limits)
    {
        _limits = limits;
    }

    public VaconControlLimits? Limits => _limits;

    public VaconCommandValidation Validate(
        VaconControlCommand command,
        decimal? targetHz,
        bool confirmed)
    {
        if (!confirmed)
        {
            return new VaconCommandValidation(false, "confirmation-required");
        }

        return new VaconCommandValidation(false, "control-commissioning-required");
    }
}
