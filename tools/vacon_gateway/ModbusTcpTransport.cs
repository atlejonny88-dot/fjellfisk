using System.Buffers.Binary;
using System.Net.Sockets;
using System.Threading;

namespace Fjellfisk.Vacon;

/// <summary>
/// Low-level Modbus/TCP transport ONLY: no VACON register map or safety logic.
/// This is not a command executor. Callers MUST enforce independent
/// authorization, fieldbus readiness, safe Hz range, local interlocks,
/// timeouts, single-execution and readback before any write.
/// </summary>
public sealed class ModbusTcpTransport
{
    private readonly string _host;
    private readonly int _port;
    private readonly byte _unitId;
    private int _transactionId;

    public ModbusTcpTransport(string host, int port = 502, byte unitId = 1)
    {
        if (string.IsNullOrWhiteSpace(host)) throw new ArgumentException("Missing host", nameof(host));
        if (port is < 1 or > 65535) throw new ArgumentOutOfRangeException(nameof(port));
        _host = host;
        _port = port;
        _unitId = unitId;
    }

    public async Task<ushort[]> ReadHoldingRegistersAsync(
        ushort zeroBasedAddress, ushort count, CancellationToken ct = default)
    {
        if (count is < 1 or > 125) throw new ArgumentOutOfRangeException(nameof(count));
        var payload = new byte[4];
        BinaryPrimitives.WriteUInt16BigEndian(payload.AsSpan(0, 2), zeroBasedAddress);
        BinaryPrimitives.WriteUInt16BigEndian(payload.AsSpan(2, 2), count);
        var pdu = await ExchangeAsync(3, payload, ct).ConfigureAwait(false);
        if (pdu.Length != 2 + count * 2 || pdu[1] != count * 2)
            throw new IOException("Unexpected register response length.");
        var result = new ushort[count];
        for (int i = 0; i < count; i++)
            result[i] = BinaryPrimitives.ReadUInt16BigEndian(pdu.AsSpan(2 + i * 2, 2));
        return result;
    }

    // Exposed for a future model-specific, verified command executor.
    // NEVER use register addresses from the mobile/web client.
    public async Task WriteSingleRegisterAsync(
        ushort zeroBasedAddress, ushort value, CancellationToken ct = default)
    {
        var payload = new byte[4];
        BinaryPrimitives.WriteUInt16BigEndian(payload.AsSpan(0, 2), zeroBasedAddress);
        BinaryPrimitives.WriteUInt16BigEndian(payload.AsSpan(2, 2), value);
        var pdu = await ExchangeAsync(6, payload, ct).ConfigureAwait(false);
        if (pdu.Length != 5 || !pdu.AsSpan(1, 4).SequenceEqual(payload))
            throw new IOException("Modbus write echo verification failed.");
        // Echo verification is NOT confirmation that the motor responded.
        // Model-specific status/readback must confirm the physical action.
    }

    private async Task<byte[]> ExchangeAsync(byte function, byte[] data, CancellationToken ct)
    {
        var transactionId = unchecked((ushort)Interlocked.Increment(ref _transactionId));
        var message = new byte[8 + data.Length];
        BinaryPrimitives.WriteUInt16BigEndian(message.AsSpan(0, 2), transactionId);
        // Protocol identifier (bytes 2/3) remains zero.
        BinaryPrimitives.WriteUInt16BigEndian(message.AsSpan(4, 2), (ushort)(2 + data.Length));
        message[6] = _unitId;
        message[7] = function;
        data.CopyTo(message, 8);

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(4));
        using var client = new TcpClient();
        await client.ConnectAsync(_host, _port, timeout.Token).ConfigureAwait(false);
        using var stream = client.GetStream();
        await stream.WriteAsync(message.AsMemory(), timeout.Token).ConfigureAwait(false);

        var header = new byte[7];
        await ReadFullAsync(stream, header, timeout.Token).ConfigureAwait(false);
        if (BinaryPrimitives.ReadUInt16BigEndian(header.AsSpan(0, 2)) != transactionId ||
            BinaryPrimitives.ReadUInt16BigEndian(header.AsSpan(2, 2)) != 0 ||
            header[6] != _unitId)
            throw new IOException("Mismatched Modbus response header.");

        var length = BinaryPrimitives.ReadUInt16BigEndian(header.AsSpan(4, 2));
        if (length is < 2 or > 254)
            throw new IOException("Invalid Modbus frame length.");

        var pdu = new byte[length - 1];
        await ReadFullAsync(stream, pdu, timeout.Token).ConfigureAwait(false);
        if (pdu[0] == (byte)(function | 0x80))
            throw new IOException("Modbus exception " + (pdu.Length > 1 ? pdu[1] : 0));
        if (pdu[0] != function)
            throw new IOException("Unexpected Modbus function response.");
        return pdu;
    }

    private static async Task ReadFullAsync(Stream stream, byte[] bytes, CancellationToken ct)
    {
        var offset = 0;
        while (offset < bytes.Length)
        {
            var read = await stream.ReadAsync(bytes.AsMemory(offset), ct).ConfigureAwait(false);
            if (read == 0) throw new EndOfStreamException("Modbus connection closed early.");
            offset += read;
        }
    }
}
