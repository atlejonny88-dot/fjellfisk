namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Simulator-only representation of the documented fixed control-word bit 0.
/// No live Modbus transport accepts or sends this value.
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
