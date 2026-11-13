param([Parameter(Mandatory)][ValidatePattern('^check-assets-local-[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$doorProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$doorWorkspace=Split-Path -Parent $doorProject
$doorServer=Get-Process -Id 35640 -ErrorAction Stop
$doorBefore=@{id=$doorServer.Id;name=$doorServer.ProcessName;start=$doorServer.StartTime.ToUniversalTime().ToString('o')}
$doorEndpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction Stop
if(-not @($doorEndpoint|Where-Object OwningProcess -eq 35640).Count){throw 'Protected original server does not own UDP5121'}
$doorSecure=Get-Content -LiteralPath (Join-Path $doorWorkspace 'runtime-logs/local-multiplayer-server/native-test-key.dpapi') -Raw|ConvertTo-SecureString
$doorPayload=$null
try{$doorPayload=@{cdKey=[Net.NetworkCredential]::new('',$doorSecure).Password;password=''}|ConvertTo-Json -Compress}finally{$doorSecure.Dispose()}
$doorStart=[Diagnostics.ProcessStartInfo]::new()
$doorStart.FileName='node';$doorStart.WorkingDirectory=$doorWorkspace;$doorStart.UseShellExecute=$false;$doorStart.CreateNoWindow=$true;$doorStart.RedirectStandardInput=$true
$doorStart.ArgumentList.Add((Join-Path $PSScriptRoot 'check-assets-local-host.mjs'));$doorStart.ArgumentList.Add($Run)
$doorChild=[Diagnostics.Process]::Start($doorStart)
try{$doorChild.StandardInput.Write($doorPayload);$doorPayload='';$doorChild.StandardInput.Close();$doorChild.WaitForExit()}finally{$doorPayload=''}
$doorAfter=Get-Process -Id 35640 -ErrorAction Stop
$doorPreserved=$doorAfter.ProcessName-eq$doorBefore.name-and$doorAfter.StartTime.ToUniversalTime().ToString('o')-eq$doorBefore.start
@{protectedOriginalServerUnchanged=$doorPreserved;exit=$doorChild.ExitCode;server='127.0.0.1:5121'}|ConvertTo-Json -Compress
if(-not$doorPreserved-or$doorChild.ExitCode-ne0){exit 1}
