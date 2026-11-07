namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Models the documented control-word/reference contract without granting a
/// path to a physical transport. The live control gateway is deliberately
/// blocked until formal commissioning is complete.
/// </summary>
public sealed class VaconCommandModel
{
    private readonly VaconSafetyValidator _safetyValidator;

    public VaconCommandModel(VaconControlLimits? limits)
    {
        _safetyValidator = new VaconSafetyValidator(limits);
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
