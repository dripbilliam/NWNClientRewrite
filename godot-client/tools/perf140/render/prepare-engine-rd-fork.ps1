[CmdletBinding()]
param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-rd-thread-return-v1',
 [switch]$PristineForAB
)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderDirectory=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
if(Test-Path -LiteralPath $renderDirectory){throw 'Existing engine evidence is preserved; use a fresh stage'}
$renderArchive=Join-Path $renderProject '.cache/native-text-build/godot-source.tar.gz'
$renderArchiveHash=(Get-FileHash -LiteralPath $renderArchive).Hash.ToLowerInvariant()
if($renderArchiveHash-ne'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef'){throw 'Pinned original engine archive drifted'}
$renderSource=Join-Path $renderDirectory 'source'
New-Item -ItemType Directory -Path $renderSource -Force|Out-Null
& tar -xf $renderArchive -C $renderSource --strip-components 1
if($LASTEXITCODE-ne0){throw 'Private verified archive extraction failed'}
$renderFile=Join-Path $renderSource 'servers/rendering/rendering_server_default.cpp'
$renderOriginal=[IO.File]::ReadAllText($renderFile)
$renderNeedle="`t`tserver_thread = Thread::MAIN_ID;`n`t} else {`n`t`t_finish();"
if(([regex]::Matches($renderOriginal,[regex]::Escape($renderNeedle))).Count-ne1){throw 'Pinned engine finish context changed'}
$renderReplacement=@'
		server_thread = Thread::MAIN_ID;
		// _assign_mt_ids() transferred the main device to the rendering task.
		// That task has now finished and cannot use the device again. Return
		// ownership to this thread before DisplayServer destroys its screens
		// and RenderingDevice during normal engine shutdown.
		if (RenderingDevice *rd = RenderingDevice::get_singleton()) {
			rd->make_current();
		}
	} else {
		_finish();
'@
$renderReplacement=$renderReplacement.Replace('\t',"`t").Replace("`r`n","`n")
Copy-Item -LiteralPath $renderFile -Destination (Join-Path $renderDirectory 'rendering_server_default.pristine.cpp')
$renderOriginalHash=(Get-FileHash -LiteralPath $renderFile).Hash.ToLowerInvariant()
$renderPatchedFile=Join-Path $renderDirectory 'rendering_server_default.patched.cpp'
[IO.File]::WriteAllText($renderPatchedFile,$renderOriginal.Replace($renderNeedle,$renderReplacement),[Text.UTF8Encoding]::new($false))
if(-not$PristineForAB){Copy-Item -LiteralPath $renderPatchedFile -Destination $renderFile}
$renderPatch=Join-Path $PSScriptRoot 'godot-rd-thread-return.patch'
Copy-Item -LiteralPath $renderPatch -Destination (Join-Path $renderDirectory 'godot-rd-thread-return.patch')
$renderReceipt=@{version=1;directory=$renderDirectory;source=$renderSource;initialSourceState=$(if($PristineForAB){'pristine'}else{'patched'});originalRepository='https://github.com/godotengine/godot';originalCommit='ed1daf0bf001b61586d9930840f2f1394092c079';archive=$renderArchive;archiveSha256=$renderArchiveHash;originalTargetSha256=$renderOriginalHash;changedTargetSha256=(Get-FileHash -LiteralPath $renderPatchedFile).Hash.ToLowerInvariant();patchSha256=(Get-FileHash -LiteralPath $renderPatch).Hash.ToLowerInvariant();sharedSourceChanged=$false;sharedEngineChanged=$false;buildStarted=$false;onlyAuthoredSourceChange='servers/rendering/rendering_server_default.cpp: Return main RD owner to caller after rendering task joined.'}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'manifest.json'),($renderReceipt|ConvertTo-Json -Depth 4))
$renderReceipt|ConvertTo-Json -Depth 4
