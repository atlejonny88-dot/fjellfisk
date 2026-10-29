using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Windows.Forms;
using System.Runtime.InteropServices;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        var pipeName = args.FirstOrDefault(argument => argument.StartsWith("--pipe=", StringComparison.OrdinalIgnoreCase))?["--pipe=".Length..];
        if (string.IsNullOrWhiteSpace(pipeName))
        {
            return 1;
        }

        using var pipe = new NamedPipeClientStream(
            ".",
            pipeName,
            PipeDirection.InOut,
            PipeOptions.Asynchronous);
        try
        {
            // Connect before starting any asynchronous work so WinForms stays
            // on this STA thread; Clipboard requires STA.
            pipe.Connect(10_000);
        }
        catch
        {
            return 1;
        }

        using var writer = new StreamWriter(pipe, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), 1024, leaveOpen: true)
        {
            AutoFlush = true,
        };
        using var reader = new StreamReader(pipe, Encoding.UTF8, false, 1024, leaveOpen: true);

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        using var form = new PairingForm(() => writer.WriteLineAsync("{\"kind\":\"retry\"}"));
        _ = Task.Run(async () =>
        {
            try
            {
                while (true)
                {
                    var line = await reader.ReadLineAsync();
                    if (line is null)
                    {
                        return;
                    }

                    form.ApplyMessage(line);
                }
            }
            catch (IOException)
            {
                // The parent process ended or the window was closed.
            }
            catch (JsonException)
            {
                // Local IPC input is deliberately ignored when malformed.
            }
        });

        Application.Run(form);
        return 0;
    }
}

sealed class PairingForm : Form
{
    private readonly Label _code;
    private readonly Label _countdown;
    private readonly Label _instructions;
    private readonly Button _copyButton;
    private readonly Button _retryButton;
    private readonly System.Windows.Forms.Timer _timer;
    private readonly Func<Task> _retry;
    private DateTimeOffset? _expiresAtUtc;
    private string? _activeCode;

    public PairingForm(Func<Task> retry)
    {
        _retry = retry;
        Text = "Fjellfisk Collector";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = true;
        ClientSize = new Size(500, 330);
        BackColor = Color.FromArgb(247, 250, 252);
        Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);

        var header = new Panel
        {
            Dock = DockStyle.Top,
            Height = 74,
            BackColor = Color.FromArgb(11, 60, 93),
        };
        header.Controls.Add(new Label
        {
            AutoSize = true,
            Location = new Point(28, 20),
            ForeColor = Color.White,
            Font = new Font("Segoe UI Semibold", 18F, FontStyle.Bold, GraphicsUnit.Point),
            Text = "Fjellfisk Collector",
        });
        Controls.Add(header);

        Controls.Add(new Label
        {
            AutoSize = true,
            Location = new Point(30, 98),
            ForeColor = Color.FromArgb(31, 41, 51),
            Font = new Font("Segoe UI Semibold", 15F, FontStyle.Bold, GraphicsUnit.Point),
            Text = "Koble denne PC-en til Fjellfisk",
        });

        Controls.Add(new Label
        {
            AutoSize = true,
            Location = new Point(30, 135),
            ForeColor = Color.FromArgb(78, 98, 118),
            Text = "Paringskode:",
        });

        _code = new Label
        {
            AutoSize = false,
            Location = new Point(30, 158),
            Size = new Size(300, 42),
            TextAlign = ContentAlignment.MiddleLeft,
            ForeColor = Color.FromArgb(11, 60, 93),
            Font = new Font("Segoe UI Semibold", 18F, FontStyle.Bold, GraphicsUnit.Point),
            Text = "Venter på kode...",
        };
        Controls.Add(_code);

        _instructions = new Label
        {
            AutoSize = false,
            Location = new Point(30, 246),
            Size = new Size(438, 48),
            ForeColor = Color.FromArgb(54, 74, 94),
            Text = "Åpne Fjellfisk → Verktøy → Add-ons → Collector og skriv inn koden.",
        };

        _copyButton = new Button
        {
            Location = new Point(350, 160),
            Size = new Size(118, 36),
            Text = "Kopier kode",
            Enabled = false,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.White,
            ForeColor = Color.FromArgb(0, 105, 192),
        };
        _copyButton.FlatAppearance.BorderColor = Color.FromArgb(0, 105, 192);
        _copyButton.Click += (_, _) =>
        {
            if (!string.IsNullOrWhiteSpace(_activeCode))
            {
                try
                {
                    Clipboard.SetDataObject(
                        _activeCode,
                        copy: true,
                        retryTimes: 5,
                        retryDelay: 100);
                    _instructions.Text = "Koden er kopiert. Lim den inn i Fjellfisk.";
                }
                catch (Exception exception) when (
                    exception is ExternalException or ThreadStateException)
                {
                    _instructions.Text =
                        "Kunne ikke kopiere koden. Skriv den inn manuelt i Fjellfisk.";
                }
            }
        };
        Controls.Add(_copyButton);

        _countdown = new Label
        {
            AutoSize = true,
            Location = new Point(30, 212),
            ForeColor = Color.FromArgb(78, 98, 118),
            Text = "Gyldig i: --:--",
        };
        Controls.Add(_countdown);

        Controls.Add(_instructions);

        _retryButton = new Button
        {
            Location = new Point(350, 207),
            Size = new Size(118, 34),
            Text = "Prøv igjen",
            Visible = false,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(0, 105, 192),
            ForeColor = Color.White,
        };
        _retryButton.FlatAppearance.BorderSize = 0;
        _retryButton.Click += async (_, _) =>
        {
            _retryButton.Enabled = false;
            await _retry();
        };
        Controls.Add(_retryButton);

        _timer = new System.Windows.Forms.Timer { Interval = 1000 };
        _timer.Tick += (_, _) => UpdateCountdown();
        _timer.Start();
    }

    public void ApplyMessage(string line)
    {
        if (IsDisposed)
        {
            return;
        }

        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(ApplyMessage), line);
            return;
        }

        using var document = JsonDocument.Parse(line);
        var root = document.RootElement;
        var kind = root.TryGetProperty("kind", out var kindValue) ? kindValue.GetString() : null;
        if (string.Equals(kind, "close", StringComparison.Ordinal))
        {
            Close();
            return;
        }

        if (string.Equals(kind, "backend-unavailable", StringComparison.Ordinal))
        {
            _activeCode = null;
            _expiresAtUtc = null;
            _code.Text = "Venter på tilkobling...";
            _countdown.Text = "Collector prøver automatisk igjen.";
            _instructions.Text = "Fjellfisk er midlertidig utilgjengelig. Du kan prøve på nytt.";
            _copyButton.Enabled = false;
            _retryButton.Visible = true;
            _retryButton.Enabled = true;
            return;
        }

        if (!string.Equals(kind, "pairing-code", StringComparison.Ordinal) ||
            !root.TryGetProperty("code", out var codeValue) ||
            !root.TryGetProperty("expiresAtUtc", out var expiryValue) ||
            !DateTimeOffset.TryParse(expiryValue.GetString(), out var expiresAtUtc))
        {
            return;
        }

        _activeCode = codeValue.GetString();
        _expiresAtUtc = expiresAtUtc.ToUniversalTime();
        _code.Text = _activeCode ?? "Venter på kode...";
        _instructions.Text = "Åpne Fjellfisk → Verktøy → Add-ons → Collector og skriv inn koden.";
        _copyButton.Enabled = !string.IsNullOrWhiteSpace(_activeCode);
        _retryButton.Visible = false;
        UpdateCountdown();
    }

    private void UpdateCountdown()
    {
        if (_expiresAtUtc is not { } expiresAtUtc)
        {
            return;
        }

        var remaining = expiresAtUtc - DateTimeOffset.UtcNow;
        if (remaining <= TimeSpan.Zero)
        {
            _countdown.Text = "Koden er utløpt. Henter ny kode...";
            _copyButton.Enabled = false;
            return;
        }

        _countdown.Text = $"Gyldig i: {remaining.Minutes:D2}:{remaining.Seconds:D2}";
    }
}
