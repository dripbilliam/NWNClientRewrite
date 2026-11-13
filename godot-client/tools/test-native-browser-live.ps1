param([Parameter(Mandatory)][ValidatePattern('^nwn40-live-[a-z0-9-]+$')][string]$Run,[Parameter(Mandatory)][string]$ProtectedKeyFile)
$ErrorActionPreference='Stop'
foreach($ticketPort in @(5127,5128,5129,5130)){if(Get-NetUDPEndpoint -LocalPort $ticketPort -ErrorAction SilentlyContinue){throw 'A browser test port is occupied; existing session preserved'}}
$ticketPipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
$ticketPipe=[IO.Pipes.NamedPipeServerStream]::new($ticketPipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
$ticketLease=[IO.File]::Open((Join-Path $PSScriptRoot '../.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$ticketStart=[Diagnostics.ProcessStartInfo]::new();$ticketStart.FileName='node';$ticketStart.UseShellExecute=$false;$ticketStart.CreateNoWindow=$true;$ticketStart.WorkingDirectory=(Get-Location).Path
$ticketStart.ArgumentList.Add((Join-Path $PSScriptRoot 'test-native-browser-live.mjs'));$ticketStart.ArgumentList.Add('--run='+$Run);$ticketStart.ArgumentList.Add('--private-login-pipe='+$ticketPipeName)
$ticketProcess=[Diagnostics.Process]::Start($ticketStart)
try{
 $ticketSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
 try{$ticketPlain=[Net.NetworkCredential]::new('', $ticketSecure).Password;$ticketPayload=@{cdKey=$ticketPlain}|ConvertTo-Json -Compress}finally{$ticketPlain='';$ticketSecure.Dispose()}
 $ticketTimeout=[Threading.CancellationTokenSource]::new(20000);$ticketPipe.WaitForConnectionAsync($ticketTimeout.Token).GetAwaiter().GetResult()|Out-Null
 $ticketBytes=[Text.Encoding]::UTF8.GetBytes($ticketPayload);$ticketPipe.Write($ticketBytes,0,$ticketBytes.Length)
}finally{$ticketPayload='';if($ticketBytes){[Array]::Clear($ticketBytes,0,$ticketBytes.Length)};$ticketPipe.Dispose();if($ticketTimeout){$ticketTimeout.Dispose()}}
try{$ticketProcess.WaitForExit();exit $ticketProcess.ExitCode}finally{$ticketLease.Dispose()}
