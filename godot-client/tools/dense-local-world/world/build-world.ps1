param(
    [Parameter(Mandatory)][string]$FixtureRoot,
    [ValidateSet('smoke','dense')][string]$Scale='dense',
    [ValidateRange(1024,65535)][int]$Port=5127,
    [ValidateRange(1,4)][int]$DensityMultiplier=1,
    [string]$SeedVault=''
)
$ErrorActionPreference='Stop'

$project=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$workspace=Split-Path $project -Parent
$cache=(Resolve-Path -LiteralPath (Join-Path $workspace '.cache')).Path
$resolved=[IO.Path]::GetFullPath($FixtureRoot)
if(-not $resolved.StartsWith($cache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'FixtureRoot must be a fresh directory below the workspace .cache'
}
if(Test-Path -LiteralPath $resolved){throw 'FixtureRoot already exists'}
$parent=Split-Path $resolved -Parent
while($parent -ne $cache){
    if((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)){
        throw 'FixtureRoot cannot traverse a reparse point'
    }
    $parent=Split-Path $parent -Parent
}

$install=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$source=Join-Path $PSScriptRoot 'fixtures/DensePerf.mod'
$sourceSha='FEC1D0E61A4542216BFB8E6E16A85700F0E1A59B71CFBFB888661EA8F693B247'
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $sourceSha){throw 'The retained DensePerf layout differs from the pinned fixture'}
if(-not (Test-Path -LiteralPath $engine -PathType Leaf)){throw 'The client Godot installation is unavailable'}
$seed=$null
if($SeedVault){
    $seedRoot=(Resolve-Path -LiteralPath $SeedVault).Path
    if(-not $seedRoot.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
        throw 'SeedVault must be a previously owned fixture inside the workspace'
    }
    $bics=@(Get-ChildItem -LiteralPath $seedRoot -Filter '*.bic' -File -Recurse)
    if($bics.Count -ne 1){throw 'Expected exactly one owned server-vault BIC to seed'}
    $seed=$bics[0]
    $relative=[IO.Path]::GetRelativePath($seedRoot,$seed.FullName)
    if($relative -notmatch '^[A-Za-z0-9_]+[\\/][A-Za-z0-9_]+\.bic$'){throw 'Unexpected seeded vault identifier'}
}

$folder=New-Item -ItemType Directory -Path $resolved
$log=Join-Path $folder.FullName 'build.log'
$options=[Diagnostics.ProcessStartInfo]::new()
$options.FileName=$engine
$options.WorkingDirectory=$project
$options.UseShellExecute=$false
$options.CreateNoWindow=$true
$options.RedirectStandardOutput=$true
$options.RedirectStandardError=$true
$options.Environment['APPDATA']=$folder.FullName
$options.Environment['LOCALAPPDATA']=$folder.FullName
foreach($argument in @('--headless','--path',$project,'--log-file',$log,'--script','res://tools/dense-local-world/world/build_world.gd','--',$install,$source,$folder.FullName,$Scale,[string]$Port,[string]$DensityMultiplier)){
    $options.ArgumentList.Add($argument)
}
$process=[Diagnostics.Process]::Start($options)
try {
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(90000)){
        $process.Kill()
        [void]$process.WaitForExit(5000)
        throw 'World generator exceeded its deadline'
    }
    $messages=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
    $published=Join-Path $folder.FullName 'world.json'
    if($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $published -PathType Leaf) -or $messages -match '(?m)^SCRIPT ERROR:'){
        throw "DenseSync generation failed. See $log. $messages"
    }
    if($null -ne $seed){
        foreach($destination in @('seed-vault','server/servervault')){
            $target=Join-Path $folder.FullName (Join-Path $destination $relative)
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $seed.FullName -Destination $target
        }
        $descriptor=Get-Content -LiteralPath $published -Raw | ConvertFrom-Json -AsHashtable
        $descriptor.serverVault=$true
        $descriptor.seedSha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $descriptor | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $published -Encoding utf8
    }
    Get-Content -LiteralPath $published -Raw
} finally {
    $process.Dispose()
}
