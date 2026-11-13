param([string]$Report = '.cache/nwn77/static-visual-a/pixel-pairs.json')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$drawingPath = [System.Drawing.Bitmap].Assembly.Location
$gdiPath = Join-Path (Split-Path $drawingPath) 'System.Private.Windows.GdiPlus.dll'
$corePath = Join-Path (Split-Path $drawingPath) 'System.Private.Windows.Core.dll'
$primitivePath = Join-Path (Split-Path $drawingPath) 'System.Drawing.Primitives.dll'
Add-Type -ReferencedAssemblies @($drawingPath,$gdiPath,$corePath,$primitivePath) -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Nwn77SavedPixels {
    static byte[] Read(Bitmap source) {
        using (var bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(bitmap)) graphics.DrawImageUnscaled(source, 0, 0);
            var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var bits = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try { var bytes = new byte[Math.Abs(bits.Stride) * bitmap.Height]; Marshal.Copy(bits.Scan0, bytes, 0, bytes.Length); return bytes; }
            finally { bitmap.UnlockBits(bits); }
        }
    }
    public static string Compare(string left, string right, int x0, int y0, int x1, int y1) {
        using (var a = new Bitmap(left)) using (var b = new Bitmap(right)) {
            if (a.Width != b.Width || a.Height != b.Height) throw new Exception("Image dimensions differ");
            x0 = Math.Max(0, x0); y0 = Math.Max(0, y0); x1 = Math.Min(a.Width, x1); y1 = Math.Min(a.Height, y1);
            var aa = Read(a); var bb = Read(b); long changed = 0, strong = 0, sum = 0, max = 0, pixels = 0;
            var stride = a.Width * 4;
            for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
                int i = y * stride + x * 4;
                int d = Math.Abs(aa[i] - bb[i]) + Math.Abs(aa[i + 1] - bb[i + 1]) + Math.Abs(aa[i + 2] - bb[i + 2]);
                pixels++; sum += d; if (d > 0) changed++; if (d > 24) strong++; if (d > max) max = d;
            }
            return "{\"pixels\":" + pixels + ",\"changed\":" + changed + ",\"strong\":" + strong + ",\"mean_rgb_abs\":" + ((double)sum / (pixels * 3)).ToString("R", System.Globalization.CultureInfo.InvariantCulture) + ",\"max_rgb_sum\":" + max + "}";
        }
    }
    public static string StableModeDifference(string offA, string onA, string onB, string offB, int x1, int y1) {
        using (var a = new Bitmap(offA)) using (var b = new Bitmap(onA)) using (var c = new Bitmap(onB)) using (var d = new Bitmap(offB)) {
            if (a.Width != b.Width || a.Width != c.Width || a.Width != d.Width || a.Height != b.Height || a.Height != c.Height || a.Height != d.Height) throw new Exception("Image dimensions differ");
            var aa = Read(a); var bb = Read(b); var cc = Read(c); var dd = Read(d);
            long candidates = 0, stable = 0, modeSpecific = 0; int minX = a.Width, minY = a.Height, maxX = -1, maxY = -1;
            var cells = new int[750];
            for (int y = 0; y < Math.Min(a.Height,y1); y++) for (int x = 0; x < Math.Min(a.Width,x1); x++) {
                int i = (y * a.Width + x) * 4, withinOff = 0, withinOn = 0, across = 0;
                for (int channel = 0; channel < 3; channel++) {
                    withinOff += Math.Abs(aa[i+channel] - dd[i+channel]);
                    withinOn += Math.Abs(bb[i+channel] - cc[i+channel]);
                    across += Math.Abs((aa[i+channel] + dd[i+channel]) - (bb[i+channel] + cc[i+channel])) / 2;
                }
                candidates++;
                if (withinOff <= 8 && withinOn <= 8) { stable++; if (across > 24) { modeSpecific++; minX=Math.Min(minX,x);minY=Math.Min(minY,y);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y); cells[(y/64)*50+x/64]++; } }
            }
            var top = "["; for(int j=0;j<10;j++) {int best=-1;for(int k=0;k<cells.Length;k++)if(cells[k]>0&&(best<0||cells[k]>cells[best]))best=k;if(best<0)break;if(j>0)top+=",";top+="[\""+(best%50)+":"+(best/50)+"\","+cells[best]+"]";cells[best]=0;} top+="]";
            return "{\"pixels\":" + candidates + ",\"stable\":" + stable + ",\"mode_specific\":" + modeSpecific + ",\"bounds\":[" + minX + "," + minY + "," + maxX + "," + maxY + "],\"top_64px_cells\":"+top+"}";
        }
    }
}
'@
$root = (Resolve-Path '.').Path
$runs = @('1-off','2-on','3-on','4-off')
$pairs = @(@(0,3),@(1,2),@(0,1),@(3,2),@(0,2),@(3,1))
$rows = @()
foreach ($suffix in @('native.ready.png','native.png')) {
    foreach ($pair in $pairs) {
        $left = Join-Path $root ('reports/nwn77-current-static-a-' + $runs[$pair[0]] + '.' + $suffix)
        $right = Join-Path $root ('reports/nwn77-current-static-a-' + $runs[$pair[1]] + '.' + $suffix)
        $whole = [Nwn77SavedPixels]::Compare($left,$right,0,0,3440,1369) | ConvertFrom-Json
        $world = [Nwn77SavedPixels]::Compare($left,$right,0,0,3200,950) | ConvertFrom-Json
        $rows += [pscustomobject]@{left=$runs[$pair[0]];right=$runs[$pair[1]];image=$suffix;whole=$whole;world=$world}
    }
}
$parent = Split-Path -Parent $Report
New-Item -ItemType Directory -Force $parent | Out-Null
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Report
$modeRows = @()
foreach ($suffix in @('native.ready.png','native.png')) {
    $images = $runs | ForEach-Object { Join-Path $root ('reports/nwn77-current-static-a-' + $_ + '.' + $suffix) }
    $modeRows += [pscustomobject]@{image=$suffix;world=([Nwn77SavedPixels]::StableModeDifference($images[0],$images[1],$images[2],$images[3],3200,950) | ConvertFrom-Json)}
}
$modeRows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ([System.IO.Path]::ChangeExtension($Report,'.mode.json'))
$rows | Select-Object image,left,right,@{n='world_changed';e={$_.world.changed}},@{n='world_mean_rgb_abs';e={$_.world.mean_rgb_abs}} | Format-Table -AutoSize
$modeRows | Format-Table -AutoSize
