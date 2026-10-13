# Combat compatibility requirement — 2026-10-12

The user requires combat to be almost perfectly identical because the
replacement will participate alongside original clients. Server interoperability
is a required acceptance gate. This document records implementation and
validation requirements; it does not establish native combat semantics or
claim that combat/networking is currently implemented.

## Target and authority

- Initial target: NWN:EE `89.8193.37-17`, with the installed resource set and
  explicit module/HAK/custom-rule configuration recorded for each scenario.
- Separate local simulation from the network client's action requests and
  replicated state. In multiplayer, authoritative server results govern HP,
  damage, effects, death, ownership and action outcomes. Presentation or
  prediction must not commit competing combat results.
- Preserve server object identities and mapped native object/handle widths.
  Local imported IDs must never silently replace authoritative external IDs.
- Map native request messages, target references, sequencing, acknowledgements,
  cancellation, replication and reconciliation before implementing the wire
  adapter. Invented local message formats do not demonstrate compatibility.
- Protocol implementation may remain a later milestone, but authority boundaries
  must constrain today's object, action and combat interfaces.

## Fidelity required by each implemented combat slice

1. **Inputs and derived rules:** class/race/feat/skill providers; ability
   modifiers; base and adjusted attack/AC/saves; equipment, weapons and effects;
   stacking, caps, immunity/resistance, rounding and integer field behavior.
   Read tables through the actual module/HAK/base precedence and trace their
   consumers. Do not substitute generic tabletop formulas for verified code.
2. **Actions and rounds:** target validity, approach and reach, facing, action
   queue priority, attack scheduling, iteration/extra attacks, cancellation,
   interruptions, movement and exceptional attack conditions. Map each rule
   before treating it as supported; animation duration is not an assumed clock
   for hit resolution.
3. **Resolution:** native random draws and consumption order, attack/critical
   and concealment checks, damage components and mitigation, saving throws,
   immunity and effect application/removal/expiry. Matching a seed alone is not
   proof of matching random outcomes until the RNG and call order are mapped.
4. **Consequences:** HP and dying/death transitions, combat/script event order,
   attacker/target references, inventory/equipment effects, action cleanup and
   authoritative notifications. Final HP alone is insufficient validation.
5. **Client presentation:** attack animation selection, queued attack cues,
   hit/miss/damage feedback, sounds, floating text, combat log, target state and
   interrupt/death presentation. Associate cues with the correct native event
   and object. Timing tolerances require measured justification.

Known incomplete providers and unsupported calls continue to emit persistent
diagnostics. Placeholders and approximate behavior cannot satisfy a combat
compatibility gate.

## Validation and acceptance

For each slice, record build/resource hashes, configuration, native function
and call-site evidence, initial state, requested actions and ordered outcomes.
Keep observed behavior, inference and open questions distinct. Read-only
disassembly must include relevant tails/callers; another open implementation
or a familiar 2DA column name is supporting material, not an original-game
oracle. Do not modify/inject into the original game to obtain results.

Use repeatable scenarios against the original target. Obtain controlled inputs
through supported test-module/server interfaces or compare recorded native
outcomes; establish how rolls were controlled rather than assuming determinism.
Compare intermediate modifiers, draw order when observable, event order,
state changes and presentation cues. An expected value computed by the same
replacement formula is not independent evidence.

The first gate is a narrowly defined melee scenario backed by native traces
and independently verified outcomes. Then extend the matrix to weapon and
attack modes, multiclass/epic combinations, feats, armor/equipment, movement
and interruptions, spells/effects and the supported module/HAK overrides.
Coverage must be documented; passing basic melee does not mean all combat is
compatible.

The multiplayer gate requires the replacement and an original client on the
same unmodified target server. Exercise both attacking and receiving attacks,
multiple participants, cancellation, equipment/effect changes, death,
transitions and reconnects, followed by latency/loss/reordered-update cases.
Require consistent authoritative IDs/state and event attribution, no duplicate
or locally fabricated resolution, and no unexplained divergence in the claimed
scenario matrix. Preserve mismatches in the diagnostic journal and traces.

## Implementation order

Build shared runtime stat/feat/equipment/effect providers and canonical
object/item lifecycle first. Follow with verified melee action/round/damage
slices and their observation/replay adapters. Class eligibility and complete
new-choice level-up validation remain required before enabling their UI; they
need not all precede a narrowly scoped melee implementation.

The current progression evidence already identifies native base-attack/save
entry points but does not establish full combat calculations. `CopyObject` and
`EffectDamage` remain observed startup blockers. See
[Character progression](character-progression.md) and
[Runtime diagnostic recording](runtime-diagnostics.md).
