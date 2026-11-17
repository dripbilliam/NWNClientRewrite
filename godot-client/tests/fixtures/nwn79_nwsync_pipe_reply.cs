// Test-only process-pipe peer for Godot's native NWSync reader. Build with the
// Windows .NET Framework csc.exe into an isolated scratch directory.
using System;
using System.IO;
using System.Threading;

internal static class Nwn79NwsyncPipeReply
{
    private static bool ReadExactly(Stream stream, byte[] bytes)
    {
        int offset = 0;
        while (offset < bytes.Length)
        {
            int count = stream.Read(bytes, offset, bytes.Length - offset);
            if (count <= 0) return false;
            offset += count;
        }
        return true;
    }

    private static int Main(string[] args)
    {
        if (args.Length != 1) return 2;
        string mode = Path.GetFileName(args[0].TrimEnd(Path.DirectorySeparatorChar));
        if (mode != "normal" && mode != "surplus") return 2;
        Stream input = Console.OpenStandardInput();
        byte[] header = new byte[5];
        if (!ReadExactly(input, header)) return 3;
        int length = BitConverter.ToInt32(header, 0);
        if (length < 1 || length > 41 || header[4] != 2) return 4;
        byte[] payload = new byte[length - 1];
        if (!ReadExactly(input, payload)) return 5;
        // One OS write contains a complete reply and, in surplus mode, a byte
        // beyond its declared two-byte body. Do not send text to stdout.
        byte[] reply = mode == "surplus"
            ? new byte[] { 2, 0, 0, 0, 0, 23, 99 }
            : new byte[] { 2, 0, 0, 0, 0, 23 };
        Stream output = Console.OpenStandardOutput();
        output.Write(reply, 0, reply.Length);
        output.Flush();
        Thread.Sleep(1000); // Keep the pipe alive until the reader closes it.
        return 0;
    }
}
