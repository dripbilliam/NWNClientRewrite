# Native special-attack initialization and level20 eye effects

2026-10-27. **Integrated; headless component acceptance only.** Full gameplay
parity remains active/incomplete. Particle optimization, graphical tests, GPU
benchmarks and live server tests remain paused while the user plays another
game. No graphical client or server was started for this work.

## Original evidence

Read-only NWN:EE89.8193.37-17 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- `0x140810680..0x140810790` calls gate7fdca0 modes0/1 independently. Mode1
  calls eye owner8033c0. Mode0 with animation-base BYTE+dd equal1/2 loads paired
  ki slots through803c50; otherwise it requests cessation/speed1/flags1/time0
  on extant slots0/1. Eye eligibility does not require the mode0 feat predicate.
  An absent animation base is not unarmed.
- `0x1408033c0..0x140803c32` supports appearance WORD+cc0..6. Signed alignment
  WORD descriptor+c6 selects cached flags+208/+20c/+210 for below31, above69,
  and the middle range. Nonzero selected flags return. Otherwise destroy the
  previous model first. Flags commit even if allocation fails.
- Original model stem `vfx_monkeyes`: female BYTE+d0 equal1 appends
  df/ef/gf/af/f/of/f for appearance0..6; other genders append
  d/empty/g/ha/empty/empty/empty. Above69 appends01, middle range02, below31
  nothing. These literals are original model selection, not a new race table.
- Constructed monkeyes attaches to bodyFF head_g, flags0. Active appearance2DA
  HELMET_SCALE_F/M supplies scale, default1 only on lookup failure. Phenotype
  BYTE+d1 equal2 adds binary32(0.13). Request impact/speed1/flags0/time0 and
  ignore its returned value.
- Complete dossiers: `../backups/animations/rea-native-special-initialize-v1.json`
  and `rea-native-special-aura-v1.json`. They retain target identity, body ranges,
  assembly, calls and pseudocode; native-value-flow/raw duplicate payloads are
  omitted. Decompiler output is not original source or complete shader evidence.
- Caller receipts already retained in backups/animations:
  rea-current-creature-frame-v1.json subtracts the AI millisecond delta and
  calls810680 when its6000ms counter expires; the weapon-class refresh in
  rea-arelith-creature-appearance-refresh-v1.txt calls810680 after writing +dd.
  character-record-object-reader-v1.txt clamps the first replicated stats SHORT
  to0..100, stores descriptor+c6 and calls810680. Its field order corresponds to
  protocol stats.fieldDE4; assembly785289 writes it,7852bf calls initialization.

`scripts/inspect-native-special-initialization.py` executes both unchanged
owners offline in Unicorn. Report `native-special-initialization-original-v1`
contains192 initializer and672 eye-owner cases with executable/function/generator
hashes. Coverage includes stance/presence/slot masks, signed alignment thresholds,
appearance/gender/phenotype alternatives, cached flags, failed allocation and
scale lookup success/failure. Allocator/string, gate, model/virtual and table
boundaries are controlled. Complete callers, shaders, original model providers
and authoritative outcomes are outside this oracle.

## Native integration

`native_data/special_initialization.gd` preserves those transitions and binary32
boundaries. `special_attack_world.gd` invokes it on admitted actor/class/feat/
alignment/appearance/weapon-context changes and6000ms intervals. Elapsed time
comes from the world; there is no additional full-scene scan. Metadata equality
suppresses unchanged initialization, including active-table readiness.

Native workers/catalogs load original resources. The actual head_g Part supplies
current transforms; explicit scale survives later attachment updates. The active
server appearance table supplies scale. Missing eye-specific table/alignment
data defers only that effect, allowing independent paired-ki initialization to
proceed. Receiving the missing metadata retries without guessing a default eye.

Canonical lifetime, physical binding, requested/installed appearance and world
closure guard pending commands and owned models. A late resource cannot resurrect
an expired binding. No effect creates canonical object IDs or changes replicated
or authoritative state. Original unsupported appearance cases remain unsupported.

The actual stock vfx_monkeyesf/f01/f02 models have emitter Parts and **no clips**.
Gob052580 returns0 for missing impact;8033c0 ignores that result. Native code
issues the same request, retains the model and counts missing_clip_requests
without inventing animation. An existing clip whose provider fails remains an
integration failure. The headless report retains actual resource hashes and Part
features. Particle visibility still follows the existing Options setting.

## Verification and limits

All final reports below use test-native-kernel-debugger.ps1 headlessly, source
pins, captured stderr, four native exception traps and verified termination.
Every final proof has sourceUnchanged=true, no engine/lifetime error or native
exception. No graphical run, public connection or localhost server was used.

| Report prefix in reports/ | Checks | Coverage |
| --- | ---: | --- |
| native-special-init-accept-data-v1 |865|864 independent original cases plus corpus gate |
| native-special-init-accept-world-v1 |27|Actual original body/paired ki/three eye models, head Parts/transforms, active custom scale, cadence, stance and deferred/replacement/close cleanup; queued live probe compilation |
| native-special-init-accept-unarmed-data-v1 |938|Original gate/load/play corpus |
| native-special-init-accept-unarmed-world-v1 |21|Actual unarmed model/events/lifetimes |
| native-special-init-accept-equipped-world-v1 |22|Actual equipped models/colour/attachment/lifetimes |
| native-special-init-accept-cast-world-v1 |28|Native casting/world regression |

Total1901 assertions. These are not actual server or pixel acceptance. Casting
retains its preexisting fx_ref-catalog and point-to-point-movement warnings; that
passing component test does not resolve those wider rendering gaps.

Historical failures remain: data-v1 had a bad preload path and was terminated
after a script error; world-v1 had a strict type warning; world-v2 restored a
test table after its owner closed; world-v3/v4 wrongly expected impact clips;
world-v5 wrongly expected mesh geometry instead of emitter Parts. world-v6 and
the final accept-world run pass with clean teardown. Particle simulation is
explicitly disabled in the headless world test; no FPS claim is made.

## Queued actual-server acceptance

Do **not** execute while testing is paused. The existing special-attack live
probe now checks paired-ki initialization before swings. For an original sample
with level20/supported appearance it also checks the selected eye resource,
physical head_g, emitted GPU geometry and shown/hidden pixels, saving
*-monk-eyes.png. An ineligible sample explicitly records missing eye coverage;
that is not evidence of parity. No live message, feat result, animation event or
server outcome is forced by the probe.

After permission resumes:

```powershell
./godot-client/tools/test-native-actions.ps1 -SpecialAttack -SpecialAttackKind quivering -Run native-special-initialization-live-v1
```

Run Stun/chained actions separately. Intermittent missing Stun output and the
chained Stun→cancel→Quivering failure remain open. Wider race/gender/shape/custom
resource pixels, complete clocks/shaders, reactions/death/audio and paired-client
gameplay still require original-server/client evidence.
