# NWN-79 Godot-only runtime progress

Godot owns the normal client path: `join-native.ps1` delegates to
`join-godot.ps1`, with no Node or Electron process. Native helpers remain for
Windows DPAPI, libhydrogen and read-only installed NWSync SQLite access.
NWN-79 remains In Progress while public-server, remaining protocol, visual and
delivery acceptance is completed.

The clean Godot-only package staged on 2026-11-16 has 2,432 hash-verified
files. Its private matrix passed baseline login/world admission, browser
authentication, manual character choice, inventory/dialog, reconnect, travel,
character export and NWSync cold/warm/corrupt-cache repair, with clean exits
and zero live settings writes. Evidence:
`.cache/nwn79-current-clean-restage-20261116-b-private-matrix/matrix-summary.json`
(relative to the workspace root). This does not establish public Arelith,
ordinary in-world visual parity, or FPS acceptance.

After NWN-79 meets all acceptance criteria, continue with ready NWNAnalog
tickets that are not about FPS or CPU timing. This is the user's requested
next-work order; it does not relax NWN-79 completion requirements.

## Implemented and verified

- `native_network_session.gd` starts from saved protected settings, original
  installed build/language metadata, reliable encrypted UDP and login. It sends
  status, resolves/downloads NWSync content, requests the server character
  list, requests a preview, submits Play, acknowledges module loading and
  decodes the first area packet. It exposes phase, character and area signals.
- `native_network_inflater.gd` uses Godot's persistent `StreamPeerGZIP` zlib
  state for compressed original-server messages. The original captured `P 3/1`
  record passes without Node's zlib.
- `native_resource_requirements.gd` decodes the original `P 1/3` status record.
  `native_resource_admission.gd` checks the advertised manifests, language
  requirements, named NWM/HAK/TLK sources and available blob inventory. Servers
  without an NWSync advertisement use the same admission gate against the
  installed game and profile. Installed NWM/HAK/TLK directories now match the
  former native resource owner (`data/nwm`, `data/hk`, `data/hak`, language TLK).
- `native_nwsync_repository.gd` uses Godot HTTPRequest, bounded responses,
  verified SHA-1 and decoded size, private cache writes and corrupt-entry
  repair. Missing blobs download with at most four concurrent requests.
- `native_server_characters.gd` decodes server-vault lists and produces exact
  preview/play request packets. `native_device_properties.gd` produces the
  original format-0 GUI metric packet; the session owner can send changed
  metrics before the status request.
- A headless live Arelith run of `nwn79_native_network_session_test.gd` reached
  character selection with one entry, requested its server-vault preview,
  received a 9,931-byte BIC, submitted Play, received confirmation and
  compressed module information, sent module-ready, and decoded the first area
  packet (55 tiles, 179 static placeables). With `--enter-area`, the same
  Godot-owned session also mounts the server catalog, prepares terrain, sends
  the original `4/3` area-ready request, receives the first live world and
  stages its controlled creature through the existing Godot renderer. One
  live run staged 288 objects. It exits before playable UI/input, travel and
  reconnect. These runs used Godot and narrow native helpers only. Another
  live run of `nwn79_direct_login_probe.gd` proved the lower stages.
- `native_area_state.gd` matches the full original captured area tree field for
  field. `native_player_roster.gd` decodes player list changes and the controlled
  object ID; five saved original-session packets match its output.
- `native_object_updates.gd` decodes original A/P/U/I/G/D/W object records.
  It uses the same installed 2DA tables as the Godot asset/UI owners for item,
  class, visual-effect and skill field shapes. Five captured character packets
  now finish, including two `I` player-state records previously unhandled by
  the saved capture. Original inventory checks pass 160 format-0 observations
  and a session containing seven object-update packets, three equipped items
  and five backpack items. Unknown records still fail explicitly.
- `native_network_world.gd` stages received area, roster, object and inventory
  state without Node. The original 33-object local-session summary matches,
  including entry, time, controls and all object IDs. The Godot session now
  owns this state and can emit a presentation snapshot after a completed work
  boundary. The recorded snapshot also passes the existing Godot renderer's
  cooperative receipt and stages the controlled creature. This is a headless
  handoff check; renderer/UI attachment to the live session remains pending.
- The Godot session now exposes its admitted server archive and NWSync source
  descriptor for `SessionCatalog`, using the previous host's ordering and
  priorities. The installed Arelith content resolves to the same cached
  manifest without a Node source-descriptor step. The live session mounts that
  catalog concurrently with character selection and loads the original 2DA
  object rules from it. Playable UI attachment remains pending.
- `native_runtime_messages.gd` handles original device echo requests and
  optional login waypoint response. The captured 363 device echo packets
  decode, and their empty replies match the native wire format. The live
  Arelith first-world check passes with echo replies enabled.
- `native_module_time.gd` applies server clock changes to the Godot world;
  the live first-world entry still passes with this handler enabled. The
  first-world presentation now follows the former host's bounded 200 ms
  publication cadence because live Arelith object packets do not supply a
  final `W` count. This avoids waiting forever after area-ready.
- `native_quickbar.gd` decodes the original full/single-button server packets,
  including embedded item data through the existing Godot item reader. The
  live Arelith first-world check received and applied its quickbar packet;
  subsequent world presentations carry 36 current buttons for the UI.
- `native_player_requests.gd` encodes the original click-to-move waypoint
  request. All 35 saved native sender cases match byte-for-byte except the
  original's undefined padding bits, which are masked in the oracle. The
  Godot session sends it only for a current, admitted controlled creature and
  keeps the native byte sequence. Live movement has not been exercised yet.
- The same Godot request owner now encodes keyboard drive, stop and turn.
  All 62 saved native sender cases match after masking undefined padding;
  the session enforces current controlled-creature scope, preserves sequence
  increments for unsent cadence slots and sends only admitted operations.
  Keyboard input is connected in the Godot direct world used by the normal
  launcher.
- Native examine, conversation, attack, door open/close and object-use packets
  now match seven original sender byte cases. The direct entry routes those
  existing UI commands through the Godot session with actor/target admission
  checks. Their server responses and full UI lifecycle still require work.
- The existing renderer entry now accepts an already-mounted Godot session
  catalog directly; its gameplay UI, loading screen and renderer share that
  owner. `nwn79_direct_catalog_handoff_test.gd` passes without a Node process.
  `native_direct_session_world.gd` is the Godot-only normal entry and connects
  the session to renderer/UI, area-ready, world updates and movement in process.
- A first headless Arelith run of that direct entry reached resource/UI setup,
  then timed out before area admission: the shell waited for a controlled
  creature that the server sends only after `4/3`. The direct entry now opens
  terrain from pre-admission area state. The 33-object original local fixture
  passes this sequence on one renderer: terrain ready first, then the admitted
  controlled actor. The corrected entry passed a headless run against the owned
  private Prelude server without NWSync: its installed stock fighter BIC was
  accepted, 19 objects and 36 quickbar slots reached the existing renderer/UI,
  five snapshots arrived, the controlled creature matched server state, and
  shutdown exited cleanly. The private server was stopped afterward. This is
  an early private fixture; the later packaged normal-entry matrix is listed
  above. Public Arelith acceptance remains separate.
- Arelith's 4,184,254-byte manifest with 100,809 entries, one 37,615-byte
  blob, corrupt private manifest/blob repair and three parallel blob downloads
  passed `nwn79_native_nwsync_repository_test.gd`. The installed Arelith
  manifest, custom TLK and every required blob pass the admission check.
- Recorded native binary wire fixtures pass the login, reliable-window,
  message, resource, character-list/request and device-property tests.
- The Windows protection helper now authenticates legacy Chromium `v10`
  ciphertext with the DPAPI-wrapped profile key and AES-256-GCM through a
  private pipe. Godot's settings store re-protects and verifies every legacy
  CD key, saves a ciphertext-only backup before replacing the settings file,
  and leaves the original untouched if any profile fails. A disposable two-
  profile test passed migration, backup, idempotence and corrupt-second-key
  refusal without Node. A copy-only check of the current user profile found
  two profiles and a readable active key; it had already been upgraded, so it
  migrated zero records. The real settings file was not modified by that test.
- The direct Godot startup now resolves the installed profile, saved Workshop
  selection, NWSync cache and local character roots before the menu starts,
  using the same content descriptor the transitional host supplies. The
  `nwn79_direct_startup_ticket_test.gd` check found seven local content choices,
  mounted 90 catalog layers and read the original `pre_main` GUI from the
  installed assets. A subsequent private Prelude headless session reached the
  playable world with 19 objects, 36 quickbar slots and clean shutdown.
  The direct entry now presents the existing Godot character chooser for
  server-vault characters, or verified local BICs if the private server has
  none. The private Prelude check selected and previewed `fighter.bic` through
  the chooser request path, submitted Play, and reached the same 19-object
  world with 36 quickbar slots. Its prior first-character and named-BIC
  automatic paths remain explicit headless/development checks. Server-vault
  manual selection, graphical menu readiness, server browsing and the normal
  launcher remain unaccepted.
- The same explicit direct entry can now open the Godot main menu, enter its
  Direct browser tab and connect to the private Prelude server through the
  existing browser request signal. A headless check completed that route and
  reached the 19-object world. The check also rejected a mismatched saved
  profile name, rejected a malformed temporary CD key, and recovered to a
  successful saved-key join in the same process. The Godot session passes a
  direct-connect server password to the original challenge-response owner;
  that server-password path has only the existing identity packet test, not a
  password-protected live-server check. A temporary CD key can be used for a
  login if the saved ciphertext cannot be unlocked, without replacing the
  saved settings file; that valid-key recovery route still needs acceptance.
  Its menu layout was available, but the headless
  report had only 1/5 menu preload cohorts ready and no visible main menu;
  graphical startup and browser-list presentation were still outstanding at
  that checkpoint; the later Internet directory checks below cover fetch and
  headless selection, not graphical acceptance.
- The direct entry's Disconnect now closes its Godot network owner, retires
  the renderer/UI session, returns to the main menu and opens a fresh browser
  scope. One private Prelude process completed two sequential joins: both
  presented 19 objects and 36 quickbar slots, the second used UI generation 2,
  and shutdown exited cleanly. This verifies a local reconnect path; a live
  server travel/reconnect sequence and graphical cleanup remain outstanding.
- The original self-inventory window and panel senders now match 19 recorded
  native packet cases. Godot admits them only for the current controlled
  creature, and the direct gameplay UI routes open, page and close through
  that owner with command replies. On the private Prelude server, an open
  request produced two received inventory channels before page and close;
  all three UI requests were accepted. The direct owner now also encodes
  equip, move, drop, pickup, unequip, split, learn and equipment-toggle requests.
  It matches 115 original action cases and 130 paired-toggle cases; 120 original
  item success/cancel packets decode and reach the existing inventory UI. A
  private Prelude run sent a repository move from the Godot gameplay UI,
  received the original server's successful `inventory-result`, then paged and
  closed inventory without failure. Evidence:
  `.cache/nwn79/direct-local-item-action-20261115.json`. Container, associate,
  store and alternate inventory ownership remain explicitly rejected; graphical
  item-action presentation still needs acceptance.
- The Godot direct owner encodes Talk, Shout, Whisper, Tell, Party and DM chat
  against 40 original client sender cases, and rejects stale controlled actors
  and stale Tell-player identity. Its incoming decoder matches 43 original
  server chat packets and 32 one-liners. Original conversation entry/reply
  decoding and reply sending match the captured Prelude entry and 56 native
  sender cases; stale or unoffered replies are rejected. A private Prelude
  run sent chat through Godot, received its server echo, opened an NPC
  conversation, sent the offered reply and received the next dialog entry.
  Evidence: `.cache/nwn79/direct-local-chat-dialog-20261115.json`. This is
  headless/local validation; graphical chat/overhead and Arelith acceptance
  remain outstanding.
- A disposable Godot-only client profile and the owned `GodotBuffs1` private
  server completed an A→B→A area cycle using server chat triggers. Both new
  areas were acknowledged after Godot renderer preparation, area IDs changed
  and returned, and the UI/renderer reached generation 3 with six snapshots.
  The direct world retired the previous dialog, old area sounds and transient
  container/store inventory state on area admission. Evidence:
  `.cache/nwn79/direct-local-travel-20261115.json`. This does not substitute
  for public-server travel or graphical parity.
- The Godot browser now fetches and bounds the Beamdog Internet server list
  with `HTTPRequest`; a live fetch returned 326 valid endpoints. A headless
  browser check listed and selected an owned Prelude fixture through the
  existing Internet UI request path, joined it without Node/Electron, and
  reached the playable world. The Direct tab's mismatched-profile and invalid
  temporary-key rejection/retry path passed again after the browser change.
  Evidence: `.cache/nwn79/direct-local-directory-20261115.json` and
  `.cache/nwn79/direct-local-browser-regression-fixed2-20261115.json`.
  The existing login-profile panel now sends its create, select, delete and
  recovery actions to a Godot controller over the same view/request protocol.
  Its disposable Windows-protected store and actual panel integration tests
  passed. The direct browser refreshes the active profile after a change,
  and manual player names can accompany temporary CD keys when no saved
  profile exists. An empty-settings run rejected a malformed key, then read
  a valid existing protected key only in memory and reached the playable
  private Prelude world without saving a credential in the new settings
  directory. Evidence:
  `.cache/nwn79/direct-fresh-user-recovered-20261115.json`.
- Godot now reads and writes the existing `native-server-browser.json` format
  for History, Favorites, last server and default player name. A disposable
  legacy-format fixture passed read, write, favorite toggle and reopen checks.
  The authenticated Direct-tab join recorded History in a disposable settings
  copy; a second local run selected that History row, saved it to Favorites,
  switched tabs, selected the Favorite and joined the private Prelude world.
  Evidence: `.cache/nwn79/direct-browser-history-20261115.json` and
  `.cache/nwn79/direct-history-favorites-20261115.json`.
- Godot now sends native BNXI/BNES/BNDS UDP queries and decodes server names,
  advertised module details and the optional NWSync manifest advertisement.
  A private Prelude query returned its original server name, module and
  extended details. The existing browser's Server info action displayed the
  module detail and then joined the playable world. Evidence:
  `.cache/nwn79/direct-server-info-20261115.json`. Graphical list/detail
  acceptance and a real prior-version key upgrade remain outstanding.
- The Godot session now accepts shortcut activation and assignment from the
  existing gameplay UI. Ten original shortcut-assignment packet shapes match
  the former sender byte-for-byte. Assignment checks current actor and item
  ownership, sends the original request, and updates the client-owned layout.
  Activations cover equipment/container shortcuts, quick chat, familiar
  possession, polymorph cancel and specific-associate commands; the matching
  radial/desktop actions use the same original senders. Other spell/feat,
  dynamic-associate and targeted shortcut families still need porting and
  live acceptance. Focused sender/session tests pass; no live shortcut claim.
- `join-godot.ps1` is a Node-free development launcher and prerequisite check
  for the direct Godot entry. It prepares the pinned engine, compiled native
  helpers and resource extension, then launches Godot directly with no IPC
  broker. Its `-Headless -HeadlessCheck` route authenticated against the owned
  Prelude server, selected the pregenerated character and reached a playable
  19-object area with 36 quickbar entries and four snapshots. Evidence:
  `.cache/nwn79/godot-launcher-prelude-fixed-20261115.json`. The first attempt
  exposed a PowerShell argument-array bug; the fixed invocation passed.
- Direct profile startup imports non-secret existing settings once, records a
  durable marker and backup, and asks for key re-entry into the Godot-owned
  protected store. Old Chromium saved-key decryption is not required. The
  isolated one-time import and credential recovery checks passed; the package
  matrix consumed an already imported v3 profile. The Godot-only source guard
  covers 100 supported files in the full checkout and rejects an injected
  Node command.

## Remaining NWN-79 acceptance

1. Finish the remaining original-server protocol and UI behaviors, then verify
   them through the normal Godot entry. Private travel, reconnect, inventory,
   character export and NWSync paths have passed in the clean package.
2. Verify one-time settings import and credential failure/re-entry as separate
   acceptance rows. The old saved key does not need to be decrypted.
3. Complete public Arelith gameplay, visual and performance checks, plus any
   remaining delivery scenarios. Keep NWN-79 In Progress until these pass.

Run the focused checks from `godot-client` with the pinned Godot console binary:

```powershell
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_resource_requirements_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_server_characters_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_device_properties_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_area_state_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_player_roster_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_object_updates_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_inventory_stats_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_inventory_messages_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_world_state_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_world_state_test.gd' -- --render-world
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_resource_sources_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_resource_sources_test.gd' -- --mount
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_runtime_messages_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_player_requests_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_direct_startup_ticket_test.gd'
& '.\.tools\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script 'res://tests/nwn79_native_network_session_test.gd' -- --enter-area
```

The repository and live session checks need network access and the Windows
user's saved credential. They never print the key or character names. The
private repository test cache is under `.cache/nwn79/repository-test`.
