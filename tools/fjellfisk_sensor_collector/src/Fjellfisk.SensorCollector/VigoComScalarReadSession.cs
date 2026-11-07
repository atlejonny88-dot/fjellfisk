using System.Reflection;
using System.Runtime.InteropServices;

namespace Fjellfisk.SensorCollector;

// The production COM surface deliberately contains only the proven scalar
// read sequence. Diagnostics/type inspection remain in the Service Tool.
internal sealed class VigoComScalarReadSession : IDisposable
{
    private object? _vigo;

    public void CreateCom()
    {
        var vigoType = Type.GetTypeFromProgID("VIGO.PRO", throwOnError: true)
            ?? throw new InvalidOperationException("VIGO.PRO is not registered on this computer.");
        _vigo = Activator.CreateInstance(vigoType)
            ?? throw new InvalidOperationException("VIGO.PRO could not be created.");
    }

    // PhysId selects one compiled allowlisted scalar on the local COM object.
    // It is not a process-data write.
    public void SelectPhysId(string physId) => RequireCreatedVigo().GetType().InvokeMember(
        "PhysId",
        BindingFlags.SetProperty,
        binder: null,
        target: RequireCreatedVigo(),
        args: new object[] { physId });

    public object? ReadValue() => RequireCreatedVigo().GetType().InvokeMember(
        "Value",
        BindingFlags.GetProperty,
        binder: null,
        target: RequireCreatedVigo(),
        args: null);

    public object? ReadErrorCode() => RequireCreatedVigo().GetType().InvokeMember(
        "ErrorCode",
        BindingFlags.GetProperty,
        binder: null,
        target: RequireCreatedVigo(),
        args: null);

    public void Dispose()
    {
        if (_vigo is not null && Marshal.IsComObject(_vigo))
        {
            Marshal.FinalReleaseComObject(_vigo);
        }

        _vigo = null;
    }

    private object RequireCreatedVigo() => _vigo
        ?? throw new InvalidOperationException("VIGO.PRO has not been created.");
}
