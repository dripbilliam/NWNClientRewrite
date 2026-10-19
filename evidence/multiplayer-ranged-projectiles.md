# Native multiplayer ranged presentation — 2026-10-18

Progress on the ACTIVE vanilla-server interoperability goal. Ranged attack
animations and separate server projectile messages now drive client visuals.
The replacement does not resolve attacks, roll damage, spend ammunition, run
combat AI or allocate visual IDs in the authoritative registry.

Target: installed unmodified nwmain.exe, build89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Owned nwserver.exe SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Original files/project remain read-only. No proprietary models or binaries copied.

## Executed native evidence

- Selector14080f5e0:1164 original executions, including ranged9→200,
  side2→1/contextE0/base1, parry12→262, creature lookup, missing weapon,
  attack-type storage, and the92/melee dispatch. Travel140762900 executes
  native magnitude2303d0 and finite sqrtc7d6d8, FLOAT operations and signed64
  truncation. Base-item mask8800000080000000 selects speed40 versus55; delay
  is half the WORD duration plus travel, wrapped to WORD. Missing creature
  retains its prior delay. This is presentation timing, not ResolveRangedAnimations.
- Sender1404df550 and bounded reader1407ac7d1..7ac97b:96 complete original
  sender/scalar/OBJECTID writer and original header/scalar/OBJECTID reader
  comparisons. Native envelope major34/minor1; appearance6 carries spell,
  7 carries spell/path, others carry path/base-item/result. Build gating,
  transport and final SendServerToPlayerMessage are captured lower boundaries.
  Raw external uint32 IDs are preserved. Truncation/excess streams are rejected
  before presentation; these are decoded game packets, not encrypted datagrams.
- Complete receiver1407ac670..7ae8c4:132 executions with synthetic rules,
  lookups, model/scene/path services and captured allocation/CRT byte search.
  Real scalar/string/resref/vector helpers execute. Checks cover ammunition1..6,
  legacy/signed-byte row selection, rhand launch offsets, source scale cap1.2,
  hit/block/miss target selection, result bytes, impact critical flag, facing2,
  path2/11/12/13 selection and impact0/8000ms lifetime. This is not a native
  renderer or model/path/AI oracle; those owners retain their existing separate
  fixtures. During oracle development the allocation hook initially observed the
  wrong address; v9 corrects it and reads the constructed projectile's fields.
- Gob::GetRandomPart14008f680 plus recursive Part14008f560/08f740:84 complete
  native cases verify cached areas, physical traversal, strict weighted boundary,
  fallback and CRT draw count. Original header copier140078ab0 separately
  verifies5 disk268→runtime2bc FLOAT copies. Binary parser retains that stored
  area; it does not recompute weights from animated/scaled triangles. Installed
  PLC_A08 physical hierarchy selects an actual authored mesh name.

Static evidence: base-items Load14029dfa0 stores AmmunitionType at BYTEac;
receiver uses active ammunitiontypes physical AmmunitionType and
DamageRangedProjectile columns, falling back to the old six-row blocks only
when either column is absent. Model/ShotSound/ImpactSound remain table data.
No bow/projectile model lookup is hardcoded in production.

Client options getter6ab9b0 and setter6bce30 connect BYTE40 to game.gore.
Registration6b995d..6b99be supplies default1 and its callback wrapper vtable
e2c6c8. The renderer currently uses that native default; a replacement options
UI/profile override is not implemented. Body-type/virtual-table candidates that
did not point to a valid function were discarded, not treated as proof.

## Integration and ownership

NetworkGameMessage decodes safe-projectile; NetworkFrontend serializes delivery
after area loading; NetworkScene forwards it to ClientProjectilePresentation.
The existing independently checked path/AI/stage/target/impact adapters are
shared by singleplayer and multiplayer. Native ranged dispatch is now connected
there too; singleplayer lazily resolves its active ammunitiontypes table.

ClientObjectArray accepts a native-pose projection for network proxies, including
static-position fallback after animation-only updates. Canonical uint32 IDs and
object identity survive; transient projectile/dummy IDs use a separate client
internal table. No server/local gameplay ID cursor or RNG is consumed. Tests
cover replaced identities, late model/rules loads after disposal, and visual
cleanup. The physical model-part adapter stores only small name/type/area
metadata on hierarchy groups, avoiding whole model copies in Three userData.

Projectile animators have one update owner. Scene disposal removes their models,
attachments, local tracking entries and object-array IDs. Projectiles receive
the presentation world clock; no locally resolved combat result is substituted.
Model resource names survive in bindings for native door/placeable impact names.

## Live owned vanilla-server evidence

User authorized clearing test sessions. All resets used the exact-install/profile
scoped launcher. Final server PID39860, Prelude,127.0.0.1:5121; all QA clients
closed. Last probe PID53832 is terminal/missing. Unchanged installed ranger BIC.

v40: request targeted a static/nonattackable object; no attacks/projectiles.
It is not a successful combat test. Also exposed inventory Q as unimplemented.
v41: correct dynamic chest; bowshot/bowrdy and11 native projectile messages,
but10 receiver failures exposed the unbound random-part owner. Retained failure.
v42: after weighted-part wiring,5 native attacks/projectiles,5 loaded/impacted,
0 failed. The24-second capture ended with the last native8-second attachment
still alive;4 destroyed. This is not a complete expiry assertion.
v43:38 seconds,2222 real GPU offscreen paints;7 native attack groups and7
separate native projectile packets. All7 loaded wamar_001 through active tables,
played stages1/2, attached to actual a08_impact, and expired:7 spawned/loaded/
impacted/destroyed,0 failed,0 active. Target removed; player animation1/bowrdy,
pending0/remainingnull/deferredfalse. No probe failure/sampleFailure, receiver/
update/model failures, scene-combat-unhandled or error diagnostics. Both attack
and final readiness PNGs inspected. This proves the tested bow/chest path, not
all ranged weapons, parry, creature encounters or original-client concurrency.

Replay now retains partial-record diagnostics instead of aborting or silently
claiming completeness. Both live/replay explicitly retain inventory channel Q
unavailable in the ranger startup packet. It remains independent required work.

## Verification and limits

229 focused network/animation/projectile/model/hierarchy/clock regression tests
PASSv2. Build PASSv5 (existing chunk-size warning); harness syntax PASS.
Source and this section's capture credential audit:2154files/private hits0.
An attempted scan of all unrelated historical captures timed out and is not
counted as validation; the focused audit completed. Credentials were provided
through encrypted loopback input and never source/files/environment/argv.

Remaining: native audio mixer/output, ranged blood/weapon VFX, shield equipment
impact model projection, full native client flag28 updates, ASCII mesh area
postprocessing, generic model/scene/material parity, native full SetBase and
pause/time ownership, and creature ranged/parry/thrown/crossbow live comparisons.
The default material remains the loaded model's DEFAULT; arbitrary material
override restoration is not claimed. Assembled model tree/attachment parity
beyond the checked physical traversal is not proven. Missing services remain
durable diagnostics. Spell requests/cast effects, quickbar/Q replication and
actual simultaneous original-client play remain ahead. Goal must stay ACTIVE.

Post-seal checkpoint `multiplayer-ranged-projectiles-20261018-v1.zip`:12760files,
228950147bytes. Writer37225 terminal0 consumed; every entry length/SHA256
verified.39selected required files present,0forbidden native assets/private
server-profile entries. These seal notes were added after archive creation.
