# Native class and feat ability radials

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and complete hash-verified PE instruction captures were used.
No original executable, assets or Ghidra project were changed.

## Original decisions

`src/feat_radial.js` ports these complete decision owners:

| Owner | Original address | Compared executions |
| --- | --- | --- |
| Class ability collector |14098f550..14098f7bc|486|
| Class ability page |14098fbf0..1409904ae|1083|
| Feat leaf |1409957a0..140995f0b|1268|
| Feat variant creator |140991230..1409914a2|216|
| Radial selection |140998520..1409987c9|504|

All3557 observations execute the original owners. Metadata, normal/bonus
ownership, remaining uses, allocation, string/icon/menu presentation and
outbound target/input helpers are captured boundaries. `GetSubRadialSpell`
runs unchanged. These comparisons do not establish native GUI rendering,
replicated client storage, picking, packets or lower server simulation.

The class collector keeps physical class order. It groups castable cleric
domains or two qualifying owned class feats; OnMenu must equal1, not merely
nonzero. A null class-feat record stops the collector but is skipped by the
class-page owner. The grouping helper140998960 is true for classcount>3, else
reads `ui.radial.class-abilities.always-show-as-subradial` with defaultfalse.
Grouped menus suppress feat1089 in class lists; the root can show it separately.

Class pages follow successors only while the direct next WORD is owned, then
collapse duplicates. They preserve domain entries on the first page and native
7/8-slot continuation arithmetic. Feat leaves use the signed-positive raw INT
successor check, distinct from class pages and from server highest-feat lookup.
Raw high successor bits can merge into packed auxiliary fields and are retained.
Variant menus preserve physical child holes, parent use counts and TargetSelf
restrictions. Submenu creation itself bypasses the ordinary leaf disabled flag;
its children decide separately. Unlimited100 clears ordinary leaf/variant counts;
the separate domain constructor retains its own count behavior.

Selection handles compiled modes, direct input6 for non-self contexts and
retargeting from self menus. Its auxiliary normalization differs from hotbar
initialization. The existing shared input6/UseFeat/cast runtime is reused; no
per-spell execution cases were added to the UI.

## Active metadata and live menu

`feat_radial_rules.js` projects active classes/FeatsTable/feat/spells/domains,
canonical normal and bonus ownership, live remaining uses and familiar identity.
LoadFeatsTable14029a9a0, GetClassFeat1402997f0, LoadDomainInfo1402a7f60,
GetDomain1402a3ba0 and domain constructor14029c540 were inspected. The native
class loader's shrinking WORD bound on invalid feat rows is preserved; reads
from untouched allocation remain explicit errors. Missing resources stay
diagnosed. These metadata projections have targeted tests and installed sweeps;
the full metadata loaders were not instruction-emulated in this change.

GameUi replaces its local fixed Class abilities placeholder with the ordinary
root140994d10/class entry140991610 layout: direct class/leaf slots5-index when
small and ungrouped, otherwise slot4 class submenu and separate1089. More-class
entries use the physical class index. Native TLK references and active icons
supply labels. The local `classAbilitiesAlwaysSubradial` boolean supplies the
grouping preference; a complete native settings frontend is not claimed.
Use counts now render in the shared radial presenter. Native visual placement,
hover timing, preview range and complete visual styling remain separate work.

Familiar possession and Craft/Taunt/Search/Stealth execution are still explicit
diagnosed requests. The DM ability tree and the separate Special attacks root
remain open. The local defensive-stance/familiar fields are projections of
shared simulation state, not an implemented native replication protocol.

## Validation and limits

All39 unchanged installed BIC presets traverse the metadata-backed ordinary
menu without invalid slots, duplicate slots or warnings
(`installed-feat-radial-v2.json`). This sweep captures uses100 and synthetic
text; it does not execute every class feat or establish every effect.

Actual hidden Electron druid run (`live-feat-radial-ui.json`,
`feat-radial-ui-v3.txt`) selects unchanged installed druid.bic. It first drags
owned WildShape338 to F2/type4, casts and restores. Then right-click Player
actions ->Special abilities ->Druid at native slot5 ->Wild Shape opens five
physical variants1008..1012. Brown Bear1008 dispatches input6, runs the authored
script, changes model to c_beardire, consumes another feat use (5->4->3) and
restores to the original model. Canonical player565 is retained. The visible
variant count4 is verified; `live-feat-radial-choices.png` is retained. The
existing camera/occlusion makes the world dark in this fixture; this is not
visual perfection or campaign acceptance. Entry/startup fixture stays isolated.

All1588 tests pass (`feat-radial-full-tests-v3.txt`), production build passes
with the existing chunk-size warning (`feat-radial-build-v4.txt`). Ordinary
book/radial/F2/cancellation/counterspell and innate type44/duplicate charge/radial
UI regressions pass separately. Known missing plc_w02.pwk is retained separately
when encountered; new errors/console errors are zero in the druid run. Native
fixture setup mistakes and first comparison failures remain captured as v1/v2;
final original observations are v4 and all eight focused tests pass.

Active impact-script inventory v30 still finds95 unbound engine names and22
missing authored NCS resources. Presence counts are not complete implementations.
NWScript ActionUseFeat287, remaining casting/effect/event owners, combat and the
continuous base campaign play/fix loop remain open. Goal remains ACTIVE.
