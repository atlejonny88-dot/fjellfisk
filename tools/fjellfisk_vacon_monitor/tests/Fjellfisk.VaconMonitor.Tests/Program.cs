using System.Reflection;
using Fjellfisk.VaconMonitor;

var tests = new (string Name, Func<Task> Run)[]
{
    ("Simulated VACON returns verified 13.00 Hz", SimulatedReadReturnsVerifiedFrequencyAsync),
    ("Simulator applies target frequency and reads it back", SimulatorAppliesFrequencyAndReadsBackAsync),
    ("Simulator supports frequency increases and reductions", SimulatorSupportsFrequencyIncreaseAndReductionAsync),
    ("Simulator reference scaling uses configured frequency limits", SimulatorReferenceScalingUsesConfiguredLimitsAsync),
    ("Simulator start and stop change only simulated state", SimulatorStartAndStopAsync),
    ("Simulator handles faults and connection loss safely", SimulatorHandlesFaultAndConnectionLossAsync),
    ("Simulator rejects an invalid target frequency", SimulatorRejectsInvalidFrequencyAsync),
    ("Commands require an explicit confirmation", CommandsRequireExplicitConfirmationAsync),
    ("Live VACON control stays explicitly blocked", LiveControlRemainsBlockedAsync),
    ("Confirmed live command attempts remain blocked", ConfirmedLiveCommandsRemainBlockedAsync),
    ("Reconnect never starts the motor or replays a prior command", ReconnectDoesNotReplayCommandAsync),
    ("Controller serializes monitor reads and simulator commands", ControllerSerializesReadsAndCommandsAsync),
    ("Modbus request uses FC04 for the documented process-data block", ModbusRequestTargetsProcessDataBlockAsync),
    ("Modbus response maps the verified frequency and RPM", ModbusResponseMapsFrequencyAndSpeedAsync),
    ("Status word exposes ready, running, fault, alarm and reference", StatusWordIsDecodedAsync),
    ("Active fault code is surfaced without inventing a description", ActiveFaultCodeIsUnverifiedAsync),
    ("Motor current remains raw until its scaling is verified", MotorCurrentRemainsRawAsync),
    ("Invalid and exception responses are rejected", InvalidResponsesAreRejectedAsync),
    ("Controller becomes stale without hiding the last reading", ControllerMarksFailedDataStaleAsync),
    ("Controller prevents overlapping polls", ControllerPreventsOverlappingPollsAsync),
    ("Communication log retains safe categories only", CommunicationLogUsesSafeCategoriesAsync),
    ("Command log records only safe command metadata", CommandLogUsesSafeMetadataAsync),
    ("Modbus client exposes no write or control API", ModbusClientExposesNoWriteApiAsync),
};

var failures = new List<string>();
foreach (var (name, run) in tests)
{
    try
    {
        await run();
        Console.WriteLine($"PASS {name}");
    }
    catch (Exception exception)
    {
        failures.Add($"FAIL {name}: {exception.Message}");
    }
}

foreach (var failure in failures)
{
    Console.Error.WriteLine(failure);
}

Console.WriteLine($"VACON Monitor tests: {tests.Length - failures.Count}/{tests.Length} passed");
return failures.Count == 0 ? 0 : 1;

static async Task SimulatedReadReturnsVerifiedFrequencyAsync()
{
    var result = await new SimulatedVaconReadOnlyClient().ReadAsync(CancellationToken.None);
    Assert(result.ActualFrequencyHz == 13.00m, "Expected the simulated confirmed frequency.");
}

static async Task SimulatorAppliesFrequencyAndReadsBackAsync()
{
    var drive = new SimulatedVaconDrive();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        new SimulatedVaconControlGateway(drive));

    await controller.PollOnceAsync(CancellationToken.None);
    var result = await controller.ApplyTargetFrequencyAsync(14.5m, true, CancellationToken.None);
    Assert(result.Accepted, "A valid simulated target should be accepted.");
    Assert(result.Acknowledged, "The simulator command was not acknowledged by a readback.");
    Assert(result.ReadbackFrequencyHz == 14.5m, "The simulated target must be read back after Apply.");
    Assert(controller.Current.ActualFrequencyHz == 14.5m, "The controller did not publish the readback.");
    DeleteTestDirectory(directory);
}

static Task SimulatorReferenceScalingUsesConfiguredLimitsAsync()
{
    var range = new VaconFrequencyReferenceRange(10m, 30m);
    Assert(range.ToRaw(10m) == 0, "The configured minimum must map to zero.");
    Assert(range.ToRaw(13m) == 1500, "Reference scaling must use configured 10-30 Hz limits, not an assumed 50 Hz.");
    Assert(range.ToRaw(30m) == 10000, "The configured maximum must map to 10000.");
    Assert(range.FromRaw(1500) == 13m, "Reference decoding must use the same configured limits.");
    AssertThrowsType(() => range.ToRaw(30.1m), typeof(ArgumentOutOfRangeException));
    return Task.CompletedTask;
}

static async Task SimulatorSupportsFrequencyIncreaseAndReductionAsync()
{
    var drive = new SimulatedVaconDrive();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        new SimulatedVaconControlGateway(drive));

    var increased = await controller.ApplyTargetFrequencyAsync(13.1m, true, CancellationToken.None);
    var reduced = await controller.ApplyTargetFrequencyAsync(13m, true, CancellationToken.None);
    Assert(increased.Acknowledged && reduced.Acknowledged, "Simulator frequency changes were not acknowledged.");
    Assert(drive.TargetFrequencyHz == 13m, "Simulator frequency reduction did not return to the requested target.");
    DeleteTestDirectory(directory);
}

static async Task SimulatorStartAndStopAsync()
{
    var drive = new SimulatedVaconDrive();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        new SimulatedVaconControlGateway(drive));

    var stopped = await controller.StopMotorAsync(true, CancellationToken.None);
    Assert(stopped.Accepted && stopped.ReadbackFrequencyHz == 0m, "Simulator stop must return a zero-Hz readback.");
    Assert(controller.Current.DriveStatus == VaconDriveStatus.Stopped, "Simulator did not enter stopped state.");
    var started = await controller.StartMotorAsync(true, CancellationToken.None);
    Assert(started.Accepted && started.ReadbackFrequencyHz == 13m, "Simulator start must read back its prior target.");
    Assert(controller.Current.DriveStatus == VaconDriveStatus.Running, "Simulator did not enter running state.");
    DeleteTestDirectory(directory);
}

static async Task SimulatorHandlesFaultAndConnectionLossAsync()
{
    var drive = new SimulatedVaconDrive();
    var gateway = new SimulatedVaconControlGateway(drive);
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        gateway);

    drive.SetSimulationFault(new VaconActiveFault("SIM-01", "Simulert aktiv feil"));
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(controller.Current.DriveStatus == VaconDriveStatus.Fault, "Simulator fault was not exposed.");
    var blockedByFault = await controller.StartMotorAsync(true, CancellationToken.None);
    Assert(!blockedByFault.Accepted, "A simulated active fault must reject commands.");

    drive.SetSimulationFault(null);
    drive.SetSimulationConnectionAvailable(false);
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(controller.Current.State is VaconConnectionState.Stale or VaconConnectionState.Unavailable, "Connection loss was not reported.");
    drive.SetSimulationConnectionAvailable(true);
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(controller.Current.State == VaconConnectionState.Simulated, "Simulator did not recover after a local connection restore.");
    DeleteTestDirectory(directory);
}

static async Task SimulatorRejectsInvalidFrequencyAsync()
{
    var drive = new SimulatedVaconDrive();
    var result = await new SimulatedVaconControlGateway(drive)
        .ExecuteAsync(VaconControlCommand.SetFrequency, 50.5m, CancellationToken.None);
    Assert(!result.Accepted && result.ResultCode == "target-out-of-range", "Out-of-range simulator target was accepted.");
}

static async Task CommandsRequireExplicitConfirmationAsync()
{
    var drive = new SimulatedVaconDrive();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        new SimulatedVaconControlGateway(drive));

    var result = await controller.ApplyTargetFrequencyAsync(14m, false, CancellationToken.None);
    Assert(!result.Accepted && result.ResultCode == "confirmation-required", "An unconfirmed simulator command must be rejected.");
    Assert(drive.TargetFrequencyHz == 13m, "An unconfirmed command changed simulator state.");
    DeleteTestDirectory(directory);
}

static async Task LiveControlRemainsBlockedAsync()
{
    var gateway = new BlockedLiveVaconControlGateway();
    var result = await gateway.ExecuteAsync(VaconControlCommand.StartMotor, null, CancellationToken.None);
    Assert(!gateway.ControlsEnabled, "Live controls must not be enabled by default.");
    Assert(!result.Accepted && result.ResultCode == "live-control-blocked", "Live control was not explicitly blocked.");
}

static async Task ConfirmedLiveCommandsRemainBlockedAsync()
{
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(),
        VaconMonitorOptions.SimulatedDefaults with { Simulated = false },
        new VaconMonitorLogger(directory),
        new BlockedLiveVaconControlGateway());

    var attempts = await Task.WhenAll(
        controller.ApplyTargetFrequencyAsync(14m, true, CancellationToken.None),
        controller.StartMotorAsync(true, CancellationToken.None),
        controller.StopMotorAsync(true, CancellationToken.None));
    Assert(attempts.All(result => !result.Accepted && result.ResultCode == "live-control-blocked"),
        "A confirmed live command bypassed the read-only boundary.");
    DeleteTestDirectory(directory);
}

static async Task ReconnectDoesNotReplayCommandAsync()
{
    var drive = new SimulatedVaconDrive();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        new SimulatedVaconReadOnlyClient(drive),
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        new SimulatedVaconControlGateway(drive));

    await controller.ApplyTargetFrequencyAsync(14m, true, CancellationToken.None);
    await controller.StopMotorAsync(true, CancellationToken.None);
    drive.SetSimulationConnectionAvailable(false);
    await controller.PollOnceAsync(CancellationToken.None);
    drive.SetSimulationConnectionAvailable(true);
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(drive.TargetFrequencyHz == 14m, "Reconnect replayed or changed a previous command.");
    Assert(controller.Current.DriveStatus == VaconDriveStatus.Stopped, "Reconnect automatically started the simulated motor.");
    Assert(controller.Current.ActualFrequencyHz == 0m, "A stopped motor returned a non-zero frequency after reconnect.");
    DeleteTestDirectory(directory);
}

static async Task ControllerSerializesReadsAndCommandsAsync()
{
    var client = new BlockingClient();
    var gateway = new TrackingControlGateway();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        client,
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory),
        gateway);

    var poll = controller.PollOnceAsync(CancellationToken.None);
    await client.WaitUntilCalledAsync();
    var command = controller.ApplyTargetFrequencyAsync(14m, true, CancellationToken.None);
    await Task.Delay(50);
    Assert(gateway.Calls == 0, "A control command ran alongside an active monitor read.");
    client.Complete();
    await poll;
    await command;
    Assert(gateway.Calls == 1, "The queued control command did not run after the read completed.");
    DeleteTestDirectory(directory);
}

static Task ModbusRequestTargetsProcessDataBlockAsync()
{
    var request = VaconReadOnlyModbusClient.BuildReadInputRegisterRequest(0x1234, 255);
    Assert(request.Length == 12, "Unexpected Modbus request size.");
    Assert(request[6] == 255, "The request unit ID changed.");
    Assert(request[7] == 0x04, "The request must only use FC04.");
    Assert(VaconReadOnlyRegisterMap.StatusWordDocumentedRegister == 2101, "The documented status-word register changed.");
    Assert(VaconReadOnlyRegisterMap.ActualFrequencyDocumentedRegister == 2104, "The documented VACON frequency register changed.");
    Assert(VaconReadOnlyRegisterMap.ActualFrequencyPduAddress == 2103, "Documented register 2104 must map to PDU address 2103.");
    Assert(ReadUInt16(request, 8) == 2100, "The process-data block must start at zero-based PDU address 2100.");
    Assert(ReadUInt16(request, 10) == 11, "The process-data block must contain registers 2101 through 2111.");
    Assert(VaconControlRegisterMap.FieldbusControlWordPduAddress == 2000, "Control word 2001 must map to PDU 2000.");
    Assert(VaconControlRegisterMap.FieldbusSpeedReferencePduAddress == 2002, "Speed reference 2003 must map to PDU 2002.");
    return Task.CompletedTask;
}

static async Task ModbusResponseMapsFrequencyAndSpeedAsync()
{
    var transport = new FixedResponseTransport(BuildResponse(1, 255, BuildProcessData(
        statusWord: 0x0023,
        frequencyRaw: 1300,
        speedRpm: 780,
        currentRaw: 153,
        faultCode: 0)));
    var options = VaconMonitorOptions.SimulatedDefaults with { Simulated = false };
    var client = new VaconReadOnlyModbusClient(options, transport);
    var result = await client.ReadAsync(CancellationToken.None);
    Assert(result.ActualFrequencyHz == 13.00m, "Register 2104 must be scaled from 1300 to 13.00 Hz.");
    Assert(result.MotorSpeedRpm == 780, "Register 2105 must be presented as raw RPM.");
    Assert(transport.Request![7] == 0x04, "The transport saw a non-read function.");
    Assert(ReadUInt16(transport.Request, 8) == 2100, "The client shifted the process-data start address.");
}

static Task StatusWordIsDecodedAsync()
{
    var status = VaconStatusWord.FromRaw(0x003B);
    Assert(status.Ready, "Ready bit was not decoded.");
    Assert(status.Running, "Running bit was not decoded.");
    Assert(status.Fault, "Fault bit was not decoded.");
    Assert(status.Alarm, "Alarm bit was not decoded.");
    Assert(status.AtReference, "At-reference bit was not decoded.");
    Assert(status.DriveStatus == VaconDriveStatus.Fault, "Fault must override running in drive status.");
    return Task.CompletedTask;
}

static Task ActiveFaultCodeIsUnverifiedAsync()
{
    var snapshot = VaconProcessDataMapper.Map(BuildProcessData(
        statusWord: 0x0008,
        frequencyRaw: 0,
        speedRpm: 0,
        currentRaw: 0,
        faultCode: 37), DateTimeOffset.UtcNow);
    Assert(snapshot.ActiveFault?.Code == "37", "The active fault code was not surfaced.");
    Assert(snapshot.ActiveFault?.Description.Contains("ikke verifisert", StringComparison.OrdinalIgnoreCase) == true,
        "The monitor must not invent a fault description.");
    return Task.CompletedTask;
}

static Task MotorCurrentRemainsRawAsync()
{
    var snapshot = VaconProcessDataMapper.Map(BuildProcessData(
        statusWord: 0x0001,
        frequencyRaw: 1300,
        speedRpm: 780,
        currentRaw: 456,
        faultCode: 0), DateTimeOffset.UtcNow);
    Assert(snapshot.MotorCurrentRaw == 456, "The raw motor-current value was not preserved.");
    Assert(snapshot.MotorCurrentAmperes is null, "Live motor current must not be assigned an assumed ampere scale.");
    Assert(!snapshot.MotorCurrentScaleVerified, "Live motor-current scaling must remain unverified.");
    return Task.CompletedTask;
}

static Task InvalidResponsesAreRejectedAsync()
{
    AssertThrows(() => VaconReadOnlyModbusClient.ParseReadInputRegisterResponse(new byte[8], 1, 255), "invalid-read");
    AssertThrows(() => VaconReadOnlyModbusClient.ParseReadInputRegisterResponse(BuildExceptionResponse(1, 255), 1, 255), "modbus-error");
    AssertThrows(() => VaconReadOnlyModbusClient.ParseReadInputRegisterResponse(BuildResponse(2, 255, BuildProcessData()), 1, 255), "invalid-read");
    return Task.CompletedTask;
}

static async Task ControllerMarksFailedDataStaleAsync()
{
    var now = new DateTimeOffset(2026, 11, 6, 12, 0, 0, TimeSpan.Zero);
    var client = new SequenceClient(
        new VaconInputRegisterSnapshot(now, 13.00m),
        new VaconReadException("timeout"));
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        client,
        VaconMonitorOptions.SimulatedDefaults with { Simulated = false },
        new VaconMonitorLogger(directory),
        utcNow: () => now.AddSeconds(6));

    await controller.PollOnceAsync(CancellationToken.None);
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(controller.Current.State == VaconConnectionState.Stale, "A failed refresh must make prior data stale.");
    Assert(controller.Current.ActualFrequencyHz == 13.00m, "The last reading should remain visible while stale.");
    DeleteTestDirectory(directory);
}

static async Task ControllerPreventsOverlappingPollsAsync()
{
    var client = new BlockingClient();
    var directory = CreateTestDirectory();
    using var controller = new VaconMonitorController(
        client,
        VaconMonitorOptions.SimulatedDefaults,
        new VaconMonitorLogger(directory));

    var first = controller.PollOnceAsync(CancellationToken.None);
    await client.WaitUntilCalledAsync();
    await controller.PollOnceAsync(CancellationToken.None);
    Assert(client.Calls == 1, "A second poll must not overlap an active read.");
    client.Complete();
    await first;
    DeleteTestDirectory(directory);
}

static Task CommunicationLogUsesSafeCategoriesAsync()
{
    var directory = CreateTestDirectory();
    var logger = new VaconMonitorLogger(directory);
    logger.LogFailure("192.168.30.50:502 token=not-allowed");
    var contents = File.ReadAllText(Path.Combine(directory, "vacon-monitor.log"));
    Assert(contents.Contains("category=read-error", StringComparison.Ordinal), "Unsafe categories must be normalized.");
    Assert(!contents.Contains("192.168", StringComparison.Ordinal), "Endpoint details must not be logged.");
    DeleteTestDirectory(directory);
    return Task.CompletedTask;
}

static Task CommandLogUsesSafeMetadataAsync()
{
    var directory = CreateTestDirectory();
    var logger = new VaconMonitorLogger(directory);
    var commandLogger = new VaconCommandLogger(logger, "vacon-100-flow", true);
    commandLogger.Log(new VaconControlAttempt(
        VaconControlCommand.SetFrequency,
        13m,
        true,
        "simulated-target-accepted",
        13m,
        true,
        null,
        2600), 13m);
    var contents = File.ReadAllText(Path.Combine(directory, "vacon-monitor.log"));
    Assert(contents.Contains("drive=vacon-100-flow", StringComparison.Ordinal), "The safe drive ID was not logged.");
    Assert(contents.Contains("mode=simulated", StringComparison.Ordinal), "The simulator mode was not logged.");
    Assert(contents.Contains("simulatedReferenceRaw=2600", StringComparison.Ordinal), "The normalized simulator reference was not logged.");
    Assert(!contents.Contains("192.168", StringComparison.Ordinal), "Command logs must not contain endpoint details.");
    DeleteTestDirectory(directory);
    return Task.CompletedTask;
}

static Task ModbusClientExposesNoWriteApiAsync()
{
    var unsafeMethods = typeof(VaconReadOnlyModbusClient)
        .GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static)
        .Where(method => !method.IsSpecialName)
        .Where(method => method.Name.Contains("write", StringComparison.OrdinalIgnoreCase)
            || method.Name.Contains("set", StringComparison.OrdinalIgnoreCase)
            || method.Name.Contains("control", StringComparison.OrdinalIgnoreCase))
        .Select(method => method.Name)
        .ToArray();
    Assert(unsafeMethods.Length == 0, "The Modbus client must expose no write or control API.");
    return Task.CompletedTask;
}

static byte[] BuildResponse(ushort transactionId, byte unitId, params ushort[] values)
{
    var result = new byte[9 + (values.Length * 2)];
    WriteUInt16(result, 0, transactionId);
    WriteUInt16(result, 2, 0);
    WriteUInt16(result, 4, (ushort)(3 + (values.Length * 2)));
    result[6] = unitId;
    result[7] = 0x04;
    result[8] = (byte)(values.Length * 2);
    for (var index = 0; index < values.Length; index++)
    {
        WriteUInt16(result, 9 + (index * 2), values[index]);
    }

    return result;
}

static byte[] BuildExceptionResponse(ushort transactionId, byte unitId)
{
    var result = new byte[9];
    WriteUInt16(result, 0, transactionId);
    WriteUInt16(result, 2, 0);
    WriteUInt16(result, 4, 3);
    result[6] = unitId;
    result[7] = 0x84;
    result[8] = 0x02;
    return result;
}

static ushort[] BuildProcessData(
    ushort statusWord = 0,
    ushort frequencyRaw = 1300,
    ushort speedRpm = 0,
    ushort currentRaw = 0,
    ushort faultCode = 0)
{
    var values = new ushort[VaconReadOnlyRegisterMap.InputRegisterCount];
    values[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.StatusWordPduAddress)] = statusWord;
    values[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.ActualFrequencyPduAddress)] = frequencyRaw;
    values[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.MotorSpeedPduAddress)] = speedRpm;
    values[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.MotorCurrentPduAddress)] = currentRaw;
    values[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.ActiveFaultPduAddress)] = faultCode;
    return values;
}

static ushort ReadUInt16(byte[] bytes, int offset) => (ushort)((bytes[offset] << 8) | bytes[offset + 1]);

static void WriteUInt16(byte[] bytes, int offset, ushort value)
{
    bytes[offset] = (byte)(value >> 8);
    bytes[offset + 1] = (byte)value;
}

static void AssertThrows(Action action, string expectedCategory)
{
    try
    {
        action();
    }
    catch (VaconReadException exception) when (exception.Category == expectedCategory)
    {
        return;
    }

    throw new InvalidOperationException($"Expected VaconReadException category={expectedCategory}.");
}

static void AssertThrowsType(Action action, Type expectedType)
{
    try
    {
        action();
    }
    catch (Exception exception) when (exception.GetType() == expectedType)
    {
        return;
    }

    throw new InvalidOperationException($"Expected {expectedType.Name}.");
}

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

static string CreateTestDirectory()
{
    var directory = Path.Combine(Path.GetTempPath(), $"fjellfisk-vacon-monitor-{Guid.NewGuid():N}");
    Directory.CreateDirectory(directory);
    return directory;
}

static void DeleteTestDirectory(string directory)
{
    if (Directory.Exists(directory))
    {
        Directory.Delete(directory, recursive: true);
    }
}

internal sealed class FixedResponseTransport : IVaconModbusTransport
{
    private readonly byte[] _response;

    public FixedResponseTransport(byte[] response)
    {
        _response = response;
    }

    public byte[]? Request { get; private set; }

    public Task<byte[]> ExchangeAsync(byte[] request, CancellationToken cancellationToken)
    {
        Request = request;
        var response = _response.ToArray();
        response[0] = request[0];
        response[1] = request[1];
        return Task.FromResult(response);
    }
}

internal sealed class SequenceClient : IVaconReadOnlyClient
{
    private readonly Queue<object> _results;

    public SequenceClient(params object[] results)
    {
        _results = new Queue<object>(results);
    }

    public Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken)
    {
        var next = _results.Dequeue();
        return next switch
        {
            VaconInputRegisterSnapshot snapshot => Task.FromResult(snapshot),
            Exception exception => Task.FromException<VaconInputRegisterSnapshot>(exception),
            _ => throw new InvalidOperationException(),
        };
    }
}

internal sealed class BlockingClient : IVaconReadOnlyClient
{
    private readonly TaskCompletionSource<VaconInputRegisterSnapshot> _completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly TaskCompletionSource<bool> _called = new(TaskCreationOptions.RunContinuationsAsynchronously);

    public int Calls { get; private set; }

    public Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken)
    {
        Calls++;
        _called.TrySetResult(true);
        return _completion.Task;
    }

    public Task WaitUntilCalledAsync() => _called.Task;

    public void Complete() => _completion.TrySetResult(new VaconInputRegisterSnapshot(DateTimeOffset.UtcNow, 13m));
}

internal sealed class TrackingControlGateway : IVaconControlGateway
{
    public int Calls { get; private set; }

    public bool IsSimulation => true;

    public bool ControlsEnabled => true;

    public VaconControlLimits Limits { get; } = new(0m, 50m, 0.5m);

    public string DisabledReason => string.Empty;

    public Task<VaconControlAttempt> ExecuteAsync(
        VaconControlCommand command,
        decimal? targetHz,
        CancellationToken cancellationToken)
    {
        Calls++;
        return Task.FromResult(new VaconControlAttempt(command, targetHz, true, "simulated-target-accepted"));
    }
}
