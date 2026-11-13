param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-original-resource-baseline-v1',
 [string]$Install='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall',
 [string]$SourceProfile='C:/Users/Niflheim/Documents/Neverwinter Nights.0')
$ErrorActionPreference='Stop'
$originalProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$originalReport=Join-Path $originalProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $originalReport){throw 'Original benchmark report already exists'}
$originalExecutable=Join-Path $Install 'bin/win32/nwmain.exe'
$originalSha=(Get-FileHash -LiteralPath $originalExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
if($originalSha-ne'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'){throw 'Pinned original executable required'}
$originalRunning=@(Get-CimInstance Win32_Process|Where-Object {$_.Name-eq'nwmain.exe'})
if($originalRunning.Count){throw 'Preserve the existing original game; no second benchmark copy is started'}
$originalHome=Join-Path ([IO.Path]::GetTempPath()) ('nwn-original-resource-benchmark-'+[Guid]::NewGuid().ToString('N'))
$originalStarted=$false
try {
New-Item -ItemType Directory -Path $originalHome|Out-Null
foreach($directory in @('localvault','logs','override','portraits','hak','tlk','modules','servervault','temp','tempclient')){New-Item -ItemType Directory -Path (Join-Path $originalHome $directory)|Out-Null}
# Use existing licensed local configuration, never print/hash its key. This
# ephemeral native profile is outside source/checkpoints and must be removed
# after the specifically owned original process exits. User profiles are read only.
foreach($name in @('cdkey.ini','nwnplayer.ini')){Copy-Item -LiteralPath (Join-Path $SourceProfile $name) -Destination (Join-Path $originalHome $name)}
$originalSettings=[IO.File]::ReadAllText((Join-Path $SourceProfile 'settings.tml'))
function Set-OriginalTomlValue([string]$Text,[string]$Table,[string]$Key,[string]$Value){
 $tablePattern='(?ms)(^[\t ]*\['+[Regex]::Escape($Table)+'\][^\r\n]*\r?\n)(.*?)(?=^[\t ]*\[|\z)'
 $tableRegex=[Regex]::new($tablePattern)
 if(-not$tableRegex.IsMatch($Text)){throw ('Original settings table is unavailable: '+$Table)}
 return $tableRegex.Replace($Text,[Text.RegularExpressions.MatchEvaluator]{param($m)
  $body=$m.Groups[2].Value;$keyRegex=[Regex]::new('(?m)^([\t ]*)'+[Regex]::Escape($Key)+'[\t ]*=[^\r\n]*')
  if(-not$keyRegex.IsMatch($body)){throw ('Original settings key is unavailable: '+$Key)}
  return $m.Groups[1].Value+$keyRegex.Replace($body,[Text.RegularExpressions.MatchEvaluator]{param($k)$k.Groups[1].Value+$Key+' = '+$Value},1)
 },1)
}
$originalModes=& (Join-Path $originalProject '.cache/native-window/nwn-window-modes.exe')|ConvertFrom-Json
$originalScreen=@($originalModes.screens|Where-Object {-not $_.primary})|Select-Object -First 1
if(-not$originalScreen){throw 'Secondary monitor is required for the original benchmark'}
$originalWidth=[Math]::Min(1440,[int]$originalScreen.size[0]-96);$originalHeight=[Math]::Min(900,[int]$originalScreen.size[1]-96)
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window' 'mode' '"windowed"'
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window.windowed' 'width' ([string]$originalWidth)
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window.windowed' 'height' ([string]$originalHeight)
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window.windowed.position' 'mode' '"remember"'
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window.windowed.position' 'x' ([string]([int]$originalScreen.position[0]+48))
$originalSettings=Set-OriginalTomlValue $originalSettings 'graphics.window.windowed.position' 'y' ([string]([int]$originalScreen.position[1]+48))
[IO.File]::WriteAllText((Join-Path $originalHome 'settings.tml'),$originalSettings)
$originalAliases=@('[Alias]',('HD0='+$originalHome+'\'))
foreach($name in @('LOCALVAULT','SERVERVAULT','OVERRIDE','PORTRAITS','HAK','TLK','MODULES','TEMP','TEMPCLIENT')){$originalAliases+=($name+'='+$originalHome+'\'+$name.ToLowerInvariant()+'\')}
[IO.File]::WriteAllLines((Join-Path $originalHome 'nwn.ini'),$originalAliases)
$originalWizard=Join-Path $Install 'data/lcv/wizard.bic';Copy-Item -LiteralPath $originalWizard -Destination (Join-Path $originalHome 'localvault/wizard.bic')
$originalStart=[Diagnostics.ProcessStartInfo]::new();$originalStart.FileName=$originalExecutable;$originalStart.WorkingDirectory=Split-Path $originalExecutable -Parent;$originalStart.UseShellExecute=$false;$originalStart.CreateNoWindow=$true
foreach($argument in @('-userdirectory',$originalHome,'+connect','127.0.0.1:5121')){$originalStart.ArgumentList.Add($argument)}
$originalBegan=[DateTime]::UtcNow;$originalProcess=[Diagnostics.Process]::Start($originalStart)
$originalStarted=$true
$originalProof=[ordered]@{run=$Run;pid=$originalProcess.Id;startedUtc=$originalBegan.ToString('o');executable=$originalExecutable;sha256=$originalSha;endpoint='127.0.0.1:5121';profile=$originalHome;temporaryLicensedProfile=$true;originalProfilesModified=$false;characterSha256=(Get-FileHash -LiteralPath $originalWizard -Algorithm SHA256).Hash.ToLowerInvariant();screen=[int]$originalScreen.index;requestedWindow=@($originalWidth,$originalHeight);scope='Owned original client on the existing authoritative localhost Prelude server. Startup metadata only; not a timing or parity acceptance receipt.'}
$originalProof|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $originalReport -Encoding utf8
[pscustomobject]$originalProof|Select-Object run,pid,endpoint,screen,requestedWindow|ConvertTo-Json -Compress
} catch {
 if(-not$originalStarted-and(Test-Path -LiteralPath $originalHome)){
  $originalAbsolute=[IO.Path]::GetFullPath($originalHome);$originalTemp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if($originalAbsolute.StartsWith($originalTemp+'\',[StringComparison]::OrdinalIgnoreCase)-and([IO.Path]::GetFileName($originalAbsolute)).StartsWith('nwn-original-resource-benchmark-')){Remove-Item -LiteralPath $originalAbsolute -Recurse -Force}
 }
 throw
}
