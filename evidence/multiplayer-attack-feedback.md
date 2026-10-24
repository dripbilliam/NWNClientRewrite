# Native multiplayer attack feedback — 2026-10-19

CC18 minors5/6 now decode and present ordinary and special attack results. The
server remains the sole owner of rolls, damage, HP, resource use and combat AI.
This change does not complete combat or the active multiplayer goal.

Read-only target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
Original processes, binaries and Ghidra project were not patched or injected.

## Native evidence

Whole server writer1404cf090, original CHAR writer1402dacb0..1402dad86 and
actual scalar/string/object codecs execute in isolated Unicorn memory.1152
packets vary both minors, all4-bit results, signed modifier truncation, roll/
mode/concealment widths, offhand selection, sneak/death/coup flags, confirmation,
debug CP1252 strings and canonical high/invalid IDs. Data getters, debug-string
ownership, cleanup and final transport are explicit captured lower boundaries.
Every defined wire bit agrees; only native allocator tail padding is masked.
Strict truncated-field and trailing-data mutations reject.

Client branches140772612..140773d93 and140773d98..140774fb5 execute unchanged,
stopping at common dispatcher tail14077a4cd.1650 factored cases compare exact
formatted output, final tokens, service call order and floating events. Lower
scalar readers, strings/CRT, names, TLK/parser, feat lookup and GUI sinks are
synthetic providers. Finite profiles are not proof of the entire combat system.
Original cases include all result/mode nibbles, flag combinations, signed
boundaries, absent names/player/creature, option off, missing feat data and
special attack IDs. The oracle caught descriptor order and floating-owner
details that static reading alone had not established reliably.

Ordinary10470 and special10471 use different token slots. Result5/6 text only
exists in the special branch; ordinary7 has its own result. Confirmation61953
and concealment62336/62337 parse before the header overwrites shared tokens.
Source self/other colors are99ffff/cc99cc; outer attack text isff6601. Target
name is fetched first; missing names use8349. Special names use native special
sentinels or active feat.2da physical rows; native GetFeat1402a3bd0 and the
already verified LoadFeatInfo1402a8800 validity rule apply. No spell, module or
server-specific lookup has been added.

Unknown combat modes preserve the original scratch-string prefix and emit a
diagnostic; the formatter does not replace it with a guessed English label.
CC5 distinguishes mode0/9 from the prefix branch, while CC6 skips modes0/1.
Offhand, sneak/death, coup and special-minus534 prefixes retain native order.

Attack floating notices belong to the SOURCE creature, unlike damage digits
on the target. CC5 emits native precision/critical/coup/special notices; CC6
formats the special name and result and suppresses types867/868. Empty font
requests select the existing native widget default fnt_galahad14. The actual
installed bitmap atlas is loaded in memory; no proprietary assets are copied.
Lifetime/rise/fade remains shared with the previous original-derived renderer.
Multi-widget admission/overlap and exact native GUI scaling remain unverified.

## Validation and deployment boundary

294 network tests pass. Additional focused float/font/presentation/attack tests
pass; recorded vanilla v34 attacks now decode into CC5 rather than unsupported,
with their original canonical identities. Presentation tests preserve HP and
all canonical objects and use active feat metadata and server TLK overrides.
The production frontend AND main HUD route the new message kind.

Buildv1 passes with the existing bundle-size warning. Installed-resource HUD
fixture UIv2 exits0 and its screenshot was inspected: native critical roll/
confirmation text and actual bitmap Critical Hit notice appear in the split
system pane/world overlay. UIv1 failed a fixture-only assumption that the
bitmap marker contained its resource name; the actual marker is boolean and
UIv2 checks the resolved default font cache. Fixture input is synthetic, not a
new live damage claim.

Prior passive v116 closed normally; sealed report49333984bytes/230wiremessages,
final phaseclosed and no failure/sampleFailure. Original33744 and server20964
remain running. The owned integration harness now accepts revisioned additional
test steps through its workspace-only control file, so campaign navigation can
continue within one real native session. Steps still use production UI or
scoped IPC requests; they do not mutate replicated objects or execute scripts.

Next verify fresh hostile-target damage and shared gameplay live. The previous
familiar test had no CC3 packet or HP loss and remains insufficient evidence.

## Verified checkpoint and live acceptance

Base checkpoint multiplayer-attack-feedback-20261019-v1.zip contains14991files/
454080793bytes, every length/SHA256 verified. Independent scope audit verifies
14992entries/21required/0missing/forbidden/duplicates/new credential candidates.
The independent audit script and this post-seal note were written afterward;
the live follow-up checkpoint preserves them with the newer evidence.

v117 closed normally with retained test-driver failure: a reply-index override
from Olgerd collided with Jaroo's single Continue reply. The driver correctly
stopped automation. Revisioned controls now support explicit failure recovery,
retain recovered failures, publish control acknowledgements and reset entry
deduplication when conversation owner changes. v118 safely rejected an assumed
starting-door transition: the native server actually retained the character's
mage-room location across reconnect. Both failed driver reports remain sealed;
neither is claimed successful. v119 started without preset navigation and used
current authoritative positions, IDs and displayed dialogue choices.

Successful v119 closed normally:154616113bytes/554wiremessages,4actual quickbar/
canvas actions,2scoped movement requests,3interactions, no driver/control failure.
First Magic Missile targeted the plot-protected practice creature and produced
five real zero-damage packets. This proves live zero-value rendering, not HP loss.
Jaroo's full authored challenge dialogue then identified the actual placeable
statue. A second quickbar cast at that current replicated placeable produced
five native damage packets5,3,2,3,4 (17magical total), its removal and the trainer's
congratulations. The following normal dialogue completed the Mage's Challenge
and delivered the trainer's gift/progression. No local spell/damage/quest code
ran or changed server state directly.

Six actual ordinary-attack packets against the protected practice creature now
display native attack rolls, hit results and threat confirmation, followed by
authoritative zero damage and critical-hit immunity feedback. Normal server
movement stopped the practice attack. The PC stayed77/77HP; the connected
original player's canonical identity stayed86/86HP. Original-client display or
active shared combat was not observed, and no hostile victory is claimed.

Native damage-font screenshot and live attack/confirmation screenshot were
inspected. No renderer errors or feedback/font presentation failures occurred.
Warnings remain recorded, including node availability, emitter bounds and
projectile/spatial audio. Final projectile counters17received/4spawned include
NPC casts; they do NOT establish every player missile rendered. This is a
specific follow-up investigation, not hidden behind the successful damage test.

Compact authentic wire fixture binds packet indices/times to the sealed report's
SHA256. A regression checks six native attack results, confirmation, five
positive statue hits, zero protected-dummy damage and canonical nonmutation.
Final32focused tests pass; the earlier294network regression tests and build/UI
remain valid (no subsequent production changes). Acceptance JSON records limits.

Next: remaining player projectile presentation and a hostile/shared encounter;
the native character has completed wizard training in m0q1b. Continue through
the south assembly-hall guard using current replicated objects. Never infer
location or quest reset from a newly uploaded character file. Goal ACTIVE.

Post-seal live follow-up checkpoint multiplayer-attack-feedback-live-20261019-v1.zip VERIFIED25files/35937152bytes; independent audit45646 terminal0 verifies27entries, base-chain SHA256,3sealed reports,6required,0missing/forbidden/duplicates/new credential candidates. Extract base then overlay incremental source/evidence.

Passive v120/PID47812 is playing m0q1b at[62,40,0] alongside original33744 on vanilla server20964. No automated gameplay inputs or replies. Its full local-network-attack-feedback-v120.json remains unsealed while open; close only via network-renderer-control-v120.json when appropriate. Do not include active v120 stdout/stderr/live/control/full-report files in future checkpoints. No driver/control failure at ready check. User may move it; re-read state before further commands. This post-seal note is newer than both archives.
