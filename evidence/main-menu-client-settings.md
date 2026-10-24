# Main Menu Options: local mods and protected login key

The user requested a persistent mods-folder setting, preset to the default,
and CD-key storage through Main Menu. They explicitly chose Windows-protected
profile storage and clarified that Workshop HAKs should be globally active
with a per-mod toggle.

Options now offers Browse, Use default, enabled-mod checkboxes, a password-type
CD-key field, saved-status text, removal, Save and Back. Folder and mod choices
persist and apply on the next connection; resource changes are blocked while
that window owns a live session. Changing the folder resets its disabled IDs.
The list uses local item identifiers/content hints; live Steam display titles
and native Steam API subscription ordering are not implemented. Installed ACF
membership/order is used when present. No subscription or download is changed.

ClientSettings writes an atomic profile JSON with the selected folder, disabled
IDs and safeStorage-encrypted key bytes. Windows protection must be available;
there is no plaintext fallback. Metadata IPC returns a saved-key Boolean, never
the plaintext or encrypted key. The renderer clears the entered field/request.
An empty connection key asks the main process to decrypt the saved key directly
into the existing login identity path. It is never fetched into the renderer.
The identity remains transient and disposable. User-provided passwords remain
per-connection and are not persisted by this feature.

Only attached trusted main frames can reach these endpoints. The selected
folder reaches lobby and connection resource owners. Enabled Workshop loose
portraits use image-only admission; enabled local overrides remain a local
fallback; globally enabled Workshop HAKs form their own archive layer below
selected server content. No previous server's downloaded content is mounted
as a global mod. Disabling a mod excludes all of its supported alias directories.
Current snapshots retain their ownership while the next connection takes a new
selection. A pending old menu asset/font owner is disposed and generation-checked
when the selection changes, preventing its late completion replacing the new one.

Indexed ERF/HAK reads validate headers/key tables/bounds and open/read only the
requested resource payload, then close the handle. A changed file invalidates
the snapshot with an explicit reconnect error. Native texture source location
remains archive3. Selected-source failures are propagated without silently
substituting a lower resource. Actual per-item/within-HAK collision ordering is
the documented local ordering policy, not a complete native registration proof.

Validation:

-51 focused tests pass: settings persistence/removal/unavailable protection,
 trusted IPC and login reuse, active-session restrictions, installed membership,
 global mod activation/toggling, lazy archive reads/change detection, server
 A/B rules isolation, portrait precedence and existing NWSync/HAK priorities.
 The initial new Workshop fixture used base.key instead of nwn_base.key; it was
 corrected. An unconditional await without a settings store also disturbed an
 existing cancellation test; the optional path no longer adds that yield and
 cancellation is checked after actual settings IO. Earlier failures are retained.
- Actual packaged UI/preload/IPC test uses real Windows safeStorage with a
 synthetic key and temporary profile. It verifies disk/store recreation,
 no key readback, 19 mods/default path, saved toggle after reopening Options,
 Browse/save and removal. Both builds pass; final bundle index-DoA0JAYO.js.
 The rendered Options screenshot was visually inspected. No external fetch
 or game join is performed by this UI test.
- Offline installed-content probe opens66 HAKs and all seven recovered medium
 portraits and verifies CEP disable behavior. No proprietary payload is copied.
- A separate bounded local-only login saves the dedicated test credential in a
 temporary Windows-protected store, clears its input copy, reopens the store,
 connects with an empty renderer-key request and loads the avatar. It succeeds
 in4.80s including setup, with zero renderer errors/failed models. That run is
 index-CoHoJKyl.js, before the final menu-asset generation guard; connection,
 settings and mod modules are unchanged. The temporary protected store is
 removed and the session is disconnected without saving. No credential bytes
 or public identifier appear in the report.

The production app is opened at Main Menu Options for user review. No real key
is automatically saved to the user's permanent profile by the agent. The user
can enter it in Options or continue supplying a per-connection key. Main Menu
New/Load/Movies/News behavior is outside this change. The wider goal remains
active; missing effect ownership and broader local performance scopes remain.
