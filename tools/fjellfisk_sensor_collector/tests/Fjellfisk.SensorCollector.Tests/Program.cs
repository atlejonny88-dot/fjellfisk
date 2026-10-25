using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Net;
using System.Text.Json;
using Fjellfisk.SensorCollector;

var tests = new (string Name, Func<Task> Run)[]
{
    ("Collector identity persists without a plaintext secret", CollectorIdentityPersistsAsync),
    ("Copying only the executable cannot reuse identity", CopiedExecutableGetsNewIdentityAsync),
    ("Allowlist blocks unknown sensors", AllowlistBlocksUnknownSensorsAsync),
    ("OxyGuard reader rejects modified allowlist entries", OxyGuardReaderRejectsModifiedSensorsAsync),
    ("Diagnostics stops immediately after its first COM error", DiagnosticsStopsAfterComErrorAsync),
    ("Diagnostics uses only the allowlisted temperature sensor", DiagnosticsUsesTemperatureOnlyAsync),
    ("Inventory reads all known Pacific candidates sequentially", InventoryReadsKnownPacificSensorsAsync),
    ("Inventory continues after a missing path", InventoryContinuesAfterMissingPathAsync),
    ("Inventory records a partial sensor without stopping", InventoryRecordsPartialSensorAsync),
    ("Inventory classifies COM exceptions", InventoryClassifiesComExceptionsAsync),
    ("Inventory records VIGO ErrorCode failures", InventoryRecordsVigoErrorCodeAsync),
    ("Inventory records timeouts", InventoryRecordsTimeoutsAsync),
    ("Inventory persists machine-readable diagnostic JSON", InventoryPersistsJsonAsync),
    ("Inventory preserves Ppm and saturation field mapping", InventoryPreservesOxygenMappingAsync),
    ("Inventory exposes no VIGO write surface or uploader", InventoryStaysReadOnlyAsync),
    ("DOM inventory reads all confirmed channels with exact paths", DomInventoryReadsAllChannelsAsync),
    ("DOM inventory continues after COM, timeout, and VIGO errors", DomInventoryHandlesPerChannelFailuresAsync),
    ("DOM inventory persists the expected diagnostic JSON", DomInventoryPersistsJsonAsync),
    ("DOM and Pacific inventories retain separate path families", DomAndPacificPathsStaySeparateAsync),
    ("Production discovery supports dynamic Pacific devices and probes", DynamicPacificDiscoveryAsync),
    ("Production discovery supports variable DOM meters and channels", DynamicDomDiscoveryAsync),
    ("Production discovery supports Pacific-only DOM-only and mixed sites", ProductionDiscoverySupportsSourceCombinationsAsync),
    ("Production discovery isolates a failed configuration source", ProductionDiscoveryIsolatesSourceFailuresAsync),
    ("Production runtime allowlist accepts only discovered sensors", RuntimeAllowlistUsesDiscoveredSensorsAsync),
    ("Production sensor IDs are stable regardless of discovery order", ProductionSensorIdsAreStableAsync),
    ("Production runtime isolates individual sensor failures", ProductionRuntimeIsolatesSensorFailuresAsync),
    ("Production read-once traverses only dynamically discovered allowlist sensors", ProductionReadOnceUsesDynamicAllowlistAsync),
    ("Production read-once supports Pacific-only DOM-only and mixed batches", ProductionReadOnceSupportsSourceCombinationsAsync),
    ("Production read-once handles an empty discovery without COM reads", ProductionReadOnceHandlesEmptyDiscoveryAsync),
    ("Production read-once preserves normalized Pacific and DOM field mappings", ProductionReadOncePreservesFieldMappingsAsync),
    ("Production read-once marks a partial measurement failure as degraded", ProductionReadOnceHandlesPartialMeasurementFailureAsync),
    ("Production read-once continues after a complete COM sensor failure", ProductionReadOnceContinuesAfterComFailureAsync),
    ("Production read-once continues after a timeout", ProductionReadOnceContinuesAfterTimeoutAsync),
    ("Production read-once writes a mapping-free local JSON batch", ProductionReadOnceWritesLocalJsonAsync),
    ("Production read-once has no uploader dependency", ProductionReadOnceHasNoUploaderDependencyAsync),
    ("Production read-once traverses a large dynamic inventory without a fixed limit", ProductionReadOnceTraversesLargeInventoryAsync),
    ("Production discovery represents large inventories without a fixed limit", ProductionDiscoveryHandlesLargeInventoryAsync),
    ("Production CLI exposes no internal service commands", ProductionCliIsRestrictedAsync),
    ("Production storage preserves a migrated identity", ProductionStorageMigratesIdentityAsync),
    ("Production sensor sources expose no VIGO write operations", ProductionSensorSourcesStayReadOnlyAsync),
    ("Pairing registers once and protects its device credential", PairingRegistersAndProtectsCredentialAsync),
    ("Pairing reuses the persisted backend identity", PairingReusesPersistedIdentityAsync),
    ("Pairing rotates an expired code without persisting it", PairingRotatesExpiredCodeAsync),
    ("Closing pairing popup waits until the next code rotation", PairingPopupCloseAndReopenAsync),
    ("Pairing keeps at most one popup active", PairingKeepsOnePopupAsync),
    ("Pairing retries after backend unavailability", PairingRetriesAfterBackendUnavailableAsync),
    ("Paired restart does not display a pairing popup", PairedRestartDoesNotShowPopupAsync),
    ("Revoked Collector can resume only after backend reset", RevokedCollectorResumesAfterBackendResetAsync),
    ("Pairing handles wrong device credentials without exposing them", PairingHandlesWrongCredentialAsync),
    ("Pairing logs contain no code or device credential", PairingLogsAreSecretFreeAsync),
    ("Pairing URL permits only HTTPS or explicit loopback emulator", PairingBackendConfigurationIsSafeAsync),
    ("Pairing HTTP client follows the backend contract", PairingHttpClientUsesBackendContractAsync),
    ("Pairing state machine has no Vigo reader dependency", PairingStateDoesNotDependOnVigoAsync),
    ("Payload uses normalized fields", PayloadUsesNormalizedFieldsAsync),
    ("Normalizer validates scalar readings", NormalizerValidatesScalarReadingsAsync),
    ("Backoff follows safe schedule", BackoffFollowsSafeScheduleAsync),
    ("Buffer retention removes old and oversize data", BufferRetentionAsync),
    ("Uploader failure preserves buffer and resends its measurement id", UploaderRetryAsync),
    ("Buffered measurements resend oldest first", BufferResendsOldestFirstAsync),
    ("Collector publishes live mock snapshots", CollectorPublishesLiveSnapshotsAsync),
    ("One pilot cycle completes exactly one sensor round", OnePilotCycleStopsAfterOneRoundAsync),
    ("Public API has no VIGO write methods", PublicApiHasNoVigoWriteMethodsAsync),
    ("Minimum polling interval is enforced", MinimumPollingIntervalAsync),
    ("Single instance lock blocks a second collector", SingleInstanceLockAsync),
    ("Service host delays and reuses CollectorCore", ServiceHostUsesCollectorCoreAsync),
    ("Enrollment supports pending and connected states", EnrollmentStatesAsync),
    ("Revoked enrollment prevents uploads", RevokedEnrollmentStopsUploadAsync),
    ("HTTPS uploader is TLS-only and uses measurement idempotency", HttpsUploaderUsesIdempotencyAsync),
    ("Status output contains operational state without credentials", StatusOutputAsync),
    ("Soak test stops at duration and writes a local summary", SoakTestStopsAtDurationAsync),
    ("Soak statistics count failed cycles, timeouts, and COM errors", SoakStatisticsCountFailuresAsync),
    ("Soak test handles Ctrl+C cancellation gracefully", SoakTestHandlesCancellationAsync),
    ("Soak test log rotation keeps local disk use bounded", SoakLogRotationAsync),
    ("Soak test uses a local-only uploader and no service host", SoakTestStaysLocalOnlyAsync),
};

var testList = tests.ToList();
if (string.Equals(Environment.GetEnvironmentVariable("FJELLFISK_COLLECTOR_E2E"), "1", StringComparison.Ordinal))
{
    testList.Add(("Collector pairing completes against the local Firebase Emulator", PairingCoordinatorEmulatorE2EAsync));
}

if (string.Equals(Environment.GetEnvironmentVariable("FJELLFISK_COLLECTOR_PROCESS_E2E"), "1", StringComparison.Ordinal))
{
    testList.Add(("Collector pairing window closes after local emulator pairing", PairingWindowEmulatorE2EAsync));
}

var failures = new List<string>();
foreach (var test in testList)
{
    try
    {
        await test.Run();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (Exception exception)
    {
        failures.Add($"{test.Name}: {exception.Message}");
        Console.Error.WriteLine($"FAIL {test.Name}: {exception}");
    }
}

Console.WriteLine($"{testList.Count - failures.Count}/{testList.Count} tests passed.");
return failures.Count == 0 ? 0 : 1;

static Task CollectorIdentityPersistsAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var store = new CollectorIdentityStore(directory, clock);
    var first = store.LoadOrCreate();
    var rawIdentity = File.ReadAllText(store.IdentityPath);
    var second = new CollectorIdentityStore(directory, clock).LoadOrCreate();

    Assert(first.CollectorDeviceId == second.CollectorDeviceId, "Identity changed after restart.");
    Assert(rawIdentity.Contains("ProtectedDeviceSecret", StringComparison.Ordinal), "Protected secret field missing.");
    Assert(!rawIdentity.Contains("\"DeviceSecret\":", StringComparison.Ordinal), "Plaintext secret field was written.");
    Assert(!rawIdentity.Contains("secret-", StringComparison.OrdinalIgnoreCase), "Plaintext secret marker was written.");

    Directory.Delete(directory, recursive: true);
    return Task.CompletedTask;
}

static Task CopiedExecutableGetsNewIdentityAsync()
{
    var firstDirectory = CreateTemporaryDirectory();
    var secondDirectory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var first = new CollectorIdentityStore(firstDirectory, clock).LoadOrCreate();
    var second = new CollectorIdentityStore(secondDirectory, clock).LoadOrCreate();

    Assert(first.CollectorDeviceId != second.CollectorDeviceId, "A new local data directory reused identity.");
    Directory.Delete(firstDirectory, recursive: true);
    Directory.Delete(secondDirectory, recursive: true);
    return Task.CompletedTask;
}

static Task AllowlistBlocksUnknownSensorsAsync()
{
    ExpectThrows<InvalidOperationException>(() => SensorAllowlist.GetRequired("arbitrary_live_path"));
    Assert(SensorAllowlist.Pacific01.Count == 3, "Expected exactly three initial sensors.");
    return Task.CompletedTask;
}

static Task OxyGuardReaderRejectsModifiedSensorsAsync()
{
    var allowed = SensorAllowlist.Pacific01[0];
    var modified = allowed with { PhysId = "Commander5:outside-the-allowlist.Value" };
    var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        CompiledSensorAllowlist.Instance);

    ExpectThrows<InvalidOperationException>(() =>
        reader.ReadAsync(modified, CancellationToken.None).GetAwaiter().GetResult());
    return Task.CompletedTask;
}

static Task DiagnosticsStopsAfterComErrorAsync()
{
    var logger = new CapturingLogger();
    var session = new FakeDiagnosticSession
    {
        SelectException = new COMException("Unknown name", unchecked((int)0x80020006)),
    };

    var result = new VigoDiagnosticsRunner(logger).Run(session);

    Assert(!result.Succeeded, "Diagnostics unexpectedly succeeded.");
    Assert(result.FailedStage == "set_physid_property", "Diagnostics did not identify the failed stage.");
    Assert(result.HResult == unchecked((int)0x80020006), "Diagnostics did not preserve the COM HRESULT.");
    Assert(session.CreateCalls == 1, "Diagnostics retried COM creation.");
    Assert(session.SelectCalls == 1, "Diagnostics retried the failed stage.");
    Assert(session.ValueCalls == 0 && session.ErrorCodeCalls == 0, "Diagnostics continued after the first COM error.");
    Assert(logger.Messages.Count(message => message.Contains("stage=set_physid_property", StringComparison.Ordinal)) == 2,
        "Diagnostics did not log exactly one start/failure pair for the failed stage.");
    return Task.CompletedTask;
}

static Task DiagnosticsUsesTemperatureOnlyAsync()
{
    var session = new FakeDiagnosticSession();
    var result = new VigoDiagnosticsRunner(new TestLogger()).Run(session);
    var temperature = SensorAllowlist.GetRequired("pacific01_temperature").PhysId;

    Assert(result.Succeeded, "Temperature diagnostics should succeed with a healthy fake session.");
    Assert(session.SelectedPhysIds.SequenceEqual(new[] { temperature }), "Diagnostics accessed a sensor other than temperature.");
    Assert(session.ValueCalls == 1 && session.ErrorCodeCalls == 1, "Diagnostics did not perform exactly one read sequence.");
    return Task.CompletedTask;
}

static async Task InventoryReadsKnownPacificSensorsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    var candidates = VigoInventorySources.Pacific.Candidates;
    var report = await new VigoInventoryRunner(reader, clock).RunAsync(
        candidates,
        CancellationToken.None);

    Assert(report.Mode == "read-only" && report.Source == "VIGO.PRO", "Inventory metadata is incorrect.");
    Assert(report.Devices.Count == 4, "Inventory did not include all Pacific 01 probes.");
    Assert(report.Summary.CandidatesTested == 4, "Inventory candidate count was incorrect.");
    Assert(report.Summary.ReadableSensors == 4, "Healthy Pacific candidates were not readable.");
    Assert(report.Summary.SuccessfulMeasurementChannels == 12, "Inventory did not read all channels.");
    Assert(report.Summary.FailedReads == 0, "Healthy inventory reported failures.");
    Assert(
        report.Devices.Select(device => device.SensorId).SequenceEqual(new[]
        {
            "pacific01_probe01",
            "pacific01_probe02",
            "pacific01_probe03",
            "pacific01_probe04",
        }),
        "Inventory identifiers do not match the four Pacific 01 probes.");

    for (var probeIndex = 1; probeIndex <= 4; probeIndex++)
    {
        var device = report.Devices[probeIndex - 1];
        var physIdPrefix =
            $"Commander5:Master_Box_1.Pacific.Pacific_01.Probe_{probeIndex:00}.Oxygen.Measurement.";

        Assert(device.SourceIndex == 1 && device.ProbeIndex == probeIndex, "Inventory probe metadata was incorrect.");
        Assert(device.Measurements["temperatureC"].PhysId == physIdPrefix + "Temperature.Value", "Temperature PhysId was incorrect.");
        Assert(device.Measurements["oxygenMgL"].PhysId == physIdPrefix + "Ppm.Value", "Oxygen PhysId was incorrect.");
        Assert(device.Measurements["oxygenSaturationPct"].PhysId == physIdPrefix + "Saturation.Value", "Saturation PhysId was incorrect.");
    }
    Assert(
        reader.ReadKeys.SequenceEqual(candidates.SelectMany(candidate => candidate.Measurements).Select(sensor => sensor.Key)),
        "Inventory did not read candidates sequentially.");
}

static async Task InventoryContinuesAfterMissingPathAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Exceptions["pacific01_probe03_temperature"] = new COMException(
        "Unknown name",
        unchecked((int)0x80020006));

    var report = await RunInventoryAsync(reader, clock);
    var missing = report.Devices.Single(device => device.SensorId == "pacific01_probe03")
        .Measurements["temperatureC"];
    var nextDevice = report.Devices.Single(device => device.SensorId == "pacific01_probe04");

    Assert(!missing.Success && missing.FailureKind == "path-not-found", "Missing path was not classified.");
    Assert(nextDevice.Measurements.Values.All(measurement => measurement.Success), "Inventory stopped after a missing path.");
    Assert(reader.ReadKeys.Count == 12, "Inventory retried or skipped candidate reads.");
}

static async Task InventoryRecordsPartialSensorAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Exceptions["pacific01_probe02_oxygen"] = new InvalidOperationException("Oxygen channel unavailable.");

    var report = await RunInventoryAsync(reader, clock);
    var measurements = report.Devices.Single(device => device.SensorId == "pacific01_probe02").Measurements;

    Assert(measurements["temperatureC"].Success, "Partial sensor lost temperature data.");
    Assert(!measurements["oxygenMgL"].Success, "Failed O2 channel was reported as successful.");
    Assert(measurements["oxygenSaturationPct"].Success, "Partial sensor lost saturation data.");
}

static async Task InventoryClassifiesComExceptionsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Exceptions["pacific01_saturation"] = new COMException(
        "COM server failure",
        unchecked((int)0x80004005));

    var report = await RunInventoryAsync(reader, clock);
    var measurement = report.Devices[0].Measurements["oxygenSaturationPct"];

    Assert(measurement.FailureKind == "com-error", "COM exception was not classified.");
    Assert(report.Summary.ComErrors == 1, "COM error summary was incorrect.");
}

static async Task InventoryRecordsVigoErrorCodeAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Readings["pacific01_probe04_saturation"] = reader.CreateReading(
        SensorAllowlist.GetRequired("pacific01_probe04_saturation"),
        errorCode: 7);

    var report = await RunInventoryAsync(reader, clock);
    var measurement = report.Devices.Single(device => device.SensorId == "pacific01_probe04")
        .Measurements["oxygenSaturationPct"];

    Assert(!measurement.Success && measurement.FailureKind == "vigo-error-code", "VIGO ErrorCode was not classified.");
    Assert(measurement.ErrorCode == 7, "VIGO ErrorCode was not retained.");
}

static async Task InventoryRecordsTimeoutsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Exceptions["pacific01_temperature"] = new TimeoutException("Read timed out.");

    var report = await RunInventoryAsync(reader, clock);
    var measurement = report.Devices[0].Measurements["temperatureC"];

    Assert(measurement.FailureKind == "timeout", "Timeout was not classified.");
    Assert(report.Summary.Timeouts == 1, "Timeout summary was incorrect.");
}

static async Task InventoryPersistsJsonAsync()
{
    var directory = CreateTemporaryDirectory();
    var path = Path.Combine(directory, "logs", "vigo-inventory-test.json");
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var report = await RunInventoryAsync(new InventoryTestReader(clock), clock);

    await VigoInventoryReportFile.PersistAsync(path, report, CancellationToken.None);
    using var document = JsonDocument.Parse(await File.ReadAllTextAsync(path));
    var root = document.RootElement;
    var firstMeasurement = root
        .GetProperty("devices")[0]
        .GetProperty("measurements")
        .GetProperty("temperatureC");

    Assert(root.GetProperty("mode").GetString() == "read-only", "Inventory JSON mode missing.");
    Assert(root.GetProperty("source").GetString() == "VIGO.PRO", "Inventory JSON source missing.");
    Assert(root.GetProperty("summary").GetProperty("candidatesTested").GetInt32() == 4, "Inventory JSON candidate count missing.");
    Assert(!root.GetProperty("summary").TryGetProperty("devicesDiscovered", out _), "Inventory JSON retained the misleading discovery field.");
    Assert(firstMeasurement.GetProperty("success").GetBoolean(), "Inventory JSON result missing.");
    Assert(firstMeasurement.GetProperty("physId").GetString() is { Length: > 0 }, "Diagnostic PhysId missing.");
    Directory.Delete(directory, recursive: true);
}

static async Task InventoryPreservesOxygenMappingAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T09:00:00Z"));
    var firstCandidate = VigoInventorySources.Pacific.Candidates[0];
    var report = await new VigoInventoryRunner(new InventoryTestReader(clock), clock).RunAsync(
        new[] { firstCandidate },
        CancellationToken.None);
    var measurements = report.Devices.Single().Measurements;

    Assert(measurements["oxygenMgL"].PhysId.EndsWith("Ppm.Value", StringComparison.Ordinal), "Ppm was not mapped to oxygenMgL.");
    Assert(measurements["oxygenSaturationPct"].PhysId.EndsWith("Saturation.Value", StringComparison.Ordinal), "Saturation was not mapped to oxygenSaturationPct.");
    Assert(measurements["oxygenMgL"].Value == 11.66f, "Oxygen concentration value was mapped incorrectly.");
    Assert(measurements["oxygenSaturationPct"].Value == 101.85f, "Oxygen saturation value was mapped incorrectly.");
}

static async Task InventoryStaysReadOnlyAsync()
{
    var publicMethods = typeof(VigoInventoryRunner).Assembly
        .GetExportedTypes()
        .Where(type => type.Namespace == typeof(VigoInventoryRunner).Namespace)
        .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
        .Select(method => method.Name)
        .ToArray();
    var forbidden = new[] { "SetValue", "DoWrite", "Write", "Setpoint", "Control", "Command" };
    foreach (var name in forbidden)
    {
        Assert(!publicMethods.Contains(name, StringComparer.Ordinal), $"Inventory assembly exposes forbidden method {name}.");
    }

    var runnerFields = typeof(VigoInventoryRunner)
        .GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        .Select(field => field.FieldType)
        .ToArray();
    Assert(!runnerFields.Contains(typeof(IUploader)), "Inventory runner has an uploader dependency.");
    Assert(!runnerFields.Contains(typeof(CollectorServiceHost)), "Inventory runner has a service dependency.");
    await Task.CompletedTask;
}

static Task<VigoInventoryReport> RunInventoryAsync(InventoryTestReader reader, IClock clock) =>
    new VigoInventoryRunner(reader, clock).RunAsync(
        VigoInventorySources.Pacific,
        CancellationToken.None);

static async Task DomInventoryReadsAllChannelsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T10:00:00Z"));
    var reader = new InventoryTestReader(clock);
    var source = VigoInventorySources.Dom;
    var report = await new VigoInventoryRunner(reader, clock).RunAsync(source, CancellationToken.None);

    Assert(report.SensorFamily == "DOM", "DOM report did not identify its sensor family.");
    Assert(report.Devices.Count == 18, "DOM inventory did not include 18 channels.");
    Assert(report.Summary.CandidatesTested == 18, "DOM candidate count was incorrect.");
    Assert(report.Summary.ReadableSensors == 18, "Healthy DOM channels were not readable.");
    Assert(report.Summary.MeasurementChannels == 54, "DOM inventory did not include 54 measurements.");
    Assert(report.Summary.SuccessfulMeasurementChannels == 54, "DOM inventory did not read all measurements.");
    Assert(
        report.Devices.Select(device => device.SensorId).SequenceEqual(
            Enumerable.Range(0, 3).SelectMany(meterIndex =>
                Enumerable.Range(0, 6).Select(channelIndex => $"dom_m{meterIndex}_do{channelIndex}"))),
        "DOM sensor identifiers were not stable or sequential.");

    for (var meterIndex = 0; meterIndex <= 2; meterIndex++)
    {
        for (var channelIndex = 0; channelIndex <= 5; channelIndex++)
        {
            var device = report.Devices.Single(candidate =>
                candidate.SensorId == $"dom_m{meterIndex}_do{channelIndex}");
            var physIdPrefix =
                $"Commander5:Master_Box_1.DOM.DO_Meter_{meterIndex}.DO_{channelIndex}.Measurement.";

            Assert(device.SourceType == "DOM", "DOM source type was incorrect.");
            Assert(device.SourceDevice == $"DO_Meter_{meterIndex}", "DOM source device was incorrect.");
            Assert(device.SourceChannel == $"DO_{channelIndex}", "DOM source channel was incorrect.");
            Assert(device.MeterIndex == meterIndex && device.ChannelIndex == channelIndex, "DOM channel metadata was incorrect.");
            Assert(device.Measurements["temperatureC"].PhysId == physIdPrefix + "temperature", "DOM temperature PhysId was incorrect.");
            Assert(device.Measurements["oxygenMgL"].PhysId == physIdPrefix + "ppm", "DOM ppm PhysId was incorrect.");
            Assert(device.Measurements["oxygenSaturationPct"].PhysId == physIdPrefix + "saturation", "DOM saturation PhysId was incorrect.");
        }
    }

    Assert(
        reader.ReadKeys.SequenceEqual(source.Candidates.SelectMany(candidate => candidate.Measurements).Select(sensor => sensor.Key)),
        "DOM inventory was not sequential.");
    Assert(!reader.ReadKeys.Any(key => key.Contains("AlarmStat", StringComparison.OrdinalIgnoreCase)), "DOM inventory attempted an AlarmStat read.");
}

static async Task DomInventoryHandlesPerChannelFailuresAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T10:00:00Z"));
    var reader = new InventoryTestReader(clock);
    reader.Exceptions["dom_m1_do2_temperature"] = new COMException(
        "COM server failure",
        unchecked((int)0x80004005));
    reader.Exceptions["dom_m1_do2_oxygen"] = new TimeoutException("Read timed out.");
    reader.Readings["dom_m2_do4_saturation"] = reader.CreateReading(
        SensorAllowlist.GetRequired("dom_m2_do4_saturation"),
        errorCode: 7);

    var report = await RunDomInventoryAsync(reader, clock);
    var partial = report.Devices.Single(device => device.SensorId == "dom_m1_do2").Measurements;
    var nextChannel = report.Devices.Single(device => device.SensorId == "dom_m1_do3");
    var vigoError = report.Devices.Single(device => device.SensorId == "dom_m2_do4")
        .Measurements["oxygenSaturationPct"];

    Assert(!partial["temperatureC"].Success && partial["temperatureC"].FailureKind == "com-error", "DOM COM error was not classified.");
    Assert(!partial["oxygenMgL"].Success && partial["oxygenMgL"].FailureKind == "timeout", "DOM timeout was not classified.");
    Assert(partial["oxygenSaturationPct"].Success, "DOM partial channel lost a readable measurement.");
    Assert(nextChannel.Measurements.Values.All(measurement => measurement.Success), "DOM inventory stopped after a failed channel.");
    Assert(!vigoError.Success && vigoError.FailureKind == "vigo-error-code", "DOM VIGO ErrorCode was not classified.");
    Assert(report.Summary.ComErrors == 1 && report.Summary.Timeouts == 1, "DOM error summary was incorrect.");
    Assert(reader.ReadKeys.Count == 54, "DOM inventory retried or skipped a measurement.");
}

static async Task DomInventoryPersistsJsonAsync()
{
    var directory = CreateTemporaryDirectory();
    var path = Path.Combine(directory, "logs", "vigo-dom-inventory-test.json");
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T10:00:00Z"));
    var report = await RunDomInventoryAsync(new InventoryTestReader(clock), clock);

    await VigoInventoryReportFile.PersistAsync(path, report, CancellationToken.None);
    using var document = JsonDocument.Parse(await File.ReadAllTextAsync(path));
    var root = document.RootElement;
    var firstChannel = root.GetProperty("channels")[0];

    Assert(root.GetProperty("sensorFamily").GetString() == "DOM", "DOM JSON sensor family was missing.");
    Assert(root.GetProperty("channels").GetArrayLength() == 18, "DOM JSON channel count was incorrect.");
    Assert(!root.TryGetProperty("devices", out _), "DOM JSON exposed the Pacific device property.");
    Assert(firstChannel.GetProperty("sensorId").GetString() == "dom_m0_do0", "DOM JSON sensor id was incorrect.");
    Assert(firstChannel.GetProperty("meterIndex").GetInt32() == 0, "DOM JSON meter index was incorrect.");
    Assert(firstChannel.GetProperty("channelIndex").GetInt32() == 0, "DOM JSON channel index was incorrect.");
    Assert(firstChannel.GetProperty("measurements").GetProperty("oxygenMgL").GetProperty("physId").GetString() is { } oxygenPath &&
        oxygenPath.EndsWith("Measurement.ppm", StringComparison.Ordinal), "DOM JSON ppm path was incorrect.");
    Directory.Delete(directory, recursive: true);
}

static async Task DomAndPacificPathsStaySeparateAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T10:00:00Z"));
    var pacific = VigoInventorySources.Pacific.Candidates[0];
    var dom = VigoInventorySources.Dom.Candidates[0];
    var pacificReport = await new VigoInventoryRunner(new InventoryTestReader(clock), clock).RunAsync(
        new[] { pacific },
        CancellationToken.None);
    var domReport = await new VigoInventoryRunner(new InventoryTestReader(clock), clock).RunAsync(
        new[] { dom },
        CancellationToken.None);

    Assert(pacificReport.Devices.Single().Measurements["oxygenMgL"].PhysId.EndsWith("Oxygen.Measurement.Ppm.Value", StringComparison.Ordinal), "Pacific path changed.");
    Assert(domReport.Devices.Single().Measurements["oxygenMgL"].PhysId.EndsWith("Measurement.ppm", StringComparison.Ordinal), "DOM path did not use lowercase ppm.");
    Assert(!domReport.Devices.Single().Measurements.Values.Any(measurement =>
        measurement.PhysId.Contains("AlarmStat", StringComparison.OrdinalIgnoreCase)), "DOM report contained AlarmStat.");
}

static Task<VigoInventoryReport> RunDomInventoryAsync(InventoryTestReader reader, IClock clock) =>
    new VigoInventoryRunner(reader, clock).RunAsync(
        VigoInventorySources.Dom,
        CancellationToken.None);

static async Task DynamicPacificDiscoveryAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var result = await DiscoverProductionAsync(clock, new[]
    {
        PacificReference(1, 1),
        PacificReference(1, 125),
        PacificReference(2, 1),
        PacificReference(17, 23),
    });

    Assert(result.Sensors.Count == 4, "Dynamic Pacific discovery imposed a fixed probe limit.");
    Assert(result.Sources.Single().Type == "Pacific", "Pacific capability was missing.");
    Assert(result.Sources.Single().Devices == 3 && result.Sources.Single().Sensors == 4, "Pacific capabilities were incorrect.");
    var probe125 = result.Sensors.Single(sensor => sensor.SourceChannel == "Probe_125");
    Assert(probe125.Measurements[0].PhysId.EndsWith("Probe_125.Oxygen.Measurement.Temperature.Value", StringComparison.Ordinal), "Pacific 125 path was not preserved.");
    Assert(probe125.Measurements[1].PhysId.EndsWith("Ppm.Value", StringComparison.Ordinal), "Pacific ppm path was incorrect.");
}

static async Task DynamicDomDiscoveryAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var result = await DiscoverProductionAsync(clock, new[]
    {
        DomReference(0, 0),
        DomReference(0, 9),
        DomReference(3, 1),
        DomReference(47, 19),
    });

    Assert(result.Sensors.Count == 4, "Dynamic DOM discovery imposed a fixed channel limit.");
    Assert(result.Sources.Single().Type == "DOM", "DOM capability was missing.");
    Assert(result.Sources.Single().Devices == 3 && result.Sources.Single().Sensors == 4, "DOM capabilities were incorrect.");
    var meter47 = result.Sensors.Single(sensor => sensor.SourceDevice == "DO_Meter_47");
    Assert(meter47.SourceChannel == "DO_19", "DOM channel identity was incorrect.");
    Assert(meter47.Measurements[0].PhysId.EndsWith("Measurement.temperature", StringComparison.Ordinal), "DOM lowercase temperature path was incorrect.");
    Assert(meter47.Measurements[1].PhysId.EndsWith("Measurement.ppm", StringComparison.Ordinal), "DOM lowercase ppm path was incorrect.");
    Assert(meter47.Measurements[2].PhysId.EndsWith("Measurement.saturation", StringComparison.Ordinal), "DOM lowercase saturation path was incorrect.");
}

static async Task ProductionDiscoverySupportsSourceCombinationsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var pacificOnly = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 1) });
    var domOnly = await DiscoverProductionAsync(clock, new[] { DomReference(0, 0) });
    var mixed = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 1), DomReference(0, 0) });
    var empty = await DiscoverProductionAsync(clock, Array.Empty<string>());

    Assert(pacificOnly.Sensors.Count == 1 && pacificOnly.Sources.Count == 1 && pacificOnly.Sources[0].Type == "Pacific", "Pacific-only discovery failed.");
    Assert(domOnly.Sensors.Count == 1 && domOnly.Sources.Count == 1 && domOnly.Sources[0].Type == "DOM", "DOM-only discovery failed.");
    Assert(mixed.Sensors.Count == 2 && mixed.Sources.Count == 2, "Mixed discovery failed.");
    Assert(empty.Sensors.Count == 0 && empty.Sources.Count == 0 && empty.Issues.Count == 0, "Empty discovery was not handled safely.");
}

static async Task ProductionDiscoveryIsolatesSourceFailuresAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var goodSource = new InMemoryVigoConfigurationSource("good", new[] { DomReference(2, 3) });
    var failedSource = new ThrowingVigoConfigurationSource("broken-config");
    var result = await new ProductionDiscoveryService(
        new IVigoConfigurationDiscoverySource[] { failedSource, goodSource },
        clock: clock).DiscoverAsync(CancellationToken.None);

    Assert(result.Sensors.Count == 1 && result.Sensors[0].SourceType == "DOM", "A failed source stopped a healthy source family.");
    Assert(result.Issues.Single().SourceName == "broken-config", "Discovery did not retain the failed source issue.");
}

static async Task RuntimeAllowlistUsesDiscoveredSensorsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var result = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 1), DomReference(0, 0) });
    var allowlist = result.CreateRuntimeAllowlist();

    Assert(allowlist.Sensors.Count == 6, "Runtime allowlist did not contain exactly three leaves per discovered sensor.");
    Assert(allowlist.GetRequired(result.Sensors[0].Measurements[0].Key).PhysId == result.Sensors[0].Measurements[0].PhysId, "Runtime allowlist changed a discovered PhysId.");
    ExpectThrows<InvalidOperationException>(() => allowlist.GetRequired("Commander5:untrusted-path"));
}

static async Task ProductionSensorIdsAreStableAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var references = new[] { PacificReference(2, 1), DomReference(4, 3), PacificReference(1, 57) };
    var first = await DiscoverProductionAsync(clock, references);
    var second = await DiscoverProductionAsync(clock, references.Reverse().ToArray());

    Assert(first.Sensors.Select(sensor => sensor.SensorId).SequenceEqual(second.Sensors.Select(sensor => sensor.SensorId)), "Discovery order changed stable sensor identifiers.");
    Assert(first.Sensors.All(sensor => !sensor.SensorId.Contains("timestamp", StringComparison.OrdinalIgnoreCase)), "Sensor id used volatile data.");
}

static async Task ProductionRuntimeIsolatesSensorFailuresAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 1), DomReference(0, 0) });
    var reader = new InventoryTestReader(clock);
    var failedMeasurement = discovery.Sensors.Single(sensor => sensor.SourceType == "Pacific").Measurements[1];
    reader.Exceptions[failedMeasurement.Key] = new InvalidOperationException("Unavailable.");
    var layout = ProductionStorageLayout.Open(directory);
    var identity = new CollectorIdentityStore(layout.IdentityDirectory, clock).LoadOrCreate();
    var runtime = new ProductionCollectorRuntime(
        reader,
        discovery.CreateRuntimeAllowlist(),
        identity,
        new CollectorBuildMetadata("1.0.0", "1.0.0+test", "test"),
        new LocalCollectorBatchBuffer(Path.Combine(layout.BufferDirectory, "batches.jsonl")),
        clock);

    var batch = await runtime.ReadOneCycleAsync(discovery, CancellationToken.None);
    var failed = batch.Readings.Single(reading => reading.SourceType == "Pacific");
    var healthy = batch.Readings.Single(reading => reading.SourceType == "DOM");

    Assert(failed.Health == "degraded" && failed.OxygenMgL is null, "A failed production channel was not isolated.");
    Assert(healthy.Health == "ok", "A failed Pacific sensor stopped DOM data.");
    Assert(File.Exists(Path.Combine(layout.BufferDirectory, "batches.jsonl")), "Production runtime did not persist its local-only batch.");
    Assert(typeof(CollectorReading).GetProperties().All(property =>
        !property.Name.Contains("tank", StringComparison.OrdinalIgnoreCase) &&
        !property.Name.Contains("section", StringComparison.OrdinalIgnoreCase)), "Production reading contains tank or section mapping.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceUsesDynamicAllowlistAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[]
    {
        PacificReference(4, 91),
        DomReference(19, 37),
    });
    var reader = new InventoryTestReader(clock);
    var buffer = new RecordingBatchBuffer();

    var batch = await RunProductionReadAsync(directory, discovery, reader, buffer, clock);

    var expectedKeys = discovery.Sensors.SelectMany(sensor => sensor.Measurements)
        .Select(measurement => measurement.Key)
        .ToArray();
    Assert(reader.ReadKeys.SequenceEqual(expectedKeys), "Read-once did not use the dynamic discovery allowlist in descriptor order.");
    Assert(batch.Readings.Select(reading => reading.SensorId).SequenceEqual(discovery.Sensors.Select(sensor => sensor.SensorId)), "Batch sensor IDs did not follow discovery descriptors.");
    Assert(!reader.ReadKeys.Any(key => key.Contains("AlarmStat", StringComparison.OrdinalIgnoreCase)), "Read-once attempted AlarmStat.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceSupportsSourceCombinationsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var combinations = new[]
    {
        new[] { PacificReference(8, 13) },
        new[] { DomReference(27, 4) },
        new[] { PacificReference(8, 13), DomReference(27, 4) },
    };

    foreach (var references in combinations)
    {
        var directory = CreateTemporaryDirectory();
        var discovery = await DiscoverProductionAsync(clock, references);
        var reader = new InventoryTestReader(clock);
        var batch = await RunProductionReadAsync(
            directory,
            discovery,
            reader,
            new RecordingBatchBuffer(),
            clock);

        Assert(batch.Readings.Count == discovery.Sensors.Count, "Read-once did not include every source combination sensor.");
        Assert(batch.Readings.All(reading => reading.Health == "ok"), "Healthy source combination was not normalized as OK.");
        Directory.Delete(directory, recursive: true);
    }
}

static async Task ProductionReadOnceHandlesEmptyDiscoveryAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, Array.Empty<string>());
    var reader = new InventoryTestReader(clock);
    var output = new LocalProductionReadOutput(Path.Combine(directory, "buffer"));

    var batch = await RunProductionReadAsync(directory, discovery, reader, output, clock);

    Assert(batch.Readings.Count == 0, "Empty discovery produced synthetic sensor readings.");
    Assert(reader.ReadKeys.Count == 0, "Empty discovery created a VIGO read.");
    Assert(output.LastWrittenPath is { } path && File.Exists(path), "Empty discovery did not create controlled local output.");
    Assert(ProductionReadSummary.Create(discovery, batch).SensorsAttempted == 0, "Empty summary was incorrect.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOncePreservesFieldMappingsAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { PacificReference(5, 2), DomReference(3, 4) });

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        new InventoryTestReader(clock),
        new RecordingBatchBuffer(),
        clock);

    foreach (var reading in batch.Readings)
    {
        Assert(!string.IsNullOrWhiteSpace(reading.SourceDevice) && !string.IsNullOrWhiteSpace(reading.SourceChannel), "Source device/channel were omitted from the normalized reading.");
        Assert(reading.TemperatureC == 9.52f, "Temperature was mapped incorrectly.");
        Assert(reading.OxygenMgL == 11.66f, "ppm/Ppm was not mapped to oxygenMgL.");
        Assert(reading.OxygenSaturationPct == 101.85f, "Saturation was mapped incorrectly.");
        Assert(reading.Measurements.Select(status => status.Field).SequenceEqual(new[]
        {
            "temperatureC", "oxygenMgL", "oxygenSaturationPct",
        }), "Per-measurement status did not retain normalized fields.");
    }

    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceHandlesPartialMeasurementFailureAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { DomReference(2, 8) });
    var reader = new InventoryTestReader(clock);
    var failedMeasurement = discovery.Sensors.Single().Measurements.Single(measurement => measurement.Kind == SensorKind.OxygenMgL);
    reader.Exceptions[failedMeasurement.Key] = new InvalidOperationException("Expected mock read failure.");

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        reader,
        new RecordingBatchBuffer(),
        clock);
    var reading = batch.Readings.Single();

    Assert(reading.Health == "degraded", "One failed measurement did not mark the sensor as degraded.");
    Assert(reading.TemperatureC is not null && reading.OxygenMgL is null && reading.OxygenSaturationPct is not null, "Partial failure invalidated healthy measurements.");
    Assert(reading.Measurements.Single(status => status.Field == "oxygenMgL").Status == "read-error", "Partial failure status was not retained.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceContinuesAfterComFailureAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 1), DomReference(1, 1) });
    var reader = new InventoryTestReader(clock);
    foreach (var measurement in discovery.Sensors.First().Measurements)
    {
        reader.Exceptions[measurement.Key] = new COMException("Expected mock COM failure.", unchecked((int)0x80020006));
    }

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        reader,
        new RecordingBatchBuffer(),
        clock);
    var summary = ProductionReadSummary.Create(discovery, batch);

    Assert(batch.Readings.First().Health == "failed", "Complete COM failure did not mark its sensor as failed.");
    Assert(batch.Readings.Last().Health == "ok", "COM failure stopped the next dynamically discovered sensor.");
    Assert(summary.ComErrors == 3, "COM errors were not counted per failed measurement.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceContinuesAfterTimeoutAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { PacificReference(7, 3), DomReference(8, 2) });
    var reader = new InventoryTestReader(clock);
    var timeoutMeasurement = discovery.Sensors.First().Measurements.Single(measurement => measurement.Kind == SensorKind.TemperatureC);
    reader.Exceptions[timeoutMeasurement.Key] = new TimeoutException("Expected mock timeout.");

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        reader,
        new RecordingBatchBuffer(),
        clock);
    var summary = ProductionReadSummary.Create(discovery, batch);

    Assert(batch.Readings.First().Health == "degraded", "Timeout did not degrade only the affected sensor.");
    Assert(batch.Readings.Last().Health == "ok", "Timeout stopped the next sensor.");
    Assert(summary.Timeouts == 1, "Timeout summary did not count the failed measurement.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionReadOnceWritesLocalJsonAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(clock, new[] { PacificReference(1, 3), DomReference(0, 4) });
    var output = new LocalProductionReadOutput(Path.Combine(directory, "buffer"));

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        new InventoryTestReader(clock),
        output,
        clock);
    var path = output.LastWrittenPath ?? throw new InvalidOperationException("Expected local batch output path.");
    var json = await File.ReadAllTextAsync(path);
    var roundTripped = JsonSerializer.Deserialize<CollectorBatch>(json, new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true,
    });

    Assert(Path.GetFileName(path).StartsWith("production-read-2026-10-09_120000", StringComparison.Ordinal), "Read-once output file name was not timestamped.");
    Assert(roundTripped?.Readings.Count == batch.Readings.Count, "Local batch JSON did not deserialize.");
    Assert(!json.Contains("tankId", StringComparison.OrdinalIgnoreCase) && !json.Contains("sectionId", StringComparison.OrdinalIgnoreCase), "Local batch exposed customer mapping.");
    Directory.Delete(directory, recursive: true);
}

static Task ProductionReadOnceHasNoUploaderDependencyAsync()
{
    var fieldTypes = typeof(ProductionCollectorRuntime)
        .GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        .Select(field => field.FieldType)
        .ToArray();
    Assert(!fieldTypes.Any(type => type.Name.Contains("Uploader", StringComparison.Ordinal)), "Production read runtime has an uploader dependency.");
    Assert(ProductionCliPolicy.Parse(new[] { "--read-once" }) == ProductionCommand.ReadOnce, "Production read-once command was unavailable.");
    ExpectThrows<ArgumentException>(() => ProductionCliPolicy.Parse(new[] { "--read-once", "--physid=Commander5:untrusted" }));
    return Task.CompletedTask;
}

static async Task ProductionReadOnceTraversesLargeInventoryAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T12:00:00Z"));
    var discovery = await DiscoverProductionAsync(
        clock,
        Enumerable.Range(1, 5_716).Select(index => PacificReference(3, index)).ToArray());
    var reader = new InventoryTestReader(clock);

    var batch = await RunProductionReadAsync(
        directory,
        discovery,
        reader,
        new RecordingBatchBuffer(),
        clock);

    Assert(batch.Readings.Count == 5_716, "Read-once truncated a large dynamic sensor inventory.");
    Assert(reader.ReadKeys.Count == 17_148, "Read-once did not attempt every dynamic measurement.");
    Directory.Delete(directory, recursive: true);
}

static async Task ProductionDiscoveryHandlesLargeInventoryAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var references = Enumerable.Range(1, 5_716)
        .Select(probeIndex => PacificReference(1, probeIndex))
        .ToArray();
    var result = await DiscoverProductionAsync(clock, references);

    Assert(result.Sensors.Count == 5_716, "Large production inventory was truncated.");
    Assert(result.CreateRuntimeAllowlist().Sensors.Count == 17_148, "Large runtime allowlist did not retain all measurement leaves.");
}

static Task ProductionCliIsRestrictedAsync()
{
    Assert(ProductionCliPolicy.Parse(new[] { "--identity" }) == ProductionCommand.Identity, "Production identity command was unavailable.");
    Assert(ProductionCliPolicy.Parse(new[] { "--status" }) == ProductionCommand.Status, "Production status command was unavailable.");
    Assert(ProductionCliPolicy.Parse(new[] { "--discovery-status" }) == ProductionCommand.DiscoveryStatus, "Production discovery command was unavailable.");
    Assert(ProductionCliPolicy.Parse(new[] { "--read-once" }) == ProductionCommand.ReadOnce, "Production read-once command was unavailable.");
    ExpectThrows<ArgumentException>(() => ProductionCliPolicy.Parse(new[] { "--vigo-pilot" }));
    ExpectThrows<ArgumentException>(() => ProductionCliPolicy.Parse(new[] { "--read-once", "--physid=Commander5:manual" }));
    return Task.CompletedTask;
}

static Task ProductionStorageMigratesIdentityAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-09T11:00:00Z"));
    var legacyIdentity = new CollectorIdentityStore(directory, clock).LoadOrCreate();
    var layout = ProductionStorageLayout.Open(directory);
    var migratedIdentity = new CollectorIdentityStore(layout.IdentityDirectory, clock).LoadOrCreate();

    Assert(legacyIdentity.CollectorDeviceId == migratedIdentity.CollectorDeviceId, "Production storage did not preserve the existing identity.");
    Assert(File.Exists(Path.Combine(layout.IdentityDirectory, "identity.json")), "Production identity was not moved to the persistent identity directory.");
    Assert(Directory.Exists(layout.ConfigDirectory) && Directory.Exists(layout.LogsDirectory) && Directory.Exists(layout.BufferDirectory), "Production storage directories were not created.");
    Directory.Delete(directory, recursive: true);
    return Task.CompletedTask;
}

static Task ProductionSensorSourcesStayReadOnlyAsync()
{
    var forbidden = new[] { "SetValue", "DoWrite", "Write", "Setpoint", "Control", "Command" };
    var methods = new[] { typeof(PacificDiscoverySource), typeof(DomDiscoverySource) }
        .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
        .Select(method => method.Name)
        .ToArray();

    foreach (var method in forbidden)
    {
        Assert(!methods.Contains(method, StringComparer.Ordinal), $"Production sensor sources expose forbidden method {method}.");
    }

    return Task.CompletedTask;
}

static async Task PairingRegistersAndProtectsCredentialAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var ui = new TestPairingUi();
    var logger = new TestPairingLogger();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, logger);

    await coordinator.RunSingleCycleAsync(CancellationToken.None);

    Assert(backend.RegistrationCalls == 1, "First pairing cycle did not register the Collector.");
    Assert(coordinator.Snapshot.State == CollectorPairingState.PairingCodeActive, "Registered Collector did not receive a pairing code.");
    Assert(ui.Codes.Count == 1, "Pairing code was not passed to the pairing UI.");
    var rawState = File.ReadAllText(Path.Combine(directory, "identity", "pairing.json"));
    Assert(!rawState.Contains(backend.DeviceCredential, StringComparison.Ordinal), "Device credential was written as plaintext.");
    Assert(!rawState.Contains(ui.Codes[0].Code, StringComparison.Ordinal), "Pairing code was persisted locally.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingReusesPersistedIdentityAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var first = CreatePairingCoordinator(directory, clock, backend, new TestPairingUi(), new TestPairingLogger());
    await first.RunSingleCycleAsync(CancellationToken.None);
    var registeredCollectorId = backend.LastRegisteredCollectorId;

    var secondUi = new TestPairingUi();
    var second = CreatePairingCoordinator(directory, clock, backend, secondUi, new TestPairingLogger());
    await second.RunSingleCycleAsync(CancellationToken.None);

    Assert(backend.RegistrationCalls == 1, "Restart generated a second backend identity.");
    Assert(second.Snapshot.CollectorId == registeredCollectorId, "Restart did not reuse the saved backend collector id.");
    Assert(secondUi.Codes.Count == 1, "Unpaired restart did not request a fresh pairing code.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingRotatesExpiredCodeAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var ui = new TestPairingUi();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, new TestPairingLogger());
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    var oldCode = ui.Codes.Single().Code;

    clock.UtcNow = clock.UtcNow.AddMinutes(11);
    await coordinator.RunSingleCycleAsync(CancellationToken.None);

    Assert(ui.Codes.Count == 2, "Expired pairing code was not replaced.");
    Assert(ui.Codes.Last().Code != oldCode, "Pairing rotation reused the expired code.");
    Assert(coordinator.Snapshot.PairingCodeExpiresAtUtc > clock.UtcNow, "New code expiry was not retained in active state.");
    var rawState = File.ReadAllText(Path.Combine(directory, "identity", "pairing.json"));
    Assert(!rawState.Contains(oldCode, StringComparison.Ordinal), "Expired code remained in local state.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingPopupCloseAndReopenAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var ui = new TestPairingUi();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, new TestPairingLogger());
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    ui.CloseManually();

    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(ui.WindowsCreated == 1, "Closed popup reopened before code expiry.");

    clock.UtcNow = clock.UtcNow.AddMinutes(11);
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(ui.WindowsCreated == 2, "New code did not reopen the manually closed popup.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingKeepsOnePopupAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var ui = new TestPairingUi();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, new TestPairingLogger());
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    await coordinator.RunSingleCycleAsync(CancellationToken.None);

    Assert(ui.WindowsCreated == 1, "Active pairing cycle created more than one popup.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingRetriesAfterBackendUnavailableAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock) { ThrowStatusUnavailable = true };
    var ui = new TestPairingUi();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, new TestPairingLogger());

    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(coordinator.Snapshot.State == CollectorPairingState.BackendUnavailable, "Offline backend did not enter a safe state.");
    Assert(ui.BackendUnavailableCalls == 1, "Offline state was not shown in the pairing UI.");

    backend.ThrowStatusUnavailable = false;
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(coordinator.Snapshot.State == CollectorPairingState.PairingCodeActive, "Collector did not resume pairing after reconnect.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairedRestartDoesNotShowPopupAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var first = CreatePairingCoordinator(directory, clock, backend, new TestPairingUi(), new TestPairingLogger());
    await first.RunSingleCycleAsync(CancellationToken.None);
    backend.State = "PAIRED";

    var pairedUi = new TestPairingUi();
    var paired = CreatePairingCoordinator(directory, clock, backend, pairedUi, new TestPairingLogger());
    await paired.RunSingleCycleAsync(CancellationToken.None);
    Assert(paired.Snapshot.State == CollectorPairingState.Paired, "Backend paired state was not honoured.");
    Assert(pairedUi.Codes.Count == 0, "Paired restart displayed a pairing code.");
    Directory.Delete(directory, recursive: true);
}

static async Task RevokedCollectorResumesAfterBackendResetAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var coordinator = CreatePairingCoordinator(directory, clock, backend, new TestPairingUi(), new TestPairingLogger());
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    backend.State = "REVOKED";
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(coordinator.Snapshot.State == CollectorPairingState.Revoked, "Revoked backend state was ignored.");

    backend.State = "UNPAIRED";
    await coordinator.RunSingleCycleAsync(CancellationToken.None);
    Assert(coordinator.Snapshot.State == CollectorPairingState.PairingCodeActive, "Backend reset did not start a new pairing flow.");
    Assert(backend.RegistrationCalls == 1, "Collector re-registered instead of retaining its backend identity after reset.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingHandlesWrongCredentialAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock) { ThrowAuthenticationFailure = true };
    var logger = new TestPairingLogger();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, new TestPairingUi(), logger);

    await coordinator.RunSingleCycleAsync(CancellationToken.None);

    Assert(coordinator.Snapshot.State == CollectorPairingState.AuthenticationFailed, "Credential rejection did not stop pairing safely.");
    Assert(!logger.Messages.Any(message => message.Contains(backend.DeviceCredential, StringComparison.Ordinal)), "Credential leaked to logs.");
    Directory.Delete(directory, recursive: true);
}

static async Task PairingLogsAreSecretFreeAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-11T08:00:00Z"));
    var backend = new PairingBackendFake(clock);
    var ui = new TestPairingUi();
    var logger = new TestPairingLogger();
    var coordinator = CreatePairingCoordinator(directory, clock, backend, ui, logger);
    await coordinator.RunSingleCycleAsync(CancellationToken.None);

    var code = ui.Codes.Single().Code;
    Assert(!logger.Messages.Any(message => message.Contains(code, StringComparison.Ordinal)), "Pairing code leaked to logs.");
    Assert(!logger.Messages.Any(message => message.Contains(backend.DeviceCredential, StringComparison.Ordinal)), "Device credential leaked to logs.");
    Directory.Delete(directory, recursive: true);
}

static Task PairingBackendConfigurationIsSafeAsync()
{
    var directory = CreateTemporaryDirectory();
    ExpectThrows<ArgumentException>(() => CollectorPairingBackendConfiguration.Load(
        new[] { "--pairing", "--pairing-backend-url=http://example.invalid/collector/v1" },
        directory));
    var emulator = CollectorPairingBackendConfiguration.Load(
        new[]
        {
            "--pairing",
            "--pairing-emulator",
            "--pairing-backend-url=http://127.0.0.1:5001/project/region/function/collector/v1",
        },
        directory);
    Assert(emulator.Endpoint?.Scheme == Uri.UriSchemeHttp, "Explicit loopback emulator URL was rejected.");
    Directory.Delete(directory, recursive: true);
    return Task.CompletedTask;
}

static async Task PairingHttpClientUsesBackendContractAsync()
{
    var handler = new PairingHttpHandler(
        new HttpResponseMessage(HttpStatusCode.Created)
        {
            Content = new StringContent("{\"collectorId\":\"backend-collector\",\"deviceCredential\":\"credential-abcdefghijklmnopqrstuvwxyz-012345\",\"state\":\"UNPAIRED\"}"),
        },
        new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{\"collectorId\":\"backend-collector\",\"state\":\"UNPAIRED\"}"),
        },
        new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{\"collectorId\":\"backend-collector\",\"state\":\"UNPAIRED\",\"code\":\"FJ-ABCD-EFGH-JKLM\",\"expiresAt\":\"2026-10-11T08:10:00Z\"}"),
        });
    using var client = new HttpClient(handler);
    using var backend = new HttpCollectorPairingBackend(
        new CollectorPairingBackendConfiguration(new Uri("https://pairing.example/collector/v1/"), "test"),
        client);
    var identity = await backend.RegisterAsync("1.0.1", "windows-x86", CancellationToken.None);
    await backend.GetStatusAsync(identity, CancellationToken.None);
    var result = await backend.IssuePairingCodeAsync(identity, CancellationToken.None);

    Assert(handler.Requests.Select(request => request.Path).SequenceEqual(new[] { "/collector/v1/register", "/collector/v1/status", "/collector/v1/pairing-code" }),
        "Pairing client used an unexpected endpoint path.");
    Assert(handler.Requests[0].Method == "POST", "Registration did not use POST.");
    Assert(handler.Requests[1].CollectorId == identity.CollectorId && handler.Requests[1].Credential == identity.DeviceCredential,
        "Status request omitted collector authentication headers.");
    Assert(result.PairingCode?.Code == "FJ-ABCD-EFGH-JKLM", "Pairing code response was not read exactly.");
}

static Task PairingStateDoesNotDependOnVigoAsync()
{
    var fieldTypes = typeof(CollectorPairingCoordinator)
        .GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        .Select(field => field.FieldType)
        .ToArray();
    Assert(!fieldTypes.Contains(typeof(ISensorReader)), "Pairing coordinator depends on Vigo sensor reading.");
    Assert(!fieldTypes.Contains(typeof(OxyGuardVigoReader)), "Pairing coordinator references the COM reader.");
    return Task.CompletedTask;
}

static async Task PairingCoordinatorEmulatorE2EAsync()
{
    var repositoryRoot = Environment.GetEnvironmentVariable("FJELLFISK_REPOSITORY_ROOT");
    if (string.IsNullOrWhiteSpace(repositoryRoot) ||
        !File.Exists(Path.Combine(repositoryRoot, "functions", "test", "claim_collector_emulator.mjs")))
    {
        throw new InvalidOperationException(
            "FJELLFISK_REPOSITORY_ROOT must point to the repository for the opt-in emulator E2E test.");
    }

    if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("FIRESTORE_EMULATOR_HOST")))
    {
        throw new InvalidOperationException("FIRESTORE_EMULATOR_HOST is required for the opt-in emulator E2E test.");
    }

    var directory = CreateTemporaryDirectory();
    try
    {
        var layout = ProductionStorageLayout.Open(directory);
        var configuration = CollectorPairingBackendConfiguration.Load(
            new[]
            {
                "--pairing",
                "--pairing-emulator",
                "--pairing-backend-url=http://127.0.0.1:5001/trolltungaarctictrout/europe-west1/collectorApi/collector/v1",
            },
            layout.ConfigDirectory);
        using var backend = new HttpCollectorPairingBackend(configuration);
        var ui = new TestPairingUi();
        var logger = new TestPairingLogger();
        var coordinator = new CollectorPairingCoordinator(
            new CollectorPairingStateStore(layout.IdentityDirectory),
            backend,
            ui,
            logger,
            SystemClock.Instance,
            new PairingTestDelay(),
            "1.0.1-e2e",
            "windows-x86");

        await coordinator.RunSingleCycleAsync(CancellationToken.None);
        Assert(coordinator.Snapshot.State == CollectorPairingState.PairingCodeActive,
            "The real emulator backend did not return an active pairing code.");
        var code = ui.Codes.Single().Code;

        await ClaimEmulatorPairingCodeAsync(repositoryRoot, code);
        await coordinator.RunSingleCycleAsync(CancellationToken.None);

        Assert(coordinator.Snapshot.State == CollectorPairingState.Paired,
            "The Collector did not observe the PAIRED state from the real emulator backend.");
        Assert(ui.CloseCalls >= 1, "The pairing UI was not closed after the Collector became paired.");
        Assert(!logger.Messages.Any(message => message.Contains(code, StringComparison.Ordinal)),
            "The real emulator pairing code leaked to Collector logs.");
    }
    finally
    {
        Directory.Delete(directory, recursive: true);
    }
}

static async Task ClaimEmulatorPairingCodeAsync(string repositoryRoot, string code)
{
    var scriptPath = Path.Combine(repositoryRoot, "functions", "test", "claim_collector_emulator.mjs");
    var startInfo = new ProcessStartInfo("node")
    {
        WorkingDirectory = repositoryRoot,
        UseShellExecute = false,
        RedirectStandardInput = true,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true,
    };
    startInfo.ArgumentList.Add(scriptPath);
    startInfo.Environment["FIRESTORE_EMULATOR_HOST"] = Environment.GetEnvironmentVariable("FIRESTORE_EMULATOR_HOST")!;
    startInfo.Environment["FUNCTIONS_EMULATOR_HOST"] = Environment.GetEnvironmentVariable("FUNCTIONS_EMULATOR_HOST") ?? "127.0.0.1:5001";
    startInfo.Environment["FIREBASE_AUTH_EMULATOR_HOST"] = Environment.GetEnvironmentVariable("FIREBASE_AUTH_EMULATOR_HOST") ?? "127.0.0.1:9099";
    startInfo.Environment["GCLOUD_PROJECT"] = Environment.GetEnvironmentVariable("GCLOUD_PROJECT") ?? "trolltungaarctictrout";
    startInfo.Environment["GOOGLE_CLOUD_DISABLE_GCE_CHECK"] = "true";

    using var process = Process.Start(startInfo)
        ?? throw new InvalidOperationException("The local emulator claim helper could not start.");
    await process.StandardInput.WriteAsync(JsonSerializer.Serialize(new { code }));
    process.StandardInput.Close();

    var output = await process.StandardOutput.ReadToEndAsync();
    _ = await process.StandardError.ReadToEndAsync();
    await process.WaitForExitAsync();

    if (process.ExitCode != 0 || !output.Contains("\"state\":\"PAIRED\"", StringComparison.Ordinal))
    {
        throw new InvalidOperationException("The local emulator claim helper did not confirm pairing.");
    }
}

static async Task PairingWindowEmulatorE2EAsync()
{
    if (!OperatingSystem.IsWindows())
    {
        throw new InvalidOperationException("The pairing-window E2E test requires Windows.");
    }

    var repositoryRoot = Environment.GetEnvironmentVariable("FJELLFISK_REPOSITORY_ROOT");
    var publishDirectory = Environment.GetEnvironmentVariable("FJELLFISK_COLLECTOR_PUBLISH_DIRECTORY");
    if (string.IsNullOrWhiteSpace(repositoryRoot) ||
        string.IsNullOrWhiteSpace(publishDirectory) ||
        !File.Exists(Path.Combine(publishDirectory, "pairing-ui", "Fjellfisk.Collector.PairingUi.exe")))
    {
        throw new InvalidOperationException(
            "FJELLFISK_REPOSITORY_ROOT and FJELLFISK_COLLECTOR_PUBLISH_DIRECTORY must reference the local test build.");
    }

    var originalProcessIds = Process.GetProcessesByName("Fjellfisk.Collector.PairingUi")
        .Select(process => process.Id)
        .ToHashSet();
    var directory = CreateTemporaryDirectory();
    try
    {
        var layout = ProductionStorageLayout.Open(directory);
        var configuration = CollectorPairingBackendConfiguration.Load(
            new[]
            {
                "--pairing",
                "--pairing-emulator",
                "--pairing-backend-url=http://127.0.0.1:5001/trolltungaarctictrout/europe-west1/collectorApi/collector/v1",
            },
            layout.ConfigDirectory);
        using var backend = new HttpCollectorPairingBackend(configuration);
        using var pairingWindow = new PairingWindowProcessHost(publishDirectory);
        var ui = new CapturingPairingUi(pairingWindow);
        var logger = new TestPairingLogger();
        var coordinator = new CollectorPairingCoordinator(
            new CollectorPairingStateStore(layout.IdentityDirectory),
            backend,
            ui,
            logger,
            SystemClock.Instance,
            new PairingTestDelay(),
            "1.0.1-e2e",
            "windows-x86");

        await coordinator.RunSingleCycleAsync(CancellationToken.None);
        var code = ui.Codes.Single().Code;
        await WaitUntilAsync(
            () => Process.GetProcessesByName("Fjellfisk.Collector.PairingUi")
                .Any(process => !originalProcessIds.Contains(process.Id)),
            TimeSpan.FromSeconds(10),
            "The separate pairing window did not start.");

        await ClaimEmulatorPairingCodeAsync(repositoryRoot, code);
        await coordinator.RunSingleCycleAsync(CancellationToken.None);

        Assert(coordinator.Snapshot.State == CollectorPairingState.Paired,
            "The Collector did not become paired after the real local claim.");
        await WaitUntilAsync(
            () => Process.GetProcessesByName("Fjellfisk.Collector.PairingUi")
                .All(process => originalProcessIds.Contains(process.Id)),
            TimeSpan.FromSeconds(10),
            "The pairing window did not close after pairing succeeded.");
        Assert(!logger.Messages.Any(message => message.Contains(code, StringComparison.Ordinal)),
            "The pairing-window E2E code leaked to Collector logs.");
    }
    finally
    {
        Directory.Delete(directory, recursive: true);
    }
}

static async Task WaitUntilAsync(Func<bool> condition, TimeSpan timeout, string failureMessage)
{
    var deadline = DateTimeOffset.UtcNow + timeout;
    while (DateTimeOffset.UtcNow < deadline)
    {
        if (condition())
        {
            return;
        }

        await Task.Delay(TimeSpan.FromMilliseconds(50));
    }

    throw new InvalidOperationException(failureMessage);
}

static CollectorPairingCoordinator CreatePairingCoordinator(
    string rootDirectory,
    FakeClock clock,
    PairingBackendFake backend,
    TestPairingUi ui,
    TestPairingLogger logger)
{
    var layout = ProductionStorageLayout.Open(rootDirectory);
    return new CollectorPairingCoordinator(
        new CollectorPairingStateStore(layout.IdentityDirectory),
        backend,
        ui,
        logger,
        clock,
        new PairingTestDelay(),
        "1.0.1",
        "windows-x86");
}

static Task<ProductionDiscoveryResult> DiscoverProductionAsync(IClock clock, IReadOnlyCollection<string> references) =>
    new ProductionDiscoveryService(
        new IVigoConfigurationDiscoverySource[]
        {
            new InMemoryVigoConfigurationSource("test", references),
        },
        clock: clock).DiscoverAsync(CancellationToken.None);

static async Task<CollectorBatch> RunProductionReadAsync(
    string directory,
    ProductionDiscoveryResult discovery,
    ISensorReader reader,
    ICollectorBatchBuffer buffer,
    IClock clock)
{
    var layout = ProductionStorageLayout.Open(directory);
    var identity = new CollectorIdentityStore(layout.IdentityDirectory, clock).LoadOrCreate();
    var runtime = new ProductionCollectorRuntime(
        reader,
        discovery.CreateRuntimeAllowlist(),
        identity,
        new CollectorBuildMetadata("1.0.0", "1.0.0+test", "test"),
        buffer,
        clock);
    return await runtime.ReadOneCycleAsync(discovery, CancellationToken.None);
}

static string PacificReference(int deviceIndex, int probeIndex) =>
    $"Commander5:Master_Box_1.Pacific.Pacific_{deviceIndex:D2}.Probe_{probeIndex:D2}.Oxygen.Measurement.Ppm.Value";

static string DomReference(int meterIndex, int channelIndex) =>
    $"Commander5:Master_Box_1.DOM.DO_Meter_{meterIndex}.DO_{channelIndex}.Measurement.ppm";

static Task PayloadUsesNormalizedFieldsAsync()
{
    var measurement = SampleMeasurement("payload-1", DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    using var document = JsonDocument.Parse(MeasurementJson.Serialize(measurement));
    var root = document.RootElement;

    Assert(root.GetProperty("collectorId").GetString() == "fjellfisk-vigo-pilot-01", "Missing collector id.");
    Assert(root.GetProperty("deviceId").GetString() == "pacific-01", "Missing device id.");
    Assert(root.GetProperty("temperatureC").GetSingle() == 9.52f, "Wrong temperature.");
    Assert(root.GetProperty("oxygenMgL").GetSingle() == 11.66f, "Wrong oxygen.");
    Assert(root.GetProperty("oxygenSaturationPct").GetSingle() == 101.85f, "Wrong saturation.");
    Assert(!MeasurementJson.Serialize(measurement).Contains("PhysId", StringComparison.Ordinal), "Payload leaked PhysId.");
    return Task.CompletedTask;
}

static Task NormalizerValidatesScalarReadingsAsync()
{
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var normalizer = new MeasurementNormalizer(clock);
    var readings = SensorAllowlist.Pacific01.Select(sensor => new SensorReadResult(
        sensor,
        sensor.Kind switch
        {
            SensorKind.TemperatureC => 9.52f,
            SensorKind.OxygenMgL => 11.66f,
            _ => 101.85f,
        },
        ErrorCode: 0,
        PnetDataType: 36,
        DotNetType: "System.Single",
        clock.UtcNow,
        TimeSpan.FromMilliseconds(15))).ToArray();

    var normalized = normalizer.Normalize("collector", "pacific-01", readings);
    Assert(normalized.Status == "ok", "Expected ok status.");

    var invalidReadings = readings.ToArray();
    invalidReadings[0] = invalidReadings[0] with { ErrorCode = 4 };
    ExpectThrows<InvalidOperationException>(() => normalizer.Normalize("collector", "pacific-01", invalidReadings));
    return Task.CompletedTask;
}

static Task BackoffFollowsSafeScheduleAsync()
{
    var backoff = new RetryBackoff();
    var expected = new[] { 15, 30, 60, 120, 240, 300, 300 };
    foreach (var seconds in expected)
    {
        Assert(backoff.RegisterFailure() == TimeSpan.FromSeconds(seconds), $"Expected {seconds}s backoff.");
    }

    backoff.Reset();
    Assert(backoff.RegisterFailure() == TimeSpan.FromSeconds(15), "Backoff did not reset.");
    return Task.CompletedTask;
}

static async Task BufferRetentionAsync()
{
    var directory = CreateTemporaryDirectory();
    var path = Path.Combine(directory, "buffer.jsonl");
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-01T00:00:00Z"));
    var buffer = new LocalJsonlBuffer(path, new BufferOptions(TimeSpan.FromHours(24), 700), clock);

    await buffer.EnqueueAsync(SampleMeasurement("old", clock.UtcNow), CancellationToken.None);
    clock.UtcNow = clock.UtcNow.AddHours(25);
    await buffer.EnqueueAsync(SampleMeasurement("new", clock.UtcNow), CancellationToken.None);

    Assert(await buffer.CountAsync(CancellationToken.None) == 1, "Expired buffer entry was retained.");
    Assert((await buffer.PeekOldestAsync(CancellationToken.None))?.MeasurementId == "new", "Wrong retained entry.");

    for (var index = 0; index < 10; index++)
    {
        await buffer.EnqueueAsync(SampleMeasurement($"size-{index}", clock.UtcNow), CancellationToken.None);
    }

    Assert(new FileInfo(path).Length <= 700, "Buffer exceeded byte cap.");
    Directory.Delete(directory, recursive: true);
}

static async Task UploaderRetryAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var buffer = new LocalJsonlBuffer(
        Path.Combine(directory, "buffer.jsonl"),
        new BufferOptions(TimeSpan.FromHours(24), 10_000),
        clock);
    var uploader = new FailingOnceUploader();
    var runner = CreateRunner(clock, buffer, uploader);

    var first = await runner.RunCycleAsync(CancellationToken.None);
    Assert(!first.Success && first.NextDelay == TimeSpan.FromSeconds(15), "Expected first upload failure and 15s retry.");
    Assert(await buffer.CountAsync(CancellationToken.None) == 1, "Failed upload removed buffered data.");

    var second = await runner.FlushBufferedMeasurementsAsync(CancellationToken.None);
    Assert(second.Succeeded, "Second upload did not succeed.");
    Assert(await buffer.CountAsync(CancellationToken.None) == 0, "Successful upload did not remove buffered data.");
    Assert(uploader.MeasurementIds.Count == 2, "Expected two attempts.");
    Assert(uploader.MeasurementIds[0] == uploader.MeasurementIds[1], "Retry changed measurement idempotency key.");
    Directory.Delete(directory, recursive: true);
}

static async Task CollectorPublishesLiveSnapshotsAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var buffer = new LocalJsonlBuffer(
        Path.Combine(directory, "buffer.jsonl"),
        new BufferOptions(TimeSpan.FromHours(24), 10_000),
        clock);
    var runner = CreateRunner(clock, buffer, new ConsoleMockUploader(new TestLogger()));
    var snapshots = new List<CollectorSnapshot>();
    runner.SnapshotChanged += snapshots.Add;

    await runner.RunCyclesAsync(1, CancellationToken.None);

    Assert(snapshots.Any(snapshot => snapshot.Status.Running), "Mockup did not receive a running state.");
    var latest = snapshots.Last().LatestMeasurement;
    if (latest is null)
    {
        throw new InvalidOperationException("Mockup did not receive a measurement.");
    }

    Assert(latest.TemperatureC == 9.52f, "Mockup received the wrong temperature.");
    Assert(latest.OxygenMgL == 11.66f, "Mockup received the wrong oxygen value.");
    Assert(latest.OxygenSaturationPct == 101.85f, "Mockup received the wrong saturation.");
    Assert(snapshots.Last().Status.BufferCount == 0, "Mockup received the wrong buffer count.");
    Assert(snapshots.Any(snapshot => snapshot.Status.VigoConnected), "Mockup did not receive connected state.");

    Directory.Delete(directory, recursive: true);
}

static async Task OnePilotCycleStopsAfterOneRoundAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var reader = new CountingReader(clock);
    var runner = new CollectorRunner(
        new CollectorOptions("collector", "pacific-01", TimeSpan.FromSeconds(15)),
        reader,
        new MeasurementNormalizer(clock),
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        new ConsoleMockUploader(new TestLogger()),
        new TestLogger());

    await runner.RunCyclesAsync(1, CancellationToken.None);

    Assert(reader.ReadCount == 3, "One pilot cycle did not perform exactly three allowlisted reads.");
    Assert(!runner.Status.Running, "One pilot cycle did not stop after its round.");
    Assert(runner.Status.LastSuccessfulReadingUtc is not null, "One pilot cycle did not complete a measurement.");
    Directory.Delete(directory, recursive: true);
}

static async Task BufferResendsOldestFirstAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var buffer = new LocalJsonlBuffer(
        Path.Combine(directory, "buffer.jsonl"),
        new BufferOptions(TimeSpan.FromHours(24), 10_000),
        clock);
    await buffer.EnqueueAsync(SampleMeasurement("first", clock.UtcNow), CancellationToken.None);
    await buffer.EnqueueAsync(SampleMeasurement("second", clock.UtcNow.AddSeconds(1)), CancellationToken.None);
    var uploader = new OrderedRecordingUploader();
    var runner = CreateRunner(clock, buffer, uploader);

    var result = await runner.FlushBufferedMeasurementsAsync(CancellationToken.None);
    Assert(result.Succeeded, "Buffered resend failed.");
    Assert(uploader.MeasurementIds.SequenceEqual(new[] { "first", "second" }), "Buffer was not resent oldest-first.");
    Assert(await buffer.CountAsync(CancellationToken.None) == 0, "Buffer was not emptied after successful resend.");
    Directory.Delete(directory, recursive: true);
}

static Task PublicApiHasNoVigoWriteMethodsAsync()
{
    var forbidden = new[] { "SetValue", "DoWrite", "Write", "Setpoint", "Control", "Command" };
    var methods = typeof(CollectorRunner).Assembly
        .GetExportedTypes()
        .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
        .Select(method => method.Name)
        .ToArray();

    foreach (var name in forbidden)
    {
        Assert(!methods.Contains(name, StringComparer.Ordinal), $"Public API exposes forbidden method {name}.");
    }

    return Task.CompletedTask;
}

static Task MinimumPollingIntervalAsync()
{
    ExpectThrows<ArgumentOutOfRangeException>(() =>
        new CollectorOptions("collector", "pacific-01", TimeSpan.FromSeconds(1)));
    ExpectThrows<ArgumentOutOfRangeException>(() =>
        new SoakTestOptions(
            TimeSpan.FromHours(1),
            TimeSpan.FromSeconds(5),
            TimeSpan.FromMinutes(15)).Validate());
    return Task.CompletedTask;
}

static Task SingleInstanceLockAsync()
{
    using var first = CollectorInstanceLock.TryAcquire("collector-test-lock");
    using var second = CollectorInstanceLock.TryAcquire("collector-test-lock");
    Assert(first.IsAcquired, "First collector instance did not acquire the lock.");
    Assert(!second.IsAcquired, "Second collector instance acquired the lock.");
    return Task.CompletedTask;
}

static async Task ServiceHostUsesCollectorCoreAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var identity = new CollectorIdentityStore(directory, clock).LoadOrCreate();
    var runner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        new ConsoleMockUploader(new TestLogger()));
    using var cancellation = new CancellationTokenSource();
    var delay = new CancellingDelay(cancellation);
    var host = new CollectorServiceHost(
        identity,
        runner,
        new TestLogger(),
        delay,
        ServiceHostOptions.Default);

    var result = await host.RunAsync(cancellation.Token);
    Assert(result, "Service host should exit gracefully after cancellation.");
    Assert(delay.LastDelay == TimeSpan.FromSeconds(60), "Service host skipped the required 60-second delay.");
    Assert(ReferenceEquals(host.Runner, runner), "Service host did not reuse CollectorCore runner.");
    Directory.Delete(directory, recursive: true);
}

static async Task EnrollmentStatesAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var identity = new CollectorIdentityStore(directory, clock).LoadOrCreate();
    var state = new CollectorLocalStateStore(directory);
    var provider = new MockEnrollmentProvider(clock);
    var coordinator = new EnrollmentCoordinator(identity, state, provider, clock, new TestLogger());

    var pending = await coordinator.StartOrResumeAsync(CancellationToken.None);
    Assert(pending.State == EnrollmentState.Pending, "Collector did not enter pending enrollment.");
    Assert(pending.ClaimCode == "FJ-MOCK-0001", "Unexpected pairing code.");

    provider.SimulateConnected();
    var connected = await coordinator.PollPendingOnceAsync(CancellationToken.None);
    Assert(connected.State == EnrollmentState.Connected, "Collector did not enter connected enrollment.");
    var enrollmentFile = File.ReadAllText(Path.Combine(directory, "enrollment.json"));
    Assert(!enrollmentFile.Contains("mock-device-credential", StringComparison.Ordinal), "Credential was stored plaintext.");
    Directory.Delete(directory, recursive: true);
}

static async Task RevokedEnrollmentStopsUploadAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var identity = new CollectorIdentityStore(directory, clock).LoadOrCreate();
    var state = new CollectorLocalStateStore(directory);
    var provider = new MockEnrollmentProvider(clock);
    var coordinator = new EnrollmentCoordinator(identity, state, provider, clock, new TestLogger());
    await coordinator.StartOrResumeAsync(CancellationToken.None);
    provider.SimulateRevoked();
    var revoked = await coordinator.PollPendingOnceAsync(CancellationToken.None);
    Assert(revoked.State == EnrollmentState.Revoked, "Collector did not enter revoked enrollment.");

    var inner = new RecordingUploader();
    var gate = new EnrollmentGatedUploader(state, inner);
    var result = await gate.UploadAsync(SampleMeasurement("revoked", clock.UtcNow), CancellationToken.None);
    Assert(!result.Succeeded, "Revoked collector could upload.");
    Assert(inner.Attempts == 0, "Revoked collector reached inner uploader.");
    Directory.Delete(directory, recursive: true);
}

static async Task HttpsUploaderUsesIdempotencyAsync()
{
    ExpectThrows<ArgumentException>(() => new HttpsMeasurementUploader(
        new Uri("http://collector.example.invalid/measurements"),
        () => "credential",
        new RecordingHttpsTransport(),
        TimeSpan.FromSeconds(10)));

    var transport = new RecordingHttpsTransport();
    var uploader = new HttpsMeasurementUploader(
        new Uri("https://collector.example.invalid/measurements"),
        () => "credential",
        transport,
        TimeSpan.FromSeconds(10));
    var measurement = SampleMeasurement("idempotent-measurement", DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var result = await uploader.UploadAsync(measurement, CancellationToken.None);

    Assert(result.Succeeded, "HTTPS mock transport rejected upload.");
    Assert(transport.LastRequest?.IdempotencyKey == measurement.MeasurementId, "Uploader did not use measurement id as idempotency key.");
}

static async Task StatusOutputAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-06T16:42:00Z"));
    var identity = new CollectorIdentityStore(directory, clock).LoadOrCreate();
    var runner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        new ConsoleMockUploader(new TestLogger()));
    await runner.RunCycleAsync(CancellationToken.None);
    var status = CollectorStatusPresenter.Create(
        identity,
        new EnrollmentSnapshot(EnrollmentState.Connected, null, null, null),
        runner,
        await runner.GetBufferedMeasurementCountAsync(CancellationToken.None));

    Assert(status.Contains("Collector ID:", StringComparison.Ordinal), "Status omitted collector id.");
    Assert(status.Contains("Reader: MockVigoReader", StringComparison.Ordinal), "Status omitted reader type.");
    Assert(status.Contains("Vigo connectivity: True", StringComparison.Ordinal), "Status omitted connectivity.");
    Assert(!status.Contains("credential", StringComparison.OrdinalIgnoreCase), "Status exposed credentials.");
    Directory.Delete(directory, recursive: true);
}

static async Task SoakTestStopsAtDurationAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-08T15:00:00Z"));
    var uploader = new LocalOnlyAcknowledgingUploader();
    var runner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        uploader,
        samplingInterval: TimeSpan.FromSeconds(10));
    var console = new List<string>();
    var summary = await new VigoSoakTestRunner(
        runner,
        clock,
        new AdvancingDelay(clock),
        new TestLogger(),
        console.Add).RunAsync(
        new SoakTestOptions(
            TimeSpan.FromSeconds(30),
            TimeSpan.FromSeconds(10),
            TimeSpan.FromSeconds(15)),
        CancellationToken.None);

    Assert(summary.CollectorExit == SoakTestExit.Normal, "Soak test did not stop normally at duration.");
    Assert(summary.TotalCycles == 3 && summary.SuccessfulCycles == 3, "Soak test used the wrong number of cycles.");
    Assert(summary.FailedCycles == 0, "Healthy soak test reported a failure.");
    Assert(summary.AverageReadDuration is { } average && average > TimeSpan.Zero, "Soak test did not calculate latency.");
    Assert(summary.LastSuccessfulReading is not null, "Soak test lost the final measurement.");
    Assert(uploader.AcknowledgedCount == 3, "Soak test did not use the local acknowledgement path.");
    Assert(!runner.Status.Running, "Soak test did not stop its foreground runner.");
    Assert(console.Contains("Fjellfisk VIGO Soak Test"), "Soak test did not emit a periodic summary.");

    var summaryPath = Path.Combine(directory, "soak-test-summary.json");
    await SoakTestSummaryFile.WriteAsync(summaryPath, summary, CancellationToken.None);
    using var summaryJson = JsonDocument.Parse(await File.ReadAllTextAsync(summaryPath));
    Assert(summaryJson.RootElement.GetProperty("totalCycles").GetInt32() == 3, "Summary file omitted the cycle count.");
    Directory.Delete(directory, recursive: true);
}

static async Task SoakStatisticsCountFailuresAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-08T15:00:00Z"));
    var timeoutRunner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        new LocalOnlyAcknowledgingUploader(),
        reader: new ThrowingReader(new TimeoutException("Read timed out.")),
        samplingInterval: TimeSpan.FromSeconds(10));
    var timeoutSummary = await new VigoSoakTestRunner(
        timeoutRunner,
        clock,
        new AdvancingDelay(clock),
        new TestLogger()).RunAsync(
        new SoakTestOptions(
            TimeSpan.FromSeconds(25),
            TimeSpan.FromSeconds(10),
            TimeSpan.FromSeconds(10)),
        CancellationToken.None);

    Assert(timeoutSummary.TotalCycles == 2 && timeoutSummary.FailedCycles == 2, "Failed soak cycles were counted incorrectly.");
    Assert(timeoutSummary.Timeouts == 2, "Timeout cycles were not counted.");
    Assert(timeoutSummary.LongestConsecutiveFailurePeriod == TimeSpan.FromSeconds(25), "Failure period was not tracked to test end.");

    var comRunner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "com-buffer.jsonl"), BufferOptions.Default, clock),
        new LocalOnlyAcknowledgingUploader(),
        reader: new ThrowingReader(new System.Reflection.TargetInvocationException(
            new COMException("Unknown name", unchecked((int)0x80020006)))),
        samplingInterval: TimeSpan.FromSeconds(10));
    var comCycle = await comRunner.RunCycleAsync(CancellationToken.None);
    Assert(comCycle.IsComError, "Wrapped COM errors were not classified as COM errors.");

    var statistics = new SoakTestStatistics();
    statistics.RecordCycle(
        clock.UtcNow,
        comCycle,
        comRunner.Snapshot);
    var statisticsSummary = statistics.CreateSummary(
        clock.UtcNow,
        clock.UtcNow.AddSeconds(15),
        TimeSpan.FromSeconds(15),
        SoakTestExit.Normal);
    Assert(statisticsSummary.ComErrors == 1, "COM errors were not counted.");
    Directory.Delete(directory, recursive: true);
}

static async Task SoakTestHandlesCancellationAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-08T15:00:00Z"));
    using var cancellation = new CancellationTokenSource();
    var runner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        new LocalOnlyAcknowledgingUploader(),
        samplingInterval: TimeSpan.FromSeconds(10));
    var summary = await new VigoSoakTestRunner(
        runner,
        clock,
        new CancellingAdvancingDelay(clock, cancellation),
        new TestLogger()).RunAsync(
        new SoakTestOptions(
            TimeSpan.FromHours(1),
            TimeSpan.FromSeconds(10),
            TimeSpan.FromMinutes(15)),
        cancellation.Token);

    Assert(summary.CollectorExit == SoakTestExit.Cancelled, "Cancellation did not produce a controlled soak exit.");
    Assert(summary.TotalCycles == 1, "Cancellation did not stop after the active cycle.");
    Assert(!runner.Status.Running, "Collector remained running after cancellation.");
    Directory.Delete(directory, recursive: true);
}

static Task SoakLogRotationAsync()
{
    var directory = CreateTemporaryDirectory();
    var logger = new RollingFileLogger(
        directory,
        writeToConsole: false,
        fileName: "vigo-soak-test.log",
        maxLogBytes: 100,
        maxArchives: 2);

    for (var index = 0; index < 10; index++)
    {
        logger.Log("soak_cycle", new string('x', 120));
    }

    Assert(File.Exists(logger.LogPath), "The active soak log was not created.");
    Assert(File.Exists(logger.LogPath + ".1"), "Soak log did not rotate.");
    Assert(Directory.GetFiles(directory).Length <= 3, "Soak log rotation exceeded its archive cap.");
    Directory.Delete(directory, recursive: true);
    return Task.CompletedTask;
}

static async Task SoakTestStaysLocalOnlyAsync()
{
    var directory = CreateTemporaryDirectory();
    var clock = new FakeClock(DateTimeOffset.Parse("2026-10-08T15:00:00Z"));
    var uploader = new LocalOnlyAcknowledgingUploader();
    var runner = CreateRunner(
        clock,
        new LocalJsonlBuffer(Path.Combine(directory, "buffer.jsonl"), BufferOptions.Default, clock),
        uploader,
        samplingInterval: TimeSpan.FromSeconds(10));

    await new VigoSoakTestRunner(
        runner,
        clock,
        new AdvancingDelay(clock),
        new TestLogger()).RunAsync(
        new SoakTestOptions(
            TimeSpan.FromSeconds(10),
            TimeSpan.FromSeconds(10),
            TimeSpan.FromMinutes(15)),
        CancellationToken.None);

    Assert(uploader.AcknowledgedCount == 1, "Soak test did not use its local-only uploader.");
    var soakFieldTypes = typeof(VigoSoakTestRunner)
        .GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
        .Select(field => field.FieldType)
        .ToArray();
    Assert(!soakFieldTypes.Contains(typeof(CollectorServiceHost)), "Soak test should not host a Windows service.");
    Assert(!soakFieldTypes.Contains(typeof(HttpsMeasurementUploader)), "Soak test should not hold a production uploader.");
    Directory.Delete(directory, recursive: true);
}

static CollectorRunner CreateRunner(
    IClock clock,
    LocalJsonlBuffer buffer,
    IUploader uploader,
    ISensorReader? reader = null,
    TimeSpan? samplingInterval = null) =>
    new(
        new CollectorOptions("collector", "pacific-01", samplingInterval ?? TimeSpan.FromSeconds(15)),
        reader ?? new MockVigoReader(clock),
        new MeasurementNormalizer(clock),
        buffer,
        uploader,
        new TestLogger());

static SensorMeasurement SampleMeasurement(string id, DateTimeOffset timestamp) =>
    new(id, "fjellfisk-vigo-pilot-01", "pacific-01", timestamp, 9.52f, 11.66f, 101.85f, "ok");

static string CreateTemporaryDirectory()
{
    var directory = Path.Combine(Path.GetTempPath(), $"fjellfisk-collector-tests-{Guid.NewGuid():N}");
    Directory.CreateDirectory(directory);
    return directory;
}

static void ExpectThrows<TException>(Action action)
    where TException : Exception
{
    try
    {
        action();
    }
    catch (TException)
    {
        return;
    }

    throw new InvalidOperationException($"Expected {typeof(TException).Name}.");
}

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

sealed class FakeClock : IClock
{
    public FakeClock(DateTimeOffset utcNow)
    {
        UtcNow = utcNow;
    }

    public DateTimeOffset UtcNow { get; set; }
}

sealed class FakeDiagnosticSession : IVigoDiagnosticSession
{
    public Exception? SelectException { get; init; }

    public int CreateCalls { get; private set; }

    public int SelectCalls { get; private set; }

    public int ValueCalls { get; private set; }

    public int ErrorCodeCalls { get; private set; }

    public List<string> SelectedPhysIds { get; } = new();

    public void CreateCom() => CreateCalls++;

    public VigoTypeInformationReport DescribePublicMembers() => new(
        new[]
        {
            new VigoComMember("SetPhysId", "INVOKE_FUNC"),
            new VigoComMember("GetValue", "INVOKE_FUNC"),
            new VigoComMember("ErrorCode", "INVOKE_PROPERTYGET"),
        },
        null);

    public void SelectTemperaturePhysIdProperty(string physId)
    {
        SelectCalls++;
        SelectedPhysIds.Add(physId);
        if (SelectException is not null)
        {
            throw SelectException;
        }
    }

    public object ReadScalarValueProperty()
    {
        ValueCalls++;
        return 9.52f;
    }

    public object ReadErrorCodeProperty()
    {
        ErrorCodeCalls++;
        return 0;
    }

    public void Dispose()
    {
    }
}

sealed class CountingReader : ISensorReader
{
    private readonly IClock _clock;

    public CountingReader(IClock clock)
    {
        _clock = clock;
    }

    public int ReadCount { get; private set; }

    public string ReaderName => "CountingReader";

    public Task<SensorReadResult> ReadAsync(SensorDefinition sensor, CancellationToken cancellationToken)
    {
        ReadCount++;
        var value = sensor.Kind switch
        {
            SensorKind.TemperatureC => 9.52f,
            SensorKind.OxygenMgL => 11.66f,
            _ => 101.85f,
        };
        return Task.FromResult(new SensorReadResult(
            sensor,
            value,
            ErrorCode: 0,
            PnetDataType: 36,
            DotNetType: "System.Single",
            TimestampUtc: _clock.UtcNow,
            Duration: TimeSpan.FromMilliseconds(15)));
    }
}

sealed class FailingOnceUploader : IUploader
{
    public List<string> MeasurementIds { get; } = new();

    public Task<UploadResult> UploadAsync(SensorMeasurement measurement, CancellationToken cancellationToken)
    {
        MeasurementIds.Add(measurement.MeasurementId);
        return Task.FromResult(MeasurementIds.Count == 1
            ? new UploadResult(false, "Mock network unavailable.")
            : UploadResult.Success);
    }
}

sealed class RecordingUploader : IUploader
{
    public int Attempts { get; private set; }

    public Task<UploadResult> UploadAsync(SensorMeasurement measurement, CancellationToken cancellationToken)
    {
        Attempts++;
        return Task.FromResult(UploadResult.Success);
    }
}

sealed class OrderedRecordingUploader : IUploader
{
    public List<string> MeasurementIds { get; } = new();

    public Task<UploadResult> UploadAsync(SensorMeasurement measurement, CancellationToken cancellationToken)
    {
        MeasurementIds.Add(measurement.MeasurementId);
        return Task.FromResult(UploadResult.Success);
    }
}

sealed class RecordingHttpsTransport : ICollectorHttpsTransport
{
    public CollectorUploadRequest? LastRequest { get; private set; }

    public Task<UploadResult> SendAsync(CollectorUploadRequest request, CancellationToken cancellationToken)
    {
        LastRequest = request;
        return Task.FromResult(UploadResult.Success);
    }
}

sealed class CancellingDelay : IAsyncDelay
{
    private readonly CancellationTokenSource _cancellation;

    public CancellingDelay(CancellationTokenSource cancellation)
    {
        _cancellation = cancellation;
    }

    public TimeSpan? LastDelay { get; private set; }

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
    {
        LastDelay = delay;
        _cancellation.Cancel();
        return Task.CompletedTask;
    }
}

sealed class AdvancingDelay : IAsyncDelay
{
    private readonly FakeClock _clock;

    public AdvancingDelay(FakeClock clock)
    {
        _clock = clock;
    }

    public List<TimeSpan> Delays { get; } = new();

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Delays.Add(delay);
        _clock.UtcNow = _clock.UtcNow.Add(delay);
        return Task.CompletedTask;
    }
}

sealed class CancellingAdvancingDelay : IAsyncDelay
{
    private readonly FakeClock _clock;
    private readonly CancellationTokenSource _cancellation;

    public CancellingAdvancingDelay(FakeClock clock, CancellationTokenSource cancellation)
    {
        _clock = clock;
        _cancellation = cancellation;
    }

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
    {
        _clock.UtcNow = _clock.UtcNow.Add(delay);
        _cancellation.Cancel();
        return Task.CompletedTask;
    }
}

sealed class ThrowingReader : ISensorReader
{
    private readonly Exception _exception;

    public ThrowingReader(Exception exception)
    {
        _exception = exception;
    }

    public string ReaderName => "ThrowingReader";

    public Task<SensorReadResult> ReadAsync(SensorDefinition sensor, CancellationToken cancellationToken) =>
        Task.FromException<SensorReadResult>(_exception);
}

sealed class InventoryTestReader : ISensorReader
{
    private readonly IClock _clock;

    public InventoryTestReader(IClock clock)
    {
        _clock = clock;
    }

    public Dictionary<string, Exception> Exceptions { get; } = new(StringComparer.Ordinal);

    public Dictionary<string, SensorReadResult> Readings { get; } = new(StringComparer.Ordinal);

    public List<string> ReadKeys { get; } = new();

    public string ReaderName => "InventoryTestReader";

    public Task<SensorReadResult> ReadAsync(SensorDefinition sensor, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ReadKeys.Add(sensor.Key);
        if (Exceptions.TryGetValue(sensor.Key, out var exception))
        {
            return Task.FromException<SensorReadResult>(exception);
        }

        if (Readings.TryGetValue(sensor.Key, out var reading))
        {
            return Task.FromResult(reading);
        }

        return Task.FromResult(CreateReading(sensor));
    }

    public SensorReadResult CreateReading(SensorDefinition sensor, int errorCode = 0) =>
        new(
            sensor,
            sensor.Kind switch
            {
                SensorKind.TemperatureC => 9.52f,
                SensorKind.OxygenMgL => 11.66f,
                SensorKind.OxygenSaturationPct => 101.85f,
                _ => throw new ArgumentOutOfRangeException(nameof(sensor)),
            },
            errorCode,
            PnetDataType: 36,
            DotNetType: "System.Single",
            TimestampUtc: _clock.UtcNow,
            Duration: TimeSpan.FromMilliseconds(15));
}

sealed class RecordingBatchBuffer : ICollectorBatchBuffer
{
    public List<CollectorBatch> Batches { get; } = new();

    public Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Batches.Add(batch);
        return Task.CompletedTask;
    }
}

sealed class InMemoryVigoConfigurationSource : IVigoConfigurationDiscoverySource
{
    private readonly IReadOnlyCollection<string> _references;

    public InMemoryVigoConfigurationSource(string name, IReadOnlyCollection<string> references)
    {
        Name = name;
        _references = references;
    }

    public string Name { get; }

    public Task<IReadOnlyCollection<string>> ReadObjectReferencesAsync(
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(_references);
    }
}

sealed class ThrowingVigoConfigurationSource : IVigoConfigurationDiscoverySource
{
    public ThrowingVigoConfigurationSource(string name)
    {
        Name = name;
    }

    public string Name { get; }

    public Task<IReadOnlyCollection<string>> ReadObjectReferencesAsync(
        CancellationToken cancellationToken) =>
        Task.FromException<IReadOnlyCollection<string>>(new IOException("Configuration is unavailable."));
}

sealed class PairingBackendFake : ICollectorPairingBackend
{
    private readonly FakeClock _clock;
    private int _codeCounter;
    private CollectorBackendIdentity? _identity;

    public PairingBackendFake(FakeClock clock)
    {
        _clock = clock;
    }

    public int RegistrationCalls { get; private set; }

    public string LastRegisteredCollectorId => _identity?.CollectorId ?? string.Empty;

    public string DeviceCredential { get; } = "credential-abcdefghijklmnopqrstuvwxyz-012345";

    public string State { get; set; } = "UNPAIRED";

    public bool ThrowStatusUnavailable { get; set; }

    public bool ThrowAuthenticationFailure { get; set; }

    public Task<CollectorBackendIdentity> RegisterAsync(
        string collectorVersion,
        string platform,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        RegistrationCalls++;
        _identity ??= new CollectorBackendIdentity("backend-collector-01", DeviceCredential);
        return Task.FromResult(_identity);
    }

    public Task<CollectorBackendStatus> GetStatusAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ValidateIdentity(identity);
        if (ThrowStatusUnavailable)
        {
            throw new CollectorPairingBackendException("BACKEND_UNAVAILABLE");
        }

        return Task.FromResult(Status(identity.CollectorId));
    }

    public Task<(CollectorBackendStatus Status, PairingCodePresentation? PairingCode)> IssuePairingCodeAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ValidateIdentity(identity);
        var status = Status(identity.CollectorId);
        if (State != "UNPAIRED")
        {
            return Task.FromResult((status, (PairingCodePresentation?)null));
        }

        _codeCounter++;
        return Task.FromResult((
            status,
            (PairingCodePresentation?)new PairingCodePresentation(
                $"FJ-TEST-CODE-{_codeCounter:D2}",
                _clock.UtcNow.AddMinutes(10))));
    }

    private CollectorBackendStatus Status(string collectorId) =>
        new(collectorId, State, null, null, State == "PAIRED" ? _clock.UtcNow : null);

    private void ValidateIdentity(CollectorBackendIdentity identity)
    {
        if (ThrowAuthenticationFailure || !string.Equals(identity.DeviceCredential, DeviceCredential, StringComparison.Ordinal))
        {
            throw new CollectorPairingBackendException("COLLECTOR_AUTH_FAILED", HttpStatusCode.Unauthorized);
        }
    }
}

sealed class TestPairingUi : ICollectorPairingUi
{
    public event EventHandler? RetryRequested;

    public List<PairingCodePresentation> Codes { get; } = new();

    public int WindowsCreated { get; private set; }

    public int BackendUnavailableCalls { get; private set; }

    public int CloseCalls { get; private set; }

    public bool IsOpen { get; private set; }

    public Task ShowPairingCodeAsync(PairingCodePresentation pairingCode, CancellationToken cancellationToken)
    {
        if (!IsOpen)
        {
            WindowsCreated++;
        }

        IsOpen = true;
        Codes.Add(pairingCode);
        return Task.CompletedTask;
    }

    public Task ShowBackendUnavailableAsync(CancellationToken cancellationToken)
    {
        if (!IsOpen)
        {
            WindowsCreated++;
        }

        IsOpen = true;
        BackendUnavailableCalls++;
        return Task.CompletedTask;
    }

    public Task CloseAsync(CancellationToken cancellationToken)
    {
        CloseCalls++;
        IsOpen = false;
        return Task.CompletedTask;
    }

    public void CloseManually() => IsOpen = false;

    public void RequestRetry() => RetryRequested?.Invoke(this, EventArgs.Empty);
}

sealed class CapturingPairingUi : ICollectorPairingUi
{
    private readonly ICollectorPairingUi _inner;

    public CapturingPairingUi(ICollectorPairingUi inner)
    {
        _inner = inner;
    }

    public event EventHandler? RetryRequested
    {
        add => _inner.RetryRequested += value;
        remove => _inner.RetryRequested -= value;
    }

    public List<PairingCodePresentation> Codes { get; } = new();

    public async Task ShowPairingCodeAsync(PairingCodePresentation pairingCode, CancellationToken cancellationToken)
    {
        Codes.Add(pairingCode);
        await _inner.ShowPairingCodeAsync(pairingCode, cancellationToken);
    }

    public Task ShowBackendUnavailableAsync(CancellationToken cancellationToken) =>
        _inner.ShowBackendUnavailableAsync(cancellationToken);

    public Task CloseAsync(CancellationToken cancellationToken) => _inner.CloseAsync(cancellationToken);
}

sealed class PairingTestDelay : ICollectorPairingDelay
{
    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken) => Task.CompletedTask;
}

sealed class TestPairingLogger : ICollectorPairingLogger
{
    public List<string> Messages { get; } = new();

    public void Log(string eventName, string message)
    {
        Messages.Add($"{eventName}:{message}");
    }
}

sealed class PairingHttpHandler : HttpMessageHandler
{
    private readonly Queue<HttpResponseMessage> _responses;

    public PairingHttpHandler(params HttpResponseMessage[] responses)
    {
        _responses = new Queue<HttpResponseMessage>(responses);
    }

    public List<(string Method, string Path, string? CollectorId, string? Credential)> Requests { get; } = new();

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests.Add((
            request.Method.Method,
            request.RequestUri?.AbsolutePath ?? string.Empty,
            request.Headers.TryGetValues("x-fjellfisk-collector-id", out var collectorIds) ? collectorIds.Single() : null,
            request.Headers.TryGetValues("x-fjellfisk-device-credential", out var credentials) ? credentials.Single() : null));
        return Task.FromResult(_responses.Dequeue());
    }
}

sealed class TestLogger : ICollectorLogger
{
    public void Log(string eventName, string message)
    {
    }
}

sealed class CapturingLogger : ICollectorLogger
{
    public List<string> Messages { get; } = new();

    public void Log(string eventName, string message)
    {
        Messages.Add($"{eventName}:{message}");
    }
}
