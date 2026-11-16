param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+\.json$')][string]$Report,[ValidateSet('roundtrip','cancel','failure','nui','vault','sync')][string]$Scenario='roundtrip',[Alias('Fixture')][ValidatePattern('^vault-handoff-fixtures-v[0-9]+\.json$')][string]$FixtureReport='',[string]$SyncFixture='',[ValidateSet('none','cancel','failure')][string]$SyncRecovery='none',[switch]$OriginGc)
$ErrorActionPreference='Stop'
# NWN79_HANDOFF_RETIRED: the original Electron fixture cannot be launched.
throw 'Original-host handoff scenarios are retired. Use tools/nwn79/run-direct-handoff-roundtrip.ps1 when its Godot scenario is available.'
