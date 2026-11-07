using System.Security.Cryptography;
using System.Text;

namespace Fjellfisk.SensorCollector;

public sealed record CollectorRegistrationRequest(
    string CollectorDeviceId,
    string RegistrationProof);

public sealed record EnrollmentRegistration(
    string ClaimCode,
    DateTimeOffset ExpiresAtUtc,
    string ClaimSession);

public sealed record EnrollmentPollResult(
    EnrollmentState State,
    string? DeviceCredential,
    string? SafeError);

// This is a future HTTPS boundary. It contains no organization, site, or Firebase data.
public interface IEnrollmentProvider
{
    Task<EnrollmentRegistration> RegisterAsync(
        CollectorRegistrationRequest request,
        CancellationToken cancellationToken);

    Task<EnrollmentPollResult> PollAsync(
        string claimSession,
        CancellationToken cancellationToken);
}

public sealed class EnrollmentCoordinator
{
    public static readonly TimeSpan PendingPollInterval = TimeSpan.FromSeconds(30);

    private readonly CollectorIdentity _identity;
    private readonly CollectorLocalStateStore _localState;
    private readonly IEnrollmentProvider _provider;
    private readonly IClock _clock;
    private readonly ICollectorLogger _logger;

    public EnrollmentCoordinator(
        CollectorIdentity identity,
        CollectorLocalStateStore localState,
        IEnrollmentProvider provider,
        IClock clock,
        ICollectorLogger logger)
    {
        _identity = identity;
        _localState = localState;
        _provider = provider;
        _clock = clock;
        _logger = logger;
    }

    public EnrollmentSnapshot Current => _localState.GetEnrollmentSnapshot();

    public async Task<EnrollmentSnapshot> StartOrResumeAsync(CancellationToken cancellationToken)
    {
        var current = Current;
        if (current.State == EnrollmentState.Connected || current.State == EnrollmentState.Revoked)
        {
            return current;
        }

        if (current.State == EnrollmentState.Pending)
        {
            return await PollPendingOnceAsync(cancellationToken);
        }

        try
        {
            var registration = await _provider.RegisterAsync(
                CreateRegistrationRequest(_identity),
                cancellationToken);
            _localState.MarkPending(
                registration.ClaimCode,
                registration.ExpiresAtUtc,
                registration.ClaimSession);
            _logger.Log("enrollment_pending", "Collector pairing code was created.");
            return Current;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.Log("enrollment_error", exception.Message);
            _localState.MarkError("Enrollment is temporarily unavailable.");
            return Current;
        }
    }

    public async Task<EnrollmentSnapshot> PollPendingOnceAsync(CancellationToken cancellationToken)
    {
        var current = Current;
        if (current.State != EnrollmentState.Pending)
        {
            return current;
        }

        if (current.ExpiresAtUtc is { } expiresAtUtc && expiresAtUtc <= _clock.UtcNow)
        {
            _localState.MarkError("The pairing code has expired.");
            _logger.Log("enrollment_expired", "Collector pairing code expired.");
            return Current;
        }

        var claimSession = _localState.GetPendingSession();
        if (string.IsNullOrWhiteSpace(claimSession))
        {
            _localState.MarkError("The local pairing session is unavailable.");
            return Current;
        }

        try
        {
            var result = await _provider.PollAsync(claimSession, cancellationToken);
            switch (result.State)
            {
                case EnrollmentState.Pending:
                    return Current;
                case EnrollmentState.Connected when !string.IsNullOrWhiteSpace(result.DeviceCredential):
                    _localState.MarkConnected(result.DeviceCredential);
                    _logger.Log("enrollment_connected", "Collector pairing was confirmed.");
                    return Current;
                case EnrollmentState.Revoked:
                    _localState.MarkRevoked();
                    _logger.Log("enrollment_revoked", "Collector enrollment was revoked.");
                    return Current;
                default:
                    _localState.MarkError(result.SafeError ?? "Enrollment could not be completed.");
                    return Current;
            }
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.Log("enrollment_error", exception.Message);
            _localState.MarkError("Enrollment is temporarily unavailable.");
            return Current;
        }
    }

    public async Task<EnrollmentSnapshot> PollPendingUntilResolvedAsync(
        IAsyncDelay delay,
        CancellationToken cancellationToken)
    {
        while (Current.State == EnrollmentState.Pending)
        {
            await delay.DelayAsync(PendingPollInterval, cancellationToken);
            await PollPendingOnceAsync(cancellationToken);
        }

        return Current;
    }

    private static CollectorRegistrationRequest CreateRegistrationRequest(CollectorIdentity identity)
    {
        var proofBytes = HMACSHA256.HashData(
            identity.DeviceSecret,
            Encoding.UTF8.GetBytes(identity.CollectorDeviceId));
        return new CollectorRegistrationRequest(
            identity.CollectorDeviceId,
            Convert.ToBase64String(proofBytes));
    }
}

// Local-only behavior for the pairing UI and automated tests. It never opens a network connection.
public sealed class MockEnrollmentProvider : IEnrollmentProvider
{
    private readonly IClock _clock;
    private EnrollmentState _simulatedState = EnrollmentState.Pending;
    private string? _activeSession;

    public MockEnrollmentProvider(IClock clock)
    {
        _clock = clock;
    }

    public Task<EnrollmentRegistration> RegisterAsync(
        CollectorRegistrationRequest request,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (string.IsNullOrWhiteSpace(request.CollectorDeviceId) ||
            string.IsNullOrWhiteSpace(request.RegistrationProof))
        {
            throw new InvalidOperationException("Collector registration request is incomplete.");
        }

        _activeSession = $"mock-session-{Guid.NewGuid():N}";
        _simulatedState = EnrollmentState.Pending;
        return Task.FromResult(new EnrollmentRegistration(
            "FJ-MOCK-0001",
            _clock.UtcNow.AddMinutes(15),
            _activeSession));
    }

    public Task<EnrollmentPollResult> PollAsync(
        string claimSession,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!string.Equals(claimSession, _activeSession, StringComparison.Ordinal))
        {
            return Task.FromResult(new EnrollmentPollResult(
                EnrollmentState.Error,
                null,
                "The pairing session was not found."));
        }

        return Task.FromResult(_simulatedState switch
        {
            EnrollmentState.Connected => new EnrollmentPollResult(
                EnrollmentState.Connected,
                "mock-device-credential",
                null),
            EnrollmentState.Revoked => new EnrollmentPollResult(
                EnrollmentState.Revoked,
                null,
                null),
            EnrollmentState.Pending => new EnrollmentPollResult(
                EnrollmentState.Pending,
                null,
                null),
            _ => new EnrollmentPollResult(
                EnrollmentState.Error,
                null,
                "Mock enrollment reported an error."),
        });
    }

    public void SimulateConnected() => _simulatedState = EnrollmentState.Connected;

    public void SimulateRevoked() => _simulatedState = EnrollmentState.Revoked;
}
