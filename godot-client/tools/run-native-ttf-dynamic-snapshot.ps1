param([string]$Name='native-ttf-dynamic-snapshot-v1')
$ErrorActionPreference='Stop'
if($Name -notmatch '^native-ttf-dynamic-[a-z0-9-]+$'){throw 'Use a unique bounded font snapshot name'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$workspace=[IO.Path]::GetFullPath((Join-Path $project '..'));$snapshot=Join-Path $workspace ('.cache/'+$Name)
$proof=Join-Path $project ('reports/'+$Name+'.proof.json')
if((Test-Path -LiteralPath $snapshot) -or (Test-Path -LiteralPath $proof)){throw 'Preserve prior snapshot/evidence'}
[IO.Directory]::CreateDirectory($snapshot)|Out-Null
$manifest=@()
foreach($source in Get-ChildItem -LiteralPath (Join-Path $project 'systems') -Recurse -File -Filter '*.gd'){
    $relative=[IO.Path]::GetRelativePath($project,$source.FullName);$destination=Join-Path $snapshot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
    $bytes=[IO.File]::ReadAllBytes($source.FullName);[IO.File]::WriteAllBytes($destination,$bytes)
    $manifest+=@{source=$source.FullName;snapshot=$destination;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant();proposedHook=$false}
}
$helper=Join-Path $snapshot 'systems/native_data/ttf_pixel_height.gd'
[IO.File]::WriteAllBytes($helper,[IO.File]::ReadAllBytes((Join-Path $project 'tools/native_ttf_em_font.gd')))
$owner=Join-Path $snapshot 'systems/native_bitmap_fonts.gd';$body=[IO.File]::ReadAllText($owner)
$old='var font:=FontFile.new(); font.data=result.value.data; font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false'
if(([regex]::Matches($body,[regex]::Escape($old))).Count -ne 1){throw 'Proposed hook no longer matches the exact original owner branch'}
# Keep the generated edit literal and narrow; no original production file is written.
$replacement="var packet:=preload(`"res://systems/native_data/ttf_pixel_height.gd`").make(result.value.data,int(pending[name].height))`n`t`tif not packet.success: fail(name,str(packet.error)); return`n`t`tvar font: FontFile=packet.font"
$body=$body.Replace($old,$replacement);[IO.File]::WriteAllText($owner,$body,[Text.UTF8Encoding]::new($false))
foreach($entry in $manifest){if($entry.snapshot -eq $owner){$entry.proposedHook=$true}}
$fitter=Join-Path $snapshot 'systems/native_data/nameplate_text.gd';$fitBody=[IO.File]::ReadAllText($fitter)
$fitOld='glyphs[character]=0.0 if character in ["\n","\r","\t"] else F.f(font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.01)'
if(([regex]::Matches($fitBody,[regex]::Escape($fitOld))).Count -ne 1){throw 'Proposed fitting hook no longer matches current source'}
$fitNew="if character in [`"\n`",`"\r`",`"\t`"]: glyphs[character]=0.0`n`t`telif font is FontFile and bool(font.get_meta(`"native_ttf_pixel_height`",false)) and int(font.get_meta(`"native_ttf_pixel_height_prepared`",-1))==size and font.has_char(character.unicode_at(0)):`n`t`t`tvar glyph: int=font.get_glyph_index(size,character.unicode_at(0),0)`n`t`t`tglyphs[character]=F.f(font.get_glyph_advance(0,size,glyph).x*0.01)`n`t`telse: glyphs[character]=F.f(font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.01)"
$fitBody=$fitBody.Replace($fitOld,$fitNew);[IO.File]::WriteAllText($fitter,$fitBody,[Text.UTF8Encoding]::new($false))
foreach($entry in $manifest){if($entry.snapshot -eq $fitter){$entry.proposedHook=$true}}
[IO.Directory]::CreateDirectory((Join-Path $snapshot 'tests'))|Out-Null
$metrics=[IO.File]::ReadAllText((Join-Path $project 'tools/test_native_ttf_em_gates.gd')).Replace('res://tools/native_ttf_em_font.gd','res://systems/native_data/ttf_pixel_height.gd')
[IO.File]::WriteAllText((Join-Path $snapshot 'tests/font_metrics.gd'),$metrics,[Text.UTF8Encoding]::new($false))
$fittingTest=[IO.File]::ReadAllText((Join-Path $project 'tools/test_native_ttf_fitting_adapter.gd')).Replace('res://tools/native_ttf_em_font.gd','res://systems/native_data/ttf_pixel_height.gd')
[IO.File]::WriteAllText((Join-Path $snapshot 'tests/font_fitting.gd'),$fittingTest,[Text.UTF8Encoding]::new($false))
$binding=[IO.File]::ReadAllText((Join-Path $project 'tools/test_native_ttf_source_owner.gd'))
$classStart=$binding.IndexOf('class CandidateFonts extends ');$classEnd=$binding.IndexOf('class NonRenderingArt extends ')
if($classStart -lt 0 -or $classEnd -le $classStart){throw 'Font fixture class region changed'}
$candidateClass="class CandidateFonts extends `"res://systems/native_bitmap_fonts.gd`":`n`tvar builds: Array=[]`n`tfunc publish(name: String) -> void:`n`t`tbuilds.append({`"name`":name,`"ms`":null}); super.publish(name)`n"
$binding=$binding.Substring(0,$classStart)+$candidateClass+$binding.Substring($classEnd)
$binding=$binding.Replace('"candidatePublicationTestSubclass":true','"candidatePublicationCopiedOwner":true').Replace('Proposed TTF branch exists only in this test subclass.','Proposed TTF branch exists only in the copied runtime owner.')
[IO.File]::WriteAllText((Join-Path $snapshot 'tests/font_owner.gd'),$binding,[Text.UTF8Encoding]::new($false))
$configuration="config_version=5`n[application]`nconfig/name=`"Isolated native font gates`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n"
[IO.File]::WriteAllText((Join-Path $snapshot 'project.godot'),$configuration,[Text.UTF8Encoding]::new($false))
$snapshotInputs=@(Get-ChildItem -LiteralPath $snapshot -Recurse -File|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
$exe=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe';$inputs=Join-Path $project 'reports/native-ttf-metrics-current-v2.json';$oracle=Join-Path $workspace 'backups/animations/native-ttf-metrics-v1.json';$install=Join-Path (Split-Path $workspace) 'FullDecomp/NwnRootInstall'
$extraInputs=@($exe,$inputs,$oracle,(Join-Path $project 'tools/native_ttf_em_font.gd'),(Join-Path $project 'tools/test_native_ttf_em_gates.gd'),(Join-Path $project 'tools/test_native_ttf_fitting_adapter.gd'),(Join-Path $project 'tools/test_native_ttf_source_owner.gd'),$PSCommandPath)+@((Get-Content -LiteralPath $inputs -Raw|ConvertFrom-Json).resources.path)
$extraHashes=@($extraInputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
$cases=@(@{name='metrics';script='res://tests/font_metrics.gd';bound=15000;extra=@(('"--inputs='+$inputs+'"'),('"--oracle='+$oracle+'"'))},@{name='fitting';script='res://tests/font_fitting.gd';bound=15000;extra=@(('"--inputs='+$inputs+'"'),('"--oracle='+$oracle+'"'))},@{name='owner';script='res://tests/font_owner.gd';bound=35000;extra=@(('"--install='+$install+'"'),('"--cache='+(Join-Path $snapshot 'private-resource-cache')+'"'))})
$results=@()
foreach($case in $cases){
    $report=Join-Path $project ('reports/'+$Name+'-'+$case.name+'.json');$log=Join-Path $project ('reports/'+$Name+'-'+$case.name+'.engine.log')
    if((Test-Path -LiteralPath $report) -or (Test-Path -LiteralPath $log)){throw 'Preserve prior case'}
    $arguments=@('--headless','--path',('"'+$snapshot+'"'),'--log-file',('"'+$log+'"'),'--script',$case.script,'--',('"--report='+$report+'"'))+$case.extra
    $process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru;$finished=$process.WaitForExit($case.bound)
    if(-not $finished){$process.Kill();$process.WaitForExit()}
    $data=$null;$engine='';if(Test-Path -LiteralPath $report){$data=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json};if(Test-Path -LiteralPath $log){$engine=Get-Content -LiteralPath $log -Raw}
    $clean=$engine -notmatch '(?im)(SCRIPT ERROR|ERROR:|WARNING:|ObjectDB instances leaked|resources still in use|Unicode parsing error)'
    $results+=@{name=$case.name;pid=$process.Id;finished=$finished;exitCode=$process.ExitCode;engineClean=$clean;report=$report;log=$log;checks=if($data){$data.checks}else{0};success=($finished -and $process.ExitCode -eq 0 -and $clean -and $null -ne $data -and $data.success);failures=if($data){@($data.failures)}else{@('No result report')}}
}
$sourceUnchanged=$true;foreach($entry in $manifest){if((Get-FileHash -LiteralPath $entry.source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$sourceUnchanged=$false}}
$snapshotUnchanged=$true;foreach($entry in $snapshotInputs){if((Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$snapshotUnchanged=$false}}
$extraUnchanged=$true;foreach($entry in $extraHashes){if((Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$extraUnchanged=$false}}
$success=$sourceUnchanged -and $snapshotUnchanged -and $extraUnchanged -and @($results|Where-Object{-not $_.success}).Count -eq 0
$receipt=@{success=$success;sourceUnchanged=$sourceUnchanged;snapshotUnchanged=$snapshotUnchanged;extraInputsUnchanged=$extraUnchanged;sourceInputs=$manifest;snapshotInputs=$snapshotInputs;extraInputs=$extraHashes;runtimeSha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant();cases=$results;checks=($results|Measure-Object -Property checks -Sum).Sum;helperRuntimePath='res://systems/native_data/ttf_pixel_height.gd';runtimeToolsDependency=$false;oracleUsedOnlyByMetricTest=$true;proposedOwnerHookOnlyInCopiedProject=$true;productionChanged=$false;defaultChanged=$false;headless=$true;gpu=$false;serverConnections=0;originalFontAssetsPrivateOnly=$true}
$receipt|ConvertTo-Json -Depth 9|Set-Content -LiteralPath $proof -Encoding UTF8
@{success=$success;sourceUnchanged=$sourceUnchanged;snapshotUnchanged=$snapshotUnchanged;checks=$receipt.checks;proof=$proof;cases=$results}|ConvertTo-Json -Depth 6
if(-not $success){exit 1}
