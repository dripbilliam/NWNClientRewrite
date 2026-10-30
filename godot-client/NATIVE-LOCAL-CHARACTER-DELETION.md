# Native local character deletion — partial UI parity

Local Delete now uses the original `OKCANCELPANEL`, authored models, Galahad
caption controls and active native TLK. Both the production picker and original
record page reach the same native operation. Server-vault rows remain unavailable
for deletion. Customize and complete DM-vault management remain unported.

## Original evidence

All original observations pin `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root evidence files `rea-native-character-delete-confirmation-v1.json` and
`rea-native-confirmation-label-v1.json` under `backups/animations` retain:

- `7103a0`: Delete constructs `CPanelOkCancel` and activates TLK10512/66/67
  (`0x2910/0x42/0x43`). These are the original question and **OK/Cancel** captions.
- `201fa0` and `1fe260`: the explicitly imported MessageLabel has flag4, so its
  authored width/height apply. It is not an unclaimed floating pregame label.
- `201ef0`, `201e30`, `2015a0`: accept returns1; Cancel/Escape return2.
  `CGuiMan::HandleModalPanelEscKey1f55a0` dispatches to the top modal independently
  of the focused edit. Native Escape therefore does not rely on Control focus.
- `70e5b0`: deletion targets `LOCALVAULT` or `DMVAULT`, not installed80M data.
  `CExoResMan::RemoveFile191460` clears read-only status before unlinking. Its
  result is ignored by the caller, which still removes the selected list row.
- `710420`: only result1 invokes deletion. The same visual row is selected
  afterward, or the previous row if the deleted row was last.

`scripts/inspect-native-character-delete-results.py` executes the unchanged
confirmation/result/reselection instructions in an isolated emulator. GUI
deactivation/destruction, physical deletion/list decrement and preview calls
are captured boundaries. Its55 observations are in
`backups/animations/native-character-delete-results-v1.json`. This is not a
claim that the complete original filesystem or GUI renderer was emulated.

## Native ownership and feedback

The native metadata worker supplies typed IsDM status. The existing raw file
transport additionally identifies the resolved storage role: installed, profile
or Workshop. Deletion captures connection, selected key, file path, byte count
and digest before opening the modal. It blocks competing selection/Play, and
checks current ownership again on acceptance. The native file owner checks the
approved root, loose `.bic` identity, link status, size, signature and digest
before changing attributes or removing exactly that captured file.

Cancel/Escape, stale connections, changed files and unsupported DM ownership do
not remove files. Errors remain visible. Profile/Workshop read-only files follow
the original chmod/unlink sequence; installed-only rows never change installed
bytes or attributes. A row backed only by installed data is dismissed from the
current chooser list, with explicit preserved-file feedback. A new connection
re-enumerates it, matching the distinction between list deletion and a failed
loose-vault alias removal. Resolved Workshop/profile aliases remain real file
mutations even when another enumeration row also names that resource.

After acceptance, Godot sends only a scoped key, digest and request nonce to the
existing raw-catalog service. That service rescans and acknowledges membership;
it does not delete files, decode BIC presentation, upload a character or invent
server success. Native metadata must settle before post-delete row selection.
Negative refresh acknowledgments release ownership and display refusal feedback;
late work cannot publish into a replacement connection.

The read-only attribute implementation uses Godot's documented
[FileAccess API](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-set-read-only-attribute).
Original installation and user character files were not modified by automation.
All destructive checks used owned copies inside uniquely named report folders.

## Validation and remaining work

`native-delete-final-input-v1` passes95 native checks:55 original instruction
observations plus actual native dialog input/artwork, bounded text, No/Escape,
acceptance, changed-byte refusal, ownership, read-only files, installed dismissal,
negative refresh, typed DM guard and owned cleanup. Its `.confirmation.png` was
reviewed. The first graphical attempt exposed an out-of-frame floating label;
that failure of appearance acceptance is retained and the bounded-label fix is
verified. Old test labels sometimes call the acceptance Yes/No; the actual source
captions remain the original OK/Cancel.

Earlier regressions are `native-delete-current-picker-v1`41 checks,
`native-delete-current-cache-v1`22 and `native-delete-current-metadata-v1`61.
The protocol coordinator has25 unit cases, including raw rescan ownership,
negative acknowledgments, late results and installed-row lifetime.

The owned original-server regression is `native-delete-local-current-v1`:
7 admission,18 player-page,12 exact native record-input and170 authoritative
action checks. It tests ordinary native local-vault admission/actions alongside
the new role metadata; it does not automate Delete over the full live bridge.
Native destructive input/file tests and catalog-service checks are separate
evidence. The connected follow-up below addresses this initial IPC gap;
these earlier receipts remain historical, not current-source acceptance.

## Connected native Delete follow-up

`test-native-actions.ps1 -LocalVault -LocalDelete` now creates two disposable
copies beside a separate owned admission character. The running Godot client
uses actual pointer/key input, its native confirmation/file owner and the real
`lobby-local-refresh` transport. The raw catalog service must rescan and return
the matching connection/key/nonce; the probe never supplies an acknowledgment.
The host independently checks both files are absent and both raw rows retired
before admitting the untouched character to the original loopback server.

The first run (`native-delete-ipc-local-v1`) exposed a probe holding a row
across a metadata-publication frame. It was stopped as an owned failed test.
The next run (`native-delete-ipc-local-v2`) completed actions but was rejected
for a real client error: a row's `gui_input` could trigger a caption rebuild
which immediately freed that same signal owner. `rebuild_rows` now hides and
detaches retired rows immediately and queues destruction after dispatch. The
focused regression deliberately invalidates captions inside real row input;
it must emit one current selection without a locked-object error. An active
confirmation also no longer incorrectly reports that class tables are loading.

`native-delete-ipc-local-v3` passed the original-style connected flow. The final
`native-delete-ipc-production-v1` additionally opens the production picker on
the same connection and deletes the second copy through its actual controls.
It passes33 connected checks,7 native admission checks,12 exact-BIC original
record-input checks and170 authoritative action checks. Source hashes remain
unchanged, the native process exits normally, workers retire and preview
storage clears. No public gameplay connection is made. Both confirmation and
refreshed production-picker screenshots were visually reviewed. Artwork is
explicitly awaited for the confirmation capture; the earlier bare capture is
retained as an unaccepted visual observation.

Current focused safeguards are `native-delete-ipc-input-final-v1`95 native
checks and `native-row-signal-retirement-final-v1`18. The coordinator's25
unit cases remain separate evidence. `audit-native-local-delete-live.mjs`
checks these receipts, current source hashes, exact IPC ownership/membership,
owned-file cleanup and the verified rollback checkpoint. This accepts the
covered connected Delete paths, not the complete character picker or UI.

Remaining gaps include DM-vault enumeration/management, exported-vault metadata
management, duplicate alias edge cases and all original disk-failure variants,
prompt-sound playback, Enter/Tab and other modal key details, relevant UI scales,
fullscreen and direct original-client pixel/gesture comparison. Customize is
still unavailable. The entire native UI objective remains active and unaccepted.
