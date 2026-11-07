using System.Drawing;

namespace Fjellfisk.VaconMonitor;

/// <summary>
/// Edits only local monitor connection metadata. It never sends Modbus data or
/// modifies Windows networking.
/// </summary>
public sealed class VaconConnectionSetupForm : Form
{
    private readonly VaconDriveConfigurationStore _store;
    private VaconDriveConfigurationDocument _document;
    private readonly ComboBox _drives = new();
    private readonly TextBox _idInput = new();
    private readonly TextBox _nameInput = new();
    private readonly TextBox _hostInput = new();
    private readonly TextBox _subnetInput = new();
    private readonly TextBox _gatewayInput = new();
    private readonly NumericUpDown _portInput = new();
    private readonly NumericUpDown _unitInput = new();
    private readonly NumericUpDown _minimumInput = new();
    private readonly NumericUpDown _maximumInput = new();
    private readonly CheckBox _limitsApprovedInput = new();
    private string? _editingId;
    private bool _loading;

    public VaconConnectionSetupForm(
        VaconDriveConfigurationStore store,
        VaconDriveConfigurationDocument document)
    {
        _store = store;
        _document = document;

        Text = "VACON connection setup";
        StartPosition = FormStartPosition.CenterParent;
        MinimumSize = new Size(620, 690);
        Size = new Size(680, 760);
        BackColor = Color.FromArgb(242, 246, 250);
        Font = new Font("Segoe UI", 10F);

        var page = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            Padding = new Padding(24),
            ColumnCount = 2,
            RowCount = 15,
        };
        page.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 190));
        page.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        var heading = new Label
        {
            Text = "VACON CONNECTIONS",
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 18F),
            ForeColor = Color.FromArgb(5, 55, 91),
            Margin = new Padding(0, 0, 0, 8),
        };
        page.Controls.Add(heading, 0, 0);
        page.SetColumnSpan(heading, 2);

        var note = new Label
        {
            Text = "Oppsettet er lokal metadata for monitoren. Det endrer ikke Windows-nettverk, VACON-parametere eller fysisk styring.",
            AutoSize = true,
            MaximumSize = new Size(590, 0),
            ForeColor = Color.FromArgb(78, 92, 110),
            Margin = new Padding(0, 0, 0, 16),
        };
        page.Controls.Add(note, 0, 1);
        page.SetColumnSpan(note, 2);

        _drives.DropDownStyle = ComboBoxStyle.DropDownList;
        _drives.Dock = DockStyle.Fill;
        _drives.SelectedIndexChanged += (_, _) => LoadSelectedDrive();
        AddRow(page, 2, "Configured drive", _drives);

        ConfigureTextInput(_idInput);
        ConfigureTextInput(_nameInput);
        ConfigureTextInput(_hostInput);
        ConfigureTextInput(_subnetInput);
        ConfigureTextInput(_gatewayInput);
        ConfigureNumberInput(_portInput, 1, 65535, 0);
        ConfigureNumberInput(_unitInput, 1, 255, 0);
        ConfigureNumberInput(_minimumInput, 0, 1000, 2);
        ConfigureNumberInput(_maximumInput, 0, 1000, 2);

        AddRow(page, 3, "Drive ID", _idInput);
        AddRow(page, 4, "Display name", _nameInput);
        AddRow(page, 5, "IP address", _hostInput);
        AddRow(page, 6, "Subnet mask", _subnetInput);
        AddRow(page, 7, "Gateway", _gatewayInput);
        AddRow(page, 8, "Modbus TCP port", _portInput);
        AddRow(page, 9, "Modbus Unit ID", _unitInput);
        AddRow(page, 10, "Minimum Hz", _minimumInput);
        AddRow(page, 11, "Maximum Hz", _maximumInput);

        _limitsApprovedInput.Text = "Frekvensgrensene er dokumentert for dette oppsettet";
        _limitsApprovedInput.AutoSize = true;
        _limitsApprovedInput.Margin = new Padding(0, 7, 0, 7);
        page.Controls.Add(_limitsApprovedInput, 1, 12);

        var safety = new Label
        {
            Text = "Merk: Selv dokumenterte grenser aktiverer ikke fysisk Start, Stopp eller frekvensskriving. Live-modus forblir FC04 read-only.",
            AutoSize = true,
            MaximumSize = new Size(400, 0),
            ForeColor = Color.FromArgb(126, 85, 0),
        };
        page.Controls.Add(safety, 1, 13);

        var actions = new FlowLayoutPanel
        {
            AutoSize = true,
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            Margin = new Padding(0, 18, 0, 0),
        };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.OK };
        var delete = new Button { Text = "Remove", AutoSize = true };
        var setActive = new Button { Text = "Use as active drive", AutoSize = true };
        var save = new Button { Text = "Save connection", AutoSize = true, BackColor = Color.FromArgb(0, 100, 190), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
        var add = new Button { Text = "New connection", AutoSize = true };
        close.Click += (_, _) => Close();
        delete.Click += (_, _) => DeleteClicked();
        setActive.Click += (_, _) => SetActiveClicked();
        save.Click += (_, _) => SaveClicked();
        add.Click += (_, _) => NewClicked();
        actions.Controls.Add(close);
        actions.Controls.Add(delete);
        actions.Controls.Add(setActive);
        actions.Controls.Add(save);
        actions.Controls.Add(add);
        page.Controls.Add(actions, 0, 14);
        page.SetColumnSpan(actions, 2);

        Controls.Add(page);
        ReloadChoices(_document.SelectedDriveId);
    }

    public bool Saved { get; private set; }

    private void ReloadChoices(string? selectedId)
    {
        _loading = true;
        try
        {
            _drives.Items.Clear();
            foreach (var drive in _document.Drives)
            {
                _drives.Items.Add(drive);
            }

            var selected = _document.Drives.FirstOrDefault(drive => string.Equals(drive.Id, selectedId, StringComparison.OrdinalIgnoreCase))
                ?? _document.SelectedDrive;
            _drives.SelectedItem = selected;
            PopulateInputs(selected);
        }
        finally
        {
            _loading = false;
        }
    }

    private void LoadSelectedDrive()
    {
        if (_loading || _drives.SelectedItem is not VaconDriveConfiguration drive)
        {
            return;
        }

        PopulateInputs(drive);
    }

    private void PopulateInputs(VaconDriveConfiguration drive)
    {
        _editingId = drive.Id;
        _idInput.Text = drive.Id;
        _nameInput.Text = drive.DisplayName;
        _hostInput.Text = drive.Host;
        _subnetInput.Text = drive.SubnetMask;
        _gatewayInput.Text = drive.Gateway;
        _portInput.Value = drive.Port;
        _unitInput.Value = drive.UnitId;
        _minimumInput.Value = drive.MinimumFrequencyHz;
        _maximumInput.Value = drive.MaximumFrequencyHz;
        _limitsApprovedInput.Checked = drive.FrequencyLimitsApproved;
    }

    private void NewClicked()
    {
        var number = 1;
        var nextId = "vacon-drive-1";
        while (_document.Drives.Any(drive => string.Equals(drive.Id, nextId, StringComparison.OrdinalIgnoreCase)))
        {
            number++;
            nextId = $"vacon-drive-{number}";
        }

        PopulateInputs(VaconDriveConfiguration.Default with
        {
            Id = nextId,
            DisplayName = $"VACON drive {number}",
            FrequencyLimitsApproved = false,
        });
        _drives.SelectedIndex = -1;
    }

    private void SaveClicked()
    {
        try
        {
            var drive = ReadInputs();
            var drives = _document.Drives.ToList();
            var existingIndex = _editingId is null
                ? -1
                : drives.FindIndex(item => string.Equals(item.Id, _editingId, StringComparison.OrdinalIgnoreCase));
            var duplicate = drives.Any(item => !string.Equals(item.Id, _editingId, StringComparison.OrdinalIgnoreCase) &&
                string.Equals(item.Id, drive.Id, StringComparison.OrdinalIgnoreCase));
            if (duplicate)
            {
                throw new ArgumentException("Drive ID is already in use.");
            }

            if (existingIndex >= 0)
            {
                drives[existingIndex] = drive;
            }
            else
            {
                drives.Add(drive);
            }

            var selectedId = string.Equals(_document.SelectedDriveId, _editingId, StringComparison.OrdinalIgnoreCase)
                ? drive.Id
                : _document.SelectedDriveId;
            _document = new VaconDriveConfigurationDocument(selectedId, drives);
            _store.Save(_document);
            Saved = true;
            ReloadChoices(drive.Id);
        }
        catch (Exception exception) when (exception is ArgumentException or ArgumentOutOfRangeException or InvalidOperationException)
        {
            MessageBox.Show(exception.Message, "Connection not saved", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void SetActiveClicked()
    {
        try
        {
            var drive = ReadInputs();
            SaveCurrentDraft(drive);
            _document = _document with { SelectedDriveId = drive.Id };
            _store.Save(_document);
            Saved = true;
            ReloadChoices(drive.Id);
        }
        catch (Exception exception) when (exception is ArgumentException or ArgumentOutOfRangeException or InvalidOperationException)
        {
            MessageBox.Show(exception.Message, "Active connection not changed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void DeleteClicked()
    {
        if (_editingId is null || _document.Drives.Count == 1)
        {
            MessageBox.Show("At least one VACON connection must remain.", "Connection not removed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var drives = _document.Drives.Where(drive => !string.Equals(drive.Id, _editingId, StringComparison.OrdinalIgnoreCase)).ToList();
        var selectedId = string.Equals(_document.SelectedDriveId, _editingId, StringComparison.OrdinalIgnoreCase)
            ? drives[0].Id
            : _document.SelectedDriveId;
        _document = new VaconDriveConfigurationDocument(selectedId, drives);
        _store.Save(_document);
        Saved = true;
        ReloadChoices(selectedId);
    }

    private void SaveCurrentDraft(VaconDriveConfiguration drive)
    {
        var drives = _document.Drives.ToList();
        var existingIndex = _editingId is null
            ? -1
            : drives.FindIndex(item => string.Equals(item.Id, _editingId, StringComparison.OrdinalIgnoreCase));
        var duplicate = drives.Any(item => !string.Equals(item.Id, _editingId, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(item.Id, drive.Id, StringComparison.OrdinalIgnoreCase));
        if (duplicate)
        {
            throw new ArgumentException("Drive ID is already in use.");
        }

        if (existingIndex >= 0)
        {
            drives[existingIndex] = drive;
        }
        else
        {
            drives.Add(drive);
        }

        _document = new VaconDriveConfigurationDocument(_document.SelectedDriveId, drives);
    }

    private VaconDriveConfiguration ReadInputs()
    {
        var drive = new VaconDriveConfiguration(
            _idInput.Text.Trim(),
            _nameInput.Text.Trim(),
            _hostInput.Text.Trim(),
            _subnetInput.Text.Trim(),
            _gatewayInput.Text.Trim(),
            decimal.ToInt32(_portInput.Value),
            decimal.ToByte(_unitInput.Value),
            _minimumInput.Value,
            _maximumInput.Value,
            _limitsApprovedInput.Checked);
        drive.Validate();
        return drive;
    }

    private static void ConfigureTextInput(TextBox input)
    {
        input.Dock = DockStyle.Fill;
    }

    private static void ConfigureNumberInput(NumericUpDown input, decimal minimum, decimal maximum, int decimalPlaces)
    {
        input.Minimum = minimum;
        input.Maximum = maximum;
        input.DecimalPlaces = decimalPlaces;
        input.Dock = DockStyle.Left;
        input.Width = 180;
    }

    private static void AddRow(TableLayoutPanel panel, int row, string label, Control input)
    {
        panel.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 7, 12, 7) }, 0, row);
        input.Margin = new Padding(0, 4, 0, 4);
        panel.Controls.Add(input, 1, row);
    }
}
