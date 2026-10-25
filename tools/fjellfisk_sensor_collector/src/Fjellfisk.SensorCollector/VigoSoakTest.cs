using System.Text.Json;

namespace Fjellfisk.SensorCollector;

public enum SoakTestExit
{
    Normal,
    Cancelled,
    FatalError,
}

public sealed record SoakTestOptions(
    TimeSpan Duration,
    TimeSpan SamplingInterval,
    TimeSpan PeriodicSummaryInterval)
{
    public static readonly TimeSpan DefaultDuration = TimeSpan.FromHours(72);
    public static readonly TimeSpan DefaultSamplingInterval = TimeSpan.FromSeconds(15);
    public static readonly TimeSpan DefaultPeriodicSummaryInterval = TimeSpan.FromMinutes(15);

    public void Validate()
    {
        if (Duration <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(Duration));
        }

        if (SamplingInterval < CollectorOptions.MinimumSamplingInterval)
        {
            throw new ArgumentOutOfRangeException(
                nameof(SamplingInterval),
                $"Sampling interval must be at least {CollectorOptions.MinimumSamplingInterval.TotalSeconds:0} seconds.");
        }

        if (PeriodicSummaryInterval <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(PeriodicSummaryInterval));
        }
    }
}

public sealed record SoakLastReading(
    DateTimeOffset TimestampUtc,
    float TemperatureC,
    float OxygenMgL,
    float OxygenSaturationPct);

public sealed record SoakTestSummary(
    TimeSpan RequestedDuration,
    TimeSpan Runtime,
    int TotalCycles,
    int SuccessfulCycles,
    int FailedCycles,
    double SuccessPercentage,
    TimeSpan? MinimumReadDuration,
    TimeSpan? MaximumReadDuration,
    TimeSpan? AverageReadDuration,
    SoakLastReading? LastSuccessfulReading,
    TimeSpan LongestConsecutiveFailurePeriod,
    int ComErrors,
    int Timeouts,
    int BufferCount,
    SoakTestExit CollectorExit,
    string? FatalError);

public sealed class SoakTestStatistics
{
    private int _totalCycles;
    private int _successfulCycles;
    private int _failedCycles;
    private long _totalReadDurationTicks;
    private int _readDurationCount;
    private TimeSpan? _minimumReadDuration;
    private TimeSpan? _maximumReadDuration;
    private DateTimeOffset? _failureStartedUtc;
    private TimeSpan _longestFailurePeriod;
    private int _comErrors;
    private int _timeouts;
    private int _bufferCount;
    private SoakLastReading? _lastSuccessfulReading;

    public void RecordCycle(
        DateTimeOffset nowUtc,
        CycleResult result,
        CollectorSnapshot snapshot)
    {
        _totalCycles++;
        _bufferCount = snapshot.Status.BufferCount;
        RecordReadDuration(result.ReadDuration);

        if (result.Success)
        {
            _successfulCycles++;
            CompleteFailurePeriod(nowUtc);

            if (snapshot.LatestMeasurement is { } measurement)
            {
                _lastSuccessfulReading = new SoakLastReading(
                    measurement.TimestampUtc,
                    measurement.TemperatureC,
                    measurement.OxygenMgL,
                    measurement.OxygenSaturationPct);
            }

            return;
        }

        _failedCycles++;
        if (result.IsComError)
        {
            _comErrors++;
        }

        if (result.IsTimeout)
        {
            _timeouts++;
        }

        _failureStartedUtc ??= nowUtc;
    }

    public SoakTestSummary CreateSummary(
        DateTimeOffset startedUtc,
        DateTimeOffset endedUtc,
        TimeSpan requestedDuration,
        SoakTestExit collectorExit,
        string? fatalError = null)
    {
        var runtime = endedUtc - startedUtc;
        var longestFailurePeriod = _longestFailurePeriod;
        if (_failureStartedUtc is { } failureStartedUtc)
        {
            var currentFailurePeriod = endedUtc - failureStartedUtc;
            if (currentFailurePeriod > longestFailurePeriod)
            {
                longestFailurePeriod = currentFailurePeriod;
            }
        }

        return new SoakTestSummary(
            requestedDuration,
            runtime < TimeSpan.Zero ? TimeSpan.Zero : runtime,
            _totalCycles,
            _successfulCycles,
            _failedCycles,
            _totalCycles == 0 ? 0 : _successfulCycles * 100d / _totalCycles,
            _minimumReadDuration,
            _maximumReadDuration,
            _readDurationCount == 0
                ? null
                : TimeSpan.FromTicks(_totalReadDurationTicks / _readDurationCount),
            _lastSuccessfulReading,
            longestFailurePeriod,
            _comErrors,
            _timeouts,
            _bufferCount,
            collectorExit,
            fatalError);
    }

    private void RecordReadDuration(TimeSpan duration)
    {
        if (duration <= TimeSpan.Zero)
        {
            return;
        }

        _totalReadDurationTicks += duration.Ticks;
        _readDurationCount++;
        _minimumReadDuration = _minimumReadDuration is null || duration < _minimumReadDuration
            ? duration
            : _minimumReadDuration;
        _maximumReadDuration = _maximumReadDuration is null || duration > _maximumReadDuration
            ? duration
            : _maximumReadDuration;
    }

    private void CompleteFailurePeriod(DateTimeOffset endedUtc)
    {
        if (_failureStartedUtc is not { } startedUtc)
        {
            return;
        }

        var duration = endedUtc - startedUtc;
        if (duration > _longestFailurePeriod)
        {
            _longestFailurePeriod = duration;
        }

        _failureStartedUtc = null;
    }
}

public sealed class VigoSoakTestRunner
{
    private readonly CollectorRunner _runner;
    private readonly IClock _clock;
    private readonly IAsyncDelay _delay;
    private readonly ICollectorLogger _logger;
    private readonly Action<string> _writeConsole;

    public VigoSoakTestRunner(
        CollectorRunner runner,
        IClock clock,
        IAsyncDelay delay,
        ICollectorLogger logger,
        Action<string>? writeConsole = null)
    {
        _runner = runner;
        _clock = clock;
        _delay = delay;
        _logger = logger;
        _writeConsole = writeConsole ?? Console.WriteLine;
    }

    public async Task<SoakTestSummary> RunAsync(
        SoakTestOptions options,
        CancellationToken cancellationToken)
    {
        options.Validate();
        var startedUtc = _clock.UtcNow;
        var nextSummaryUtc = startedUtc + options.PeriodicSummaryInterval;
        var statistics = new SoakTestStatistics();
        var exit = SoakTestExit.Normal;
        string? fatalError = null;

        _runner.StartForegroundRun();
        _logger.Log(
            "soak_test_start",
            $"duration={options.Duration} samplingSeconds={options.SamplingInterval.TotalSeconds:F0} readOnly=true uploader=local-only");

        try
        {
            while (_clock.UtcNow - startedUtc < options.Duration)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var result = await _runner.RunCycleAsync(cancellationToken);
                var nowUtc = _clock.UtcNow;
                statistics.RecordCycle(nowUtc, result, _runner.Snapshot);
                LogCycle(nowUtc, result, _runner.Snapshot);

                while (nowUtc >= nextSummaryUtc)
                {
                    WritePeriodicSummary(statistics.CreateSummary(
                        startedUtc,
                        nowUtc,
                        options.Duration,
                        SoakTestExit.Normal));
                    nextSummaryUtc += options.PeriodicSummaryInterval;
                }

                var remaining = options.Duration - (_clock.UtcNow - startedUtc);
                if (remaining <= TimeSpan.Zero)
                {
                    break;
                }

                var delay = result.NextDelay < remaining ? result.NextDelay : remaining;
                await _delay.DelayAsync(delay, cancellationToken);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            exit = SoakTestExit.Cancelled;
            _logger.Log("soak_test_cancelled", "Cancellation requested; writing the local summary.");
        }
        catch (Exception exception)
        {
            exit = SoakTestExit.FatalError;
            fatalError = exception.Message;
            _logger.Log("soak_test_fatal", exception.Message);
        }
        finally
        {
            _runner.StopForegroundRun($"Soak test stopped with exit={exit}.");
        }

        var summary = statistics.CreateSummary(
            startedUtc,
            _clock.UtcNow,
            options.Duration,
            exit,
            fatalError);
        _logger.Log("soak_test_complete", FormatSummary(summary));
        return summary;
    }

    public static string FormatSummary(SoakTestSummary summary) =>
        $"runtime={summary.Runtime} cycles={summary.TotalCycles} successful={summary.SuccessfulCycles} " +
        $"failed={summary.FailedCycles} successPercent={summary.SuccessPercentage:F2} " +
        $"avgRead={FormatLatency(summary.AverageReadDuration)} " +
        $"maxRead={FormatLatency(summary.MaximumReadDuration)} comErrors={summary.ComErrors} " +
        $"timeouts={summary.Timeouts} longestFailure={summary.LongestConsecutiveFailurePeriod} " +
        $"bufferCount={summary.BufferCount} exit={summary.CollectorExit}";

    private void LogCycle(
        DateTimeOffset timestampUtc,
        CycleResult result,
        CollectorSnapshot snapshot)
    {
        if (result.Success && snapshot.LatestMeasurement is { } measurement)
        {
            _logger.Log(
                "soak_cycle",
                $"timestamp={timestampUtc:O} temperatureC={measurement.TemperatureC:F3} " +
                $"oxygenMgL={measurement.OxygenMgL:F3} " +
                $"oxygenSaturationPct={measurement.OxygenSaturationPct:F3} " +
                $"errorCode={result.ErrorCode ?? 0} readDurationMs={result.ReadDuration.TotalMilliseconds:F0} " +
                $"collectorState={GetCollectorState(snapshot.Status)} bufferCount={snapshot.Status.BufferCount}");
            return;
        }

        _logger.Log(
            "soak_cycle_failure",
            $"timestamp={timestampUtc:O} errorCode={result.ErrorCode?.ToString() ?? "unknown"} " +
            $"readDurationMs={result.ReadDuration.TotalMilliseconds:F0} " +
            $"collectorState={GetCollectorState(snapshot.Status)} retryDelaySeconds={result.NextDelay.TotalSeconds:F0} " +
            $"error={result.Error ?? "Unknown error."}");
    }

    private void WritePeriodicSummary(SoakTestSummary summary)
    {
        _writeConsole("Fjellfisk VIGO Soak Test");
        _writeConsole($"Runtime: {summary.Runtime:dd\\.hh\\:mm\\:ss}");
        _writeConsole($"Successful cycles: {summary.SuccessfulCycles}");
        _writeConsole($"Failed cycles: {summary.FailedCycles}");
        _writeConsole($"Success rate: {summary.SuccessPercentage:F2}%");
        _writeConsole($"Last reading: {FormatLastReading(summary.LastSuccessfulReading)}");
        _writeConsole($"Avg latency: {FormatLatency(summary.AverageReadDuration)}");
    }

    private static string GetCollectorState(CollectorStatus status) =>
        status.Running
            ? status.VigoConnected ? "running-connected" : "running-backoff"
            : "stopped";

    private static string FormatLastReading(SoakLastReading? reading) => reading is null
        ? "none"
        : $"{reading.TimestampUtc:O} temperatureC={reading.TemperatureC:F3} " +
          $"oxygenMgL={reading.OxygenMgL:F3} oxygenSaturationPct={reading.OxygenSaturationPct:F3}";

    private static string FormatLatency(TimeSpan? duration) => duration is { } value
        ? $"{value.TotalMilliseconds:F1} ms"
        : "n/a";
}

public static class SoakTestSummaryFile
{
    public static async Task WriteAsync(
        string path,
        SoakTestSummary summary,
        CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(path);
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new ArgumentException("A summary path with a directory is required.", nameof(path));
        }

        Directory.CreateDirectory(directory);
        var options = new JsonSerializerOptions(MeasurementJson.Options)
        {
            WriteIndented = true,
        };
        var json = JsonSerializer.Serialize(summary, options);
        await File.WriteAllTextAsync(path, json, cancellationToken);
    }
}
