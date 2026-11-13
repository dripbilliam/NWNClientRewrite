param([ValidatePattern('^[a-z0-9-]+$')][string]$Label='a')
$ErrorActionPreference='Stop'
$ltoProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$ltoOut=Join-Path $ltoProject ('.cache/native-render-gap/original/compiler/archive-proof-'+$Label)
if(Test-Path -LiteralPath $ltoOut){throw 'Preserve prior proof'}
New-Item -ItemType Directory -Path $ltoOut|Out-Null
$ltoToolDir=Join-Path $ltoProject '.cache/native-text-build/compiler/w64devkit/bin'
$ltoCompiler=Join-Path $ltoToolDir 'x86_64-w64-mingw32-g++.exe'
if((Get-FileHash -LiteralPath $ltoCompiler).Hash.ToLowerInvariant()-ne'03e15580dda29518716dc6f6840d5ea055f526ddc8f59f14192b8d3e3eeea622'){throw 'Pinned GCC drift'}
$ltoAr=Join-Path $ltoToolDir 'x86_64-w64-mingw32-ar.exe'
$ltoNm=Join-Path $ltoToolDir 'x86_64-w64-mingw32-nm.exe'
$ltoObjdump=Join-Path $ltoToolDir 'x86_64-w64-mingw32-objdump.exe'
$ltoInvocations=[Collections.Generic.List[object]]::new()
function Invoke-LtoProof([string]$Tool,[string[]]$Arguments,[string]$Working,[string]$Name) {
 $ltoStart=[Diagnostics.ProcessStartInfo]::new();$ltoStart.FileName=$Tool;$ltoStart.WorkingDirectory=$Working;$ltoStart.UseShellExecute=$false;$ltoStart.CreateNoWindow=$true;$ltoStart.RedirectStandardOutput=$true;$ltoStart.RedirectStandardError=$true
 foreach($ltoArgument in $Arguments){$ltoStart.ArgumentList.Add($ltoArgument)}
 $ltoStart.Environment['PATH']=$ltoToolDir+';'+$env:PATH
 $ltoChild=[Diagnostics.Process]::new();$ltoChild.StartInfo=$ltoStart;$ltoWatch=[Diagnostics.Stopwatch]::StartNew();[void]$ltoChild.Start();$ltoPid=$ltoChild.Id;$ltoStdout=$ltoChild.StandardOutput.ReadToEndAsync();$ltoStderr=$ltoChild.StandardError.ReadToEndAsync()
 if(-not$ltoChild.WaitForExit(30000)){$ltoChild.Kill($true);[void]$ltoChild.WaitForExit(1000);throw 'Owned tiny compiler/linker proof timed out'}
 $ltoWatch.Stop();$ltoCode=$ltoChild.ExitCode;$ltoText=$ltoStdout.GetAwaiter().GetResult();$ltoError=$ltoStderr.GetAwaiter().GetResult();$ltoChild.Dispose()
 [IO.File]::WriteAllText((Join-Path $Working ($Name+'.stdout.log')),$ltoText);[IO.File]::WriteAllText((Join-Path $Working ($Name+'.stderr.log')),$ltoError)
 $ltoInvocations.Add(@{name=$Name;tool=$Tool;toolSha256=(Get-FileHash -LiteralPath $Tool).Hash.ToLowerInvariant();arguments=$Arguments;pid=$ltoPid;exit=$ltoCode;wallMs=$ltoWatch.Elapsed.TotalMilliseconds})
 if($ltoCode-ne0){throw ('Tiny LTO proof command failed '+$Name+': '+$ltoError)}
 return $ltoText
}
$ltoVariants=@(
 @{name='baseline';compile=@();link=@();archive=$true},
 @{name='godot-supported-archive';compile=@('-flto','-fno-use-linker-plugin','-fwhole-program');link=@('-flto=2','-fno-use-linker-plugin','-fwhole-program');archive=$true},
 @{name='plugin-archive';compile=@('-flto','-fuse-linker-plugin');link=@('-flto=2','-fuse-linker-plugin');archive=$true},
 @{name='godot-supported-loose';compile=@('-flto','-fno-use-linker-plugin','-fwhole-program');link=@('-flto=2','-fno-use-linker-plugin','-fwhole-program');archive=$false}
)
$ltoResults=[Collections.Generic.List[object]]::new()
try {
 foreach($ltoVariant in $ltoVariants) {
  $ltoDir=Join-Path $ltoOut $ltoVariant.name;New-Item -ItemType Directory -Path $ltoDir|Out-Null
  foreach($ltoFile in @('archive-main.cpp','archive-function.cpp')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $ltoFile) -Destination (Join-Path $ltoDir $ltoFile)}
  $ltoCommon=@('-std=gnu++17','-O3','-ffp-contract=off','-static')+$ltoVariant.compile
  [void](Invoke-LtoProof $ltoCompiler ($ltoCommon+@('-c','archive-main.cpp','-o','main.o')) $ltoDir 'compile-main')
  [void](Invoke-LtoProof $ltoCompiler ($ltoCommon+@('-c','archive-function.cpp','-o','function.o')) $ltoDir 'compile-function')
  $ltoInput='function.o'
  if($ltoVariant.archive){[void](Invoke-LtoProof $ltoAr @('rcs','libfunction.a','function.o') $ltoDir 'archive');$ltoInput='libfunction.a'}
  [void](Invoke-LtoProof $ltoCompiler (@('-O3','-ffp-contract=off','-static','main.o',$ltoInput,'-o','proof.exe','-Wl,-Map=proof.map')+$ltoVariant.link) $ltoDir 'link')
  foreach($ltoCase in @(@{arguments=@();expected=10},@{arguments=@('a');expected=13},@{arguments=@('a','b');expected=16})){$ltoActual=(Invoke-LtoProof (Join-Path $ltoDir 'proof.exe') $ltoCase.arguments $ltoDir ('run-'+$ltoCase.arguments.Count)).Trim();if($ltoActual-ne[string]$ltoCase.expected){throw 'Exact integer result mismatch'}}
  $ltoAssembly=Invoke-LtoProof $ltoObjdump @('-d','-C','proof.exe') $ltoDir 'objdump'
  $ltoSymbols=Invoke-LtoProof $ltoNm @('-n','-C','proof.exe') $ltoDir 'nm'
  $ltoMain=[regex]::Match($ltoAssembly,'(?ms)^\s*[0-9a-f]+ <main>:\r?\n(.*?)(?=^\s*[0-9a-f]+ <|\z)').Groups[1].Value
  if($ltoMain.Length-eq0){throw 'No exact main disassembly'}
  $ltoCall=[regex]::IsMatch($ltoMain,'\bcall\s+[^\r\n]*<cross_tu_fold(?:[.+][^>]*)?>')
  $ltoResults.Add(@{variant=$ltoVariant.name;crossTuCallRetained=$ltoCall;crossTuSymbolPresent=[regex]::IsMatch($ltoSymbols,'(?m) [Tt] cross_tu_fold(?:[.][^\r\n]*)?\r?$');codeAndRuntimePass=$true;binarySha256=(Get-FileHash -LiteralPath (Join-Path $ltoDir 'proof.exe')).Hash.ToLowerInvariant();mainAssembly=$ltoMain;mainNamedCalls=@([regex]::Matches($ltoMain,'\bcall\s+[^\r\n]*<([^>]+)>')|ForEach-Object{$_.Groups[1].Value})})
 }
 $ltoSuccess=$true
} finally {
 @{version=1;success=$ltoSuccess;sourceOnly=$false;out=$ltoOut;variants=$ltoResults;invocations=$ltoInvocations;scope='Tiny exact pinned-GCC cross-TU archive semantics/IPA capability proof, not engine compilation or performance/FPS evidence. All files private; no existing archive/object/engine output modified.'}|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $ltoOut 'receipt.json') -Encoding utf8
}
$ltoResults|Select-Object variant,crossTuCallRetained,crossTuSymbolPresent,codeAndRuntimePass|ConvertTo-Json -Compress
