using System.Drawing;

namespace Fjellfisk.VaconMonitor;

public sealed class VaconControlForm : Form
{
    private readonly VaconMonitorController _controller;
    private readonly VaconMonitorOptions _options;
    private readonly VaconDriveConfigurationStore _configurationStore;
    private VaconDriveConfigurationDocument _configuration;
    private readonly CancellationTokenSource _shutdown = new();
    private readonly Label _connectionValue = CreateStatusValue();
    private readonly Label _communicationValue = CreateStatusValue();
    private readonly Label _motorValue = CreateStatusValue();
    private readonly Label _readyValue = CreateStatusValue();
    private readonly Label _faultValue = CreateStatusValue();
    private readonly Label _statusWordValue = CreateStatusValue();
    private readonly Label _frequencyValue = new();
    private readonly Label _targetValue = CreateMetricValue();
    private readonly Label _rpmValue = CreateMetricValue();
    private readonly Label _currentValue = CreateMetricValue();
    private readonly Label _lastReadValue = CreateStatusValue();
    private readonly Label _controlNote = new();
    private readonly Label _commandResult = new();
    private readonly Button _minusButton = new();
    private readonly Button _plusButton = new();
    private readonly Button _applyButton = new();
    private readonly Button _startButton = new();
    private readonly Button _stopButton = new();
    private readonly Button _connectButton = new();
    private readonly Button _disconnectButton = new();
    private readonly Label _activeDriveValue = CreateStatusValue();
    private readonly Button _setupButton = new();
    private readonly Button _detailsButton = new();
    private readonly VaconPendingFrequencyTarget _pendingTarget;
    private Panel? _detailsPanel;
    private CancellationTokenSource? _connectionShutdown;
    private Task? _runTask;
    private bool _targetInitializedFromLiveReading;

    public VaconControlForm(
        VaconMonitorController controller,
        VaconMonitorOptions options,
        VaconDriveConfigurationStore configurationStore,
        VaconDriveConfigurationDocument configuration)
    {
        _controller = controller;
        _options = options;
        _configurationStore = configurationStore;
        _configuration = configuration;
        _pendingTarget = new VaconPendingFrequencyTarget(
            _options.Drive.MinimumFrequencyHz,
            _options.Drive.MaximumFrequencyHz,
            _options.Drive.FrequencyLimitsApproved);
        _controller.Updated += Render;

        Text = "Fjellfisk VACON Control v0.5.0";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(VaconUiLayout.MinimumWindowWidth, VaconUiLayout.MinimumWindowHeight);
        Size = new Size(VaconUiLayout.DefaultWindowWidth, VaconUiLayout.DefaultWindowHeight);
        AutoScaleMode = AutoScaleMode.Dpi;
        BackColor = Color.FromArgb(242, 246, 250);
        Font = new Font("Segoe UI", 10F);

        var page = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(16),
            ColumnCount = 1,
            RowCount = 8,
            AutoScroll = true,
        };
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        page.Controls.Add(CreateHeading(), 0, 0);
        page.Controls.Add(CreateModeNote(), 0, 1);
        page.Controls.Add(CreateDrivePanel(), 0, 2);
        page.Controls.Add(CreateStatusPanel(), 0, 3);
        page.Controls.Add(CreateMetricsPanel(), 0, 4);
        page.Controls.Add(CreateControlPanel(), 0, 5);

        _lastReadValue.Margin = new Padding(0, 18, 0, 0);
        page.Controls.Add(CreateLastReadPanel(), 0, 6);
        page.Controls.Add(CreateDetailsPanel(), 0, 7);
        Controls.Add(page);
        Shown += OnShown;
        FormClosing += OnClosing;
        Render(_controller.Current);
    }

    private Control CreateHeading()
    {
        var panel = new Panel { AutoSize = true, Dock = DockStyle.Top, Margin = new Padding(0, 0, 0, 4) };
        panel.Controls.Add(new Label
        {
            AutoSize = true,
            Text = "VACON CONTROL",
            Font = new Font("Segoe UI Semibold", 18F),
            ForeColor = Color.FromArgb(5, 55, 91),
        });
        return panel;
    }

    private Control CreateModeNote()
    {
        return new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 8),
            ForeColor = Color.FromArgb(104, 48, 40),
            Text = "LIVE READ-ONLY: FC04-overvaking. Fysisk styring er sperret til idriftsettelsen er dokumentert.",
        };
    }

    private Control CreateStatusPanel()
    {
        var panel = CreatePanel();
        var content = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, AutoSize = true };
        content.Controls.Add(CreateSectionHeading("SYSTEM STATUS"), 0, 0);
        var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 2, AutoSize = true };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
        grid.Controls.Add(CreateStatusBlock("Tilkobling", _connectionValue), 0, 0);
        grid.Controls.Add(CreateStatusBlock("Motor", _motorValue), 1, 0);
        grid.Controls.Add(CreateStatusBlock("Klar", _readyValue), 2, 0);
        grid.Controls.Add(CreateStatusBlock("Aktiv feil", _faultValue), 0, 1);
        grid.Controls.Add(CreateStatusBlock("Siste maling", _lastReadValue), 1, 1);
        grid.Controls.Add(CreateStatusBlock("Kommunikasjon", _communicationValue), 2, 1);
        content.Controls.Add(grid, 0, 1);
        panel.Controls.Add(content);
        return panel;
    }

    private Control CreateDrivePanel()
    {
        var panel = CreatePanel();
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, AutoSize = true };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.Controls.Add(CreateSectionHeading("ACTIVE VACON CONNECTION"), 0, 0);
        _activeDriveValue.Text = _options.Drive.DisplayLabel;
        _activeDriveValue.Margin = new Padding(0, 0, 0, 4);
        layout.Controls.Add(_activeDriveValue, 0, 1);
        var actions = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
        _setupButton.Text = "Oppsett";
        _setupButton.AutoSize = true;
        _setupButton.Margin = new Padding(8, 3, 0, 3);
        _setupButton.Click += OpenConnectionSetup;
        _connectButton.Text = "Koble til";
        _connectButton.AutoSize = true;
        _connectButton.Margin = new Padding(8, 3, 0, 3);
        _connectButton.Click += ConnectClicked;
        _disconnectButton.Text = "Koble fra";
        _disconnectButton.AutoSize = true;
        _disconnectButton.Margin = new Padding(8, 3, 0, 3);
        _disconnectButton.Click += DisconnectClicked;
        actions.Controls.Add(_setupButton);
        actions.Controls.Add(_disconnectButton);
        actions.Controls.Add(_connectButton);
        layout.Controls.Add(actions, 1, 1);
        panel.Controls.Add(layout);
        return panel;
    }

    private Control CreateMetricsPanel()
    {
        var panel = CreatePanel();
        var content = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, AutoSize = true };
        content.Controls.Add(CreateSectionHeading("AKTUELL FREKVENS"), 0, 0);

        _frequencyValue.AutoSize = true;
        _frequencyValue.Text = "-- Hz";
        _frequencyValue.Font = new Font("Segoe UI Semibold", 34F);
        _frequencyValue.ForeColor = Color.FromArgb(4, 79, 122);
        _frequencyValue.Margin = new Padding(0, 0, 0, 2);
        content.Controls.Add(_frequencyValue, 0, 1);
        panel.Controls.Add(content);
        return panel;
    }

    private Control CreateControlPanel()
    {
        var panel = CreatePanel();
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 7, AutoSize = true };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));

        layout.Controls.Add(new Label
        {
            Text = "FREKVENSKONTROLL",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 12F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 0, 0, 12),
        }, 0, 0);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 0)!, 3);

        _minusButton.Text = "- 1 Hz";
        _minusButton.Dock = DockStyle.Fill;
        _minusButton.Click += (_, _) => ChangeTarget(-1);
        _plusButton.Text = "+ 1 Hz";
        _plusButton.Dock = DockStyle.Fill;
        _plusButton.Click += (_, _) => ChangeTarget(1);
        _applyButton.Text = "BRUK FREKVENS";
        _applyButton.Dock = DockStyle.Fill;
        _applyButton.BackColor = Color.FromArgb(0, 100, 190);
        _applyButton.ForeColor = Color.White;
        _applyButton.FlatStyle = FlatStyle.Flat;
        _applyButton.Click += (_, _) => ShowCommissioningRequired();

        var targetHeading = new Label
        {
            Text = "MALFREKVENS",
            AutoSize = true,
            Anchor = AnchorStyles.None,
            ForeColor = Color.FromArgb(78, 92, 110),
            Margin = new Padding(0, 4, 0, 0),
        };
        layout.Controls.Add(targetHeading, 0, 1);
        layout.SetColumnSpan(targetHeading, 3);

        layout.Controls.Add(_minusButton, 0, 2);
        layout.Controls.Add(_targetValue, 1, 2);
        layout.Controls.Add(_plusButton, 2, 2);
        layout.Controls.Add(_applyButton, 0, 3);
        layout.SetColumnSpan(_applyButton, 3);

        layout.Controls.Add(new Label
        {
            Text = "MOTORKONTROLL",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 12F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 16, 0, 8),
        }, 0, 4);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 4)!, 3);

        _startButton.Text = "START MOTOR";
        _startButton.BackColor = Color.FromArgb(0, 123, 76);
        _startButton.ForeColor = Color.White;
        _startButton.FlatStyle = FlatStyle.Flat;
        _startButton.AutoSize = true;
        _startButton.Click += (_, _) => ShowCommissioningRequired();
        _stopButton.Text = "STOP MOTOR";
        _stopButton.BackColor = Color.FromArgb(176, 38, 45);
        _stopButton.ForeColor = Color.White;
        _stopButton.FlatStyle = FlatStyle.Flat;
        _stopButton.AutoSize = true;
        _stopButton.Margin = new Padding(12, 8, 0, 8);
        _stopButton.Click += (_, _) => ShowCommissioningRequired();
        layout.Controls.Add(_startButton, 0, 5);
        layout.Controls.Add(_stopButton, 1, 5);
        layout.SetColumnSpan(_stopButton, 2);

        _controlNote.AutoSize = true;
        _controlNote.ForeColor = Color.FromArgb(110, 85, 20);
        _controlNote.Margin = new Padding(0, 8, 0, 0);
        layout.Controls.Add(_controlNote, 0, 6);
        layout.SetColumnSpan(_controlNote, 3);
        panel.Controls.Add(layout);
        return panel;
    }

    private Control CreateLastReadPanel()
    {
        var panel = new Panel { AutoSize = true, Dock = DockStyle.Top };
        panel.Controls.Add(new Label
        {
            Text = "Siste vellykkede måling",
            AutoSize = true,
            ForeColor = Color.FromArgb(78, 92, 110),
            Location = new Point(0, 0),
        });
        _detailsButton.Text = "Vis detaljer";
        _detailsButton.AutoSize = true;
        _detailsButton.Location = new Point(210, 0);
        _detailsButton.Click += (_, _) => ToggleDetails();
        panel.Controls.Add(_detailsButton);
        return panel;
    }

    private Control CreateDetailsPanel()
    {
        _detailsPanel = CreatePanel();
        _detailsPanel.Visible = false;
        var content = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, AutoSize = true };
        content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        content.Controls.Add(CreateSectionHeading("AVANSERT OVERVAKING"), 0, 0);
        content.SetColumnSpan(content.GetControlFromPosition(0, 0)!, 2);
        content.Controls.Add(CreateStatusBlock("Motorhastighet (radata)", _rpmValue), 0, 1);
        content.Controls.Add(CreateStatusBlock("Motorstrom (radata)", _currentValue), 1, 1);
        content.Controls.Add(CreateStatusBlock("Statusord", _statusWordValue), 0, 2);
        _commandResult.AutoSize = true;
        _commandResult.ForeColor = Color.FromArgb(78, 92, 110);
        _commandResult.Margin = new Padding(0, 4, 0, 0);
        content.Controls.Add(CreateStatusBlock("Siste kommando", _commandResult), 1, 2);
        _detailsPanel.Controls.Add(content);
        return _detailsPanel;
    }

    private static Panel CreatePanel() => new()
    {
        AutoSize = true,
        Dock = DockStyle.Top,
        BackColor = Color.White,
        BorderStyle = BorderStyle.FixedSingle,
        Padding = new Padding(14),
        Margin = new Padding(0, 0, 0, 8),
    };

    private static Label CreateSectionHeading(string text) => new()
    {
        Text = text,
        AutoSize = true,
        Font = new Font("Segoe UI Semibold", 12F),
        ForeColor = Color.FromArgb(5, 55, 91),
        Margin = new Padding(0, 0, 0, 12),
    };

    private static Control CreateStatusBlock(string caption, Label value)
    {
        var block = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, RowCount = 2 };
        block.Controls.Add(new Label { Text = caption, AutoSize = true, ForeColor = Color.FromArgb(78, 92, 110) }, 0, 0);
        block.Controls.Add(value, 0, 1);
        return block;
    }

    private static Control CreateMetricBlock(string caption, Label value)
    {
        var block = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, RowCount = 2 };
        block.Controls.Add(new Label { Text = caption, AutoSize = true, ForeColor = Color.FromArgb(78, 92, 110) }, 0, 0);
        block.Controls.Add(value, 0, 1);
        return block;
    }

    private static Label CreateStatusValue() => new()
    {
        AutoSize = true,
        Font = new Font("Segoe UI Semibold", 11F),
        ForeColor = Color.FromArgb(6, 83, 128),
        Margin = new Padding(0, 6, 0, 0),
    };

    private static Label CreateMetricValue() => new()
    {
        AutoSize = true,
        Font = new Font("Segoe UI Semibold", 21F),
        ForeColor = Color.FromArgb(4, 79, 122),
        Margin = new Padding(0, 7, 0, 0),
    };

    private void OnShown(object? sender, EventArgs eventArgs)
    {
        _commandResult.Text = "Ingen fysisk kommando er sendt.";
    }

    private void OnClosing(object? sender, FormClosingEventArgs eventArgs)
    {
        _connectionShutdown?.Cancel();
        _shutdown.Cancel();
        _controller.Dispose();
        _connectionShutdown?.Dispose();
        _shutdown.Dispose();
    }

    private void ConnectClicked(object? sender, EventArgs eventArgs)
    {
        if (_connectionShutdown is not null)
        {
            return;
        }

        _connectionShutdown = CancellationTokenSource.CreateLinkedTokenSource(_shutdown.Token);
        _pendingTarget.Clear();
        _targetInitializedFromLiveReading = false;
        _controller.BeginConnection();
        _connectButton.Enabled = false;
        _disconnectButton.Enabled = true;
        _runTask = RunPollingAsync(_connectionShutdown.Token);
    }

    private async void DisconnectClicked(object? sender, EventArgs eventArgs)
    {
        var connectionShutdown = _connectionShutdown;
        var runTask = _runTask;
        connectionShutdown?.Cancel();
        if (runTask is not null)
        {
            try
            {
                await runTask;
            }
            catch (OperationCanceledException)
            {
                // Cancellation is the expected disconnect path.
            }
        }

        connectionShutdown?.Dispose();
        _connectionShutdown = null;
        _runTask = null;
        _controller.Disconnect();
        _pendingTarget.Clear();
        _targetInitializedFromLiveReading = false;
        UpdateTargetPreview();
        _connectButton.Enabled = true;
        _disconnectButton.Enabled = false;
    }

    private async Task RunPollingAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                await _controller.PollOnceAsync(cancellationToken).ConfigureAwait(false);
                await Task.Delay(_options.PollInterval, cancellationToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            // A manual disconnect never replays a polling or control operation.
        }
    }

    private void OpenConnectionSetup(object? sender, EventArgs eventArgs)
    {
        using var setup = new VaconConnectionSetupForm(_configurationStore, _configuration);
        setup.ShowDialog(this);
        if (!setup.Saved)
        {
            return;
        }

        try
        {
            _configuration = _configurationStore.Load();
        }
        catch (InvalidOperationException exception)
        {
            MessageBox.Show(exception.Message, "Connection setup", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        if (MessageBox.Show(
                "Tilkoblingsinnstillingene er lagret. Start monitoren på nytt for å bruke valgt drive. Ingen fysisk kommando sendes.",
                "Start monitor på nytt",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information) == DialogResult.Yes)
        {
            Application.Restart();
            Close();
        }
    }

    private void ChangeTarget(int direction)
    {
        if (_pendingTarget.MoveByOneHz(direction))
        {
            UpdateTargetPreview();
        }
    }

    private void ShowCommissioningRequired() => MessageBox.Show(
        "Fysisk motorkontroll er ikke tilgjengelig. Idriftsettelse må dokumentere kontrollkilde, lokal/fjern-valg, frekvensgrenser, interlocks, nødstopp, kommunikasjonstap og restartatferd før skriverettigheter i det hele tatt kan vurderes.",
        "Idriftsettelse kreves",
        MessageBoxButtons.OK,
        MessageBoxIcon.Warning);

    private void Render(VaconMonitorSnapshot snapshot)
    {
        if (IsDisposed)
        {
            return;
        }

        if (InvokeRequired)
        {
            BeginInvoke(new Action(() => Render(snapshot)));
            return;
        }

        if (snapshot.State == VaconConnectionState.Connected &&
            snapshot.ActualFrequencyHz is decimal actualFrequency &&
            !_targetInitializedFromLiveReading)
        {
            _targetInitializedFromLiveReading = _pendingTarget.TryInitializeFromFreshActual(actualFrequency);
        }

        _frequencyValue.Text = snapshot.ActualFrequencyHz is decimal frequency ? $"{frequency:0.00} Hz" : "-- Hz";
        UpdateTargetPreview();
        _rpmValue.Text = snapshot.MotorSpeedRaw is ushort speed ? $"{speed} rå" : "Ikke verifisert";
        _currentValue.Text = snapshot.MotorCurrentAmperes is decimal current
            ? $"{current:0.00} A"
            : snapshot.MotorCurrentRaw is ushort raw ? $"{raw} rå" : "Ikke verifisert";
        _lastReadValue.Text = snapshot.LastSuccessfulReadUtc is DateTimeOffset timestamp
            ? timestamp.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss")
            : "Ingen vellykket måling ennå";

        (_connectionValue.Text, _connectionValue.ForeColor) = snapshot.State switch
        {
            VaconConnectionState.Connected => ("Tilkoblet", Color.FromArgb(0, 120, 68)),
            VaconConnectionState.Stale => ("Data utdaterte", Color.FromArgb(156, 96, 0)),
            VaconConnectionState.Unavailable => ("Forbindelse tapt", Color.FromArgb(170, 36, 43)),
            VaconConnectionState.Disconnected => ("Frakoblet", Color.FromArgb(104, 112, 120)),
            _ => ("Kobler til", Color.FromArgb(65, 88, 118)),
        };

        (_motorValue.Text, _motorValue.ForeColor) = snapshot.DriveStatus switch
        {
            VaconDriveStatus.Running => ("Kjører", Color.FromArgb(0, 120, 68)),
            VaconDriveStatus.Stopped => ("Stoppet", Color.FromArgb(104, 112, 120)),
            VaconDriveStatus.Fault => ("Feil", Color.FromArgb(170, 36, 43)),
            _ => ("Ikke verifisert", Color.FromArgb(104, 112, 120)),
        };
        _readyValue.Text = snapshot.StatusWord is VaconStatusWord readyStatus
            ? readyStatus.Ready ? "Klar" : "Ikke klar"
            : "Ikke verifisert";
        _readyValue.ForeColor = snapshot.StatusWord?.Ready == true
            ? Color.FromArgb(0, 120, 68)
            : Color.FromArgb(104, 112, 120);
        _faultValue.Text = snapshot.ActiveFault is VaconActiveFault fault
            ? $"{fault.Code}: {fault.Description}"
            : "Ingen aktive feil";
        _faultValue.ForeColor = snapshot.ActiveFault is null ? Color.FromArgb(0, 120, 68) : Color.FromArgb(170, 36, 43);
        _statusWordValue.Text = snapshot.StatusWord is VaconStatusWord statusWord
            ? $"0x{statusWord.Raw:X4}: {statusWord.ToDisplayText()}"
            : "Ikke verifisert";
        _statusWordValue.ForeColor = snapshot.StatusWord?.Fault == true
            ? Color.FromArgb(170, 36, 43)
            : snapshot.StatusWord?.Alarm == true ? Color.FromArgb(156, 96, 0) : Color.FromArgb(6, 83, 128);

        _communicationValue.Text = snapshot.FailureCategory is null
            ? snapshot.State == VaconConnectionState.Connected ? "OK" : "Ingen aktiv lesing"
            : snapshot.FailureCategory;
        _communicationValue.ForeColor = snapshot.FailureCategory is null
            ? Color.FromArgb(0, 120, 68)
            : Color.FromArgb(170, 36, 43);

        var targetCanBeAdjusted = snapshot.State == VaconConnectionState.Connected && _pendingTarget.CanAdjust;
        _minusButton.Enabled = targetCanBeAdjusted;
        _plusButton.Enabled = targetCanBeAdjusted;
        _applyButton.Enabled = false;
        _startButton.Enabled = false;
        _stopButton.Enabled = false;
        _connectButton.Enabled = _connectionShutdown is null;
        _disconnectButton.Enabled = _connectionShutdown is not null;
        _controlNote.Text = _options.Drive.FrequencyLimitsApproved
            ? $"{_controller.ControlsDisabledReason} Dokumentert omrade: {_options.Drive.MinimumFrequencyHz:0.00}-{_options.Drive.MaximumFrequencyHz:0.00} Hz."
            : "Malfrekvens kan ikke justeres for frekvensgrensene er dokumentert og godkjent.";
    }

    private void UpdateTargetPreview()
    {
        _targetValue.Text = _pendingTarget.ValueHz is decimal target ? $"{target:0} Hz (ikke sendt)" : "Venter pa fersk maling";
    }

    private void ToggleDetails()
    {
        if (_detailsPanel is null)
        {
            return;
        }

        _detailsPanel.Visible = !_detailsPanel.Visible;
        _detailsButton.Text = _detailsPanel.Visible ? "Skjul detaljer" : "Vis detaljer";
        PerformLayout();
    }
}
