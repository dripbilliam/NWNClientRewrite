[CmdletBinding()]
param([Parameter(Mandatory)][int]$DebuggerProcessId,[Parameter(Mandatory)][string]$NativeExecutable,[Parameter(Mandatory)][string]$ReportFile,[Parameter(Mandatory)][string]$Output,[switch]$ObserveOnly)
$ErrorActionPreference='Stop'
$debugRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$expectedRuntime=Join-Path $debugRoot '.tools/Godot_v4.7.2-stable_win64.exe'
$expectedReports=[IO.Path]::GetFullPath((Join-Path $debugRoot 'reports'))+[IO.Path]::DirectorySeparatorChar
if([IO.Path]::GetFullPath($NativeExecutable)-ne$expectedRuntime-or-not[IO.Path]::GetFullPath($ReportFile).StartsWith($expectedReports)-or-not[IO.Path]::GetFullPath($Output).StartsWith($expectedReports)-or[IO.Path]::GetFileName($ReportFile)-notmatch'^native-creation-[a-z0-9-]+\.native\.json$'-or(Test-Path -LiteralPath $Output)){throw 'Owned diagnostic paths differ or evidence exists'}
$debugger=Get-CimInstance Win32_Process -Filter ('ProcessId='+$DebuggerProcessId)
$candidates=@(Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$DebuggerProcessId)|Where-Object{$_.ExecutablePath-eq$expectedRuntime-and$_.CommandLine.Contains('--report='+$ReportFile)-and$_.CommandLine.Contains('res://native_session_world.gd')})
if($candidates.Count-ne1){throw 'Exact owned native child is not unique'}
$native=$candidates[0]
. (Join-Path $PSScriptRoot 'native-creation-owned-identity.ps1')
Assert-OwnedCreationLaunch -Debugger $debugger -Native $native -ExpectedRuntime $expectedRuntime -ReportFile $ReportFile
$cpu=[ordered]@{atUtc=[DateTime]::UtcNow.ToString('o');native=[ordered]@{processId=[int]$native.ProcessId;startedUtc=$native.CreationDate.ToUniversalTime().ToString('o');cpuSeconds=(Get-Process -Id $native.ProcessId).TotalProcessorTime.TotalSeconds};debugger=[ordered]@{processId=[int]$debugger.ProcessId;startedUtc=$debugger.CreationDate.ToUniversalTime().ToString('o');cpuSeconds=(Get-Process -Id $debugger.ProcessId).TotalProcessorTime.TotalSeconds}}
if($ObserveOnly){
 $result=[ordered]@{success=$true;exactLaunchIdentity=$true;observedOnly=$true;breakRequested=$false;cpu=$cpu;privateValuesLogged=$false}
 [IO.File]::WriteAllText($Output,($result|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
 [pscustomobject]$result|ConvertTo-Json -Depth 5 -Compress
 exit 0
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class OwnedCreationDebugBreak {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint id);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool DebugBreakProcess(IntPtr process);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
'@
$handle=[OwnedCreationDebugBreak]::OpenProcess(0x43a,$false,[uint32]$native.ProcessId)
if($handle-eq[IntPtr]::Zero){throw 'Cannot open exact owned native process for diagnostic break'}
try{$requested=[OwnedCreationDebugBreak]::DebugBreakProcess($handle);if(-not$requested){throw 'Owned diagnostic break failed'}}finally{[OwnedCreationDebugBreak]::CloseHandle($handle)|Out-Null}
$result=[ordered]@{success=$true;debuggerProcessId=$DebuggerProcessId;nativeProcessId=$native.ProcessId;exactLaunchIdentity=$true;breakRequested=$true;cpu=$cpu;expectedExistingTrap='bpe prints exception/context/all thread stacks then quits; this diagnostic rejects gameplay acceptance';privateValuesLogged=$false}
[IO.File]::WriteAllText($Output,($result|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
[pscustomobject]$result|ConvertTo-Json -Depth 5 -Compress
