namespace Fjellfisk.SensorCollector;

/// <summary>
/// Exposes only the safe state needed by the process host. It never exposes a
/// COM object or a way to invoke VIGO members.
/// </summary>
public interface ICollectorSensorReadHealth
{
    bool IsStalled { get; }
}

/// <summary>
/// Signals that the read-only STA worker timed out and must be discarded with
/// the Collector process. No VIGO or P-NET restart is requested.
/// </summary>
public sealed class CollectorSensorReadStalledException : Exception
{
    public CollectorSensorReadStalledException()
        : base("The read-only VIGO worker is stalled.")
    {
    }
}

public interface ICollectorWorkerProcess
{
    Task<int> RunAsync(CancellationToken cancellationToken);
}

public interface ICollectorRecoveryDelay
{
    Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken);
}

public sealed class SystemCollectorRecoveryDelay : ICollectorRecoveryDelay
{
    public static readonly SystemCollectorRecoveryDelay Instance = new();

    private SystemCollectorRecoveryDelay()
    {
    }

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken) =>
        Task.Delay(delay, cancellationToken);
}

/// <summary>
/// Runs one isolated Collector worker at a time. A worker is never replaced
/// until its process has exited, so the Collector never issues parallel COM
/// calls. Recovery is deliberately bounded: three restarts in fifteen minutes.
/// </summary>
public sealed class CollectorReadRecoverySupervisor
{
    public const int StalledReaderExitCode = 75;
    private readonly ICollectorWorkerProcess _worker;
    private readonly ICollectorPairingLogger _logger;
    private readonly IClock _clock;
    private readonly ICollectorRecoveryDelay _delay;
    private readonly int _maximumRestarts;
    private readonly TimeSpan _restartWindow;
    private readonly TimeSpan _restartDelay;

    public CollectorReadRecoverySupervisor(
        ICollectorWorkerProcess worker,
        ICollectorPairingLogger logger,
        IClock clock,
        ICollectorRecoveryDelay delay,
        int maximumRestarts = 3,
        TimeSpan? restartWindow = null,
        TimeSpan? restartDelay = null)
    {
        _worker = worker ?? throw new ArgumentNullException(nameof(worker));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
        _delay = delay ?? throw new ArgumentNullException(nameof(delay));
        _maximumRestarts = maximumRestarts;
        _restartWindow = restartWindow ?? TimeSpan.FromMinutes(15);
        _restartDelay = restartDelay ?? TimeSpan.FromSeconds(60);
        if (_maximumRestarts < 0 || _restartWindow <= TimeSpan.Zero || _restartDelay <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumRestarts));
        }
    }

    public async Task<int> RunAsync(CancellationToken cancellationToken)
    {
        var restarts = new Queue<DateTimeOffset>();
        while (!cancellationToken.IsCancellationRequested)
        {
            // Awaiting the worker exit is the process boundary: a replacement
            // cannot begin while the old STA/COM client process still exists.
            var exitCode = await _worker.RunAsync(cancellationToken);
            if (cancellationToken.IsCancellationRequested)
            {
                return 0;
            }

            if (exitCode != StalledReaderExitCode)
            {
                return exitCode;
            }

            var now = _clock.UtcNow;
            while (restarts.Count > 0 && now - restarts.Peek() >= _restartWindow)
            {
                restarts.Dequeue();
            }

            if (restarts.Count >= _maximumRestarts)
            {
                _logger.Log("sensor_reader_recovery_limit",
                    "Read-only worker recovery limit reached; Collector stopped without restarting VIGO or P-NET.");
                return StalledReaderExitCode;
            }

            restarts.Enqueue(now);
            _logger.Log("sensor_reader_recovery_scheduled",
                $"Read-only worker exited after a stalled read; restarting Collector worker in {(int)_restartDelay.TotalSeconds}s. restartCount={restarts.Count}");
            await _delay.DelayAsync(_restartDelay, cancellationToken);
        }

        return 0;
    }
}
