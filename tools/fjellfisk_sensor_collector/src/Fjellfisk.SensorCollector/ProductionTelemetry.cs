using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace Fjellfisk.SensorCollector;

public sealed record TelemetrySensorReading(string SensorId, string Name, string SourceType,
    float? TemperatureC, float? OxygenMgL, float? OxygenSaturationPct,
    DateTimeOffset TimestampUtc, string Health);

public sealed record TelemetrySensorBatch(string BatchId, string CollectorVersion,
    IReadOnlyList<TelemetrySensorReading> Readings);

public interface IProductionTelemetryUploader
{
    Task UploadAsync(CollectorBackendIdentity identity, TelemetrySensorBatch batch, CancellationToken cancellationToken);
}

public sealed class HttpsProductionTelemetryUploader : IProductionTelemetryUploader, IDisposable
{
    internal static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
    private readonly HttpClient _client;
    private readonly bool _ownsClient;
    private readonly Uri _uri;

    public HttpsProductionTelemetryUploader(CollectorPairingBackendConfiguration configuration, HttpClient? client = null)
    {
        var endpoint = configuration.Endpoint ?? throw new ArgumentException("HTTPS backend must be configured.");
        if (endpoint.Scheme != Uri.UriSchemeHttps)
            throw new ArgumentException("Sensor uploads require HTTPS; emulator pairing does not enable sensor upload.");
        _uri = new Uri(endpoint, "measurements");
        _client = client ?? new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(15) };
        _ownsClient = client is null;
    }

    public async Task UploadAsync(CollectorBackendIdentity identity, TelemetrySensorBatch batch, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, _uri);
        request.Headers.Add("x-fjellfisk-collector-id", identity.CollectorId);
        request.Headers.Add("x-fjellfisk-device-credential", identity.DeviceCredential);
        request.Content = new StringContent(JsonSerializer.Serialize(batch, JsonOptions), Encoding.UTF8, "application/json");
        using var response = await _client.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode) throw new HttpRequestException("Sensor upload rejected.", null, response.StatusCode);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        if (!body.RootElement.TryGetProperty("accepted", out var accepted) ||
            accepted.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            throw new HttpRequestException("Sensor upload acknowledgement is invalid.");
    }

    public void Dispose() { if (_ownsClient) _client.Dispose(); }
}

/// Durable, bounded queue. Credentials and pairing codes never enter batch files.
public sealed class ProductionTelemetryQueue
{
    private readonly string _directory;
    private readonly int _maximumFiles;
    private readonly long _maximumBytes;
    public ProductionTelemetryQueue(string directory, int maximumFiles = 300, long maximumBytes = 50 * 1024 * 1024)
    {
        _directory = directory;
        _maximumFiles = maximumFiles;
        _maximumBytes = maximumBytes;
        Directory.CreateDirectory(_directory);
    }

    public string[] Files => Directory.GetFiles(_directory, "*.sensor-batch.json").OrderBy(path => path, StringComparer.Ordinal).ToArray();
    public bool HasCapacity => Files.Length < _maximumFiles && Files.Sum(path => new FileInfo(path).Length) < _maximumBytes;

    public async Task EnqueueAsync(TelemetrySensorBatch batch, CancellationToken token)
    {
        var json = JsonSerializer.Serialize(batch, HttpsProductionTelemetryUploader.JsonOptions);
        if (!HasCapacity || Encoding.UTF8.GetByteCount(json) + Files.Sum(path => new FileInfo(path).Length) > _maximumBytes)
            throw new IOException("Sensor buffer is full; collection is paused.");
        var path = Path.Combine(_directory, $"{DateTimeOffset.UtcNow.UtcDateTime.Ticks:D19}-{batch.BatchId}.sensor-batch.json");
        await File.WriteAllTextAsync(path + ".tmp", json, token);
        File.Move(path + ".tmp", path);
    }

    public async Task FlushAsync(CollectorBackendIdentity identity, IProductionTelemetryUploader uploader, CancellationToken token)
    {
        foreach (var path in Files.Take(8))
        {
            var batch = JsonSerializer.Deserialize<TelemetrySensorBatch>(await File.ReadAllTextAsync(path, token),
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new IOException("Sensor buffer is invalid.");
            // Match server retention so a week-old offline batch cannot block current readings forever.
            if (batch.Readings.Any(reading => reading.TimestampUtc < DateTimeOffset.UtcNow.AddDays(-7)))
            {
                File.Delete(path);
                continue;
            }
            await uploader.UploadAsync(identity, batch, token);
            File.Delete(path);
        }
    }
}

/// Creates the reader lazily, only after a confirmed PAIRED status. No device
/// control, remote PhysIds, or server-provided commands are accepted.
public sealed class ProductionTelemetrySession : IDisposable
{
    private readonly Func<CancellationToken, Task<ProductionDiscoveryResult>> _discover;
    private readonly Func<RuntimeSensorAllowlist, ISensorReader> _createReader;
    private readonly CollectorIdentity _identity;
    private readonly CollectorBuildMetadata _metadata;
    private readonly ProductionTelemetryQueue _queue;
    private readonly IProductionTelemetryUploader _uploader;
    private readonly Func<CollectorBackendIdentity?> _backendIdentity;
    private readonly ICollectorPairingLogger _logger;
    private readonly IClock _clock;
    private readonly ICollectorSensorReadDiagnostics _diagnostics;
    private ProductionDiscoveryResult? _discovery;
    private ISensorReader? _reader;
    private ProductionCollectorRuntime? _runtime;
    private DateTimeOffset _retryAt;
    private int _failures;

    public ProductionTelemetrySession(Func<CancellationToken, Task<ProductionDiscoveryResult>> discover,
        Func<RuntimeSensorAllowlist, ISensorReader> createReader, CollectorIdentity identity,
        CollectorBuildMetadata metadata, ProductionTelemetryQueue queue, IProductionTelemetryUploader uploader,
        CollectorPairingStateStore stateStore, ICollectorPairingLogger logger, IClock? clock = null,
        ICollectorSensorReadDiagnostics? diagnostics = null)
    {
        _discover = discover; _createReader = createReader; _identity = identity; _metadata = metadata;
        _queue = queue; _uploader = uploader; _backendIdentity = stateStore.GetBackendIdentity; _logger = logger;
        _clock = clock ?? SystemClock.Instance;
        _diagnostics = diagnostics ?? NullCollectorSensorReadDiagnostics.Instance;
    }

    public async Task ReadAndUploadAsync(CancellationToken token)
    {
        if (_clock.UtcNow < _retryAt) return;
        var backendIdentity = _backendIdentity() ?? throw new InvalidOperationException("Pairing identity is unavailable.");
        try
        {
            await _queue.FlushAsync(backendIdentity, _uploader, token);
            if (!_queue.HasCapacity) throw new IOException("Sensor buffer is full.");
            if (_runtime is null)
            {
                _discovery = await _discover(token);
                if (_discovery.Sensors.Count == 0)
                {
                    _logger.Log("sensor_inventory_empty", "No supported local sensors discovered; no COM reads performed.");
                    _retryAt = _clock.UtcNow.AddMinutes(1);
                    return;
                }
                var allowlist = _discovery.CreateRuntimeAllowlist();
                _reader = _createReader(allowlist);
                _runtime = new ProductionCollectorRuntime(_reader, allowlist, _identity, _metadata,
                    new NoExtraBatchFile(), _clock, _diagnostics);
            }
            var batch = await _runtime.ReadOneCycleAsync(_discovery!, token);
            foreach (var readings in batch.Readings.Chunk(128))
            {
                var payload = readings.Select(reading =>
                {
                    float? Valid(float? value, float min, float max) => value is { } number &&
                        float.IsFinite(number) && number >= min && number <= max ? number : null;
                    var temperature = Valid(reading.TemperatureC, -50, 100);
                    var oxygen = Valid(reading.OxygenMgL, 0, 100);
                    var saturation = Valid(reading.OxygenSaturationPct, 0, 1000);
                    var count = new[] { temperature, oxygen, saturation }.Count(value => value is not null);
                    return new TelemetrySensorReading(reading.SensorId,
                        _discovery!.Sensors.First(sensor => sensor.SensorId == reading.SensorId).DisplayName,
                        reading.SourceType, temperature, oxygen, saturation, reading.ReadTimestampUtc,
                        count == 3 ? "ok" : count > 0 ? "degraded" : "failed");
                }).ToArray();
                await _queue.EnqueueAsync(new TelemetrySensorBatch(Guid.NewGuid().ToString(), _metadata.ProductVersion, payload), token);
            }
            await _queue.FlushAsync(backendIdentity, _uploader, token);
            _logger.Log("sensor_upload_ok", $"sensors={batch.Readings.Count} bufferCount={_queue.Files.Length}");
            if (batch.Readings.All(reading => reading.Health == "failed")) Backoff("sensor_read_backoff");
            else _failures = 0;
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested) { throw; }
        catch (Exception error) when (error is HttpRequestException or IOException or TaskCanceledException)
        {
            if (error is HttpRequestException httpError && httpError.StatusCode is { } status)
                _logger.Log("sensor_http_failure", $"status={(int)status}; no response body or credentials logged");
            Backoff("sensor_upload_backoff");
        }
    }

    private void Backoff(string reason)
    {
        var seconds = Math.Min(300, 15 * (1 << Math.Min(_failures++, 5)));
        _retryAt = _clock.UtcNow.AddSeconds(seconds);
        _logger.Log(reason, $"retryDelay={seconds}s bufferCount={_queue.Files.Length}; no VIGO restart or configuration change");
    }

    public void Dispose() { (_reader as IDisposable)?.Dispose(); }

    private sealed class NoExtraBatchFile : ICollectorBatchBuffer
    {
        public Task PersistAsync(CollectorBatch batch, CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
