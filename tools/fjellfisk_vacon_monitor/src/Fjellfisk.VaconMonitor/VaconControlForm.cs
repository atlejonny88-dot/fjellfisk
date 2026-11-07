using System.Drawing;

namespace Fjellfisk.VaconMonitor;

public sealed class VaconControlForm : Form
{
    private readonly VaconMonitorController _controller;
    private readonly VaconMonitorOptions _options;
    private readonly SimulatedVaconDrive? _simulation;
    private readonly VaconDriveConfigurationStore _configurationStore;
    private VaconDriveConfigurationDocument _configuration;
    private readonly CancellationTokenSource _shutdown = new();
    private readonly Label _connectionValue = CreateStatusValue();
    private readonly Label _motorValue = CreateStatusValue();
    private readonly Label _faultValue = CreateStatusValue();
    private readonly Label _statusWordValue = CreateStatusValue();
    private readonly Label _frequencyValue = new();
    private readonly Label _targetValue = CreateMetricValue();
    private readonly Label _rpmValue = CreateMetricValue();
    private readonly Label _currentValue = CreateMetricValue();
    private readonly Label _lastReadValue = CreateStatusValue();
    private readonly Label _controlNote = new();
    private readonly Label _commandResult = new();
    private readonly NumericUpDown _targetInput = new();
    private readonly ComboBox _stepInput = new();
    private readonly Button _minusButton = new();
    private readonly Button _plusButton = new();
    private readonly Button _applyButton = new();
    private readonly Button _startButton = new();
    private readonly Button _stopButton = new();
    private readonly Button _faultButton = new();
    private readonly Button _connectionButton = new();
    private readonly Label _activeDriveValue = CreateStatusValue();
    private readonly Button _setupButton = new();
    private Task? _runTask;

    public VaconControlForm(
        VaconMonitorController controller,
        VaconMonitorOptions options,
        SimulatedVaconDrive? simulation,
        VaconDriveConfigurationStore configurationStore,
        VaconDriveConfigurationDocument configuration)
    {
        _controller = controller;
        _options = options;
        _simulation = simulation;
        _configurationStore = configurationStore;
        _configuration = configuration;
        _controller.Updated += Render;

        Text = "Fjellfisk VACON Control v0.4.0";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(820, 720);
        Size = new Size(920, 800);
        BackColor = Color.FromArgb(242, 246, 250);
        Font = new Font("Segoe UI", 10F);

        var page = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(28),
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
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        page.Controls.Add(CreateHeading(), 0, 0);
        page.Controls.Add(CreateModeNote(), 0, 1);
        page.Controls.Add(CreateDrivePanel(), 0, 2);
        page.Controls.Add(CreateStatusPanel(), 0, 3);
        page.Controls.Add(CreateMetricsPanel(), 0, 4);
        page.Controls.Add(CreateControlPanel(), 0, 5);

        if (_simulation is not null)
        {
            page.Controls.Add(CreateSimulationPanel(), 0, 6);
        }

        _lastReadValue.Margin = new Padding(0, 18, 0, 0);
        page.Controls.Add(CreateLastReadPanel(), 0, 7);
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
            Font = new Font("Segoe UI Semibold", 22F),
            ForeColor = Color.FromArgb(5, 55, 91),
        });
        return panel;
    }

    private Control CreateModeNote()
    {
        return new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 16),
            ForeColor = _options.Simulated ? Color.FromArgb(126, 85, 0) : Color.FromArgb(104, 48, 40),
            Text = _options.Simulated
                ? "SIMULATOR - kontrollene påvirker kun en lokal modell."
                : "LIVE MONITORING - REMOTE CONTROL DISABLED. Modbus FC04 brukes kun til prosessdata.",
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
        grid.Controls.Add(CreateStatusBlock("Aktiv feil", _faultValue), 2, 0);
        grid.Controls.Add(CreateStatusBlock("Statusord", _statusWordValue), 0, 1);
        grid.SetColumnSpan(grid.GetControlFromPosition(0, 1)!, 3);
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
        _activeDriveValue.Margin = new Padding(0, 0, 0, 8);
        layout.Controls.Add(_activeDriveValue, 0, 1);
        _setupButton.Text = "Setup connections";
        _setupButton.AutoSize = true;
        _setupButton.Margin = new Padding(14, 3, 0, 3);
        _setupButton.Click += OpenConnectionSetup;
        layout.Controls.Add(_setupButton, 1, 1);
        var note = new Label
        {
            Text = "Only one drive is monitored at a time. Switching the active drive requires an explicit monitor restart and never sends a control command.",
            AutoSize = true,
            MaximumSize = new Size(680, 0),
            ForeColor = Color.FromArgb(78, 92, 110),
            Margin = new Padding(0, 8, 0, 0),
        };
        layout.Controls.Add(note, 0, 2);
        layout.SetColumnSpan(note, 2);
        panel.Controls.Add(layout);
        return panel;
    }

    private Control CreateMetricsPanel()
    {
        var panel = CreatePanel();
        var content = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, AutoSize = true };
        content.Controls.Add(CreateSectionHeading("LIVE MONITORING"), 0, 0);
        var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, AutoSize = true };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));

        _frequencyValue.AutoSize = true;
        _frequencyValue.Text = "-- Hz";
        _frequencyValue.Font = new Font("Segoe UI Semibold", 34F);
        _frequencyValue.ForeColor = Color.FromArgb(4, 79, 122);
        grid.Controls.Add(CreateMetricBlock("Actual Frequency", _frequencyValue), 0, 0);
        grid.Controls.Add(CreateMetricBlock("Motor Speed (pros.data)", _rpmValue), 1, 0);
        grid.Controls.Add(CreateMetricBlock("Motor Current (raw, unverified)", _currentValue), 2, 0);
        content.Controls.Add(grid, 0, 1);
        panel.Controls.Add(content);
        return panel;
    }

    private Control CreateControlPanel()
    {
        var panel = CreatePanel();
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 6, RowCount = 7, AutoSize = true };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 72));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

        layout.Controls.Add(new Label
        {
            Text = "FREQUENCY CONTROL",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 12F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 0, 0, 12),
        }, 0, 0);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 0)!, 6);

        var limits = _controller.ControlLimits;
        _targetInput.DecimalPlaces = 2;
        _targetInput.Increment = limits?.DefaultStepHz ?? 0.5m;
        _targetInput.Minimum = limits?.MinimumHz ?? 0m;
        _targetInput.Maximum = limits?.MaximumHz ?? 999m;
        _targetInput.Value = Math.Min(_targetInput.Maximum, Math.Max(_targetInput.Minimum, 13m));
        _targetInput.ValueChanged += (_, _) => UpdateTargetPreview();
        _targetInput.Width = 100;
        _targetInput.Margin = new Padding(0, 4, 8, 4);

        _stepInput.DropDownStyle = ComboBoxStyle.DropDownList;
        _stepInput.Items.AddRange(new object[] { "0,1 Hz", "0,5 Hz", "1,0 Hz" });
        _stepInput.SelectedIndex = 0;
        _targetInput.Increment = 0.1m;
        _stepInput.SelectedIndexChanged += (_, _) => _targetInput.Increment = _stepInput.SelectedIndex switch
        {
            0 => 0.1m,
            1 => 0.5m,
            _ => 1m,
        };
        _stepInput.Width = 86;

        _minusButton.Text = "-";
        _minusButton.Width = 54;
        _minusButton.Click += (_, _) => ChangeTarget(-_targetInput.Increment);
        _plusButton.Text = "+";
        _plusButton.Width = 54;
        _plusButton.Click += (_, _) => ChangeTarget(_targetInput.Increment);
        _applyButton.Text = "Apply";
        _applyButton.Width = 88;
        _applyButton.BackColor = Color.FromArgb(0, 100, 190);
        _applyButton.ForeColor = Color.White;
        _applyButton.FlatStyle = FlatStyle.Flat;
        _applyButton.Click += ApplyClickedAsync;

        layout.Controls.Add(CreateStatusBlock("Target Frequency", _targetValue), 0, 1);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 1)!, 6);

        layout.Controls.Add(new Label { Text = "Target Hz", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 2);
        layout.Controls.Add(_targetInput, 1, 2);
        layout.Controls.Add(_stepInput, 2, 2);
        layout.Controls.Add(_minusButton, 3, 2);
        layout.Controls.Add(_plusButton, 4, 2);
        layout.Controls.Add(_applyButton, 5, 2);

        layout.Controls.Add(new Label
        {
            Text = "MOTOR CONTROL",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 12F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 16, 0, 8),
        }, 0, 3);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 3)!, 6);

        _startButton.Text = "START MOTOR";
        _startButton.BackColor = Color.FromArgb(0, 123, 76);
        _startButton.ForeColor = Color.White;
        _startButton.FlatStyle = FlatStyle.Flat;
        _startButton.AutoSize = true;
        _startButton.Click += StartClickedAsync;
        _stopButton.Text = "STOP MOTOR";
        _stopButton.BackColor = Color.FromArgb(176, 38, 45);
        _stopButton.ForeColor = Color.White;
        _stopButton.FlatStyle = FlatStyle.Flat;
        _stopButton.AutoSize = true;
        _stopButton.Margin = new Padding(12, 8, 0, 8);
        _stopButton.Click += StopClickedAsync;
        layout.Controls.Add(_startButton, 0, 4);
        layout.SetColumnSpan(_startButton, 2);
        layout.Controls.Add(_stopButton, 2, 4);
        layout.SetColumnSpan(_stopButton, 2);

        _controlNote.AutoSize = true;
        _controlNote.ForeColor = Color.FromArgb(110, 85, 20);
        _controlNote.Margin = new Padding(0, 8, 0, 0);
        layout.Controls.Add(_controlNote, 0, 5);
        layout.SetColumnSpan(_controlNote, 6);
        _commandResult.AutoSize = true;
        _commandResult.ForeColor = Color.FromArgb(78, 92, 110);
        _commandResult.Margin = new Padding(0, 4, 0, 0);
        layout.Controls.Add(_commandResult, 0, 6);
        layout.SetColumnSpan(_commandResult, 6);
        panel.Controls.Add(layout);
        return panel;
    }

    private Control CreateSimulationPanel()
    {
        var panel = CreatePanel();
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true };
        layout.Controls.Add(new Label
        {
            Text = "Simulatortest",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 11F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 7, 18, 0),
        });
        _faultButton.Text = "Simuler feil";
        _faultButton.Click += (_, _) => ToggleSimulatedFault();
        _connectionButton.Text = "Simuler kommunikasjonsbrudd";
        _connectionButton.Click += (_, _) => ToggleSimulatedConnection();
        layout.Controls.Add(_faultButton);
        layout.Controls.Add(_connectionButton);
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
        _lastReadValue.Location = new Point(0, 23);
        panel.Controls.Add(_lastReadValue);
        return panel;
    }

    private static Panel CreatePanel() => new()
    {
        AutoSize = true,
        Dock = DockStyle.Top,
        BackColor = Color.White,
        BorderStyle = BorderStyle.FixedSingle,
        Padding = new Padding(20),
        Margin = new Padding(0, 0, 0, 14),
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
        _runTask = _controller.RunAsync(_shutdown.Token);
    }

    private void OnClosing(object? sender, FormClosingEventArgs eventArgs)
    {
        _shutdown.Cancel();
        _controller.Dispose();
        _shutdown.Dispose();
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
                "Connection settings were saved. Restart the monitor now to use the selected drive? No physical command will be sent.",
                "Restart monitoring",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information) == DialogResult.Yes)
        {
            Application.Restart();
            Close();
        }
    }

    private void ChangeTarget(decimal delta)
    {
        var next = _targetInput.Value + delta;
        _targetInput.Value = Math.Min(_targetInput.Maximum, Math.Max(_targetInput.Minimum, next));
    }

    private async void ApplyClickedAsync(object? sender, EventArgs eventArgs)
    {
        if (!ConfirmSimulationCommand($"Bekreft APPLY { _targetInput.Value:0.00} Hz. Dette påvirker bare simulatoren i denne versjonen."))
        {
            return;
        }

        var result = await _controller.ApplyTargetFrequencyAsync(_targetInput.Value, true, _shutdown.Token);
        ShowControlResult(result);
    }

    private async void StartClickedAsync(object? sender, EventArgs eventArgs)
    {
        if (MessageBox.Show(
                "Bekreft START MOTOR. Dette påvirker bare simulatoren i denne versjonen.",
                "Bekreft start",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            return;
        }

        ShowControlResult(await _controller.StartMotorAsync(true, _shutdown.Token));
    }

    private async void StopClickedAsync(object? sender, EventArgs eventArgs)
    {
        if (MessageBox.Show(
                "Bekreft STOP MOTOR. Programvare erstatter ikke fysisk nødstopp.",
                "Bekreft stopp",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            return;
        }

        ShowControlResult(await _controller.StopMotorAsync(true, _shutdown.Token));
    }

    private void ToggleSimulatedFault()
    {
        if (_simulation is null)
        {
            return;
        }

        var enableFault = _controller.Current.ActiveFault is null;
        _simulation.SetSimulationFault(enableFault ? new VaconActiveFault("SIM-01", "Simulert aktiv feil") : null);
        _faultButton.Text = enableFault ? "Fjern simulert feil" : "Simuler feil";
        _ = _controller.PollOnceAsync(_shutdown.Token);
    }

    private void ToggleSimulatedConnection()
    {
        if (_simulation is null)
        {
            return;
        }

        var disconnect = _controller.Current.State != VaconConnectionState.Unavailable;
        _simulation.SetSimulationConnectionAvailable(!disconnect);
        _connectionButton.Text = disconnect ? "Gjenopprett simulert forbindelse" : "Simuler kommunikasjonsbrudd";
        _ = _controller.PollOnceAsync(_shutdown.Token);
    }

    private void ShowControlResult(VaconControlAttempt result)
    {
        _commandResult.ForeColor = result.Accepted ? Color.FromArgb(0, 120, 68) : Color.FromArgb(170, 36, 43);
        _commandResult.Text = result.Accepted
            ? $"Simulert kommando akseptert{(result.Acknowledged ? " og bekreftet av tilbakelesing" : "")}. Tilbakelesing: {result.ReadbackFrequencyHz?.ToString("0.00") ?? "--"} Hz"
            : $"Kommando ikke sendt/akseptert: {result.ResultCode}";
    }

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

        _frequencyValue.Text = snapshot.ActualFrequencyHz is decimal frequency ? $"{frequency:0.00} Hz" : "-- Hz";
        UpdateTargetPreview();
        _rpmValue.Text = snapshot.MotorSpeedRpm is int rpm ? $"{rpm} RPM" : "Ikke verifisert";
        _currentValue.Text = snapshot.MotorCurrentAmperes is decimal current
            ? $"{current:0.00} A"
            : snapshot.MotorCurrentRaw is ushort raw ? $"{raw} rå" : "Ikke verifisert";
        _lastReadValue.Text = snapshot.LastSuccessfulReadUtc is DateTimeOffset timestamp
            ? timestamp.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss")
            : "Ingen vellykket måling ennå";

        (_connectionValue.Text, _connectionValue.ForeColor) = snapshot.State switch
        {
            VaconConnectionState.Simulated => ("SIMULERT", Color.FromArgb(126, 85, 0)),
            VaconConnectionState.Connected => ("Connected", Color.FromArgb(0, 120, 68)),
            VaconConnectionState.Stale => ("Data utdaterte", Color.FromArgb(156, 96, 0)),
            VaconConnectionState.Unavailable => ("Disconnected", Color.FromArgb(170, 36, 43)),
            _ => ("Kobler til", Color.FromArgb(65, 88, 118)),
        };

        (_motorValue.Text, _motorValue.ForeColor) = snapshot.DriveStatus switch
        {
            VaconDriveStatus.Running => ("Running", Color.FromArgb(0, 120, 68)),
            VaconDriveStatus.Stopped => ("Stopped", Color.FromArgb(104, 112, 120)),
            VaconDriveStatus.Fault => ("Fault", Color.FromArgb(170, 36, 43)),
            _ => ("Ikke verifisert", Color.FromArgb(104, 112, 120)),
        };
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

        var controlsEnabled = _controller.ControlsEnabled;
        _targetInput.Enabled = controlsEnabled;
        _stepInput.Enabled = controlsEnabled;
        _minusButton.Enabled = controlsEnabled;
        _plusButton.Enabled = controlsEnabled;
        _applyButton.Enabled = controlsEnabled;
        _startButton.Enabled = controlsEnabled;
        _stopButton.Enabled = controlsEnabled;
        _controlNote.Text = controlsEnabled
            ? $"Simulator limits: {_options.Drive.MinimumFrequencyHz:0.00}–{_options.Drive.MaximumFrequencyHz:0.00} Hz. These only affect the local simulator."
            : $"{_controller.ControlsDisabledReason} Configured range: {_options.Drive.MinimumFrequencyHz:0.00}–{_options.Drive.MaximumFrequencyHz:0.00} Hz; it does not enable physical control.";
    }

    private bool ConfirmSimulationCommand(string message) => MessageBox.Show(
        message,
        "Bekreft simulert kommando",
        MessageBoxButtons.YesNo,
        MessageBoxIcon.Warning) == DialogResult.Yes;

    private void UpdateTargetPreview()
    {
        _targetValue.Text = _controller.IsSimulation
            ? $"{_targetInput.Value:0.00} Hz"
            : "Ikke tilgjengelig i live read-only";
    }
}
