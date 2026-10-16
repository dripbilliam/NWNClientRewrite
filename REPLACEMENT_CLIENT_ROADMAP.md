# NWN Replacement Client Roadmap

Scripted creation continuation: CreateObject243 now supports all five native
types through canonical loaders/placement/area owners. The real Gate cast and
delayed authored creation/OnSpawn pass; rendered right-click Use creates a
pickable placeable that survives area revisit. Placeable orientation preserves
the original FLOAT collision guard (288 original comparisons). All1,748 tests
and build pass. Map pins and ground-item drawing remain diagnosed gaps; see
[creation evidence](evidence/create-object-runtime.md).

Creature-template casting continuation: the complete wrapper now preserves
native tag/load order, forces template NPC stats and readies imported spells.
Great-ability feat bonuses and level-history reversal use the active rule.
Fixed three ruleset labels whose native calls hash a suffix with a prehashed
first letter; UMD restrictions now reach implemented pricing. All1,746 tests/
build and rendered summoning/casting regressions pass. CreateObject243 was bound
in the subsequent increment above; see [creature readiness evidence](evidence/creature-template-readiness.md).

Store continuation: full UTM loader, stock acquisition and three item pricing
owners now match1,846 original executions; GetGoldPieceValue adds32 wrapper
comparisons and a live command binding. All42 installed store templates and
4,597 direct stock items import/price/destroy with canonical IDs. All1,741
tests/build and rendered casting/loot regressions pass. CreateObject243, GIT
store import and trade GUI remain unfinished; see
[store and pricing evidence](evidence/store-template-runtime.md).

Full UTP runtime continuation: placeable templates now load through concrete
typed field/script/table/inventory/visual/UUID/locals providers. Canonical saved
IDs propagate into nested items; reload preserves repository ownership. Fixed
regular versus trap faction storage. Item GFF wrapper and portrait setters match
555 original executions; installed UTP area/geometry/destruction checks and
rendered casting/loot regressions pass. All1,734 tests and build pass.
CreateObject243, UTM and saved effects/actions remain unfinished. See
[placeable runtime evidence](evidence/placeable-template-runtime.md).

Timed visual-data continuation: curve loading/restart, scoped maps and assignment
now match873 original executions. All five visual-data owners have a canonical
runtime adapter; GIT placeables use it after inventory. Owned animation reloads
reach the model animator, and equipped items copy transforms to their real
owner's hand maps. Missing presentation is retained in diagnostics. All1,727
tests/build, installed-resource checks and rendered casting/loot regressions
pass. Full UTP/UTM adapters, CreateObject243 and scoped transform drawing remain
unfinished; see [current visual runtime evidence](evidence/object-visual-transforms.md).

Visual-data continuation: four complete material/replacement/misc loaders now
match167 original executions. Fixed16-byte GFF query-label handling against144
native cases, which also fixes parsed creature animation replacements reaching
the actual model animator. All1,719 tests/build, installed-resource checks and
rendered casting regression pass. Visual transforms and the concrete UTP/
CreateObject243 hookup remain unfinished; see
[visual-data evidence](evidence/object-visual-data-loading.md).

Placeable loader continuation: complete data-loader coordinator now matches431
original executions, and tag sanitation matches888 runs using the original CRT
classifier. Corrected swapped current/max HP aliases in the shared body-bag
field bridge. All1,715 tests/build and casting/body-bag regressions pass. UTP runtime
adapter/CreateObject243 remain unfinished; its five visual-data dependencies
are now identified for the next port. See
[placeable loading evidence](evidence/placeable-template-loading.md).

Waypoint template continuation: concrete active-resource loading, UUID/variable
providers, canonical area insertion/movement/destruction and localized members
now work with installed UTWs. Tag insertion/query and leading-NUL GFF string
semantics are corrected against original owners. All1,712 tests/build plus
installed checks and casting/body-bag UI regressions pass. CreateObject243,
UTP/UTM adapters and map-pin transport remain unfinished; see
[runtime evidence](evidence/world-template-runtime.md).

Variable-loading continuation: fresh serialized objects now use native typed
primitive/location imports, shared-name cells, loading flag1 and retained struct
outputs. Empty local locations return owned native defaults, and nonzero vectors
survive an invalid area ID. Unrebasable BIC locations are cleared and diagnosed.
Native comparisons and installed NCS/active-blueprint checks pass. Solver/JSON
lower loaders and CreateObject243 still need work; see
[variable evidence](evidence/script-variable-loading.md).
All1,710 tests/build and final casting UI regression pass; verified checkpoint
target `backups/variable-load-1710-20261016-v1.zip`.

Persistent UUID continuation: separate UUID storage, waypoint import, base-object
cleanup and GetObjectByUUID898 now preserve canonical runtime IDs and original
collision/old-alias behavior. Original-owner and bounded-stream comparisons,
installed Prelude NCS/VM checks, all1,708 tests/build and casting UI regression
pass. Random UUID/save, broader imports and CreateObject243 remain unfinished.
See [UUID evidence](evidence/object-uuid-loading.md).

World-template continuation: placeable/store/waypoint template wrappers and the
full waypoint data-loader coordinator now match1,418 original-code cases.
Native lower-call tracing distinguishes UUID loading from script variables;
concrete loaders/adapters and CreateObject243 binding remain unfinished.
See [template evidence](evidence/world-object-template-loading.md).

Latest loot UI continuation: installed native container artwork now presents
canonical repository grids/pages and queues normal drag/drop/close/bag actions.
Actual browser mouse drags and page wrapping pass. Stock container callbacks
also exposed GetIsOpen443, now mapped with its mutating door getter;970 added
original-code observations and installed checks pass. All1,703 tests/build,
body-bag/casting/scroll-learning/default-item UI regressions pass. Item icons,
some presentation/client initialization and remaining gameplay owners stay open.
See [container UI and query evidence](evidence/container-ui-and-open-query.md).

Repository looting continuation: decoded inventory subtype9/action13 now transfers
canonical items through original repository/ownership/rollback owners. Placeable
OnInvDisturbed delivery and GFF import are connected. Six tests compare1,445
original observations; installed chest acquisition/return, NCS disturbance queries,
invalid-coordinate fallback and full-bag rollback pass. All1,700 tests/build and
rendered bag/revisit regression pass. Visible container UI/drag-drop and ground
pickup remain open. See [transfer evidence](evidence/repository-move-looting.md).

Latest inventory continuation: decoded inventory status/page requests, character
owner changes, item-container open/close, ignored item script events, movement/
destruction cleanup and common item HP state now use original owners. Added
2,267 original-code observations and installed request/bag lifecycle checks;
all1,694 tests/build and rendered bag/revisit regression pass. Actual loot-window
presentation/pickup and primary-owner login initialization remain open. See
[item inventory/input evidence](evidence/item-inventory-input.md).

Native Use Object continuation: real wheel/left-click and NWScript requests now
reach action40, with approach, inventory ownership, callbacks,500ms wait and
cancellation. Seven tests compare1,674 original-code observations; installed
queue/GUI/VM and rendered wheel/script/bag/revisit checks pass. All1,687 tests
and build pass. Loot window/pickup and remaining lock/trap/corpse/item-container
owners stay open. See [Use Object evidence](evidence/use-object-action.md).

Inventory continuation: native GUI/LUO ownership, placeable observer open/close,
callback IDs and cleanup now have2,242 original-code comparisons and installed
state/VM checks. All1680 tests/build plus rendered bag/revisit and summoning
regressions pass. Native UseObject action and actual loot window/pickup remain
unfinished; see [inventory GUI evidence](evidence/inventory-gui-ownership.md).

Latest body-bag continuation: populated placeable destruction now transfers
canonical items into a synthetic native bag, inserts it after1000ms, loads its
dynamic model and preserves it across area revisits. Original-code comparisons,
seven installed sources, and actual right-click Use/NCS/render/revisit checks
pass; all1674 tests/build and polymorph/summoning UI regressions pass. Loot GUI/
pickup and creature corpse copying/death scheduling remain outstanding. See
[body-bag evidence](evidence/body-bag-lifecycle.md).

Latest verified continuation (October16): placeable/store/waypoint constructor
ownership and destructors, placeable inventory/acquisition, scheduled world
destruction and direct inventory counting/closure coordinators. Six independent
comparison tests cover1,695 original-code observations; installed Prelude
creation/transfer/deletion preserves canonical IDs and cleans recursive ownership.
All1,671 tests/build and rendered polymorph regression pass. Full body-bag/store
GUI owners, CreateObject template/presentation adapters and continuous campaign
acceptance remain unfinished. See [ownership evidence](evidence/world-object-ownership.md).

This roadmap tracks a plausible replacement for the NWN: Enhanced Edition client. It does not assume that matching rendered screenshots is sufficient: the client must load modules, simulate the relevant world state, execute gameplay rules, present usable UI, and preserve progress.

## Target and completion tiers

Keep the current compatibility target fixed at NWN:EE `89.8193.37-17` unless a later decision expands it. The game install remains read-only; user-authorized Ghidra annotations require periodic backups. The replacement loads user-provided game data and does not ship BioWare assets.

There are two distinct goals:

- **Single-player replacement:** play the entire original campaign, Prelude through Chapter4, without launching the original client, with usable combat/casting/UI and persistent progress. This is the current priority. Representative local modules remain regression fixtures, not sufficient completion evidence.
- **Server-compatible client:** connect to an unmodified NWN:EE server and participate alongside original clients in authoritative multiplayer sessions. This is a required acceptance gate, separately validated from local play; it does not require replacing the server. Server authority and native identities constrain earlier implementation work.

A replacement server, toolset, and broad compatibility with community modules are explicitly beyond the initial target.

The base-game completion gate requires a continuous low-level-character
playthrough, quest/dialogue/journal and companion progress, normal combat and
casting, corpse loot, equipment/stores, resting/leveling, authored area/chapter
transfers, save/reload and final completion. Preserve native IDs and active data
tables throughout; fixes must not depend on a campaign name, NPC tag or a stock
high-level test character. Every selected unsupported owner or load failure
remains recorded until implemented and validated.

## Current checkpoint

World placement: canonical PWK points now drive placeable approach and native
use-range checks. Shared creature displacement, door state and player-map refresh
are connected with1,070 original-code cases. Installed door/PWK blockers safely
move the same player record; rendered radial polymorph regression passes.
All1,665 tests/build pass. See [evidence and limits](evidence/world-placement.md).
Creation243, remaining spells/presentation, combat and campaign gates stay open.

Scripted creation foundations: full CreateObject coordinator and noncreature
area add/remove owners ported;853 original-code cases recorded. Explicit
placeable collision updates preserve native slot storage. Engine243 binding,
concrete loaders/cleanup/displacement and dynamic noncreature visuals remain
open. Fixed a real shared-state bug that could run summoned creatures' OnSpawn
twice; installed Summon Creature VII and six lifecycle cycles pass. See
[creation evidence and boundaries](evidence/create-object-lifecycle.md).
All1,659 tests and production build pass. The complete spells/combat/campaign
goal remains ACTIVE.

Effect-copy audit: child payloads now follow the original clearing constructor;
beam transfers are explicit, and vision suppression/restoration use the correct
fresh/preserved effect IDs.5,976 original-code cases compare, including1,783
complete copy-constructor executions in the updated existing probes. Installed
spell/lifecycle and rendered polymorph wheel/cast/restore checks pass. All1,652
tests/build pass. See [evidence and limits](evidence/effect-copy-lifecycle.md).
Spell APIs/presentation, combat and continuous campaign gates remain open.
Full goal ACTIVE.

Earlier checkpoints below are historical where superseded above.

Damage-buff continuation: shared bonus/penalty, reduction/resistance, immunity
and shield handlers now use original admission, icon/floaty and pre-erase cache
semantics.8,188 original executions compare; installed Endure Elements,
Stoneskin, Divine Favor and Elemental Shield and rendered rest/cast regression
pass. All1,651 tests/build pass. Existing copy adapters in other effect families
still need auditing; native HUD buff art remains open. See
[evidence and limits](evidence/damage-buff-lifecycle.md). Full goal ACTIVE.

Earlier checkpoints below are historical where superseded above.

Conditional spell effects continuation: shared alignment/race wrappers and full
attack/save/AC admission, icon, feedback and removal handlers replace simplified
behavior.16,948 original executions compare; installed protection/aura impacts
and rendered protection variants through the right-click wheel pass. All1,649
tests/build pass.86 unbound impact API names/22 missing NCS remain. See
[evidence and remaining limits](evidence/conditional-spell-effects.md). The whole
spell/combat/campaign goal remains ACTIVE.

The rest checkpoint below is historical where superseded above.

Rest lifecycle continuation: normal rest now uses active duration/enemy rules,
action42, progressive healing/spell recovery, cancellation and shared effect/
feat/item/ability restoration. HUD rest/progress, NPC ScriptRested, module history
and ActionRest/ForceRest/queries are wired.3759 original comparisons, installed
learn→prepare→rest→authored cast, rendered learn/rest/cast/cancel and existing
item-target casting regression pass. All1644 tests/build pass.88 unbound impact
dependencies/22 missing NCS remain; no spells/combat/campaign completion claim.
See [evidence and limits](evidence/rest-lifecycle.md). Goal ACTIVE.

The preparation checkpoint below is historical where superseded above.

Spell preparation continuation: the Prepare tab now copies known/class/domain
spells into physical slots, exchanges prepared spells, clears slots and supports
owned metamagic using active rules. Shared native input16/17, clear/drop/list
owners match5573 original executions; newly edited spells remain unready.
Installed learn/prepare and divine/domain probes plus rendered copy/exchange/
clear/Empower pass; all1631 tests/build pass. Full rest and learn->prepare->rest
->cast acceptance are next. Goal ACTIVE; spells/combat/campaign not complete.
See [evidence and remaining gates](evidence/spell-preparation.md).

The script/scroll checkpoint below is historical where superseded above.

Scripted item use and scroll learning continuation: both typed item commands910/
911 now share native property-ID selection and the existing casting executor.
Learn Scroll connects inventory right-click, active class/spell/school admission,
canonical known pools, consumption/destruction and acknowledgement.1608 new
original executions, actual installed script/learning probes and rendered learning/
duplicate/spellbook checks pass; all1625 tests/build pass. Preparation/memorization
UI, artwork/feedback, further casting/effect gates and combat/campaign completion
remain open. Goal ACTIVE. See [evidence and limits](evidence/script-item-use-and-scroll-learning.md).

The hotbar checkpoint below is historical where superseded above.

Whole-item hotbar continuation: shared native configuration/default selection,
client wield/size, use-count/enabled state and equipment pairing pass3616 new
original executions. Whole-item potion drag now selects its native default,
casts through F2 and consumes the stack with drink animation; explicit wheel
drag and shortcut move/reload regressions pass. All1617 tests/build pass.
Non-property equipment/container activation, scroll learning, script ActionUseItem
and broader spell acceptance remain open. Goal ACTIVE. See
[shortcut evidence and limits](evidence/item-quickbar-configuration.md).

The item wheel checkpoint below is historical where superseded above.

Item wheel continuation: native use-entry slots, paging, child variants and
item-specific targeting now connect inventory right-click and explicit
property/variant quickbar bindings to input9/action46. 2,058 new original-code
comparisons and all1,610 tests/build pass. Rendered test consumes an unchanged
potion stack via wheel→DOM drag/drop→F2, plays the real drink clip three times,
and clears its shortcut on destruction. Known missing PWK remains recorded.
Default whole-item shortcuts, scroll learning, script ActionUseItem, further
spell effects/presentation and full scroll/wand acceptance remain open. Goal
ACTIVE. See [item wheel evidence](evidence/item-radial-casting.md).

Item execution continuation: action46 now executes the original item-casting
timing, variant selection, resource consumption and delayed destruction paths.
11,514 original instruction comparisons cover execution/resources/cancellation/
event11/decoded input9. Installed potion stack3→2→1→removed runs its authored
script through typed talent and player item input, heals HP67→77, and preserves
class/innate pools. Real Get/SetItemCharges607/608 bind shared owners. All1,603
tests/build pass; auditv33:88 unbound names/22 missing NCS. Wheel/hotbar item-use
selection, complete scroll/wand acceptance, release/projectile presentation and
other spell effects remain open. Goal ACTIVE; combat and campaign gates remain
unmet. See [item execution evidence](evidence/item-cast-execution.md).

The request-only checkpoint below is historical; its missing action46 status
has been superseded by the execution continuation above.

Item request continuation: complete native UseItem and AddItemCastSpellActions
owners now connect item-backed talents to canonical ownership/equipment,
active metadata, range and typed queues.5236 original comparisons and1596
tests/build pass. Actual installed potion queues native action46 and preserves
resources until execution. The action46 executor remains explicitly diagnosed;
item/scroll casting is not playable yet. Next: its native lifecycle, resource
consumption, player input and item UI. Goal ACTIVE. See
[item request evidence](evidence/item-cast-requests.md).

Talent action continuation: full object/location talent wrappers and scripted
309/310 dispatch now share casting/feat/skill owners, preserving conditional VM
target pops and native item-routing boundaries. Corrected installed accessor
names362/363.12444 original cases,1594 tests/build and existing innate UI pass.
Five unchanged installed player/NPC profiles execute class, feat and innate
talents through the typed VM with correct pool consumption and canonical IDs.
Known absent PWK remains recorded separately. Audit90 unbound names/22 missing
NCS. Item/scroll use and other effects remain open; goal ACTIVE. See
[talent dispatch evidence](evidence/talent-action-dispatch.md).

Scripted feat continuation: ActionUseFeat287 is connected to the shared feat
runtime with native argument groups, auxiliary conversion, actor/target/area
selection and null-point rules.738 original command comparisons pass. Actual
typed-VM calls with unchanged druid/barbarian characters run their authored
effects and consume feat uses without class slots or identity changes.1591
tests/build pass; active audit94 unbound names/22 missing NCS. Remaining spell/
effect owners, combat and continuous campaign acceptance stay open. Goal ACTIVE.
See [script feat evidence](evidence/script-feat-activation.md).

Class/feat radial continuation: replaced the local Class abilities placeholder
with native adaptive class slots, domain/class pages, feat variants, counts and
selection routing into shared input6/casting.3557 original decision executions
pass; all39 installed presets traverse active metadata. Actual druid F2 plus
wheel-selected Brown Bear casts/restores with uses5->4->3 and same player565.
1588 tests/build and ordinary/innate UI regressions pass. Audit95 unbound names/
22 missing NCS remains explicit. ActionUseFeat, remaining effect/event owners,
combat and continuous campaign acceptance remain open. Goal ACTIVE. See
[class radial evidence](evidence/feat-class-radial.md).

Feat activation continuation: Feats-panel drag/type4/F2 now reaches native
client targeting, input6, UseFeat, shared cast/impact and feat-use consumption.
Unchanged installed Wild Shape/Rage characters execute authored scripts; actual
F2 form change and radial restoration retain canonical IDs and class slots.
Native owners compared:857 UseFeat,960 feat casting,1620 special attacks,
387 input and517 targeting cases.1580 tests/build and feat/ordinary/innate UI
regressions pass. Shared native item-level restriction default restored; enabled
pricing remains open. Class/feat radial submenus, ActionUseFeat, remaining effects,
combat and continuous campaign acceptance remain open. Goal ACTIVE. See
[feat evidence](evidence/feat-casting-activation.md).

Client innate casting continuation: quickbar44/Abilities drag and Special
abilities ->Innate abilities now reach native input35, shared casting actions,
authored scripts and separate ability-use consumption. Target setup preserves
parent IDs while using first-child metadata.4,263 target,633 input/wrapper and
358 innate radial original-instruction cases pass. Installed location/object
casts and actual F2 parent polymorph pass.1,575 tests/build plus ability and
existing casting UI regressions pass; known missing plc_w02.pwk remains recorded.
Class/feat ability submenus, special feat casting and other owners remain open.
Audit95 unbound names/22 missing NCS; goal ACTIVE. See
[client input evidence](evidence/spell-like-client-input.md).

Form equipment/defenses continuation: shared property handlers now traverse all
102 installed forms with valid appearances; 6,238 original materializer cases,
499 turning-resistance cases and128 HP-pipeline cases pass. Corrected ability
cache ownership and kept native missing-CON HP behavior. All-form sweep records
HP differences explicitly; it is not full HP parity acceptance. Two authored
item templates remain unavailable. Existing visual attachments rebind across
body replacement.1,572 tests, build and polymorph radial UI pass. Active spell
audit95 unbound names/22 missing NCS. Next: original book/hotbar child selection.
See [defense evidence](evidence/form-equipment-defenses.md). Goal remains ACTIVE.

Polymorph continuation: full transform/restoration coordinators now connect
type62 to active form data, canonical item IDs, shared stats/racial traits and
same-area remove/re-add. Self radial cancellation uses Input30/deferred removal;
feat289 is creature-weapon proficiency. Live appearance/equipment changes rebind
models and animations inside the same wrapper. Native comparisons:1037 form,
984 property,144 input cases. Installed forms3/0/1/2/4 pass full local reversal;
1569 tests/build pass. Broader107-form probe stops at property71/TrueSeeing.
Saved combat a48 is explicitly diagnosed as a projection; full native d70 is
open. Full UI radial GiantSpider387 cast/model/restoration and existing spellbook/
F2/counterspell regressions pass. Goal ACTIVE. See
[evidence](evidence/polymorph-form-lifecycle.md).

- **2026-10-15 polymorph construction and racial effects:** command463 and
  active-data racial68/vision children are connected. Native upper polymorph
  lifecycle is ported/tested with lower transform/restoration captured.3747
  original cases,1566 tests, build and installed race/VM probes pass. Authored
  polymorph now reaches the still-unimplemented type62 application; full form,
  equipment/model restoration and radial cancellation remain open. Audit97
  unbound names/22 missing NCS. See [effect evidence](evidence/polymorph-effect-owners.md).

- **2026-10-15 polymorph stat dependencies:** six shared base-ability setters
  and native natural-armor query now preserve byte widths, CON injury/cache
  ordering and transition/polymorph armor sources.4452 original instruction
  cases,1560 tests, build and installed stat/drain/recovery checks pass.
  Full polymorph casting, equipment/model transformation/restoration and radial
  cancellation remain open. See [stat owner evidence](evidence/polymorph-stat-owners.md).

- **2026-10-15 shared removal and expiry:** callback retention, assignment/value
  re-find, live cursors, creator-target cleanup and strict expiry/restart now
  follow original owners.1260 original cases,1557 tests, production build and
  installed affliction/recovery/drain/bonus-feat regressions pass. Fixed area/
  summon constructors preserving six string slots. This supersedes the removal
  prerequisite warning below; full polymorph transformation/restoration and
  cancellation, other spell owners, combat and campaign acceptance remain open.
  See [removal evidence](evidence/effect-removal-lifecycle.md).

- **2026-10-15 polymorph bonus feats:** native bonus pool, grant/removal/query
  and EffectBonusFeat command are connected, including temporary duplicates and
  passive stat/HP projection.2894 original cases and installed lifecycle pass;
  all1552 tests/build pass. Full polymorph remains open: transform/restoration,
  equipment/appearance and cancel UI require further work. Native deferred
  removal was identified as a prerequisite; current remover must preserve its
  callback0 retention and half-second transition before type62 can be bound.

- **2026-10-15 negative levels and script effect types:** shared class BYTE
  counters, linked penalties, independent caster HP bonus and lethal event now
  follow original handlers.3115 native cases plus installed Enervation and real
  Restoration/Greater Restoration lifecycle pass. Complete native/public effect
  type mapping fixes cure scripts for negative levels, poison and disease.
  All1549 tests/build pass; audit98 unbound names/22 missing scripts. Ordinary
  negative-level casting, remaining visual/feedback/engine owners and campaign
  acceptance remain open; no synthetic readied slots used for validation.

- **2026-10-15 equipped regeneration:** native item-property materializer51 now
  feeds the shared regeneration/healing owner, preserving item creator and
  property IDs.72 original cases plus installed property insertion, strict
  ticks, unequip/re-equip and removal probes pass. All1546 tests/build/item
  casting UI pass. Generic remaining materializers and spell effects still open.

- **2026-10-15 regeneration, healing and resurrection:** shared constructors,
  handlers and strict tick clock now match original code. Healing handles
  native feedback, live group removal and dying recovery; resurrection restores
  existing canonical state. Installed Regenerate/Monstrous Regeneration timed
  lifecycle and Raise Dead/Resurrection impacts pass. Prepared Regenerate uses
  a real slot. A GetLocation structure bug found by recovery scripts is fixed
  against387 original cases. All1546 tests/build/full casting UI pass; audit99
  unbound names/22 missing scripts. Native death GUI/feedback rendering, complete
  outer effect-list/active-timer lifecycle, save import and campaign remain open.

- **2026-10-15 poison and disease:** active-table constructors, initial saves,
  ability damage, secondary poison and disease incubation/daily stages now use
  shared native effect owners. Original handler/time/copy/equality/poll checks
  and actual installed lifecycle probes pass. Prepared Quillfire also completes
  the normal casting path and consumes a slot. All1541 tests/build pass. Audit
  has101 unbound spell-used names/22 missing scripts; this remains incomplete
  spell coverage. Missing plc_w02.pwk remains diagnosed during area loading.
  Rendered affliction, save import/rest recovery and campaign acceptance remain
  open. Canonical object IDs and independent ability-damage group IDs preserved.

- **2026-10-15 shared spell queries and petrification:** connected live
  appearance/size/tail/subrace reads, native script mode comparison, canonical
  droppable flags and EffectPetrify through the existing shared state pipeline.
  Original-code comparisons cover widths, defaults, mode narrowing and flags.
  Installed enemy impact probes now verify Flesh to Stone application/removal
  and Sunburst damage; Gust of Wind and Bigby impact probes pass. All1535 tests,
  build and full casting/radial UI regression pass. Static spell dependency audit
  drops110->103 unbound command names;22 script resources remain unavailable.
  Impact fixtures do not prove complete casting/rendering or campaign acceptance.
  Legacy localized subrace, detect/stealth activity lifecycle, further effects
  and procedural presentation remain open.

- **2026-10-15 helper emitter simulation:** untextured zero-lifetime emitters
  now receive authored events and produce wind bursts while following the
  original no-draw lifetime gate. Point wind math/append/lifetimes match375
  original observations. All1527 tests pass; actual GMW UI casting generates
  particle vertices and a timed wind burst without a spell particle failure.
  Ambient wind/noise, scene manager registration and native outer scheduling
  remain explicit gaps. Factories retain their original session/scene across
  asynchronous resource loading. Full spell/combat/campaign acceptance is open.

- **2026-10-15 one-shot visual delivery:** decoded original object receiver
  matches 864 native cases and now reaches the client renderer. One-shot entries
  retain local identity separately from canonical looping effects; asynchronous
  loading respects actor identity and area ownership. Actual GMW UI casting
  presents visual150/vim_magsuper with native pose, then naturally retires it.
  Client-only dummy/point and area-message ownership remain diagnosed, as do
  procedural/audio gaps. A NULL-textured helper emitter now exposed by this
  live path still needs its original admission/render policy checked. Spell,
  combat and continuous campaign completion remain open.

- **2026-10-15 native geometry pose rendering:** binary own clips now use
  retained controller/value pools, native Part IDs, checked sampling/blending
  and hierarchy dispatch in the client. Geometry loop and transition flags0/1
  are admitted; manual root placement suppresses its controller gate while
  child animation continues. Native current/stop/restart keeps channel state.
  All1510 tests/build pass. Real UI confirms equipped Light uses this backend;
  real-resource CPU composition verifies canonical removal, cessation, authored
  Detonate, particle vertices, reattachment and retirement. GPU cessation/NCS
  delivery and continuous campaign acceptance remain open. Emitter bounds,
  native scene services, other procedural modes and related gaps remain logged.

- **2026-10-15 shared animation blend/hierarchy owners:** generic controller
  application matches480 composed original cases; hierarchy dispatch matches
  512 physical-tree cases, including duplicate IDs, callback mutation and depth
  limits. All1503 tests/build pass. These owners still need the native parser
  remapping and specialized scene bridge before geometry blending is enabled.

- **2026-10-15 native animation sampler foundation:** scalar/vector/quaternion
  controller sampling now matches2304 original profiles, including original
  quaternion trigonometry/status helpers. Runtime WORD indexing, Bezier tail
  behavior, position-only scale and shortest-path quaternion rules are retained.
  All1501 tests/build pass. Renderer hookup still requires verified hierarchy,
  runtime controller remapping and blending; geometry flags0/1 remain blocked.

- **2026-10-15 position/orientation attachment:** renderer modes0/3 copy
  anchor world position/orientation independently of parent scale. The complete
  native no-orientation update matches72 original profiles and preserves the
  current orientation each frame. Global root get/set now use checked owners.
  Native attachment event/handle/lifetime machinery remains diagnosed.
  All1498 tests/build pass; spell UI regression passes and now separately
  verifies Light and an admitted dormant cessation-only item buff model.

- **2026-10-15 shared visual phases in the client:** active visualeffects,
  progfx and appearance tables now drive the checked loader and native
  start/place/detach/update/stop/retirement owners. Model instances are created
  at phase boundaries; Type4 cessation reuses the duration model/run as native.
  Canonical removal retains cessation until native retirement, and the competing
  detach helper matches326 original profiles. All1495 tests and build pass;
  real spellbook/hotbar/item-wheel targeting and equipped Light smoke pass.
  Geometry orientation/blending, other program types, sound/shake, renderer
  contexts/light selection and outer scene scheduling remain diagnosed gaps.
  Full spell ecosystem, combat and continuous campaign acceptance remain open.

- **2026-10-15 live Type4 attachment and priority selection:** the renderer
  now calls checked Type4 start/local attachment and native effect selection.
  It preserves physical record order across async loads, selects the last equal
  priority and reattaches survivors on removal. Native local head-node fields
  and root alias replace accumulated bone placement. Light priority2/4 is now
  stored separately from animated properties. 1,488 tests/build and real
  prepared spellbook/F2/item-wheel casting checks pass, including the native
  equipped-item Light gate. Program loading/clear/update731 cases and Type4
  stop770 cases are also ported; outer impact/cessation/retirement, renderer
  light selection, scene suppression and generic geometry/procedural factory
  are still pending and diagnosed. [Evidence](evidence/visual-effect-phases.md).

- **2026-10-15 native animation playback and visual ownership:** full model
  run start/reuse ordering matches2,173 original executions; run-clock timing,
  reverse playback and authored-event delivery match474 full Animate profiles
  within recorded scene gates. Procedural one-shot models now use these native
  paths. Actual prepared spellbook/item targeting, F2, item spell wheel, slot
  consumption and cancellation pass in the rendered client. Visual loader767,
  node-pose288, priority/retirement selection895, selection-time attachment1,169
  and Type4 start388/local attachment134 cases also match. Async model loading
  preserves a single native selection pass. 1,480 tests and
  the build pass.
  Reconciliation supports native-instance
  cessation/retirement and invalidates stale area bindings. Shared geometry/
  program phase integration, blended/inherited pose rendering and remaining
  scene services are still open; spellcasting, combat and campaign completion
  are not claimed. [Evidence](evidence/visual-effect-phases.md).

- **2026-10-15 visual placement and scene detachment:** native anchor names,
  orientation/parent flags, rotation reset and update sequencing match583
  original runs; detachment and Type4 context refresh match75. 1,466 tests/
  build pass. Loader policy, lower model/scene adapters and live gameplay
  lifecycle integration remain open. [Evidence](evidence/visual-effect-phases.md).
- **2026-10-15 visual phase lifecycle owners:** full start/restart, cessation
  and update now match688 original executions, including model/program timers,
  table-driven shake/audio and delayed retirement. 1,464 tests/build pass.
  Native loader/attachment and gameplay reconciliation remain to be connected;
  no rendered gameplay cessation acceptance yet.
  [Evidence](evidence/visual-effect-phases.md).
- **2026-10-15 authored particle detonate events:** shared event scheduling,
  listener dispatch and Explosion detonate match304 coupled original runs.
  Instance-scoped model events now trigger the authored Explosion; the rendered
  clip shows both Fountains and its burst, then reloads cleanly. 1,462 tests/
  build pass. Other handlers, upper animation modes and gameplay visual phase
  delivery remain open. [Evidence](evidence/particle-emitter-runtime.md).
- **2026-10-15 live model particle renderer:** instantiated emitters now use
  the checked native CPU owners and generated vertices with active textures.
  The installed authored cessation clip visibly renders its two Fountain
  emitters with decorative previews disabled; reload cleans up runtime state.
  A rendered check caught and fixed camera-basis conversion;1,460 tests/build
  pass. Spellbook/F2/item-wheel regression passes with no engine failures.
  Model events/detonation, several scene services, other movement classes,
  material quality/fog and gameplay visual phases remain open and recorded.
  See [particle-emitter-runtime.md](evidence/particle-emitter-runtime.md).
- **2026-10-15 shared particle draw and update owners:** Explosion and Single
  updates match647 original executions; outer frame logic matches800; all seven
  draw modes match245 original generated vertex streams and atlas mutations.
  GPU/material/scene integration, animation events and visual lifecycle remain
  open. These CPU comparisons are not rendered spell or campaign acceptance.
  See [particle-emitter-runtime.md](evidence/particle-emitter-runtime.md).
- **2026-10-15 native particle physics:** full initialization and standard
  movement now match876 and384 original executions, including inherited
  transforms, random direction, gravity and collision response. Coupled Fountain
  birth/movement/expiry/reuse matches27 original frames using the real helpers.
  1,454 tests and build pass. Outer model timing, other update/movement modes
  and GPU rendering remain open; these helpers are not yet gameplay particles.
  See [particle-emitter-runtime.md](evidence/particle-emitter-runtime.md).
- **2026-10-15 particle emitter decoding and frame owners:** serialized emitter
  fields and39 parameter curves retained; native binary reader checks pass.
  Full lifetime helper matches290 original executions; Fountain scheduling
  matches165 with explicit lower constructor/movement providers. 1,451 tests
  and build pass. Gameplay particle initialization/motion/rendering remain open;
  preview output is not used as gameplay acceptance. The visual audit records
  missing resources and410 emitter-bearing models needing this shared path.
  See [particle-emitter-runtime.md](evidence/particle-emitter-runtime.md).
- **2026-10-15 authored duration light presentation:** binary light fields and
  color/radius/multiplier animation channels now render through the shared model
  pipeline. Active visualeffects/progfx selects model/clip, with canonical loop
  reconciliation and late-load/removal/area cleanup. Prepared inventory Light
  renders its authored fade; native legacy attenuation fixes overexposure.
  Twelve full original model-reader runs match; 1,446 tests/build pass. Rendered
  self/counterspell/summon/area-transfer regressions pass; autosave remains logged.
  Other visual program types and native lighting/shadow policies remain open.
  See [procedural-light-presentation.md](evidence/procedural-light-presentation.md).
- **2026-10-15 prepared inventory/equipment spell targeting:** spellbook and
  hotbar selections can target carried/equipped items; item right-click menus
  use the native item spell filter. Rendered prepared casts consume real slots
  through all three paths. Runtime-log checking exposed and fixed Light's
  property44/type54 controller and copied visual ownership;396 original runs
  match. Light state/removal is verified, while its rendering remains explicitly
  diagnosed. 1,438 tests/build and self/counterspell UI regression pass. Other
  logged failures and broader spell/combat/campaign work remain open.
  [Evidence and limits](evidence/inventory-spell-targeting.md).
  Backup report:backups/animations/item-targeting-checkpoint.txt.

- **2026-10-15 armor spell properties and carried-item casting:** property
  types1..5 now use the native AC materializer. The release LOS check admits
  carried items according to the original game. 151 full armor-handler and96
  original release-block comparisons pass. Installed Magic Vestment adds an
  equipped armor property and changes AC8→11; removal/expiry restores8, and
  re-equipping preserves the buff. 1,436 tests/build pass. This is scripted-cast
  fixture acceptance; normal item-target UI and remaining spell systems are open.
  [Evidence and limits](evidence/equipped-item-spell-buffs.md).
  Backup report:backups/animations/armor-item-buffs-checkpoint.txt.

- **2026-10-15 equipped spell buffs and item on-hit casting:** nine native
  enhancement/damage/ability materializers, equipment traversal and delayed
  item-spell payloads are connected. 1,804 original executions match. Installed
  Magic Weapon, Greater Magic Weapon, Flame Weapon and Darkfire scripts now
  apply/remove weapon properties; on-hit scripts cause damage and restore
  interrupted caster context. 1,434 tests/build and rendered radial summon/
  area-transfer regression pass. Attached visuals, other materializers and full
  spell/combat/campaign acceptance remain open.
  [Evidence and limits](evidence/equipped-item-spell-buffs.md).
  Backup report:backups/animations/equipped-item-buffs-checkpoint.txt.

- **2026-10-15 item-property mutation and ownership:** Add/Remove bindings,
  type91 retention/removal, queued exposure changes, property-ID effect
  linkage and repository-item expiry are connected.1,534 original command/
  state/block comparisons pass. Installed dagger API/expiry checks and guards
  against unsupported buff leakage pass. Equipped materializers and permanent
  restriction/pricing remain unfinished.1,430 tests/build and rendered radial
  casting/companion transfers pass. [Evidence and limits](evidence/item-property-mutation.md).
  Backup report:backups/animations/item-property-mutation-checkpoint.txt.

- **2026-10-15 shared spell item-property constructors:** all79 installed
  constructor bindings now use the decoded shared engine factory and active
  2DA validation.1,262 original synthetic and237 installed-input executions
  match. Static spell scan has48 fewer unbound constructor names;112 other
  names and22 script load failures remain. Item mutation/equipment propagation
  remains unfinished.1,425 tests/build and rendered radial casting/companion
  transfer checks pass. [Evidence and limits](evidence/item-property-factory.md).
  Backup report:backups/animations/item-property-factory-checkpoint-v2.txt.

- **2026-10-15 complete ClientArea sender composition:** all10 installed
  messages match combined original sender/packer/writers/envelope execution.
  Client ID namespace and localized-string readers match312 original cases.
  Actual unnamed client receiver and area loader located through verified
  string references; receiving scene/ready flow remains unfinished.1,423 tests
  and build pass. Autosave and campaign acceptance remain open.
  [Evidence and limits](evidence/complete-client-area-client-identity.md).
  Backup report:backups/animations/complete-client-area-checkpoint.txt.

- **2026-10-15 GIT/object area-message bindings:** normal loading now supplies
  ambient/grass, waypoint, sound and placeable message state.1,212 original
  state/block executions pass; all10 installed Prelude area-pack bodies
  match the full original packer in both tested modes, including204 objects
  and144 tiles.1,421 tests/build and rendered radial summon/companion transfers
  pass. Outer ClientArea/receiver/ready transport and autosave remain open.
  [Evidence and limits](evidence/area-git-object-message-bindings.md).
  Backup report:backups/animations/git-area-checkpoint.txt.

- **2026-10-15 decoded full area packer:** the complete owner plus ambient/
  sound serialization, tile flags, master map pins and live object passes
  match439 original cases; another152 constructor/ARE/tile input cases pass.
  Area/tile metadata and a diagnosed session binding are live. The installed
  probe reaches the missing ambient/GIT property binding in all5 Prelude
  areas and records every failure; no partial packet is transmitted.1,416
  tests/build and rendered casting/companion-transfer checks pass. GIT/object
  bindings, actual receiver/ready transport and autosave remain unfinished.
  [Evidence and limits](evidence/area-message-pack.md).
  Backup report:backups/animations/area-pack-checkpoint.txt.

- **2026-10-15 native message text and area identity:** byte strings, ResRefs,
  localized-language fallback and canonical-ID wire boundaries match1,802
  original cases, including128 area-identity prefixes. Live area loading now
  retains localized names; original readers decode replacement identity bytes
  from all5 Prelude areas. Native GFF key normalization/duplicate replacement
  is retained.1,412 tests/build and rendered radial/companion
  transfer checks pass. Full pack/ready transport and autosave remain open.
  [Evidence and limits](evidence/native-message-text-area-identity.md).
  Backup report:backups/animations/message-text-checkpoint.txt.

- **2026-10-15 native scalar message codec:** byte/residual-bit writing,
  reading, type checks, growth, truncation diagnostics and outgoing envelope
  match4,295 original executions. The original binary independently decodes10
  replacement-produced ClientArea headers from all5 installed Prelude areas.
  Shared codec providers now serve the installed transition probe.1,406
  tests/build pass. Full area packing/receiver/transport and autosave remain open.
  [Evidence and limits](evidence/native-message-scalar-codec.md).
  Backup report:backups/animations/message-codec-checkpoint.txt.

- **2026-10-15 area entry ownership and message state:** first/last-player
  activation is shared by native area insertion/removal and the current PC
  adapter; door heartbeat and placeable static conditions match the original.
  SetAreaTransitionBMP now belongs to the caller's client. Decoded ClientArea
  sender, native loading-screen selection/entry fields and last-sent-map cleanup
  match1,531 original cases. Installed data and rendered spell/associate
  transfers pass.1,398 tests/build pass; autosave still fails and is recorded.
  Full area packing/client receiver/ACK integration remains unfinished.
  [Evidence and limits](evidence/client-area-message-activation.md).
  Backup report:backups/animations/client-area-checkpoint.txt.

- **2026-10-15 character automaps:** canonical ordered area IDs and separate
  exploration buffers now initialize, reconcile, clear and update through
  native exploration rules at PC entry/heartbeat. Five script APIs are live.
  5,465 original-code cases and installed Prelude out/back/reorder/API checks
  pass; rendered spell/associate radial transfers pass with zero browser errors.
  Autosave still fails and remains logged.1,392 tests/build pass. Native PC
  load protocol, map fog/persistence and full campaign acceptance remain open.
  [Evidence and limits](evidence/automap-state-exploration.md).
  Backup report:backups/animations/automap-checkpoint.txt.

- **2026-10-15 companion area restoration:** native recursive realization now
  preserves associate IDs, inventory, placement/visibility and queue cleanup
  across local player area changes. Native wait60 is live; decoded ack/player
  placement coordinators are compared, pending protocol integration.5,688
  original cases and installed/rendered summon transfer out/back plus radial
  dismissal pass.1,387 tests/build pass. The rendered trip exposes the still
  unimplemented autosave call; this is not campaign acceptance.
  [Evidence and open dependencies](evidence/player-area-restoration.md).
  Backup report:backups/animations/player-area-checkpoint.txt.

- **2026-10-15 native door landing:** active DWK action-point parsing, native
  state transforms/selection and active terrain-material Walk queries now drive
  door jumps and GetUseRange.2,512 native point/selection cases,43 loader cases
  and1,080 material/walk cases pass. Installed38 doors queried and three queued
  jumps pass; known missing PWK remains logged. Rendered spell/associate radial
  regression passes. Normal/paired door state events synchronize native D8.
  1,386 tests/build pass. [Evidence and limits](evidence/door-action-point.md).
  PC transfer/automap, limbo and script-adapter replacement remain unfinished.
  Backup report:backups/animations/door-placement-checkpoint-v2.txt.

- **2026-10-15 creature relocation:** native jump actions5/48 now execute in
  the live queue and stalled-movement timeout recovery. Safe placement, facing,
  trigger membership, attached AoE jumps and canonical NPC area transfer are
  connected.1,980 original action cases,420 subarea/AoE cases,18 route-cut cases
  and96 extra cancellation cases pass; installed queued/forced relocation also
  passes with the known absent training-room PWK still logged.1,382 tests/build
  pass. [Evidence and limits](evidence/jump-actions.md). Door action-point,
  PC area handshake/automap, limbo and legacy script-wrapper replacement remain
  unfinished. Backup report:backups/animations/jump-checkpoint.txt.

- **2026-10-15 installed voice delivery:** PlayVoiceChat now uses native
  quick-chat recipients/WORD payload and active SoundSet/SSF/TLK/WAV resources;
  battle cries share actual client playback.572 native command/send comparisons,
  72 SSF/wrapper observations, installed PC/NPC cues and real Chromium audio
  decode/start/caption checks pass. Floating-text duplicate binding repaired.
  1,379 tests/build pass. [Evidence and limits](evidence/voice-quick-chat.md).
  Native mixer/overhead/profile presentation, forced-jump fallback, broader
  spell forms/effects and campaign completion remain unfinished. Backup report:
  backups/animations/voice-checkpoint.txt.

- **2026-10-15 authored associate follow:** received commands now execute real
  conversation scripts with native matched-string ownership/default-script
  gates. Shared force-follow actions and cancellation move summons toward their
  master; Follow/Stand/Guard/Attack Nearest/Heal Me route from owned radial.
  Actual rendered Follow/Stand/Unsummon/model removal passes.1,258 added bounded
  original comparisons;1,371 tests/build pass. Voice chat and stalled-movement
  forced jump remain unfinished. [Evidence](evidence/associate-listen-follow.md).
  Verified backup report:backups/animations/listen-follow-checkpoint.txt.

- **2026-10-15 summon radial dismissal:** owned-creature menus now use canonical
  master/type and preserve original associate submenu slots/commands. Unsummon
  dispatches decoded input with ownership recheck, then the original shared
  deferred destruction path; visible summon view removal passes real right-click
  renderer input.607 original comparisons;1,366 tests/build pass. Generic
  associate conversation-event7/AI and possession/domination remain unfinished.
  [Evidence](evidence/associate-command.md). Verified backup report:
  backups/animations/associate-command-checkpoint.txt.

- **2026-10-15 live summon ownership:** installed Summon Creature VII now casts
  through queue/scripts and ground right-click radial, spends a real slot and
  creates a canonical inventory-owning associate. Replacement, expiry, delayed
  spawn races, adoption/rejection and deferred alive-NPC destruction pass.
  New shared area/associate/destructor/time owners add1,601 bounded original
  comparisons.1,364 tests/build pass; rendered radial smoke reports0 errors.
  [Evidence and remaining limits](evidence/summoning-lifecycle.md). PC/DM area
  services, dead-bodybag/noncreature cleanup and other spell forms remain open.
  Backup report:backups/animations/summon-runtime-checkpoint.txt.

- **2026-10-15 shared appear effect:** EffectAppear/internal81 now queues native
  uninterruptible52, selects normal/alternate appearance, runs fixed2000ms and
  restores idle.142 native comparisons, installed-character live probe and
  1,355 tests/build pass. Hidden effect queries match original enum visibility.
  [Evidence](evidence/appear-effect.md). Full summoning still awaits area,
  associate removal and destruction; the broader spell goal remains active.

- **2026-10-15 summon ownership foundation:** shared summon constructor,
  apply/remove, delayed event24, type4 associate and unsummon coordinators
  compare3,040 original observations;1,352 tests/build pass. Live bindings remain
  pending complete area entry/removal/destructor, associate removal and appear
  action owners. [Evidence](evidence/summoning-lifecycle.md). No playable summon
  or full spell completion claim; the formal goal remains active.

- **2026-10-15 counterspell lifecycle:** decoded player/radial and script orders
  now run canonical action50, native identification/selection, real resources,
  animation/round timing, countered impact suppression and CC12 feedback.
  Fake casts now omit actual impacts and counterspell reactions. Adds919
  original instruction cases;1,347 tests/build pass. Installed positive,
  unseen and fake-cast probes pass without fabricated spell slots; rendered
  world NPC counterspell radial mode/target acceptance passes, errors0.
  [Evidence and limitations](evidence/counterspell-lifecycle.md). Full spell
  ecosystem, combat and continuous campaign acceptance remain open.

- **2026-10-15 counterspell foundation:** shared native count/selection/slot
  metadata and cleanup owners compare1,800 additional original cases; canonical
  round cleanup is connected.1,345 tests/build pass. Counterspell queue,
  consumption, interruption, animation and feedback remain required before
  exposing playable counterspells. [Continuation](evidence/counterspell-lifecycle.md).

- **2026-10-15 radial casting continuation:** world spell wheels now read live
  class/level/metamagic/domain/child pools and native target masks, submitting
  to the shared cast queue. Defensive casting uses decoded input10 and native
  mode toggling, including deferred associate script notifications.4,180 native
  comparisons,1,342 tests/build and isolated rendered self-radial casting pass.
  See [evidence](evidence/spell-radial-casting.md). Counterspell/epic owners and
  the broader spell completion gate remain open. The formal spells → combat →
  continuous campaign play/fix goal is active.

- **2026-10-15 shared spell continuation:** script/fake-cast adapters,
  spontaneous conversion, touch attacks, beams, blindness/darkness/special
  vision/deafness, dispelling, damage shields and damaged-caster concentration
  are connected through shared owners and active tables. Installed-script
  fixtures verify rays, conversion, hostile Blindness/Deafness, persistent
  Darkness, four dispelling spells, three reflecting shields and interrupted
  casting. Original-code comparisons cover7,432 new cases at stated lower
  boundaries. **1,337 tests/build and isolated rendered casting acceptance pass.**
  Spell completion is still open: counterspells, summons/polymorph/disease/
  poison, item-property mutation, feat/item/placeable/talent casting, conversion/
  memorization/rest UI and complete VFX remain. Audit-v12 records163 unbound
  impact command names and22 missing scripts. See [shared spell evidence](evidence/spell-ecosystem-shared-owners.md).
  This supersedes the spontaneous/script-cast pending statuses below.

- **2026-10-15 live ordinary player casting:** spellbook clicks and spell
  hotbar activation now enter the serialized canonical player-input queue,
  native action15 phases, spell consumption and deferred caster event8.
  Installed Light and Magic Missile execute their active ImpactScripts; the
  damage fixture reduces a goblin from4HP to-11HP. Rendered spellbook/F2 casts
  consume two prepared uses and play conjure2/castup, with round waiting.
  Lowercase native component checks are corrected. Counterspells, spontaneous
  conversion, special/feat/item casts, full spell release/projectile presentation
  and original-client/network acceptance remain open. This is ordinary casting
  integration, not completion of the spell ecosystem. See
  [live casting evidence](evidence/live-player-casting.md).

- **2026-10-15 missing script-load behavior:** installed Prelude ARE fields
  reference absent script1 heartbeat/script2 exit resources; neither NCS nor NSS
  exists in the module, active base/retail catalogs or installed override folder.
  Shared named-script execution now returns native failure0/load error-634 while
  retaining a diagnostic for each attempt. Missing actions/exit scripts permit
  the caller to continue; missing dialogue conditions reject the branch. Failed
  loads are retryable, and parser/read/engine failures remain explicit. 1313
  tests/build and rendered out-and-back traversal pass without missing-script
  session errors or HUD interruptions. See [native evidence](evidence/missing-script-load-behavior.md).

- **2026-10-15 scripted doors and area exit:** StringToFloat and AngleToVector
  unblock the standard transition script. ActionOpenDoor/ActionCloseDoor now
  create native object actions20/21; canonical door AI drains them into deferred
  open/close events, linked-door state and source callbacks. Both original
  reported dialogue scripts and the m0q1a to m0q1b transfer pass. Physical binary
  parent indices prevent duplicate node names from creating self-parent errors
  during destination loading;106 model resources audit successfully. 1307 tests
  and build pass. Rendered m0q1a to m0q1b and back passes without renderer errors
  while retaining canonical IDs. Creature-owned scripted door approaches/locks,
  native door displacement/automaps and broader transition acceptance remain open.
  See [native evidence](evidence/door-actions-and-area-transitions.md).

- **2026-10-14 quickbar assignment and scripted unlocking:** the PC owns36 typed
  quickbar records with native QBList import/export fields and canonical item
  references reconstructed from equipment/repository coordinates. Inventory,
  spell and feat drag/drop, right-click assignment/clear, moving shortcuts,
  modifier rows and per-character local layout restoration pass Electron checks.
  SetLocked now preserves raw integer state and deferred lock/unlock callbacks;
  the original Bim unlock script completes. 1298 tests/build pass. Hotbar use
  emits typed requests; ordinary spell execution is connected in the later
  live-casting checkpoint. UI execution owners for items/feats and native
  automatic default layout creation remain open and recorded. Radial category
  presentation is local, rather than a fully reconstructed native client menu.
  See [native evidence](evidence/quickbar-assignment-and-locking.md).

- **2026-10-14 dialogue feedback/camera requests:** SpeakOneLinerConversation
  selects authored DLG starts, routes text/sounds and runs entry actions without
  opening a modal. SetCameraMode targets the controlling client. Both reported
  original scripts now execute; rendered Pavel dialogue reaches entry33 and
  applies top-down mode without error. 1291 tests/build pass. Native speech
  bubbles, full token/parameter support and chase-camera smoothing remain open.
  See [native evidence](evidence/dialog-feedback-and-camera.md).

- **2026-10-14 world geometry and movement repair:** binary models now use
  native draw-index groups, restoring combined floor/furniture/wall geometry.
  Player movement loads snapped native tile surfaces, removing invisible cracks
  across tile seams. Repeating polling omissions retain counted records flushed
  periodically and on close/export. 1286 tests/build, installed floor coverage,
  animation smoke and keyboard traversal in both directions pass. Other logged
  engine gaps remain open. See [repair evidence](evidence/world-geometry-and-log-flood.md).

- **2026-10-14 character selection/creation:** module entry now waits for a
  confirmed character. The first-level wizard writes fresh BICs from active
  rules, packages and UTIs, with separate local-vault persistence and export.
  All154 stock race/gender/base-class combinations generate; eleven canonical
  imports and an Electron specialist-creation/save/reload/world-entry flow pass.
  Ghidra/native evidence includes2,304 alignment and36 ability-cost comparisons.
  1282 tests/build pass. Optional native wizard conveniences, arbitrary prestige
  prerequisites, manual level-up and original server acceptance remain open.
  See [character creation evidence](evidence/character-creation.md).
  Backup: `backups/live-character-creation-1282-20261014.zip`.

- **2026-10-14 silence/visibility continuation:** shared silence, invisibility
  and concealment are connected to hearing/observer checks and combat defense.
  110 silence plus242 visibility/concealment native cases compare. Installed
  Silence area callbacks and ordinary/improved Invisibility impact/removal
  probes pass.1271 tests/build pass.184 impact commands remain unbound; full
  casts, Darkness/blindness, rendering and campaign acceptance remain open.
  See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 persistent spell objects:** location and attached area effects
  use canonical IDs, active VFX_PERSISTENT data, native caster metadata,
  geometry, enter/exit/heartbeat callbacks and ordinary removal.1067 isolated
  original-code cases compare; installed Cloudkill/Grease lifecycle fixtures
  complete without engine errors.1266 tests/build pass. Audit-v7 still has186
  unbound impact commands/22 missing scripts; separate persistent callbacks
  expose9 unbound commands/7 missing scripts. Full cast/UI/rendering, harmful
  target acceptance and campaign playthrough remain open. See
  [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 ability/bag-weight continuation:** ability buffs/debuffs now
  feed current stats, modifier caches and Constitution injury preservation.
  Standard six buff scripts and Haste pass direct application/removal checks;
  reduced bag weight is connected to Strength encumbrance refresh.1262 tests
  and build pass. All39 imports retain the sole prior PaleMaster HP mismatch.
  Persistent area effects, full casts/UI/rendering and191 unbound commands
  remain open. See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 shared control effects:** Haste/Slow and movement controllers,
  Sleep/paralysis/stun/fear/charm state effects, script immunity queries and
  native ambient body selection are connected. Domination's association
  lifecycle remains explicitly unavailable.1257 tests/build pass; installed
  Haste and Sleep impact branches complete. Active audit still has196 unbound
  commands/22 missing scripts. Full cast/UI/renderer gates remain open.
  Next are area effects and ability modifiers; no campaign-specific handlers.
  See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 linked/location/control foundation:** linked protections/icons,
  property queries, location visuals and Reflex handling are connected. Bless
  and Fireball impact probes complete; full casting/UI/render gates remain open.
  Original command/effect tables exposed and corrected Knockdown's wrong
  internal ID46→20.1251 tests/build pass; pure Haste/Slow controllers await lower
  owner binding. See [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 impact/defense continuation:** live visual apply/loop expiration,
  script log, resistance, absorption, immunity and faction equality are connected.
  Authored Magic Missile impact/deferred situations completes HP17→-11 with no
  engine-call errors.1241 tests/build pass. Full casting/render acceptance remains
  open; see [impact/defense evidence](evidence/casting-impact-defense.md).

- **2026-10-14 active full-spell continuation:** release failure ordering,
  automatic Quicken and concentration are mapped; live GetSpellSaveDC uses
  active class/spell/rules.3490 cast and2343 DC original traversals compare.
  Corrected automatic-feat rule labels to EPIC_AUTOMATIC_* and executed the
  original pre-seeded hash leaf in comparisons. See
  [release/DC evidence](evidence/casting-release-save-dc.md). Full impact/effect,
  request/action and presentation binding remains required; work continues.

Latest sealed source/research backup: `backups/live-native-spell-authored-helpers-1236-20261014.zip` (4029 verified files).1236 tests/build and authored combat regression pass. See [release/authored-helper evidence](evidence/casting-release-save-dc.md), [casting metadata/travel evidence](evidence/casting-metadata-projectiles.md), [casting actions evidence](evidence/casting-actions.md) and [spellbook evidence](evidence/casting-spell-book.md) for scope and failed acceptance gates. Full spell ecosystem work remains active.

- **2026-10-14 casting metadata/admission/caster/travel:**1225 tests/build pass. Active spell rows now supply native animation/path enums, timings and master/metamagic/components; ordinary component admission includes exact Silent/Still exemptions and automatic feat thresholds. GetCasterLevel and four further spell-context queries are live, preserving class penalty/scaling and native target-location area semantics. Original capture files contain11361 bounded cases, including the expanded action/context cases; projectile timing is pure and guarded against differing CPU outcomes. Installed-data fixtures check840 spell rows and45 class slots across39 BICs without failures; prior full-import/HP readiness failures remain open. Concurrent authored combat regression passes with the same missing resources/omitted owners. **Casting remains unbound:** release/impact/effects, actions15/18, interruptions and animation integration remain required. Original FMA/process CPU and full-cast/network parity remain open. See [Casting metadata/travel evidence](evidence/casting-metadata-projectiles.md).

- **2026-10-14 resumed casting actions/context:**1211 tests/build pass. Corrected dispatch4/19/49 and bound face-object/point plus wait16, preserving path storage and using trigger polygon centers. Six live spell-context queries use distinct constructor-owned current/history fields. Pure cast queue/timing/round start/removal owners are mapped;1910 bounded original executions cover queues/facing/timing/round/context and an observed ignored-region-query fix. Concurrent authored combat regression passes retaliation, approach and encounter clearing; missing resources and six omitted readiness owners remain recorded. **Casting is still not playable:** action15, admission/release/caster/DC/projectile/impact/effect/script and animation bindings remain required. See [Casting actions evidence](evidence/casting-actions.md). No original full-cast, campaign or network parity claim.

- **2026-10-14 casting foundations:**1194 tests/build pass. Live native spellbook import, readiness/talent/has-spell and class/uses queries now use canonical owned pools. Resource consumption, ability readiness and per-day maximum adjustment match1567 original bounded cases; the pure cast-command/query coordinator matches811 of814 captured cases (three VM-pop failures are separate). The spell panel reads live pools; a rendered wizard shows43 known and34 memorized entries. The installed39-character audit consumes17 caster class slots successfully but keeps `importReady=false` for the Pale Master's102/114 HP mismatch. Prelude's missing resources/startup owners remain recorded; melee retaliation/approach/encounter regression passes. **Casting is not playable:** cast requests and consumption/refresh coordinators still require native queue/action15 timing, caster/impact context, effects, interruptions and cast-animation bindings. See [Casting spellbook evidence](evidence/casting-spell-book.md). No campaign, original full-cast or network parity completion claim.

- **2026-10-14 original campaign startup:**1177 tests/build pass. A fresh-session audit covers all seven base-game modules and321 IFO-listed areas with startup scripts enabled. Fixed the replacement-only256-event fatal limit that aborted five modules' finite spawn batches. Five native script queries plus authored creature/waypoint/door orientation imports match2628 original bounded executions; runtime facing now observes the loaded canonical vector. The authored encounter still passes retaliation/approach and clears all four enemies. The strict startup readiness gate still **fails** on autosave, sitting, effects, casting and other recorded owners; this is not a campaign playthrough or combat completion. Rendered authored-target attacks and cancellation also pass with zero animation failures across26 actors; failed short-lived spawned-target attempts remain recorded. See [Base campaign startup evidence](evidence/base-campaign-startup.md). Corpse copying/loot and full persistence remain open. Sealed source/research backup: `backups/live-base-campaign-startup-1177-20261014.zip` (3544 verified files).

- **2026-10-14 corpse metadata and lifecycle cores:**1167 tests/build pass. Body-bag appearance/get/set matches144/16/48 original executions and installed creature/placeable script queries. Death flag/scheduling/event11 cores match108/432/3456 original bounded cases. Placeable acquisition/corpse collection match360/1296 original complete coordinator cases, with captured copy/storage/acquisition dependencies. Four equipment slots create new loot copies; five size buckets retain physical ordering; raw unsigned gold and native ignored fit returns are preserved. Queries and placeable BodyBag import are live. The lifecycle/transfer coordinators remain **unbound** pending complete item copying, body-bag construction, area removal/destruction and death-effect bridging; live corpse cleanup is still missing. Full combat/casting/original/network parity remains unfinished. Backup: `backups/live-native-corpse-transfer-1167-20261014.zip`.

- **2026-10-14 pending equipment and unequip:**1159 tests/build pass. Native unequip matches1008 original owner executions; eligibility378, pending conversion32, requests1296, round insertion/rescaling180, action dispatch576, cancellation48, page arithmetic400 and script wrappers188. Live attack cancellation and round end now convert pending gear records in native tail order; ordinary/timed unequip and ActionEquipItem/ActionUnequipItem use the same canonical owners. An installed plain-item NPC fixture passes equip/unequip and cancellation with pending gear, with no errors. The full authored encounter passes retaliation/approach and clears its four spawned enemies; six observed omitted owners still prevent readiness. PC item-level restrictions/passive effects, alternate client panels, drops and broader transfer/merge/effect owners remain explicit limitations. Backup: `backups/live-native-unequip-1159-20261014.zip`.

- **2026-10-14 native queue display/cancellation:**1150 tests/build pass. Ten physical queue records match227 original executions; forward normal/special mappings match131072 inputs and the reverse cancellation map matches65536. Cancellation traversal/ownership matches240 original executions. The HUD resolves icons from active actions/spells tables, retains canonical target IDs, and sends cancellation through the local input FIFO. A separate rendered encounter verifies cancellation of group0, fresh radial Attack, approach, swing/fall→held-dead and zero animation failures across26 actors. This establishes the bounded local owners, not packet/network or full combat parity. Corpse/body bags, traps, dirty-stat refresh, automap, voice/achievement presentation and remaining equipment/special/on-hit/casting owners remain open. Backup: `backups/live-native-queue-cancel-1150-20261014.zip`.

- **2026-10-14 rendered spawned combat, corpse fields and LOS:**1144 tests/build pass. A living enemy from the nearest activated encounter is picked by canonical ID through the real radial, approached and killed, with swing/fall→held-dead presentation and zero animation failures across26 actors. Corpse query gates/item count match184 original cases; authored BOOL/BYTE/unsigned decay import matches30. Original rotated LOS generates IEEE nonfinite heights;64 complete clip/rotation and144 box/AABB/polygon executions now verify propagation through the native kernels, removing the replacement-only rejection. The encounter error gate passes again. The all-severity readiness gate deliberately **fails** on seven observed omitted owners (trap checks, queue display, dirty-stat refresh, corpse/body bags, automap, achievement presentation, voices). Remaining special/on-hit/equipment/ranged/casting and original/network comparisons also remain. Backup: `backups/live-native-los-corpse-fields-1144-20261014.zip`.

- **2026-10-14 live area path commit:**1139 tests/build pass. Surface/tile/best-exit/area coordinators match364/577/1731/165 original executions with documented helper boundaries. Native graph and triangle search, corridor collision probes, resumable cache ownership, rotations, route commit and smoothing now drive live attack approach. Installed obstructed geometry commits a route in three passes; the strict authored encounter clears all four spawned goblins with only installed missing-resource diagnostics. Rendered spawned-target radial/animation acceptance is still being checked. Combat remains incomplete: remaining special/on-hit/status and equipment owners, corpse lifecycle, ranged validation, casting and full original/network comparisons are open. Backup: `backups/live-native-area-path-1139-20261014.zip`.

- **2026-10-14 intra-tile collision and successors:**1135 tests pass. Tile/area walkable wrappers match864 original cases; complete triangle successor generation matches960, including hierarchy masks, NPC optimisation, direct/corner goals, midpoint/centre traversal and level/score ordering. Real installed geometry reaches a clear goal in one pass and routes around the goblin-area obstruction in two resumable passes. These core tests do not commit a live area path. Native best-exit, surface/tile/area coordinators and waypoint commit remain to connect, followed by strict full-encounter and rendered spawned-target acceptance. Backup: `backups/live-native-intratile-collision-1135-20261014.zip`.

- **2026-10-14 intra-tile core and hierarchy:**1133 tests pass. Native saved-alternative Create/Delete/Get/Set match240 cases; IntraTileDFS matches312 cases with captured geometry; original subdivision and encoded queries match two passes across five meshes,495 searches and304 getter calls. Path reset now disposes supported resume nodes instead of rejecting every allocation. Native collision checks, intra-tile successor generation/best exits, waypoint commit and the area plot coordinator remain to connect before reliable full encounters. Backup: `backups/live-native-intratile-core-1133-20261014.zip`.

- **2026-10-14 inter-tile geometry and successor ordering:**1129 tests pass. Native successor exclusions/ordering/scoring match1152 original cases; path-node getter/rotation adapters match25968 original cases. Installed Prelude geometry reaches the formerly blocked target tile through7,10→8,10→8,9→8,8 using the verified core. This is an inter-tile graph route, **not a committed walkable path**: intra-tile search/waypoint construction and the live area plot coordinator remain next. No approximate route is substituted. Backup: `backups/live-native-intertile-geometry-1129-20261014.zip`.

- **2026-10-14 inter-tile search core:**1127 tests pass. GenerateInterTilePath/InterTileDFS now match368 original instruction comparisons, retaining two-step iterative deepening, per-region BYTE pruning, avoidance exits, failed route writes and cleanup. This is a verified core with captured successor/exit geometry; it is **not connected as a live area plot provider yet**. Next map native successor ordering and intra-tile routing, then repeat the strict full encounter test and spawned radial/animation test. Backup: `backups/live-native-intertile-core-1127-20261014.zip`.

- **2026-10-14 timed equipment and manual combat cancellation:**1126 tests/build pass. Native equipment request/round queue/execution, owned-item replacement, cancellation and round recalculation are connected;864/3456/768/48/1768/3912 original cases match captured helper boundaries. An installed plain-dagger fixture completes normal and timed switches, keeps canonical ownership/repository membership and applies the1500ms pause without engine errors. WASD/Escape/UI cancellation now clears the native action queue through the local input FIFO. Rendered authored retaliation/Attack/fall→corpse passes with26 actors and zero clip failures; a stricter encounter rerun fails when a wandering enemy requires the unavailable inter-tile path owner. Combat is **not ready**: path reliability, passive item properties, higher unequip/drop/transfer, corpse lifecycle, casting and complete native/network parity remain open. Backup: `backups/live-native-equipment-cycle-1126-20261014.zip`.

- **2026-10-13 complete authored encounter and weapon selection:**1119 tests/build pass. The installed Prelude run includes enemy retaliation, player damage/death handling, all four spawned enemy kills and encounter exhaustion with no engine failures in that capture; two installed resources remain missing. Native shape, associate, inventory enumeration, degree trigonometry/location and melee/ranged/ammunition selection owners now have original instruction comparisons. Lower equip/unequip mutations are connected; queued equipment execution, passive property callbacks, blocked inter-tile plotting, corpse cleanup, encounter AI/respawn, casting and broader native/network parity remain unfinished. Rendered authored attack/fall coverage is retained; a spawned-target keyboard approach test has not passed. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-weapon-cycle-1119-20261013.zip`.

- **2026-10-13 encounter combat and dynamic animations:**1109 tests/build pass. Native encounter activation, CR pools, spawn selection/placement, canonical creature template/equipment imports, wandering, lock/location queries, AI removal and death active-count/exhaustion are connected. The authored Prelude test kills an existing goblin and a newly spawned enemy. Rendered radial Attack, enemy swing, player damage and fall→held corpse pass with zero animation failures across26 bound creatures, including dynamically loaded encounter actors. Generic transition selection matches31684 original executions; loop classification matches1712. Corpse cleanup, encounter respawn/AI, shape/associate queries, casting, remaining combat branches and full native/network parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-encounter-combat-1109-20261013.zip`.

- **2026-10-13 native skills and transfer:**1095 tests/build pass. Pickpocket request/action, carried item removal, inventory disturbance scripts/getters and ordered activity cleanup are connected;896/486/768/720/24/20/80 original owner observations match captured dependencies. Latest authored campaign run includes enemy damage, player kill and three remaining distinct errors. Other active skills, encounters/corpse, casting and broader combat/presentation/network parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-skills-1095-20261013.zip`.

- **2026-10-13 combat loot creation:**1086 tests/build pass. Authored creature item creation/acquisition and identification now complete after the goblin kill, preserving canonical IDs, stack merges and module events.1800/384/24 original wrapper/acquire/setter observations match. Old-owner transfer, other inventory owners, make-room dropping, pickpocket skills, encounters, casting and broader combat parity remain unfinished. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-fresh-item-acquisition-1086-20261013.zip`.

- **2026-10-13 authored retaliation and combat animations:**1082 tests/build pass. Noncaster talent selection and eight additional native script queries now let authored enemy AI resolve attacks. Installed-module smoke passes enemy attack, player attack/damage/death; rendered UI passes radial Attack, enemy swing/reaction and fall→held corpse with zero clip failures across14 creatures.541 native query observations pass. Caster eligibility/import, loot acquisition, skills, encounter activation and broader combat/network parity remain open. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-authored-retaliation-1082-20261013.zip`.

- **2026-10-13 canonical inventory import:**1077 tests/build pass. Creature/container loading now uses separate equipment IDs, repository nodes, admitted item properties and mapped possession events. Stack comparison, gold and weapon/import equipment gates match1080/600/6480/8064 original executions; module equipment events match48. Authored player attack still reaches damage/death; enemy talent, item creation and skill owners remain open before a full combat cycle. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-native-inventory-1077-20261013.zip`.

- **2026-10-13 module item-event routing:**1067 tests/build pass. Acquired/lost item events and six NWScript history getters are connected and match288 full native handler observations, with separate histories, canonical IDs/quantities and script contexts. Live native item import/equipment/acquisition/talent/skill integration remains unfinished; the full enemy combat cycle is not ready. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-module-item-events-1067-20261013.zip`.

- **2026-10-13 item possession/presentation owners:**1064 tests/build pass. SetPossessor matches1024 full original executions; active use counts/cache and item visual selection match2430/90/3960 runs. Correct native initial item state and inventory script-event flags are traced. These item owners still need live module-event/import/equipment integration before talent/creation/skill calls can complete the authored combat cycle. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-combat-item-possession-presentation-1064-20261013.zip`.

- **2026-10-13 life/item-owner continuation:**1059 tests, build and authored combat smoke pass. Live radial swings/reactions/fall/death/body sequence passes on installed models. Death/dying reads native object INT89c and actual familiar control, matching432 original executions. Item-property admission/counters match144 runs; repository no-merge insertion/position/panel handling matches384 runs. Item possession/equipment/cost/talent/skill ownership still prevents a full enemy combat cycle; item phases are not yet live import. See [dependency evidence](evidence/live-engine-dependencies.md). Backup: `backups/live-combat-life-item-repository-1059-20261013.zip`.

- **2026-10-13 client combat animations:**1048 tests and build pass. Canonical attack deliveries now select and sample native-named melee/reaction clips on rendered bodies, with separate presentation RNG.30672 native name lookups,2592 selector cases,60 death-animation phase cases and72 body-transition cases pass. Authored radial attack integration passed strikes/reactions/corpse; fall transitions are connected but their follow-up UI camera check is pending. Enemy talent/item/skill calls and other combat owners still prevent a full cycle. See [animation evidence and limits](evidence/combat-client-animation.md). Source/evidence checkpoint: `backups/live-combat-animation-1048-20261013.zip`.

- **2026-10-13 item eligibility/repository continuation:**1038 tests and build pass. Creature inventory allocation now follows native equipment-before-carried order and record limits. Required-provider item eligibility/restrictions/proficiency and repository fit/scan owners are ported;669 eligibility/proficiency and1050 fit comparisons execute the original native bodies. Talent selection, creation/acquisition and ActionUseSkill still need live owners. Authored combat deals damage; seven distinct failures remain in the latest trace, and the other previously observed skill site remains open. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-item-repository-1038-20261013.zip`.
- **2026-10-13 talent owner continuation:**1028 tests and production build pass. Talent values/accessors and VM reservation are connected; feat/skill selectors match60 read-only original machine-code observations. Generic spell/item selection, category/CR and physical traversal owners are ported with required providers. Live GetCreatureTalentBest/Random still need native spell eligibility, item property/repository and CanUseItem owners; the eight recorded combat failures remain open. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-talent-core-1028-20261013.zip`.

- **2026-10-13 trap/knockdown continuation:**1018 tests and production build pass; full authored Prelude combat passes HP17->-12 with eight distinct errors remaining. Native trap ID/known-ID queries and GIT allocation order, FloatToInt/ASCII case conversion, knockdown pause/control/body state and linked effect cleanup are connected. Effect removal now handles every record sharing a native 64-bit effect ID. Trap detection/firing, status animation presentation and full combat/casting remain incomplete. Continue real skill/talent/item owners and native encounter comparison. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-trap-knockdown-1018-20261013.zip`.

- **2026-10-13 listening/movement/script-animation continuation:**1008 tests and production build pass; the full authored Prelude combat harness passes (HP17->-11), with ten unique errors remaining. Listening parser/matcher matches70 native parse observations and1904 match/capture comparisons; object patterns, associate IDs, imported ExpressionList and actual GetIsListening are connected. Native dawn/dusk, byte-string operations, script movement/force movement, waits, animation queue/timing/cancellation and EffectDeath constructor are implemented. Speech dispatch, client animation presentation and death cleanup are still recorded as incomplete. Continue FloatToInt, knockdown, real skill/talent/trap/item owners and original encounter comparison. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-listen-animation-1008-20261013.zip`.

- **2026-10-13 live engine dependencies:**992 tests, production build and an asserted full Prelude combat smoke test pass (authored goblinHP17->-11). Canonical ActionDoCommand ownership, state queries, client/faction iteration, legacy emotions, commandability, distance/facing and destroyability wrappers are connected. Indoor sound now uses traced SET-selected engine graphs, tile/region DFS and door checks; all480 graph shapes/rotations match read-only native emulation. **Sixteen unique errors remain in the campaign run; combat/casting are not complete.** Continue listening expressions, actual skill/talent/animation actions, death/status/item/trap owners and native encounter comparison. Platform achievement presentation is recorded separately. See [live dependency evidence](evidence/live-engine-dependencies.md). Source/evidence checkpoint: `backups/live-engine-dependencies-992-20261013.zip`.

- Source backup: `backups/combat-reputation-lifecycle-checkpoint-20261012.zip` (source, tests, scripts and evidence; original game/Ghidra state unchanged).
- Native-traced FAC/PC/associate/PVP/personal reputation, a persistent 50-record attack pool, target changes, attack cancellation, idle/body/orientation state, melee/ranged group sequencing, independent animation RNG, defender timing and delayed strike signaling now extend the shared runtime. Creature damage events reach live HP at the scheduled impact time; other live combat events remain diagnosed. Attack-history script getters translate native internal IDs. All 358 tests and the build pass; installed reputation/action/timing/damage checks cover Prelude and Witch's Wake, with 39-character bonus checks and bundled character rendering. **Ordinary attacks are still not playable and casting is not implemented.** Dynamic perception/LOS/approach, native attack preparation/default strike and post-hit providers, event/associate/ammunition/projectile integration and presentation must be completed, then compared against the original game. The earlier preview-actor startup/UI failure remains open. See [Reputation/lifecycle evidence and limits](evidence/combat-reputation-lifecycle.md). The prior object-action archive is `backups/combat-object-actions-checkpoint-20261012-181210.zip`.
- The earlier 302-test checkpoint connected pause/round timing before effect expiry, direct OnCombatRoundEnd scripts, provider-level requests, grouped attack-action dispatch and active-rule reach. See [Timing/action evidence and limits](evidence/combat-scheduler.md).
- Damage-effect bonuses now select active 2DA Rank values, preserve native source/hand/critical/RNG rules, project mapped enhancement/damage equipment properties, and update attack components through ordered live resistance budgets. All 278 tests, the build, 39-character checks and existing creature/script-damage checks pass in Prelude and Witch's Wake. Base-only GetSkillRank is mapped; effective ranks remain explicitly unsupported. **Ordinary attacks are still not playable and casting is not implemented.** Native attack scheduling/presentation and independent encounter/server validation remain open. See [Damage-effect evidence and limits](evidence/combat-damage-bonuses.md).
- The earlier 255-test checkpoint connected script damage to live base/temporary HP, mitigation, damage history, direct creature OnDamaged/OnDeath and queued player dying/death events while preserving IDs. Its bundled UI check is historical. Full death/AI/presentation and casting/status/shield damage branches remain incomplete; authored scripts retain missing ActionEquipMostDamagingRanged/effective GetSkillRank diagnostics. See [Live damage evidence and limits](evidence/combat-damage-runtime.md).
- The earlier 233-test provider checkpoint established damage dice/critical/bonus, weapon flag/power, resistance/reduction and base/temporary HP primitives, installed retail KEY precedence and script immunity cache updates. See [Damage provider evidence](evidence/combat-damage.md).
- Shared native-traced AC, nominal melee/offhand/ranged bonuses and final save modifiers now include mapped equipped properties and positive stat effect application/removal/expiry. 159 tests and bundled character/startup checks pass; 39/39 AC and 38/39 final save BIC snapshots match under two module rule chains. Opponent-specific modifiers, immunity-aware decreases, actual equipment mutation, melee resolution and native/server differential checks remain open. See [Final modifier evidence](evidence/combat-final-modifiers.md).
- Persistent runtime diagnostics now retain unsupported/failed engine calls, resource attempts and scene/UI/audio omissions across area/module changes. Electron writes ignored per-run JSONL files; Tools provides status/export/retry and browsers retain/export saved sessions through IndexedDB. 130 tests and native/browser renderer checks pass. See [Diagnostic evidence and limits](evidence/runtime-diagnostics.md). Resume the shared class/feat/skill/stat validation milestone next.
- Static MOD/ARE/GIT loading, KEY/BIF/ERF/HAK resource resolution, ASCII and supported binary MDL rendering, TGA/DDS/PLT textures, lighting approximations, and static creature assemblies are implemented.
- The viewer selects `Mod_Entry_Area`, parses WOK walkability, loads a BIC player model (or a preview capsule), and constrains basic movement to walkable faces.
- Available placeable PWK and state-selected DWK meshes block capsule movement. Expanded exporter-header support brings the Witch's Wake entry area to 1,223 walkable faces and 82 object-collision faces.
- Visible door clicks, E and the movement HUD enter a shared use-action queue. The actor approaches DWK use points before changing state; locks are rechecked on arrival, opening side follows actor position, and authored transitions drive appearance/collision. Doors rest until used. State persists across development area switches.
- Right-click world radial menus share eight-slot modal input, lazy submenus, installed icons, state-based disabling and explicit placeholders. Door Open/Close uses the action queue, including linked-door Close; creature/placeable/player/ground menus are available, with item/associate providers awaiting their systems. See [Radial evidence](evidence/radial-menu.md).
- A shared binary/ASCII controller runtime supports transform/opacity playback and supermodel inheritance across tiles, placeables, doors, creatures, attachments, and standalone models. Idle/default clips and diagnostic clip previews are available; mapped skin geometry follows bone updates.
- Shared native-style numeric object identities/tags, render picking, cancellable approach/use/settle actions, local routing, an NCS VM, deferred events and real linked-door traversal are implemented. BIC character/owned-item state, journal and positive script XP awards are connected to the UI. The area dropdown and opt-in animation tools remain development affordances. Broader AI, gameplay animation selection, interactions, saves, audio and networking remain open.
- Existing code and research state: [README](README.md), [Research Tracker](RESEARCH_TRACKER.md), [First object-render milestone](evidence/first-object-render.md), [Rendering pipeline evidence](evidence/rendering-pipeline.md).
- NPC click/radial Talk and placeable OnUsed execute authored DLG branches, conditions/actions/endings, once-only XP and quest states. Movement-trigger enter/exit, native nearest-creature filtering and cutscene/input state are connected. All 66 local DLG resources validate; Angmar and TearsMessage pass pointer/keyboard UI checks. See [Dialogue and trigger evidence](evidence/conversations-triggers.md).

## Roadmap

### 0. Reproducible compatibility baseline

**Status: Mostly established.**

- Keep a small test corpus: Witch's Wake start, one interior, one transition, one module with HAKs, and one CEP module.
- Record expected resource resolution, entry area, starting position, creatures, doors, walkable surfaces, and known unsupported features for each.
- Add automated parser fixtures and headless resource smoke tests; preserve screenshots for visual regressions.
- **2026-10-12:** implemented the full occurrence journal and persistent diagnostic sinks. Missing lookup probes remain distinct from final omissions; aborted scripts still report their real failure location. See [Runtime diagnostics](evidence/runtime-diagnostics.md).
- Keep evidence, inference, and unknowns distinct. Use Ghidra when behavior or a binary contract is target-specific and not established by formats or validated reference code.

**Exit gate:** a clean checkout can build, run the test suite, and load each local test module reproducibly.

### 1. Reliable local movement and area traversal

**Traversal gate remains open. Core object/action/script systems now take priority.**

**2026-10-11 progress:** separated closed/open1/open2 DWK collision using target-binary evidence, added local door interaction, swept object collision and continuous floor-support checks, safer spawn checks, focus handling, parser regression tests, and local-resource/hidden-renderer smoke tools. Witch's Wake entry, Angmar's House, and Brogan's Arm pass resource/movement checks; nine unlocked door instances pass closed/open/closed collision checks. See [Movement and door evidence](evidence/local-movement-doors.md). This does not yet satisfy the traversal exit gate.

- Finish walkmesh edge cases: stacked floors, slopes/steps, narrow passages, tile seams, rotated tiles, partial PWK/DWK availability, and movement tunneling.
- Add interaction targeting and door state changes; select the correct DWK state, animate or otherwise represent open/closed state, and prevent false blocking from alternate door poses.
- Replace the development area dropdown with module-driven transitions through doors, triggers, and scripted area changes.
- Add robust spawn placement, facing, camera modes, pause/focus handling, and keyboard/mouse controls; retain collision diagnostics for test builds.
- Extend collision to relevant creatures and dynamic blockers, and validate against in-game movement rather than only synthetic geometry.

**Exit gate:** a player can enter the module, traverse a representative route, open a door, transition areas, and cannot pass through walls or closed blocking objects.

### 2. Actor and object simulation

**2026-10-11 foundation:** shared controller playback, inherited clips, mapped skin updates, attachment movement, idle/default selection, and authored door transitions are implemented. Nine real model samples pass all-clip resource checks; the Electron viewer checks playback/pause across tile, door, placeable, and creature categories in Brogan's Arm. Blending, event dispatch, animated-mesh/dangly channels, full controller coverage, exceptional skin variants, and gameplay actor state selection remain open. See [Animation evidence](evidence/model-animation.md). This does not satisfy the phase exit gate.

- Evaluate MDL animation controllers and supermodel inheritance; animate skeletal creatures, equipment, doors, and simple placeables.
- Replace the capsule-only controller with a selectable player creature, authored appearance/equipment, facing, idle/walk/run transitions, and movement feedback.
- Implement area object lifecycles for creatures, placeables, doors, triggers, waypoints, encounters, and transitions; resolve object tags and linked objects.
- Add path planning and movement requests where the game expects click-to-move or scripted movement, rather than treating WASD displacement as the final control model.

**Exit gate:** representative actors animate and change state from gameplay events; object placement, collision, and facing remain coherent through transitions.

### 3. Interactions and core game loop

**Current priority: gameplay foundations.** Door behavior is the first vertical slice of shared object/action/event systems. [Door click evidence](evidence/door-click-gameplay.md) traces native input through queued use, range checks and state events. Object picking, approach planning, cancellation and door state events are implemented. A first bytecode VM now executes shipped door transition scripts through the shared event scheduler, with persistent native-style uint32 object IDs. Broader interactions and the phase exit gate remain open.

- Select/inspect objects and execute context-sensitive actions: talk, use, open, attack, loot, and examine.
- Populate the shared radial providers from real character, inventory, faction and skill rules; replace placeholder requests with validated simulation actions incrementally. Preserve native default-use versus explicit radial action behavior.
- Implement conversation loading and branching, journal/quest updates, party/faction state, and common encounter triggers.
- Implement combat/action queues, round timing, attacks, damage, effects, saving throws, spells, feats, and inventory/equipment rules incrementally.
- **2026-10-12 combat requirement:** nearly identical behavior alongside original clients, demonstrated through native evidence and side-by-side differential scenarios. Validate modifiers, RNG consumption, action/round/event ordering, consequences and presentation for each claimed slice. Keep network requests/presentation separate from authoritative server resolution. Placeholders and approximate combat cannot pass the gate. See [Combat compatibility contract](evidence/combat-compatibility-contract.md).
- Build essential UI workflows: character selection/creation as required by the target module, HUD, action feedback, conversation, inventory, journal, map, pause, and settings.

**2026-10-11 UI checkpoint:** shared native GUI/MDL/texture/font presentation, gameplay HUD/quickbar/message log, working journal text/completion and session notes, examination, and principal gameplay/front-end panel shells. All 104 installed GUI layouts are available through the resource catalog; missing engine-backed actions produce structured placeholders. Character creation, inventory rules, dialogue, native automap/pause, saves and networking remain open. See [UI evidence and validation](evidence/game-ui.md).

**2026-10-11 player checkpoint:** BIC player import, canonical owned/equipped item IDs, portrait/body/chest armor assembly, racial/class/equipped-ability state, mapped PC HP and positive XP awards. Character, skills, feats, equipment and spellbook read real imported data. Brogan's native compiled script awards 100 XP once and the clicked-door round trip preserves actor/owned-item state. All 39 installed BICs parse; one archived Pale Master HP discrepancy needs native runtime comparison. General effects/item rules, leveling/creation, gameplay movement animations and full equipment visuals remain open. See [Character evidence and validation](evidence/player-character.md).

**2026-10-11 conversation checkpoint:** native-checked dialogue order/participant IDs, stale-reply rejection, journal progression, once-only XP, click/radial Talk, placeable use points/range, movement triggers and cutscene plot/input state. 103 tests pass. Full-module UI checks verify Angmar's 15 XP once and TearsMessage's 50 XP / quest state 20. Startup/audio/effects, automatic camera obstruction, dialogue timing and broader AI remain open; test fixtures explicitly bypass initial startup. See [Evidence and limits](evidence/conversations-triggers.md).

**Exit gate:** complete a representative scripted encounter and conversation with visible, persistent consequences, not just a walkable scene.

### 4. NWScript and module behavior

**Largest single-player risk.**

**2026-10-11 execution checkpoint:** native-style object array allocation/insertion/lookup/deletion and internal/external namespaces; persistent module-wide records including inventory/equipment IDs; typed variable tables; NCS decoder/core VM; deferred script situations; linked-door mirroring and real Angmar/Brogan round-trip traversal. Witch's Wake client entry adds its 11 journal entries once, and the real transition script rejects possessed familiars. All 866 module/HAK NCS resources decode; 3,362 objects across 29 IFO-listed areas are indexed. Full startup remains blocked by character/XP, audio, cutscene and other unsupported engine calls, which produce explicit script/PC diagnostics. See [Evidence, tests and limits](evidence/script-object-runtime.md). This does not satisfy the phase exit gate.

- Implement an NWScript bytecode VM with stack/frame semantics, instruction behavior, errors, and event scheduling.
- Add engine calls in measured groups: object lookup, events, actions, inventory, dialogue, combat, effects, area transitions, and persistence.
- Validate each group against shipped scripts and target behavior. Do not treat xoreos or another implementation as proof of exact NWN:EE behavior without checking differences.
- Implement module/area/creature/placeable/door event ordering, timers, delayed commands, and script-driven state changes.

**Exit gate:** the target campaign's startup scripts and representative module scripts run without hand-coded per-module substitutions.

### 5. Resources, saves, audio, and presentation

- Complete format and lifecycle coverage needed by the corpus: remaining MDL mesh types/controllers, TXI/material parameters, fonts, portraits, GUI resources, and sound/music formats.
- Add audio playback, spatial/ambient audio, music changes, lip sync where practical, and sound cues for actions.
- Implement save/load for player and module state, versioned settings, recovery from corrupt/unsupported records, and deterministic resume tests.
- Replace approximation-only lighting, shadows, environment maps, transparency, and particle behavior where the compatibility corpus demonstrates a meaningful mismatch.
- Provide clear diagnostics for missing resources/scripts and preserve user-installed modules and HAK precedence.

**Exit gate:** the campaign can be saved, closed, resumed, and completed with required resources and feedback intact.

### 6. Single-player replacement candidate

- Remove development-only controls from the player workflow; keep them behind a developer mode.
- Add module selection, install/data discovery, content validation, settings, accessibility, input remapping, logs, and graceful unsupported-content reporting.
- Run a compatibility matrix over the chosen base campaigns and selected user modules; fix blockers in startup, traversal, combat, conversations, saves, and UI.
- Profile large areas and long sessions; test memory/resource disposal, alt-tab, resize, controller focus, and common display configurations.

**Candidate gate:** a user with a legitimate NWN:EE installation can launch and finish the agreed single-player corpus without starting the original client, with no progression-blocking defects and documented remaining differences.

### 7. NWN:EE multiplayer client compatibility

**Required interoperability gate.** Transport/session implementation remains a separate milestone; native IDs, server authority, action requests and reconciliation must shape earlier architecture. The replacement is intended to coexist with original clients, not merely reproduce a local encounter.

- Reconcile existing protocol research in `../FullDecomp`; map handshake, authentication, version negotiation, message framing, compression/encryption, and disconnect/error behavior.
- Implement protocol and session state, then server-authoritative area/object replication, player actions, chat, party state, inventory updates, and area transitions.
- Validate against an authorized local NWN:EE server across reconnects, latency/loss, version mismatch, and multiple clients. Keep server simulation authoritative; do not silently substitute local state.
- Treat anti-cheat, account services, persistence ownership, and server extensions as explicit compatibility questions.

**Candidate gate:** connect to an unmodified target server alongside an original client, pass the documented combat/state compatibility matrix with no unexplained divergence, and recover cleanly from reconnect and version/error cases. Compare both participants' authoritative outcomes, identities, event attribution and presentation; a successful connection alone is insufficient.

## Recommended next milestone

2026-10-13: Interactive combat session configuration now supplies selectable local PvP and keeps native AI/perception active when opening scripts are skipped. Failed individual perception queries are recorded without freezing other queries or action clocks; this is a replacement recovery policy, not native indoor-sound parity. Repeated HUD errors notify once per area while retaining every diagnostic occurrence. An installed Prelude/fighter input trace starts a real round and changes the authored goblin's HP17→−11 without creature overrides; the user observed rolls/damage. **966 tests, build and eight original perception observations pass; combat is not ready.** NPC scripts, indoor sound, presentation and the existing ranged/death/equipment/full-fight gates remain. See [UI session evidence](evidence/combat-ui-session.md). Checkpoint: `backups/combat-ui-session-966-checkpoint-20261013-v2.zip` (active launcher stdout/stderr excluded).

2026-10-13: Native ranged ammunition availability/release/consumption, separate post-hit owner, projectile timing/reactions, miss trajectories, called-shot coordination and event21 recipient delivery are connected. Active2DA data supplies limb, damage-projectile, weight and encumbrance rules. Three replacement fixture strikes consume100→97 arrows and damage20→14HP without engine failures. **963 tests, production build,45 original combat observations, eight perception events and three death/XP observations pass; combat is not ready.** Complete event11 destruction/unequipping and auto-equip side effects, status/on-hit/death owners, remaining frame/faction/movement/presentation and full independent native encounter comparison before the combat gate; casting follows. See [ranged evidence and limits](evidence/combat-native-ranged.md). Checkpoint: `backups/combat-native-ranged-963-checkpoint-20261013.zip`. This supersedes the916 checkpoint below.

Verification for the following death/movement checkpoint: **916 tests, production build,45 original combat observations, eight perception events and the three scripted death/XP observations pass.** Saved source/evidence: `backups/combat-native-death-movement-916-checkpoint-20261013.zip`. Ranged owners are next.

2026-10-13: Independent original scripted death/XP comparison now matches before/OnDeath/after observations, including HP−80 and50XP. It exposed and corrected NWScript GetIsPC to query attached client ownership independently of stats PC flags. Death magic-immunity/bypass/feedback and active visualeffects.2da purge rules are connected. Native safe-direction fallback and blocked movement event31/GetBlockingDoor are connected; both clear and overlapping loaded-fighter approaches complete kills and1806XP awards without engine failures. Full encounter/RNG/network validation, faction/PVP/associates/history, corpse/encounter, status/on-hit/ranged/traps and animation/UI remain open. **Combat is not ready.** See [XP evidence](evidence/combat-native-death-experience.md) and [movement evidence](evidence/combat-native-bump-friends.md). This supersedes the901 checkpoint below.

2026-10-13: Native faction owners now retain ordered canonical member IDs, append-index allocation and deleted slots; normal creature loading and combat broadcasts use these lists. Ordinary creature death clears shared actions, adjusts witnesses, assigns killer/runs OnDeath/applies native XP, clears the same status WORD used by movement/perception, and retains the corpse ID. Native AddExperience/SetExperience award/feedback coordinators are connected; native level-history side effects and full death/corpse owners remain incomplete. Actual loaded fighter input approaches, kills HP20→−11 and receives1806 XP with no engine errors in an explicit authored fixture. Direct BumpFriends displacement and fallback ordering are mapped; safe-direction search/event31 remain open. **901 tests, production build,45 earlier original combat observations and eight perception events pass; combat is not ready.** Continue independent original death/XP encounter comparison, remaining faction/PVP/associate/history, death/corpse/encounter, movement fallback, status/on-hit/ranged/traps and animation/UI owners before combat readiness; casting follows. See [faction evidence](evidence/combat-native-factions.md), [XP evidence](evidence/combat-native-death-experience.md) and [friend displacement](evidence/combat-native-bump-friends.md). Checkpoint: `backups/combat-native-faction-death-901-checkpoint-20261013.zip`. This supersedes the881 checkpoint below.

2026-10-13: Native creature frame timing/active timer selection, decoded normal Attack input, radial target Attack, canonical creature render positions and Cleave/Circle Kick insertion are connected. Death XP calculation/recipient coordinator follows active physical XPTable data but is **not yet bound to native faction storage/death awards**. **881 tests, production build, eight-event original perception comparison and45 earlier original combat observations pass; combat is not ready.** Native-style ordinary NPC melee and decoded-input fixtures repeat attacks/delayed damage without errors; immortal targets and omitted scripts do not validate a complete fight. Continue full death/faction/XP/corpse ownership, status/on-hit/ranged/traps, remaining movement, native clip/presentation and complete original encounter comparisons before the combat gate. See [frame/input evidence](evidence/combat-native-frame-input.md) and [death XP evidence](evidence/combat-native-death-experience.md). Source/evidence checkpoint: `backups/combat-native-player-frame-xp-881-checkpoint-20261013.zip`. This supersedes the849 checkpoint below.

2026-10-13: Native module/area AI rotation, calendar/day/night transitions, heartbeat scripts and shared weather RNG are connected after the AI master traversal. **849 tests, production build and the eight-event original-server perception comparison pass; combat is not ready.** GetTimeHour/Minute/Second now read the same world clock. Continue native creature active-timer/frame ownership, remaining movement/sound, trap/encounter/effect/status/death/ranged owners, combat input/presentation and full original encounter comparisons before the combat gate; casting follows. See [module clock evidence](evidence/combat-native-module-clock.md). Source/evidence checkpoint: `backups/combat-native-module-ai-849-checkpoint-20261013.zip`. This supersedes the837 checkpoint below.

2026-10-13: Native Spot/Listen/stealth, visibility gain/loss, ScriptOnNotice, constructor RNG order, spawn/heartbeat, AI level storage/script locking and AI master event traversal are connected. **837 tests, production build and an eight-event original-server perception comparison pass; combat is not ready.** The live AI loop reproduces those same flags/events with target movement replayed manually. Complete native tile/indoor sound/safe-location/friend displacement, effect/status/death/ranged owners, area/module clock/trap/encounter updates, combat input/presentation and full original encounter comparisons before the combat gate; casting follows. See [perception evidence](evidence/combat-native-perception.md) and [AI evidence](evidence/combat-native-ai.md). Source/evidence checkpoint: `backups/combat-native-perception-ai-837-checkpoint-20261013.zip`. This supersedes the785 checkpoint below.

2026-10-13: Native blocked-path selection, grid search, route smoothing, creature bumpability, personal-space initialization and movement/approach cancellation are connected to canonical local state. **785 tests, production build and 50,003 independent grid-math instruction comparisons pass; combat is not ready.** A live action-queue fixture now routes around a blocking creature on real tiles. Native tile search, safe-location/friend displacement, perception/frame ownership, encounter activation, presentation and full native encounter comparison remain. Continue these dependencies and the remaining combat owners before casting. See [grid-search evidence](evidence/combat-native-grid.md). Source/evidence checkpoint: `backups/combat-native-grid-checkpoint-20261013.zip`. This supersedes the759 checkpoint below.

2026-10-13: Native approach/retarget/use-range owners, retry/wait actions, active CreatureSpeed rates, tile height, direct path plotting, waypoint walking and action1 are now connected to canonical local state. **759 tests and build pass; combat is not ready.** Actual blocked/interarea/safe-location searches, friend/door movement event owners, native perception/frame ownership, encounter activation, presentation and complete encounter comparison remain. See [approach/direct movement evidence](evidence/combat-native-approach.md). Continue those owners and the remaining combat branches; casting follows. Source checkpoint: `backups/combat-native-live-path-checkpoint-20261013.zip`. This supersedes the695 status below.

2026-10-13: Native combat steps now use real direct-line collision, persistent canonical uint32 spatial arrays, subarea membership/event10 dispatch and finite embedded-CRT orbital math. **695 tests and build pass; combat is not ready.** Native approach/pathfinding, perception, encounter/trap/AOE activation, presentation and independent encounter comparison remain. See [movement evidence](evidence/combat-native-movement.md). Next implement the native group-preserving approach action sequence and actual movement/check owners. Source/evidence backup: `backups/combat-native-movement-checkpoint-20261013.zip`. This supersedes the671 checkpoint below.

2026-10-13: Native ordinary tile/area LOS now drives default attack eligibility from active authored WOK AABB trees, surfacemat LineOfSight values and canonical door/placeable collision storage. **671 tests and build pass. Combat is not ready:** spatial lifecycle, approach/perception, orbital math, presentation and full native encounter differential validation remain. See [native LOS evidence](evidence/combat-native-los.md). Resource queries cover303 Prelude and1195 Witch's Wake tiles without failures; these are integration checks, not encounter parity. Next trace native position/subarea updates and actual approach/pathfinding. Source/evidence checkpoint `backups/combat-native-los-checkpoint-20261013.zip` supersedes652 below.

**2026-10-13 object collision checkpoint:**652 tests and the build pass. Initial area collision now uses native parallel arrays with canonical object IDs, capacity/hole/compaction rules, physical active placeables/door 2DA selection, original PWK/DWK transforms and detailed polygon/transparent-door queries. Installed Prelude/Witch's Wake collision stores contain143/630 placeables and38/89 doors; known missing PWKs follow the traced empty-mesh failure path while retaining diagnostics. Dynamic geometry mutations and ambiguous native scratch results fail explicitly. **Combat remains unfinished:** native tile AABB/area LOS, subarea/position lifecycle, approach/perception, orbital math, Attack input/presentation, remaining combat branches and ranged require completion and full encounter comparison. See [current object geometry evidence](evidence/combat-object-geometry.md); this supersedes statuses below.

**2026-10-13 native geometry checkpoint:**621 tests and the build pass. Canonical areas now retain signed native tile placements and lazily resolve active SET/WOK/surfacemat data. Native vertex snapping/deduplication, face classification, adjacency, clipping, triangle-height traversal, quarter turns, denied-tile polygons and creature-line eligibility are ported. All303 Prelude and1195 Witch's Wake tiles load through the same resource chain. A stationary world-frame melee fixture reaches delayed damage and another round with explicit LOS/stationary flags. **Combat remains unfinished:** detailed door/placeable collision/LOS, orbital math, subarea updates, approach/perception, Attack UI/presentation, special/status/on-hit/death and ranged need completion and full native encounter comparison. Native scratch-state/CRT-dispatch ambiguities are diagnosed instead of guessed. See [current native geometry evidence](evidence/combat-native-geometry.md); this supersedes implementation statuses below.

**2026-10-12 live action/clock/mode checkpoint:** shared object actions now drive the mapped attack owner during world updates. Native hostility/witness changes, module world-clock arithmetic, ordinary mode switching, target cleanup, round startup, strike dispatch and delayed damage are connected. Startup now preserves the native extra 500ms combat-step decrements and invalid-mode current-round attack bonus. **565 tests and the build pass**; installed Prelude/Witch's Wake action fixtures and the existing independent server capture comparison pass. **Combat is not ready:** Attack input/presentation, dynamic perception, native LOS/approach/pathfinding/combat-step movement, replacement target search, special/status/on-hit/death branches and ranged remain unfinished. Next finish geometry/movement and full encounter comparisons, then remaining combat branches; casting follows. See [current action-loop evidence](evidence/combat-action-loop.md). This supersedes the older checkpoint implementation statuses below.

**2026-10-12 strike/save/skill/oracle checkpoint:** native-traced roll, preparation, precision, defensive and damage/post-damage stages now have partial shared runtime adapters; saving throws preserve native bonus caps, immunity timing, rerolls and feedback ownership. Effective skill arithmetic, use gates and live skill effects follow active tables and native source stacking. All **443 tests** and the build pass. An authored fixture run by the unmodified native server independently agrees on three stat baselines, IsImmortal damage/history, three poison-immune saves, bare Parry/Spellcraft and stacked Parry buff/debuff results. Its logs are bound to the fixture hash. **Combat is still not playable end to end**, and Attack remains a placeholder. Complete the remaining live action/approach/perception, modifier/AC/parry/skill, spell/feat-use, on-hit/death, event-delivery and presentation providers; connect the complete round loop and compare full encounters. Casting remains unimplemented. See [Strike/save/native-oracle evidence](evidence/combat-strike-saves-oracle.md). This supersedes the checkpoint below.

**2026-10-12 reputation/lifecycle checkpoint:** shared creature reputation and persistent attack storage now support native-traced target changes, attack cancellation, group sequencing, defender timing and delayed damage events. All 358 tests and the build pass, with installed module checks and bundled character rendering. **Combat remains incomplete:** complete dynamic perception/client ownership, native geometry/approach, attack preparation/default strike/post-hit providers and all live combat event handlers; then drain the shared action queue into actual round/strike/presentation work. Finish special/defensive/death/AI/status/shield/concentration branches and compare full encounters against the original game. Casting follows combat and is not implemented. Original-server coexistence remains a separate required gate. See [Reputation/lifecycle evidence](evidence/combat-reputation-lifecycle.md), [Object-action evidence](evidence/combat-object-actions.md), [Timing/action evidence](evidence/combat-scheduler.md), [Damage effects](evidence/combat-damage-bonuses.md), [Live runtime evidence](evidence/combat-damage-runtime.md) and [Resolution evidence](evidence/combat-resolution.md). This supersedes the next-work recommendations below.

**2026-10-12 final modifier checkpoint:** script-visible AC, nominal melee/offhand/ranged bonuses, final saves and positive stat effects now refresh shared canonical state through XP changes, area entry and effect lifecycle. Character UI and authored startup checks pass with 159 tests. All 39 AC snapshots match; 38 final-save snapshots match under both Prelude and Witch's Wake. The Weapon Master discrepancy remains recorded, with no character/campaign exception. Next: opponent-specific AC/attack, immunity-aware decreases and temporary ability effects, actual equipment mutation and an independent native modifier oracle; then a narrow melee round with RNG/event comparisons. See [Final modifier evidence](evidence/combat-final-modifiers.md). This supersedes the next-work recommendation in the historical base checkpoint below.

**2026-10-12 base combat checkpoint:** shared native-traced class/epic base attack and base save providers, feat/ruleset bonuses, uint64 ruleset hashing and native ability-modifier arithmetic now recompute from live character state. `GetBaseAttackBonus` and clearly labeled base values in the character panel are connected. 141 tests pass; all 39 BICs load under Prelude and Witch's Wake, all 17 available base-attack snapshots match, and native startup rollback changes BAB 7→0 with base saves 5/5/9→0/0/2. Eight partial save snapshot discrepancies remain recorded. Next: effective armor class, final attack/save modifiers and equipment/effect lifecycle, then a narrowly scoped melee round with an independent native oracle. Combat resolution and multiplayer parity are not established. See [Base combat provider evidence](evidence/combat-stat-providers.md).

**2026-10-12 character rules checkpoint:** native-mapped PC XP reduction and stored future-history replay now reconcile class slots, abilities, feats, skills, HP and spells on shared live state, retaining canonical IDs and immutable imported data. Class table references and equipped bonus-spell-slot counters are loaded through general rules/providers. 121 tests pass; all 17 installed high-level BICs pass loss/replay checks under Witch's Wake and Prelude resource chains. Startup-enabled UI observes level 1 / 5 HP; CopyObject and EffectDamage still block the opening. See [Character progression and broader rules map](evidence/character-progression.md).

**Priority after the user's rules/combat clarification:** shared runtime class/race/feat/skill/stat, attack/AC/save, equipment/effect providers and canonical object/item lifecycle come first, followed by a narrowly scoped, native-verified melee loop. Build class availability/alignment/prestige prerequisites, feat grants/selection prerequisites and skill purchase validation before enabling manual character creation and level-up UI; the entire selection UI need not block basic combat. Keep trusted stored-history replay separate from new-choice validation. Implement native mutation side effects and continue startup without campaign-specific substitutions. Apply the [Combat compatibility contract](evidence/combat-compatibility-contract.md) throughout; multiplayer coexistence is required.

**2026-10-11 startup checkpoint:** mapped Heal/CutsceneGhost records, separate uint64 effect handles, enumeration/removal/expiry, direct SetXP within the current level, and queued script sound routing with in-memory IMA decoding/output. 113 tests pass; real reward sound plays in the full-module UI check. Startup-enabled testing now reaches clone creation and native level rollback; it does not complete the opening. See [Startup effects/audio evidence](evidence/startup-effects-audio.md).

Continue **core gameplay systems** through the shared rules work above and canonical clone/item creation/destruction, then advance the actual opening script without a bypass. Its authored setup resets the PC to level 1 and replaces equipment; the XP/history slice now handles the reset, while object/equipment replacement remains open. Add damage and gold/equip rules, cutscene visuals/fades/camera and dynamic conversation objects in measured groups. Native cutscene abort, journal timestamps/party propagation, perception updates, camera obstruction, trigger/area-transfer ordering and the remaining HP discrepancy also remain open. Keep native object IDs canonical, including future authoritative external objects. Combat and multiplayer remain later gates.

## Risks and boundaries

- NWScript API breadth, exact event ordering, and target-specific behavior are likely to dominate single-player compatibility.
- NWN:EE networking is an independent protocol and authority problem; a working local client does not imply server compatibility.
- Visual completeness is cheaper than behavioral completeness; prioritize progression blockers and representative workflows.
- Use locally installed assets only. Do not copy game binaries/assets into this workspace or patch/inject/alter the running game.
- Ghidra remains valuable for unresolved target-specific behavior. The current WOK/PWK/DWK slices were readable text resources, so they did not require binary modification or speculative Ghidra edits.
