param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-server-vault-picker-v1',[Parameter(Mandatory=$true)][string]$ProtectedKeyFile,[switch]$Headless,[switch]$AppearanceRoundTrip)
$ErrorActionPreference='Stop'
if(Get-NetUDPEndpoint -LocalPort 5126 -ErrorAction SilentlyContinue){throw 'Owned probe port is occupied; existing session preserved'}
$vaultProbePipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
$vaultProbePipe=[IO.Pipes.NamedPipeServerStream]::new($vaultProbePipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
$vaultProbeStart=[Diagnostics.ProcessStartInfo]::new();$vaultProbeStart.FileName='node';$vaultProbeStart.UseShellExecute=$false;$vaultProbeStart.CreateNoWindow=$true;$vaultProbeStart.WorkingDirectory=(Get-Location).Path
$vaultProbeStart.ArgumentList.Add((Join-Path $PSScriptRoot 'test-native-server-vault-preview.mjs'));$vaultProbeStart.ArgumentList.Add('--run='+$Run);$vaultProbeStart.ArgumentList.Add('--private-login-pipe='+$vaultProbePipeName)
if($Headless){$vaultProbeStart.ArgumentList.Add('--headless=true')}
if($AppearanceRoundTrip){$vaultProbeStart.ArgumentList.Add('--appearance-roundtrip=true')}
$vaultProbeProcess=[Diagnostics.Process]::Start($vaultProbeStart)
try{
 $vaultProbeSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
 try{$vaultProbePlain=[Net.NetworkCredential]::new('', $vaultProbeSecure).Password;$vaultProbePayload=@{cdKey=$vaultProbePlain}|ConvertTo-Json -Compress}finally{$vaultProbePlain='';$vaultProbeSecure.Dispose()}
 $vaultProbeTimeout=[Threading.CancellationTokenSource]::new(20000);$vaultProbePipe.WaitForConnectionAsync($vaultProbeTimeout.Token).GetAwaiter().GetResult()
 $vaultProbeBytes=[Text.Encoding]::UTF8.GetBytes($vaultProbePayload);$vaultProbePipe.Write($vaultProbeBytes,0,$vaultProbeBytes.Length)
}finally{$vaultProbePayload='';if($vaultProbeBytes){[Array]::Clear($vaultProbeBytes,0,$vaultProbeBytes.Length)};$vaultProbePipe.Dispose();if($vaultProbeTimeout){$vaultProbeTimeout.Dispose()}}
$vaultProbeProcess.WaitForExit();exit $vaultProbeProcess.ExitCode
