'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');const project=path.resolve(__dirname,'../../../..'),sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');const old=path.join(project,'tools/native-render-gap/scene/static-prefix-fixture-capsule-b/run.ps1'),seal=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-render-gap/scene/static-prefix-fixture-capsule-source-b/receipt.json')));const pin=seal.sourcePins.find(row=>row.origin===old);assert(pin&&sha(old)===pin.sha256);let text=fs.readFileSync(old,'utf8');const start=text.indexOf('$fixtureStart=[Diagnostics.ProcessStartInfo]'),end=text.indexOf("& node (Join-Path $PSScriptRoot 'verify.cjs') --phase=post");assert(start>0&&end>start);
const preamble=`param([Parameter(Mandatory=$true)][string]$Suite,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$SuiteSha,[Parameter(Mandatory=$true)][int]$Index,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Source-only isolated runner; a new authorized native slot is required'}
$suiteFile=[IO.Path]::GetFullPath($Suite)
if((Get-FileHash -LiteralPath $suiteFile).Hash.ToLowerInvariant()-ne$SuiteSha){throw 'Isolated suite pin mismatch'}
$suiteData=Get-Content -LiteralPath $suiteFile -Raw|ConvertFrom-Json
if($Index-lt0-or$Index-ge$suiteData.jobs.Count){throw 'Isolated job index differs'}
$suiteRunner=@($suiteData.pins|Where-Object file -EQ $PSCommandPath)
if($suiteRunner.Count-ne1-or(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-ne$suiteRunner[0].sha256){throw 'Frozen isolated runner changed'}
$job=$suiteData.jobs[$Index]
$fixture=[pscustomobject]@{engine=$suiteData.engine;out=$job.out;cli=$job.cli;environment=$job.environment;requiredModules=$suiteData.requiredModules;output=$job.output}
& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=pre ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha) ('--index='+$Index)
if($LASTEXITCODE-ne0){throw 'Isolated child preparation rejected'}
`;
const tail=`& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=post ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha) ('--index='+$Index)
if($LASTEXITCODE-ne0){throw 'Isolated child proof rejected; complete observations retained'}
`;
text=preamble+text.slice(start,end)+tail;const file=path.join(__dirname,'run-child.ps1');fs.writeFileSync(file,text,{flag:'wx'});
const D=require('./comparison.cjs'),policy={version:1,kind:'private-isolated-exact-error-policy',engineSha256:'10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13',candidateManifestSha256:'98e80d4ca5f9140e88252a8615b1cdb64197343c9d69f5fc4bc05b089259fb21',contractSha256:'b29a15b0ca7d67d28a33f4938e8bce37ff582faae6db812d2e3163bf519b6898',fixtureManifestSha256:'b3be1bfa5e3551a062ac853047d3a4af9eedc8b68ff631bc6c0eb2671532fbfe',cases:Object.fromEntries(D.cases.map(name=>[name,{reviewRequired:D.potentialErrors.has(name),reviewed:false,expected:{engine:[],stdout:[],stderr:[]},normalizations:[],reviewEvidence:[],reason:D.potentialErrors.has(name)?'Potential error observation: actual closed original/candidate logs must be reviewed; no expected text is invented.':'No errors expected; unknown output/errors reject.'}])),scope:'Default source-only policy. Potential error cases remain BLOCKED until actual role/channel logs are reviewed and explicitly pinned. Only capsule-path and reviewed exact role-frame line normalization is supported; messages, categories, ordering and missing frames are never discarded.'};fs.writeFileSync(path.join(__dirname,'error-policy.json'),JSON.stringify(policy,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({runner:file,runnerSha256:sha(file),policyCases:D.cases.length,nativeStarts:0}));
