# Native multiplayer damage feedback and floating text

CC18/3 now decodes canonical source/target IDs, build-gated13/32 optional14-bit
damage values and optional combat-debug text. These are server results only.
Formatting sums/group totals for display; it never rolls damage, changes HP,
spends spells, creates objects or competes with server AI/scripts. Existing
object/attack/effect replication still owns gameplay state and animations.

Read-only original NWN:EE89.8193.37-17 win64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original binary, running original process or vanilla server was patched.

## Original evidence

Client dispatcher140770c80 jump table14077a5ac selects CC3 at14077115e; bounded
branch ends14077260d ->77a4cd. The actual original vector resize140768770 is
executed by the fixture; it is a generic vector owner, not a semantic ordering
function. Rule pointers+130/+3a0/+3a8 and referenced resource strings identify
active DamageTypes and DamageTypeGroups. Integer cells supply DamageTypeGroup,
ColorR/G/B and FeedbackStrref. Missing cells retain native skip/default behavior.
Group order is native row order; zero and absent damage remain distinct.

`inspect-native-damage-feedback.py`:2592 complete original branch executions.
Matrix covers both build answers, six damage patterns, source/target name
availability, missing/local/other controlled creature, three floating modes,
three rule profiles and debug on/off. Scalar/2DA/name/TLK/string/GUI services are
captured lower boundaries; arithmetic, branches, group accumulation and colors
execute unchanged. Old-layout tests do not invent the uninitialized extended
stack slots that an older server combined with an expanded damage table could
make the original read. The port explicitly diagnoses that unsupported pairing.

`inspect-native-damage-feedback-wire.py`:60 complete original server writer
1404cf090 cases with real native message/object/string/bit codecs, including
build-dependent count, noncanonical input narrowing, debug bytes and high IDs.
CC getters, client build answer, ownership/cleanup and final transport remain
captured lower boundaries. Packet comparisons exclude only unowned low bits of
the final fragment; the used-bit count comes from the first fragment header,
not the packet's final byte. This distinction matters for multiple bit bytes.

Installed TLK10466 and active group FeedbackStrrefs supply text. CUSTOM0 receives
colored source, CUSTOM1 target/fallback, CUSTOM2 total; subsequent groups replace
CUSTOM0 with each amount. Native fallback name fetch/write order is preserved.
Default log colorff6601; group RGB components below1 clamp to1, others narrow to
BYTE. No module/spell/English damage-type database is embedded.

Native float creation140766a70 and widget constructor972300/setters972670,
972680,9726c0,972750 establish owner ID, optional shadow, font and duration.
Actual overridden frame comes from vtable140e70d18+58 ->140972840; the earlier
interior query9727e0 resolves to the text setter and is not update evidence.
`inspect-native-floating-frame.py`:576 complete native frame cases prove1.5sec
lifetime,0.5world-unit/sec rise above owner Z+2, final0.5sec alpha fade, float32
updates, owner/model/world absence gates and truncating screen rounding. The
renderer reuses this pure frame state with the actual scene/camera adapter.

Native font TGA/TXI2022 resources `fnt_floaty_smal` supply glyph art/metrics;
the label alignment setter715100 and pnl_floatytext hooks establish centered
foreground and optional offset shadow. Resources are loaded in memory from the
active resolver. No proprietary fonts, textures or models are copied to source.
Font loading is asynchronous and cannot block received world updates. Entries
and pending font results are scoped to the connection/area and expire/reset.

Static option-reference/instruction evidence around1406b7d36/7e92/7f06 establishes
`ui.floating-text-feedback` defaulttrue, totals-only defaultfalse and total color
`#9999ff`. Both boolean controls are available in our Options panel. The huge
containing options-loader analysis failed; bounded instructions are the evidence,
not a full-loader decompilation claim. Full native GUI scale, GPU blending and
multi-widget admission/overlap still require original-client visual comparison.

## Validation

326 relevant tests pass, including all2592 formatter outputs/token/service traces,
60 real native packet writers,576 native frames, strict malformed packets,
active rules, canonical HP nonmutation, bitmap metadata bounds and existing
network/casting/token behavior. The sealed vanilla-server v34 packet decodes to
the same24 damage and canonical IDs as its recorded killing-blow animation;
replay now declares that capture's known8193.37.17 server build explicitly.

Installed Electron HUD fixture passes with actual damage text, nested colors,
native bitmap digit pixels and canonical nonmutation. Screenshot inspected.
Fixture damage is synthetic; it never writes gameplay state or sends packets.
Build passes with the existing bundle-size warning. Source backup and new live
acceptance are recorded separately below when complete.

## Remaining scope

Attack/miss/result CC5/6 and other CC minors are still unhandled, as are complex
generic CC11 branches, portions of spatial/voice audio and broader shared combat.
This does not complete multiplayer, combat or casting. The full goal stays active.


## Verified checkpoint and deployment

Checkpoint multiplayer-damage-feedback-20261019-v1.zip VERIFIED14961files/436615411bytes; writer46678 terminal0. Independent audit80973 terminal0:14962entries/52required/0missing/forbidden/duplicates/new credential candidates,78changed/new text scanned, every entry length/hash verified.326tests and buildv3 PASS. The checkpoint also preserves sealed v111/v112/v113 reports; active/future v114/v115/v116 captures are excluded.

SEALED controlled test v115/PID45440: local-network-damage-feedback-v115.json,65501992bytes,104wiremessages,9UI actions, finalclosed, no failure/sampleFailure. Summoned own familiar Kytos using existing feat shortcut, dragged active Magic Missile107 from level1 spellbook to empty quickbar34, activated and targeted the familiar through its actual portrait. Minimum-health guard26 passed with52HP. Native cast start/release and resource consumption occurred, but no incoming18/3 damage packet was emitted; familiar HP remained52 and original character HP86 throughout. CC minors seen:8x3 and11x2. This is NOT live damage/floating-hit acceptance. A friendly-target restriction is only an inference; no reason has been proven. No client-side damage was fabricated.

LIVE passive v116/PID38376 plays m0q1a alongside original33744 on vanilla server20964. Startup window:echo replies19; zero errors, font failures, failed objects, unsupported game packets or sampler failures. No automated actions scheduled. v116 report unsealed while open. Prior v114/PID13380 closed normally and its report is sealed. Acceptance/post-seal evidence: network-damage-feedback-acceptance-v1.json.

Next: native CC5/6 attack/miss/result messages and a live hostile-target damage/floating check. The existing sealed v34 killing-blow damage packet is decoded/verified24; installed HUD/bitmap rendering uses isolated fixture input, not a new live hit. network-hostile-target-followup-v1.json records the already proven Bim dialog/door route from m0q1a to m0q1b using v107; weak-enemy route beyond that remains to verify. Do not reuse captured object IDs as commands. Full multiplayer goal remains ACTIVE, including actual shared combat/casting and audio.

Superseded by the later [attack-feedback/live acceptance checkpoint](multiplayer-attack-feedback.md): CC5/6 are implemented; successful sealed v119 verifies five positive spell hits totaling17 on the Mage's Challenge placeable, its removal and native quest progression, plus six ordinary attacks/threat confirmation on a protected practice creature. Source and report hashes are recorded there. v116 is sealed. Hostile/shared combat, live CC6 and remaining projectile/audio presentation still require work; the whole goal remains ACTIVE.
