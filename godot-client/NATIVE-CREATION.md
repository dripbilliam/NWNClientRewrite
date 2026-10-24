# Native multiplayer character creation

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
