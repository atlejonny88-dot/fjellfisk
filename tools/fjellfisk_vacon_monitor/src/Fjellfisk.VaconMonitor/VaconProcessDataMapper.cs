namespace Fjellfisk.VaconMonitor;

public static class VaconProcessDataMapper
{
    public static VaconInputRegisterSnapshot Map(ushort[] registers, DateTimeOffset observedAtUtc)
    {
        if (registers.Length != VaconReadOnlyRegisterMap.InputRegisterCount)
        {
            throw new VaconReadException("invalid-read");
        }

        var statusWord = VaconStatusWord.FromRaw(Read(registers, VaconReadOnlyRegisterMap.StatusWordPduAddress));
        var frequency = Read(registers, VaconReadOnlyRegisterMap.ActualFrequencyPduAddress)
            / VaconReadOnlyRegisterMap.ActualFrequencyScale;
        var speed = Read(registers, VaconReadOnlyRegisterMap.MotorSpeedPduAddress);
        var currentRaw = Read(registers, VaconReadOnlyRegisterMap.MotorCurrentPduAddress);
        var faultCode = Read(registers, VaconReadOnlyRegisterMap.ActiveFaultPduAddress);

        return new VaconInputRegisterSnapshot(
            observedAtUtc,
            frequency,
            speed,
            null,
            statusWord.DriveStatus,
            CreateActiveFault(statusWord, faultCode),
            statusWord,
            currentRaw,
            false);
    }

    private static ushort Read(ushort[] registers, ushort pduAddress) =>
        registers[VaconReadOnlyRegisterMap.IndexForPduAddress(pduAddress)];

    private static VaconActiveFault? CreateActiveFault(VaconStatusWord statusWord, ushort faultCode)
    {
        if (!statusWord.Fault && faultCode == 0)
        {
            return null;
        }

        var description = statusWord.Fault && faultCode == 0
            ? "Feilbit er aktiv; kodebeskrivelse er ikke verifisert"
            : "Kodebeskrivelse er ikke verifisert";
        return new VaconActiveFault(faultCode.ToString(), description);
    }
}
