namespace Fjellfisk.SensorCollector;

public sealed record CollectorUploadRequest(
    Uri Endpoint,
    string DeviceCredential,
    string IdempotencyKey,
    string JsonPayload,
    TimeSpan Timeout);

// The concrete HTTPS transport is deliberately supplied later by the deployment host.
// This preserves a TLS-only, authenticated interface without creating a live endpoint here.
public interface ICollectorHttpsTransport
{
    Task<UploadResult> SendAsync(
        CollectorUploadRequest request,
        CancellationToken cancellationToken);
}

public sealed class HttpsMeasurementUploader : IUploader
{
    private readonly Uri _endpoint;
    private readonly Func<string?> _deviceCredentialProvider;
    private readonly ICollectorHttpsTransport _transport;
    private readonly TimeSpan _timeout;

    public HttpsMeasurementUploader(
        Uri endpoint,
        Func<string?> deviceCredentialProvider,
        ICollectorHttpsTransport transport,
        TimeSpan timeout)
    {
        if (!string.Equals(endpoint.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("Collector uploads require an HTTPS endpoint.", nameof(endpoint));
        }

        if (timeout <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(timeout));
        }

        _endpoint = endpoint;
        _deviceCredentialProvider = deviceCredentialProvider;
        _transport = transport;
        _timeout = timeout;
    }

    public async Task<UploadResult> UploadAsync(
        SensorMeasurement measurement,
        CancellationToken cancellationToken)
    {
        var credential = _deviceCredentialProvider();
        if (string.IsNullOrWhiteSpace(credential))
        {
            return new UploadResult(false, "Collector is not enrolled.");
        }

        var request = new CollectorUploadRequest(
            _endpoint,
            credential,
            measurement.MeasurementId,
            MeasurementJson.Serialize(measurement),
            _timeout);
        using var timeoutCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCancellation.CancelAfter(_timeout);
        try
        {
            return await _transport.SendAsync(request, timeoutCancellation.Token);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new UploadResult(false, "Collector upload timed out.");
        }
    }
}

public sealed class EnrollmentGatedUploader : IUploader
{
    private readonly CollectorLocalStateStore _localState;
    private readonly IUploader _innerUploader;

    public EnrollmentGatedUploader(CollectorLocalStateStore localState, IUploader innerUploader)
    {
        _localState = localState;
        _innerUploader = innerUploader;
    }

    public Task<UploadResult> UploadAsync(
        SensorMeasurement measurement,
        CancellationToken cancellationToken)
    {
        var state = _localState.GetEnrollmentSnapshot().State;
        return state == EnrollmentState.Connected
            ? _innerUploader.UploadAsync(measurement, cancellationToken)
            : Task.FromResult(new UploadResult(false, "Collector enrollment is not connected."));
    }
}
