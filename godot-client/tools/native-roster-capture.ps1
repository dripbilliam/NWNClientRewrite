param([ValidateRange(30,300)][int]$Seconds=120,
      [switch]$Wire,
      [string]$SourceProfile='C:\Users\Niflheim\Documents\Neverwinter Nights.0')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$install='C:\Users\Niflheim\Desktop\Tools\Local Tools\FullDecomp\NwnRootInstall'
$native=Join-Path $install 'bin\win32\nwmain.exe'
$debugger='C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe'
$expected='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
if((Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToLowerInvariant()-ne$expected){throw 'Pinned native binary mismatch'}
if(-not(Test-Path -LiteralPath $debugger)){throw 'CDB unavailable'}
if(Get-Process -Name nwmain,cdb -ErrorAction SilentlyContinue){throw 'A native client or debugger is already running'}
$cache=[IO.Path]::GetFullPath((Join-Path $project '.cache\native-roster-capture'))
$run=Join-Path $cache ([Guid]::NewGuid().ToString('N'))
$profile=Join-Path $run 'profile'
$log=Join-Path $cache ('last-cdb'+$(if($Wire){'-wire'}else{''})+'.log')
$commands=Join-Path $run 'roster.cdb'
$process=$null
try {
 New-Item -ItemType Directory -Path $profile -Force|Out-Null
 foreach($folder in @('localvault','logs','override','portraits','hak','tlk','modules','servervault','temp','tempclient')){New-Item -ItemType Directory -Path (Join-Path $profile $folder)|Out-Null}
 foreach($name in @('cdkey.ini','nwnplayer.ini','settings.tml')){Copy-Item -LiteralPath (Join-Path $SourceProfile $name) -Destination (Join-Path $profile $name)}
 $aliases=@('[Alias]',('HD0='+$profile+'\'))
 foreach($name in @('LOCALVAULT','SERVERVAULT','OVERRIDE','PORTRAITS','HAK','TLK','MODULES','TEMP','TEMPCLIENT')){$aliases+=($name+'='+$profile+'\'+$name.ToLowerInvariant()+'\')}
 [IO.File]::WriteAllLines((Join-Path $profile 'nwn.ini'),$aliases)
 $cdb=@(
  'bp nwmain+0x7af780 ".echo EVENT resource_dispatch; gc"',
  'bp nwmain+0x7cdd20 ".echo EVENT resource_install_begin; gc"',
  'bp nwmain+0x7cefa0 ".echo EVENT resource_reload_begin; gc"',
  'bp nwmain+0x2ad110 ".echo EVENT rules_reload_begin; gc"',
  'bp nwmain+0x7a31b0 ".echo EVENT login_dispatch; gc"',
  'bp nwmain+0x705f10 ".echo EVENT character_list_owner; gc"',
  'bp nwmain+0x7c4a90 ".echo EVENT roster_request_send; gc"',
  'g'
 )
 if($Wire){$cdb=@(
  'bp nwmain+0x2522a0 ".echo EVENT lowlevel_header_and_active_slot; db @r8 L3; dd @rcx+0x28a56d8 L1; gc"',
  'bp nwmain+0x24d1e0 ".echo EVENT packetize_header; db @r8 L3; gc"'
 )+$cdb}
 [IO.File]::WriteAllLines($commands,$cdb)
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$debugger
 $start.WorkingDirectory=Split-Path $native -Parent
 $start.UseShellExecute=$false
 $start.CreateNoWindow=$true
 foreach($argument in @('-logo',$log,'-cf',$commands,$native,'-userdirectory',$profile,'+connect','127.0.0.1:5121')){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 [pscustomobject]@{cdbPid=$process.Id;log=$log;endpoint='127.0.0.1:5121';seconds=$Seconds}|ConvertTo-Json -Compress
 if(-not $process.WaitForExit($Seconds*1000)){
  $process.Kill($true)
  [void]$process.WaitForExit(5000)
 }
 if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log|Where-Object {$_ -match 'EVENT|error|Error|Break instruction|unable|Unable' }|Select-Object -Last 100}
} finally {
 if($process){if(-not $process.HasExited){$process.Kill($true);[void]$process.WaitForExit(5000)};$process.Dispose()}
 $full=[IO.Path]::GetFullPath($run)
 if($full.StartsWith($cache+'\',[StringComparison]::OrdinalIgnoreCase)-and (Split-Path $full -Leaf) -match '^[a-f0-9]{32}$'){
  if(Test-Path -LiteralPath $full){Remove-Item -LiteralPath $full -Recurse -Force}
 }
}
