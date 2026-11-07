using System.Net.Sockets;

namespace Fjellfisk.VaconMonitor;

public sealed record VaconInputRegisterSnapshot(
    DateTimeOffset ObservedAtUtc,
    decimal ActualFrequencyHz,
    ushort? MotorSpeedRaw = null,
    decimal? MotorCurrentAmperes = null,
    VaconDriveStatus DriveStatus = VaconDriveStatus.Unknown,
    VaconActiveFault? ActiveFault = null,
    VaconStatusWord? StatusWord = null,
    ushort? MotorCurrentRaw = null,
    bool MotorCurrentScaleVerified = false,
    decimal? TargetFrequencyHz = null);

public interface IVaconReadOnlyClient
{
    Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken);
}

public interface IVaconModbusTransport
{
    Task<byte[]> ExchangeAsync(byte[] request, CancellationToken cancellationToken);
}

public sealed class VaconReadException : Exception
{
    public VaconReadException(string category)
        : base(category)
    {
        Category = category;
    }

    public string Category { get; }
}

/// <summary>
/// A deliberately narrow Modbus client. It only forms FC04 input-register
/// requests for the compiled VACON process-data output block.
/// </summary>
public sealed class VaconReadOnlyModbusClient : IVaconReadOnlyClient
{
    private const byte ReadInputRegistersFunction = 0x04;
    private readonly VaconMonitorOptions _options;
    private readonly IVaconModbusTransport _transport;
    private int _transactionSequence;

    public VaconReadOnlyModbusClient(VaconMonitorOptions options, IVaconModbusTransport transport)
    {
        if (options.UnitId == 0)
        {
            throw new ArgumentException("Modbus Unit ID 0 is not supported.", nameof(options));
        }

        _options = options;
        _transport = transport;
    }

    public async Task<VaconInputRegisterSnapshot> ReadAsync(CancellationToken cancellationToken)
    {
        var transactionId = unchecked((ushort)Interlocked.Increment(ref _transactionSequence));
        var request = BuildReadInputRegisterRequest(transactionId, _options.UnitId);
        var response = await _transport.ExchangeAsync(request, cancellationToken).ConfigureAwait(false);
        var registers = ParseReadInputRegisterResponse(response, transactionId, _options.UnitId);
        return VaconProcessDataMapper.Map(registers, DateTimeOffset.UtcNow);
    }

    public static byte[] BuildReadInputRegisterRequest(ushort transactionId, byte unitId)
    {
        if (unitId == 0)
        {
            throw new ArgumentOutOfRangeException(nameof(unitId), "Modbus Unit ID 0 is not supported.");
        }

        var request = new byte[12];
        WriteUInt16(request, 0, transactionId);
        WriteUInt16(request, 2, 0);
        WriteUInt16(request, 4, 6);
        request[6] = unitId;
        request[7] = ReadInputRegistersFunction;
        WriteUInt16(request, 8, VaconReadOnlyRegisterMap.FirstPduAddress);
        WriteUInt16(request, 10, VaconReadOnlyRegisterMap.InputRegisterCount);
        return request;
    }

    public static ushort[] ParseReadInputRegisterResponse(byte[] response, ushort expectedTransactionId, byte expectedUnitId)
    {
        if (response.Length < 9)
        {
            throw new VaconReadException("invalid-read");
        }

        var transactionId = ReadUInt16(response, 0);
        var protocolId = ReadUInt16(response, 2);
        var length = ReadUInt16(response, 4);

        if (transactionId != expectedTransactionId || protocolId != 0 || response.Length != length + 6 || response[6] != expectedUnitId)
        {
            throw new VaconReadException("invalid-read");
        }

        if (response[7] == (ReadInputRegistersFunction | 0x80))
        {
            throw new VaconReadException("modbus-error");
        }

        if (response[7] != ReadInputRegistersFunction || response[8] != VaconReadOnlyRegisterMap.InputRegisterCount * 2)
        {
            throw new VaconReadException("invalid-read");
        }

        var expectedLength = 9 + response[8];
        if (response.Length != expectedLength)
        {
            throw new VaconReadException("invalid-read");
        }

        var registers = new ushort[VaconReadOnlyRegisterMap.InputRegisterCount];
        for (var index = 0; index < registers.Length; index++)
        {
            registers[index] = ReadUInt16(response, 9 + (index * 2));
        }

        return registers;
    }

    private static ushort ReadUInt16(byte[] bytes, int offset) =>
        (ushort)((bytes[offset] << 8) | bytes[offset + 1]);

    private static void WriteUInt16(byte[] bytes, int offset, ushort value)
    {
        bytes[offset] = (byte)(value >> 8);
        bytes[offset + 1] = (byte)value;
    }
}

public sealed class TcpVaconModbusTransport : IVaconModbusTransport
{
    private readonly VaconMonitorOptions _options;

    public TcpVaconModbusTransport(VaconMonitorOptions options)
    {
        _options = options;
    }

    public async Task<byte[]> ExchangeAsync(byte[] request, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(_options.ReadTimeout);

        try
        {
            using var client = new TcpClient();
            await client.ConnectAsync(_options.Host, _options.Port).WaitAsync(timeout.Token).ConfigureAwait(false);
            using var stream = client.GetStream();
            await stream.WriteAsync(request.AsMemory(), timeout.Token).ConfigureAwait(false);

            var header = new byte[7];
            await ReadExactlyAsync(stream, header, timeout.Token).ConfigureAwait(false);
            var length = (ushort)((header[4] << 8) | header[5]);

            if (length < 2 || length > 253)
            {
                throw new VaconReadException("invalid-read");
            }

            var remainder = new byte[length - 1];
            await ReadExactlyAsync(stream, remainder, timeout.Token).ConfigureAwait(false);
            return header.Concat(remainder).ToArray();
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new VaconReadException("timeout");
        }
        catch (VaconReadException)
        {
            throw;
        }
        catch (SocketException)
        {
            throw new VaconReadException("com-error");
        }
        catch (IOException)
        {
            throw new VaconReadException("read-error");
        }
    }

    private static async Task ReadExactlyAsync(NetworkStream stream, byte[] destination, CancellationToken cancellationToken)
    {
        var offset = 0;
        while (offset < destination.Length)
        {
            var read = await stream.ReadAsync(destination.AsMemory(offset), cancellationToken).ConfigureAwait(false);
            if (read == 0)
            {
                throw new VaconReadException("read-error");
            }

            offset += read;
        }
    }
}

