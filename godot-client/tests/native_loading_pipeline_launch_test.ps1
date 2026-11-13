$ErrorActionPreference='Stop'
$file=Join-Path $PSScriptRoot '../join-native.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile([IO.Path]::GetFullPath($file),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ('Launcher syntax errors: '+$errors.Count)}
$source=[IO.File]::ReadAllText([IO.Path]::GetFullPath($file))
$checks=[Collections.Generic.List[object]]::new()
function Check([string]$name,[scriptblock]$body){try{& $body;$checks.Add(@{name=$name;passed=$true})}catch{$checks.Add(@{name=$name;passed=$false;error=$_.Exception.Message})}}
function Assert([bool]$condition,[string]$message){if(-not$condition){throw $message}}
# Reuse only the actual parsed parameter declarations: no launcher body runs.
$bind=[scriptblock]::Create($ast.ParamBlock.Extent.Text+"`nreturn @{LoadingPipeline=`$LoadingPipeline;SharedAnimationPreparation=[bool]`$SharedAnimationPreparation;NativeDrawCache=[bool]`$NativeDrawCache;NativeCacheGiB=`$NativeCacheGiB}")
function Reject-Binding([hashtable]$values){$rejected=$false;try{& $bind @values|Out-Null}catch{$rejected=$true};Assert $rejected 'Invalid option was not rejected by launcher binding'}
Check 'PowerShell AST has no parse errors' {Assert ($errors.Count-eq0) 'Parse failed'}
Check 'Default binding is ordinary with independent options off' {$r=& $bind;Assert ($r.LoadingPipeline-eq'ordinary'-and-not$r.SharedAnimationPreparation-and-not$r.NativeDrawCache-and$r.NativeCacheGiB-eq25) 'Defaults changed'}
Check 'Streamed and merged binding available' {foreach($mode in @('ordinary','streamed','merged')){$r=& $bind -LoadingPipeline $mode;Assert ($r.LoadingPipeline-eq$mode) 'Pipeline binding differed'}}
Check 'Cache lower and upper boundaries available' {foreach($budget in @(25,1024)){$r=& $bind -NativeDrawCache -NativeCacheGiB $budget;Assert ($r.NativeCacheGiB-eq$budget-and$r.NativeDrawCache) 'Budget binding differed'}}
foreach($budget in @(0,24,1025,-25,'nope','25.0','25.5','025','1e2',' 25','25 ')){Check ('Invalid budget binding rejects '+$budget) {Reject-Binding @{NativeDrawCache=$true;NativeCacheGiB=$budget}}}
Check 'Invalid pipeline binding rejects' {Reject-Binding @{LoadingPipeline='bad'}}
Check 'Explicit disabled-cache budget rejects before build/process paths' {
 $guard=$ast.EndBlock.Statements|Where-Object{$_.Extent.Text -like "if(`$PSBoundParameters.ContainsKey('NativeCacheGiB')*"}|Select-Object -First 1
 Assert ($null-ne$guard) 'Explicit budget guard missing'
 Assert ($guard.Extent.StartOffset-lt$source.IndexOf('$nativeRoot=')) 'Guard follows launcher work'
 $probe=[scriptblock]::Create($ast.ParamBlock.Extent.Text+"`n"+$guard.Extent.Text)
 $rejected=$false;try{& $probe -NativeCacheGiB 25}catch{$rejected=$_.Exception.Message-eq'NativeCacheGiB requires NativeDrawCache'}
 Assert $rejected 'Explicit disabled-cache budget accepted'
 & $probe -NativeDrawCache -NativeCacheGiB 25
 & $probe
}
Check 'Actual PowerShell forwarding block emits canonical options only' {
 $seams=@("if(`$PSBoundParameters.ContainsKey('LoadingPipeline'))*","if(`$SharedAnimationPreparation)*","if(`$NativeDrawCache)*","if(`$PSBoundParameters.ContainsKey('NativeCacheGiB'))*")
 $statements=foreach($seam in $seams){$found=@($ast.EndBlock.Statements|Where-Object{$_.Extent.Text -like $seam});Assert ($found.Count-eq1) 'Forwarding seam is not unique';$found[0].Extent.Text}
 $block=[scriptblock]::Create($ast.ParamBlock.Extent.Text+"`n`$nativeStart=[pscustomobject]@{ArgumentList=[Collections.Generic.List[string]]::new()}`n"+($statements -join "`n")+"`nreturn ,`$nativeStart.ArgumentList.ToArray()")
 $defaults=& $block;Assert ($defaults.Count-eq0) 'Implicit defaults emit arguments'
 $r=& $block -LoadingPipeline MeRgEd -SharedAnimationPreparation -NativeDrawCache -NativeCacheGiB 64
 Assert (($r -join '|')-ceq'--loading-pipeline=merged|--shared-animation-preparation=true|--native-draw-cache=prepared|--native-draw-cache-gib=64') 'Forwarded options differ'
}
$result=@{success=@($checks|Where-Object{-not$_.passed}).Count-eq0;checks=@($checks);scope='Only PowerShell AST, parameter binding and isolated extracted forwarding statements; no launcher/client/build/server runs'}
$result|ConvertTo-Json -Depth 4
if(-not$result.success){exit 1}
