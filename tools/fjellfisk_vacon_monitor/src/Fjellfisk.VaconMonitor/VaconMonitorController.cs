namespace Fjellfisk.VaconMonitor;

public enum VaconConnectionState
{
    Connecting,
    Connected,
    Simulated,
    Stale,
    Unavailable,
}

public sealed record VaconMonitorSnapshot(
    VaconConnectionState State,
    decimal? ActualFrequencyHz,
    DateTimeOffset? LastSuccessfulReadUtc,
    string? FailureCategory,
    int? MotorSpeedRpm = null,
    decimal? MotorCurrentAmperes = null,
    VaconDriveStatus DriveStatus = VaconDriveStatus.Unknown,
    VaconActiveFault? ActiveFault = null,
    VaconStatusWord? StatusWord = null,
    ushort? MotorCurrentRaw = null,
    bool MotorCurrentScaleVerified = false,
    decimal? TargetFrequencyHz = null);

public sealed class VaconMonitorController : IDisposable
{
    private readonly IVaconReadOnlyClient _client;
    private readonly VaconMonitorOptions _options;
    private readonly VaconMonitorLogger _logger;
    private readonly IVaconControlGateway _controlGateway;
    private readonly VaconCommandModel _commandModel;
    private readonly VaconCommandLogger _commandLogger;
    private readonly Func<DateTimeOffset> _utcNow;
    private readonly SemaphoreSlim _operationLock = new(1, 1);
    private bool _disposed;
    private VaconMonitorSnapshot _current;

    public VaconMonitorController(
        IVaconReadOnlyClient client,
        VaconMonitorOptions options,
        VaconMonitorLogger logger,
        IVaconControlGateway? controlGateway = null,
        Func<DateTimeOffset>? utcNow = null)
    {
        _client = client;
        _options = options;
        _logger = logger;
        _controlGateway = controlGateway ?? new BlockedLiveVaconControlGateway();
        _commandModel = new VaconCommandModel(_controlGateway.IsSimulation, _controlGateway.Limits);
        _commandLogger = new VaconCommandLogger(_logger, options.DriveId, _controlGateway.IsSimulation);
        _utcNow = utcNow ?? (() => DateTimeOffset.UtcNow);
        _current = new VaconMonitorSnapshot(VaconConnectionState.Connecting, null, null, null);
    }

    public event Action<VaconMonitorSnapshot>? Updated;

    public VaconMonitorSnapshot Current => _current;

    public bool ControlsEnabled => _controlGateway.ControlsEnabled &&
        (_current.State == VaconConnectionState.Simulated || _current.State == VaconConnectionState.Connected);

    public bool IsSimulation => _controlGateway.IsSimulation;

    public VaconControlLimits? ControlLimits => _controlGateway.Limits;

    public string ControlsDisabledReason => _controlGateway.DisabledReason;

    public async Task PollOnceAsync(CancellationToken cancellationToken)
    {
        ThrowIfDisposed();

        if (!await _operationLock.WaitAsync(0, cancellationToken).ConfigureAwait(false))
        {
            return;
        }

        try
        {
            var reading = await _client.ReadAsync(cancellationToken).ConfigureAwait(false);
            PublishReading(reading);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (VaconReadException exception)
        {
            PublishFailure(exception.Category);
        }
        catch (Exception)
        {
            PublishFailure("read-error");
        }
        finally
        {
            _operationLock.Release();
        }
    }

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await PollOnceAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }

            try
            {
                await Task.Delay(_options.PollInterval, cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
        }
    }

    public Task<VaconControlAttempt> ApplyTargetFrequencyAsync(
        decimal targetHz,
        bool confirmed,
        CancellationToken cancellationToken) =>
        ExecuteControlAsync(VaconControlCommand.SetFrequency, targetHz, confirmed, cancellationToken);

    public Task<VaconControlAttempt> StartMotorAsync(bool confirmed, CancellationToken cancellationToken) =>
        ExecuteControlAsync(VaconControlCommand.StartMotor, null, confirmed, cancellationToken);

    public Task<VaconControlAttempt> StopMotorAsync(bool confirmed, CancellationToken cancellationToken) =>
        ExecuteControlAsync(VaconControlCommand.StopMotor, null, confirmed, cancellationToken);

    public void Dispose()
    {
        _disposed = true;
    }

    private void PublishFailure(string category)
    {
        _logger.LogFailure(category);
        var lastRead = _current.LastSuccessfulReadUtc;
        var hasFreshPreviousValue = lastRead is not null && _utcNow() - lastRead.Value < _options.StaleAfter;
        var state = hasFreshPreviousValue ? VaconConnectionState.Stale : VaconConnectionState.Unavailable;
        Publish(_current with { State = state, FailureCategory = category });
    }

    private async Task<VaconControlAttempt> ExecuteControlAsync(
        VaconControlCommand command,
        decimal? targetHz,
        bool confirmed,
        CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        var preparation = _commandModel.Prepare(command, targetHz, confirmed);
        if (!preparation.Validation.Accepted)
        {
            var rejected = new VaconControlAttempt(command, targetHz, false, preparation.Validation.ResultCode);
            _commandLogger.Log(rejected, _current.ActualFrequencyHz);
            return rejected;
        }

        await _operationLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var result = await _controlGateway.ExecuteAsync(command, targetHz, cancellationToken).ConfigureAwait(false);
            VaconInputRegisterSnapshot? readback = null;

            if (result.Accepted)
            {
                try
                {
                    readback = await _client.ReadAsync(cancellationToken).ConfigureAwait(false);
                    PublishReading(readback);
                }
                catch (VaconReadException exception)
                {
                    PublishFailure(exception.Category);
                }
                catch (Exception)
                {
                    PublishFailure("read-error");
                }
            }

            var acknowledged = result.Accepted && readback is not null && IsAcknowledged(command, targetHz, readback);
            var completed = result with
            {
                ReadbackFrequencyHz = readback?.ActualFrequencyHz,
                Acknowledged = acknowledged,
                ResultCode = result.Accepted && !acknowledged ? "simulated-readback-not-acknowledged" : result.ResultCode,
                SimulatedControlWord = preparation.Command?.ControlWord,
                SimulatedReferenceRaw = preparation.Command?.NormalizedReference,
            };
            _commandLogger.Log(completed, readback?.ActualFrequencyHz ?? _current.ActualFrequencyHz);
            return completed;
        }
        finally
        {
            _operationLock.Release();
        }
    }

    private void PublishReading(VaconInputRegisterSnapshot reading)
    {
        var state = _options.Simulated ? VaconConnectionState.Simulated : VaconConnectionState.Connected;
        Publish(new VaconMonitorSnapshot(
            state,
            reading.ActualFrequencyHz,
            reading.ObservedAtUtc,
            null,
            reading.MotorSpeedRpm,
            reading.MotorCurrentAmperes,
            reading.DriveStatus,
            reading.ActiveFault,
            reading.StatusWord,
            reading.MotorCurrentRaw,
            reading.MotorCurrentScaleVerified,
            reading.TargetFrequencyHz));
    }

    private void Publish(VaconMonitorSnapshot snapshot)
    {
        _current = snapshot;
        Updated?.Invoke(snapshot);
    }

    private static bool IsAcknowledged(
        VaconControlCommand command,
        decimal? targetHz,
        VaconInputRegisterSnapshot readback) => command switch
    {
        VaconControlCommand.SetFrequency => targetHz is decimal target &&
            readback.TargetFrequencyHz is decimal actualTarget && actualTarget == target,
        VaconControlCommand.StartMotor => readback.DriveStatus == VaconDriveStatus.Running,
        VaconControlCommand.StopMotor => readback.DriveStatus == VaconDriveStatus.Stopped,
        _ => false,
    };

    private void ThrowIfDisposed()
    {
        if (_disposed)
        {
            throw new ObjectDisposedException(nameof(VaconMonitorController));
        }
    }
}

