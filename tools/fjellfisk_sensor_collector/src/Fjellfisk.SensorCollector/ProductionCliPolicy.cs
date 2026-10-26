namespace Fjellfisk.SensorCollector;

public enum ProductionCommand
{
    Help,
    Identity,
    Status,
    DiscoveryStatus,
    ReadOnce,
    Pairing,
}

public static class ProductionCliPolicy
{
    public static ProductionCommand Parse(IReadOnlyCollection<string> arguments)
    {
        if (arguments.Count == 0 || arguments.Contains("--help", StringComparer.OrdinalIgnoreCase))
        {
            return ProductionCommand.Help;
        }

        var commands = new Dictionary<string, ProductionCommand>(StringComparer.OrdinalIgnoreCase)
        {
            ["--identity"] = ProductionCommand.Identity,
            ["--status"] = ProductionCommand.Status,
            ["--discovery-status"] = ProductionCommand.DiscoveryStatus,
            ["--read-once"] = ProductionCommand.ReadOnce,
            ["--pairing"] = ProductionCommand.Pairing,
        };
        var selected = arguments.Where(argument => argument.StartsWith("--", StringComparison.Ordinal))
            .Where(argument => !argument.StartsWith("--data-dir=", StringComparison.OrdinalIgnoreCase))
            .Where(argument => !argument.StartsWith("--pairing-backend-url=", StringComparison.OrdinalIgnoreCase))
            .Where(argument => !string.Equals(argument, "--pairing-emulator", StringComparison.OrdinalIgnoreCase))
            .ToArray();
        if (selected.Length != 1 || !commands.TryGetValue(selected[0], out var command))
        {
            throw new ArgumentException("Only --identity, --status, --discovery-status, --read-once, or --pairing are available in Production Collector.");
        }

        return command;
    }
}
