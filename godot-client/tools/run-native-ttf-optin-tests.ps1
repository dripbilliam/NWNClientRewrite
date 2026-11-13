param([string]$Name='native-ttf-optin-final-v1')
$ErrorActionPreference='Stop'
if($Name -notmatch '^native-ttf-optin-[a-z0-9-]+$'){throw 'Choose a unique native font test name'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$workspace=[IO.Path]::GetFullPath((Join-Path $project '..'));$copy=Join-Path $workspace ('.cache/'+$Name);$proof=Join-Path $project ('reports/'+$Name+'.proof.json')
if((Test-Path -LiteralPath $copy) -or (Test-Path -LiteralPath $proof)){throw 'Preserve prior test project/receipt'}
[IO.Directory]::CreateDirectory($copy)|Out-Null
$paths=@(Get-ChildItem -LiteralPath (Join-Path $project 'systems'),(Join-Path $project 'tests') -Recurse -File|Where-Object{$_.Extension -in '.gd','.gdshader'})+@(Get-ChildItem -LiteralPath $project -File -Filter '*.gd')
$paths+=@(Get-Item -LiteralPath (Join-Path $project 'native/particle_kernel.gdextension'),(Join-Path $project '.cache/native-kernel/nwn-particle-kernel.dll'),(Join-Path $project 'reports/native-bitmap-font-oracle-v5.json'))
$sources=@()
foreach($file in $paths){
    $relative=[IO.Path]::GetRelativePath($project,$file.FullName);$target=Join-Path $copy $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
    $bytes=[IO.File]::ReadAllBytes($file.FullName);[IO.File]::WriteAllBytes($target,$bytes);$sources+=@{source=$file.FullName;copy=$target;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
}
# Dummy headless RenderingServer emits no frame_post_draw. Keep every existing
# bitmap assertion; guard only its final presentation wait in this copied test.
$bitmap=Join-Path $copy 'tests/native_bitmap_font_test.gd';$body=[IO.File]::ReadAllText($bitmap);$old="`tawait RenderingServer.frame_post_draw"
if(([regex]::Matches($body,[regex]::Escape($old))).Count -ne 1){throw 'Bitmap presentation wait changed; review before copying'}
$body=$body.Replace($old,"`tif DisplayServer.get_name()!=`"headless`": await RenderingServer.frame_post_draw").Replace('if not OS.get_cmdline_args().has("--headless")','if DisplayServer.get_name()!="headless"');[IO.File]::WriteAllText($bitmap,$body,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $copy 'project.godot'),"config_version=5`n[application]`nconfig/name=`"Isolated integrated native fonts`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n",[Text.UTF8Encoding]::new($false))
$copied=@(Get-ChildItem -LiteralPath $copy -File -Recurse|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
$exe=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe';$inputs=Join-Path $project 'reports/native-ttf-metrics-current-v2.json';$oracle=Join-Path $workspace 'backups/animations/native-ttf-metrics-v1.json';$wrapping=Join-Path $workspace 'backups/animations/native-nameplate-text-v3.json';$install=Join-Path (Split-Path $workspace) 'FullDecomp/NwnRootInstall'
$extraPaths=@($exe,$inputs,$oracle,$wrapping,$PSCommandPath)+@((Get-Content -LiteralPath $inputs -Raw|ConvertFrom-Json).resources.path)
$extras=@($extraPaths|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
$metricArgs=@(('"--inputs='+$inputs+'"'),('"--oracle='+$oracle+'"'))
$installArgs=@(('"--install='+$install+'"'))
$cases=@(@{name='metrics';script='native_ttf_pixel_height_test';extra=$metricArgs},@{name='fitting';script='native_ttf_pixel_fitting_test';extra=$metricArgs},@{name='owner';script='native_ttf_pixel_owner_test';extra=$installArgs+@(('"--cache='+(Join-Path $copy 'private-font-cache')+'"'))},@{name='bitmap';script='native_bitmap_font_test';extra=$installArgs},@{name='nameplates';script='native_nameplate_test';extra=$installArgs},@{name='wrapping';script='native_nameplate_text_test';extra=@(('"--oracle='+$wrapping+'"'))},@{name='chat-hud';script='native_chat_hud_test';extra=$installArgs})
$results=@()
foreach($case in $cases){
    $report=Join-Path $project ('reports/'+$Name+'-'+$case.name+'.json');$log=Join-Path $project ('reports/'+$Name+'-'+$case.name+'.engine.log')
    if((Test-Path -LiteralPath $report) -or (Test-Path -LiteralPath $log)){throw 'Preserve prior case'}
    $arguments=@('--headless','--path',('"'+$copy+'"'),'--log-file',('"'+$log+'"'),'--script',('res://tests/'+$case.script+'.gd'),'--',('"--report='+$report+'"'))+$case.extra
    $clock=[Diagnostics.Stopwatch]::StartNew();$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru;$finished=$process.WaitForExit(35000)
    if(-not $finished){$process.Kill();$process.WaitForExit()};$clock.Stop();$data=$null;$engine=''
    if(Test-Path -LiteralPath $report){$data=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json};if(Test-Path -LiteralPath $log){$engine=Get-Content -LiteralPath $log -Raw}
    $clean=$engine -notmatch '(?im)(SCRIPT ERROR|ERROR:|WARNING:|ObjectDB instances leaked|resources still in use|Unicode parsing error)'
    $results+=@{name=$case.name;pid=$process.Id;finished=$finished;exitCode=$process.ExitCode;wallMs=$clock.Elapsed.TotalMilliseconds;engineClean=$clean;report=$report;log=$log;checks=if($data){$data.checks}else{0};success=($finished -and $process.ExitCode -eq 0 -and $clean -and $null -ne $data -and $data.success);failures=if($data){@($data.failures)}else{@('No result report')}}
}
$unchanged=$true;foreach($entry in $sources){if((Get-FileHash -LiteralPath $entry.source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$unchanged=$false}}
$copyUnchanged=$true;foreach($entry in $copied){if((Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$copyUnchanged=$false}}
$extraUnchanged=$true;foreach($entry in $extras){if((Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){$extraUnchanged=$false}}
$success=$unchanged -and $copyUnchanged -and $extraUnchanged -and @($results|Where-Object{-not $_.success}).Count -eq 0
$receipt=@{success=$success;sourceUnchanged=$unchanged;copyUnchanged=$copyUnchanged;extraInputsUnchanged=$extraUnchanged;sourceInputs=$sources;copiedInputs=$copied;extraInputs=$extras;cases=$results;checks=($results|Measure-Object -Property checks -Sum).Sum;headless=$true;gpu=$false;nativeBuilds=0;serverConnections=0;ordinaryDefaultsChanged=$false;productionTestOverrides=@();copiedTestOnlyChange='Use DisplayServer headless identity to guard only final bitmap frame_post_draw wait and screenshot; all assertions unchanged';originalPixelsAccepted=$false}
$receipt|ConvertTo-Json -Depth 9|Set-Content -LiteralPath $proof -Encoding UTF8
@{success=$success;sourceUnchanged=$unchanged;copyUnchanged=$copyUnchanged;checks=$receipt.checks;proof=$proof;cases=$results}|ConvertTo-Json -Depth 6
if(-not $success){exit 1}
