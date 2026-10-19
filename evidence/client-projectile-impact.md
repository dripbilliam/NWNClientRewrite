# Projectile body impact attachment — 2026-10-16

The live client now runs the native impact selection/pose/duration owner and
parents spell projectiles to authored target parts. It follows moving anchors,
applies the original root quaternion and forgets the attachment on destruction.
No spell ID/name branch was added. Full spellcasting/combat/campaign remains open.

Read-only original: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/Ghidra project unchanged. Prior verified checkpoint:
`backups/projectile-target-1865-20261016-v1.zip`,9732 files/122154044 bytes.
Verified checkpoint: `backups/projectile-impact-1869-20261016-v1.zip`,9753 files,
122516303 bytes. All entry lengths and SHA256 hashes verified.

## Native owners and ordering

AIUpdate140983860, after stage2, sound stop and impact one-shot, checks INT1e0
exactly1 at983e21. The impact fragment983e2e..9841d2 looks up target198 in the
client object array. Successful lookup initializes root-position zero and root
quaternion identity. Result BYTE1e4=0 checks model handle78 via1407630a0, then
INT28, then ready model virtual140 with part255/flags1. A nonzero28 clears
impact-duration1fc only if the handle exists. Result2 instead casts target to
creature, asks140800dd0 for slot20, resolves client item1406abc80, checks native
baseitem weapon-type BYTE8 exactly7 and then28 before querying item+48's model.
Results1/3 and other bytes have no body/shield attachment. Ready projectile model
is still queried when target lookup succeeded, even if the anchor is unavailable.

For result0 it calls model virtual98 with the cached target part and flags0 at
983f8a. Result2 consumes one client CRT draw and selects `imp_shield_1` or2 before
the same call at983ff4. Return from attachment does not gate subsequent pose work.
Virtual138 reads global root P/Q at98401e; missing part leaves initialized values.
Native Vector Pitch14022de40 and Yaw14022f690 operate directly on orientation44.
YawPitchRoll14022f6d0 receives yaw/pitch/roll0 at984049. Virtual130 then sets
global root position preserved from the read and this new quaternion at9840a7.
There is no model setter's preliminary normalization/near-zero cutoff here.

Afterward the creature/ranged visual170 branch has a separate14080bb10 owner.
Duration is copied from1fc to194 even on failed target lookup. Existing AI handles
the impact phase and expiry; the later destruction removes scene and model.

CNWCObject ctor140761760 writes INT28=0 at761914. This work preserves that exact
local client cell; its later native updates/meaning are still unproved and are
explicitly diagnosed. It is not synthesized from death, HP, visibility or another
server field. Getter1407630a0 simply returns78. Separately,140765920 writes
a9/ac/a4, snapshots time and calls display virtuals. Receiver1407ac670 calls it
on a dummy with args1/1/duration+500, then sets104=1. Complete dummy lifetime
requires tracing the later consumers; the old informal lifetime label alone is
not proof of allocation, area ownership, countdown or destruction behavior.

## Implementation

`client_projectile_impact.js` ports the body/shield decision tree with explicit
lower services. `client_projectile_orientation.js` shares the existing checked
rotation math while preserving the raw-vector impact entry point. Ordinary
model orientation retains its normalization/cutoff, verified by its existing130
original-code cases. Client mirrors own28 independently of canonical objects.
Projectile constructor ranged visual170 is initialized0 as in original9832a0.

`ClientProjectilePresentation` binds model/target lookup, body model availability,
parenting and global root get/set to the existing checked visual pose adapter.
It syncs attachments after projectile AI/motion so the renderer's scene root
tracks its anchor. Disposal forgets the attachment before model destruction.
Missing authored anchor and unavailable/update failures remain diagnostics.
Scene-sync exceptions are recorded and allocated projectiles are reclaimed.
The prior broad impact-attachment-unimplemented diagnostic is removed.

## Validation

`scripts/inspect-native-projectile-impact.py` executes unchanged original impact
instructions, handle getter and embedded vector/quaternion/SSE math. It captures
object/equipment/baseitem queries, model virtuals, strings, CRT RNG, sqrtf and
FP notifications as lower boundaries. This does not execute a full native Gob
scene. Ranged visual170 is clear in this oracle; its effect branch is excluded.
`native-projectile-impact-observations.json`:2472 cases across lookup/result,
handle/model readiness,28=0/1/-1, target creature/item/type, parenting and root
pose success/failure, CRT draws and seven vectors including zero/tiny vectors.
Tests compare exact call order, pose float bits and final duration/remaining.

Three renderer integration tests exercise actual Three scene/pose services:
authored part selection and a moving anchor through the impact lifetime, nonzero28
duration0/no parenting, and a missing anchor with diagnostic/normal cleanup.
They preserve authoritative registry identities/allocation counters and reclaim
the internal client ID, model and attachment. All1869 tests and build pass.

The installed UI test selects the untouched wizard's prepared spell through the
spellbook and world target. Active spell37 uses authored `vpr_los`, path1. Capture
`live-projectile-impact-ui.json` records impactAttach part `impact`, attachedtrue,
failed0, renderer errors[]. Existing chant, CC8 start/release, conjure/fade/
callback cleanup and projectile cleanup checks pass. Screenshot inspected;
existing dark/occluded geometry remains. Electron reports its known GPU command
buffer error after PASS/exit; full GPU stability is not established.

## Remaining work

Full native28 update replication is not proved. The verified shield decision tree
still lacks the live client equipment/item-model projection; entering it reports
an unavailable service. Ranged visuals14080bb10, other ammunition/weapon receiver
branches, camera-facing impact orientation, missing-target dummy, linked/ref and
scene-hit paths, child spawns, moving loop audio, complete packets/scene scheduling
and remaining spell effects/engine calls remain unfinished. This increment is
body impact presentation progress, not full combat or campaign parity.
