# Multiplayer spell wheel and innate input — 2026-10-18

Goal remains ACTIVE, full multiplayer scope unchanged. This is a focused input
and presentation checkpoint, not complete casting/combat or original-client
concurrent-play verification.

## Native evidence

Read-only installed x64 nwmain.exe build89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Vanilla nwserver.exe SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
REA dossiers and original-code oracle outputs are in backups/animations.

| Original owner | Findings and validation |
| --- | --- |
| Client spell gain7f6b20 | 1756 complete-owner oracle cases agree on signed BYTE ability/race/increase/bonus arithmetic, ruleset minimum, school bonus, native arcane INT equality, prestige divisors and rival class tie-breaking. Class/race/ability query leaves and final class-gain leaf are captured, not full rules initialization. |
| Stats ctor7ea230; I reader7b4f70; G/S stats | Native base/current cells are shared across I and G/S updates. False I ability-present flag preserves prior cells. Bonuses and Dex bonus initialize to0. I abilities populate the cache even before the character-sheet panel has been opened. |
| GetAbilityGainForLevel299710, increase7f1110, modifier7ec3a0, class gain299e40 | Active StatGainTable, SpellGainTable, racialtypes and ruleset adapters feed the verified gate. Native bounds, signed wrapping and aggregate clamp are retained. Provisional29aee0 dossier is unrelated, not evidence for ability gain. |
| Innate sender7bf6e0 → server4531b0/35 | 160 original sender/full server-reader cases, including full talent wrappers380fb0/380e20. DWORD spell, BYTE caster level and target/point flags; same native FLOAT magnitude threshold and Z+FLOAT0.3 as ordinary spells. No class/domain/meta/TargetType fields on this packet. Lower lookup/transport/feedback/final queue insertion are captured. |
| Radial selection9a4610 →804e20; hotbar target submit704420 | UI uses spell WORD and caster-level nibble, even when the replicated pool carries a larger BYTE. Encoder itself preserves full BYTE for typed callers. |
| Talent wrappers380fb0/380e20 | Object path resolves a creature and uses its native position, ignoring the supplied point. Ordinary location path queues directly; its GetArea branch belongs to item use. Server queues class254/domain0/meta0/conversion0 and owns admission, readiness and consumption. |

Native gates and wire fields are implemented generically. No spell-specific or
module-specific gameplay handler, local spell spend, spell resolver, AI or
scripts were added to multiplayer.

## Integrated behavior

The actual right-click wheel now uses shared native class/level/metamagic,
prepared/known/child-spell and conversion menus, using replicated player pools
and active module resources. Class tables are loaded from active class row
references. Domain/feat name prefetch does not grant client feat ownership.
Innate and feat/class-ability trees use their shared original-game menu owners.
Unimplemented feat, skill, mode and other actions still produce diagnostics.
Missing combat-mode/familiar projections are explicitly diagnosed.

Ordinary wheel selection sends native6/18. Innate wheel and type44 hotbar
selection route through a separate typed6/35 request, trusted-frame/session IPC,
current controlled actor/area generation and canonical target checks. Innate
hotbar counts count ready records with matching spell/caster BYTE, rather than
summing flag values. No replicated pools are spent locally. Target cancellation,
area changes and disconnect invalidate pending target selection.

## Live evidence and limits

Hidden offscreen GPU Electron renderer, real production pointer/menu handlers,
owned unmodified Prelude server on UDP5121, ordinary legal-character enforcement
left enabled. Credentials supplied only through the one-use encrypted loopback
input helper, never argv/environment/files. Each QA connection disconnects.

- v51, unchanged installed wizard:10 UI steps, two native6/18 requests,
  prepared Light readiness2→1→0,1867 GPU frames, no runtime error records.
  Actual right-click → Cast spell → Wizard → Cantrips → Light.
- v53, unchanged installed sorcerer:5 UI steps, one native6/18 request,
  per-day cantrip uses6→5,1512 GPU frames, no runtime error records.
  Native ability-gain gate therefore also participates in the live menu path.
- Both runs play conjure2/castup/castuplp and return to pause1. Short release
  clips are verified through actual playback events as well as500ms samples.
  Menu PNGs were visually inspected; packet records and authoritative updates
  were replayed with active installed rules. Existing effect/audio warnings
  remain visible; zero error records does not mean zero unsupported features.
- v52, fresh data-driven level-one character with two explicitly authored
  innate Light records for protocol QA: **character rejected**, reason66222.
  Scoped server observation reports too many feats. No world entry or casts.
  This is an unresolved creator/admission issue, not live innate success.
  The generated BIC was confined to an OS temporary directory and removed;
  no game assets or BIC are included in the checkpoint. ELC was not disabled.

The160-case native innate oracle and targeter/IPC/pool tests pass; live innate
wheel/hotbar consumption still needs an admissible fixture or server-issued
ability/control context. Do not bypass server admission to manufacture success.
The rejected fixture does not isolate whether its innate records would pass
later ELC checks. First trace native feat-budget validation against the creator.

Validation:84 focused tests PASS (`network-spell-wheel-tests-v10.txt`), covering
native/shared menus, packets, targeter, IPC/session, real capture replay,
canonical state, combat/cast presentation and private input helper. Production
build and JS syntax checks pass. No all-tests/full-campaign claim.
Final build log is `network-spell-wheel-build-v4.txt`. Credential audit3402
source/evidence/research/current-capture files, private hits0
(`network-spell-wheel-credential-audit-v1.txt`). Private server profile, identity,
settings and logs are excluded from backups.

Next: resolve generated-character native feat-budget rejection; obtain real
innate wheel/hotbar evidence; connect server-owned feat/item powers, preparation,
remaining target/feedback/effect/audio owners, wider combat and original-client
concurrent play. Generic manual picker still uses renderer ray-hit points; the
direct object wheel now stores the canonical replicated target position.

Verified checkpoint `multiplayer-spell-wheel-20261018-v1.zip`:12984 files,
245092442 bytes. Writer4589 finished terminal0; all entry lengths/SHA256
verified. Scope41 required present, forbidden0. Scope audit and this postseal
note are outside the sealed archive. Only audited REA stderr is included from
runtime-logs; original binaries/assets/BICs/server profile are excluded.
