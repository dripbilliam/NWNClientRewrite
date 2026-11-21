param(
    [Parameter(Mandatory)][string]$Repository,
    [string]$LogDirectory=''
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $Repository).Path
$descriptor=Get-Content -LiteralPath (Join-Path $root 'descriptor.json') -Raw | ConvertFrom-Json
if($descriptor.format -ne 'dense-local-nwsync-v1' -or $descriptor.manifestHash -cnotmatch '^[a-f0-9]{40}$'){throw 'Invalid benchmark NWSync descriptor'}
$baseUri=[uri]$descriptor.url
if($baseUri.Scheme -cne 'http' -or $baseUri.Host -cne '127.0.0.1' -or $baseUri.PathAndQuery -cne '/' -or $baseUri.Fragment -or $baseUri.UserInfo){throw 'Benchmark NWSync must use IPv4 loopback HTTP'}
$manifest=Join-Path $root 'manifest.bin'
if((Get-FileHash -LiteralPath $manifest -Algorithm SHA1).Hash -ine $descriptor.manifestHash){throw 'Benchmark manifest digest differs'}
$routes=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$routes.Add('/manifests/'+$descriptor.manifestHash,$manifest)
foreach($entry in $descriptor.entries){
    $hash=[string]$entry.hash
    if($hash -cnotmatch '^[a-f0-9]{40}$'){throw 'Invalid benchmark NWSync resource digest'}
    $route='/data/sha1/'+$hash.Substring(0,2)+'/'+$hash.Substring(2,2)+'/'+$hash
    if($routes.ContainsKey($route)){continue}
    $blob=Get-Item -LiteralPath (Join-Path $root ('blobs/'+$hash+'.bin'))
    if($blob.PSIsContainer -or $blob.Length -ne $entry.blobBytes){throw "Benchmark resource bytes differ: $hash"}
    $routes.Add($route,$blob.FullName)
}
if($routes.Count -ne $descriptor.expectedColdRequests){throw 'Benchmark NWSync route count differs'}
$logs=$root
if($LogDirectory){
    $logs=[IO.Path]::GetFullPath($LogDirectory)
    if(Test-Path -LiteralPath $logs){throw 'NWSync log directory already exists'}
    New-Item -ItemType Directory -Path $logs | Out-Null
}

# Match the parallel HTTP requests of the production client. The server
# accepts only manifest and blob paths listed in the authored descriptor.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public static class DenseWorldNwSyncHttp
{
    public static void Listen(int port, Dictionary<string, string> routes, string root, int pid)
    {
        var listener = new TcpListener(IPAddress.Loopback, port);
        var workers = new SemaphoreSlim(16);
        var logLock = new object();
        var log = Path.Combine(root, "requests.jsonl");
        var ready = Path.Combine(root, "ready.json");
        listener.Start();
        try
        {
            var temporaryReady = ready + "." + pid + ".tmp";
            File.WriteAllText(temporaryReady, $"{{\"pid\":{pid},\"port\":{port}}}");
            File.Move(temporaryReady, ready, true);
            while (true)
            {
                workers.Wait();
                var client = listener.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(_ => {
                    try { Reply(client, routes, log, logLock); }
                    finally { workers.Release(); }
                });
            }
        }
        finally { listener.Stop(); }
    }

    static void Reply(TcpClient client, Dictionary<string, string> routes, string log, object logLock)
    {
        var watch = Stopwatch.StartNew();
        int status = 400;
        long bytes = 0;
        bool completed = false;
        string route = "";
        try
        {
            using (client)
            {
                client.ReceiveTimeout = 5000;
                client.SendTimeout = 10000;
                using var stream = client.GetStream();
                using var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true);
                var request = reader.ReadLine()?.Split(' ');
                if (request == null) return;
                for (int count = 0; count < 100; count++)
                {
                    var line = reader.ReadLine();
                    if (string.IsNullOrEmpty(line)) break;
                    if (line.Length > 8192 || count == 99) return;
                }
                string path = null;
                if (request.Length == 3 && request[0] == "GET") routes.TryGetValue(request[1], out path);
                if (path != null) route = request[1];
                status = path == null ? 404 : 200;
                using var source = path == null ? null : File.OpenRead(path);
                bytes = source == null ? 0 : source.Length;
                var result = status == 200 ? "200 OK" : "404 Not Found";
                var header = Encoding.ASCII.GetBytes($"HTTP/1.1 {result}\r\nContent-Length: {bytes}\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n\r\n");
                stream.Write(header);
                if (source != null) source.CopyTo(stream);
                completed = true;
            }
        }
        catch (IOException) { }
        catch (SocketException) { }
        finally
        {
            var success = completed ? "true" : "false";
            var row = $"{{\"route\":\"{route}\",\"status\":{status},\"completed\":{success},\"bytes\":{bytes},\"durationMs\":{watch.ElapsedMilliseconds}}}\n";
            lock (logLock) File.AppendAllText(log, row);
        }
    }
}
'@

[DenseWorldNwSyncHttp]::Listen($baseUri.Port,$routes,$logs,$PID)
