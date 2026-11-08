using System.Reflection;
using System.Drawing;
using System.Windows.Forms;
using Fjellfisk.VaconMonitor;

var tests = new (string Name, Func<Task> Run)[]
{
    ("Live-only startup rejects command-line modes", LiveOnlyOptionsRejectCommandLineModesAsync),
    ("FC04 request targets the documented process-data block", ModbusRequestTargetsProcessDataBlockAsync),
    ("FC04 response maps output frequency and raw process data", ModbusResponseMapsFrequencyAndRawDataAsync),
    ("Status word is decoded from documented bits", StatusWordIsDecodedAsync),
    ("Active fault codes remain unverified descriptions", ActiveFaultCodeIsUnverifiedAsync),
    ("Motor current remains raw until scaling is verified", MotorCurrentRemainsRawAsync),
    ("Invalid Modbus responses are rejected", InvalidResponsesAreRejectedAsync),
    ("Controller marks failed data stale without discarding the last value", ControllerMarksFailedDataStaleAsync),
    ("Controller prevents overlapping FC04 reads", ControllerPreventsOverlappingPollsAsync),
    ("Manual connect and disconnect update monitor state", ManualConnectionStateAsync),
    ("Communication logs contain safe metadata", CommunicationLogUsesSafeFieldsAsync),
    ("Drive profiles persist locally and retain the selection", MultipleDriveProfilesPersistAsync),
    ("Drive profiles reject invalid network metadata", ConnectionProfilesRejectUnsafeMetadataAsync),
    ("Configured drive data feeds the FC04 request", ConfiguredDriveFeedsReadOnlyRequestAsync),
    ("Pending target starts from a fresh physical reading", PendingTargetInitializesFromFreshReadingAsync),
    ("Pending target moves in exact whole-Hz steps", PendingTargetMovesInWholeHzStepsAsync),
    ("Unapproved limits never permit target adjustment", UnapprovedLimitsKeepTargetReadOnlyAsync),
    ("Compact control-panel dimensions remain fixed", CompactControlPanelDimensionsAsync),
    ("Primary WinForms layout fits at supported display scaling", PrimaryWinFormsLayoutFitsAtSupportedDisplayScalingAsync),
    ("All physical control commands remain blocked", LiveControlRemainsBlockedAsync),
    ("Control preparation remains blocked before commissioning", CommissioningBoundaryRemainsBlockedAsync),
    ("Modbus client exposes no write or control API", ModbusClientExposesNoWriteApiAsync),
    ("Modbus transport exposes no write or control API", ModbusTransportExposesNoWriteApiAsync),
    ("Production assembly contains no simulator mode", ProductionAssemblyContainsNoSimulatorTypesAsync),
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

Console.WriteLine($"VACON Control tests: {tests.Length - failures.Count}/{tests.Length} passed");
return failures.Count == 0 ? 0 : 1;

static Task LiveOnlyOptionsRejectCommandLineModesAsync()
{
    Assert(VaconMonitorOptions.Parse(Array.Empty<string>()) == VaconMonitorOptions.LiveDefaults, "Default startup must use live monitoring options.");
    AssertThrows<ArgumentException>(() => VaconMonitorOptions.Parse(new[] { "--live" }), "Command-line modes must not enable a separate mode.");
    return Task.CompletedTask;
}

static Task ModbusRequestTargetsProcessDataBlockAsync()
{
    var request = VaconReadOnlyModbusClient.BuildReadInputRegisterRequest(0x1234, 255);
    Assert(request.Length == 12, "FC04 request length was unexpected.");
    Assert(request[6] == 255, "The documented Unit ID must be used.");
    Assert(request[7] == 0x04, "Only Modbus FC04 may be sent.");
    Assert(ReadUInt16(request, 8) == 2100, "Documented register 2101 must use PDU address 2100.");
    Assert(ReadUInt16(request, 10) == 11, "The FC04 request must end at documented register 2111.");
    return Task.CompletedTask;
}

static async Task ModbusResponseMapsFrequencyAndRawDataAsync()
{
    var transport = new FixedResponseTransport(CreateProcessDataResponse);
    var client = new VaconReadOnlyModbusClient(VaconMonitorOptions.LiveDefaults, transport);
    var result = await client.ReadAsync(CancellationToken.None);
    Assert(result.ActualFrequencyHz == 13.00m, "Register 2104 must be scaled by 100 to 13.00 Hz.");
    Assert(result.MotorSpeedRaw == 780, "Register 2105 must stay raw until RPM scaling is verified.");
    Assert(result.MotorCurrentRaw == 153, "Register 2106 must stay raw until current scaling is verified.");
    Assert(result.MotorCurrentAmperes is null && !result.MotorCurrentScaleVerified, "Current must not be presented as amperes without verification.");
    Assert(result.ActiveFault is null, "Zero active-fault register must not create a fault.");
}

static Task StatusWordIsDecodedAsync()
{
    var status = VaconStatusWord.FromRaw(35);
    Assert(status.Ready && status.Running && status.AtReference, "Status word 35 must show ready, running, and at reference.");
    Assert(!status.Fault && !status.Alarm, "Status word 35 must not invent a fault or alarm.");
    Assert(status.DriveStatus == VaconDriveStatus.Running, "Running bit must map to the running status.");
    return Task.CompletedTask;
}

static Task ActiveFaultCodeIsUnverifiedAsync()
{
    var result = VaconProcessDataMapper.Map(CreateRegisters(statusWord: 0x0008, faultCode: 71), DateTimeOffset.UtcNow);
    Assert(result.ActiveFault?.Code == "71", "The raw fault code must be shown.");
    Assert(result.ActiveFault?.Description.Contains("ikke verifisert", StringComparison.OrdinalIgnoreCase) == true, "The app must not invent a fault description.");
    return Task.CompletedTask;
}

static Task MotorCurrentRemainsRawAsync()
{
    var result = VaconProcessDataMapper.Map(CreateRegisters(motorCurrentRaw: 112), DateTimeOffset.UtcNow);
    Assert(result.MotorCurrentRaw == 112, "The raw current register was lost.");
    Assert(result.MotorCurrentAmperes is null, "Raw motor current must not be labelled as amperes.");
    Assert(!result.MotorCurrentScaleVerified, "Current scale must remain unverified.");
    return Task.CompletedTask;
}

static Task InvalidResponsesAreRejectedAsync()
{
    AssertThrows<VaconReadException>(() => VaconReadOnlyModbusClient.ParseReadInputRegisterResponse(new byte[8], 1, 255), "An undersized response must fail safely.");
    var badResponse = CreateProcessDataResponse(new byte[] { 0, 1, 0, 0, 0, 6, 255, 4, 8, 52, 0, 11 });
    badResponse[7] = 0x03;
    AssertThrows<VaconReadException>(() => VaconReadOnlyModbusClient.ParseReadInputRegisterResponse(badResponse, 1, 255), "A non-FC04 response must fail safely.");
    return Task.CompletedTask;
}

static async Task ControllerMarksFailedDataStaleAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        var now = DateTimeOffset.UtcNow;
        var clock = now;
        var client = new SequenceClient(
            Task.FromResult(new VaconInputRegisterSnapshot(now, 13m)),
            Task.FromException<VaconInputRegisterSnapshot>(new VaconReadException("timeout")));
        using var controller = new VaconMonitorController(client, VaconMonitorOptions.LiveDefaults with { StaleAfter = TimeSpan.FromMinutes(1) }, new VaconMonitorLogger(directory), utcNow: () => clock);
        await controller.PollOnceAsync(CancellationToken.None);
        clock = clock.AddSeconds(10);
        await controller.PollOnceAsync(CancellationToken.None);
        Assert(controller.Current.State == VaconConnectionState.Stale, "A temporary failed read must mark last data stale.");
        Assert(controller.Current.ActualFrequencyHz == 13m, "The last valid value must remain visible as stale data.");
        Assert(controller.Current.FailureCategory == "timeout", "The safe error category was not preserved.");
    }
    finally
    {
        DeleteTestDirectory(directory);
    }
}

static async Task ControllerPreventsOverlappingPollsAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        var client = new BlockingClient();
        using var controller = new VaconMonitorController(client, VaconMonitorOptions.LiveDefaults, new VaconMonitorLogger(directory));
        var first = controller.PollOnceAsync(CancellationToken.None);
        await client.Started.Task;
        var second = controller.PollOnceAsync(CancellationToken.None);
        await Task.Delay(25);
        Assert(client.ReadCalls == 1, "A second poll started a parallel FC04 call.");
        client.Complete(new VaconInputRegisterSnapshot(DateTimeOffset.UtcNow, 13m));
        await Task.WhenAll(first, second);
    }
    finally
    {
        DeleteTestDirectory(directory);
    }
}

static Task ManualConnectionStateAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        using var controller = new VaconMonitorController(new SequenceClient(), VaconMonitorOptions.LiveDefaults, new VaconMonitorLogger(directory));
        controller.BeginConnection();
        Assert(controller.Current.State == VaconConnectionState.Connecting, "Manual connect must show connecting state before a read.");
        controller.Disconnect();
        Assert(controller.Current.State == VaconConnectionState.Disconnected, "Manual disconnect must stop active monitoring state.");
    }
    finally
    {
        DeleteTestDirectory(directory);
    }

    return Task.CompletedTask;
}

static Task CommunicationLogUsesSafeFieldsAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        var logger = new VaconMonitorLogger(directory);
        logger.LogStartup();
        logger.LogConnectionState(VaconConnectionState.Unavailable, "timeout");
        logger.LogTelemetry(new VaconInputRegisterSnapshot(DateTimeOffset.UtcNow, 13m, MotorSpeedRaw: 780, MotorCurrentRaw: 153), "drive/unsafe name");
        var log = File.ReadAllText(Path.Combine(directory, "vacon-monitor.log"));
        Assert(log.Contains("mode=live-read-only", StringComparison.Ordinal), "The log must mark the live read-only mode.");
        Assert(log.Contains("drive=driveunsafename", StringComparison.Ordinal), "Drive identifiers must be sanitised before logging.");
        Assert(!log.Contains("192.168.30.50", StringComparison.Ordinal), "Telemetry logs must not contain network configuration.");
    }
    finally
    {
        DeleteTestDirectory(directory);
    }

    return Task.CompletedTask;
}

static Task MultipleDriveProfilesPersistAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        var store = new VaconDriveConfigurationStore(directory);
        var secondary = VaconDriveConfiguration.Default with { Id = "vacon-secondary", DisplayName = "Sekundær VACON", Host = "192.168.30.51", Dns = "vacon-secondary.local" };
        store.Save(new VaconDriveConfigurationDocument(secondary.Id, new[] { VaconDriveConfiguration.Default, secondary }));
        var loaded = store.Load();
        Assert(loaded.Drives.Count == 2, "Multiple drives were not persisted.");
        Assert(loaded.SelectedDrive.Id == secondary.Id, "The selected drive was not retained.");
        Assert(loaded.SelectedDrive.Dns == "vacon-secondary.local", "DNS metadata was not retained.");
    }
    finally
    {
        DeleteTestDirectory(directory);
    }

    return Task.CompletedTask;
}

static Task ConnectionProfilesRejectUnsafeMetadataAsync()
{
    AssertThrows<ArgumentException>((VaconDriveConfiguration.Default with { Host = "not-an-ip" }).Validate, "A connection profile must require an IPv4 host.");
    AssertThrows<ArgumentException>((VaconDriveConfiguration.Default with { Dns = "not a valid hostname" }).Validate, "Invalid optional DNS metadata must be rejected.");
    return Task.CompletedTask;
}

static async Task ConfiguredDriveFeedsReadOnlyRequestAsync()
{
    var drive = VaconDriveConfiguration.Default with { Id = "vacon-test", Host = "192.168.30.51", UnitId = 42 };
    var transport = new FixedResponseTransport(CreateProcessDataResponse);
    var client = new VaconReadOnlyModbusClient(VaconMonitorOptions.LiveDefaults.ForDrive(drive), transport);
    await client.ReadAsync(CancellationToken.None);
    Assert(transport.LastRequest is not null && transport.LastRequest[6] == 42, "Configured Unit ID did not feed the FC04 request.");
    Assert(transport.LastRequest?[7] == 0x04, "Configured connections must remain FC04-only.");
}

static Task PendingTargetInitializesFromFreshReadingAsync()
{
    var target = new VaconPendingFrequencyTarget(8m, 20m, limitsApproved: true);
    Assert(target.ValueHz is null, "A target must not exist before a fresh read.");
    Assert(target.TryInitializeFromFreshActual(13.00m), "A fresh actual frequency should initialise the target.");
    Assert(target.ValueHz == 13m, "The target must use the nearest whole Hz, not a hardcoded default.");
    target.Clear();
    Assert(target.ValueHz is null, "Disconnecting must cancel the pending target.");
    return Task.CompletedTask;
}

static Task PendingTargetMovesInWholeHzStepsAsync()
{
    var target = new VaconPendingFrequencyTarget(8m, 20m, limitsApproved: true);
    target.TryInitializeFromFreshActual(13.49m);
    Assert(target.ValueHz == 13m, "A 13.49 Hz measurement must initialise to 13 Hz.");
    Assert(target.MoveByOneHz(1) && target.ValueHz == 14m, "Plus must change only the pending target by exactly 1 Hz.");
    Assert(target.MoveByOneHz(1) && target.ValueHz == 15m, "Each plus press must add exactly 1 Hz.");
    Assert(target.MoveByOneHz(-1) && target.ValueHz == 14m, "Minus must change only the pending target by exactly 1 Hz.");
    Assert(VaconDriveConfiguration.Default.ToControlLimits("test").DefaultStepHz == 1m, "The control model must expose only a 1 Hz default step.");
    return Task.CompletedTask;
}

static Task UnapprovedLimitsKeepTargetReadOnlyAsync()
{
    var target = new VaconPendingFrequencyTarget(8m, 20m, limitsApproved: false);
    Assert(target.TryInitializeFromFreshActual(13m), "A fresh actual frequency may be displayed even when limits are not approved.");
    Assert(target.ValueHz == 13m, "The displayed pending target must come from the actual reading.");
    Assert(!target.CanAdjust, "Unapproved limits must prevent target adjustment.");
    Assert(!target.MoveByOneHz(1) && target.ValueHz == 13m, "A blocked adjustment must not mutate the pending target.");
    return Task.CompletedTask;
}

static Task CompactControlPanelDimensionsAsync()
{
    Assert(VaconUiLayout.DefaultWindowWidth == 700 && VaconUiLayout.DefaultWindowHeight == 700,
        "The compact default window must be 700 by 700 pixels.");
    Assert(VaconUiLayout.MinimumWindowWidth >= 700 && VaconUiLayout.MinimumWindowHeight >= 620,
        "The compact layout must keep a usable minimum size.");
    return Task.CompletedTask;
}

static Task PrimaryWinFormsLayoutFitsAtSupportedDisplayScalingAsync() => RunOnSta(() =>
{
    Application.EnableVisualStyles();

    foreach (var scale in new[] { 1F, 1.25F, 1.5F })
    {
        var directory = CreateTestDirectory();
        try
        {
            var drive = VaconDriveConfiguration.Default with
            {
                MinimumFrequencyHz = 8m,
                MaximumFrequencyHz = 20m,
                FrequencyLimitsApproved = true,
            };
            var options = VaconMonitorOptions.LiveDefaults.ForDrive(drive);
            using var controller = new VaconMonitorController(new SequenceClient(), options, new VaconMonitorLogger(directory));
            using var form = new VaconControlForm(
                controller,
                options,
                new VaconDriveConfigurationStore(directory),
                VaconDriveConfigurationStore.CreateDefault());

            form.StartPosition = FormStartPosition.Manual;
            form.Location = new Point(-32000, -32000);
            form.Show();
            if (scale != 1F)
            {
                form.Scale(new SizeF(scale, scale));
            }

            form.PerformLayout();
            Application.DoEvents();

            var page = FindControl<TableLayoutPanel>(form, "MainPage");
            var connection = FindControl<Label>(form, "ConnectionStatusValue");
            var motor = FindControl<Label>(form, "MotorStatusValue");
            var fault = FindControl<Label>(form, "ActiveFaultValue");
            var actual = FindControl<Label>(form, "ActualFrequencyValue");
            var decrease = FindControl<Button>(form, "DecreaseFrequencyButton");
            var pending = FindControl<Label>(form, "PendingFrequencyValue");
            var increase = FindControl<Button>(form, "IncreaseFrequencyButton");
            var apply = FindControl<Button>(form, "ApplyFrequencyButton");

            Assert(!page.HorizontalScroll.Visible, $"The main page showed a horizontal scrollbar at {scale * 100:0}% scaling.");
            AssertIsVisibleInsideForm(form, connection, $"Connection status at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, motor, $"Motor status at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, fault, $"Active fault at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, actual, $"Actual frequency at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, decrease, $"Decrease button at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, pending, $"Pending target at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, increase, $"Increase button at {scale * 100:0}% scaling");
            AssertIsVisibleInsideForm(form, apply, $"Apply button at {scale * 100:0}% scaling");
            Assert(decrease.Right <= pending.Left && pending.Right <= increase.Left,
                $"The three frequency controls did not remain in order at {scale * 100:0}% scaling.");
            Assert(apply.Top >= decrease.Bottom, $"Apply Frequency was not below the target row at {scale * 100:0}% scaling.");
            form.Close();
        }
        finally
        {
            DeleteTestDirectory(directory);
        }
    }
});

static async Task LiveControlRemainsBlockedAsync()
{
    var gateway = new BlockedLiveVaconControlGateway();
    foreach (var command in Enum.GetValues<VaconControlCommand>())
    {
        var result = await gateway.ExecuteAsync(command, command == VaconControlCommand.SetFrequency ? 13m : null, CancellationToken.None);
        Assert(!result.Accepted, $"{command} must not be accepted before commissioning.");
        Assert(result.ResultCode == "control-commissioning-required", "Blocked controls must state the commissioning boundary.");
    }
}

static async Task CommissioningBoundaryRemainsBlockedAsync()
{
    var directory = CreateTestDirectory();
    try
    {
        using var controller = new VaconMonitorController(new SequenceClient(), VaconMonitorOptions.LiveDefaults, new VaconMonitorLogger(directory));
        var result = await controller.ApplyTargetFrequencyAsync(13m, true, CancellationToken.None);
        Assert(!result.Accepted, "Even a confirmed target must remain blocked.");
        Assert(result.ResultCode == "control-commissioning-required", "No hidden control path may bypass commissioning.");
    }
    finally
    {
        DeleteTestDirectory(directory);
    }
}

static Task ModbusClientExposesNoWriteApiAsync()
{
    AssertNoWriteOrControlMembers(typeof(VaconReadOnlyModbusClient));
    AssertNoWriteOrControlMembers(typeof(IVaconReadOnlyClient));
    return Task.CompletedTask;
}

static Task ModbusTransportExposesNoWriteApiAsync()
{
    AssertNoWriteOrControlMembers(typeof(TcpVaconModbusTransport));
    AssertNoWriteOrControlMembers(typeof(IVaconModbusTransport));
    return Task.CompletedTask;
}

static Task ProductionAssemblyContainsNoSimulatorTypesAsync()
{
    var simulatorTypes = typeof(VaconReadOnlyModbusClient).Assembly.GetTypes().Where(type => type.Name.Contains("Simulat", StringComparison.OrdinalIgnoreCase)).Select(type => type.FullName).ToArray();
    Assert(simulatorTypes.Length == 0, "The production executable must not contain simulator types.");
    return Task.CompletedTask;
}

static byte[] CreateProcessDataResponse(byte[] request) => CreateProcessDataResponseFromRegisters(request, CreateRegisters());

static byte[] CreateProcessDataResponseFromRegisters(byte[] request, ushort[] registers)
{
    var response = new byte[9 + (registers.Length * 2)];
    response[0] = request[0]; response[1] = request[1];
    var length = (ushort)(response.Length - 6);
    response[4] = (byte)(length >> 8); response[5] = (byte)length;
    response[6] = request[6]; response[7] = 0x04; response[8] = (byte)(registers.Length * 2);
    for (var index = 0; index < registers.Length; index++)
    {
        response[9 + (index * 2)] = (byte)(registers[index] >> 8);
        response[10 + (index * 2)] = (byte)registers[index];
    }

    return response;
}

static ushort[] CreateRegisters(ushort statusWord = 35, ushort actualFrequencyRaw = 1300, ushort motorSpeedRaw = 780, ushort motorCurrentRaw = 153, ushort faultCode = 0)
{
    var registers = new ushort[VaconReadOnlyRegisterMap.InputRegisterCount];
    registers[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.StatusWordPduAddress)] = statusWord;
    registers[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.ActualFrequencyPduAddress)] = actualFrequencyRaw;
    registers[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.MotorSpeedPduAddress)] = motorSpeedRaw;
    registers[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.MotorCurrentPduAddress)] = motorCurrentRaw;
    registers[VaconReadOnlyRegisterMap.IndexForPduAddress(VaconReadOnlyRegisterMap.ActiveFaultPduAddress)] = faultCode;
    return registers;
}

static ushort ReadUInt16(byte[] values, int offset) => (ushort)((values[offset] << 8) | values[offset + 1]);

static string CreateTestDirectory()
{
    var directory = Path.Combine(Path.GetTempPath(), "FjellfiskVaconTests", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(directory);
    return directory;
}

static void DeleteTestDirectory(string directory)
{
    if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
}

static void AssertNoWriteOrControlMembers(Type type)
{
    var prohibited = type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
        .Where(method => method.Name.Contains("write", StringComparison.OrdinalIgnoreCase) || method.Name.Contains("control", StringComparison.OrdinalIgnoreCase) || method.Name.Contains("start", StringComparison.OrdinalIgnoreCase) || method.Name.Contains("stop", StringComparison.OrdinalIgnoreCase))
        .Select(method => method.Name).ToArray();
    Assert(prohibited.Length == 0, $"{type.Name} exposes prohibited public API: {string.Join(", ", prohibited)}.");
}

static void AssertThrows<TException>(Action action, string message) where TException : Exception
{
    try { action(); } catch (TException) { return; }
    throw new InvalidOperationException(message);
}

static void Assert(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

static Task RunOnSta(Action action)
{
    var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
    var thread = new Thread(() =>
    {
        try
        {
            action();
            completion.SetResult();
        }
        catch (Exception exception)
        {
            completion.SetException(exception);
        }
    });
    thread.SetApartmentState(ApartmentState.STA);
    thread.Start();
    return completion.Task;
}

static TControl FindControl<TControl>(Control root, string name) where TControl : Control
{
    var control = root.Controls.Find(name, searchAllChildren: true).OfType<TControl>().SingleOrDefault();
    if (control is null)
    {
        throw new InvalidOperationException($"Required {typeof(TControl).Name} '{name}' was not found.");
    }

    return control;
}

static void AssertIsVisibleInsideForm(Form form, Control control, string description)
{
    var topLeft = form.PointToClient(control.PointToScreen(Point.Empty));
    var bounds = new Rectangle(topLeft, control.Size);
    Assert(control.Visible && bounds.Left >= 0 && bounds.Right <= form.ClientSize.Width && bounds.Top >= 0 && bounds.Bottom <= form.ClientSize.Height,
        $"{description} was outside the visible 700 px window.");
}

sealed class FixedResponseTransport : IVaconModbusTransport
{
    private readonly Func<byte[], byte[]> _responseFactory;
    public FixedResponseTransport(Func<byte[], byte[]> responseFactory) => _responseFactory = responseFactory;
    public byte[]? LastRequest { get; private set; }
    public Task<byte[]> ExchangeAsync(byte[] request, CancellationToken cancellationToken)
    {
        LastRequest = request.ToArray();
        return Task.FromResult(_responseFactory(request));
    }
}

sealed class SequenceClient : IVaconReadOnlyClient
{
    private readonly Queue<Task<VaconInputRegisterSnapshot>> _results;
    public SequenceClient(params Task<VaconInputRegisterSnapshot>[] results) => _results = new Queue<Task<VaconInputRegisterSnapshot>>(results);
    public Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken) => _results.Count > 0 ? _results.Dequeue() : Task.FromResult(new VaconInputRegisterSnapshot(DateTimeOffset.UtcNow, 0m));
}

sealed class BlockingClient : IVaconReadOnlyClient
{
    private readonly TaskCompletionSource<VaconInputRegisterSnapshot> _completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
    public TaskCompletionSource<bool> Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    public int ReadCalls { get; private set; }
    public Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken)
    {
        ReadCalls++;
        Started.TrySetResult(true);
        return _completion.Task;
    }

    public void Complete(VaconInputRegisterSnapshot result) => _completion.TrySetResult(result);
}
