using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

// Tiny desktop entry point. The adjacent launch-target.txt lists node,
// the reviewed JS launcher, and its private session config, one per line.
// Starting this executable from the desktop keeps the game on that desktop.
internal static class InteractiveTracyLauncher
{
    [STAThread]
    private static void Main()
    {
        string directory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string[] lines = File.ReadAllLines(Path.Combine(directory, "launch-target.txt"));
        if (lines.Length != 3) throw new InvalidDataException("Expected exactly three launch paths");
        var start = new ProcessStartInfo(lines[0]);
        start.Arguments = Quote(lines[1]) + " " + Quote(lines[2]) + " --disable-electron-gpu";
        start.WorkingDirectory = Path.GetDirectoryName(lines[1]);
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        Process.Start(start);
    }

    private static string Quote(string value)
    {
        if (value.IndexOf('"') >= 0) throw new InvalidDataException("Unexpected quote in launch path");
        return "\"" + value + "\"";
    }
}
