namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Converts a target frequency to VACON's normalized Fieldbus Speed Reference
/// range. The physical minimum and maximum must be supplied explicitly; this
/// type never assumes that 10000 means 50 Hz.
/// </summary>
public sealed record VaconFrequencyReferenceRange(decimal MinimumHz, decimal MaximumHz)
{
    public ushort ToRaw(decimal targetHz)
    {
        if (MaximumHz <= MinimumHz)
        {
            throw new ArgumentException("Maximum frequency must exceed minimum frequency.");
        }

        if (targetHz < MinimumHz || targetHz > MaximumHz)
        {
            throw new ArgumentOutOfRangeException(nameof(targetHz));
        }

        var normalized = (targetHz - MinimumHz) / (MaximumHz - MinimumHz);
        return (ushort)decimal.Round(normalized * 10000m, 0, MidpointRounding.AwayFromZero);
    }

    public decimal FromRaw(ushort raw)
    {
        if (MaximumHz <= MinimumHz)
        {
            throw new ArgumentException("Maximum frequency must exceed minimum frequency.");
        }

        return MinimumHz + ((MaximumHz - MinimumHz) * raw / 10000m);
    }
}
