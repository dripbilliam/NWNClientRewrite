$ErrorActionPreference='Stop'
$testProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $testProject 'tools/native-level-up-no-build.ps1')
$testRoot=Join-Path $testProject ('.cache/level-up-source-launch-tests/'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
New-Item -ItemType Directory -Path $testRoot -Force|Out-Null
$testCases=[Collections.Generic.List[object]]::new()
function Check([string]$name,[scriptblock]$body){
 try{& $body;$testCases.Add(@{name=$name;success=$true})}catch{$testCases.Add(@{name=$name;success=$false;error=$_.Exception.Message})}
}
function Reject([scriptblock]$body,[string]$message){
 $caught=$null;try{& $body}catch{$caught=$_.Exception.Message}
 if(-not$caught-or$caught-notlike$message){throw 'Expected exact preflight rejection was absent'}
}
function New-Fixture([string]$name){
 $fixtureRoot=Join-Path $testRoot $name
 foreach($directory in @('native','tools','.cache/native-window','.cache/native-kernel','.cache/native-resource-index')){New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $directory) -Force|Out-Null}
 foreach($file in @('native/window_modes.c','native/test.hpp','tools/build-window-modes.ps1','.cache/native-window/nwn-window-modes.exe','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll')){[IO.File]::WriteAllText((Join-Path $fixtureRoot $file),'Offline hash fixture only')}
 function Hash([string]$file){(Get-FileHash -LiteralPath (Join-Path $fixtureRoot $file)).Hash.ToLowerInvariant()}
 $window=@{source=Hash 'native/window_modes.c';builder=Hash 'tools/build-window-modes.ps1';binary=Hash '.cache/native-window/nwn-window-modes.exe'}
 [IO.File]::WriteAllText((Join-Path $fixtureRoot '.cache/native-window/build-manifest.json'),($window|ConvertTo-Json))
 foreach($kind in @('kernel','resource-index')){
  $binary=if($kind-eq'kernel'){'nwn-particle-kernel.dll'}else{'nwn-resource-index.dll'}
  $manifest=@{binarySha256=Hash ('.cache/native-'+$kind+'/'+$binary);sources=@{'native/test.hpp'=Hash 'native/test.hpp'}}
  [IO.File]::WriteAllText((Join-Path $fixtureRoot ('.cache/native-'+$kind+'/build-manifest.json')),($manifest|ConvertTo-Json))
 }
 $fixtureRoot
}
Check 'Existing reviewed native manifests pass without building' {Assert-NativeLevelUpNoBuild -Root $testProject}
Check 'Detached consistent pins pass' {$fixtureRoot=New-Fixture 'valid';Assert-NativeLevelUpNoBuild -Root $fixtureRoot}
Check 'Changed window builder rejects' {$fixtureRoot=New-Fixture 'builder';[IO.File]::AppendAllText((Join-Path $fixtureRoot 'tools/build-window-modes.ps1'),'changed');Reject {Assert-NativeLevelUpNoBuild -Root $fixtureRoot} '*Window inputs changed*'}
Check 'Changed native binary rejects' {$fixtureRoot=New-Fixture 'binary';[IO.File]::AppendAllText((Join-Path $fixtureRoot '.cache/native-kernel/nwn-particle-kernel.dll'),'changed');Reject {Assert-NativeLevelUpNoBuild -Root $fixtureRoot} '*Native output changed*'}
Check 'Changed source rejects' {$fixtureRoot=New-Fixture 'source';[IO.File]::AppendAllText((Join-Path $fixtureRoot 'native/test.hpp'),'changed');Reject {Assert-NativeLevelUpNoBuild -Root $fixtureRoot} '*Native source changed*'}
Check 'Unlisted header rejects' {$fixtureRoot=New-Fixture 'header';[IO.File]::WriteAllText((Join-Path $fixtureRoot 'native/new.hpp'),'new');Reject {Assert-NativeLevelUpNoBuild -Root $fixtureRoot} '*Unpinned native header*'}
Check 'Escaping manifest input rejects' {
 $fixtureRoot=New-Fixture 'escape';$file=Join-Path $fixtureRoot '.cache/native-kernel/build-manifest.json';$manifest=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json -AsHashtable;$manifest.sources['../outside.hpp']='0';[IO.File]::WriteAllText($file,($manifest|ConvertTo-Json));Reject {Assert-NativeLevelUpNoBuild -Root $fixtureRoot} '*escapes its project*'
}
$join=Join-Path $testProject 'join-native.ps1'
$launch=@{LevelUpSourceCheck=$true;Headless=$true;LocalOnly=$true;Debugger=$true;ProtectedKeyFile='never-read.invalid';LevelUpSourceDirectory='never-used.invalid'}
Check 'Unrelated check rejects before key, build or process access' {Reject {& $join @launch -FeatCheck} '*cannot combine unrelated*'}
Check 'Environment-selected release rejects before pack preparation or key access' {
 $saved=$env:NWN_GODOT_RUNTIME
 try{$env:NWN_GODOT_RUNTIME='release';Reject {& $join @launch} '*requires the existing editor engine*'}finally{if($null-eq$saved){Remove-Item Env:NWN_GODOT_RUNTIME -ErrorAction SilentlyContinue}else{$env:NWN_GODOT_RUNTIME=$saved}}
}
Check 'Source arguments require explicit check before any process access' {Reject {& $join -LevelUpSourceCase wizard-multiclass} '*require their explicit check*'}
Check 'Source launch physically excludes builders from its executed branch' {
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($join,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw 'Join parser failed'}
 $branch=$ast.FindAll({param($node)$node-is[Management.Automation.Language.IfStatementAst]-and$node.Clauses[0].Item1.Extent.Text-eq'$LevelUpSourceCheck'-and$node.ElseClause.Extent.Text-like'*build-window-modes.ps1*'},$true)
 if($branch.Count-ne1-or$branch[0].Clauses[0].Item2.Extent.Text-notlike'*Assert-NativeLevelUpNoBuild*'-or$branch[0].Clauses[0].Item2.Extent.Text-match'build-window-modes|ensure-particle-kernel|ensure-resource-index'){throw 'No-build branch contract changed'}
}
$result=@{success=-not($testCases.success-contains$false);checks=$testCases.Count;cases=@($testCases);serverConnections=0;keyReads=0;nativeBuilds=0;engineProcesses=0;scope='Offline launch rejection and native-output pin tests only.'}
[IO.File]::WriteAllText((Join-Path $testRoot 'proof.json'),($result|ConvertTo-Json -Depth 7)+[Environment]::NewLine)
$result|ConvertTo-Json -Depth 7
if(-not$result.success){throw 'Source launch preflight tests failed; evidence retained'}
