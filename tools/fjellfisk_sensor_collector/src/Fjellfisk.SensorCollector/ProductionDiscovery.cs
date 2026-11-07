using System.Collections.ObjectModel;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Fjellfisk.SensorCollector;

public sealed record VigoDiscoveryOptions(
    IReadOnlyList<string> CandidateRoots,
    int MaximumFilesPerRoot,
    long MaximumFileBytes)
{
    public static VigoDiscoveryOptions Default { get; } = new(
        VigoInstallationLocator.GetDefaultRoots(),
        MaximumFilesPerRoot: 10_000,
        MaximumFileBytes: 8 * 1024 * 1024);
}

public static class VigoInstallationLocator
{
    public static IReadOnlyList<string> GetDefaultRoots()
    {
        var commonApplicationData = Environment.GetFolderPath(
            Environment.SpecialFolder.CommonApplicationData);
        var publicUserRoot = Path.GetDirectoryName(Environment.GetFolderPath(
            Environment.SpecialFolder.CommonDocuments));
        var roots = new[]
        {
            publicUserRoot is null ? null : Path.Combine(publicUserRoot, "VIGO", "DynamicData", "Commander5"),
            publicUserRoot is null ? null : Path.Combine(publicUserRoot, "VIGO", "DynamicData", "visualvigo"),
            publicUserRoot is null ? null : Path.Combine(publicUserRoot, "VIGO", "StaticData"),
            Path.Combine(commonApplicationData, "VIGO", "DynamicData", "Commander5"),
            Path.Combine(commonApplicationData, "VIGO", "DynamicData", "visualvigo"),
            Path.Combine(commonApplicationData, "VIGO", "StaticData"),
        };

        return roots
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(path => Path.GetFullPath(path!))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }
}

public interface IVigoConfigurationDiscoverySource
{
    string Name { get; }

    Task<IReadOnlyCollection<string>> ReadObjectReferencesAsync(
        CancellationToken cancellationToken);
}

/// <summary>
/// Reads only local Vigo project/runtime files. It extracts supported object
/// names from bytes and never sends a discovered string directly to COM.
/// </summary>
public sealed class LocalVigoConfigurationDiscoverySource : IVigoConfigurationDiscoverySource
{
    private readonly VigoDiscoveryOptions _options;

    public LocalVigoConfigurationDiscoverySource(VigoDiscoveryOptions? options = null)
    {
        _options = options ?? VigoDiscoveryOptions.Default;
    }

    public string Name => "local-vigo-config";

    public async Task<IReadOnlyCollection<string>> ReadObjectReferencesAsync(
        CancellationToken cancellationToken)
    {
        var references = new HashSet<string>(StringComparer.Ordinal);
        foreach (var root in _options.CandidateRoots)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!Directory.Exists(root))
            {
                continue;
            }

            var scannedFiles = 0;
            foreach (var file in EnumerateFiles(root))
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (++scannedFiles > _options.MaximumFilesPerRoot)
                {
                    break;
                }

                var info = new FileInfo(file);
                if (info.Length <= 0 || info.Length > _options.MaximumFileBytes)
                {
                    continue;
                }

                try
                {
                    var bytes = await File.ReadAllBytesAsync(file, cancellationToken);
                    foreach (var reference in VigoObjectReferenceParser.ExtractReferences(
                                 Encoding.Latin1.GetString(bytes)))
                    {
                        references.Add(reference);
                    }
                }
                catch (IOException)
                {
                    // A runtime file can rotate while being observed. It is
                    // skipped until the next controlled discovery operation.
                }
                catch (UnauthorizedAccessException)
                {
                    // Discovery must not require broader rights than the
                    // foreground collector has received.
                }
            }
        }

        return references.OrderBy(value => value, StringComparer.Ordinal).ToArray();
    }

    private static IEnumerable<string> EnumerateFiles(string root)
    {
        try
        {
            return Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories);
        }
        catch (IOException)
        {
            return Array.Empty<string>();
        }
        catch (UnauthorizedAccessException)
        {
            return Array.Empty<string>();
        }
    }
}

public enum VigoSensorFamily
{
    Pacific,
    Dom,
}

public sealed record VigoDiscoveredObject(
    VigoSensorFamily Family,
    string VigoRoot,
    int DeviceIndex,
    int ChannelIndex,
    string DeviceToken,
    string ChannelToken)
{
    public string StablePath => Family switch
    {
        VigoSensorFamily.Pacific =>
            $"{VigoRoot}.Pacific.Pacific_{DeviceToken}.Probe_{ChannelToken}",
        VigoSensorFamily.Dom =>
            $"{VigoRoot}.DOM.DO_Meter_{DeviceToken}.DO_{ChannelToken}",
        _ => throw new ArgumentOutOfRangeException(nameof(Family)),
    };
}

public static class VigoObjectReferenceParser
{
    private static readonly Regex PacificPattern = new(
        @"(?<root>Commander5:[A-Za-z0-9_-]+)\.Pacific\.Pacific_(?<device>\d+)\.Probe_(?<channel>\d+)",
        RegexOptions.CultureInvariant);

    private static readonly Regex DomPattern = new(
        @"(?<root>Commander5:[A-Za-z0-9_-]+)\.DOM\.DO_Meter_(?<device>\d+)\.DO_(?<channel>\d+)",
        RegexOptions.CultureInvariant);

    public static IReadOnlyCollection<string> ExtractReferences(string content)
    {
        ArgumentNullException.ThrowIfNull(content);
        return PacificPattern.Matches(content)
            .Cast<Match>()
            .Concat(DomPattern.Matches(content).Cast<Match>())
            .Select(match => match.Value)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    public static IReadOnlyList<VigoDiscoveredObject> Parse(
        IEnumerable<string> references)
    {
        ArgumentNullException.ThrowIfNull(references);
        var objects = new Dictionary<string, VigoDiscoveredObject>(StringComparer.Ordinal);
        foreach (var reference in references)
        {
            AddMatches(objects, PacificPattern, reference, VigoSensorFamily.Pacific);
            AddMatches(objects, DomPattern, reference, VigoSensorFamily.Dom);
        }

        return objects.Values
            .OrderBy(value => value.Family)
            .ThenBy(value => value.VigoRoot, StringComparer.Ordinal)
            .ThenBy(value => value.DeviceIndex)
            .ThenBy(value => value.ChannelIndex)
            .ToArray();
    }

    private static void AddMatches(
        IDictionary<string, VigoDiscoveredObject> objects,
        Regex pattern,
        string? reference,
        VigoSensorFamily family)
    {
        if (string.IsNullOrWhiteSpace(reference))
        {
            return;
        }

        foreach (Match match in pattern.Matches(reference))
        {
            if (!int.TryParse(match.Groups["device"].Value, out var deviceIndex) ||
                !int.TryParse(match.Groups["channel"].Value, out var channelIndex) ||
                deviceIndex < 0 || channelIndex < 0)
            {
                continue;
            }

            var discovered = new VigoDiscoveredObject(
                family,
                match.Groups["root"].Value,
                deviceIndex,
                channelIndex,
                match.Groups["device"].Value,
                match.Groups["channel"].Value);
            objects[discovered.StablePath] = discovered;
        }
    }
}

public sealed record CollectorSensorDescriptor(
    string SensorId,
    string DisplayName,
    string SourceType,
    string SourceDevice,
    string SourceChannel,
    IReadOnlyDictionary<string, string> SourceMetadata,
    IReadOnlyList<SensorDefinition> Measurements);

public interface IDiscoveredSensorSource
{
    VigoSensorFamily Family { get; }

    IReadOnlyList<CollectorSensorDescriptor> BuildSensors(
        IEnumerable<VigoDiscoveredObject> objects);
}

public sealed class PacificDiscoverySource : IDiscoveredSensorSource
{
    public VigoSensorFamily Family => VigoSensorFamily.Pacific;

    public IReadOnlyList<CollectorSensorDescriptor> BuildSensors(
        IEnumerable<VigoDiscoveredObject> objects) => objects
        .Where(item => item.Family == Family)
        .Select(CreateSensor)
        .OrderBy(sensor => sensor.SensorId, StringComparer.Ordinal)
        .ToArray();

    private static CollectorSensorDescriptor CreateSensor(VigoDiscoveredObject item)
    {
        var sensorId = $"pacific_{NormalizeRoot(item.VigoRoot)}_{item.DeviceIndex:D2}_probe_{item.ChannelIndex:D2}";
        var sourceDevice = $"Pacific_{item.DeviceToken}";
        var sourceChannel = $"Probe_{item.ChannelToken}";
        var physIdPrefix =
            $"{item.VigoRoot}.Pacific.{sourceDevice}.{sourceChannel}.Oxygen.Measurement.";

        return CreateDescriptor(
            sensorId,
            $"Pacific {item.DeviceToken} / Probe {item.ChannelToken}",
            "Pacific",
            sourceDevice,
            sourceChannel,
            item.VigoRoot,
            new[]
            {
                new SensorDefinition($"{sensorId}:temperature", sourceDevice, physIdPrefix + "Temperature.Value", SensorKind.TemperatureC),
                new SensorDefinition($"{sensorId}:oxygen", sourceDevice, physIdPrefix + "Ppm.Value", SensorKind.OxygenMgL),
                new SensorDefinition($"{sensorId}:saturation", sourceDevice, physIdPrefix + "Saturation.Value", SensorKind.OxygenSaturationPct),
            });
    }

    internal static string NormalizeRoot(string value) => value
        .ToLowerInvariant()
        .Replace(':', '_')
        .Replace('-', '_');

    internal static CollectorSensorDescriptor CreateDescriptor(
        string sensorId,
        string displayName,
        string sourceType,
        string sourceDevice,
        string sourceChannel,
        string vigoRoot,
        IReadOnlyList<SensorDefinition> measurements) =>
        new(
            sensorId,
            displayName,
            sourceType,
            sourceDevice,
            sourceChannel,
            new ReadOnlyDictionary<string, string>(new Dictionary<string, string>
            {
                ["vigoRoot"] = vigoRoot,
            }),
            measurements);
}

public sealed class DomDiscoverySource : IDiscoveredSensorSource
{
    public VigoSensorFamily Family => VigoSensorFamily.Dom;

    public IReadOnlyList<CollectorSensorDescriptor> BuildSensors(
        IEnumerable<VigoDiscoveredObject> objects) => objects
        .Where(item => item.Family == Family)
        .Select(CreateSensor)
        .OrderBy(sensor => sensor.SensorId, StringComparer.Ordinal)
        .ToArray();

    private static CollectorSensorDescriptor CreateSensor(VigoDiscoveredObject item)
    {
        var sensorId = $"dom_{PacificDiscoverySource.NormalizeRoot(item.VigoRoot)}_meter_{item.DeviceIndex}_do_{item.ChannelIndex}";
        var sourceDevice = $"DO_Meter_{item.DeviceToken}";
        var sourceChannel = $"DO_{item.ChannelToken}";
        var physIdPrefix =
            $"{item.VigoRoot}.DOM.{sourceDevice}.{sourceChannel}.Measurement.";

        return PacificDiscoverySource.CreateDescriptor(
            sensorId,
            $"DOM Meter {item.DeviceToken} / DO {item.ChannelToken}",
            "DOM",
            sourceDevice,
            sourceChannel,
            item.VigoRoot,
            new[]
            {
                new SensorDefinition($"{sensorId}:temperature", sourceDevice, physIdPrefix + "temperature", SensorKind.TemperatureC),
                new SensorDefinition($"{sensorId}:oxygen", sourceDevice, physIdPrefix + "ppm", SensorKind.OxygenMgL),
                new SensorDefinition($"{sensorId}:saturation", sourceDevice, physIdPrefix + "saturation", SensorKind.OxygenSaturationPct),
            });
    }
}

public sealed record DiscoveryIssue(string SourceName, string Message);

public sealed record SourceCapability(string Type, int Devices, int Sensors);

public sealed record ProductionDiscoveryResult(
    DateTimeOffset DiscoveredAtUtc,
    IReadOnlyList<CollectorSensorDescriptor> Sensors,
    IReadOnlyList<SourceCapability> Sources,
    IReadOnlyList<DiscoveryIssue> Issues)
{
    public RuntimeSensorAllowlist CreateRuntimeAllowlist() => new(Sensors);
}

public sealed class ProductionDiscoveryService
{
    private readonly IReadOnlyList<IVigoConfigurationDiscoverySource> _configurationSources;
    private readonly IReadOnlyList<IDiscoveredSensorSource> _sensorSources;
    private readonly IClock _clock;

    public ProductionDiscoveryService(
        IEnumerable<IVigoConfigurationDiscoverySource> configurationSources,
        IEnumerable<IDiscoveredSensorSource>? sensorSources = null,
        IClock? clock = null)
    {
        _configurationSources = configurationSources?.ToArray()
            ?? throw new ArgumentNullException(nameof(configurationSources));
        _sensorSources = sensorSources?.ToArray() ?? new IDiscoveredSensorSource[]
        {
            new PacificDiscoverySource(),
            new DomDiscoverySource(),
        };
        _clock = clock ?? SystemClock.Instance;
    }

    public async Task<ProductionDiscoveryResult> DiscoverAsync(CancellationToken cancellationToken)
    {
        var references = new HashSet<string>(StringComparer.Ordinal);
        var issues = new List<DiscoveryIssue>();
        foreach (var source in _configurationSources)
        {
            try
            {
                foreach (var reference in await source.ReadObjectReferencesAsync(cancellationToken))
                {
                    references.Add(reference);
                }
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                issues.Add(new DiscoveryIssue(source.Name, SanitizeMessage(exception.Message)));
            }
        }

        var objects = VigoObjectReferenceParser.Parse(references);
        var sensors = _sensorSources
            .SelectMany(source => source.BuildSensors(objects))
            .GroupBy(sensor => sensor.SensorId, StringComparer.Ordinal)
            .Select(group => group.First())
            .OrderBy(sensor => sensor.SensorId, StringComparer.Ordinal)
            .ToArray();
        var sourceCapabilities = CreateCapabilities(sensors);

        return new ProductionDiscoveryResult(_clock.UtcNow, sensors, sourceCapabilities, issues);
    }

    private static IReadOnlyList<SourceCapability> CreateCapabilities(
        IReadOnlyCollection<CollectorSensorDescriptor> sensors) => sensors
        .GroupBy(sensor => sensor.SourceType, StringComparer.Ordinal)
        .OrderBy(group => group.Key, StringComparer.Ordinal)
        .Select(group => new SourceCapability(
            group.Key,
            group.Select(sensor =>
                $"{sensor.SourceMetadata["vigoRoot"]}|{sensor.SourceDevice}").Distinct(StringComparer.Ordinal).Count(),
            group.Count()))
        .ToArray();

    private static string SanitizeMessage(string message)
    {
        var sanitized = message.Replace('\r', ' ').Replace('\n', ' ').Trim();
        return sanitized.Length <= 300 ? sanitized : sanitized[..300];
    }
}

public sealed class RuntimeSensorAllowlist : IReadOnlySensorAllowlist
{
    private readonly IReadOnlyDictionary<string, SensorDefinition> _sensors;

    internal RuntimeSensorAllowlist(IEnumerable<CollectorSensorDescriptor> discoveredSensors)
    {
        ArgumentNullException.ThrowIfNull(discoveredSensors);
        var sensors = new Dictionary<string, SensorDefinition>(StringComparer.Ordinal);
        foreach (var sensor in discoveredSensors)
        {
            foreach (var measurement in sensor.Measurements)
            {
                if (!sensors.TryAdd(measurement.Key, measurement))
                {
                    throw new InvalidOperationException("Discovery produced duplicate runtime sensor keys.");
                }
            }
        }

        _sensors = new ReadOnlyDictionary<string, SensorDefinition>(sensors);
    }

    public IReadOnlyCollection<SensorDefinition> Sensors => _sensors.Values.ToArray();

    public SensorDefinition GetRequired(string sensorKey) => _sensors.TryGetValue(sensorKey, out var sensor)
        ? sensor
        : throw new InvalidOperationException("The requested sensor is not in the runtime read-only allowlist.");
}

public sealed class ProductionStorageLayout
{
    private ProductionStorageLayout(string rootDirectory)
    {
        RootDirectory = rootDirectory;
        ConfigDirectory = Path.Combine(rootDirectory, "config");
        IdentityDirectory = Path.Combine(rootDirectory, "identity");
        LogsDirectory = Path.Combine(rootDirectory, "logs");
        BufferDirectory = Path.Combine(rootDirectory, "buffer");
    }

    public string RootDirectory { get; }

    public string ConfigDirectory { get; }

    public string IdentityDirectory { get; }

    public string LogsDirectory { get; }

    public string BufferDirectory { get; }

    public string DiscoveryCachePath => Path.Combine(ConfigDirectory, "discovery-cache.json");

    public static ProductionStorageLayout Open(string? rootDirectory = null)
    {
        var root = rootDirectory ?? CollectorIdentityStore.DefaultDataDirectory;
        var layout = new ProductionStorageLayout(root);
        Directory.CreateDirectory(layout.ConfigDirectory);
        Directory.CreateDirectory(layout.IdentityDirectory);
        Directory.CreateDirectory(layout.LogsDirectory);
        Directory.CreateDirectory(layout.BufferDirectory);
        layout.MigrateLegacyIdentity();
        return layout;
    }

    private void MigrateLegacyIdentity()
    {
        var legacyPath = Path.Combine(RootDirectory, "identity.json");
        var canonicalPath = Path.Combine(IdentityDirectory, "identity.json");
        if (File.Exists(legacyPath) && !File.Exists(canonicalPath))
        {
            File.Move(legacyPath, canonicalPath);
        }
    }
}

public static class ProductionDiscoveryCache
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static Task PersistAsync(
        string path,
        ProductionDiscoveryResult result,
        CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("Discovery cache path has no directory.");
        Directory.CreateDirectory(directory);
        return File.WriteAllTextAsync(path, JsonSerializer.Serialize(result, JsonOptions), cancellationToken);
    }
}
