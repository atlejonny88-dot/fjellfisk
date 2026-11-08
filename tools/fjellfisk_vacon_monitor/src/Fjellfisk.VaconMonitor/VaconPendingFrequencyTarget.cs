namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Holds an operator's local, unsent target. It never talks to Modbus and is
/// deliberately reset on disconnect or a device change.
/// </summary>
public sealed class VaconPendingFrequencyTarget
{
    private readonly decimal _minimumHz;
    private readonly decimal _maximumHz;
    private readonly bool _limitsApproved;

    public VaconPendingFrequencyTarget(decimal minimumHz, decimal maximumHz, bool limitsApproved)
    {
        if (minimumHz < 0m || maximumHz <= minimumHz)
        {
            throw new ArgumentException("Frequency limits must be ordered non-negative values.");
        }

        _minimumHz = decimal.Ceiling(minimumHz);
        _maximumHz = decimal.Floor(maximumHz);
        _limitsApproved = limitsApproved;
    }

    public decimal? ValueHz { get; private set; }

    public bool CanAdjust => _limitsApproved && _minimumHz <= _maximumHz && ValueHz is not null;

    public bool TryInitializeFromFreshActual(decimal actualFrequencyHz)
    {
        if (_minimumHz > _maximumHz)
        {
            ValueHz = null;
            return false;
        }

        var nearestWholeHz = decimal.Round(actualFrequencyHz, 0, MidpointRounding.AwayFromZero);
        ValueHz = Math.Min(_maximumHz, Math.Max(_minimumHz, nearestWholeHz));
        return true;
    }

    public bool MoveByOneHz(int direction)
    {
        if (!CanAdjust || direction is not -1 and not 1)
        {
            return false;
        }

        ValueHz = Math.Min(_maximumHz, Math.Max(_minimumHz, ValueHz!.Value + direction));
        return true;
    }

    public void Clear() => ValueHz = null;
}
