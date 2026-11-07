namespace Fjellfisk.VaconMonitor;

public sealed record VaconMonitorOptions(
    bool Simulated,
    string Host,
    int Port,
    byte UnitId,
    string DriveId,
    TimeSpan PollInterval,
    TimeSpan ReadTimeout,
    TimeSpan StaleAfter)
{
    public const string DefaultHost = "192.168.30.50";
    public const int DefaultPort = 502;
    public const byte DefaultUnitId = 255;
    public const string DefaultDriveId = "vacon-100-flow";

    public static VaconMonitorOptions SimulatedDefaults { get; } = new(
        Simulated: true,
        Host: DefaultHost,
        Port: DefaultPort,
        UnitId: DefaultUnitId,
        DriveId: DefaultDriveId,
        PollInterval: TimeSpan.FromSeconds(2),
        ReadTimeout: TimeSpan.FromSeconds(3),
        StaleAfter: TimeSpan.FromSeconds(8))
    {
        Drive = VaconDriveConfiguration.Default,
    };

    public VaconDriveConfiguration Drive { get; init; } = VaconDriveConfiguration.Default;

    public static VaconMonitorOptions Parse(string[] args)
    {
        var live = args.Any(argument => string.Equals(argument, "--live", StringComparison.OrdinalIgnoreCase));
        var unsupported = args.Where(argument => !string.Equals(argument, "--live", StringComparison.OrdinalIgnoreCase)).ToArray();

        if (unsupported.Length > 0)
        {
            throw new ArgumentException("VACON Monitor supports only --live. Without it, the safe simulation is used.");
        }

        return SimulatedDefaults with { Simulated = !live };
    }

    public VaconMonitorOptions ForDrive(VaconDriveConfiguration drive)
    {
        drive.Validate();
        return this with
        {
            Host = drive.Host,
            Port = drive.Port,
            UnitId = drive.UnitId,
            DriveId = drive.Id,
            Drive = drive,
        };
    }
}

public static class VaconReadOnlyRegisterMap
{
    // VACON documentation uses one-based register numbers. Modbus PDU offsets
    // are zero-based. The live read is a single contiguous FC04 block.
    public const ushort StatusWordDocumentedRegister = 2101;
    public const ushort StatusWordPduAddress = StatusWordDocumentedRegister - 1;
    public const ushort ActualFrequencyDocumentedRegister = 2104;
    public const ushort ActualFrequencyPduAddress = ActualFrequencyDocumentedRegister - 1;
    public const ushort MotorSpeedDocumentedRegister = 2105;
    public const ushort MotorSpeedPduAddress = MotorSpeedDocumentedRegister - 1;
    public const ushort MotorCurrentDocumentedRegister = 2106;
    public const ushort MotorCurrentPduAddress = MotorCurrentDocumentedRegister - 1;
    public const ushort ActiveFaultDocumentedRegister = 2111;
    public const ushort ActiveFaultPduAddress = ActiveFaultDocumentedRegister - 1;
    public const ushort FirstPduAddress = StatusWordPduAddress;
    public const ushort InputRegisterCount = ActiveFaultPduAddress - FirstPduAddress + 1;
    public const decimal ActualFrequencyScale = 100m;

    public static int IndexForPduAddress(ushort pduAddress)
    {
        if (pduAddress < FirstPduAddress || pduAddress >= FirstPduAddress + InputRegisterCount)
        {
            throw new ArgumentOutOfRangeException(nameof(pduAddress));
        }

        return pduAddress - FirstPduAddress;
    }
}

public static class VaconControlRegisterMap
{
    // These are documented for modelling and test coverage only. v0.3.0 has
    // no Modbus write transport and never transmits these addresses.
    public const ushort FieldbusControlWordDocumentedRegister = 2001;
    public const ushort FieldbusControlWordPduAddress = FieldbusControlWordDocumentedRegister - 1;
    public const ushort FieldbusSpeedReferenceDocumentedRegister = 2003;
    public const ushort FieldbusSpeedReferencePduAddress = FieldbusSpeedReferenceDocumentedRegister - 1;
}

