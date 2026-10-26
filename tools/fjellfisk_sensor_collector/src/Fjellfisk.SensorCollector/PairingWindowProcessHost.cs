using System.Diagnostics;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;

namespace Fjellfisk.SensorCollector;

/// <summary>
/// Starts the customer-facing pairing window out of process. The child receives
/// a named-pipe name only; credentials, Vigo data, and backend configuration
/// never cross this boundary.
/// </summary>
public sealed class PairingWindowProcessHost : ICollectorPairingUi, IDisposable
{
    private readonly string _pairingUiExecutablePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Process? _process;
    private NamedPipeServerStream? _pipe;
    private StreamWriter? _writer;
    private bool _disposed;

    public PairingWindowProcessHost(string applicationDirectory)
    {
        _pairingUiExecutablePath = Path.Combine(
            applicationDirectory,
            "pairing-ui",
            "Fjellfisk.Collector.PairingUi.exe");
    }

    public event EventHandler? RetryRequested;

    public async Task ShowPairingCodeAsync(PairingCodePresentation pairingCode, CancellationToken cancellationToken)
    {
        await SendAsync("pairing-code", pairingCode.Code, pairingCode.ExpiresAtUtc, cancellationToken);
    }

    public Task ShowBackendUnavailableAsync(CancellationToken cancellationToken) =>
        SendAsync("backend-unavailable", null, null, cancellationToken);

    public async Task CloseAsync(CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_writer is not null)
            {
                await _writer.WriteLineAsync("{\"kind\":\"close\"}");
                await _writer.FlushAsync();
            }
        }
        catch (IOException)
        {
            // A manually closed window is an expected state.
        }
        finally
        {
            ReleaseExitedWindow();
            _gate.Release();
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        try
        {
            CloseAsync(CancellationToken.None).GetAwaiter().GetResult();
        }
        catch
        {
            // The parent collector must be able to exit even when a user has
            // already dismissed the non-critical pairing window.
        }

        _gate.Dispose();
    }

    private async Task SendAsync(
        string kind,
        string? code,
        DateTimeOffset? expiresAtUtc,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            ThrowIfDisposed();
            await EnsureWindowAsync(cancellationToken);
            var message = JsonSerializer.Serialize(new
            {
                kind,
                code,
                expiresAtUtc = expiresAtUtc?.ToUniversalTime().ToString("O"),
            });
            await _writer!.WriteLineAsync(message);
            await _writer.FlushAsync();
        }
        catch (IOException)
        {
            ReleaseExitedWindow();
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task EnsureWindowAsync(CancellationToken cancellationToken)
    {
        if (_process is { HasExited: false } && _writer is not null)
        {
            return;
        }

        ReleaseExitedWindow();
        if (!File.Exists(_pairingUiExecutablePath))
        {
            throw new FileNotFoundException("Pairing UI was not found in the Collector installation.", _pairingUiExecutablePath);
        }

        var pipeName = $"FjellfiskCollectorPairing-{Guid.NewGuid():N}";
        _pipe = new NamedPipeServerStream(
            pipeName,
            PipeDirection.InOut,
            1,
            PipeTransmissionMode.Byte,
            PipeOptions.Asynchronous);
        var startInfo = new ProcessStartInfo(_pairingUiExecutablePath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Normal,
        };
        startInfo.ArgumentList.Add($"--pipe={pipeName}");
        _process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Pairing UI could not be started.");

        using var connectTimeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        connectTimeout.CancelAfter(TimeSpan.FromSeconds(10));
        await _pipe.WaitForConnectionAsync(connectTimeout.Token);
        _writer = new StreamWriter(_pipe, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), 1024, leaveOpen: true)
        {
            AutoFlush = true,
        };
        _ = ListenForUiEventsAsync(_pipe);
    }

    private async Task ListenForUiEventsAsync(Stream stream)
    {
        try
        {
            using var reader = new StreamReader(stream, Encoding.UTF8, false, 1024, leaveOpen: true);
            while (true)
            {
                var line = await reader.ReadLineAsync();
                if (line is null)
                {
                    return;
                }

                using var document = JsonDocument.Parse(line);
                if (document.RootElement.TryGetProperty("kind", out var kind) &&
                    string.Equals(kind.GetString(), "retry", StringComparison.Ordinal))
                {
                    RetryRequested?.Invoke(this, EventArgs.Empty);
                }
            }
        }
        catch (IOException)
        {
            // Closing the UI is normal and pairing continues in the parent.
        }
        catch (JsonException)
        {
            // Ignore malformed local UI input rather than affecting collector state.
        }
    }

    private void ReleaseExitedWindow()
    {
        if (_process is { HasExited: false })
        {
            return;
        }

        _writer?.Dispose();
        _writer = null;
        _pipe?.Dispose();
        _pipe = null;
        _process?.Dispose();
        _process = null;
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
        {
            throw new ObjectDisposedException(nameof(PairingWindowProcessHost));
        }
    }
}
