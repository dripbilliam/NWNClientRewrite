$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$launcher=Join-Path $project 'join-native.ps1'
$tokens=$null;$errors=$null
$tree=[Management.Automation.Language.Parser]::ParseFile($launcher,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Launcher has parse errors'}
$checks=[Collections.Generic.List[object]]::new()
function Check([string]$Name,[bool]$Passed){$checks.Add(@{name=$Name;passed=$Passed});if(-not$Passed){throw $Name}}
Check 'Launcher AST parses' ($errors.Count-eq0)
$forwarding=@($tree.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Extent.Text -match "ContainsKey\('(PerformanceRuntime|RenderThread|DriveCollision|LightInputRegistry|WorldSnapshotPreparation|DetailedProfiling)'\)"})
Check 'Exactly six owned performance forwarding statements' ($forwarding.Count-eq6)
$body=$tree.ParamBlock.Extent.Text+"`n"+'$nativeStart=[Diagnostics.ProcessStartInfo]::new()'+"`n"+(($forwarding | ForEach-Object {$_.Extent.Text})-join"`n")+"`n"+'return @($nativeStart.ArgumentList)'
$binding=[scriptblock]::Create($body)
$driveParameter=@($tree.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath-eq'DriveCollision'})
Check 'PowerShell default agrees with authoritative indexed policy' ($driveParameter.Count-eq1-and$driveParameter[0].DefaultValue.Value-eq'indexed')
$snapshotParameter=@($tree.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath-eq'WorldSnapshotPreparation'})
Check 'Worker preparation stays script by default before runtime acceptance' ($snapshotParameter.Count-eq1-and$snapshotParameter[0].DefaultValue.Value-eq'script')
Check 'Unspecified new options forward nothing' (@(& $binding).Count-eq0)
$actual=@(& $binding -PerformanceRuntime Verified-Native -RenderThread Separate -DriveCollision Indexed -LightInputRegistry Builtin -WorldSnapshotPreparation Workers -DetailedProfiling Off)
$expected=@('--performance-runtime=verified-native','--render-thread=separate','--drive-collision=indexed','--light-input-registry=builtin','--world-snapshot-preparation=workers','--detailed-profiling=off')
Check 'Real parameter binding and forwarding produce canonical values' (($actual-join'|')-eq($expected-join'|'))
Check 'Explicit script preparation is a canonical rollback option' ((@(& $binding -WorldSnapshotPreparation Script)-join'|')-eq'--world-snapshot-preparation=script')
foreach($name in @('PerformanceRuntime','RenderThread','DriveCollision','LightInputRegistry','WorldSnapshotPreparation','DetailedProfiling')){
 $bindingValues=@{};$bindingValues[$name]='invalid-value';$rejected=$false
 try{$null=& $binding @bindingValues}catch{$rejected=$true}
 Check ('Invalid '+$name+' rejects during binding') $rejected
}
$listing=@($tree.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Extent.Text -match '^if\(\$ListFlags\)'})
Check 'Flag listing exits before native preparation or process launch' ($listing.Count-eq1-and$listing[0].Extent.Text.Contains('return')-and$listing[0].Extent.StartOffset-lt$forwarding[0].Extent.StartOffset)
@{success=$true;checks=$checks;scope='Actual launcher AST, parameter binding and six extracted forwarding statements only. No client, server, build or protected settings access.'}|ConvertTo-Json -Depth 4
