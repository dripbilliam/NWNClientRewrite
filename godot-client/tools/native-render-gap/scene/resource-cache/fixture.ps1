param([Parameter(Mandatory=$true)][string]$Project,[Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
$fixtureRoot=[IO.Path]::GetFullPath($Project)
$fixtureOutput=[IO.Path]::GetFullPath($Output)
$fixtureChecks=[Collections.Generic.List[object]]::new()
$fixtureEnsure=Join-Path $fixtureRoot 'tools/ensure-resource-index.ps1'
$fixtureCpp=Join-Path $fixtureRoot 'native/resource_index.cpp'
$fixtureTwoDa=Join-Path $fixtureRoot 'native/two_da_parser.hpp'
$fixtureRegistration=Join-Path $fixtureRoot '.godot/extension_list.cfg'
$fixtureOriginalCpp=[IO.File]::ReadAllBytes($fixtureCpp)
$fixtureOriginalTwoDa=[IO.File]::ReadAllBytes($fixtureTwoDa)
$fixtureOriginalRegistration=[IO.File]::ReadAllBytes($fixtureRegistration)
. (Join-Path $fixtureRoot 'tools/resource-index-build-inputs.ps1')
function Get-FixtureFiles {
 $snapshot=[ordered]@{}
 foreach($file in Get-ChildItem -LiteralPath $fixtureRoot -Recurse -File){$relative=$file.FullName.Substring($fixtureRoot.Length+1).Replace('\','/');$snapshot[$relative]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 return ($snapshot|ConvertTo-Json -Compress)
}
function Add-FixtureCheck([bool]$Ok,[string]$Name,$Evidence){$fixtureChecks.Add(@{ok=$Ok;name=$Name;evidence=$Evidence})}
function Test-FixtureEnsure([string]$Name,[bool]$ExpectedReady,[string]$ExpectedError='') {
 $before=Get-FixtureFiles;$caught='';$returned=$null
 try{$returned=@(& $fixtureEnsure -CheckOnly)}catch{$caught=$_.Exception.Message}
 $after=Get-FixtureFiles
 Add-FixtureCheck (($ExpectedReady-and-not$caught)-or(-not$ExpectedReady-and$caught.Contains($ExpectedError))) $Name @{expectedReady=$ExpectedReady;error=$caught;output=$returned}
 Add-FixtureCheck ($before-ceq$after) ($Name+' CheckOnly did not write/create/remove files') @{beforeSha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($before))).ToLowerInvariant();afterSha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($after))).ToLowerInvariant()}
}
function Test-FixtureClosureReject([string]$Name,[string]$Directive,[string]$ExpectedError) {
 [IO.File]::WriteAllText($fixtureCpp,[Text.Encoding]::UTF8.GetString($fixtureOriginalCpp)+"`n"+$Directive+"`n",[Text.UTF8Encoding]::new($false))
 $caught='';try{$null=@(Get-ResourceIndexBuildInputs -Project $fixtureRoot)}catch{$caught=$_.Exception.Message}
 Add-FixtureCheck ($caught.Contains($ExpectedError)) ($Name+' closure fails closed') @{error=$caught;directive=$Directive}
 Test-FixtureEnsure $Name $false $ExpectedError
 [IO.File]::WriteAllBytes($fixtureCpp,$fixtureOriginalCpp)
}
$expected=@('.tools/extension-api/extension_api.json','.tools/extension-api/gdextension_interface.h','native/resource_index.cpp','native/resource_index.gdextension','native/two_da_parser.hpp','tools/build-resource-index.ps1','tools/resource-index-build-inputs.ps1')
$actual=@(Get-ResourceIndexBuildInputs -Project $fixtureRoot)
Add-FixtureCheck (($actual-join'|')-ceq($expected-join'|')) 'Actual baseline include closure is the seven declared dependencies' @{actual=$actual;expected=$expected}
Test-FixtureEnsure 'Exact adopted F2 cache' $true
$unrelated=Join-Path $fixtureRoot 'native/particle_fixture_unrelated.hpp'
[IO.File]::WriteAllText($unrelated,"#pragma once`n// Unrelated particle header A`n")
Test-FixtureEnsure 'Adding unrelated particle header preserves resource cache' $true
[IO.File]::WriteAllText($unrelated,"#pragma once`n// Unrelated particle header B changed`n")
Test-FixtureEnsure 'Changing unrelated particle header preserves resource cache' $true
Add-FixtureCheck ((@(Get-ResourceIndexBuildInputs -Project $fixtureRoot)-join'|')-ceq($actual-join'|')) 'Unrelated particle header is absent from dependency closure' @{}
[IO.File]::WriteAllText($fixtureTwoDa,[Text.Encoding]::UTF8.GetString($fixtureOriginalTwoDa)+"`n// Actual resource dependency changed`n",[Text.UTF8Encoding]::new($false))
Test-FixtureEnsure 'Changing included two_da parser invalidates cache' $false 'check-only forbids compilation'
[IO.File]::WriteAllBytes($fixtureTwoDa,$fixtureOriginalTwoDa)
$recursiveOne=Join-Path $fixtureRoot 'native/resource_fixture_one.hpp';$recursiveTwo=Join-Path $fixtureRoot 'native/resource_fixture_two.hpp'
[IO.File]::WriteAllText($recursiveOne,"#pragma once`n#include `"resource_fixture_two.hpp`" // recursive literal include`n")
[IO.File]::WriteAllText($recursiveTwo,"#pragma once`n#include <cstdint>`n#include `"resource_fixture_one.hpp`" /* cycle */`n")
[IO.File]::WriteAllText($fixtureCpp,[Text.Encoding]::UTF8.GetString($fixtureOriginalCpp)+"`n#include `"resource_fixture_one.hpp`"`n",[Text.UTF8Encoding]::new($false))
$recursive=@(Get-ResourceIndexBuildInputs -Project $fixtureRoot)
Add-FixtureCheck ($recursive.Count-eq9-and'native/resource_fixture_one.hpp'-in$recursive-and'native/resource_fixture_two.hpp'-in$recursive) 'Recursive quoted includes expand closure and terminate a cycle' @{actual=$recursive}
Test-FixtureEnsure 'New recursive compiled inputs invalidate cache' $false 'check-only forbids compilation'
[IO.File]::WriteAllBytes($fixtureCpp,$fixtureOriginalCpp)
Test-FixtureClosureReject 'Missing quoted header' '#include "resource_fixture_missing.hpp"' 'quoted header missing or outside project'
Test-FixtureClosureReject 'Macro include expression' '#include RESOURCE_HEADER_MACRO' 'must be a literal quoted or system header'
$outside=Join-Path (Split-Path $fixtureRoot -Parent) 'outside-resource-fixture.hpp';[IO.File]::WriteAllText($outside,"#pragma once`n// Must remain outside fixture project`n")
Test-FixtureClosureReject 'Existing outside quoted header' '#include "../../outside-resource-fixture.hpp"' 'quoted header missing or outside project'
$retainedRegistration=$fixtureRegistration+'.retained'
if(-not$fixtureRegistration.StartsWith($fixtureRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture registration boundary invalid'}
Move-Item -LiteralPath $fixtureRegistration -Destination $retainedRegistration
Test-FixtureEnsure 'Missing registration file' $false 'Resource extension registration is missing'
Add-FixtureCheck (-not(Test-Path -LiteralPath $fixtureRegistration)) 'Missing registration CheckOnly did not create registration' @{}
Move-Item -LiteralPath $retainedRegistration -Destination $fixtureRegistration
[IO.File]::WriteAllText($fixtureRegistration,"res://native/particle_kernel.gdextension`n")
Test-FixtureEnsure 'Registration file missing resource entry' $false 'Resource extension registration is missing'
[IO.File]::WriteAllBytes($fixtureRegistration,$fixtureOriginalRegistration)
Test-FixtureEnsure 'Restored exact resource dependencies remain ready' $true
$success=@($fixtureChecks|Where-Object{-not$_.ok}).Count-eq0
$receipt=@{version=1;success=$success;created=[DateTime]::UtcNow.ToString('o');checks=@($fixtureChecks);project=$fixtureRoot;scope='Private CheckOnly dependency/cache/registration behavior. Every ensure call uses CheckOnly; no compiler, Godot process or main mutation. Negative-case errors are expected preserved evidence.'}
$receipt|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $fixtureOutput -Encoding utf8
Write-Output ($receipt|Select-Object success,@{n='checks';e={$_.checks.Count}},scope|ConvertTo-Json -Compress)
if(-not$success){exit 1}
