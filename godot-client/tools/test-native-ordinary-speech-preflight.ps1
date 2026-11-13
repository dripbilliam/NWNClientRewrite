param([ValidatePattern('^[a-z0-9-]+$')][string]$Label='powershell-preflight-current-v1')
$ErrorActionPreference='Stop'
$ordinaryProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ordinaryFiles=@((Join-Path $ordinaryProject 'join-native.ps1'),(Join-Path $PSScriptRoot 'test-native-ordinary-speech-live.ps1'))
foreach($ordinaryFile in $ordinaryFiles){
 $ordinaryTokens=$null;$ordinaryErrors=$null
 [Management.Automation.Language.Parser]::ParseFile($ordinaryFile,[ref]$ordinaryTokens,[ref]$ordinaryErrors)|Out-Null
 if($ordinaryErrors.Count){throw 'PowerShell parser rejected ordinary preflight'}
}
$ordinaryJoin=Get-Content -LiteralPath (Join-Path $ordinaryProject 'join-native.ps1') -Raw
$ordinaryHeader=$ordinaryJoin.Substring(0,$ordinaryJoin.IndexOf('if($LevelUpSourceCheck-and'))
$ordinaryGuard=[scriptblock]::Create($ordinaryHeader)
& $ordinaryGuard -ScriptFloatingCheck -OrdinarySpeechCheck -ScriptFloatingDirectory 'C:\private-fixture-placeholder' -Headless -LocalOnly -ProtectedKeyFile 'C:\not-read.dpapi' -EngineRuntime editor -Run native-script-floating-ordinary-v1
$ordinaryRejected=0
foreach($ordinaryArgs in @(@{OrdinarySpeechCheck=$true},@{ScriptFloatingCheck=$true;OrdinarySpeechCheck=$true;Headless=$true;LocalOnly=$true;ProtectedKeyFile='not-read';ScriptFloatingDirectory='fixture';Server='public.example'},@{ScriptFloatingCheck=$true;OrdinarySpeechCheck=$true;LocalOnly=$true;ProtectedKeyFile='not-read';ScriptFloatingDirectory='fixture'})){
 try{& $ordinaryGuard @ordinaryArgs;throw 'Unexpected selector acceptance'}catch{if($_.Exception.Message-eq'Unexpected selector acceptance'){throw};$ordinaryRejected++}
}
if($ordinaryRejected-ne3){throw 'Selector negative gates missing'}
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $ordinaryProject
$ordinaryOutput=Join-Path $ordinaryProject ('.cache/ordinary-speech/'+$Label+'.json')
if(Test-Path -LiteralPath $ordinaryOutput){throw 'Existing preflight evidence retained'}
[ordered]@{success=$true;checks=6;powerShellParsed=2;selectorAccepted=1;selectorRejected=3;noBuild=$true;engines=0;keyReads=0;source='Exact current join header extracted before any launch/key/build boundary; placeholders are never read.'}|ConvertTo-Json|Set-Content -LiteralPath $ordinaryOutput
'PowerShell/current no-build preflight clean6; no launch/key read.'
