using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

namespace Fjellfisk.SensorCollector;

public sealed record VigoTypeInformationReport(
    IReadOnlyList<VigoComMember> Members,
    string? UnavailableReason);

public interface IVigoDiagnosticSession : IDisposable
{
    void CreateCom();

    VigoTypeInformationReport DescribePublicMembers();

    void SelectTemperaturePhysIdProperty(string physId);

    object? ReadScalarValueProperty();

    object? ReadErrorCodeProperty();
}

public sealed record VigoDiagnosticResult(
    bool Succeeded,
    string? FailedStage,
    int? HResult,
    string? FailureMessage,
    VigoTypeInformationReport TypeInformation,
    float? Value,
    int? ErrorCode,
    TimeSpan Duration);

// Runs exactly one hardcoded temperature sequence. It contains no retry, polling,
// uploader, service, or arbitrary COM-member input.
public sealed class VigoDiagnosticsRunner
{
    private const string TemperatureSensorKey = "pacific01_temperature";
    private readonly ICollectorLogger _logger;

    public VigoDiagnosticsRunner(ICollectorLogger logger)
    {
        _logger = logger;
    }

    public VigoDiagnosticResult Run(IVigoDiagnosticSession session)
    {
        var started = Stopwatch.GetTimestamp();
        var typeInformation = new VigoTypeInformationReport(Array.Empty<VigoComMember>(), null);
        float? value = null;
        int? errorCode = null;

        var failure = RunStage("create_com", session.CreateCom);
        if (failure is not null)
        {
            return CreateFailure(failure, typeInformation, value, errorCode, started);
        }

        _logger.Log("diagnostic", "stage=type_info start");
        typeInformation = session.DescribePublicMembers();
        if (typeInformation.UnavailableReason is null)
        {
            _logger.Log(
                "diagnostic",
                $"stage=type_info success memberCount={typeInformation.Members.Count}");
        }
        else
        {
            _logger.Log("diagnostic", $"stage=type_info unavailable reason={typeInformation.UnavailableReason}");
        }

        var temperaturePhysId = SensorAllowlist.GetRequired(TemperatureSensorKey).PhysId;
        failure = RunStage("set_physid_property", () => session.SelectTemperaturePhysIdProperty(temperaturePhysId));
        if (failure is not null)
        {
            return CreateFailure(failure, typeInformation, value, errorCode, started);
        }

        failure = RunStage("value_property", () =>
        {
            value = Convert.ToSingle(session.ReadScalarValueProperty(), CultureInfo.InvariantCulture);
        });
        if (failure is not null)
        {
            return CreateFailure(failure, typeInformation, value, errorCode, started);
        }

        failure = RunStage("error_code_property", () =>
        {
            errorCode = Convert.ToInt32(session.ReadErrorCodeProperty(), CultureInfo.InvariantCulture);
        });
        if (failure is not null)
        {
            return CreateFailure(failure, typeInformation, value, errorCode, started);
        }

        var duration = ElapsedSince(started);
        _logger.Log(
            "diagnostic",
            $"stage=complete success value={value:F3} errorCode={errorCode} durationMs={duration.TotalMilliseconds:F0}");
        return new VigoDiagnosticResult(
            Succeeded: true,
            FailedStage: null,
            HResult: null,
            FailureMessage: null,
            TypeInformation: typeInformation,
            Value: value,
            ErrorCode: errorCode,
            Duration: duration);
    }

    private StageFailure? RunStage(string stage, Action action)
    {
        _logger.Log("diagnostic", $"stage={stage} start");
        try
        {
            action();
            _logger.Log("diagnostic", $"stage={stage} success");
            return null;
        }
        catch (COMException exception)
        {
            _logger.Log(
                "diagnostic",
                $"stage={stage} failure hresult=0x{exception.HResult:X8} message={exception.Message}");
            return new StageFailure(stage, exception.HResult, exception.Message);
        }
        catch (Exception exception)
        {
            _logger.Log(
                "diagnostic",
                $"stage={stage} failure hresult=none message={exception.Message}");
            return new StageFailure(stage, null, exception.Message);
        }
    }

    private static VigoDiagnosticResult CreateFailure(
        StageFailure failure,
        VigoTypeInformationReport typeInformation,
        float? value,
        int? errorCode,
        long started) =>
        new(
            Succeeded: false,
            FailedStage: failure.Stage,
            HResult: failure.HResult,
            FailureMessage: failure.Message,
            TypeInformation: typeInformation,
            Value: value,
            ErrorCode: errorCode,
            Duration: ElapsedSince(started));

    private static TimeSpan ElapsedSince(long started) => TimeSpan.FromSeconds(
        (Stopwatch.GetTimestamp() - started) / (double)Stopwatch.Frequency);

    private sealed record StageFailure(string Stage, int? HResult, string Message);
}

public sealed class VigoComDiagnosticSession : IVigoDiagnosticSession
{
    private readonly VigoProReadOnlySession _session = new();

    public void CreateCom() => _session.CreateCom();

    public VigoTypeInformationReport DescribePublicMembers()
    {
        try
        {
            return new VigoTypeInformationReport(_session.DescribePublicMembers(), null);
        }
        catch (COMException exception)
        {
            return new VigoTypeInformationReport(
                Array.Empty<VigoComMember>(),
                $"HRESULT=0x{exception.HResult:X8}; {exception.Message}");
        }
        catch (Exception exception)
        {
            return new VigoTypeInformationReport(
                Array.Empty<VigoComMember>(),
                exception.Message);
        }
    }

    public void SelectTemperaturePhysIdProperty(string physId) => _session.SelectPhysIdProperty(physId);

    public object? ReadScalarValueProperty() => _session.ReadScalarValueProperty();

    public object? ReadErrorCodeProperty() => _session.ReadErrorCodeProperty();

    public void Dispose() => _session.Dispose();
}
