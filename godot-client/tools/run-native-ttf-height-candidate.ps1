param([string]$ReportName='native-ttf-height-candidate-final-v1')
$ErrorActionPreference='Stop'
if($ReportName -notmatch '^native-ttf-height-[a-z0-9-]+$'){throw 'Use a unique font-candidate report name'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=[IO.Path]::GetFullPath((Join-Path $project '..'))
$exe=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$inputs=Join-Path $project 'reports/native-ttf-metrics-current-v2.json'
$oracle=Join-Path $workspace 'backups/animations/native-ttf-metrics-v1.json'
$boxes=Join-Path $project 'reports/native-ttf-glyph-boxes-v1.json'
$proof=Join-Path $project ('reports/'+$ReportName+'.proof.json')
if(Test-Path -LiteralPath $proof){throw 'Preserve prior proof'}
$sourcePaths=@('tools/native_ttf_scaling_prototype.gd','tools/probe_native_ttf_scaling.gd','tools/native_ttf_height_font.gd','tools/test_native_ttf_height_font.gd','tools/probe_native_ttf_height_binding.gd','tools/run-native-ttf-height-candidate.ps1','tools/inspect-native-ttf-glyph-boxes.py','systems/native_data/font_data.gd','systems/native_data/binary_data.gd')|ForEach-Object{Join-Path $project $_}
$sourcePaths+=@($exe,$inputs,$oracle,$boxes)
$fontInputs=Get-Content -LiteralPath $inputs -Raw|ConvertFrom-Json
$sourcePaths+=@($fontInputs.resources|ForEach-Object{$_.path})
function HashInputs { $rows=@();foreach($path in $sourcePaths){$rows+=@{path=$path;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}};return ,$rows }
$before=HashInputs
$cases=@(@{name='metrics';script='res://tools/test_native_ttf_height_font.gd'},@{name='bindings';script='res://tools/probe_native_ttf_height_binding.gd'})
$results=@()
foreach($case in $cases){
    $report=Join-Path $project ('reports/'+$ReportName+'-'+$case.name+'.json')
    $log=Join-Path $project ('reports/'+$ReportName+'-'+$case.name+'.engine.log')
    if((Test-Path -LiteralPath $report) -or (Test-Path -LiteralPath $log)){throw 'Preserve prior case artifacts'}
    $arguments=@('--headless','--path',('"'+$project+'"'),'--log-file',('"'+$log+'"'),'--script',$case.script,'--',('"--inputs='+$inputs+'"'),('"--oracle='+$oracle+'"'),('"--boxes='+$boxes+'"'),('"--report='+$report+'"'))
    $watch=[Diagnostics.Stopwatch]::StartNew();$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $finished=$process.WaitForExit(15000)
    if(-not $finished){$process.Kill();$process.WaitForExit()}
    $watch.Stop();$data=$null;$engine=''
    if(Test-Path -LiteralPath $report){$data=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
    if(Test-Path -LiteralPath $log){$engine=Get-Content -LiteralPath $log -Raw}
    $clean=$engine -notmatch '(?im)(SCRIPT ERROR|ERROR:|WARNING:|ObjectDB instances leaked|resources still in use|Unicode parsing error)'
    $results+=@{name=$case.name;pid=$process.Id;finished=$finished;exitCode=$process.ExitCode;wallMs=$watch.Elapsed.TotalMilliseconds;engineClean=$clean;report=$report;log=$log;checks=if($data){$data.checks}else{0};success=($finished -and $process.ExitCode -eq 0 -and $clean -and $null -ne $data -and $data.success);failures=if($data){@($data.failures)}else{@('No result report')}}
}
$after=HashInputs
$unchanged=(ConvertTo-Json -InputObject $before -Depth 4 -Compress) -ceq (ConvertTo-Json -InputObject $after -Depth 4 -Compress)
$success=$unchanged -and @($results|Where-Object{-not $_.success}).Count -eq 0
$receipt=@{success=$success;sourceUnchanged=$unchanged;inputs=$before;cases=$results;checks=($results|Measure-Object -Property checks -Sum).Sum;headless=$true;gpu=$false;framebuffer=$false;serverConnections=0;productionChanged=$false;sourceAssetsExported=$false;originalAtlasPixelsAccepted=$false;defaultMethodChanged=$false}
$receipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $proof -Encoding UTF8
@{success=$success;sourceUnchanged=$unchanged;checks=$receipt.checks;proof=$proof;cases=$results}|ConvertTo-Json -Depth 6
if(-not $success){exit 1}
