function Assert-NativeLevelUpNoBuild {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$Root)
 $guardRoot=[IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
 function Get-SourceGuardHash([string]$relative){
  $absolute=[IO.Path]::GetFullPath((Join-Path $guardRoot $relative))
  if(-not$absolute.StartsWith($guardRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Native no-build input escapes its project'}
  if(-not(Test-Path -LiteralPath $absolute -PathType Leaf)){throw 'Native no-build input is missing'}
  (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()
 }
 $window=Get-Content -LiteralPath (Join-Path $guardRoot '.cache/native-window/build-manifest.json') -Raw|ConvertFrom-Json -AsHashtable
 if($window.source-ne(Get-SourceGuardHash 'native/window_modes.c')-or$window.builder-ne(Get-SourceGuardHash 'tools/build-window-modes.ps1')-or$window.binary-ne(Get-SourceGuardHash '.cache/native-window/nwn-window-modes.exe')){throw 'Window inputs changed; no build authorized'}
 foreach($kind in @('kernel','resource-index')){
  $manifest=Get-Content -LiteralPath (Join-Path $guardRoot ('.cache/native-'+$kind+'/build-manifest.json')) -Raw|ConvertFrom-Json -AsHashtable
  $binary=if($kind-eq'kernel'){'nwn-particle-kernel.dll'}else{'nwn-resource-index.dll'}
  if($manifest.binarySha256-ne(Get-SourceGuardHash ('.cache/native-'+$kind+'/'+$binary))){throw 'Native output changed; no build authorized'}
  if($manifest.sources-isnot[System.Collections.IDictionary]-or$manifest.sources.Count-eq0){throw 'Native source pins are missing; no build authorized'}
  foreach($entry in $manifest.sources.GetEnumerator()){if($entry.Value-ne(Get-SourceGuardHash $entry.Key)){throw 'Native source changed; no build authorized'}}
  foreach($header in Get-ChildItem -LiteralPath (Join-Path $guardRoot 'native') -File -Filter '*.hpp'){
   $relative=$header.FullName.Substring($guardRoot.Length+1).Replace('\','/')
   if(-not$manifest.sources.Contains($relative)){throw 'Unpinned native header; no build authorized'}
  }
 }
}
