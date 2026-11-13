param([Parameter(Mandatory=$true)][string]$FileToParse)
$ErrorActionPreference='Stop'
$parseTokens=$null
$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($FileToParse,[ref]$parseTokens,[ref]$parseErrors)
if($parseErrors.Count){$parseErrors|ForEach-Object{$_.Message};exit 1}
