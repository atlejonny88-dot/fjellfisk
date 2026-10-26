using System.Security.Cryptography;
using System.Text;

namespace Fjellfisk.SensorCollector;

public interface IAsyncDelay
{
    Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken);
}

public sealed class SystemAsyncDelay : IAsyncDelay
{
    public static readonly SystemAsyncDelay Instance = new();

    private SystemAsyncDelay()
    {
    }

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken) =>
        Task.Delay(delay, cancellationToken);
}

public sealed record ServiceHostOptions(TimeSpan StartupDelay)
{
    public static readonly ServiceHostOptions Default = new(TimeSpan.FromSeconds(60));
}

public sealed class CollectorInstanceLock : IDisposable
{
    private readonly Mutex _mutex;

    private CollectorInstanceLock(Mutex mutex, bool isAcquired)
    {
        _mutex = mutex;
        IsAcquired = isAcquired;
    }

    public bool IsAcquired { get; }

    public static CollectorInstanceLock TryAcquire(string collectorDeviceId)
    {
        var stableId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(collectorDeviceId)));
        var mutex = new Mutex(initiallyOwned: true, $"Local\\FjellfiskCollector-{stableId}", out var createdNew);
        return new CollectorInstanceLock(mutex, createdNew);
    }

    public void Dispose()
    {
        if (IsAcquired)
        {
            _mutex.ReleaseMutex();
        }

        _mutex.Dispose();
    }
}

// This class is service-host ready but does not register or install a Windows service.
public sealed class CollectorServiceHost
{
    private readonly CollectorIdentity _identity;
    private readonly CollectorRunner _runner;
    private readonly ICollectorLogger _logger;
    private readonly IAsyncDelay _delay;
    private readonly ServiceHostOptions _options;

    public CollectorServiceHost(
        CollectorIdentity identity,
        CollectorRunner runner,
        ICollectorLogger logger,
        IAsyncDelay delay,
        ServiceHostOptions options)
    {
        if (options.StartupDelay < TimeSpan.FromSeconds(60))
        {
            throw new ArgumentOutOfRangeException(
                nameof(options),
                "A collector service host must wait at least 60 seconds before its first reader call.");
        }

        _identity = identity;
        _runner = runner;
        _logger = logger;
        _delay = delay;
        _options = options;
    }

    public CollectorRunner Runner => _runner;

    public async Task<bool> RunAsync(CancellationToken cancellationToken)
    {
        using var instanceLock = CollectorInstanceLock.TryAcquire(_identity.CollectorDeviceId);
        if (!instanceLock.IsAcquired)
        {
            _logger.Log("single_instance_blocked", "Another collector instance is already running.");
            return false;
        }

        _logger.Log(
            "service_startup_delay",
            $"Waiting {_options.StartupDelay.TotalSeconds:F0} seconds before the first reader call.");
        await _delay.DelayAsync(_options.StartupDelay, cancellationToken);
        if (cancellationToken.IsCancellationRequested)
        {
            return true;
        }

        await _runner.RunAsync(cancellationToken);
        return true;
    }
}
