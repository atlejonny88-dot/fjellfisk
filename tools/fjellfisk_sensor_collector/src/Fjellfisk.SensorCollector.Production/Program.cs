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
            return await RunPairingAsync(layout, metadata, arguments);

        default:
            throw new ArgumentOutOfRangeException(nameof(command));
    }
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
    Console.WriteLine("Commands: --identity, --status, --discovery-status, --read-once, --pairing");
    Console.WriteLine("Pairing uses HTTPS from pairing-backend.json or FJELLFISK_COLLECTOR_PAIRING_URL.");
    Console.WriteLine("A local emulator additionally requires --pairing-emulator and an explicit loopback URL.");
    Console.WriteLine("The production executable does not expose diagnostic or service commands.");
}

static async Task<int> RunPairingAsync(
    ProductionStorageLayout layout,
    CollectorBuildMetadata metadata,
    IReadOnlyCollection<string> arguments)
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
    var coordinator = new CollectorPairingCoordinator(
        new CollectorPairingStateStore(layout.IdentityDirectory),
        backend,
        pairingWindow,
        new PairingFileLogger(layout.LogsDirectory),
        SystemClock.Instance,
        SystemCollectorPairingDelay.Instance,
        metadata.ProductVersion,
        "windows-x86");

    Console.WriteLine($"Fjellfisk Collector pairing started ({configuration.Source}). Press Ctrl+C to stop.");
    try
    {
        await coordinator.RunAsync(cancellation.Token);
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
    using var reader = new OxyGuardVigoReader(
        SystemClock.Instance,
        allowlist);
    var runtime = new ProductionCollectorRuntime(
        reader,
        allowlist,
        identity,
        metadata,
        output,
        SystemClock.Instance);
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
