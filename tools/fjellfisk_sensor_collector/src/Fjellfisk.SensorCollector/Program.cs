using Fjellfisk.SensorCollector;

var arguments = args.ToList();
var dataDirectory = GetDataDirectory(arguments) ?? CollectorIdentityStore.DefaultDataDirectory;
if (HasSwitch(arguments, "--vigo-dom-inventory"))
{
    return await RunVigoDomInventoryAsync(dataDirectory);
}

if (HasSwitch(arguments, "--vigo-inventory"))
{
    return await RunVigoInventoryAsync(dataDirectory);
}

if (HasSwitch(arguments, "--vigo-diagnostics"))
{
    var diagnosticsLogger = new RollingFileLogger(Path.Combine(dataDirectory, "logs"));
    Console.WriteLine("VIGO diagnostics runs one read-only temperature sequence with no upload, retry, polling, service, or autostart.");
    using var diagnosticsSession = new VigoComDiagnosticSession();
    var diagnosticResult = new VigoDiagnosticsRunner(diagnosticsLogger).Run(diagnosticsSession);
    PrintDiagnostics(diagnosticResult);
    return diagnosticResult.Succeeded ? 0 : 1;
}

if (HasSwitch(arguments, "--vigo-soak-test"))
{
    return await RunVigoSoakTestAsync(arguments, dataDirectory);
}

var runtime = CreateRuntime(
    dataDirectory,
    useOxyGuardVigoReader: HasSwitch(arguments, "--vigo-pilot"));

if (HasSwitch(arguments, "--identity"))
{
    PrintIdentity(runtime.Identity, runtime.LocalState.GetEnrollmentSnapshot());
    return 0;
}

if (HasSwitch(arguments, "--status"))
{
    var bufferedCount = await runtime.Runner.GetBufferedMeasurementCountAsync(CancellationToken.None);
    Console.WriteLine(CollectorStatusPresenter.Create(
        runtime.Identity,
        runtime.LocalState.GetEnrollmentSnapshot(),
        runtime.Runner,
        bufferedCount));
    return 0;
}

if (HasSwitch(arguments, "--enroll"))
{
    var coordinator = new EnrollmentCoordinator(
        runtime.Identity,
        runtime.LocalState,
        new MockEnrollmentProvider(SystemClock.Instance),
        SystemClock.Instance,
        runtime.Logger);
    var enrollment = await coordinator.StartOrResumeAsync(CancellationToken.None);
    PrintEnrollment(enrollment);
    return enrollment.State == EnrollmentState.Error ? 1 : 0;
}

if (HasSwitch(arguments, "--vigo-pilot"))
{
    Console.WriteLine("VIGO pilot mode is read-only. It samples only the three compiled allowlist values.");
    Console.WriteLine("No production upload, service installation, autostart, or VIGO configuration is performed.");
    return await RunCollectorAsync(runtime, GetCycleCount(arguments));
}

var mockupMode = HasSwitch(arguments, "--mockup");
if (HasSwitch(arguments, "--once"))
{
    var result = await runtime.Runner.RunCycleAsync(CancellationToken.None);
    Console.WriteLine(result.Success ? "Mock collector cycle completed." : result.Error);
    return result.Success ? 0 : 1;
}

if (mockupMode)
{
    using var mockup = new ConsoleCollectorMockup(runtime.Runner);
    return await RunCollectorAsync(runtime, GetCycleCount(arguments));
}

return await RunCollectorAsync(runtime, GetCycleCount(arguments));

static CollectorRuntime CreateRuntime(string dataDirectory, bool useOxyGuardVigoReader)
{
    var identity = new CollectorIdentityStore(dataDirectory, SystemClock.Instance).LoadOrCreate();
    var logger = new RollingFileLogger(Path.Combine(dataDirectory, "logs"));
    var localState = new CollectorLocalStateStore(dataDirectory);
    var reader = useOxyGuardVigoReader
        ? (ISensorReader)new OxyGuardVigoReader(
            SystemClock.Instance,
            CompiledSensorAllowlist.Instance)
        : new MockVigoReader(SystemClock.Instance);
    var runner = new CollectorRunner(
        new CollectorOptions(identity.CollectorDeviceId, "pacific-01", TimeSpan.FromSeconds(15)),
        reader,
        new MeasurementNormalizer(SystemClock.Instance),
        new LocalJsonlBuffer(
            Path.Combine(dataDirectory, "collector-buffer.jsonl"),
            BufferOptions.Default,
            SystemClock.Instance),
        new ConsoleMockUploader(logger),
        logger);
    return new CollectorRuntime(identity, localState, logger, runner);
}

static async Task<int> RunCollectorAsync(CollectorRuntime runtime, int? cycleCount)
{
    if (cycleCount is not null)
    {
        await runtime.Runner.RunCyclesAsync(cycleCount.Value, CancellationToken.None);
        return 0;
    }

    using var shutdown = new CancellationTokenSource();
    Console.CancelKeyPress += (_, eventArgs) =>
    {
        eventArgs.Cancel = true;
        shutdown.Cancel();
    };
    await runtime.Runner.RunAsync(shutdown.Token);
    return 0;
}

static async Task<int> RunVigoSoakTestAsync(
    IReadOnlyList<string> arguments,
    string dataDirectory)
{
    if (GetCycleCount(arguments) is not null)
    {
        throw new ArgumentException("--cycles cannot be used with --vigo-soak-test.");
    }

    var duration = GetSoakDuration(arguments);
    var samplingInterval = GetSoakSamplingInterval(arguments);
    var logsDirectory = Path.Combine(dataDirectory, "logs");
    var logFileName = $"vigo-soak-{DateTimeOffset.Now:yyyy-MM-dd_HHmm}.log";
    var logger = new RollingFileLogger(logsDirectory, writeToConsole: false, fileName: logFileName);
    var identity = new CollectorIdentityStore(dataDirectory, SystemClock.Instance).LoadOrCreate();
    using var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        CompiledSensorAllowlist.Instance);
    var runner = new CollectorRunner(
        new CollectorOptions(identity.CollectorDeviceId, "pacific-01", samplingInterval),
        reader,
        new MeasurementNormalizer(SystemClock.Instance),
        new LocalJsonlBuffer(
            Path.Combine(dataDirectory, "vigo-soak-buffer.jsonl"),
            BufferOptions.Default,
            SystemClock.Instance),
        new LocalOnlyAcknowledgingUploader(),
        logger);
    var options = new SoakTestOptions(
        duration,
        samplingInterval,
        SoakTestOptions.DefaultPeriodicSummaryInterval);

    Console.WriteLine("VIGO soak test is read-only and runs only the three compiled allowlist values.");
    Console.WriteLine("No production upload, Firebase, service installation, autostart, or VIGO configuration is performed.");
    Console.WriteLine($"Duration: {duration}. Sampling interval: {samplingInterval.TotalSeconds:F0} seconds.");
    Console.WriteLine($"Detailed local log: {logger.LogPath}");

    using var shutdown = new CancellationTokenSource();
    ConsoleCancelEventHandler cancelHandler = (_, eventArgs) =>
    {
        eventArgs.Cancel = true;
        shutdown.Cancel();
    };
    Console.CancelKeyPress += cancelHandler;

    try
    {
        var summary = await new VigoSoakTestRunner(
            runner,
            SystemClock.Instance,
            SystemAsyncDelay.Instance,
            logger).RunAsync(options, shutdown.Token);
        var summaryPath = Path.Combine(dataDirectory, "soak-test-summary.json");
        await SoakTestSummaryFile.WriteAsync(summaryPath, summary, CancellationToken.None);
        PrintSoakSummary(summary, summaryPath);
        return summary.CollectorExit == SoakTestExit.FatalError ? 1 : 0;
    }
    finally
    {
        Console.CancelKeyPress -= cancelHandler;
    }
}

static async Task<int> RunVigoInventoryAsync(string dataDirectory)
{
    Console.WriteLine("FJELLFISK VIGO SENSOR INVENTORY");
    Console.WriteLine("================================");
    Console.WriteLine("Source: Vigo / VIGO.PRO");
    Console.WriteLine("Mode: READ ONLY");
    Console.WriteLine("This runs one sequential pass over the compiled Pacific candidate list.");
    Console.WriteLine("No upload, service, autostart, VIGO configuration, or retry loop is used.");

    using var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        CompiledSensorAllowlist.Instance);
    var report = await new VigoInventoryRunner(reader, SystemClock.Instance).RunAsync(
        VigoInventorySources.Pacific,
        CancellationToken.None);
    var reportPath = Path.Combine(
        dataDirectory,
        "logs",
        $"vigo-inventory-{DateTimeOffset.Now:yyyy-MM-dd_HHmm}.json");
    await VigoInventoryReportFile.PersistAsync(reportPath, report, CancellationToken.None);
    PrintInventory(report, reportPath);
    return 0;
}

static async Task<int> RunVigoDomInventoryAsync(string dataDirectory)
{
    Console.WriteLine("FJELLFISK VIGO DOM SENSOR INVENTORY");
    Console.WriteLine("====================================");
    Console.WriteLine("Source: Vigo / VIGO.PRO");
    Console.WriteLine("Mode: READ ONLY");
    Console.WriteLine("This runs one sequential pass over the 18 compiled DOM channel candidates.");
    Console.WriteLine("No upload, service, autostart, VIGO configuration, or retry loop is used.");

    using var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        CompiledSensorAllowlist.Instance);
    var report = await new VigoInventoryRunner(reader, SystemClock.Instance).RunAsync(
        VigoInventorySources.Dom,
        CancellationToken.None);
    var reportPath = Path.Combine(
        dataDirectory,
        "logs",
        $"vigo-dom-inventory-{DateTimeOffset.Now:yyyy-MM-dd_HHmm}.json");
    await VigoInventoryReportFile.PersistAsync(reportPath, report, CancellationToken.None);
    PrintInventory(report, reportPath);
    return 0;
}

static void PrintIdentity(CollectorIdentity identity, EnrollmentSnapshot enrollment)
{
    Console.WriteLine("FJELLFISK COLLECTOR IDENTITY");
    Console.WriteLine($"Collector ID: {identity.CollectorDeviceId}");
    Console.WriteLine($"Enrollment: {enrollment.State}");
    Console.WriteLine($"Version: {CollectorApplication.Version}");
}

static void PrintEnrollment(EnrollmentSnapshot enrollment)
{
    Console.WriteLine("Fjellfisk Collector");
    Console.WriteLine(enrollment.State == EnrollmentState.Pending ? "Ikke tilkoblet" : enrollment.State.ToString());
    if (enrollment.ClaimCode is { Length: > 0 })
    {
        Console.WriteLine();
        Console.WriteLine($"Tilkoblingskode: {enrollment.ClaimCode}");
        Console.WriteLine("Åpne Fjellfisk: Verktøy -> Add-ons -> Fjellfisk Collector");
    }
}

static void PrintDiagnostics(VigoDiagnosticResult result)
{
    Console.WriteLine();
    Console.WriteLine("VIGO DIAGNOSTICS RESULT");
    Console.WriteLine($"Succeeded: {result.Succeeded}");
    Console.WriteLine($"Duration: {result.Duration.TotalMilliseconds:F0} ms");
    if (result.FailedStage is { Length: > 0 })
    {
        Console.WriteLine($"Failed stage: {result.FailedStage}");
        Console.WriteLine(result.HResult is { } hresult
            ? $"HRESULT: 0x{hresult:X8}"
            : "HRESULT: none");
        Console.WriteLine($"Message: {result.FailureMessage}");
    }
    else
    {
        Console.WriteLine($"Value: {result.Value:F3}");
        Console.WriteLine($"ErrorCode: {result.ErrorCode}");
    }

    if (result.TypeInformation.UnavailableReason is { Length: > 0 } unavailableReason)
    {
        Console.WriteLine($"Type information: unavailable ({unavailableReason})");
        return;
    }

    Console.WriteLine("Public COM members:");
    foreach (var member in result.TypeInformation.Members)
    {
        Console.WriteLine($"- {member.Name} [{member.Kind}]");
    }
}

static void PrintSoakSummary(SoakTestSummary summary, string summaryPath)
{
    Console.WriteLine();
    Console.WriteLine("FJELLFISK VIGO SOAK TEST SUMMARY");
    Console.WriteLine($"Requested duration: {summary.RequestedDuration}");
    Console.WriteLine($"Runtime: {summary.Runtime}");
    Console.WriteLine($"Cycles: {summary.TotalCycles}");
    Console.WriteLine($"Successful: {summary.SuccessfulCycles}");
    Console.WriteLine($"Failed: {summary.FailedCycles}");
    Console.WriteLine($"Success rate: {summary.SuccessPercentage:F2}%");
    Console.WriteLine($"Average read latency: {FormatLatency(summary.AverageReadDuration)}");
    Console.WriteLine($"Maximum read latency: {FormatLatency(summary.MaximumReadDuration)}");
    Console.WriteLine($"COM errors: {summary.ComErrors}");
    Console.WriteLine($"Timeouts: {summary.Timeouts}");
    Console.WriteLine($"Longest failure period: {summary.LongestConsecutiveFailurePeriod}");
    Console.WriteLine(summary.LastSuccessfulReading is { } reading
        ? $"Last reading: {reading.TimestampUtc:O} temperatureC={reading.TemperatureC:F3} oxygenMgL={reading.OxygenMgL:F3} oxygenSaturationPct={reading.OxygenSaturationPct:F3}"
        : "Last reading: none");
    Console.WriteLine($"Buffer count: {summary.BufferCount}");
    Console.WriteLine($"Collector exit: {summary.CollectorExit}");
    Console.WriteLine($"Summary file: {summaryPath}");
}

static void PrintInventory(VigoInventoryReport report, string reportPath)
{
    foreach (var device in report.Devices)
    {
        Console.WriteLine();
        Console.WriteLine(device.DisplayName);
        foreach (var key in new[] { "temperatureC", "oxygenMgL", "oxygenSaturationPct" })
        {
            var measurement = device.Measurements[key];
            var result = measurement.Success && measurement.Value is { } value
                ? $"{value,7:F2} {measurement.Unit,-4} OK"
                : $"unavailable ({measurement.FailureKind})";
            Console.WriteLine($"  {measurement.Label,-17} {result}");
        }
    }

    var summary = report.Summary;
    Console.WriteLine();
    Console.WriteLine("Summary");
    Console.WriteLine("-------");
    Console.WriteLine($"Candidates tested: {summary.CandidatesTested}");
    var readableLabel = string.Equals(report.SensorFamily, "DOM", StringComparison.Ordinal)
        ? "Readable channels"
        : "Readable probes";
    Console.WriteLine($"{readableLabel}: {summary.ReadableSensors}");
    Console.WriteLine($"Measurement channels: {summary.SuccessfulMeasurementChannels}/{summary.MeasurementChannels}");
    Console.WriteLine($"Failed reads: {summary.FailedReads}");
    Console.WriteLine($"COM errors: {summary.ComErrors}");
    Console.WriteLine($"Timeouts: {summary.Timeouts}");
    Console.WriteLine($"Inventory JSON: {reportPath}");
}

static bool HasSwitch(IReadOnlyCollection<string> arguments, string value) =>
    arguments.Contains(value, StringComparer.OrdinalIgnoreCase);

static string? GetDataDirectory(IReadOnlyList<string> arguments)
{
    const string prefix = "--data-dir=";
    var value = arguments.FirstOrDefault(argument =>
        argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    return value is null ? null : value[prefix.Length..];
}

static int? GetCycleCount(IReadOnlyList<string> arguments)
{
    const string prefix = "--cycles=";
    var value = arguments.FirstOrDefault(argument =>
        argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    if (value is null)
    {
        return null;
    }

    if (!int.TryParse(value[prefix.Length..], out var cycleCount) || cycleCount < 1)
    {
        throw new ArgumentException("--cycles must be a positive whole number.");
    }

    return cycleCount;
}

static TimeSpan GetSoakDuration(IReadOnlyList<string> arguments)
{
    const string prefix = "--duration=";
    var value = arguments.FirstOrDefault(argument =>
        argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    if (value is null)
    {
        return SoakTestOptions.DefaultDuration;
    }

    return value[prefix.Length..].Trim().ToLowerInvariant() switch
    {
        "1h" => TimeSpan.FromHours(1),
        "8h" => TimeSpan.FromHours(8),
        "24h" => TimeSpan.FromHours(24),
        "72h" => TimeSpan.FromHours(72),
        _ => throw new ArgumentException("--duration must be one of: 1h, 8h, 24h, 72h."),
    };
}

static TimeSpan GetSoakSamplingInterval(IReadOnlyList<string> arguments)
{
    const string prefix = "--sampling-seconds=";
    var value = arguments.FirstOrDefault(argument =>
        argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    if (value is null)
    {
        return SoakTestOptions.DefaultSamplingInterval;
    }

    if (!int.TryParse(value[prefix.Length..], out var seconds) ||
        seconds < CollectorOptions.MinimumSamplingInterval.TotalSeconds)
    {
        throw new ArgumentException(
            $"--sampling-seconds must be a whole number of at least {CollectorOptions.MinimumSamplingInterval.TotalSeconds:0}.");
    }

    return TimeSpan.FromSeconds(seconds);
}

static string FormatLatency(TimeSpan? duration) => duration is { } value
    ? $"{value.TotalMilliseconds:F1} ms"
    : "n/a";

sealed record CollectorRuntime(
    CollectorIdentity Identity,
    CollectorLocalStateStore LocalState,
    ICollectorLogger Logger,
    CollectorRunner Runner);
