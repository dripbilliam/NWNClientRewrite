param([Parameter(Mandatory)][string]$Report)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../tools/native-creation-owned-identity.ps1')
$now=[DateTime]::UtcNow;$runtime='C:\owned\Godot.exe';$reportPath='C:\owned\native-creation-smoke.native.json'
$debugger=[pscustomobject]@{ProcessId=10;ExecutablePath='C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe';CommandLine=('cdb --report='+$reportPath);CreationDate=$now.AddSeconds(-3)}
$native=[pscustomobject]@{ProcessId=11;ParentProcessId=10;ExecutablePath=$runtime;CommandLine=('Godot res://native_session_world.gd --report='+$reportPath);CreationDate=$now.AddSeconds(-2)}
$checks=0
Assert-OwnedCreationLaunch -Debugger $debugger -Native $native -ExpectedRuntime $runtime -ReportFile $reportPath -Now $now
$checks++
foreach($fault in @('same-id','wrong-parent','wrong-executable','wrong-report','report-prefix','wrong-script','older-than-parent','late-launch','old-launch','future-launch')){
 $bad=$native.PSObject.Copy()
 switch($fault){
  'same-id'{$bad.ProcessId=10}
  'wrong-parent'{$bad.ParentProcessId=9}
  'wrong-executable'{$bad.ExecutablePath='C:\other\Godot.exe'}
  'wrong-report'{$bad.CommandLine='Godot res://native_session_world.gd --report=another'}
  'report-prefix'{$bad.CommandLine=('Godot res://native_session_world.gd --report='+$reportPath+'.other')}
  'wrong-script'{$bad.CommandLine=('Godot res://other.gd --report='+$reportPath)}
  'older-than-parent'{$bad.CreationDate=$now.AddSeconds(-4)}
  'late-launch'{$bad.CreationDate=$now.AddSeconds(35)}
  'old-launch'{$bad.CreationDate=$now.AddMinutes(-21)}
  'future-launch'{$bad.CreationDate=$now.AddSeconds(1)}
 }
 $rejected=$false
 try{Assert-OwnedCreationLaunch -Debugger $debugger -Native $bad -ExpectedRuntime $runtime -ReportFile $reportPath -Now $now}catch{$rejected=$true}
 if(-not$rejected){throw ('Owned identity accepted '+$fault)}
 $checks++
}
$wrongDebugger=$debugger.PSObject.Copy();$wrongDebugger.ExecutablePath='C:\other\cdb.exe';$rejected=$false
try{Assert-OwnedCreationLaunch -Debugger $wrongDebugger -Native $native -ExpectedRuntime $runtime -ReportFile $reportPath -Now $now}catch{$rejected=$true}
if(-not$rejected){throw 'Owned identity accepted wrong debugger'};$checks++
$result=@{success=$true;checks=$checks;scope='Pure launch evidence validation: process ID/parent/executable/report/script/start-time fences. No process action or credentials.'}
[IO.File]::WriteAllText($Report,($result|ConvertTo-Json)+[Environment]::NewLine)
$result|ConvertTo-Json -Compress
