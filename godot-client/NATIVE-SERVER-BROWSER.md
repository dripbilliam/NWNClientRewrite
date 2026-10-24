# Native server browser and transient login

Status: **local browser/admission core verified; public-server parity remains open**.
UI remains the current priority, followed by rendering and combat. No Arelith
connection or Internet discovery request was made for this milestone.

Main Menu → Multiplayer opens a native Godot server browser before connection.
It has Direct, Internet, History and Favorites views; address/UDP port, player
name, masked server password and masked optional CD key; server query details;
name/module/player/ping sorting; text and vault/password filters; bounded pages;
and private server-row identities. A successful connection proceeds to the
existing character selector rather than uploading a preset character. Opening
Multiplayer while connected retains the existing character/export/disconnect UI.

The production host deliberately enables **only 127.0.0.1:5121**. It checks that
policy before either DNS/query or login construction. The Internet view is
visible but Refresh is disabled. The service has an injected discovery provider
and exact endpoint policy for future explicitly authorized testing; no launcher
option currently enables public endpoints. Server-requested portal transfers
remain disabled. This milestone therefore does **not** establish readiness for
Arelith/master-server handoffs, public authentication, or live NWSync admission.

The subsequent [NWSync milestone](NATIVE-NWSYNC.md) verifies actual owned-local
manifest downloads, mounted resources, progress/cancellation and cached/repair
logins. Public NWSync admission and handoffs remain unaccepted; endpoint policy
is unchanged.

Queries reuse `electron/server_browser.mjs`; admission/resources/vault policy
continue through the existing shared backend. Godot never submits a server path,
character path, packet, or substituted public key. The owned server's existing
public-key pin is retained. Passwords and one-login keys are cleared immediately
from native controls after submission, and again on close/connection replacement;
service/controller copies are scrubbed on success, failure and stale input.
Leaving the key blank uses the existing Windows-protected key in Options.

`native-server-browser.json` in the existing application profile stores only
safe server metadata and the last endpoint/player name. Favorites and History
are deduplicated/capped at100 and written atomically. The original JS browser's
localStorage history/favorites are imported only when the native file is absent.
Malformed existing files are preserved with an error. Passwords, keys, resource
URLs and arbitrary server objects are excluded. The integration test uses a
separate external temporary browser store and character vault.

Native controls lock immediately while waiting for backend acknowledgement.
Backend generations and private view IDs reject stale actions and late queries.
Cancel connection invalidates the pending lobby owner, disconnects and drains its
preparation before another login is allowed; the host rejects and disconnects a
session prepared for a retired owner. Browser shutdown drains queries/store work
and pending login cancellation. Catalog packets omit full descriptions so128
maximal rows cannot exceed the native transport frame; selecting a row retrieves
its complete bounded description from the private catalog.

## Evidence

- `reports/native-browser-creation-local-v3.json`: **40 checks**, actual local
  UDP query, Direct favorite, History after admission, native15-page creation,
  canonical character export, clean disconnect/reconnect, and **two animated
  moving world admissions**. A new store instance reads back the isolated
  favorite/history/last endpoint. Native exit0, services retired, no native or
  renderer errors. This extends the previous accepted creator evidence; the
  previous server-vault-only35-check run remains separately recorded.
- `reports/browser-ui-native-v5.json`: **22 authored Godot GUI checks**, clean
  engine log. Covers connection replacement, secret clearing/masking/limits,
  error retry, private row selection, policy controls, pagination, actual panel
  pointer bounds, and synthetic pointer dispatch at a1200×850 viewport. This is
  authored GUI evidence, not physical keyboard/mouse or accessibility acceptance.
- `reports/browser-lobby-ui-regression-v2.json`: **20 checks**, clean log; pending-login Cancel plus existing
  selection/preview/create/export/save/disconnect controls retain their behavior.
- `reports/native-browser-node-regression-v2.log`: **119 tests pass**, no failures
  or skips: canonical endpoint validation, no-provider-call policy enforcement,
  atomic persistence/recreation/failure recovery, credential stripping/scrubbing,
  private handles, delayed query/login cancellation and owner retirement,
  maximal catalog transport size, and existing protocol/lobby/creation/settings/level-up regressions. The focused browser/protocol/lobby run separately passes49 tests.
- `reports/browser-creation-ui-regression-v1.json`: **16 creator GUI checks**,
  clean engine log; existing native text flush, submit/cancel, portraits and validation remain intact.
- The rendered native Direct view was reviewed in
  `reports/native-browser-creation-local-v3-browser.png`.

Rejected attempts remain distinct. The first run exposed a probe advancing before
the favorite commit completed; controls now lock on submission. The next probe
still referenced the hidden old lobby Connect button. Its reference was corrected
to the browser. The initial pointer test used an unspecified headless viewport;
the passing test uses an explicit game-window size and press/release frames.
None of those earlier failed reports is accepted as gameplay evidence.

## Remaining

Public discovery/authentication, approved non-local endpoints and pin policy,
master-server handoffs, real public NWSync resource admission, broader failure
and password-server cases, native original artwork/fonts/help/accessibility,
physical-device checks and broader creator appearance/voice coverage are
still open. Native browser core does not complete UI migration, rendering/combat
parity, single-player migration or the sustained moving-scene60FPS objective.
