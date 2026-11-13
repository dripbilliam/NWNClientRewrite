extends SceneTree
const Overlay=preload("res://tools/native_parity/highlighting/native_highlight_overlay.gd")
const ActorOwner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Enhanced=preload("res://systems/native_render/native_model_material.gd")
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func material_case(enhanced: bool) -> void:
	var authored:=StandardMaterial3D.new();authored.albedo_color=Color(0.25,0.5,0.75,0.6)
	authored.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;authored.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	var source: Material=authored
	if enhanced:
		source=Enhanced.new();source.configure(authored,[0.25,0.5,0.75],[0,0,0])
	var mesh:=MeshInstance3D.new();root.add_child(mesh);mesh.mesh=BoxMesh.new();mesh.material_override=source
	var hit:=BoxShape3D.new();mesh.set_meta("native_pick_geometry",hit)
	var owner:=ActorOwner.new();check(owner.enroll(mesh,0),"Real actor alpha wrapper enrolls transparent material")
	var material=mesh.material_override
	check(owner.set_alpha(0.35),"Real actor global alpha applies before highlight")
	var part_color: Color=material.actor_part_color;var current: Color=material.albedo_color
	var context=material.actor_alpha_context;var context_revision: int=context.revision
	var original_overlay:=StandardMaterial3D.new();mesh.material_overlay=original_overlay
	var overlay:=Overlay.create(Color(0.1,0.8,0.2))
	mesh.material_overlay=overlay
	check(mesh.material_override==material and material.actor_alpha_context==context and context.revision==context_revision,"Adding overlay never replaces private actor material/context or alpha revision")
	check(material.actor_part_color==part_color and material.albedo_color==current and absf(authored.albedo_color.a-0.6)<0.000001,"Adding overlay never resets raw Part/global/composed opacity or shared material")
	for frame in 8:
		material.publish_actor_part_pose(Color(0.25,0.5,0.75,0.2+float(frame)*0.05),Color.BLACK,true)
		check(mesh.material_overlay==overlay and absf(material.albedo_color.a-material.actor_part_color.a*0.35)<0.000001,"Animated transparent Part retains its global factor while highlighted")
	check(owner.set_alpha(0.0) and not mesh.visible and mesh.get_meta("native_pick_geometry")==hit and mesh.mesh!=null,"Zero global alpha still hides base/overlay without discarding target geometry")
	check(owner.set_alpha(0.5) and mesh.visible,"Restoring opacity cannot lose the independent Tab material")
	mesh.material_overlay=original_overlay
	check(mesh.material_overlay==original_overlay and material.actor_alpha_context==context and material.actor_part_color.a>0,"Unmark restores pre-existing overlay without mutating actor lifetime/state")
	owner.close();mesh.free()
func skin_channel_case() -> void:
	var skeleton:=Skeleton3D.new();root.add_child(skeleton);skeleton.add_bone("root");skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	var source:=StandardMaterial3D.new();source.albedo_color=Color(0.2,0.4,0.6,0.8)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_BONES]=PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0])
	arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
	var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var skin:=Skin.new();skin.add_bind(0,Transform3D.IDENTITY)
	var body:=MeshInstance3D.new();skeleton.add_child(body);body.mesh=geometry;body.skin=skin;body.skeleton=NodePath("..");body.material_override=source
	var held:=MeshInstance3D.new();root.add_child(held);held.mesh=BoxMesh.new();held.material_override=source
	var fx:=MeshInstance3D.new();root.add_child(fx);fx.mesh=BoxMesh.new();fx.material_override=source
	var owner:=ActorOwner.new();owner.enroll(body,0);owner.enroll(held,1);owner.enroll(fx,2)
	var indices:=ActorOwner.primary_model_indices([{}, {"equipmentSlot":16}, {"follow":true,"role":"arbitrary-vfx"}])
	check(indices==[0,1] and body.skin.get_bind_count()==1,"Actual skinned geometry and explicitly propagated held role remain separate from arbitrary VFX")
	owner.set_alpha(0.25,indices);owner.set_vector(3,[0.5,0.25,0.75],indices)
	check(absf(body.material_override.albedo_color.a-0.2)<0.000001 and absf(held.material_override.albedo_color.a-0.2)<0.000001,"Native invisibility alpha propagates to skin and held base passes")
	owner.set_vector(2,[0,1,0],indices)
	check(body.material_override.albedo_color.r==0 and absf(body.material_override.albedo_color.g-0.4)<0.000001 and body.material_override.albedo_color.b==0,"Tab channel2 colors the existing skin base pass without a duplicate skinned overlay")
	check(body.material_overlay==null and held.material_overlay==null and absf(body.material_override.albedo_color.a-0.2)<0.000001,"Tab vector leaves alpha product and overlay count unchanged")
	owner.set_vector(1,[1,0.5,0],indices)
	check(absf(body.material_override.albedo_color.r-0.2)<0.000001 and absf(body.material_override.albedo_color.g-0.2)<0.000001,"Hover channel1 takes native first-active precedence above Tab2 and Type5channel3")
	owner.set_vector(1,null,indices)
	check(body.material_override.albedo_color.r==0 and absf(held.material_override.albedo_color.g-0.4)<0.000001,"Clearing hover1 restores held and skin Tab2")
	owner.set_vector(2,null,indices)
	check(absf(body.material_override.albedo_color.r-0.1)<0.000001 and absf(body.material_override.albedo_color.b-0.45)<0.000001 and body.material_override.actor_alpha_context.vector_active[3]==1,"Clearing Tab2 preserves active Type5channel3")
	check(absf(fx.material_override.albedo_color.a-0.8)<0.000001 and absf(fx.material_override.albedo_color.r-0.2)<0.000001,"Unproven VFX descendants never receive parent highlight channels")
	var bounds:=Bounds.new();root.add_child(bounds)
	bounds.register_entity(1,skeleton,[],[{"anchor":body,"native_bounds":{"min":[0,0,0],"max":[1,1,0]},"is_skin":true,"subtree_enabled":true}],Color.GREEN,func(_index):return 0.25)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(3,3,3);bounds.mark([1]);bounds.tick(camera,2.5,0.3)
	check(bounds.stats.vertices==0 and body.visible,"Skin keeps native colored base pass while authored-box pass excludes its geometry")
	bounds.close();bounds.free();camera.free();owner.close();skeleton.free();held.free();fx.free()
func run() -> void:
	var color:=Color(0.2,0.6,0.8,0.99);var overlay:=Overlay.create(color)
	check(overlay.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"Native highlight pass is unlit")
	check(overlay.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and overlay.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Native SRC_ALPHA/ONE additive pass replaces ordinary alpha mixing")
	check(overlay.cull_mode==BaseMaterial3D.CULL_DISABLED,"Native highlight disables face culling")
	check(overlay.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED and not overlay.no_depth_test,"Native highlight preserves depth test while disabling depth writes")
	check(overlay.render_priority==Material.RENDER_PRIORITY_MAX,"Highlight sorts after ordinary transparent material priority")
	check(overlay.albedo_color==Color(0.2,0.6,0.8,0.28) and absf(color.a-0.99)<0.000001,"Explicit opacity preserves caller RGB and detached input")
	var other:=Overlay.create(Color.RED);check(other!=overlay and absf(overlay.albedo_color.r-0.2)<0.000001,"Per-entity overlay material remains independent")
	material_case(false);material_case(true);skin_channel_case()
	await process_frame
	print("NATIVE_PARITY_HIGHLIGHT_MATERIAL ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
