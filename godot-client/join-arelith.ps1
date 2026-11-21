param([string]$PlayerName='',[string]$ProtectedKeyFile='',[string]$Server='',[switch]$StagedRenderer)
$ErrorActionPreference='Stop'
if(-not$StagedRenderer){
 & (Join-Path $PSScriptRoot 'join-native.ps1') -PlayerName $PlayerName -ProtectedKeyFile $ProtectedKeyFile -Server $Server
 exit $LASTEXITCODE
}
$root=Split-Path $PSScriptRoot -Parent
if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot '.cache/local-bridge/latest.json'))){throw 'Build the native resource bridge first.'}
$report='public-browser-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'.json'
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Join-Path $root 'node_modules/electron/dist/electron.exe'
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
foreach($argument in @((Join-Path $PSScriptRoot 'tools/local-host.cjs'),'--public-servers',('--report='+$report),'--native-verbose')){$start.ArgumentList.Add($argument)}
if($PlayerName){$start.ArgumentList.Add('--player-name='+$PlayerName)}
if($Server){$start.ArgumentList.Add('--join-server='+$Server)}
if($ProtectedKeyFile){
 $loginPipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
 $start.ArgumentList.Add('--private-login-pipe='+$loginPipeName)
 try{
  $loginSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
  $loginPlain=[Net.NetworkCredential]::new('', $loginSecure).Password
  $loginPayload=@{cdKey=$loginPlain}|ConvertTo-Json -Compress
 }finally{$loginPlain='';if($loginSecure){$loginSecure.Dispose()}}
 $loginPipe=[IO.Pipes.NamedPipeServerStream]::new($loginPipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
}
Write-Output 'Opening native Godot server browser; choose your server and character.'
Write-Output ('Connection status: '+(Join-Path $PSScriptRoot ('reports/'+$report.Replace('.json','.status.json'))))
$process=[Diagnostics.Process]::Start($start)
if($ProtectedKeyFile){
 try{
  $loginTimeout=[Threading.CancellationTokenSource]::new(20000)
  $loginPipe.WaitForConnectionAsync($loginTimeout.Token).GetAwaiter().GetResult()
  $loginBytes=[Text.Encoding]::UTF8.GetBytes($loginPayload)
  $loginPipe.Write($loginBytes,0,$loginBytes.Length)
 }finally{$loginPayload='';if($loginBytes){[Array]::Clear($loginBytes,0,$loginBytes.Length)};$loginPipe.Dispose();if($loginTimeout){$loginTimeout.Dispose()}}
}
$process.WaitForExit()
exit $process.ExitCode
