using System.Net;
using System.Text.Json;

namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Local monitoring metadata for one VACON connection. These fields do not
/// change a Windows network adapter or any VACON parameter.
/// </summary>
public sealed record VaconDriveConfiguration(
    string Id,
    string DisplayName,
    string Host,
    string SubnetMask,
    string Gateway,
    int Port,
    byte UnitId,
    decimal MinimumFrequencyHz,
    decimal MaximumFrequencyHz,
    bool FrequencyLimitsApproved = false,
    string Model = "VACON 100 FLOW",
    string? Dns = null)
{
    public static VaconDriveConfiguration Default { get; } = new(
        "vacon-100-flow",
        "VACON 100 FLOW",
        "192.168.30.50",
        "255.255.255.0",
        "192.168.30.1",
        502,
        255,
        0m,
        50m,
        false);

    public string DisplayLabel => $"{DisplayName} ({Host}:{Port}, Unit {UnitId})";

    public VaconControlLimits ToControlLimits(string source) => new(
        MinimumFrequencyHz,
        MaximumFrequencyHz,
        0.5m,
        FrequencyLimitsApproved,
        source);

    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(Id) || Id.Length > 64 || Id.Any(character => !char.IsLetterOrDigit(character) && character is not '-' and not '_'))
        {
            throw new ArgumentException("Drive ID must contain only letters, digits, hyphens, or underscores.", nameof(Id));
        }

        if (string.IsNullOrWhiteSpace(DisplayName) || DisplayName.Length > 80)
        {
            throw new ArgumentException("Drive name is required and must be at most 80 characters.", nameof(DisplayName));
        }

        if (string.IsNullOrWhiteSpace(Model) || Model.Length > 80)
        {
            throw new ArgumentException("Drive model is required and must be at most 80 characters.", nameof(Model));
        }

        ValidateIpv4(Host, nameof(Host));
        ValidateSubnetMask(SubnetMask);
        ValidateIpv4(Gateway, nameof(Gateway));
        if (!string.IsNullOrWhiteSpace(Dns) &&
            !IPAddress.TryParse(Dns, out _) &&
            Uri.CheckHostName(Dns) is UriHostNameType.Unknown)
        {
            throw new ArgumentException("DNS must be a valid host name or IP address when provided.", nameof(Dns));
        }

        if (Port is < 1 or > 65535)
        {
            throw new ArgumentOutOfRangeException(nameof(Port), "Modbus port must be between 1 and 65535.");
        }

        if (UnitId == 0)
        {
            throw new ArgumentOutOfRangeException(nameof(UnitId), "Modbus Unit ID 0 is not supported.");
        }

        if (MinimumFrequencyHz < 0m || MaximumFrequencyHz <= MinimumFrequencyHz || MaximumFrequencyHz > 1000m)
        {
            throw new ArgumentException("Frequency limits must be non-negative, ordered, and no higher than 1000 Hz.");
        }
    }

    public override string ToString() => DisplayLabel;

    private static void ValidateIpv4(string value, string parameterName)
    {
        if (!IPAddress.TryParse(value, out var parsed) || parsed.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            throw new ArgumentException("A valid IPv4 address is required.", parameterName);
        }
    }

    private static void ValidateSubnetMask(string value)
    {
        if (!IPAddress.TryParse(value, out var parsed) || parsed.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            throw new ArgumentException("A valid IPv4 subnet mask is required.", nameof(SubnetMask));
        }

        uint mask = 0;
        foreach (var octet in parsed.GetAddressBytes())
        {
            mask = (mask << 8) | octet;
        }

        var inverted = ~mask;
        if ((inverted & (inverted + 1)) != 0)
        {
            throw new ArgumentException("Subnet mask must contain contiguous network bits.", nameof(SubnetMask));
        }
    }
}

public sealed record VaconDriveConfigurationDocument(
    string SelectedDriveId,
    IReadOnlyList<VaconDriveConfiguration> Drives)
{
    public VaconDriveConfiguration SelectedDrive => Drives.FirstOrDefault(
        drive => string.Equals(drive.Id, SelectedDriveId, StringComparison.OrdinalIgnoreCase))
        ?? Drives.First();

    public void Validate()
    {
        if (Drives.Count == 0)
        {
            throw new ArgumentException("At least one VACON connection is required.", nameof(Drives));
        }

        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var drive in Drives)
        {
            drive.Validate();
            if (!ids.Add(drive.Id))
            {
                throw new ArgumentException("Drive IDs must be unique.", nameof(Drives));
            }
        }

        if (!ids.Contains(SelectedDriveId))
        {
            throw new ArgumentException("Selected drive must exist in the configuration.", nameof(SelectedDriveId));
        }
    }
}

public sealed class VaconDriveConfigurationStore
{
    private const string ConfigurationFileName = "drives.json";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly string _configurationPath;

    public VaconDriveConfigurationStore(string? configurationDirectory = null)
    {
        var directory = configurationDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Fjellfisk",
            "VaconMonitor");
        _configurationPath = Path.Combine(directory, ConfigurationFileName);
    }

    public string ConfigurationPath => _configurationPath;

    public VaconDriveConfigurationDocument Load()
    {
        if (!File.Exists(_configurationPath))
        {
            return CreateDefault();
        }

        try
        {
            var document = JsonSerializer.Deserialize<VaconDriveConfigurationDocument>(File.ReadAllText(_configurationPath), JsonOptions)
                ?? throw new InvalidOperationException("VACON connection configuration was empty.");
            document.Validate();
            return document;
        }
        catch (Exception exception) when (exception is JsonException or ArgumentException or ArgumentOutOfRangeException)
        {
            throw new InvalidOperationException("VACON connection configuration is invalid. It was not overwritten.", exception);
        }
    }

    public void Save(VaconDriveConfigurationDocument document)
    {
        document.Validate();
        var directory = Path.GetDirectoryName(_configurationPath)!;
        Directory.CreateDirectory(directory);
        var temporaryPath = $"{_configurationPath}.{Guid.NewGuid():N}.tmp";

        try
        {
            File.WriteAllText(temporaryPath, JsonSerializer.Serialize(document, JsonOptions));
            File.Move(temporaryPath, _configurationPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    public static VaconDriveConfigurationDocument CreateDefault() => new(
        VaconDriveConfiguration.Default.Id,
        new[] { VaconDriveConfiguration.Default });
}
