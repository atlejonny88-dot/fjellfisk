using System.Diagnostics;
using Fjellfisk.SensorCollector;

var arguments = args.ToList();
try
{
    var command = ProductionCliPolicy.Parse(arguments);
    if (command == ProductionCommand.Help)
    {
        PrintUsage();
        return 0;
    }

    var layout = ProductionStorageLayout.Open(GetDataDirectory(arguments));
    var lockFileName = command switch
    {
        ProductionCommand.Pairing or ProductionCommand.Run => "collector-run.lock",
        ProductionCommand.RunWorker => "collector-worker.lock",
        _ => null,
    };
    using var instanceLock = lockFileName is null
        ? null
        : new FileStream(Path.Combine(layout.RootDirectory, lockFileName), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
    var identity = new CollectorIdentityStore(layout.IdentityDirectory, SystemClock.Instance).LoadOrCreate();
    var pairingState = new CollectorPairingStateStore(layout.IdentityDirectory);
    var metadata = CollectorBuildMetadata.Current;

    switch (command)
    {
        case ProductionCommand.Identity:
            Console.WriteLine("FJELLFISK PRODUCTION COLLECTOR IDENTITY");
            Console.WriteLine($"Collector ID: {identity.CollectorDeviceId}");
            Console.WriteLine($"Product version: {metadata.ProductVersion}");
            Console.WriteLine($"Build version: {metadata.BuildVersion}");
            Console.WriteLine($"Build ID: {metadata.BuildId}");
            Console.WriteLine($"Backend pairing identity: {(pairingState.HasBackendIdentity ? "registered" : "not registered")}");
            return 0;

        case ProductionCommand.Status:
            Console.WriteLine("FJELLFISK PRODUCTION COLLECTOR STATUS");
            Console.WriteLine($"Collector ID: {identity.CollectorDeviceId}");
            Console.WriteLine($"Product version: {metadata.ProductVersion}");
            Console.WriteLine($"Build ID: {metadata.BuildId}");
            Console.WriteLine($"Discovery cache: {(File.Exists(layout.DiscoveryCachePath) ? "available" : "not yet created")}");
            Console.WriteLine("VIGO read state: idle");
            var pairingConfiguration = CollectorPairingBackendConfiguration.Load(arguments, layout.ConfigDirectory);
            var storedPairing = pairingState.GetStoredSnapshot(pairingConfiguration.IsConfigured);
            Console.WriteLine($"Pairing backend: {(pairingConfiguration.IsConfigured ? "configured" : "not configured")}");
            Console.WriteLine($"Pairing state: {storedPairing.State}");
            Console.WriteLine($"Backend Collector ID: {storedPairing.CollectorId ?? "not registered"}");
            return 0;

        case ProductionCommand.DiscoveryStatus:
            var discovery = await new ProductionDiscoveryService(
                new[] { new LocalVigoConfigurationDiscoverySource() },
                clock: SystemClock.Instance).DiscoverAsync(CancellationToken.None);
            await ProductionDiscoveryCache.PersistAsync(
                layout.DiscoveryCachePath,
                discovery,
                CancellationToken.None);
            PrintDiscovery(discovery, layout.DiscoveryCachePath);
            return 0;

        case ProductionCommand.ReadOnce:
            return await RunControlledReadOnceAsync(layout, identity, metadata);

        case ProductionCommand.Pairing:
            return await RunPairingAsync(layout, identity, metadata, arguments, collectSensors: false);

        case ProductionCommand.Run:
            return await RunSupervisedCollectorAsync(layout, arguments);

        case ProductionCommand.RunWorker:
            return await RunPairingAsync(layout, identity, metadata, arguments, collectSensors: true);

        default:
            throw new ArgumentOutOfRangeException(nameof(command));
    }
}
catch (CollectorSensorReadStalledException)
{
    Console.Error.WriteLine("Read-only VIGO worker stalled; exiting Collector worker for controlled recovery.");
    return CollectorReadRecoverySupervisor.StalledReaderExitCode;
}
catch (Exception exception)
{
    Console.Error.WriteLine($"Production Collector error: {exception.Message}");
    return 1;
}

static string? GetDataDirectory(IReadOnlyList<string> arguments)
{
    const string prefix = "--data-dir=";
    var value = arguments.FirstOrDefault(argument =>
        argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    return value is null ? null : value[prefix.Length..];
}

static void PrintUsage()
{
    Console.WriteLine("Fjellfisk Production Collector");
    Console.WriteLine("Commands: --identity, --status, --discovery-status, --read-once, --pairing, --run");
    Console.WriteLine("--run performs read-only collection after confirmed pairing; --pairing never reads sensors.");
    Console.WriteLine("Pairing uses HTTPS from pairing-backend.json or FJELLFISK_COLLECTOR_PAIRING_URL.");
    Console.WriteLine("A local emulator additionally requires --pairing-emulator and an explicit loopback URL.");
    Console.WriteLine("The production executable does not expose diagnostic or service commands.");
}

static async Task<int> RunSupervisedCollectorAsync(
    ProductionStorageLayout layout,
    IReadOnlyCollection<string> arguments)
{
    var executablePath = Environment.ProcessPath;
    if (string.IsNullOrWhiteSpace(executablePath))
    {
        throw new InvalidOperationException("Collector executable path is unavailable.");
    }

    using var cancellation = new CancellationTokenSource();
    Console.CancelKeyPress += (_, eventArgs) =>
    {
        eventArgs.Cancel = true;
        cancellation.Cancel();
    };

    var logger = new PairingFileLogger(layout.LogsDirectory);
    var worker = new ProcessCollectorWorker(executablePath, SelectWorkerArguments(arguments));
    var supervisor = new CollectorReadRecoverySupervisor(
        worker,
        logger,
        SystemClock.Instance,
        SystemCollectorRecoveryDelay.Instance);
    Console.WriteLine("Fjellfisk Collector supervisor started. Press Ctrl+C to stop.");
    try
    {
        return await supervisor.RunAsync(cancellation.Token);
    }
    catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
    {
        return 0;
    }
}

static IReadOnlyList<string> SelectWorkerArguments(IReadOnlyCollection<string> arguments)
{
    const string dataDirectoryPrefix = "--data-dir=";
    const string backendUrlPrefix = "--pairing-backend-url=";
    var forwarded = new List<string>();
    foreach (var argument in arguments)
    {
        if (argument.StartsWith(dataDirectoryPrefix, StringComparison.OrdinalIgnoreCase) ||
            argument.StartsWith(backendUrlPrefix, StringComparison.OrdinalIgnoreCase) ||
            string.Equals(argument, "--pairing-emulator", StringComparison.OrdinalIgnoreCase))
        {
            forwarded.Add(argument);
        }
    }

    return forwarded;
}

static async Task<int> RunPairingAsync(
    ProductionStorageLayout layout,
    CollectorIdentity identity,
    CollectorBuildMetadata metadata,
    IReadOnlyCollection<string> arguments,
    bool collectSensors)
{
    var configuration = CollectorPairingBackendConfiguration.Load(arguments, layout.ConfigDirectory);
    if (!configuration.IsConfigured)
    {
        Console.Error.WriteLine(
            "Pairing backend is not configured. Set pairing-backend.json, FJELLFISK_COLLECTOR_PAIRING_URL, or --pairing-backend-url.");
        return 2;
    }

    using var cancellation = new CancellationTokenSource();
    Console.CancelKeyPress += (_, eventArgs) =>
    {
        eventArgs.Cancel = true;
        cancellation.Cancel();
    };

    using var backend = new HttpCollectorPairingBackend(configuration);
    using var pairingWindow = new PairingWindowProcessHost(AppContext.BaseDirectory);
    var stateStore = new CollectorPairingStateStore(layout.IdentityDirectory);
    var logger = new PairingFileLogger(layout.LogsDirectory);
    var sensorDiagnostics = new LocalSensorReadDiagnostics(layout.LogsDirectory, SystemClock.Instance);
    var coordinator = new CollectorPairingCoordinator(
        stateStore,
        backend,
        pairingWindow,
        logger,
        SystemClock.Instance,
        SystemCollectorPairingDelay.Instance,
        metadata.ProductVersion,
        "windows-x86");

    Console.WriteLine($"Fjellfisk Collector pairing started ({configuration.Source}). Press Ctrl+C to stop.");
    try
    {
        if (!collectSensors)
        {
            await coordinator.RunAsync(cancellation.Token);
        }
        else
        {
            using var uploader = new HttpsProductionTelemetryUploader(configuration);
            using var telemetry = new ProductionTelemetrySession(
                async token =>
                {
                    var discovered = await new ProductionDiscoveryService(
                        new[] { new LocalVigoConfigurationDiscoverySource() }).DiscoverAsync(token);
                    await ProductionDiscoveryCache.PersistAsync(layout.DiscoveryCachePath, discovered, token);
                    return discovered;
                },
                allowlist => new OxyGuardVigoReader(
                    SystemClock.Instance,
                    allowlist,
                    diagnostics: sensorDiagnostics),
                identity, metadata,
                new ProductionTelemetryQueue(Path.Combine(layout.BufferDirectory, "sensor-upload")),
                uploader, stateStore, logger, diagnostics: sensorDiagnostics);
            await coordinator.RunAsync(cancellation.Token, telemetry.ReadAndUploadAsync, TimeSpan.FromSeconds(15));
        }
        return 0;
    }
    catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
    {
        return 0;
    }
}

static async Task<int> RunControlledReadOnceAsync(
    ProductionStorageLayout layout,
    CollectorIdentity identity,
    CollectorBuildMetadata metadata)
{
    // Discovery is refreshed from local Vigo configuration for every manual
    // read. The cache is an observation record, never an untrusted input to COM.
    var discovery = await new ProductionDiscoveryService(
        new[] { new LocalVigoConfigurationDiscoverySource() },
        clock: SystemClock.Instance).DiscoverAsync(CancellationToken.None);
    await ProductionDiscoveryCache.PersistAsync(
        layout.DiscoveryCachePath,
        discovery,
        CancellationToken.None);

    var allowlist = discovery.CreateRuntimeAllowlist();
    var output = new LocalProductionReadOutput(layout.BufferDirectory);
    var sensorDiagnostics = new LocalSensorReadDiagnostics(layout.LogsDirectory, SystemClock.Instance);
    using var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        allowlist,
        diagnostics: sensorDiagnostics);
    var runtime = new ProductionCollectorRuntime(
        reader,
        allowlist,
        identity,
        metadata,
        output,
        SystemClock.Instance,
        sensorDiagnostics);
    var batch = await runtime.ReadOneCycleAsync(discovery, CancellationToken.None);
    var summary = ProductionReadSummary.Create(discovery, batch);

    PrintReadOnceSummary(summary, output.LastWrittenPath);
    return 0;
}

static void PrintReadOnceSummary(ProductionReadSummary summary, string? outputPath)
{
    Console.WriteLine("FJELLFISK PRODUCTION READ TEST");
    Console.WriteLine("==============================");
    Console.WriteLine();
    Console.WriteLine("Discovery:");
    Console.WriteLine($"Pacific sensors: {summary.PacificSensors}");
    Console.WriteLine($"DOM sensors: {summary.DomSensors}");
    Console.WriteLine($"Total sensors: {summary.SensorsAttempted}");
    Console.WriteLine();
    Console.WriteLine("Read result:");
    Console.WriteLine($"Sensors attempted: {summary.SensorsAttempted}");
    Console.WriteLine($"Sensors OK: {summary.SensorsOk}");
    Console.WriteLine($"Sensors degraded: {summary.SensorsDegraded}");
    Console.WriteLine($"Sensors failed: {summary.SensorsFailed}");
    Console.WriteLine();
    Console.WriteLine("Measurements:");
    Console.WriteLine($"Successful: {summary.SuccessfulMeasurements}");
    Console.WriteLine($"Failed: {summary.FailedMeasurements}");
    Console.WriteLine();
    Console.WriteLine($"COM errors: {summary.ComErrors}");
    Console.WriteLine($"Timeouts: {summary.Timeouts}");
    Console.WriteLine();
    Console.WriteLine($"Local batch: {outputPath ?? "not written"}");
    Console.WriteLine("Exit: Normal");
}

static void PrintDiscovery(ProductionDiscoveryResult discovery, string cachePath)
{
    Console.WriteLine("FJELLFISK PRODUCTION DISCOVERY STATUS");
    Console.WriteLine($"Discovered sensors: {discovery.Sensors.Count}");
    foreach (var source in discovery.Sources)
    {
        Console.WriteLine($"{source.Type}: devices={source.Devices}, sensors={source.Sensors}");
    }

    Console.WriteLine($"Discovery issues: {discovery.Issues.Count}");
    Console.WriteLine($"Local cache: {cachePath}");
    Console.WriteLine("VIGO read state: idle");
}

// The worker process contains the STA/COM client. It is replaced only after
// it has exited, never by starting another in-process STA reader.
sealed class ProcessCollectorWorker : ICollectorWorkerProcess
{
    private readonly string _executablePath;
    private readonly IReadOnlyList<string> _forwardedArguments;

    public ProcessCollectorWorker(string executablePath, IReadOnlyList<string> forwardedArguments)
    {
        _executablePath = executablePath;
        _forwardedArguments = forwardedArguments;
    }

    public async Task<int> RunAsync(CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo(_executablePath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        startInfo.ArgumentList.Add("--run-worker");
        foreach (var argument in _forwardedArguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ??
            throw new InvalidOperationException("Unable to start the Collector worker process.");
        using var cancellationRegistration = cancellationToken.Register(() =>
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }
            }
            catch (InvalidOperationException)
            {
                // The process exited concurrently with cancellation.
            }
        });

        try
        {
            await process.WaitForExitAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            await process.WaitForExitAsync();
            throw;
        }

        return process.ExitCode;
    }
}
