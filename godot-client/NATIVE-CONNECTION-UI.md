# Native connection UI — in progress

The complete original browser/login/character-selection migration is unfinished.
The [server-page follow-up](NATIVE-SERVER-PAGES.md) now supplies the main-flow
source Internet/History/Favorites owners and connected controls. Its explicit
remaining-work list still prevents acceptance of the entire browser.
The [server-filter follow-up](NATIVE-SERVER-FILTERS.md) now owns the original
Additional Filters modal, persistence and modern row predicates. It does not
replace the remaining generic list pages or certify the whole browser.
`native_direct_connect.gd` now presents the installed `DIRECTCONNECT` GUI through
the shared native pregame painter. It is one dialog in that larger flow, not an
acceptance of the entire connection UI or of its visible parity.

## Original evidence

`../backups/animations/rea-native-connection-dialogs-v1.json` retains13 read-only
static dossiers from original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Roles are explicitly labeled:8d44d0 initializes Direct Connect,8d3e50 initializes
Player Profile, and8d3c60 initializes the password-only panel. Mixing those
initializers would assign the wrong controls and password behavior.

Direct Connect8c3460/8d44d0 binds the address/password edits, OK8d1000 and shared
Cancel/X8cdec0. Address Enter confirms; Escape cancels. The address field receives
initial focus. Its three pregame labels use unbounded source caption anchors;
edit placement comes from `text0/text1` model hooks rather than a generic box.
All frame/button models, captions and fonts resolve natively from the independent
installed/user-enabled pregame catalog. Current source mutations are not ignored
in favor of copied coordinates. Missing required controls fail explicitly.

Connection constructor706e40 parses the first colon, uses its CRT decimal suffix
when its stored length exceeds one, uses5121 for a zero result in ordinary
client mode and stores a nonzero result's low16 bits. The native adapter follows
that presentation parsing; the existing service still validates the resulting
IPv4/hostname, port and session authorization. Original embedded-server/default
port modes and permissive address edge cases are not certified by this work.

Profile8d0c90 requires a name, strips its original byte whitelist, truncates to32
bytes on confirmation and requires another confirmation after a correction.
Its invalid/missing-name messages are66104/66256. Checkbox7331 actually reads
“Save As Default”; modern acceptance8cdb20 conditionally persists
`client.identity.name`. The native Player Name integration below now uses these
policies. All original profile roles and visible/input states are not yet certified.

## Integration and state ownership

`native_pregame_menu.source_ready` exposes its existing native painter, text and
catalog to the browser. Dialog resources prepare before a world exists; they do
not depend on active server rules or a JS presentation. Direct-tab Connect and
the browser's Direct Connect action open the source dialog. The latter also
works from saved-server pages without a selected server row. The remaining
browser and CD-key editor remain generic controls awaiting migration. The generic
name display is read-only when its native Player Name owner is installed.

Opening or canceling does not query or join any server. OK/address Enter sends
the existing `browser-input/join` with a direct endpoint and current player/key
draft to the protocol/login owner. Protected saved-key behavior is unchanged.
The dialog captures connection and view IDs; pending/denied admission, stale
views and retired held presses cannot issue a new join. A fresh Enter remains
usable after a retired mouse press. Cancel/X/Escape return to the browser.
Password editors clear on dismissal, submission and session/view retirement;
snapshots and prepared resources contain no credentials.

Invalid current-view service input now publishes a fresh authoritative retry
view before propagating its error. Previously the native sender disabled its
controls but the generic error notice could leave them disabled indefinitely.
This recovery cannot unlock another pending query or revive a retired view.
Service tests use injected providers; they perform no real network connections.

The browser closes its private dialog workers before the shared pregame painter
retires, including actual session shutdown and the startup-check cleanup route.
Generic browser-only tests no longer load an unused world client or initialize
the dialog's asset-script graph without a catalog owner.

## Verification and remaining work

Initial Direct Connect checkpoint receipts (historical source):

- `native-direct-connect-headless-v4`:33 source-model/native input/lifecycle
  checks, including actual pointer dispatch, address Enter, X/Cancel, browser
  Escape delegation, held-press retirement, busy/capability gates, saved-page
  access, scoped canonical requests and credential cleanup.
- `native-direct-browser-final-v1`:22 existing native browser regression checks.
- `native-direct-entry-layout-final-v1`:136 original Main/Options layout and
  executed original-policy oracle comparisons.
- `native-direct-browser-service-final-v1.tap`:24 protocol/storage/service tests,
  including invalid-address retry and conflicting-query refusal.

Debugger runs passed with unchanged pinned source, normal heaps and no trapped
exceptions, script errors or lifetime leaks. The earlier failed runs remain as
diagnostics: a retired OK mouse press initially blocked fresh Enter; one test
calculated a click before list layout settled; the old browser-only test loaded
unused asset dependencies and leaked script resources. These failed receipts
are not accepted evidence.

Headless tests do not certify pixels, artwork crop, original edit/caret metrics,
password glyphs, scaling, pointer hover presentation, button audio, clipboard/IME
or original-client side-by-side comparison. Direct Connect currently masks its
transient password deliberately; its initializer does not itself set the mask
font, unlike the password-only panel. Inherited original edit behavior remains
to be established rather than claiming this is exact visual parity.

The original persists the last direct address before attempting a connection.
The current service retains failed attempts during its lifetime but saves
history/default endpoint after success; exact persistent failed-address behavior
is still a gap. Seven-part CD-key entry, password-only
dialogs, connection status/cancel screens, full server-list/filter/details pages,
all multiplayer entry roles and native character selection/creation remain
unfinished. These initial receipts predate the Player Name/local-admission
follow-up below. No automated public connection was made.

To repeat the offline dialog check with a new run name:

```powershell
& ./godot-client/tools/test-native-kernel-debugger.ps1 `
  -Run native-direct-connect-next `
  -Script res://tests/native_direct_connect_test.gd `
  -TestArguments @('--install=C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall')
```

## Player Name and real local admission follow-up

`native_player_profile.gd` now presents original `MULTI_LOGIN` and `OKPANEL`
models, fonts, unbounded labels, nested Save As Default checkbox and edit hooks.
Main Menu → Multiplayer opens Player Name before the browser. The browser also
offers Player Name for changing the next login identity. Initial-profile Cancel/X
returns to Main Menu; dialog warnings dismiss before the profile itself.

`player_profile.gd` follows the original confirmation ordering: empty input warns;
invalid bytes/leading dots and spaces are removed and warn; only a subsequent
unchanged confirmation applies the32-byte length limit, again warning before
acceptance. Names are not silently truncated while typing. The independent
oracle `../backups/animations/native-player-profile-observations-v1.json` contains
781 executions of unchanged original8d0c90/16c4f0/16bcb0 instructions, including
the byte corpus and boundary/correction cases. Reproduce it with
`py -3 scripts/inspect-native-player-profile.py` from the workspace. Existing
evidence is intentionally not overwritten. The byte whitelist covers the original
Windows1252 profile; unrelated Unicode/IME behavior is not certified.

Confirm sends `browser-input/profile` to the existing storage/session owner.
The accepted name changes only after its scoped `browser-profile-result` returns.
Save As Default atomically updates the local default name; leaving it unchecked
changes the session identity while retaining the prior persistent default. Later
successful connection history cannot overwrite that distinct default. Existing
browser files migrate their previous name as the initial default. Native profile
names retain original accepted trailing spaces through the connection adapter;
legacy generic/launcher name normalization is otherwise unchanged. No password
or private key is added to this name storage. The effective protected-key owner
reports whether it actually holds a key, including isolated test credentials.

Pending/failed/stale/canceled storage operations cannot fabricate a committed
identity. A storage refusal uses the original OK notice and permits retry with
the next authoritative browser view. The notice uses an input shield, rather
than changing the underlying profile buttons' appearance: disabling them made
the source checkbox's disabled artwork misleadingly appear checked. Native
graphical review caught that defect and the corrected screenshot was reviewed.
Fresh keyboard confirmation and retired mouse presses remain independent.

Owned action tests now enter through the real native profile and Direct Connect
owners instead of the host directly calling `lobby.join`. Only the isolated
original server127.0.0.1:5125 is accepted by this probe. The host requires its
seven-check native admission proof before starting the actual connection, records
the accepted identity/endpoint and then runs the existing authoritative gameplay
suite. No manual/public session is involved. The user explicitly authorized
replacing the previously open replacement client for these tests; only that
identified client was closed. The original NWN client was preserved.

Current settled-source evidence:

- `native-player-profile-final-v1`:809 original-oracle/native graphical control,
  focus, notice, pending/refusal/retry and lifetime checks. Source Player Name
  and notice screenshots were reviewed at1200×850, scale1.
- `native-direct-connect-visual-v1`:35 original Direct Connect/source input and
  lifecycle checks; its native screenshot was reviewed at the same viewport.
- `native-player-profile-browser-final-v1`:22 existing browser regressions.
- `native-player-profile-entry-final-v1`:136 original Main/Options source and
  original-instruction policy comparisons.
- `native-player-profile-service-final-v1.tap`:29 injected service/protocol and
  persistence tests. A later audit reruns/pins this service suite separately.
- `native-player-profile-local-v1`:seven native admission checks followed by170
  original-server authoritative gameplay checks. Endpoint127.0.0.1:5125,
  public connections0, normal native exit0, debugger armed, no native exception,
  unchanged pinned source and workers joined on cleanup.

The graphical profile test recorded secondary monitor1, primary0,
unfocusable=true, focused=false and visible uncaptured mouse mode0. No physical
pointer movement/capture or original-client operation was used. A preexisting
scene-wind warning remains in the gameplay receipt; it is not a new profile failure.

At this milestone full startup was **not accepted**. The comprehensive user-content MenuCheck
exceeds its existing20-second watchdog while exercising the installed catalogs,
model preparation/cancellation and UI preloading/cancellation. In a retained
headless diagnostic its seven Main/Options/Profile/browser route checks passed,
but the whole run failed; another graphical run also timed out. The earlier
headless art-gate failure, timeout receipts and incomplete captures remain failed
evidence. The headless probe now explicitly reports routes-only and does not
certify artwork; graphical probes still require completed original art. Do not
count partial route success as a passing comprehensive startup check or remove
the timing issue from the remaining-work ledger. Its detailed stage costs remain
to be isolated; the recorded90-layer pregame mount alone took about7.1 seconds.

The later [UI cancellation follow-up](NATIVE-UI-CANCELLATION.md) identifies and
fixes unused catalog work after Cancel. Its full graphical startup/preload check
passes with the same watchdog/art requirements; the old timeout receipts remain
failed historical evidence. This does not complete the wider connection/UI audit.

## Next original navigation tier

Read-only dossiers in `../backups/animations/rea-native-multiplayer-entry-v1.json`
identify a missing `PRE_MULTIPLAYER` modal between Main and the browser/direct
dialog. Constructor708290 and initializer713510 bind six original actions:
New711570, Load710c30, Internet7107e0, LAN710840, Direct710480 and Cancel70f740.
Client-server mode disables New/Load and grays their captions. DM mode replaces
the two source background textures. Internet constructs the five-page
`SERVERLIST_PANEL` owner8c37c0; LAN constructs the separate owner8c1f50. Direct
keeps its7137e0 continuation rather than unconditionally returning to the generic
browser. Cancel may clear the session player name when no configured default
exists. Main710fd0 only opens Player Name when the current application identity
is empty; otherwise it goes straight to the multiplayer modal. These omissions
are now addressed in the [Multiplayer entry follow-up](NATIVE-MULTIPLAYER-ENTRY.md),
including provider cancellation when returning from the browser. Hosting/LAN,
the complete original browser, roles and broader visual comparison stay open.

This is scoped native presentation/input and local-admission progress. Original
client side-by-side comparison, other scales, exact caret/selection/password
glyphs, audio, clipboard/IME, legacy default-checkbox initialization, profile
reason/DM/host variants, failed-address persistence, full browser/filter/details,
CD-key/password/connection status, character selection and the rest of the entire
UI inventory remain required. Keep the full UI goal active.
