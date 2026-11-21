[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Plan,
 [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ReviewedPlanSha,
 [Parameter(Mandatory)][ValidateSet('control','candidate')][string]$Variant,
 [Parameter(Mandatory)][ValidatePattern('^native-production-local-[a-z0-9-]{1,48}$')][string]$Run,
 [ValidateRange(60,600)][int]$TimeoutSeconds=300,
 [switch]$Execute
)
$ErrorActionPreference='Stop'
if(-not $Execute){throw 'Preparation only. Root must review the plan/server identity and authorize -Execute; no client or server was started.'}
throw 'The legacy Electron production-local runner is retired. No client or server was started.'
