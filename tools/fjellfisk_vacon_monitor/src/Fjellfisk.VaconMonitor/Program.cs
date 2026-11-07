namespace Fjellfisk.VaconMonitor;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        VaconMonitorOptions options;
        try
        {
            options = VaconMonitorOptions.Parse(args);
        }
        catch (ArgumentException exception)
        {
            MessageBox.Show(exception.Message, "Fjellfisk VACON Monitor", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        VaconDriveConfigurationStore configurationStore = new();
        VaconDriveConfigurationDocument configuration;
        try
        {
            configuration = configurationStore.Load();
        }
        catch (InvalidOperationException exception)
        {
            MessageBox.Show(exception.Message, "Fjellfisk VACON Control", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        options = options.ForDrive(configuration.SelectedDrive);
        var logger = new VaconMonitorLogger();
        logger.LogStartup(options.Simulated);
        SimulatedVaconDrive? simulation = null;
        IVaconReadOnlyClient client;
        IVaconControlGateway controlGateway;
        if (options.Simulated)
        {
            simulation = new SimulatedVaconDrive(options.Drive.ToControlLimits("local-configuration"));
            client = new SimulatedVaconReadOnlyClient(simulation);
            controlGateway = new SimulatedVaconControlGateway(simulation);
        }
        else
        {
            client = new VaconReadOnlyModbusClient(options, new TcpVaconModbusTransport(options));
            controlGateway = new BlockedLiveVaconControlGateway();
        }

        using var controller = new VaconMonitorController(client, options, logger, controlGateway);

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new VaconControlForm(controller, options, simulation, configurationStore, configuration));
    }
}

