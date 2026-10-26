using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Fjellfisk.SensorCollector;

public sealed class CollectorIdentity
{
    internal CollectorIdentity(
        string collectorDeviceId,
        byte[] deviceSecret,
        DateTimeOffset createdAtUtc)
    {
        CollectorDeviceId = collectorDeviceId;
        DeviceSecret = deviceSecret;
        CreatedAtUtc = createdAtUtc;
    }

    public string CollectorDeviceId { get; }

    public DateTimeOffset CreatedAtUtc { get; }

    // The secret is intentionally unavailable outside this assembly.
    internal byte[] DeviceSecret { get; }
}

public sealed class CollectorIdentityStore
{
    private const string IdentityFileName = "identity.json";
    private readonly string _dataDirectory;
    private readonly IClock _clock;

    public CollectorIdentityStore(string dataDirectory, IClock clock)
    {
        if (string.IsNullOrWhiteSpace(dataDirectory))
        {
            throw new ArgumentException("A collector data directory is required.", nameof(dataDirectory));
        }

        _dataDirectory = dataDirectory;
        _clock = clock;
    }

    public static string DefaultDataDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "Fjellfisk",
        "SensorCollector");

    public string IdentityPath => Path.Combine(_dataDirectory, IdentityFileName);

    public CollectorIdentity LoadOrCreate()
    {
        if (File.Exists(IdentityPath))
        {
            return Load();
        }

        Directory.CreateDirectory(_dataDirectory);
        var identity = new CollectorIdentity(
            $"collector-{Guid.NewGuid():N}",
            RandomNumberGenerator.GetBytes(32),
            _clock.UtcNow);
        Persist(identity);
        return identity;
    }

    private CollectorIdentity Load()
    {
        var document = JsonSerializer.Deserialize<IdentityDocument>(File.ReadAllText(IdentityPath))
            ?? throw new InvalidOperationException("Collector identity is empty.");

        if (string.IsNullOrWhiteSpace(document.CollectorDeviceId) ||
            string.IsNullOrWhiteSpace(document.ProtectedDeviceSecret))
        {
            throw new InvalidOperationException("Collector identity is invalid.");
        }

        return new CollectorIdentity(
            document.CollectorDeviceId,
            LocalMachineSecretProtector.Unprotect(document.ProtectedDeviceSecret),
            document.CreatedAtUtc);
    }

    private void Persist(CollectorIdentity identity)
    {
        var document = new IdentityDocument(
            identity.CollectorDeviceId,
            LocalMachineSecretProtector.Protect(identity.DeviceSecret),
            identity.CreatedAtUtc);
        var temporaryPath = $"{IdentityPath}.tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(document));
        File.Move(temporaryPath, IdentityPath, overwrite: true);
    }

    private sealed record IdentityDocument(
        string CollectorDeviceId,
        string ProtectedDeviceSecret,
        DateTimeOffset CreatedAtUtc);
}

public enum EnrollmentState
{
    Unregistered,
    Pending,
    Connected,
    Revoked,
    Error,
}

public sealed record EnrollmentSnapshot(
    EnrollmentState State,
    string? ClaimCode,
    DateTimeOffset? ExpiresAtUtc,
    string? LastError);

public sealed class CollectorLocalStateStore
{
    private const string StateFileName = "enrollment.json";
    private readonly string _dataDirectory;

    public CollectorLocalStateStore(string dataDirectory)
    {
        _dataDirectory = dataDirectory;
    }

    public EnrollmentSnapshot GetEnrollmentSnapshot()
    {
        var document = LoadDocument();
        return new EnrollmentSnapshot(
            document.State,
            document.ClaimCode,
            document.ExpiresAtUtc,
            document.LastError);
    }

    internal string? GetPendingSession() =>
        LoadDocument().ProtectedClaimSession is { Length: > 0 } protectedSession
            ? LocalMachineSecretProtector.UnprotectToString(protectedSession)
            : null;

    internal string? GetDeviceCredential() =>
        LoadDocument().ProtectedDeviceCredential is { Length: > 0 } protectedCredential
            ? LocalMachineSecretProtector.UnprotectToString(protectedCredential)
            : null;

    internal void MarkPending(
        string claimCode,
        DateTimeOffset expiresAtUtc,
        string claimSession)
    {
        SaveDocument(new EnrollmentDocument(
            EnrollmentState.Pending,
            claimCode,
            expiresAtUtc,
            LocalMachineSecretProtector.ProtectString(claimSession),
            null,
            null));
    }

    internal void MarkConnected(string deviceCredential)
    {
        SaveDocument(new EnrollmentDocument(
            EnrollmentState.Connected,
            null,
            null,
            null,
            LocalMachineSecretProtector.ProtectString(deviceCredential),
            null));
    }

    internal void MarkRevoked()
    {
        SaveDocument(new EnrollmentDocument(
            EnrollmentState.Revoked,
            null,
            null,
            null,
            null,
            null));
    }

    internal void MarkError(string safeError)
    {
        SaveDocument(LoadDocument() with { State = EnrollmentState.Error, LastError = safeError });
    }

    private EnrollmentDocument LoadDocument()
    {
        var path = Path.Combine(_dataDirectory, StateFileName);
        if (!File.Exists(path))
        {
            return EnrollmentDocument.Unregistered;
        }

        return JsonSerializer.Deserialize<EnrollmentDocument>(File.ReadAllText(path))
            ?? EnrollmentDocument.Unregistered;
    }

    private void SaveDocument(EnrollmentDocument document)
    {
        Directory.CreateDirectory(_dataDirectory);
        var path = Path.Combine(_dataDirectory, StateFileName);
        var temporaryPath = $"{path}.tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(document));
        File.Move(temporaryPath, path, overwrite: true);
    }

    private sealed record EnrollmentDocument(
        EnrollmentState State,
        string? ClaimCode,
        DateTimeOffset? ExpiresAtUtc,
        string? ProtectedClaimSession,
        string? ProtectedDeviceCredential,
        string? LastError)
    {
        public static readonly EnrollmentDocument Unregistered = new(
            EnrollmentState.Unregistered,
            null,
            null,
            null,
            null,
            null);
    }
}

internal static class LocalMachineSecretProtector
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("Fjellfisk.SensorCollector.v1");

    public static string Protect(byte[] value) => Convert.ToBase64String(
        ProtectedData.Protect(value, Entropy, DataProtectionScope.LocalMachine));

    public static byte[] Unprotect(string value) => ProtectedData.Unprotect(
        Convert.FromBase64String(value),
        Entropy,
        DataProtectionScope.LocalMachine);

    public static string ProtectString(string value) => Protect(Encoding.UTF8.GetBytes(value));

    public static string UnprotectToString(string value) => Encoding.UTF8.GetString(Unprotect(value));
}
