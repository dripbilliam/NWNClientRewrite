param([string]$LedgerPath=(Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'))
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ledger=[IO.Path]::GetFullPath($LedgerPath)
if(-not$ledger.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Ledger escaped workspace'}
$data=Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json
$paths=@('electron/main.cjs','electron/network_ipc.cjs','electron/preload.cjs')
$modules=@{}
$lines=@{}
foreach($path in $paths){
 $module=@($data.moduleRecords | Where-Object {$_.oldPath -eq $path})
 if($module.Count -ne 1){throw ('Missing or duplicate module record: '+$path)}
 $modules[$path]=$module[0]
 $source=@(& git show ('HEAD:'+$path))
 if($LASTEXITCODE -ne 0 -or $source.Count -lt 10){throw ('Original Electron source unavailable: '+$path)}
 $lines[$path]=$source
}
function Add-PendingRow([string]$path,[string]$symbol,[int]$line,[string]$kind,[string[]]$callers=@()){
 $qualified=$path+'::'+$symbol+'@'+$line
 $module=$modules[$path]
 if(@($module.functions | Where-Object {$_.oldQualifiedSymbol -eq $qualified}).Count){return}
 $row=[ordered]@{
  oldSymbol=$symbol
  oldQualifiedSymbol=$qualified
  status='pending'
  evidence=@()
  kind=$kind
  gap='Original Electron function or callback inventoried; exact normal Godot replacement caller and parity evidence pending'
  godotReplacement=''
  actualGodotCaller=''
  oldLocation=$path+':'+$line
  oldCallers=@($callers)
 }
 $module.functions+=([pscustomobject]$row)
}
$bridgeByChannel=@{}
$preload='electron/preload.cjs'
Add-PendingRow $preload 'moduleBody' 1 'module side effect' @('electron/main.cjs::createWindow@12')
for($i=0;$i -lt $lines[$preload].Count;$i++){
 $line=$lines[$preload][$i];$number=$i+1
 if($line -match "contextBridge\.exposeInMainWorld\('([^']+)'"){
  Add-PendingRow $preload ('exposeInMainWorld['+$Matches[1]+']') $number 'context bridge registration' @('electron/main.cjs::createWindow@12')
 }
 if($line -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*:\s*(.+?)(?:,)?\s*$'){
  $name=$Matches[1];$body=$Matches[2]
  $bridge=if($number -lt 8){'debugTools'}elseif($number -lt 13){'runtimeLog'}else{'nativeNetwork'}
  Add-PendingRow $preload ($bridge+'.'+$name) $number 'bridge method' @('Electron renderer via window.'+$bridge+'.'+$name)
  foreach($match in [regex]::Matches($body,"(?:networkInvoke|ipcRenderer\.(?:invoke|send|on))\('([^']+)'")){
   $channel=$match.Groups[1].Value
   if(-not$bridgeByChannel.ContainsKey($channel)){$bridgeByChannel[$channel]=@()}
   $bridgeByChannel[$channel]+=$preload+'::'+$bridge+'.'+$name+'@'+$number
  }
  if($body -match 'const listener='){
   Add-PendingRow $preload ($bridge+'.'+$name+'.listener') $number 'event callback' @($preload+'::'+$bridge+'.'+$name+'@'+$number)
  }
 }
}
$main='electron/main.cjs'
Add-PendingRow $main 'moduleBody' 1 'module side effect' @('historical Electron executable entrypoint')
for($i=0;$i -lt $lines[$main].Count;$i++){
 $line=$lines[$main][$i];$number=$i+1
 foreach($match in [regex]::Matches($line,"\bapp\.(whenReady|on)\((?:'([^']+)'\s*,)?")){
  $event=if($match.Groups[2].Success){$match.Groups[2].Value}else{'ready'}
  Add-PendingRow $main ('app.'+$event) $number 'Electron lifecycle callback' @('Electron app lifecycle')
 }
 foreach($match in [regex]::Matches($line,"\bwindow\.(once|on)\('([^']+)'")){
  Add-PendingRow $main ('window.'+$match.Groups[2].Value) $number 'Electron window callback' @($main+'::createWindow@12')
 }
 if($line -match 'chooseMods:async sender=>'){Add-PendingRow $main 'chooseMods' $number 'IPC dependency callback' @('electron/network_ipc.cjs::network:mods-folder')}
 if($line -match 'chooseInstall:async sender=>'){Add-PendingRow $main 'chooseInstall' $number 'IPC dependency callback' @('electron/network_ipc.cjs::network:install')}
}
$ipc='electron/network_ipc.cjs'
Add-PendingRow $ipc 'moduleBody' 1 'module side effect' @($main+'::moduleBody@1')
for($i=0;$i -lt $lines[$ipc].Count;$i++){
 $line=$lines[$ipc][$i];$number=$i+1
 foreach($match in [regex]::Matches($line,"\bhandle\('([^']+)'") ){
  $channel=$match.Groups[1].Value
  $callers=if($bridgeByChannel.ContainsKey($channel)){@($bridgeByChannel[$channel])}else{@('Electron renderer IPC channel '+$channel+'; preload caller unresolved')}
  Add-PendingRow $ipc ('handle['+$channel+']') $number 'IPC handler' $callers
 }
 foreach($match in [regex]::Matches($line,"\bcurrent\.(on|once)\('([^']+)'")){
  Add-PendingRow $ipc ('watchSession.'+$match.Groups[2].Value) $number 'session event callback' @($ipc+'::watchSession@14')
 }
 if($line -match 'persistCharacter:'){Add-PendingRow $ipc 'connect.persistCharacter' $number 'session callback' @($ipc+'::connect@58')}
 if($line -match 'onDiagnostic:'){Add-PendingRow $ipc 'connect.onDiagnostic' $number 'session callback' @($ipc+'::connect@58')}
 if($line -match 'invalidateLobbyResources\(sender\)'){Add-PendingRow $ipc 'return.invalidateLobbyResources' $number 'returned method' @($main+'::createWindow@12')}
 if($line -match 'attach\(window\)'){Add-PendingRow $ipc 'return.attach' $number 'returned method' @($main+'::createWindow@12')}
 if($line -match "sender\.once\('destroyed'"){Add-PendingRow $ipc 'attach.destroyed' $number 'window event callback' @($ipc+'::return.attach@'+$number)}
 if($line -match "window\.on\('close'"){Add-PendingRow $ipc 'attach.close' $number 'window event callback' @($ipc+'::return.attach@'+$number)}
}
foreach($path in $paths){
 $module=$modules[$path]
 $module.functions=@($module.functions | Sort-Object {[int](($_.oldLocation -split ':')[-1])},oldQualifiedSymbol)
 $module.moduleComplete=$false
}
$data.inventoryStatus='mechanical pending inventory including Electron bootstrap, IPC handlers and preload bridge methods; no whole-runtime completion claim'
$count=0
foreach($module in $data.moduleRecords){$count+=@($module.functions).Count}
$data.sourceInventory.mechanicalCandidateCount=$count
$data.sourceInventory.method='Mechanical literal import closure from HEAD old entrypoints, line-based named declarations, and targeted supplemental Electron bootstrap/IPC/preload callback rows. Inventory can still omit other computed, anonymous or runtime-selected functions; manual AST/caller review remains required before complete=true.'
$data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ledger -Encoding utf8
foreach($path in $paths){Write-Output ($path+': '+@($modules[$path].functions).Count+' rows')}
