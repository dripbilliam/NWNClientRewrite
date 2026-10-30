# Native multiplayer character creation

## Current direct-native entry

The normal `join-native.ps1` entry now owns all fifteen creation pages, rules,
recommendations, validation, typed BIC writing, portraits, appearance preview and
voice samples in Godot. `src/character_creation.js` and the old JS creation
services are reference only; the protocol host rejects their imports. It receives
only a finished BIC for the existing original upload protocol. Authentication,
downloads and packet encoding/decoding remain in the existing protocol bridge.

From Multiplayer, connect to a server, choose **Create character**, make or
recommend choices, then **Review → Play**. The original server decides admission.
Local-vault and create-on-server upload selection uses the admitted server policy.
The current direct-native live checks cover the local-vault Prelude campaign;
server-vault-only creation still needs a fresh check on this route.

### Owners and server data

- `systems/native_creation.gd`: connection-owned draft, private view/control
  handles, resource queue and submit/cancel lifecycle.
- `systems/native_data/creation_rules.gd`: active physical 2DA rows, prerequisites,
  point allocation, class/racial feats, skills, spell choices and package preferences.
- `systems/native_data/creation_bic.gd`, `gff_writer.gd`: native first-level BIC,
  original field widths/struct types, starting items from active UTIs and CP1252.
- `systems/native_creation_preview.gd`: the same native creature/model/palette/
  texture/animation pipeline as the world, in a Godot SubViewport. No GLB staging.
- `systems/native_creation_voice.gd`: active soundset/SSF selection and original
  resource bytes decoded and played by Godot. Repeated samples cycle codes 0–48.

Classes, races, spells, feats, class spell-table columns, prerequisite tables,
starting packages/items and recommendation resources use the connection's resolved
catalog, including module/HAK, NWSync, Workshop and override precedence. The creator
has no embedded stock spell or feat lists. Custom TLKs, including female variants,
are resolved natively. Replacing the catalog retires previous tables and TLKs;
native preparation caches use content identities. Missing selectable packages
remain explicit rather than being replaced with a guessed stock package.

Native workers prepare resources and BICs. A draft scope prevents a cancelled
worker from submitting into a reopened creator. Submitted characters wait for
the server; rejection restores Review. Disconnect drains owned work. This does
not make the client authoritative over character legality.

### Current evidence

- `reports/native-creation-ui-final-v1.json`: 103 checks, all eleven original base
  classes, native BIC generation, all pages, original animated/paletted appearance,
  actual original SSF audio, stale/out-of-range controls and cancel/reopen.
- `reports/native-creation-overrides-final-v1.json`: 15 checks with authored
  replacements over installed resources: custom class/spell column/family/feats,
  prerequisite cells, package preferences, custom TLK and a new catalog afterward.
- `reports/native-creation-prelude-v2.json`,
  `native-creation-prelude-wizard-v1.json`, `native-creation-prelude-druid-v1.json`:
  newly created Fighter/Wizard/Druid admitted by the original localhost Prelude
  server, rendered, moved under authority and exported. Wizard learned spells and
  caster feat selections survive server export. `native-creation-prelude-final-v1`
  checks the final worker-scope build separately.
- `reports/native-creation-text-regression-v1.json`: 1,025 original TLK/token/UI
  checks. `native-creation-preview-compile-v1`: 25 typed writer checks. Sixteen
  existing Node lobby regressions also pass.

Tests use normal-heap CDB and preserve failed evidence. No public connections,
native exceptions, source mutations during checks or engine/lifetime errors are
accepted. These are functionality checks, not FPS acceptance. Reproduce with:

```powershell
./godot-client/join-native.ps1 -CreationCheck -CreationClass wizard -Debugger -Run unique-creation-run
```

Use the owned original Prelude server on 127.0.0.1:5121. Creation checks do not
connect publicly or save test exports into the normal replacement character vault.
Broader server-vault/mod/content coverage, prerequisite edge cases, descriptions,
feat grouping, original window fidelity and full combat/effects remain open.

## Historical staged-client evidence (superseded by the direct-native entry)

Status: **creator core implemented; full frontend parity remains incomplete**.
Godot owns the fifteen-page creation window and its input. The existing
`src/character_creation.js` remains the rules, recommendations, validation and
typed first-level BIC writer. No character data or game artwork is copied into
this project. The existing JS client and production bundle are preserved.

From Main Menu, choose Multiplayer, connect to the owned local server and choose
Create character. The sidebar exposes Gender, Race, Portrait, Class, Alignment,
Package, Abilities, Domains/school, Skills, Feats, Spells, Appearance, Voice,
Name and Review. Recommended uses the active package's actual preference tables;
a missing table reports the error and leaves the prior draft editable. Review
lists remaining requirements; Play stays disabled until shared validation passes.

Godot receives private view/control handles, labels and display values. It never
supplies a trusted draft, arbitrary BIC, package table, portrait path or network
upload subtype. Dependent changes use the existing creation semantics. Native
text fields flush together on navigation and actions; malformed batches cannot
partially edit a draft. Current biography transport is limited to 32,768
characters, with the original CP1252/GFF validation still applied.

The portrait catalog uses active server/install/Workshop resources and the
existing medium-image availability rules. Pages have 48 entries and four bounded
image jobs. A dedicated pre-world staging cache uses the original portrait
decoder; it does not depend on a live quickbar. Selected portraits use a gold
border without tinting the original image. Appearance offers body/head/clothing
choices and swatches decoded from the original skin/hair/tattoo TGA palettes.

Rules, recommendation, thumbnail and BIC work are connection/resource/view scoped.
Cancel invalidates late work before upload. A submitted character waits for the
server; it cannot be submitted twice or falsely cancelled. Rejection restores
Review; actual area admission closes the creator. Resource/connection replacement
invalidates its controls. Shutdown drains admitted operations and image jobs.
The vault selector is locked while a creation draft is open. Local-vault servers
use the existing local-character upload; server-vault-only servers use the
existing create-on-server subtype19 path.

Evidence and remaining limits are tracked in the source contract and migration
inventory. Local tests create an authored-named level1 Fighter using actual
installed rules and original portraits, submit to the owned vanilla server,
observe native locomotion, export and compare abilities/skills/feats/portrait/
biography, disconnect, select the persisted character through the allowed vault
policy, and admit/render/animate it again. Controlled-character rigid-part
animation is measured separately from NPCs. If skins exist, the validator also
requires real skin vertex deformation; a rigid model is not required to deform
nonexistent skins. These diagnostic GPU readbacks run only in explicit tests.

Server-vault exports are local copies: a subsequent server-character selection
can create a new local export entry. The test requires the server-advertised
private reference and unique character name on reconnect, rather than assuming
that server characters retain a prior local-export UUID.

Still pending: broader native preview content/device coverage;
full descriptions/help and original font/skin fidelity; extended class/race/
custom-package/familiar/spell/device/failure coverage; larger biography transport;
and broader frontend/public-server browser behavior. Native voice sampling is now
implemented and locally verified in [NATIVE-AUDIO.md](NATIVE-AUDIO.md); full audio
migration remains incomplete. This milestone does not accept full UI, rendering,
combat, multiplayer parity or sustained60FPS. No Arelith connection is used.

The live harness drives actual native button signals and the native input adapter; isolated authored GUI checks dispatch mouse events separately. Concurrent physical mouse activity can cancel synthetic live button gestures, so this is not physical-device acceptance. The apparent long-reference failure was a competing hidden DOM selector: decoded replies showed its old selection replacing the native choice. The isolated staging build now retires that selector before login. The original JS lobby remains intact in production. Unique maximum-length server references pass the corrected local check.

Creation smoke tests now use an external temporary vault, like the other multiplayer regression modes. Twelve earlier authored test entries were moved out of the normal application character list into a verified temporary recovery directory;52 other entries and all shared BIC blobs were preserved. See `reports/native-creation-vault-cleanup.json`. No CD key or Workshop preference was changed.

Accepted creator evidence: `reports/native-creation-local-v4.json` and `reports/native-creation-servervault-v12.json` each pass35 native checks, with two actual animated admissions per policy, canonical exports, saved-character readback/selection and clean retirement. `reports/creation-ui-native-v6.json` passes16 authored GUI checks; lobby17 and level-up15 GUI checks pass. `reports/native-creation-node-regression-v5.log` has98 passing Node cases. The original editor was preserved; these are functional checks, not clean GPU/FPS benchmarks.

Latest voice extension: `reports/native-voice-creation-local-v3.json` passes48 local checks, including actual original voice samples through WASAPI, fixed sample controls, canonical soundset export and two animated admissions/reconnect. Nineteen native audio checks,16/22/20 creator/browser/lobby GUI regressions and135 Node tests pass. See [NATIVE-AUDIO.md](NATIVE-AUDIO.md) for exact scope, cleanup, retained failures and remaining audio/preview/fidelity requirements.

Original-model Appearance preview is now locally verified in [NATIVE-CREATION-PREVIEW.md](NATIVE-CREATION-PREVIEW.md):61 local checks, four head/clothing/palette previews, native idle clocks/parts, canonical exports and two animated admissions;19 rendered/18 headless preview checks and164 Node regressions. The selected idle profile reduces transfer size about86% with identical GLB geometry/texture hashes. Full creator/UI/content/fidelity and performance acceptance remain open.
