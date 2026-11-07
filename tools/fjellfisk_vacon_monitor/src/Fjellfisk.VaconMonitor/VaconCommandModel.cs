namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Models commands before they reach a gateway. Live mode cannot pass this
/// boundary: the only executable command gateway in this version is simulated.
/// </summary>
public sealed class VaconCommandModel
{
    private readonly VaconSafetyValidator _safetyValidator;

    public VaconCommandModel(bool isSimulation, VaconControlLimits? limits)
    {
        _safetyValidator = new VaconSafetyValidator(isSimulation, limits);
    }

    public VaconCommandPreparation Prepare(
        VaconControlCommand command,
        decimal? targetHz,
        bool confirmed)
    {
        var validation = _safetyValidator.Validate(command, targetHz, confirmed);
        if (!validation.Accepted)
        {
            return new VaconCommandPreparation(validation, null);
        }

        ushort? normalizedReference = command == VaconControlCommand.SetFrequency
            ? new VaconFrequencyReferenceRange(
                _safetyValidator.Limits!.MinimumHz,
                _safetyValidator.Limits.MaximumHz).ToRaw(targetHz!.Value)
            : null;
        return new VaconCommandPreparation(
            validation,
            new VaconPreparedCommand(command, targetHz, VaconControlWord.For(command), normalizedReference));
    }
}

public sealed record VaconPreparedCommand(
    VaconControlCommand Command,
    decimal? TargetHz,
    ushort? ControlWord,
    ushort? NormalizedReference);

public sealed record VaconCommandPreparation(
    VaconCommandValidation Validation,
    VaconPreparedCommand? Command);
