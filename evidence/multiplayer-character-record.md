# Character record presentation, 2026-10-20

Target: installed NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. REA/Ghidra inspection was read-only. The original program and user sessions were not patched.

The previous in-game character window was a plain definition list. Both `GameUi` and `NetworkPanels` now use `CharacterRecordView`: narrow black/gold panel, title and close control, three icon tabs, portrait, race/alignment/classes, six ability scores and modifiers, AC/HP/XP/next-level summary, and independently scrollable combat details. Skills and feats have selectable icon rows and an independent description pane. Refreshes retain selection, list and description scroll; changing character/resource identity resets them. Skill/feat shortcut drags use the existing validated quickbar paths.

## Binary observations

| Function/call site | Observation used |
| --- | --- |
| `0x1409b6380` | General character `SetData` formats portrait/identity, abilities, vitals and lower combat list. Full retained pseudocode and assembly were inspected. |
| `0x1409b7351` | XP reads client stats `+94`, next to TLK314/315 formatting. |
| `0x1409b9986`, `0x1409b9bc8`, `0x1409b9e0a` | `+98` is Fortitude, `+9a` Reflex, `+99` Will. This differs from their wire order. |
| `0x1407b2740` | S inventory/character record reader populates these offsets and combat-information nodes. Existing160 original-code reader cases remain passing. |
| `0x1407ec3a0` | Ability modifiers use active `CHARGEN_ABILITY_NEUTRAL_VALUE`/`CHARGEN_ABILITY_MODIFIER_INCREMENT`, including signed division behavior. |
| `0x1407ef2f0`; `0x140781e80` | Alignment text uses thresholds31/70 and active TLK112–120. Creature stat update's first alignment SHORT becomes `+c6` (Good/Evil), second `+c8` (Law/Chaos). |
| `0x1407f3da0` | Next-level threshold uses the active rules XP array indexed by total class level. The renderer uses the active `exptable.2da`, not a fixed progression formula. |
| `0x1407f4070`, `0x1407f6590`, `0x1407f27c0`, `0x1407f2990` | Iterative attack display, monk interval rules, critical ranges and damage-node text. Damage labels/cost strings/colors/qualifiers come from active `iprp_damagecost`, `damagetypes`, `damagetypegroups`, racial types and TLK. |
| `0x1409bffb0`, `0x1407f0bf0` | Skill row visibility uses received skill flags. Values use received signed skill totals; singleplayer asks its existing effective-skill providers. |
| `0x1409bf640`, `0x1409c04b0` | Selecting skills/feats fills the description pane. |
| `CNWSkill::GetDescriptionText 0x1402ae920`, `CNWFeat::GetDescriptionText 0x1402a1200` | Description text is fetched through active TLK, not assembled from fixed English rules. |

The available installed `gui_char_icons`128x64 atlas contains the eye, skills figure, weapon and book artwork. Atlas regions were visually identified in an isolated offline fixture; those crop coordinates are a presentation reconstruction, not proven native UV-call arguments. Original `gui_chrsht_str/dex/con/int/wis/cha`16x16 images are used directly. When the actual tab model and its atlas are present they remain available for native raster decoration. This installation has the `gui_chrsht_tabs` TXI but no TGA/DDS; readable/icon fallbacks are retained instead of showing black tabs. Window geometry and scrollbars are CSS reconstructions of the supplied screenshots, not execution of the original GUI renderer.

## Validation

- Final build: `backups/animations/character-record-build-v5.txt`.
-42 focused character, audio, cache and installed-scene tests pass: `character-record-final-focused-v1.txt`.
- Singleplayer installed Prelude/wizard: statistics, skills and feats pages; effective values and native descriptions; server-side GUI pages0/1/2; repeated close/reopen without accumulating consumers. No renderer errors or new interaction failures. `character-record-local-v3.txt`, `live-character-sheet-ui.json`, and page screenshots.
- Separate unchanged vanilla server on UDP5124: production renderer/preload/IPC; existing level1 server-vault wizard; explicit Play with no upload; all three sheet pages,20 skill and7 feat icons, descriptions, close, and two server-confirmed walks. No uncaught renderer errors. Curated report: `character-record-validation-v1.json`.
- Offline active Arelith context: record list scroll600→600, description120→120, selected row retained, tab return600, different server identity resets to0; no HTTP. `character-record-scroll-v1.json`.

Unknown/unreceived server values remain unavailable rather than being inferred from local combat calculations. Broader character-record features, every combat-mode/conditional preview and exact native window resizing are not claimed complete. Existing server-selector preview and inventory/store layouts remain separate follow-up UI work.

## Performance work accompanying the creator goal

Cached content admission now enumerates the local object directory once rather than opening97,820 individual blob headers before entry. Offline real cached manifest measurement:5912.3ms before,586.5ms after;100,282 references ready, zero HTTP, identical demanded classes/feat bytes. Blob integrity/decompression checks and repair remain on actual resource demand. UI labels distinguish checking cached content from transferring downloads. See `creation-experience-admission-before-v1.json` and `creation-experience-admission-after-v1.json`.

Canonical network updates no longer wait for asynchronous scene asset preparation. A separate ordered presentation owner retains animation/effect events, with area and actor-identity checks. Model parse/inheritance sources and decoded PLT palettes are scoped to the current area/resource owner; model instances, palettes applied to textures, transforms, game IDs and animation clocks remain independent.

A real foreground test exposed an unrelated persistent frame exception: the journal GUI cue could be queued with `OBJECT_INVALID` before admission and unlocked after the local player ID changed. The generic audio adapter then created a positional panner without a source position. GUI cues now remain centered. A regression replays that ID change. Before correction the fixture repeatedly aborted frame callbacks; final25-second vanilla test has no uncaught errors, steady10–25second samples60.3–69.3FPS, median66.8, final68.7FPS, with no pending assets/shaders or failed scene objects. This is a local Prelude result, not an Arelith/worldwide FPS guarantee.

The user requested the latest program be opened and will manually bring it to Arelith. Full modded-area loading/movement acceptance is pending that handoff. The creation/performance goal remains active.

## 2026-10-20 local-only loading follow-up

The user now restricts testing to the local server. No further remote server
connections were made in this pass. Source preparation now overlaps up to four
tile or creature-part resources. The existing consumer still instantiates and
attaches them in order, owns fallbacks/diagnostics and rejects stale owners.
The per-area walkmesh loader reads/parses each distinct WOK once; each tile
retains its own native transformed vertices. Parallel supermodel roots now
detect cycles across pending cache entries instead of mutually awaiting them;
disposed caches cannot parse late bytes or repopulate their dependency graph.

Installed 9/100/144-tile areas produce exactly the same serialized physical and
camera geometry hashes as the backed-up loader. WOK reads fall from9/100/144
to6/34/42. The100-tile warm CPU runs measured35–40ms before and23–26ms after;
the144-tile runs47–50ms before and26–27ms after. This is a mesh preparation
benchmark, not an overall FPS claim. See creation-performance-walkmesh-v1.json.

One same-server/same-character starting-room comparison measured Connect to
controlled presentation8801ms before and5656ms after, with19 objects, no failed
objects/renderer errors and no outstanding assets/shaders in either run. Area
readiness itself was3779ms versus3745ms; it did not materially improve. Separate
process shader/driver cache state was not controlled, so this single pair is
supporting observation rather than proof of a general latency ratio. Derived
assertion-checked report: creation-performance-local-load-proof-v1.json.

Manual Computer Use then completed Pavel's introduction, selected Bim's
explicit tutorial-skip option, and clicked the server-unlocked door. The100-tile
academy loaded92 objects with no failures or renderer errors. Native area-ready
acknowledgement took8692ms; all92 objects and zero pending assets/shaders were
observed at15546ms. Early binding existence at1163ms is NOT a visible-frame
measurement. A floor click moved the server-owned character from about43.6/85.4
to42.4/82.1. Later samples showed85–93FPS in this1440x960 application window.
This does not establish fullscreen/high-resolution or modded-area performance.
See creation-performance-local-academy-proof-v1.json. The automated attempts
before this manual run did not complete the campaign's dialogue gate and are
retained as failed QA runs, not transition acceptance.

Current offline creator fixturev14 again passes preserved portrait/skill
scrolling, hidden unavailable feats, active-data groups/submenus, decoded voice
sampling/disposal, profile portrait decoding and both17-model/26-texture human
and half-orc appearance paths. Zero HTTP attempts and zero errors. Cached
manifest admission recheck took432ms for97820 unique blobs/100282 references,
with zero HTTP and matching demanded classes/feat hashes.51 focused checks,
12 installed native movement/camera checks and production buildv2 pass.

The goal remains active. Cold large-area shader preparation still takes
seconds; broad modded-world and fullscreen performance acceptance remains
unproven. The latest local client is left open in the academy for further work.
