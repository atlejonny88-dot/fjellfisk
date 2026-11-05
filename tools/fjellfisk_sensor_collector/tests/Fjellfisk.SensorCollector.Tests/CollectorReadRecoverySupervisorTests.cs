using System.Reflection;
using Fjellfisk.SensorCollector;

static class CollectorReadRecoverySupervisorTests
{
    public static async Task RestartsOnlyAfterWorkerExitAsync()
    {
        var worker = new ScriptedWorker(CollectorReadRecoverySupervisor.StalledReaderExitCode, 0);
        var logger = new TestLogger();
        var delay = new RecordingDelay();
        var supervisor = new CollectorReadRecoverySupervisor(
            worker, logger, new RecoveryClock(), delay);

        var exitCode = await supervisor.RunAsync(CancellationToken.None);

        Check(exitCode == 0, "Collector did not return the replacement worker exit code.");
        Check(worker.Calls == 2 && worker.MaximumConcurrentCalls == 1,
            "A replacement worker started before the stalled worker had exited.");
        Check(delay.Delays.SequenceEqual(new[] { TimeSpan.FromSeconds(60) }),
            "Collector recovery did not wait the bounded 60-second delay.");
        Check(logger.Events.Count(entry => entry == "sensor_reader_recovery_scheduled") == 1,
            "Collector recovery did not log its single scheduled restart.");
    }

    public static async Task StopsAfterBoundedStalledWorkersAsync()
    {
        var worker = new ScriptedWorker(Enumerable.Repeat(CollectorReadRecoverySupervisor.StalledReaderExitCode, 10).ToArray());
        var logger = new TestLogger();
        var delay = new RecordingDelay();
        var supervisor = new CollectorReadRecoverySupervisor(
            worker, logger, new RecoveryClock(), delay);

        var exitCode = await supervisor.RunAsync(CancellationToken.None);

        Check(exitCode == CollectorReadRecoverySupervisor.StalledReaderExitCode,
            "Collector did not stop after its stalled-worker recovery limit.");
        Check(worker.Calls == 4 && worker.MaximumConcurrentCalls == 1,
            "Collector performed unbounded or concurrent stalled-reader recovery.");
        Check(delay.Delays.Count == 3, "Collector scheduled more than three recoveries in its window.");
        Check(logger.Events.Contains("sensor_reader_recovery_limit"),
            "Collector did not log the bounded recovery limit.");
    }

    public static async Task DoesNotRestartNonStalledWorkerAsync()
    {
        var worker = new ScriptedWorker(1);
        var delay = new RecordingDelay();
        var supervisor = new CollectorReadRecoverySupervisor(
            worker, new TestLogger(), new RecoveryClock(), delay);

        var exitCode = await supervisor.RunAsync(CancellationToken.None);

        Check(exitCode == 1 && worker.Calls == 1 && delay.Delays.Count == 0,
            "Collector retried a worker exit that was not a documented stalled reader.");
    }

    public static Task DoesNotTouchPairingOrIdentityAsync()
    {
        var fields = typeof(CollectorReadRecoverySupervisor)
            .GetFields(BindingFlags.Instance | BindingFlags.NonPublic)
            .Select(field => field.FieldType)
            .ToArray();
        Check(!fields.Contains(typeof(CollectorPairingStateStore)) &&
            !fields.Contains(typeof(CollectorIdentityStore)),
            "Recovery supervisor must not own pairing or identity state.");
        return Task.CompletedTask;
    }

    private static void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private sealed class RecoveryClock : IClock
    {
        public DateTimeOffset UtcNow { get; } = DateTimeOffset.Parse("2026-11-05T10:00:00Z");
    }

    private sealed class RecordingDelay : ICollectorRecoveryDelay
    {
        public List<TimeSpan> Delays { get; } = new();
        public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
        {
            Delays.Add(delay);
            return Task.CompletedTask;
        }
    }

    private sealed class TestLogger : ICollectorPairingLogger
    {
        public List<string> Events { get; } = new();
        public void Log(string eventName, string message) => Events.Add(eventName);
    }

    private sealed class ScriptedWorker : ICollectorWorkerProcess
    {
        private readonly Queue<int> _exitCodes;
        private int _activeCalls;

        public ScriptedWorker(params int[] exitCodes) => _exitCodes = new Queue<int>(exitCodes);

        public int Calls { get; private set; }
        public int MaximumConcurrentCalls { get; private set; }

        public Task<int> RunAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Calls++;
            var active = Interlocked.Increment(ref _activeCalls);
            MaximumConcurrentCalls = Math.Max(MaximumConcurrentCalls, active);
            try
            {
                return Task.FromResult(_exitCodes.Count == 0 ? 0 : _exitCodes.Dequeue());
            }
            finally
            {
                Interlocked.Decrement(ref _activeCalls);
            }
        }
    }
}
