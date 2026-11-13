param([ValidateRange(10,180)][int]$Seconds=90,[ValidateSet('constructor-probe','constructor-tree','constructor-cached')][string]$ProbeName='constructor-probe')
$ErrorActionPreference='Stop'
$probeRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
$nativeRoot='C:\Program Files (x86)\Steam\steamapps\common\Neverwinter Nights'
$nativeExe=Join-Path $nativeRoot 'bin\win32\nwmain.exe'
$expected='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if((Get-FileHash -LiteralPath $nativeExe -Algorithm SHA256).Hash.ToLowerInvariant()-ne$expected){throw 'Original executable identity mismatch'}
if(Get-Process -Name nwmain -ErrorAction SilentlyContinue){throw 'A native client is already running'}
$debugger='C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe'
$captureDirectory='C:\Users\Niflheim\Desktop\Tools\Local Tools\EntireDecomp\godot-client\.cache\native-original-constructor'
New-Item -ItemType Directory -Path $captureDirectory -Force|Out-Null
$output=Join-Path $captureDirectory ($ProbeName+'.log')
$userDirectory='C:\Users\Niflheim\Desktop\Tools\Local Tools\EntireDecomp\godot-client\.cache\native-original-constructor\userdir-probe-win32'
New-Item -ItemType Directory -Path (Split-Path -Parent $userDirectory) -Force|Out-Null
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$debugger
$start.WorkingDirectory=Join-Path $nativeRoot 'bin\win32'
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
foreach($argument in @('-logo',$output,'-cf',(Join-Path $probeRoot ($ProbeName+'.cdb')),$nativeExe,'-userdirectory',$userDirectory)){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
try{
  if(-not $process.WaitForExit($Seconds*1000)){
    $process.Kill($true)
    [void]$process.WaitForExit(5000)
    Write-Warning "Probe exceeded $Seconds seconds; killed its own debugger tree"
  }
}finally{$process.Dispose()}
if(Test-Path -LiteralPath $output){Get-Content -LiteralPath $output -Tail 55}
