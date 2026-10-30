# Saved login profiles

Login profiles persist a label, player name and Windows-protected CD key.
Open **Login profiles…** from the Player Name dialog, the server-browser header,
or **Client Options → Interface** (Main Menu → Options → Game Options).
The browser header displays the active label; the manager shows the full label
and player name. **Save and use** creates or updates a pair and selects it.
**Use selected** switches to an existing pair, and **Delete profile** removes
that profile. The selected pair is used on the next connection and remains
selected after restarting; switching profiles does not require another restart.

Switching and editing require being disconnected with no login in progress.
This avoids changing the identity of an active connection or mixing the name
from one profile with a key still being saved. Existing connected characters
are not changed. Key/password overrides from the previous transient login are
cleared when the canonical active-profile metadata changes.

There are up to 64 named profiles; labels and player names allow 32 characters.
Labels are unique ignoring case. Keys retain the existing seven groups of five
format. Blank keys preserve an edited profile's protected key. The first profile
can reuse the existing single saved key by leaving its key blank; this is an
explicit Save action, not a silent rewrite. The legacy saved key/manual-name
mode remains available. Removing an active profile returns to that manual mode.

## Ownership

- `electron/client_settings.mjs` reads version 1 and version 2 settings, writes
  version 2 atomically, serializes concurrent changes and exposes safe metadata.
  It preserves mods and legacy settings. Profiles store ciphertext only, using
  the existing Electron `safeStorage` Windows protection for this Windows user.
- `tools/native-session-bootstrap.cjs` remains a small protected-settings broker
  with no BrowserWindow or rendering. Its child receives request/reply IPC via
  the inherited channel. `settings-broker.cjs` owns store calls; `settings-client.cjs`
  resolves current credentials at connection time rather than freezing one key
  when the program opens. Ordinary startup need not unlock the key.
- `tools/login-profile-service.mjs` owns scoped metadata views, stale/closed
  guards and mutation locking. It validates the native protocol, scrubs submitted
  keys and publishes no plaintext or encrypted key material to Godot. Opening a
  manager is read-only; user profile mutations require an explicit form action.
- `server-browser-service.mjs` adopts the active player name and publishes the
  active profile's ID/label/name. Existing stale-view and connection admission
  guards remain in force. A join arriving during a save gets a current retry
  view rather than using an unfinished profile change.
- `native_login_profiles.gd` uses the shared menu definition/builder, draggable
  window and original theme. Key entry is masked, has no context menu and is
  cleared on submission, rejection, hiding, closing and session reset. Saved
  keys are never read back into native controls. Original Player Name and
  browser header buttons open this same manager. UI construction remains Godot.

Raw keys travel only through existing local native input and inherited broker
IPC when needed. Profile commands/replies are excluded from area recordings;
only safe metadata leaves the protected store for presentation. Profile views
and these new test reports contain no real keys, key hashes or ciphertext. Owned local/action/creation test
credentials supplied through the private pipe stay ephemeral and do not overwrite
a saved profile. Diagnostic fixtures do not allow profile mutations.

## Validation

966 checks passed on the final native sources:

| Receipt | Checks |
| --- | ---: |
| `native-login-profiles-node-current-v3.tap` | 82 |
| `native-login-profiles-ui-final-v2` | 21 |
| `native-login-profiles-original-final-v2` | 809 |
| `native-login-profiles-entry-final-v2` | 35 |
| `native-login-profiles-refresh-final-v2` | 19 |

The Node tests cover protected persistence/reopening, explicit legacy-key reuse,
CRUD/uniqueness/failures, active-key removal, IPC/dynamic key selection, ephemeral
fixture credentials, exact next-login name/key pairing, protocol bounds, locks,
stale callbacks, key scrubbing and existing browser/settings behavior. Native
tests cover actual pointer actions, masked input, scoped form actions, credential
clearing, late replies, locked state, original login entry points and unchanged
refresh behavior. Native debugger receipts pin source hashes and report no
exception or engine/lifetime errors. The manager screenshot was reviewed at
`reports/native-login-profiles-ui-final-v2.png`.

`native-login-profiles-protected-current-v2.json` independently verifies actual
Windows protection, persistent pair selection after recreating the store and
real inherited IPC. It uses two fake keys in an isolated workspace directory;
neither appears as plaintext in its saved file. It does not modify user accounts.

`native-login-profiles-startup-current-v3` checks the real launcher/broker/native
Main Menu with zero server connections. This task did not restart a manual
session or join a public server. Earlier failed native form fixtures are
retained: the first test clicked before initial container layout and used the
wrong overlay layer; the corrected test uses the production layer and waits for
layout. Product actions were not weakened to satisfy it.

Backup: `backups/native-login-profiles-v1.zip`.
Audit: `reports/native-login-profiles-audit-v1.json`.
These receipts do not complete the wider UI parity or migration goal.
