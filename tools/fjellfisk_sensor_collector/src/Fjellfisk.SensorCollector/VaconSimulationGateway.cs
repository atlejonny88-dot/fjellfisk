namespace Fjellfisk.SensorCollector;

/// <summary>
/// A transport-free test double for the future VACON command lifecycle.
/// It deliberately contains no Modbus, TCP, VPN, credentials or production
/// uploader code. Physical drives remain outside the Collector until a future
/// model-specific gateway and site commissioning have been approved.
/// </summary>
public enum VaconSimulationCommandType
{
    Start,
    Stop,
    SetFrequency,
    FaultReset,
}

public enum VaconSimulationResultStatus
{
    Verified,
    Rejected,
}

public sealed record VaconSimulationProfile(
    string ProfileId,
    bool IsDocumented,
    bool SupportsRemoteControl);

public sealed record VaconSimulationTelemetry(
    DateTimeOffset MeasuredAtUtc,
    bool Running,
    decimal ActualHz,
    decimal ReferenceHz);

public sealed record VaconSimulationDevice(
    string FacilityId,
    string DeviceId,
    VaconSimulationProfile Profile,
    bool SimulationOnly,
    bool Entitled,
    bool GatewayConnected,
    bool LocalInterlockSatisfied,
    decimal MinimumHz,
    decimal MaximumHz,
    VaconSimulationTelemetry Telemetry);

public sealed record VaconSimulationRequest(
    string RequestId,
    string FacilityId,
    string DeviceId,
    VaconSimulationCommandType Type,
    DateTimeOffset ExpiresAtUtc,
    decimal? FrequencyHz = null);

public sealed record VaconSimulationAuthorization(
    string FacilityId,
    bool CanRead,
    bool CanControl,
    bool HasEntitlement);

public sealed record VaconSimulationResult(
    VaconSimulationResultStatus Status,
    string RequestId,
    string? Reason,
    VaconSimulationTelemetry? Readback)
{
    public static VaconSimulationResult Rejected(string requestId, string reason) =>
        new(VaconSimulationResultStatus.Rejected, requestId, reason, null);

    public static VaconSimulationResult Verified(
        string requestId,
        VaconSimulationTelemetry readback) =>
        new(VaconSimulationResultStatus.Verified, requestId, null, readback);
}

public sealed class SimulatedVaconGateway
{
    private static readonly TimeSpan MaximumTelemetryAge = TimeSpan.FromSeconds(30);

    private readonly Dictionary<string, VaconSimulationDevice> _devices = new(StringComparer.Ordinal);
    private readonly HashSet<string> _processedRequestIds = new(StringComparer.Ordinal);

    public SimulatedVaconGateway(IEnumerable<VaconSimulationDevice> devices)
    {
        foreach (var device in devices)
        {
            _devices.Add(Key(device.FacilityId, device.DeviceId), device);
        }
    }

    public VaconSimulationResult Process(
        VaconSimulationRequest request,
        VaconSimulationAuthorization authorization,
        DateTimeOffset now)
    {
        if (!authorization.CanRead || !authorization.CanControl ||
            !string.Equals(authorization.FacilityId, request.FacilityId, StringComparison.Ordinal))
        {
            return VaconSimulationResult.Rejected(request.RequestId, "missing-pump-control-permission");
        }

        if (!_processedRequestIds.Add(request.RequestId))
        {
            return VaconSimulationResult.Rejected(request.RequestId, "duplicate-request");
        }

        if (request.ExpiresAtUtc <= now)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "expired-request");
        }

        if (!_devices.TryGetValue(Key(request.FacilityId, request.DeviceId), out var device))
        {
            return VaconSimulationResult.Rejected(request.RequestId, "device-not-found-in-facility");
        }

        if (!authorization.HasEntitlement || !device.Entitled)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "vacon-control-not-entitled");
        }

        if (!device.SimulationOnly)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "physical-control-disabled");
        }

        if (!device.Profile.IsDocumented || !device.Profile.SupportsRemoteControl)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "model-profile-not-approved");
        }

        if (!device.GatewayConnected)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "gateway-not-connected");
        }

        if (!device.LocalInterlockSatisfied)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "local-interlock-blocked");
        }

        var age = now - device.Telemetry.MeasuredAtUtc;
        if (age < TimeSpan.Zero || age > MaximumTelemetryAge)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "telemetry-stale");
        }

        if (request.Type == VaconSimulationCommandType.SetFrequency &&
            (request.FrequencyHz is null ||
             request.FrequencyHz < device.MinimumHz ||
             request.FrequencyHz > device.MaximumHz))
        {
            return VaconSimulationResult.Rejected(request.RequestId, "frequency-out-of-range");
        }

        if (request.Type != VaconSimulationCommandType.SetFrequency && request.FrequencyHz is not null)
        {
            return VaconSimulationResult.Rejected(request.RequestId, "unexpected-frequency-value");
        }

        var running = request.Type switch
        {
            VaconSimulationCommandType.Start => true,
            VaconSimulationCommandType.Stop => false,
            _ => device.Telemetry.Running,
        };
        var reference = request.Type switch
        {
            VaconSimulationCommandType.SetFrequency => request.FrequencyHz!.Value,
            VaconSimulationCommandType.Stop => 0m,
            VaconSimulationCommandType.Start when device.Telemetry.ReferenceHz <= 0m => device.MinimumHz,
            _ => device.Telemetry.ReferenceHz,
        };
        var readback = new VaconSimulationTelemetry(
            now,
            running,
            running ? reference : 0m,
            reference);
        _devices[Key(device.FacilityId, device.DeviceId)] = device with { Telemetry = readback };

        // This verified state is generated exclusively by the in-memory test
        // double. It is never evidence of a real motor response.
        return VaconSimulationResult.Verified(request.RequestId, readback);
    }

    private static string Key(string facilityId, string deviceId) =>
        $"{facilityId}\u001f{deviceId}";
}
