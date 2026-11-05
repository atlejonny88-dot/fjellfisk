using System.Net;
using System.Text.Json;
using Fjellfisk.SensorCollector;

static class ProductionTelemetryTests
{
    static void Check(bool value, string message) { if (!value) throw new Exception(message); }
    static string DirectoryPath() { var path = Path.Combine(Path.GetTempPath(), "fjellfisk-telemetry-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(path); return path; }
    static TelemetrySensorBatch Batch() => new(Guid.NewGuid().ToString(), "1.0.5", new[] {
        new TelemetrySensorReading("sensor-1", "Pacific 01 / Probe 01", "Pacific", 9.52f, 11.66f, 101.85f, DateTimeOffset.UtcNow, "ok") });

    public static async Task SessionUploadsAsync()
    {
        var root = DirectoryPath();
        try
        {
            var clock = new FakeClock(DateTimeOffset.UtcNow);
            var backend = new PairingBackendFake(clock) { State = "PAIRED" };
            var state = new CollectorPairingStateStore(Path.Combine(root, "identity"));
            var logger = new TestPairingLogger();
            var coordinator = new CollectorPairingCoordinator(state, backend, new TestPairingUi(), logger, clock,
                new PairingTestDelay(), "1.0.5", "windows-x86");
            await coordinator.RunSingleCycleAsync(CancellationToken.None);
            var reader = new InventoryTestReader(clock);
            var handler = new Handler();
            using var client = new HttpClient(handler);
            using var uploader = new HttpsProductionTelemetryUploader(new(new Uri("https://api.example/collector/v1/"), "test"), client);
            var queue = new ProductionTelemetryQueue(Path.Combine(root, "queue"));
            var discovery = new ProductionDiscoveryService(new[] { new InMemoryVigoConfigurationSource("test", new[] {
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01", "Commander5:Master_Box_1.DOM.DO_Meter_0.DO_0" }) }, clock: clock);
            using var session = new ProductionTelemetrySession(discovery.DiscoverAsync, _ => reader,
                new CollectorIdentityStore(Path.Combine(root, "local"), clock).LoadOrCreate(),
                new("1.0.5", "1.0.5.0", "test"), queue, uploader, state, logger, clock);
            await session.ReadAndUploadAsync(CancellationToken.None);
            Check(reader.ReadKeys.Count == 6, "Expected serial Pacific and DOM reads.");
            Check(queue.Files.Length == 0, "Acknowledged batch was retained.");
            Check(handler.HeadersValid && handler.Path == "/collector/v1/measurements", "Device auth or endpoint mismatch.");
            Check(!handler.Body.Contains("Commander5:") && !handler.Body.Contains(backend.DeviceCredential), "Private paths or credentials leaked into telemetry.");
            using var json = JsonDocument.Parse(handler.Body);
            var reading = json.RootElement.GetProperty("readings")[0];
            Check(Math.Abs(reading.GetProperty("oxygenMgL").GetDouble() - 11.66) < 0.01, "Concentration was swapped.");
            Check(Math.Abs(reading.GetProperty("oxygenSaturationPct").GetDouble() - 101.85) < 0.01, "Saturation was swapped.");
        }
        finally { Directory.Delete(root, true); }
    }

    public static async Task BufferRetryAsync()
    {
        var root = DirectoryPath();
        try
        {
            var queue = new ProductionTelemetryQueue(root, maximumFiles: 1);
            var batch = Batch();
            await queue.EnqueueAsync(batch, CancellationToken.None);
            Check(!queue.HasCapacity, "Queue ignored its capacity.");
            var uploader = new Uploader { Fail = true };
            try { await queue.FlushAsync(new("collector-1", "test-credential"), uploader, CancellationToken.None); throw new Exception("Expected failure."); }
            catch (HttpRequestException) { }
            Check(queue.Files.Length == 1, "Failed upload deleted durable data.");
            var restarted = new ProductionTelemetryQueue(root);
            uploader.Fail = false;
            await restarted.FlushAsync(new("collector-1", "test-credential"), uploader, CancellationToken.None);
            Check(uploader.Ids.SequenceEqual(new[] { batch.BatchId, batch.BatchId }), "Retry did not preserve idempotency id.");
            Check(restarted.Files.Length == 0, "Successful retry did not drain the queue.");
        }
        finally { Directory.Delete(root, true); }
    }

    public static async Task PairingGateAsync()
    {
        foreach (var stateName in new[] { "UNPAIRED", "PAIRED", "REVOKED" })
        {
            var root = DirectoryPath();
            try
            {
                var clock = new FakeClock(DateTimeOffset.UtcNow);
                using var stop = new CancellationTokenSource();
                var coordinator = new CollectorPairingCoordinator(new(root), new PairingBackendFake(clock) { State = stateName },
                    new TestPairingUi(), new TestPairingLogger(), clock, new StopAfterCycle(stop), "1.0.5", "windows-x86");
                var calls = 0;
                try { await coordinator.RunAsync(stop.Token, _ => { calls++; return Task.CompletedTask; }, TimeSpan.FromSeconds(15)); }
                catch (OperationCanceledException) when (stop.IsCancellationRequested) { }
                Check(calls == (stateName == "PAIRED" ? 1 : 0), "Unpaired/revoked Collector reached sensor callback.");
            }
            finally { Directory.Delete(root, true); }
        }
    }

    public static async Task BackoffAsync()
    {
        var root = DirectoryPath();
        try
        {
            var clock = new FakeClock(DateTimeOffset.UtcNow);
            var state = new CollectorPairingStateStore(Path.Combine(root, "state"));
            var coordinator = new CollectorPairingCoordinator(state, new PairingBackendFake(clock) { State = "PAIRED" },
                new TestPairingUi(), new TestPairingLogger(), clock, new PairingTestDelay(), "1.0.5", "windows-x86");
            await coordinator.RunSingleCycleAsync(CancellationToken.None);
            var reader = new InventoryTestReader(clock);
            var uploader = new Uploader { Fail = true };
            var discovery = new ProductionDiscoveryService(new[] { new InMemoryVigoConfigurationSource("test", new[] { "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01" }) }, clock: clock);
            using var session = new ProductionTelemetrySession(discovery.DiscoverAsync, _ => reader,
                new CollectorIdentityStore(Path.Combine(root, "local"), clock).LoadOrCreate(), new("1.0.5", "test", "test"),
                new(Path.Combine(root, "queue")), uploader, state, new TestPairingLogger(), clock);
            await session.ReadAndUploadAsync(CancellationToken.None);
            await session.ReadAndUploadAsync(CancellationToken.None);
            Check(reader.ReadKeys.Count == 3 && uploader.Ids.Count == 1, "Backoff performed extra reads or uploads.");
            clock.UtcNow = clock.UtcNow.AddSeconds(15);
            uploader.Fail = false;
            await session.ReadAndUploadAsync(CancellationToken.None);
            Check(reader.ReadKeys.Count == 6 && uploader.Ids[0] == uploader.Ids[1], "Buffered batch did not resume safely.");
        }
        finally { Directory.Delete(root, true); }
    }

    public static async Task StalledReaderEscalatesAfterFinalBatchAsync()
    {
        var root = DirectoryPath();
        try
        {
            var clock = new FakeClock(DateTimeOffset.UtcNow);
            var backend = new PairingBackendFake(clock) { State = "PAIRED" };
            var state = new CollectorPairingStateStore(Path.Combine(root, "identity"));
            var logger = new TestPairingLogger();
            var coordinator = new CollectorPairingCoordinator(state, backend, new TestPairingUi(), logger, clock,
                new PairingTestDelay(), "1.0.6", "windows-x86");
            await coordinator.RunSingleCycleAsync(CancellationToken.None);
            var reader = new StalledReader();
            var handler = new Handler();
            using var client = new HttpClient(handler);
            using var uploader = new HttpsProductionTelemetryUploader(new(new Uri("https://api.example/collector/v1/"), "test"), client);
            var discovery = new ProductionDiscoveryService(new[] { new InMemoryVigoConfigurationSource("test", new[] {
                "Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01", "Commander5:Master_Box_1.DOM.DO_Meter_0.DO_0" }) }, clock: clock);
            using var session = new ProductionTelemetrySession(discovery.DiscoverAsync, _ => reader,
                new CollectorIdentityStore(Path.Combine(root, "local"), clock).LoadOrCreate(),
                new("1.0.6", "1.0.6.0", "test"), new ProductionTelemetryQueue(Path.Combine(root, "queue")),
                uploader, state, logger, clock);

            try
            {
                await session.ReadAndUploadAsync(CancellationToken.None);
                throw new Exception("A stalled reader did not request controlled worker exit.");
            }
            catch (CollectorSensorReadStalledException)
            {
            }

            Check(reader.ReadCalls == 6, "The stalled reader did not complete exactly one failed sensor round.");
            Check(handler.Body.Contains("\"health\":\"failed\"", StringComparison.Ordinal),
                "The final failed telemetry batch was not uploaded before worker exit.");
            Check(logger.Messages.Any(message => message.StartsWith("sensor_reader_stalled:", StringComparison.Ordinal)),
                "The stalled worker state was not logged safely.");
        }
        finally { Directory.Delete(root, true); }
    }

    public static async Task TransportSafetyAsync()
    {
        try { using var bad = new HttpsProductionTelemetryUploader(new(new Uri("http://127.0.0.1/collector/v1/"), "test")); throw new Exception("HTTP accepted."); }
        catch (ArgumentException) { }
        using var client = new HttpClient(new Handler { Redirect = true });
        using var uploader = new HttpsProductionTelemetryUploader(new(new Uri("https://api.example/collector/v1/"), "test"), client);
        try { await uploader.UploadAsync(new("test", "test-credential"), Batch(), CancellationToken.None); throw new Exception("Redirect accepted."); }
        catch (HttpRequestException) { }
    }

    sealed class StopAfterCycle : ICollectorPairingDelay
    {
        readonly CancellationTokenSource _stop;
        public StopAfterCycle(CancellationTokenSource stop) { _stop = stop; }
        public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken) { _stop.Cancel(); return Task.FromCanceled(_stop.Token); }
    }
    sealed class Uploader : IProductionTelemetryUploader
    {
        public bool Fail { get; set; }
        public List<string> Ids { get; } = new();
        public Task UploadAsync(CollectorBackendIdentity identity, TelemetrySensorBatch batch, CancellationToken token)
        { Ids.Add(batch.BatchId); return Fail ? Task.FromException(new HttpRequestException("test failure")) : Task.CompletedTask; }
    }
    sealed class Handler : HttpMessageHandler
    {
        public bool Redirect { get; set; }
        public string Body { get; private set; } = "";
        public string Path { get; private set; } = "";
        public bool HeadersValid { get; private set; }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
        {
            Body = await request.Content!.ReadAsStringAsync(); Path = request.RequestUri!.AbsolutePath;
            HeadersValid = request.Headers.Contains("x-fjellfisk-collector-id") && request.Headers.Contains("x-fjellfisk-device-credential");
            return new(Redirect ? HttpStatusCode.Redirect : HttpStatusCode.OK) { Content = new StringContent("{\"accepted\":true}") };
        }
    }

    sealed class StalledReader : ISensorReader, ICollectorSensorReadHealth
    {
        public bool IsStalled => true;
        public int ReadCalls { get; private set; }
        public string ReaderName => "StalledReader";

        public Task<SensorReadResult> ReadAsync(SensorDefinition sensor, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            ReadCalls++;
            return Task.FromException<SensorReadResult>(new TimeoutException("simulated stalled reader"));
        }
    }
}
