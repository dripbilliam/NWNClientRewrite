param([Parameter(Mandatory=$true)][string]$Fixture,[ValidatePattern('^[a-z0-9-]{3,80}$')][string]$Run='native-reference-gpu-v1',[string]$Install='')
$ErrorActionPreference='Stop'
$referenceProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not $Install){$Install=[IO.Path]::GetFullPath((Join-Path $referenceProject '../../FullDecomp/NwnRootInstall'))}
$referenceReport=Join-Path $referenceProject ('reports/'+$Run+'.json')
$referenceProof=$referenceReport.Replace('.json','.debugger.json')
$referenceLog=$referenceReport.Replace('.json','.cdb.log')
$referenceCommands=$referenceReport.Replace('.json','.cdb.txt')
foreach($referenceOutput in @($referenceReport,$referenceProof,$referenceLog,$referenceCommands)){if(Test-Path -LiteralPath $referenceOutput){throw 'Reference evidence output already exists'}}
$referenceSources=@('tests/native_model_reference_test.gd')
$referenceSources+=@(& rg --files (Join-Path $referenceProject 'systems') -g '*.gd' | ForEach-Object {[IO.Path]::GetFullPath($_).Substring($referenceProject.Length+1).Replace('\','/')})
$referenceHashes=[ordered]@{}
foreach($referenceSource in $referenceSources){$referenceHashes[$referenceSource]=(Get-FileHash -LiteralPath (Join-Path $referenceProject $referenceSource) -Algorithm SHA256).Hash.ToLowerInvariant()}
$referenceTrap='.echo NATIVE_REFERENCE_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
$referenceSetup=@('av','0xc0000374','0xc0000409','0xc000001d') | ForEach-Object {'sxe -c "'+$referenceTrap+'" '+$_}
$referenceSetup+=@('.echo NATIVE_REFERENCE_ARMED','g')
[IO.File]::WriteAllLines($referenceCommands,$referenceSetup)
$referenceCdb='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
$referenceArgs=@('-hd','-G','-sins','-y',(Join-Path $referenceProject '.tools'),'-logo',$referenceLog,'-cf',$referenceCommands,(Join-Path $referenceProject '.tools/Godot_v4.7.2-stable_win64.exe'),'--path',$referenceProject,'--script','res://tests/native_model_reference_test.gd','--',('--fixture='+[IO.Path]::GetFullPath($Fixture)),('--install='+[IO.Path]::GetFullPath($Install)),('--report='+$referenceReport))
& $referenceCdb @referenceArgs | Out-Null
$referenceExit=$LASTEXITCODE
$referenceText=Get-Content -LiteralPath $referenceLog -Raw
$referenceResult=Get-Content -LiteralPath $referenceReport -Raw | ConvertFrom-Json
$referenceUnchanged=$true
foreach($referenceSource in $referenceSources){if((Get-FileHash -LiteralPath (Join-Path $referenceProject $referenceSource) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$referenceHashes[$referenceSource]){$referenceUnchanged=$false}}
$referenceArmed=$referenceText-match '(?m)^NATIVE_REFERENCE_ARMED\r?$'
$referenceException=$referenceText-match '(?m)^NATIVE_REFERENCE_EXCEPTION\r?$'
$referenceEngineError=$referenceText-match '(?m)SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use'
$referencePassed=$referenceExit-eq 0-and$referenceResult.success-and$referenceArmed-and-not$referenceException-and-not$referenceEngineError-and$referenceUnchanged
$referenceEvidence=[ordered]@{success=$referencePassed;report=$referenceReport;debuggerExit=$referenceExit;normalHeap=$true;exceptionTraps=4;armed=$referenceArmed;exception=$referenceException;engineOrLifetimeError=$referenceEngineError;sourceUnchanged=$referenceUnchanged;sourceSha256=$referenceHashes;fixtureSha256=(Get-FileHash -LiteralPath $Fixture -Algorithm SHA256).Hash.ToLowerInvariant();publicConnections=0;fullMigrationAccepted=$false;performanceAccepted=$false;scope='Authored/original native reference graph and moving-chain GPU fixture; no public server or full casting/visual/performance acceptance'}
[IO.File]::WriteAllText($referenceProof,($referenceEvidence | ConvertTo-Json -Depth 6)+[Environment]::NewLine)
Write-Output (@{success=$referencePassed;checks=$referenceResult.checks;proof=$referenceProof;sourceUnchanged=$referenceUnchanged;engineOrLifetimeError=$referenceEngineError}|ConvertTo-Json -Compress)
if(-not$referencePassed){throw 'Native reference debugger check failed; inspect retained evidence'}
