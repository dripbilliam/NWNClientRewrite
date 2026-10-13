# Combat resolution checkpoint — 2026-10-12

Updated implementation and validation status: [Combat action-loop checkpoint](combat-action-loop.md). Current dice and animation selection share the same session CRT stream; earlier separate-stream statements and test counts below are superseded.

Combat is not functional end to end. The providers below are implemented but
are not connected to a live attack action or complete combat UI/lifecycle.
Casting has been researched but is not implemented. Neither combat nor casting
passes the compatibility contract.

The latest [strike/save/native oracle checkpoint](combat-strike-saves-oracle.md)
supersedes historical test counts below, with 443 tests and a narrow independent
original-server fixture. It still does not establish a playable replacement
encounter or full parity.

The subsequent [live damage checkpoint](combat-damage-runtime.md) connects
partial script damage, base/temporary HP, mitigation and lifecycle events.
The later [damage-effect checkpoint](combat-damage-bonuses.md) adds equipment
and physical/energy effect-bonus providers. The later
[timing and action-dispatch checkpoint](combat-scheduler.md) adds live round
timing, direct round-end scripts and data-driven reach queries. The latest
[object-action and eligibility checkpoint](combat-object-actions.md) adds shared
creature action storage, AI summaries and cached visibility/spatial gates. Its
322-test validation is current; older validation below remains historical.

## Target and evidence

Target: installed NWN:EE 89.8193.37-17, `nwmain.exe` SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
Read-only full disassembly and Ghidra exports are retained in
`backups/animations/resolution-*.txt`. This extends
[final modifier evidence](combat-final-modifiers.md).

Implemented native-traced providers:

- `combat_context.js`: opponent-specific AC, visibility/flat-footed gates,
  touch attacks and conditional effect stacking (`0x1403f47f0`).
- `attack_modifier.js`: actual attack modifier, iterative/extra/offhand
  counters, mode/feat/effect/opponent bonuses (`0x1403f5d20`); special attack
  bonuses (`0x140412d20`) and favored-enemy acquisition (`0x140401020`).
- `combat_weapon.js`: current attack weapon (`0x1403760a0`), critical threat
  and multiplier (`0x1403fd040`, `0x1403fcf40`), Monk attack tables
  (`0x14040b510`), pre-epic attack count (`0x1403f8e10`), flat-footed query
  (`0x1403e3910`). Perception state is an explicit input; no see-all fallback.
- `attack_roll.js`: attack/parry/confirmation resolution (`0x1403e4100`) and
  concealment predicate/draw order (`0x1403e5630`). Critical confirmation
  tests total rather than assigning special results to natural 1/20.
- `combat_round.js`: native constructor, attack counts/groups, compressed
  timers, start/end lifecycle and weapon attack selection (`0x140373de0`,
  `0x1403773a0`, `0x140376ee0`, `0x140375a30`, `0x140375b80`,
  `0x140376a40`). These require scheduler animation pauses before use.
- `native_random.js`: target CRT LCG (`0x140c7ed00`) and byte-count dice
  (`0x1402ad680`). Native startup seeding/full draw order are not established.
  Script dice/Random now share this session stream.
- `damage_weight.js`: difficulty weighting (`0x1402a4220..0x1402a4341`),
  including signed int32 intermediates, direction precedence and extra RNG
  draws and the overflow-induced integer-division fault.
- `damage_roll.js`, `damage_bonus.js`, `unarmed_damage.js`: native damage dice,
  critical/maximize branches, sneak/death feat ladders, difficulty direction,
  Strength/mode/feat bonuses, and natural/Massive Critical property dice.
  Physical effect bonuses now use the shared mapped provider by default;
  mitigation still requires explicit caller queries and never defaults to
  zero. These providers are not attached to live attacks.
- `damage_weapon.js`, `damage_mitigation.js`, `creature_damage.js`: weapon
  flags/power, resistance/reduction plans with ordered budget/removal/feedback
  operations, and native base/temporary HP damage primitives. A subsequent
  partial local adapter connects these to live script damage; surrounding
  combat/death providers remain incomplete.

The installed resource chain now loads `nwn_retail.key` before `nwn_base.key`,
matching native KEY priority. The retail archive supplies the active
`damagetypes.2da`; damage constructors use its physical row count. Live script
immunity increases/decreases now maintain the native signed-byte cache through
application, deferred removal and expiry. Linked icons remain diagnosed.
See [Damage evidence and limits](combat-damage.md) for functions and call sites.

Shared runtime changes include native NPC/PC HP initialization, stat loading for
placed creatures, cached equipped effect projections, immunity-aware negative
attack/AC/save effects, and effect-immunity queries. `EffectDamage` constructs
the native integer layout, and its subsequent partial type-38 application is
documented in the live checkpoint. These changes do not implement a playable
attack or complete death lifecycle. Missing behavior remains diagnosed.

## Validation and limits

The current checkpoint passes all **233 tests** and the production build.
Prelude's 61/61 placed creatures and Witch's Wake's 228/228 load shared stats
without load diagnostics. Under both module rule chains, all 39 BICs load,
39/39 AC and 17/17 available BAB snapshots match, and 38/39 final save snapshots
match. The Weapon Master save discrepancy remains open. A hidden bundled
Electron full-area/character UI check also passes; existing scene omissions
remain visible. These checks are not independent native attack/damage or
multiplayer observations.

The persisted Ghidra projects were copied into
`backups/ghidra-saved-before-combat-20261012-042456` before copy-only analysis.
The backup excludes a locked temporary database; it covers the last saved
state, not uncommitted live state. `DecompileCombatCopy.java` clears incorrect
CALL_RETURN instruction overrides on verified returning cleanup calls in a
read-only headless copy. The first run exported six handlers and discarded its
changes. The installed game and open Ghidra project were not modified.

A second run using full PE-unwind ranges subsequently completed successfully,
exporting OnApplyDamage, GetDamageRoll, AIActionCastSpell, AddCastSpellActions,
ExecuteCommandCastSpell and AIActionAttackObject. The log confirms discarded
changes and no persisted original-project edits. The earlier approval-service
usage failure is resolved. Cleanup aliases can still truncate some bridge
pseudocode, so full hash-checked disassembly remains the controlling evidence.

## Required next work

Finish item/effect coverage and remaining damage/death providers beyond the
now-connected damage-effect queries and partial HP/script/event adapter;
trace perception and scheduler pause/cancellation inputs; connect actual combat
actions and presentation; compare a real melee encounter against an independent
native oracle. Then implement spell action/slot/DC/metamagic/interrupt handling,
spell impact scripts and their effects through the same canonical state.
Temporary ability effects, equipment mutation and the recorded Weapon Master
save discrepancy remain open. No campaign-specific exceptions were added.
