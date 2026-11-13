function Test-OwnedCreationArgument {
 param([string]$CommandLine,[string]$Argument)
 if(-not$CommandLine){return $false}
 $escaped=[Regex]::Escape($Argument)
 return [Regex]::IsMatch($CommandLine,'(?:^|\s)(?:"'+$escaped+'"|'+$escaped+')(?=\s|$)')
}
function Assert-OwnedCreationLaunch {
 param([Parameter(Mandatory)]$Debugger,[Parameter(Mandatory)]$Native,[Parameter(Mandatory)][string]$ExpectedRuntime,[Parameter(Mandatory)][string]$ReportFile,[DateTime]$Now=[DateTime]::Now)
 if(-not$Debugger-or-not$Native-or[int]$Debugger.ProcessId-le0-or[int]$Native.ProcessId-le0-or[int]$Native.ProcessId-eq[int]$Debugger.ProcessId){throw 'Owned process IDs are invalid'}
 if($Debugger.ExecutablePath-ne'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe'-or-not(Test-OwnedCreationArgument $Debugger.CommandLine ('--report='+$ReportFile))){throw 'Exact already-running owned debugger identity differs'}
 if([int]$Native.ParentProcessId-ne[int]$Debugger.ProcessId-or$Native.ExecutablePath-ne$ExpectedRuntime-or-not(Test-OwnedCreationArgument $Native.CommandLine ('--report='+$ReportFile))-or-not(Test-OwnedCreationArgument $Native.CommandLine 'res://native_session_world.gd')){throw 'Exact owned native child identity differs'}
 if(-not($Native.CreationDate-is[DateTime])-or-not($Debugger.CreationDate-is[DateTime])){throw 'Owned launch creation times unavailable'}
 $launchDelta=($Native.CreationDate-$Debugger.CreationDate).TotalSeconds
 $nativeAge=($Now-$Native.CreationDate).TotalMinutes
 if($launchDelta-lt0-or$launchDelta-gt30-or$nativeAge-lt0-or$nativeAge-gt20){throw 'Owned launch creation times differ'}
}
