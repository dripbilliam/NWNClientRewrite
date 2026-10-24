# Mesh self-illumination controller — 2026-10-19

Live v129 exposed `network.area-visual-failed`, visual253: `Native trimesh
controller field 128/3 is unavailable`. Installed visualeffects.2da selects
vim_spike. This resource has42 meshes whose static controller100 remaps to
runtime byte displacement128, with three float components. No visual, spell,
module or server-specific production branch was added.

Read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original game, server and Ghidra databases remain unchanged. Retained REA
dossiers are rea-mesh-controller-{part-constructor,parse-field,control,
control-body,draw,render-flat}.json under backups/animations.

PartTriMesh constructor140087fd0 initializes80..88 to zero and alphaA8 to one.
MdlNodeTriMeshParseField1400931a0 binds `selfillumcolor`, its linear keys and
Bezier keys to80. ReadBinaryNode14007b870 remaps disk100 -> runtime128 for
meshes. MdlNodeTriMeshControl1400930e0 jumps to complete InternalControl140052520:
call140052546 queries the physical mesh Part through vtable58; tail140052569
enters generic controller owner140051c50. The generic vector sampler applies
position scale only at displacement16, not128.

New isolated oracle executes complete InternalControl, actual AsPartTriMesh
leaf14008c4e0, generic controller owner and original vector/scalar samplers.
75 cases cover before/inside/after key times, negative/zero/fractional/full/
extrapolated weights and three position scales; neighboring fields are checked.
Synthetic Part/controller storage is explicit. This does not prove allocation,
the complete loader, GPU lighting, scene scheduling or native color conversion.

The replacement now retains the vector field, applies existing native blend/
sampling rules, and publishes it to each instance's emissive material. Binary
base/animation decoding recognizes mesh100 separately from overlapping light/
emitter channels; ASCII supports single/linear/Bezier selfillumcolor. Legacy
playback restores the authored material color when the next clip omits it;
native playback retains existing omitted-channel behavior. Mutable materials
are isolated between instances. Singleplayer and multiplayer share this path.

The Three Lambert emissive adapter and sRGB conversion follow the replacement's
existing diffuse/light color convention. Exact original GPU lighting and color
space are not proven by the controller oracle. Native RenderFlat1400a4710 and
PartTriMesh::Draw1400a24c0 dossiers alone do not establish that renderer parity.

Validation:13 focused checks and113 affected rendering/scene checks PASS;
build PASS (existing bundle-size warning). Read-only installed vim_spike replay
completes its2.3s native impact run over150 updates, checking6300 mesh/controller
material observations without the prior exception. No game asset was copied.
This numeric installed replay is not a claim of new live effect pixels/audio.
Fresh live acceptance remains required; full multiplayer goal remains active.
