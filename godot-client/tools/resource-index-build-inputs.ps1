# Resource parser dependencies only. Unrelated particle headers are not inputs.
function Get-ResourceIndexBuildInputs {
 param([Parameter(Mandatory=$true)][string]$Project)
 $resourceInputRoot=[IO.Path]::GetFullPath($Project).TrimEnd([IO.Path]::DirectorySeparatorChar)
 $resourceInputNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($resourceInputName in @('native/resource_index.cpp','native/resource_index.gdextension','tools/build-resource-index.ps1','tools/resource-index-build-inputs.ps1','.tools/extension-api/gdextension_interface.h','.tools/extension-api/extension_api.json')){[void]$resourceInputNames.Add($resourceInputName)}
 $resourceInputPending=[Collections.Generic.Stack[string]]::new();$resourceInputPending.Push((Join-Path $resourceInputRoot 'native/resource_index.cpp'))
 $resourceInputVisited=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 while($resourceInputPending.Count){
  $resourceInputFile=[IO.Path]::GetFullPath($resourceInputPending.Pop())
  if(-not$resourceInputFile.StartsWith($resourceInputRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Resource include escaped project'}
  if(-not$resourceInputVisited.Add($resourceInputFile)){continue}
  foreach($resourceInputDirective in [regex]::Matches([IO.File]::ReadAllText($resourceInputFile),'(?m)^\s*#\s*include\s+([^\r\n]+)')){
   $resourceInputExpression=$resourceInputDirective.Groups[1].Value.Trim()
   if($resourceInputExpression-match'^<[^>]+>\s*(?://.*|/\*.*\*/)?$'){continue}
   if($resourceInputExpression-notmatch'^"([^"]+)"\s*(?://.*|/\*.*\*/)?$'){throw 'Resource include must be a literal quoted or system header'}
   $resourceInputHeader=$Matches[1]
   $resourceInputResolved=Join-Path (Split-Path -Parent $resourceInputFile) $resourceInputHeader
   if(-not(Test-Path -LiteralPath $resourceInputResolved)){$resourceInputResolved=Join-Path (Join-Path $resourceInputRoot '.tools/extension-api') $resourceInputHeader}
   $resourceInputResolved=[IO.Path]::GetFullPath($resourceInputResolved)
   if(-not$resourceInputResolved.StartsWith($resourceInputRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $resourceInputResolved -PathType Leaf)){throw 'Resource quoted header missing or outside project'}
   [void]$resourceInputNames.Add($resourceInputResolved.Substring($resourceInputRoot.Length+1).Replace('\','/'))
   $resourceInputPending.Push($resourceInputResolved)
  }
 }
 @($resourceInputNames|Sort-Object)
}
