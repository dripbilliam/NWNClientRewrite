# Casting release and save DC continuation — 2026-10-14

Target remains NWN:EE89.8193.37-17, original win32/nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original image is read-only; isolated emulation maps its unchanged code.

## Implemented and compared

- Ordinary cast release checks preserve resource-before-failure ordering,
  armor signed BYTE caches, exact Silent exemptions, the verbal20% floor,
  school/global failure maximum, percentile draw order and cancellation.
- Automatic Quicken, defensive casting and active concentration checks now
  execute in the pure cast coordinator. Skill results, visual IDs, feedback,
  node class high-BYTE mutation and animation/lock cleanup follow the original.
- `ComputeSpellSaveDC1403861c0` includes normal class/domain/master fallback,
  negative levels, signed ability modifiers, highest focus tier and native
  special/feat/equipment override branches. `GetSpellSaveDC` is live through
  canonical objects and active class/spell/ruleset tables.
- Nine spell-failure BYTE cells initialize from stats ctor1403ee638/63f.
- UseConcentration+174 and HasProjectile+19c are distinct active INT metadata;
  HasProjectile is distinct from projectile travel's Proj+128.

Original captures:3490 complete ordinary cast traversals with captured lower
round/LOS/time/impact/effect/presentation/eligibility owners;2343 save DC
executions with captured class/ability/effect/feat queries. Metadata blocks
add16 scalar executions. Comparisons include customized rules, not just defaults.
Captured lower owners are comparison boundaries, never authorized live no-ops.

## Evidence correction

Earlier component caps used `PIC_AUTOMATIC_*` from a RIP-relative string suffix.
The compiler had already hashed the first E in R8 and passed the remaining text
to hash leaf1402ae870. Full labels are `EPIC_AUTOMATIC_*`. The oracle now executes
that leaf unchanged and looks up synthetic active overrides by full native hash.
The incorrect label expectation is superseded. An overridden focus bonus exposed
the same harness problem; corrected original capture matches the active override.
Failed v1/v2/etc captures remain retained and are not acceptance evidence.

## Required continuation

Further live work now includes creature impact8/item-on-hit19 context with418
native comparisons, effect creator spell/level attribution with209 comparisons,
EventSpellCastAt/target notification with2022 comparisons, save/duration helpers
with native wrapper comparisons, active dynamic Get2DAString and the actual
GetSpellCastItem API name. Native effect storage now initializes eight zero INT
cells, four FLOATs, two vectors and four INVALID object IDs. Visual constructor
defaults/transform writes compare with360 original command executions.

The active spell audit finds840 rows referencing618 impact scripts;596 load and
22 missing resource failures remain recorded. It is a static dependency scan,
not proof that bound commands cover all selected branches. All compiled saves
in this installed set have four arguments. Original short save/partially expanded
visual-transform VM ownership remains explicit, not guessed.

Direct authored impact probes reached Magic Missile107 and Heal79 NCS but
stopped at EffectVisualEffect before application. They are NOT full cast tests.
The visual constructor is subsequently implemented; application/removal and
rendering are the next active dependency. Failed probe-v1 files have no valid
JSON; v2 retains the actual failure and complete script/PC diagnostics.

Original visual application/removal owners are140434fc0/140439730; handler
registration at140426103/114 selects them for internal type30. Looping list
owners14048da00/140498960 append and remove the LAST matching record, rather
than all duplicates. Visual radius is FLOAT(native268+2); exact Type_FD F/P
or instant duration or exact miss==1 selects consumed one-shot delivery.
119 additionally consumes without delivery when plot!=0 or destroyable==0.
Original transformation controller/cue lifecycles remain required.

Periodic intermediate checkpoint `backups/live-native-casting-release-dc-20261014.zip`
contains3952 length/SHA256 verified files. Later live additions are not in that
archive until the next checkpoint. Latest validated suite before visual storage
correction:1234 tests pass; three old integer-prefix assertions were corrected
to reflect the native eight-cell constructor after that change.

Latest sealed periodic checkpoint:
`backups/live-native-spell-authored-helpers-1236-20261014.zip` —4029 verified
files,24,391,723 bytes.1236 tests/build and concurrent authored encounter
regression pass, with the same six observed omitted combat owners and two
installed missing resources. This bookkeeping backlink follows sealing.

Component state was rechecked before live binding: creature ctor14037a8c3/8c9
writes WORD65535. Canonical runtime already owns that exact default and its
movement/death/perception aliases; no forced casting-capability workaround
was introduced.

The full spell ecosystem is NOT complete. Actions15/18 and script/UI requests
still need live binding through their remaining admission, impact and
presentation owners. Delayed event8, authored ImpactScript execution/context,
effect constructors/handlers, resistance, interrupts, spontaneous/feat/item
casting, AoEs and visual/animation lifecycle remain required. Existing FMA/CPU,
saved effect import and PaleMaster HP readiness gaps remain open. Completion
requires authored cast regression and campaign playthrough, not these fixtures.
