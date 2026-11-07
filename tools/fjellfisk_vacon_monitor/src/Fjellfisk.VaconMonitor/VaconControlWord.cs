namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Documented representation of the fixed control-word bit 0 for a future,
/// separately commissioned control implementation. No live transport accepts
/// or sends this value in v0.4.0.
/// </summary>
public static class VaconControlWord
{
    public const ushort StartBit = 0x0001;

    public static ushort? For(VaconControlCommand command) => command switch
    {
        VaconControlCommand.StartMotor => StartBit,
        VaconControlCommand.StopMotor => 0x0000,
        VaconControlCommand.SetFrequency => null,
        _ => null,
    };
}
