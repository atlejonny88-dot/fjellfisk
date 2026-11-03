using System.Runtime.InteropServices;

using Fjellfisk.SensorCollector;

static class ProductionReadDiagnosticsTests
{
    public static async Task NormalReadProducesNoFailureLogAsync()
    {
        var directory = TemporaryDirectory();
        try
        {
            var clock = new TestClock(DateTimeOffset.Parse("2026-11-03T12:00:00Z"));
            var diagnostics = new LocalSensorReadDiagnostics(directory, clock);
            var discovery = Discovery(clock);
            var runtime = Runtime(discovery, new TestReader(clock), diagnostics, clock);

            var batch = await runtime.ReadOneCycleAsync(discovery, CancellationToken.None);

            Check(batch.Readings.All(reading => reading.Health == "ok"), "Normal reads were not retained as OK.");
            Check(!File.Exists(diagnostics.LogPath), "A successful read created a failure log entry.");
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    public static async Task TimeoutLogsAndBlocksStaAsync()
    {
        var directory = TemporaryDirectory();
        using var release = new ManualResetEventSlim(false);
        using var started = new ManualResetEventSlim(false);
        try
        {
            var diagnostics = new LocalSensorReadDiagnostics(directory);
            using var executor = new StaVigoReadExecutor(diagnostics);
            var calls = 0;
            var first = executor.ExecuteAsync(
                new VigoReadOperationContext("Pacific", "temperatureC"),
                () =>
                {
                    Interlocked.Increment(ref calls);
                    started.Set();
                    release.Wait();
                    return Result("pacific_temperature");
                },
                TimeSpan.FromMilliseconds(30),
                CancellationToken.None);

            Check(started.Wait(TimeSpan.FromSeconds(1)), "The simulated COM call did not start.");
            await ExpectThrowsAsync<TimeoutException>(first);

            var log = File.ReadAllText(diagnostics.LogPath);
            Check(log.Contains("sta-reader-blocked", StringComparison.Ordinal), "The first STA timeout was not logged.");
            Check(log.Contains("\"classification\":\"timeout\"", StringComparison.Ordinal), "The timeout classification was not logged.");
            Check(log.Contains("\"stage\":\"queued\"", StringComparison.Ordinal), "The safe first-failure stage was not logged.");
            Check(calls == 1, "The initial blocked COM call was executed more than once.");
        }
        finally
        {
            release.Set();
            Directory.Delete(directory, recursive: true);
        }
    }

    public static async Task RuntimeLogsFailureClassificationsAsync()
    {
        var directory = TemporaryDirectory();
        try
        {
            var clock = new TestClock(DateTimeOffset.Parse("2026-11-03T12:00:00Z"));
            var discovery = Discovery(clock);
            var pacific = discovery.Sensors.Single(sensor => sensor.SourceType == "Pacific");
            var dom = discovery.Sensors.Single(sensor => sensor.SourceType == "DOM");
            var reader = new TestReader(clock);
            reader.Results[pacific.Measurements[0].Key] = Result(pacific.Measurements[0], errorCode: 7);
            reader.Results[pacific.Measurements[1].Key] = Result(pacific.Measurements[1], pnetDataType: 35);
            reader.Errors[pacific.Measurements[2].Key] = new COMException("simulated COM failure", unchecked((int)0x80004005));
            reader.Errors[dom.Measurements[0].Key] = new TimeoutException("simulated timeout");
            reader.Errors[dom.Measurements[1].Key] = new InvalidOperationException("simulated reader error");
            var diagnostics = new LocalSensorReadDiagnostics(directory, clock);
            var runtime = Runtime(discovery, reader, diagnostics, clock);

            await runtime.ReadOneCycleAsync(discovery, CancellationToken.None);

            var log = File.ReadAllText(diagnostics.LogPath);
            foreach (var classification in new[] { "vigo-error", "invalid-read", "com-error", "timeout", "read-error" })
            {
                Check(log.Contains($"\"classification\":\"{classification}\"", StringComparison.Ordinal),
                    $"{classification} was not retained in the local diagnostics log.");
            }

            Check(log.Contains("\"sourceType\":\"Pacific\"", StringComparison.Ordinal), "Pacific was not classified.");
            Check(log.Contains("\"sourceType\":\"DOM\"", StringComparison.Ordinal), "DOM was not classified.");
            Check(!log.Contains("Commander5:", StringComparison.Ordinal), "A PhysId leaked into the local diagnostics log.");
            Check(!log.Contains("simulated COM failure", StringComparison.Ordinal), "An exception message leaked into the local diagnostics log.");
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    public static async Task SubsequentReadsExplainBlockedStateAsync()
    {
        var directory = TemporaryDirectory();
        using var release = new ManualResetEventSlim(false);
        using var started = new ManualResetEventSlim(false);
        try
        {
            var diagnostics = new LocalSensorReadDiagnostics(directory);
            using var executor = new StaVigoReadExecutor(diagnostics);
            var first = executor.ExecuteAsync(
                new VigoReadOperationContext("Pacific", "temperatureC"),
                () =>
                {
                    started.Set();
                    release.Wait();
                    return Result("pacific_temperature");
                },
                TimeSpan.FromMilliseconds(30),
                CancellationToken.None);
            Check(started.Wait(TimeSpan.FromSeconds(1)), "The simulated COM call did not start.");
            await ExpectThrowsAsync<TimeoutException>(first);

            await ExpectThrowsAsync<TimeoutException>(executor.ExecuteAsync(
                new VigoReadOperationContext("DOM", "oxygenMgL"),
                () => Result("dom_oxygen"),
                TimeSpan.FromMilliseconds(30),
                CancellationToken.None));

            var log = File.ReadAllText(diagnostics.LogPath);
            Check(log.Contains("sta-reader-already-blocked", StringComparison.Ordinal), "Later blocked reads were not explained in the local log.");
            Check(log.Contains("\"sourceType\":\"DOM\"", StringComparison.Ordinal), "The later blocked sensor family was not recorded.");
        }
        finally
        {
            release.Set();
            Directory.Delete(directory, recursive: true);
        }
    }

    public static async Task ComFailureDoesNotBlockStaAsync()
    {
        var directory = TemporaryDirectory();
        try
        {
            var diagnostics = new LocalSensorReadDiagnostics(directory);
            using var executor = new StaVigoReadExecutor(diagnostics);
            var calls = 0;
            await ExpectThrowsAsync<COMException>(executor.ExecuteAsync(
                new VigoReadOperationContext("Pacific", "temperatureC"),
                () =>
                {
                    Interlocked.Increment(ref calls);
                    throw new COMException("simulated COM failure", unchecked((int)0x80004005));
                },
                TimeSpan.FromSeconds(1),
                CancellationToken.None));

            var result = await executor.ExecuteAsync(
                new VigoReadOperationContext("Pacific", "oxygenMgL"),
                () =>
                {
                    Interlocked.Increment(ref calls);
                    return Result("pacific_oxygen");
                },
                TimeSpan.FromSeconds(1),
                CancellationToken.None);

            Check(result.ErrorCode == 0 && calls == 2, "A COM exception incorrectly blocked the STA reader.");
            Check(!File.Exists(diagnostics.LogPath), "The STA executor treated a COM exception as a timeout block.");
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    public static async Task StalledStaReaderDoesNotRunConcurrentComAsync()
    {
        var directory = TemporaryDirectory();
        using var release = new ManualResetEventSlim(false);
        using var started = new ManualResetEventSlim(false);
        try
        {
            using var executor = new StaVigoReadExecutor(new LocalSensorReadDiagnostics(directory));
            var calls = 0;
            var first = executor.ExecuteAsync(
                new VigoReadOperationContext("Pacific", "temperatureC"),
                () =>
                {
                    Interlocked.Increment(ref calls);
                    started.Set();
                    release.Wait();
                    return Result("pacific_temperature");
                },
                TimeSpan.FromMilliseconds(30),
                CancellationToken.None);
            Check(started.Wait(TimeSpan.FromSeconds(1)), "The simulated COM call did not start.");
            await ExpectThrowsAsync<TimeoutException>(first);

            for (var index = 0; index < 5; index++)
            {
                await ExpectThrowsAsync<TimeoutException>(executor.ExecuteAsync(
                    new VigoReadOperationContext("DOM", "temperatureC"),
                    () =>
                    {
                        Interlocked.Increment(ref calls);
                        return Result("dom_temperature");
                    },
                    TimeSpan.FromMilliseconds(30),
                    CancellationToken.None));
            }

            Check(calls == 1, "A blocked STA reader accepted additional COM work.");
        }
        finally
        {
            release.Set();
            Directory.Delete(directory, recursive: true);
        }
    }

    public static Task DiagnosticLogRotatesAsync()
    {
        var directory = TemporaryDirectory();
        try
        {
            var diagnostics = new LocalSensorReadDiagnostics(directory, maximumLogBytes: 100, maximumArchives: 2);
            for (var index = 0; index < 10; index++)
            {
                diagnostics.RecordMeasurementFailure(new SensorReadDiagnosticEvent("Pacific", "temperatureC", "timeout"));
            }

            Check(File.Exists(diagnostics.LogPath), "The active diagnostics log was not created.");
            Check(File.Exists(diagnostics.LogPath + ".1"), "The diagnostics log did not rotate.");
            Check(Directory.GetFiles(directory).Length <= 3, "Diagnostics log rotation exceeded its archive limit.");
            return Task.CompletedTask;
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    public static Task DiagnosticsPreserveReadOnlyProtocolAsync()
    {
        var publicMethods = typeof(OxyGuardVigoReader)
            .GetMethods(System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public)
            .Select(method => method.Name)
            .ToArray();
        Check(!publicMethods.Any(name => name.Contains("write", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("set", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("control", StringComparison.OrdinalIgnoreCase)),
            "Diagnostics exposed a control or write API on the VIGO reader.");
        Check(typeof(OxyGuardVigoReader).GetInterfaces().SequenceEqual(new[] { typeof(ISensorReader), typeof(IDisposable) }),
            "Diagnostics changed the OxyGuard reader protocol.");
        return Task.CompletedTask;
    }

    private static ProductionDiscoveryResult Discovery(IClock clock)
    {
        var pacific = Descriptor("Pacific", "pacific", "pacific-1");
        var dom = Descriptor("DOM", "dom", "dom-1");
        return new ProductionDiscoveryResult(clock.UtcNow, new[] { pacific, dom }, Array.Empty<SourceCapability>(), Array.Empty<DiscoveryIssue>());
    }

    private static CollectorSensorDescriptor Descriptor(string sourceType, string keyPrefix, string sensorId)
    {
        var measurements = new[]
        {
            new SensorDefinition($"{keyPrefix}_temperature", sensorId, "Commander5:private-path", SensorKind.TemperatureC),
            new SensorDefinition($"{keyPrefix}_oxygen", sensorId, "Commander5:private-path", SensorKind.OxygenMgL),
            new SensorDefinition($"{keyPrefix}_saturation", sensorId, "Commander5:private-path", SensorKind.OxygenSaturationPct),
        };
        return new CollectorSensorDescriptor(sensorId, sensorId, sourceType, sourceType, "test", new Dictionary<string, string>(), measurements);
    }

    private static ProductionCollectorRuntime Runtime(
        ProductionDiscoveryResult discovery,
        ISensorReader reader,
        ICollectorSensorReadDiagnostics diagnostics,
        IClock clock) => new(
            reader,
            discovery.CreateRuntimeAllowlist(),
            new CollectorIdentity("test", new byte[32], clock.UtcNow),
            new CollectorBuildMetadata("1.0.5", "test", "test"),
            new NoOpBuffer(),
            clock,
            diagnostics);

    private static SensorReadResult Result(
        SensorDefinition sensor,
        int errorCode = 0,
        int pnetDataType = 36) => new(
            sensor,
            sensor.Kind switch
            {
                SensorKind.TemperatureC => 9.52f,
                SensorKind.OxygenMgL => 11.66f,
                SensorKind.OxygenSaturationPct => 101.85f,
                _ => throw new ArgumentOutOfRangeException(nameof(sensor)),
            },
            errorCode,
            pnetDataType,
            "System.Single",
            DateTimeOffset.UtcNow,
            TimeSpan.FromMilliseconds(1));

    private static SensorReadResult Result(string key) => Result(new SensorDefinition(key, "test", "Commander5:private-path", SensorKind.TemperatureC));

    private static string TemporaryDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), "fjellfisk-read-diagnostics-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }

    private static async Task ExpectThrowsAsync<TException>(Task task)
        where TException : Exception
    {
        try
        {
            await task;
        }
        catch (TException)
        {
            return;
        }

        throw new InvalidOperationException($"Expected {typeof(TException).Name}.");
    }

    private static void Check(bool value, string message)
    {
        if (!value)
        {
            throw new InvalidOperationException(message);
        }
    }

    private sealed class TestClock : IClock
    {
        public TestClock(DateTimeOffset utcNow) => UtcNow = utcNow;

        public DateTimeOffset UtcNow { get; }
    }

    private sealed class TestReader : ISensorReader
    {
        private readonly IClock _clock;

        public TestReader(IClock clock) => _clock = clock;

        public Dictionary<string, Exception> Errors { get; } = new(StringComparer.Ordinal);

        public Dictionary<string, SensorReadResult> Results { get; } = new(StringComparer.Ordinal);

        public string ReaderName => "TestReader";

        public Task<SensorReadResult> ReadAsync(SensorDefinition sensor, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (Errors.TryGetValue(sensor.Key, out var error))
            {
                return Task.FromException<SensorReadResult>(error);
            }

            if (Results.TryGetValue(sensor.Key, out var result))
            {
                return Task.FromResult(result);
            }

            return Task.FromResult(new SensorReadResult(
                sensor,
                sensor.Kind switch
                {
                    SensorKind.TemperatureC => 9.52f,
                    SensorKind.OxygenMgL => 11.66f,
                    SensorKind.OxygenSaturationPct => 101.85f,
                    _ => throw new ArgumentOutOfRangeException(nameof(sensor)),
                },
                0,
                36,
                "System.Single",
                _clock.UtcNow,
                TimeSpan.FromMilliseconds(1)));
        }
    }

    private sealed class NoOpBuffer : ICollectorBatchBuffer
    {
        public Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
