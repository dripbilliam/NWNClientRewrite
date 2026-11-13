param(
  [Parameter(Mandatory=$true)][string]$Off,
  [Parameter(Mandatory=$true)][string]$On
)
$ErrorActionPreference='Stop'
Add-Type -ReferencedAssemblies @((Join-Path $PSHOME 'System.Drawing.Common.dll'),(Join-Path $PSHOME 'System.Drawing.Primitives.dll'),(Join-Path $PSHOME 'System.Private.Windows.GdiPlus.dll'),(Join-Path $PSHOME 'System.Private.Windows.Core.dll'),'System.Runtime') -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Nwn74PngDifference {
 public static string Compare(string aFile,string bFile) {
  using (var a0=new Bitmap(aFile)) using (var b0=new Bitmap(bFile)) {
   if(a0.Width!=b0.Width||a0.Height!=b0.Height) throw new Exception("Screenshot dimensions differ");
   int w=a0.Width,h=a0.Height;
   using(var a=new Bitmap(w,h,PixelFormat.Format32bppArgb)) using(var b=new Bitmap(w,h,PixelFormat.Format32bppArgb)) {
    using(var g=Graphics.FromImage(a))g.DrawImageUnscaled(a0,0,0);
    using(var g=Graphics.FromImage(b))g.DrawImageUnscaled(b0,0,0);
    var rect=new Rectangle(0,0,w,h);
    var ad=a.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    var bd=b.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    try {
     int n=Math.Abs(ad.Stride)*h;
     var aa=new byte[n];var bb=new byte[n];Marshal.Copy(ad.Scan0,aa,0,n);Marshal.Copy(bd.Scan0,bb,0,n);
     long sum=0,exact=0,within8=0,within24=0;int max=0;long pixels=(long)w*h;
     for(int y=0;y<h;y++)for(int x=0;x<w;x++){
      int i=y*ad.Stride+x*4,j=y*bd.Stride+x*4;
      int d0=Math.Abs(aa[i]-bb[j]),d1=Math.Abs(aa[i+1]-bb[j+1]),d2=Math.Abs(aa[i+2]-bb[j+2]);
      int d=Math.Max(d0,Math.Max(d1,d2));sum+=d0+d1+d2;if(d==0)exact++;if(d<=8)within8++;if(d<=24)within24++;if(d>max)max=d;
     }
     return String.Format(System.Globalization.CultureInfo.InvariantCulture,"{{\"width\":{0},\"height\":{1},\"pixels\":{2},\"exactFraction\":{3:R},\"within8Fraction\":{4:R},\"within24Fraction\":{5:R},\"meanAbsoluteChannelError\":{6:R},\"maxChannelError\":{7}}}",w,h,pixels,(double)exact/pixels,(double)within8/pixels,(double)within24/pixels,(double)sum/(pixels*3),max);
    } finally {a.UnlockBits(ad);b.UnlockBits(bd);}
   }
  }
 }
}
'@
[Nwn74PngDifference]::Compare((Resolve-Path -LiteralPath $Off).Path,(Resolve-Path -LiteralPath $On).Path)
