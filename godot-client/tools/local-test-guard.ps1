function Assert-NativeLocalTestAvailable([string]$Project, [int]$PreserveOriginalPid = 0) {
    $nativeProject = [IO.Path]::GetFullPath($Project).Replace('\', '/').TrimEnd('/')
    $nativeConflicts = @()
    foreach ($nativeProcess in Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(nwmain|nwmain-windows|electron|Godot.*)\.exe$' }) {
        $nativeCommand = [string]$nativeProcess.CommandLine
        $nativeEditor = $nativeProcess.Name -like 'Godot*' -and $nativeCommand -match '(?:^|\s)--editor(?:\s|$)' -and $nativeCommand.Replace('\', '/').Contains('--path "' + $nativeProject + '"')
        $preservedOriginal = $PreserveOriginalPid -gt 0 -and $nativeProcess.ProcessId -eq $PreserveOriginalPid -and $nativeProcess.Name -eq 'nwmain.exe'
        if ($preservedOriginal) {
            Write-Output "Original NWN PID $PreserveOriginalPid preserved by explicit option; functional checks only, no clean FPS benchmark."
        } elseif ($nativeEditor) {
            Write-Output "Project editor PID $($nativeProcess.ProcessId) preserved; functional checks only, no clean FPS benchmark."
        } else {
            $nativeConflicts += $nativeProcess
        }
    }
    if ($nativeConflicts.Count) {
        throw ('Existing game preserved: ' + (($nativeConflicts | ForEach-Object { $_.Name + ' PID ' + $_.ProcessId }) -join ', '))
    }
}
