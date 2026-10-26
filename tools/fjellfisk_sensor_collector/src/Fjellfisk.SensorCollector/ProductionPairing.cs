using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace Fjellfisk.SensorCollector;

/// <summary>
/// The collector-side pairing states are intentionally independent from Vigo,
/// discovery, sensor quality, and upload state.
/// </summary>
public enum CollectorPairingState
{
    Starting,
    BackendUnavailable,
    Registering,
    Unpaired,
    PairingCodeActive,
    PairingCodeExpired,
    Paired,
    Revoked,
    AuthenticationFailed,
}

public sealed record CollectorPairingSnapshot(
    CollectorPairingState State,
    bool BackendConfigured,
    string? CollectorId,
    DateTimeOffset? PairingCodeExpiresAtUtc,
    string? SafeMessage);

public sealed record PairingCodePresentation(
    string Code,
    DateTimeOffset ExpiresAtUtc);

public sealed record CollectorBackendIdentity(
    string CollectorId,
    string DeviceCredential);

public sealed record CollectorBackendStatus(
    string CollectorId,
    string State,
    string? OrganizationId,
    string? SiteId,
    DateTimeOffset? PairedAtUtc);

public interface ICollectorPairingDelay
{
    Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken);
}

public sealed class SystemCollectorPairingDelay : ICollectorPairingDelay
{
    public static readonly SystemCollectorPairingDelay Instance = new();

    private SystemCollectorPairingDelay()
    {
    }

    public Task DelayAsync(TimeSpan delay, CancellationToken cancellationToken) =>
        Task.Delay(delay, cancellationToken);
}

public interface ICollectorPairingLogger
{
    void Log(string eventName, string message);
}

/// <summary>
/// Pairing logs deliberately accept only caller-supplied safe event text. No
/// request payload, pairing code, or credential is ever written to disk.
/// </summary>
public sealed class PairingFileLogger : ICollectorPairingLogger
{
    private readonly string _path;
    private readonly object _gate = new();

    public PairingFileLogger(string directory)
    {
        Directory.CreateDirectory(directory);
        _path = Path.Combine(directory, "pairing.log");
    }

    public void Log(string eventName, string message)
    {
        lock (_gate)
        {
            File.AppendAllText(
                _path,
                $"{DateTimeOffset.UtcNow:O} [{eventName}] {message}{Environment.NewLine}");
        }
    }
}

public sealed record CollectorPairingBackendConfiguration(
    Uri? Endpoint,
    string Source)
{
    private const string EnvironmentVariable = "FJELLFISK_COLLECTOR_PAIRING_URL";
    private const string ConfigFileName = "pairing-backend.json";

    public bool IsConfigured => Endpoint is not null;

    public static CollectorPairingBackendConfiguration Load(
        IReadOnlyCollection<string> arguments,
        string configDirectory)
    {
        var commandLineValue = ReadOption(arguments, "--pairing-backend-url=");
        var environmentValue = Environment.GetEnvironmentVariable(EnvironmentVariable);
        var configValue = ReadConfigValue(Path.Combine(configDirectory, ConfigFileName));
        var value = commandLineValue ?? environmentValue ?? configValue;
        var source = commandLineValue is not null
            ? "command line"
            : environmentValue is not null
                ? "environment"
                : configValue is not null
                    ? "local configuration"
                    : "not configured";

        if (string.IsNullOrWhiteSpace(value))
        {
            return new CollectorPairingBackendConfiguration(null, source);
        }

        if (!Uri.TryCreate(value, UriKind.Absolute, out var endpoint) ||
            string.IsNullOrWhiteSpace(endpoint.Host))
        {
            throw new ArgumentException("The pairing backend URL is invalid.");
        }

        var emulatorAllowed = arguments.Contains("--pairing-emulator", StringComparer.OrdinalIgnoreCase);
        var isLoopbackHttp = string.Equals(endpoint.Scheme, Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) &&
            (endpoint.IsLoopback || string.Equals(endpoint.Host, "localhost", StringComparison.OrdinalIgnoreCase));
        if (!string.Equals(endpoint.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) &&
            !(emulatorAllowed && isLoopbackHttp))
        {
            throw new ArgumentException(
                "Pairing requires an HTTPS endpoint. HTTP is allowed only for an explicitly selected local emulator.");
        }

        var normalized = endpoint.AbsoluteUri.EndsWith("/", StringComparison.Ordinal)
            ? endpoint
            : new Uri(endpoint.AbsoluteUri + "/", UriKind.Absolute);
        return new CollectorPairingBackendConfiguration(normalized, source);
    }

    private static string? ReadOption(IReadOnlyCollection<string> arguments, string prefix) =>
        arguments.FirstOrDefault(argument => argument.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))?[prefix.Length..];

    private static string? ReadConfigValue(string configPath)
    {
        if (!File.Exists(configPath))
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(configPath));
            return document.RootElement.TryGetProperty("endpoint", out var endpoint) &&
                endpoint.ValueKind == JsonValueKind.String
                ? endpoint.GetString()
                : null;
        }
        catch (JsonException exception)
        {
            throw new ArgumentException("The local pairing backend configuration is invalid.", exception);
        }
    }
}

public sealed class CollectorPairingBackendException : Exception
{
    public CollectorPairingBackendException(string stableCode, HttpStatusCode? statusCode = null)
        : base(stableCode)
    {
        StableCode = stableCode;
        StatusCode = statusCode;
    }

    public string StableCode { get; }

    public HttpStatusCode? StatusCode { get; }

    public bool IsAuthenticationFailure =>
        StableCode is "COLLECTOR_AUTH_FAILED" or "COLLECTOR_NOT_FOUND";
}

public interface ICollectorPairingBackend
{
    Task<CollectorBackendIdentity> RegisterAsync(
        string collectorVersion,
        string platform,
        CancellationToken cancellationToken);

    Task<CollectorBackendStatus> GetStatusAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken);

    Task<(CollectorBackendStatus Status, PairingCodePresentation? PairingCode)> IssuePairingCodeAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken);
}

/// <summary>
/// Minimal client for the deployed Functions contract. It deliberately has no
/// Firebase SDK, service account, or production secret.
/// </summary>
public sealed class HttpCollectorPairingBackend : ICollectorPairingBackend, IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly Uri _endpoint;
    private readonly HttpClient _httpClient;
    private readonly bool _disposeClient;

    public HttpCollectorPairingBackend(
        CollectorPairingBackendConfiguration configuration,
        HttpClient? httpClient = null)
    {
        if (configuration.Endpoint is null)
        {
            throw new ArgumentException("A configured pairing backend URL is required.", nameof(configuration));
        }

        _endpoint = configuration.Endpoint;
        _httpClient = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        _disposeClient = httpClient is null;
    }

    public async Task<CollectorBackendIdentity> RegisterAsync(
        string collectorVersion,
        string platform,
        CancellationToken cancellationToken)
    {
        var body = JsonSerializer.Serialize(new RegistrationRequest(collectorVersion, platform));
        using var request = new HttpRequestMessage(HttpMethod.Post, new Uri(_endpoint, "register"))
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        var response = await SendAsync<RegistrationResponse>(request, cancellationToken);
        if (response.State != "UNPAIRED" || string.IsNullOrWhiteSpace(response.CollectorId) ||
            string.IsNullOrWhiteSpace(response.DeviceCredential))
        {
            throw new CollectorPairingBackendException("BACKEND_INVALID_RESPONSE");
        }

        return new CollectorBackendIdentity(response.CollectorId, response.DeviceCredential);
    }

    public async Task<CollectorBackendStatus> GetStatusAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken)
    {
        using var request = CreateAuthenticatedRequest(HttpMethod.Get, "status", identity);
        return ToStatus(await SendAsync<StatusResponse>(request, cancellationToken));
    }

    public async Task<(CollectorBackendStatus Status, PairingCodePresentation? PairingCode)> IssuePairingCodeAsync(
        CollectorBackendIdentity identity,
        CancellationToken cancellationToken)
    {
        using var request = CreateAuthenticatedRequest(HttpMethod.Post, "pairing-code", identity);
        request.Content = new StringContent("{}", Encoding.UTF8, "application/json");
        var response = await SendAsync<PairingCodeResponse>(request, cancellationToken);
        var status = ToStatus(response);
        if (status.State != "UNPAIRED")
        {
            return (status, null);
        }

        if (string.IsNullOrWhiteSpace(response.Code) || string.IsNullOrWhiteSpace(response.ExpiresAt) ||
            !DateTimeOffset.TryParse(response.ExpiresAt, out var expiresAtUtc))
        {
            throw new CollectorPairingBackendException("BACKEND_INVALID_RESPONSE");
        }

        return (status, new PairingCodePresentation(response.Code, expiresAtUtc.ToUniversalTime()));
    }

    public void Dispose()
    {
        if (_disposeClient)
        {
            _httpClient.Dispose();
        }
    }

    private HttpRequestMessage CreateAuthenticatedRequest(
        HttpMethod method,
        string relativePath,
        CollectorBackendIdentity identity)
    {
        var request = new HttpRequestMessage(method, new Uri(_endpoint, relativePath));
        request.Headers.Add("x-fjellfisk-collector-id", identity.CollectorId);
        request.Headers.Add("x-fjellfisk-device-credential", identity.DeviceCredential);
        return request;
    }

    private async Task<T> SendAsync<T>(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        try
        {
            using var response = await _httpClient.SendAsync(request, cancellationToken);
            var content = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                throw new CollectorPairingBackendException(
                    ReadErrorCode(content) ?? "BACKEND_UNAVAILABLE",
                    response.StatusCode);
            }

            return JsonSerializer.Deserialize<T>(content, JsonOptions)
                ?? throw new CollectorPairingBackendException("BACKEND_INVALID_RESPONSE");
        }
        catch (CollectorPairingBackendException)
        {
            throw;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new CollectorPairingBackendException("BACKEND_TIMEOUT");
        }
        catch (HttpRequestException)
        {
            throw new CollectorPairingBackendException("BACKEND_UNAVAILABLE");
        }
    }

    private static string? ReadErrorCode(string content)
    {
        try
        {
            using var document = JsonDocument.Parse(content);
            return document.RootElement.TryGetProperty("error", out var error) &&
                error.TryGetProperty("code", out var code) &&
                code.ValueKind == JsonValueKind.String
                ? code.GetString()
                : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static CollectorBackendStatus ToStatus(StatusResponse response)
    {
        if (string.IsNullOrWhiteSpace(response.CollectorId) ||
            response.State is not ("UNPAIRED" or "PAIRED" or "REVOKED"))
        {
            throw new CollectorPairingBackendException("BACKEND_INVALID_RESPONSE");
        }

        DateTimeOffset? pairedAtUtc = null;
        if (!string.IsNullOrWhiteSpace(response.PairedAt) && DateTimeOffset.TryParse(response.PairedAt, out var parsed))
        {
            pairedAtUtc = parsed.ToUniversalTime();
        }

        return new CollectorBackendStatus(
            response.CollectorId,
            response.State,
            response.OrganizationId,
            response.SiteId,
            pairedAtUtc);
    }

    private sealed record RegistrationRequest(string CollectorVersion, string Platform);

    private sealed record RegistrationResponse(string? CollectorId, string? DeviceCredential, string? State);

    private record StatusResponse(
        string? CollectorId,
        string? State,
        string? OrganizationId,
        string? SiteId,
        string? PairedAt);

    private sealed record PairingCodeResponse(
        string? CollectorId,
        string? State,
        string? OrganizationId,
        string? SiteId,
        string? PairedAt,
        string? Code,
        string? ExpiresAt) : StatusResponse(CollectorId, State, OrganizationId, SiteId, PairedAt);
}

/// <summary>
/// Keeps backend credentials in a separate DPAPI-protected document. It never
/// persists pairing codes, so every unpaired restart obtains a fresh code.
/// </summary>
public sealed class CollectorPairingStateStore
{
    private const string StateFileName = "pairing.json";
    private readonly string _identityDirectory;

    public CollectorPairingStateStore(string identityDirectory)
    {
        _identityDirectory = identityDirectory;
    }

    public string StatePath => Path.Combine(_identityDirectory, StateFileName);

    public bool HasBackendIdentity => LoadDocument().CollectorId is { Length: > 0 } &&
        LoadDocument().ProtectedDeviceCredential is { Length: > 0 };

    internal CollectorBackendIdentity? GetBackendIdentity()
    {
        var document = LoadDocument();
        return document.CollectorId is { Length: > 0 } collectorId &&
            document.ProtectedDeviceCredential is { Length: > 0 } protectedCredential
            ? new CollectorBackendIdentity(
                collectorId,
                LocalMachineSecretProtector.UnprotectToString(protectedCredential))
            : null;
    }

    internal void SaveBackendIdentity(CollectorBackendIdentity identity)
    {
        SaveDocument(LoadDocument() with
        {
            CollectorId = identity.CollectorId,
            ProtectedDeviceCredential = LocalMachineSecretProtector.ProtectString(identity.DeviceCredential),
            LastState = CollectorPairingState.Unpaired,
            LastError = null,
        });
    }

    internal void SaveState(CollectorPairingState state, string? safeError)
    {
        SaveDocument(LoadDocument() with { LastState = state, LastError = safeError });
    }

    public CollectorPairingSnapshot GetStoredSnapshot(bool backendConfigured)
    {
        var document = LoadDocument();
        return new CollectorPairingSnapshot(
            document.LastState ?? CollectorPairingState.Starting,
            backendConfigured,
            document.CollectorId,
            null,
            document.LastError);
    }

    private PairingDocument LoadDocument()
    {
        if (!File.Exists(StatePath))
        {
            return PairingDocument.Empty;
        }

        return JsonSerializer.Deserialize<PairingDocument>(File.ReadAllText(StatePath)) ?? PairingDocument.Empty;
    }

    private void SaveDocument(PairingDocument document)
    {
        Directory.CreateDirectory(_identityDirectory);
        var temporaryPath = $"{StatePath}.tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(document));
        File.Move(temporaryPath, StatePath, overwrite: true);
    }

    private sealed record PairingDocument(
        string? CollectorId,
        string? ProtectedDeviceCredential,
        CollectorPairingState? LastState,
        string? LastError)
    {
        public static readonly PairingDocument Empty = new(null, null, null, null);
    }
}

public interface ICollectorPairingUi
{
    event EventHandler? RetryRequested;

    Task ShowPairingCodeAsync(PairingCodePresentation pairingCode, CancellationToken cancellationToken);

    Task ShowBackendUnavailableAsync(CancellationToken cancellationToken);

    Task CloseAsync(CancellationToken cancellationToken);
}

public sealed class NullCollectorPairingUi : ICollectorPairingUi
{
    public event EventHandler? RetryRequested
    {
        add { }
        remove { }
    }

    public Task ShowPairingCodeAsync(PairingCodePresentation pairingCode, CancellationToken cancellationToken) => Task.CompletedTask;

    public Task ShowBackendUnavailableAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task CloseAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed class CollectorPairingCoordinator
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(15);
    private static readonly TimeSpan PairedStatusInterval = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan RevokedStatusInterval = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan[] RetryDelays =
    {
        TimeSpan.FromSeconds(5),
        TimeSpan.FromSeconds(15),
        TimeSpan.FromSeconds(30),
        TimeSpan.FromMinutes(1),
        TimeSpan.FromMinutes(2),
        TimeSpan.FromMinutes(5),
    };

    private readonly CollectorPairingStateStore _stateStore;
    private readonly ICollectorPairingBackend _backend;
    private readonly ICollectorPairingUi _ui;
    private readonly ICollectorPairingLogger _logger;
    private readonly IClock _clock;
    private readonly ICollectorPairingDelay _delay;
    private readonly string _collectorVersion;
    private readonly string _platform;
    private readonly bool _backendConfigured;
    private readonly object _retryGate = new();
    private TaskCompletionSource<bool> _retryRequested = CreateRetrySignal();
    private int _retryIndex;
    private PairingCodePresentation? _activeCode;

    public CollectorPairingCoordinator(
        CollectorPairingStateStore stateStore,
        ICollectorPairingBackend backend,
        ICollectorPairingUi ui,
        ICollectorPairingLogger logger,
        IClock clock,
        ICollectorPairingDelay delay,
        string collectorVersion,
        string platform,
        bool backendConfigured = true)
    {
        _stateStore = stateStore;
        _backend = backend;
        _ui = ui;
        _logger = logger;
        _clock = clock;
        _delay = delay;
        _collectorVersion = collectorVersion;
        _platform = platform;
        _backendConfigured = backendConfigured;
        Snapshot = stateStore.GetStoredSnapshot(backendConfigured);
        _ui.RetryRequested += OnRetryRequested;
    }

    public CollectorPairingSnapshot Snapshot { get; private set; }

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                await RunSingleCycleAsync(cancellationToken);
                await WaitForNextCycleAsync(cancellationToken);
            }
        }
        finally
        {
            _ui.RetryRequested -= OnRetryRequested;
        }
    }

    public async Task RunSingleCycleAsync(CancellationToken cancellationToken)
    {
        if (!_backendConfigured)
        {
            await EnterBackendUnavailableAsync("Pairing-backend er ikke konfigurert.", cancellationToken);
            return;
        }

        var identity = _stateStore.GetBackendIdentity();
        if (identity is null)
        {
            Transition(CollectorPairingState.Registering, null, null, "Registrerer Collector.");
            try
            {
                identity = await _backend.RegisterAsync(_collectorVersion, _platform, cancellationToken);
                _stateStore.SaveBackendIdentity(identity);
                _retryIndex = 0;
                _logger.Log("pairing_registration_success", "Collector registration completed.");
            }
            catch (CollectorPairingBackendException exception) when (exception.IsAuthenticationFailure)
            {
                await EnterAuthenticationFailedAsync(exception.StableCode, cancellationToken);
                return;
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                await EnterBackendUnavailableAsync("Venter på tilkobling til Fjellfisk.", cancellationToken);
                return;
            }
        }

        try
        {
            var status = await _backend.GetStatusAsync(identity, cancellationToken);
            _retryIndex = 0;
            await ApplyBackendStatusAsync(identity, status, cancellationToken);
        }
        catch (CollectorPairingBackendException exception) when (exception.IsAuthenticationFailure)
        {
            await EnterAuthenticationFailedAsync(exception.StableCode, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            await EnterBackendUnavailableAsync("Venter på tilkobling til Fjellfisk.", cancellationToken);
        }
    }

    private async Task ApplyBackendStatusAsync(
        CollectorBackendIdentity identity,
        CollectorBackendStatus status,
        CancellationToken cancellationToken)
    {
        switch (status.State)
        {
            case "PAIRED":
                _activeCode = null;
                await _ui.CloseAsync(cancellationToken);
                Transition(CollectorPairingState.Paired, identity.CollectorId, null, null);
                _logger.Log("pairing_paired", "Collector pairing was confirmed.");
                return;

            case "REVOKED":
                _activeCode = null;
                await _ui.CloseAsync(cancellationToken);
                Transition(CollectorPairingState.Revoked, identity.CollectorId, null, "Tilgangen til denne Collectoren er tilbakekalt.");
                _logger.Log("pairing_revoked", "Collector pairing was revoked by the backend.");
                return;

            case "UNPAIRED":
                if (_activeCode is { } activeCode && activeCode.ExpiresAtUtc > _clock.UtcNow)
                {
                    Transition(CollectorPairingState.PairingCodeActive, identity.CollectorId, activeCode.ExpiresAtUtc, null);
                    return;
                }

                if (_activeCode is not null)
                {
                    _activeCode = null;
                    await _ui.CloseAsync(cancellationToken);
                    Transition(CollectorPairingState.PairingCodeExpired, identity.CollectorId, null, "Paringskoden er utløpt.");
                    _logger.Log("pairing_code_expired", "The backend pairing code expired.");
                }

                await IssuePairingCodeAsync(identity, cancellationToken);
                return;

            default:
                await EnterBackendUnavailableAsync("Fjellfisk kunne ikke lese pairing-status.", cancellationToken);
                return;
        }
    }

    private async Task IssuePairingCodeAsync(CollectorBackendIdentity identity, CancellationToken cancellationToken)
    {
        Transition(CollectorPairingState.Unpaired, identity.CollectorId, null, null);
        try
        {
            var result = await _backend.IssuePairingCodeAsync(identity, cancellationToken);
            _retryIndex = 0;
            if (result.Status.State != "UNPAIRED")
            {
                await ApplyBackendStatusAsync(identity, result.Status, cancellationToken);
                return;
            }

            if (result.PairingCode is null || result.PairingCode.ExpiresAtUtc <= _clock.UtcNow)
            {
                await EnterBackendUnavailableAsync("Fjellfisk kunne ikke opprette en gyldig paringskode.", cancellationToken);
                return;
            }

            _activeCode = result.PairingCode;
            await _ui.ShowPairingCodeAsync(result.PairingCode, cancellationToken);
            Transition(
                CollectorPairingState.PairingCodeActive,
                identity.CollectorId,
                result.PairingCode.ExpiresAtUtc,
                null);
            _logger.Log("pairing_code_issued", "A pairing code was issued for the collector.");
        }
        catch (CollectorPairingBackendException exception) when (exception.IsAuthenticationFailure)
        {
            await EnterAuthenticationFailedAsync(exception.StableCode, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            await EnterBackendUnavailableAsync("Venter på tilkobling til Fjellfisk.", cancellationToken);
        }
    }

    private async Task EnterBackendUnavailableAsync(string safeMessage, CancellationToken cancellationToken)
    {
        _activeCode = null;
        try
        {
            await _ui.ShowBackendUnavailableAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.Log("pairing_ui_unavailable", "The pairing window could not be shown.");
        }

        Transition(CollectorPairingState.BackendUnavailable, _stateStore.GetBackendIdentity()?.CollectorId, null, safeMessage);
        _logger.Log("pairing_backend_unavailable", "Pairing backend is temporarily unavailable.");
    }

    private async Task EnterAuthenticationFailedAsync(string stableCode, CancellationToken cancellationToken)
    {
        _activeCode = null;
        await _ui.CloseAsync(cancellationToken);
        Transition(
            CollectorPairingState.AuthenticationFailed,
            _stateStore.GetBackendIdentity()?.CollectorId,
            null,
            "Fjellfisk kunne ikke godkjenne denne Collectoren. Kontakt administrator.");
        _logger.Log("pairing_authentication_failed", stableCode);
    }

    private async Task WaitForNextCycleAsync(CancellationToken cancellationToken)
    {
        var delay = Snapshot.State switch
        {
            CollectorPairingState.PairingCodeActive => PollInterval,
            CollectorPairingState.Paired => PairedStatusInterval,
            CollectorPairingState.Revoked or CollectorPairingState.AuthenticationFailed => RevokedStatusInterval,
            CollectorPairingState.BackendUnavailable => RetryDelays[Math.Min(_retryIndex++, RetryDelays.Length - 1)],
            _ => TimeSpan.FromSeconds(1),
        };

        TaskCompletionSource<bool> retrySignal;
        lock (_retryGate)
        {
            retrySignal = _retryRequested;
        }

        var delayTask = _delay.DelayAsync(delay, cancellationToken);
        await Task.WhenAny(delayTask, retrySignal.Task);
        cancellationToken.ThrowIfCancellationRequested();
    }

    private void OnRetryRequested(object? sender, EventArgs eventArgs)
    {
        lock (_retryGate)
        {
            _retryIndex = 0;
            _retryRequested.TrySetResult(true);
            _retryRequested = CreateRetrySignal();
        }
    }

    private void Transition(
        CollectorPairingState state,
        string? collectorId,
        DateTimeOffset? expiresAtUtc,
        string? safeMessage)
    {
        Snapshot = new CollectorPairingSnapshot(
            state,
            _backendConfigured,
            collectorId,
            expiresAtUtc,
            safeMessage);
        _stateStore.SaveState(state, safeMessage);
    }

    private static TaskCompletionSource<bool> CreateRetrySignal() =>
        new(TaskCreationOptions.RunContinuationsAsynchronously);
}
