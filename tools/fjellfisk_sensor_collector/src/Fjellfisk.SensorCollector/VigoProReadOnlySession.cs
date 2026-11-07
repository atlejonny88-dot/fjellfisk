using System.Globalization;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace Fjellfisk.SensorCollector;

internal sealed class VigoProReadOnlySession : IDisposable
{
    private object? _vigo;

    public void CreateCom()
    {
        var vigoType = Type.GetTypeFromProgID("VIGO.PRO", throwOnError: true)
            ?? throw new InvalidOperationException("VIGO.PRO is not registered on this computer.");
        _vigo = Activator.CreateInstance(vigoType)
            ?? throw new InvalidOperationException("VIGO.PRO could not be created.");
    }

    public IReadOnlyList<VigoComMember> DescribePublicMembers()
    {
        var vigo = RequireCreatedVigo();
        if (vigo is not IDispatchTypeInfoSource dispatch)
        {
            return Array.Empty<VigoComMember>();
        }

        var countResult = dispatch.GetTypeInfoCount(out var typeInfoCount);
        Marshal.ThrowExceptionForHR(countResult);
        if (typeInfoCount == 0)
        {
            return Array.Empty<VigoComMember>();
        }

        var typeInfoResult = dispatch.GetTypeInfo(
            0,
            CultureInfo.InvariantCulture.LCID,
            out var typeInfo);
        Marshal.ThrowExceptionForHR(typeInfoResult);
        return VigoComTypeInfoReader.ReadPublicMembers(typeInfo);
    }

    // This selects the scalar on the local VIGO.PRO object. It is not a
    // process-data write and is used only by the one-shot diagnostics sequence.
    public void SelectPhysIdProperty(string physId) => RequireCreatedVigo().GetType().InvokeMember(
        "PhysId",
        BindingFlags.SetProperty,
        binder: null,
        target: RequireCreatedVigo(),
        args: new object[] { physId });

    public object? ReadScalarValueProperty() => RequireCreatedVigo().GetType().InvokeMember(
        "Value",
        BindingFlags.GetProperty,
        binder: null,
        target: RequireCreatedVigo(),
        args: null);

    public object? ReadErrorCodeProperty() => RequireCreatedVigo().GetType().InvokeMember(
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

public sealed record VigoComMember(string Name, string Kind);

internal static class VigoComTypeInfoReader
{
    public static IReadOnlyList<VigoComMember> ReadPublicMembers(ITypeInfo typeInfo)
    {
        var members = new List<VigoComMember>();
        typeInfo.GetTypeAttr(out var typeAttributePointer);
        try
        {
            var typeAttribute = Marshal.PtrToStructure<TYPEATTR>(typeAttributePointer);
            for (var index = 0; index < typeAttribute.cFuncs; index++)
            {
                typeInfo.GetFuncDesc(index, out var functionPointer);
                try
                {
                    var function = Marshal.PtrToStructure<FUNCDESC>(functionPointer);
                    members.Add(new VigoComMember(
                        GetMemberName(typeInfo, function.memid),
                        function.invkind.ToString()));
                }
                finally
                {
                    typeInfo.ReleaseFuncDesc(functionPointer);
                }
            }

            for (var index = 0; index < typeAttribute.cVars; index++)
            {
                typeInfo.GetVarDesc(index, out var variablePointer);
                try
                {
                    var variable = Marshal.PtrToStructure<VARDESC>(variablePointer);
                    members.Add(new VigoComMember(
                        GetMemberName(typeInfo, variable.memid),
                        "property"));
                }
                finally
                {
                    typeInfo.ReleaseVarDesc(variablePointer);
                }
            }
        }
        finally
        {
            typeInfo.ReleaseTypeAttr(typeAttributePointer);
        }

        return members
            .Where(member => !string.IsNullOrWhiteSpace(member.Name))
            .GroupBy(member => (member.Name, member.Kind), StringTupleComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .OrderBy(member => member.Name, StringComparer.OrdinalIgnoreCase)
            .ThenBy(member => member.Kind, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string GetMemberName(ITypeInfo typeInfo, int memberId)
    {
        typeInfo.GetDocumentation(memberId, out var name, out _, out _, out _);
        return name ?? string.Empty;
    }

    private sealed class StringTupleComparer : IEqualityComparer<(string Name, string Kind)>
    {
        public static readonly StringTupleComparer OrdinalIgnoreCase = new();

        public bool Equals((string Name, string Kind) left, (string Name, string Kind) right) =>
            string.Equals(left.Name, right.Name, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(left.Kind, right.Kind, StringComparison.OrdinalIgnoreCase);

        public int GetHashCode((string Name, string Kind) value) => HashCode.Combine(
            StringComparer.OrdinalIgnoreCase.GetHashCode(value.Name),
            StringComparer.OrdinalIgnoreCase.GetHashCode(value.Kind));
    }
}

[ComImport]
[Guid("00020400-0000-0000-C000-000000000046")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IDispatchTypeInfoSource
{
    [PreserveSig]
    int GetTypeInfoCount(out uint typeInfoCount);

    [PreserveSig]
    int GetTypeInfo(uint index, int localeId, out ITypeInfo typeInfo);
}
