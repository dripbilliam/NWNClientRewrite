param(
 [Parameter(Mandatory=$true)][string]$Install,
 [string]$OutputRoot=''
)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path $client -Parent
$installPath=[IO.Path]::GetFullPath($Install)
if(-not(Test-Path -LiteralPath $installPath -PathType Container)){throw 'NWN installation is unavailable'}
$output=if($OutputRoot){[IO.Path]::GetFullPath($OutputRoot)}else{Join-Path $workspace ('.cache/nwn79-resource-install-validation-'+[guid]::NewGuid().ToString('N'))}
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Validation output must be a fresh directory in the workspace outside godot-client'}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$planPath=Join-Path $PSScriptRoot 'resource-install-validation.json'
$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
$cases=@($plan.cases)
if($plan.format -ne 'nwn79-resource-install-validation-v1' -or $cases.Count -ne 12 -or @($cases|Select-Object -Unique).Count -ne $cases.Count){throw 'Resource/install validation manifest is invalid'}
$summary=[ordered]@{format='nwn79-resource-install-validation-v1';scope=$plan.scope;install=$installPath;output=$output;planSha256=(Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant();cases=$cases;step='prepare';passed=$false;pending=@($plan.separateAcceptance)}
$oldAppData=$env:APPDATA
try{
 $isolated=Join-Path $output 'appdata'
 New-Item -ItemType Directory -Path $isolated -Force|Out-Null
 $env:APPDATA=$isolated
 $summary.step='setup'
 & (Join-Path $PSScriptRoot 'setup-godot-client.ps1') -Install $installPath -UserDataDirectory $isolated|Out-Null
 $summary.step='guard'
 & (Join-Path $PSScriptRoot 'check-godot-only.ps1')|Out-Null
 $godot=Join-Path $client '.tools/Godot_v4.7.2-stable_win64_console.exe'
 $summary.engineSha256=(Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant()
 $resourceDll=Join-Path $client '.cache/native-resource-index/nwn-resource-index.dll'
 $summary.resourceIndexSha256=(Get-FileHash -LiteralPath $resourceDll -Algorithm SHA256).Hash.ToLowerInvariant()
 $summary.step='parse'
 $parseLog=Join-Path $output 'direct-check-only.log'
 & $godot --headless --path $client --check-only --script res://native_direct_session_world.gd *> $parseLog
 $parseExit=$LASTEXITCODE
 $parseOutput=Get-Content -LiteralPath $parseLog -Raw
 $parseOutputHasError=[regex]::IsMatch($parseOutput,'(?im)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)')
 $summary.parseExitCode=$parseExit
 $summary.parseOutputHasError=$parseOutputHasError
 if($parseExit -ne 0 -or $parseOutputHasError){throw ('Direct-world Godot parse failed: exit '+$parseExit+', error output '+$parseOutputHasError)}
 $summary.step='runner-gate'
 $runnerGate=Join-Path $output 'runner-gate.json'
 & (Join-Path $PSScriptRoot 'test-focused-tests-runner.ps1') -Scratch (Join-Path $output 'runner-gate-scratch')|Set-Content -LiteralPath $runnerGate -Encoding utf8
 $gate=Get-Content -LiteralPath $runnerGate -Raw|ConvertFrom-Json
 if($gate.passed -ne $true){throw 'Focused runner did not preserve positive and negative exits'}
 $summary.step='focused-cases'
 $focused=Join-Path $output 'focused'
 & (Join-Path $PSScriptRoot 'run-focused-tests.ps1') -Cases $cases -Install $installPath -OutputRoot $focused|Out-Null
 $caseReceipt=Get-Content -LiteralPath (Join-Path $focused 'summary.json') -Raw|ConvertFrom-Json
 if($caseReceipt.passed -ne $true -or @($caseReceipt.cases.PSObject.Properties).Count -ne $cases.Count){throw 'Focused case receipt is incomplete'}
 $summary.focusedReceipt=Join-Path $focused 'summary.json'
 $summary.step='package'
 $package=Join-Path $output 'package'
 & (Join-Path $PSScriptRoot 'build-godot-delivery.ps1') -Install $installPath -Destination $package|Out-Null
 & (Join-Path $PSScriptRoot 'verify-godot-delivery.ps1') -PackageRoot $package -Strict|Out-Null
 $manifest=Join-Path $package 'godot-client/godot-delivery-manifest.json'
 $summary.package=$package
 $summary.packageManifestSha256=(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash.ToLowerInvariant()
 $summary.step='complete';$summary.passed=$true
}catch{
 $summary.error=$_.Exception.Message
 throw
}finally{
 $env:APPDATA=$oldAppData
 [IO.File]::WriteAllText((Join-Path $output 'validation-summary.json'),($summary|ConvertTo-Json -Depth 8))
}
Write-Output ('NWN-79 resource/install validation PASS: '+(Join-Path $output 'validation-summary.json'))
