# Binary reference-node metadata — 2026-10-17

Follow-up: [dynamic child ownership and reference control](model-reference-ownership.md)
are now connected. Linked reattachment and static area expansion remain open.

Binary MDL reference nodes now retain the referenced model name, its complete
64-byte storage and the signed reattachable DWORD. They expose the same metadata
through the parsed properties and native node record. Previously the parser
advanced over this payload without reading it. Truncated payloads are rejected.
This increment completes parsing only; referenced child models and specialized
projectile paths remain unfinished and keep their diagnostics.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation and Ghidra project unchanged. The user requested a pause
at this completion; the full spellcasting/combat/campaign goal is incomplete.

## Implemented and validated

Original binary dispatcher14007abe0, reference branch14007b391 onward, copies
serialized node70..af to runtimeA0..DF and serializedB0 DWORD to runtimeE0.
The base reader14007b6c0 retains node flags and remaps controllers. The reference
name has 64 bytes of storage, rather than the 16-byte CResRef layout. The parser
preserves all bytes, decodes the name with the existing string reader and exposes
the DWORD as signed. A 64-byte field without a NUL retains all 64 characters.
The `Referenced model attachment` unsupported feature remains reported.

`scripts/inspect-native-binary-reference.py` executes the original dispatcher and
base reader with synthetic inputs. Allocator, memcpy and node-kind queries are
captured lower boundaries. It does not instantiate a child model. The capture
`backups/animations/native-binary-reference-observations.json` contains 36 cases:
empty/mixed-case/63-byte/64-byte/embedded-NUL names and six DWORD values including
both signed extremes. Tests compare bytes, decoded name, flags, reattachable and
controller remapping against that capture, and reject an extension one byte short.

Verification: 20 focused model tests, all 1879 tests, production build and the
installed normal casting UI regression pass. The UI exercises chant, CC8 text,
conjure/fade, projectile travel, body attachment and cleanup. It does not prove
reference-model rendering. Build retains its bundle-size warning.

Verified checkpoint: `backups/binary-reference-1879-20261017-v1.zip`,9817 files,
124194253 bytes. Every archived entry length and SHA256 was verified; process
31154 finished with exit0. These verification notes were added after sealing.

## Research retained for the next increment

These findings are evidence for future work, not implemented runtime behavior.
REA dossiers are retained as `backups/animations/rea-*.json`.

Native linked initializer140987f10, kind7, zeros velocity/acceleration and requires
the projectile model virtual140(255,1). With a target, it queries the cached impact
part through target model virtual138, then invokes projectile model virtual150
with that target model and the cached part, or `root` when the pose query fails.
With no target it creates `NewCAurObject("ref","dummytarget",null)` through
1400931f0, stores it at projectile230, sets its position and links to its root.
Kind7 does not dispatch ordinary basic motion. Existing presentation still
diagnoses it as unsupported; do not substitute invented homing movement.

Vtable bases140d81440/140d82f18/140d88a00 share virtual138=14008f4d0
Gob::GetPartPosition and virtual150=140093b50 Gob::ReattachReference. The latter
walks physical parts breadth first, in child order. Part virtual70 returns its
reference view. It requires reference header flags98 containing0x11,
reattachableE0 nonzero and referenced-model pointer68 nonnull. The referenced
model attaches via virtual98 to the supplied object/part; the null-target path
uses this Gob and the reference part name. It reads the referenced model position,
subtracts parent Gob positionA8/AC/B0, computes the current quaternion's forward
vector and applies RotationArc14022e1c0. Quaternion multiply14022ab00 receives
arc then current quaternion, writing the parent orientation after each eligible
reference. Ordering matters. With no eligible references this is a no-op.
This graph traversal and orientation behavior still need a composed native oracle.

Important ABI detail: Gob::SetPosition140095210 takes RCX=this, RDX=hidden Vector
return storage and R8=input Vector. Gob::GetPosition140048530 takes RCX=this and
RDX=return storage. Do not interpret the setter's two vectors as old/new position.

ASCII MdlNodeReference::InternalParseField14009e620 reads refModel intoA0 and
reattachable intoE0. The existing ASCII parser retains generic properties; this
increment adds normalized reference metadata only to the binary parser.
InternalCreateInstance140091af0 and wrapper140092e40 allocate PartReference78,
initialize the base part and set its vtable. They do not visibly initialize the
referenced-model pointer68/70. Its actual owner, child resource resolution,
initialization, replacement and destruction still need tracing. InternalControl
1400524d0 obtains PartReference then calls base control. InternalConJoin140091500
clones an E8-byte node; it does not establish child-model loading.

Kind12 math is already ported, but its `ref` object creation, position/orientation,
scene copying and reattachment remain unbound. Do not enable it just because the
payload is now parsed. The four installed kind7 spell models inspected during
research (wamar_001, wambo_001, wamdt_001, wthsh_001) have root/mesh/emitter nodes
and no reference node. That sample does not establish general resource coverage.

Remaining goal work also includes scene-hit/child projectile owners, moving loop
audio, shield equipment/model binding, complete client replication, remaining
effect/engine calls, combat and campaign playthrough. Resume from these explicit
gaps; do not mark the complete spell ecosystem or campaign finished.
