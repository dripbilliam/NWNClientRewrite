param([Parameter(Mandatory=$true)][string]$PreparedDirectory)
$ErrorActionPreference='Stop'
$diagProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$diagRoot=[IO.Path]::GetFullPath((Join-Path $diagProject '.cache/pregame-navigation-diagnostics'))
$flowRun=[IO.Path]::GetFullPath($PreparedDirectory)
if(-not$flowRun.StartsWith($diagRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Only an owned prepared diagnostic directory is accepted'}
$diagMeta=Get-Content -LiteralPath (Join-Path $flowRun 'preparation.json') -Raw|ConvertFrom-Json
if($diagMeta.kind-ne'immutable-pregame-teardown-diagnostic'-or$diagMeta.originalChecks-ne24-or$diagMeta.extraWarmCycles-ne2){throw 'Unexpected diagnostic contract'}
$flowCopy=Join-Path $flowRun 'project';$flowProject=$flowCopy
$flowInputs=$diagMeta.inputs;$flowClosure=[Collections.Generic.HashSet[string]]::new()
foreach($relative in $diagMeta.staticClosure){[void]$flowClosure.Add($relative)}
foreach($row in $flowInputs){if((Get-FileHash -LiteralPath (Join-Path $flowCopy $row.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$row.sha256){throw 'Prepared diagnostic bytes changed'}}
$flowHashes=@{};foreach($row in $flowInputs){$flowHashes[$row.path]=$row.sha256}
$Godot=Join-Path $diagProject '.tools/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot; no build/download permitted'}
$Install=[IO.Path]::GetFullPath((Join-Path $diagProject '../../FullDecomp/NwnRootInstall'));$CheckOnly=$false
# Reuse the exact accepted owned-process/file-stream/65s/log-bound harness.
# Its source copy is trusted and pinned; only its diagnostic receipt destination
# and scope text differ. No current production source is executed or accepted.
$diagDriver=Join-Path $diagMeta.sourceRun 'project/tools/test-native-pregame-flow.ps1'
if((Get-FileHash -LiteralPath $diagDriver -Algorithm SHA256).Hash.ToLowerInvariant()-ne$diagMeta.baseDriverSha256){throw 'Accepted driver bytes changed'}
$diagBody=[IO.File]::ReadAllText($diagDriver);$diagStart=$diagBody.IndexOf('[IO.File]::WriteAllText((Join-Path $flowCopy ''project.godot'')')
if($diagStart-lt0){throw 'Accepted driver boundary missing'}
$diagBody=$diagBody.Substring($diagStart)
$diagBody=$diagBody.Replace('if($flowSuccess-and-not$CheckOnly)','if($false)')
$diagScope=[regex]::new("scope='[^']*'");if($diagScope.Matches($diagBody).Count-ne1){throw 'Diagnostic scope boundary differs'}
$diagBody=$diagScope.Replace($diagBody,"diagnosticOnly=`$true;sourceRun=`$diagMeta.sourceRun;featureAccepted=`$false;scope='Immutable accepted24 native flow with fixed timing instrumentation and two extra warm disconnect cycles. All original assertions retained; no current production/performance-fix/GPU acceptance.'",1)
& ([scriptblock]::Create($diagBody))
