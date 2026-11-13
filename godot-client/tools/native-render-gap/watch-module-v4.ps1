param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,[Parameter(Mandatory=$true)][string]$Selection,[Parameter(Mandatory=$true)][string]$SelectionSha256)
$ErrorActionPreference='Stop'
$particleProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if((Get-FileHash -LiteralPath $Selection).Hash.ToLowerInvariant()-ne$SelectionSha256){throw 'Private selection changed'}
$particleSelection=Get-Content -Raw -LiteralPath $Selection | ConvertFrom-Json
$particleExpected=$particleSelection.particleLoop.module
$particleNeedle=('--report='+(Join-Path $particleProject ('reports/'+$Run+'.native.json'))).Replace('/','\')
$particleClock=[Diagnostics.Stopwatch]::StartNew();$particleResult=$null
while($particleClock.Elapsed.TotalSeconds-lt30-and-not$particleResult){
 foreach($particleProcess in Get-CimInstance Win32_Process -Filter "Name = 'godot.windows.template_release.x86_64.exe'"){
  $particleLine=([string]$particleProcess.CommandLine).Replace('/','\');$particleOffset=$particleLine.IndexOf($particleNeedle,[StringComparison]::OrdinalIgnoreCase)
  if($particleOffset-lt0){continue};$particleAfter=$particleOffset+$particleNeedle.Length
  if(($particleOffset-gt0-and$particleLine[$particleOffset-1]-ne'"'-and-not[char]::IsWhiteSpace($particleLine[$particleOffset-1]))-or($particleAfter-lt$particleLine.Length-and$particleLine[$particleAfter]-ne'"'-and-not[char]::IsWhiteSpace($particleLine[$particleAfter]))){continue}
  $particleClient=[Diagnostics.Process]::GetProcessById([int]$particleProcess.ProcessId)
  $particleCreated=$particleClient.StartTime.ToUniversalTime().ToFileTimeUtc()
  $particleCimEngine=[string]$particleProcess.ExecutablePath
  $particleObservedEngine=[string]$particleClient.MainModule.FileName
  if($particleCimEngine-and$particleCimEngine-ne$particleObservedEngine){throw 'CIM and actual loaded executable paths disagree'}
  $particleObservedHash=if($particleObservedEngine){(Get-FileHash -LiteralPath $particleObservedEngine).Hash.ToLowerInvariant()}else{$null}
  if($particleObservedEngine-ne$particleSelection.engine-or$particleObservedHash-ne$particleSelection.runtime.executableSha256){
   $particleRejection=@{success=$false;run=$Run;processId=$particleProcess.ProcessId;observedEngine=$particleObservedEngine;observedHash=$particleObservedHash;expectedEngine=$particleSelection.engine;expectedHash=$particleSelection.runtime.executableSha256;observedAt=[DateTimeOffset]::UtcNow.ToString('o');scope='Exact report-argument-matched process only; original provenance gate retained'}
   $particleRejection | ConvertTo-Json -Compress | Write-Output
   [IO.File]::WriteAllText((Join-Path $particleProject ('reports/'+$Run+'.particle-module-rejection.json')),($particleRejection|ConvertTo-Json -Depth 5))
   throw 'Matched engine provenance differs (exact rejection details retained)'
  }
  $particleModules=@($particleClient.Modules | Where-Object ModuleName -eq 'nwn-particle-kernel.dll')
  if($particleModules.Count-eq0){continue};if($particleModules.Count-ne1){throw 'Unexpected duplicate particle modules'}
  $particleActual=[IO.Path]::GetFullPath($particleModules[0].FileName)
  if($particleActual-ne$particleExpected.file-or(Get-FileHash -LiteralPath $particleActual).Hash.ToLowerInvariant()-ne$particleExpected.sha256){throw 'Actual loaded private particle DLL differs'}
  $particleClient.Refresh();if($particleClient.HasExited-or$particleClient.StartTime.ToUniversalTime().ToFileTimeUtc()-ne$particleCreated-or[string]$particleClient.MainModule.FileName-ne$particleObservedEngine){throw 'Owned process lifetime changed during module observation'}
  $particleResult=@{version=4;success=$true;run=$Run;processId=$particleClient.Id;createdFileTimeUtc=$particleCreated;createdFileTimeUtcExact=$particleCreated.ToString([Globalization.CultureInfo]::InvariantCulture);engine=$particleObservedEngine;cimExecutablePathAvailable=[bool]$particleCimEngine;executableEvidence='Windows Process.MainModule exact loaded executable path/hash, exact CIM report match and stable process creation lifetime';module=$particleActual;sha256=$particleExpected.sha256;selectionSha256=$SelectionSha256;scope='Read-only exact run/engine/process lifetime plus actual Windows loaded DLL path/hash. No unrelated process or module data retained.'};break
 }
 if(-not$particleResult){Start-Sleep -Milliseconds 200}
}
if(-not$particleResult){throw 'No verified live private particle module observed'}
$particleOutput=Join-Path $particleProject ('reports/'+$Run+'.particle-module.json')
$particleStream=[IO.File]::Open($particleOutput,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$particleBytes=[Text.Encoding]::UTF8.GetBytes(($particleResult|ConvertTo-Json -Depth 5)+[Environment]::NewLine);$particleStream.Write($particleBytes,0,$particleBytes.Length)}finally{$particleStream.Dispose()}
$particleResult|ConvertTo-Json -Compress
