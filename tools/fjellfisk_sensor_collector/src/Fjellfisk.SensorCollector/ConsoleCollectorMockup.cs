namespace Fjellfisk.SensorCollector;

public sealed class ConsoleCollectorMockup : IDisposable
{
    private readonly CollectorRunner _runner;
    private readonly bool _canRedraw;
    private bool _disposed;

    public ConsoleCollectorMockup(CollectorRunner runner)
    {
        _runner = runner;
        _canRedraw = Environment.UserInteractive && !Console.IsOutputRedirected;
        _runner.SnapshotChanged += Render;
        Render(_runner.Snapshot);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _runner.SnapshotChanged -= Render;
        _disposed = true;
    }

    private void Render(CollectorSnapshot snapshot)
    {
        if (_canRedraw)
        {
            Console.Clear();
        }

        var measurement = snapshot.LatestMeasurement;
        var status = snapshot.IsConnected
            ? "Running / Tilkoblet"
            : snapshot.Status.Running
                ? "Running / Kobler til"
                : "Stoppet";
        var lastReading = snapshot.Status.LastSuccessfulReadingUtc is { } timestamp
            ? timestamp.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss")
            : "Ingen vellykket måling ennå";

        Console.WriteLine("FJELLFISK SENSOR COLLECTOR - MOCKUP");
        Console.WriteLine($"Status: {status}");
        Console.WriteLine($"Temperatur: {(measurement is null ? "--" : $"{measurement.TemperatureC:F2} °C")}");
        Console.WriteLine($"O₂-konsentrasjon (mg/L): {(measurement is null ? "--" : $"{measurement.OxygenMgL:F2}")}");
        Console.WriteLine($"O₂-metning (%): {(measurement is null ? "--" : $"{measurement.OxygenSaturationPct:F2}")}");
        Console.WriteLine($"Siste vellykkede måling: {lastReading}");
        Console.WriteLine($"Buffer: {snapshot.Status.BufferCount}");

        if (!string.IsNullOrWhiteSpace(snapshot.Status.LastError))
        {
            Console.WriteLine("Siste feil: Registrert lokalt. Nytt forsøk følger backoff-planen.");
        }
    }
}
