extends SceneTree
const Owner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Publication=preload("res://tools/native_parity/ui/actor-alpha-publication.gd")
const Enhanced=preload("res://systems/native_render/native_model_material.gd")
const Pose=preload("res://systems/model_native_pose.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const LightPolicy=preload("res://systems/native_render/native_light_policy.gd")
var checks:=0
var failures: Array=[]
var actual_native_storage_cases:=0
var retained_extension: Resource
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func close_enough(a: float,b: float) -> bool:return absf(a-b)<0.000001
func additive_emission_matches(material,addition: Vector3) -> bool:
	var raw: Color=material.actor_part_emission.linear_to_srgb();var sum:=Color(raw.r+addition.x,raw.g+addition.y,raw.b+addition.z)
	if material is StandardMaterial3D:return material.emission.is_equal_approx(sum.srgb_to_linear())
	return material.get_shader_parameter("native_emission").is_equal_approx(LightPolicy.linear_rgb([sum.r,sum.g,sum.b]))
func source_material(enhanced: bool,alpha: float=1.0) -> Material:
	var base:=StandardMaterial3D.new();base.albedo_color=Color(0.2,0.4,0.6,alpha)
	base.roughness=0.73;base.cull_mode=BaseMaterial3D.CULL_DISABLED
	if not enhanced:return base
	var result:=Enhanced.new();result.configure(base,[0.3,0.4,0.5],[0.0,0.0,0.0]);return result
func mesh_with(material: Material) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();root.add_child(mesh);mesh.mesh=BoxMesh.new();mesh.material_override=material
	mesh.set_meta("native_pick_geometry",BoxShape3D.new());return mesh
func source_node(alpha: float) -> Dictionary:
	return {"id34":0,"flags98":0,"controllers78":[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":168}],"controllerCount80":1,"values88":PackedFloat32Array([0.0,alpha]),"children68":[],"childCount70":0}
func pose_case(enhanced: bool,direct: bool,native: bool=false) -> void:
	var base:=source_material(enhanced,0.4);var part:=Node3D.new();root.add_child(part)
	var mesh:=mesh_with(base);mesh.reparent(part,false);var hit=mesh.get_meta("native_pick_geometry")
	var owner:=Owner.new();check(owner.enroll(mesh,0),"Actor material enrolls privately")
	var original_wrapper=mesh.material_override
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":source_node(0.4),"properties":{},"children":[],"transparencyHint":false}]}
	var pose:=Pose.new();pose.compiled_controls=false;pose.bulk_evaluation=false;pose.native_storage=false;pose.direct_flush=direct
	pose.configure(metadata,{"parts":[0]},[part])
	if native:
		# A separately staged existing-library gate may enable this without a
		# rebuild. The ordinary headless fixture never claims this route ran.
		var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
		var configured: Dictionary=context.call("dispatch",0,{"parts":pose.parts,"binding":[0],"root":0,"emitter_fields":{}})
		check(not configured.has("error"),"Actual existing native storage configures alpha wrapper")
		pose.native_context=context;actual_native_storage_cases+=1
	var actual=mesh.material_override
	check(actual!=original_wrapper and actual!=base and actual.actor_alpha_context==original_wrapper.actor_alpha_context,"NativePose duplicate(false) retains this actor's context without retaining pooled material")
	check(close_enough(actual.albedo_color.a,0.4),"Initial static Part alpha survives private publication")
	check(owner.set_alpha(0.5) and close_enough(actual.albedo_color.a,0.2),"Sparse actor alpha composes with current Part alpha")
	pose.write(pose.parts[0],168,[0.8]);pose.flush()
	check(close_enough(actual.actor_part_color.a,0.8) and close_enough(actual.albedo_color.a,0.4),"Later GD/native Part publication preserves actor factor")
	check(actual.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mesh.visible,"Partial product belongs to blended draw pass")
	check(owner.set_alpha(0.0) and not mesh.visible and mesh.get_meta("native_pick_geometry")==hit and mesh.mesh!=null,"Zero opacity suppresses draw without freeing hit/mesh data")
	check(owner.set_alpha(1.0) and mesh.visible and close_enough(actual.albedo_color.a,0.8),"Restoring global alpha uses current authored alpha")
	check(close_enough(base.albedo_color.a,0.4) and close_enough(base.albedo_color.r,0.2),"Pooled source material is never mutated")
	owner.close();pose.close();part.free()
func material_cases(enhanced: bool) -> void:
	var base:=source_material(enhanced);var first:=mesh_with(base);var second:=mesh_with(base)
	var one:=Owner.new();var two:=Owner.new();one.enroll(first,0);two.enroll(second,0)
	var material=first.material_override
	check(one.set_alpha(0.5) and close_enough(material.albedo_color.a,0.5) and second.material_override.albedo_color.a==1 and base.albedo_color.a==1,"Two actors sharing a pool input remain isolated")
	material.publish_native_pose(Color(0.7,0.2,0.1,0.25),Color(0.1,0.2,0.3),true)
	check(close_enough(material.albedo_color.a,0.125) and close_enough(material.albedo_color.r,0.7) and material.emission_enabled,"Native publication signature retains RGB/emission and multiplies raw Part alpha once")
	material.publish_actor_part_pose(Color(0.7,0.2,0.1,0.75),Color.BLACK,false)
	check(close_enough(material.albedo_color.a,0.375) and not material.emission_enabled,"GD publication signature replaces Part alpha instead of accumulating the factor")
	var clone=material.duplicate(false)
	check(clone.actor_alpha_context==material.actor_alpha_context and clone.actor_alpha_endpoint==material.actor_alpha_endpoint,"Engine material duplication shares only model context/weak endpoint")
	first.material_override=clone;clone.refresh_actor_alpha();one.set_alpha(0)
	material.publish_actor_part_pose(Color.WHITE,Color.BLACK,false)
	check(not first.visible,"Unbound old material cannot resurrect replacement material's hidden draw")
	clone.publish_actor_part_pose(Color(1,1,1,0),Color.BLACK,false);one.set_alpha(0.8)
	check(not first.visible and clone.albedo_color.a==0,"Authored alpha zero remains invisible under nonzero actor factor")
	clone.publish_actor_part_pose(Color(1,1,1,0.8),Color.BLACK,false)
	check(first.visible and close_enough(clone.albedo_color.a,0.64),"Animated Part alpha can reveal previously zero-alpha draw without losing factor")
	clone.publish_actor_part_pose(Color(0.2,0.4,0.6,0.8),Color(0.1,0.2,0.3),false)
	var emission: Color=clone.emission
	check(one.set_vector(3,[0.5,0.25,0.75]) and close_enough(clone.albedo_color.r,0.1) and close_enough(clone.albedo_color.g,0.1) and close_enough(clone.albedo_color.b,0.45) and clone.actor_part_emission==emission and additive_emission_matches(clone,Vector3(0.5,0.25,0.75)),"Actor vector multiplies diffuse and adds selfillum while retaining original Part emission")
	one.set_vector(1,[0.25,0.5,0.25]);check(close_enough(clone.albedo_color.r,0.05) and close_enough(clone.albedo_color.g,0.2),"First active vector slot wins independently of insertion order")
	one.set_vector(1,null);check(close_enough(clone.albedo_color.r,0.1),"Clearing earlier vector reveals the still-active channel3")
	one.set_vector(0,Vector3.ZERO);check(clone.albedo_color.r==0 and clone.albedo_color.g==0 and first.visible,"Active zero vector is black diffuse rather than an invented hidden state")
	one.set_vector(0,null);one.set_vector(3,null);check(close_enough(clone.albedo_color.r,0.2) and close_enough(clone.albedo_color.g,0.4) and clone.emission==emission,"No active vector restores white multiplier and preserves current emission")
	check(not one.set_vector(-1,[1,1,1]) and not one.set_vector(5,[1,1,1]) and not one.set_vector(3,[NAN,1,1]) and not one.set_vector(3,[1,1]),"Invalid/unavailable vector channels cannot overwrite valid presentation state")
	var original_geometry=first.mesh;var original_hit=first.get_meta("native_pick_geometry")
	check(one.set_presentation_draw_enabled(false) and not first.visible and first.mesh==original_geometry and first.get_meta("native_pick_geometry")==original_hit,"Presentation draw gate leaves received identity and geometry/hit resources in place")
	check(one.set_presentation_draw_enabled(true) and first.visible,"Presentation draw gate restores the current nonzero Part product")
	for flags in [[false,false],[true,false],[false,true],[true,true]]:
		one.set_alpha(0.5,[0],flags[0],flags[1])
		var expected:=Publication.compose(0.8,0.5,int(flags[0])+int(flags[1]))
		check(close_enough(clone.albedo_color.a,expected),"Separate native Gob18/colour-shift flags preserve multiplication boundaries")
	one.set_alpha(2.0);clone.publish_actor_part_pose(Color(1,1,1,0.5),Color.BLACK,false)
	check(clone.albedo_color.a==1 and clone.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Independent Part opacity gate stays blended when product equals one")
	check(not one.set_alpha(NAN) and not one.set_alpha(INF) and not one.set_alpha(0.5,[999]),"Unavailable invalid inputs cannot mutate this actor state")
	var snapshot:=one.snapshot();snapshot.models[0].alpha=99
	check(one.snapshot().models[0].alpha==2.0,"Cold diagnostic snapshots are detached")
	one.set_alpha(0.5)
	var callbacks: Array=[]
	var callback:=func():
		if callbacks.is_empty():callbacks.append(true);one.set_alpha(0.25)
	first.visibility_changed.connect(callback);one.set_alpha(0.0);first.visibility_changed.disconnect(callback)
	check(callbacks.size()==1 and first.visible and close_enough(clone.albedo_color.a,0.125),"Synchronous draw-visibility callback observes and retains the newest alpha publication")
	var orphan:=mesh_with(base);one.enroll(orphan,1);orphan.free()
	check(one.set_alpha(0.5,[1]),"Freed mesh full-ID endpoint does not affect another instance")
	var held:=mesh_with(base);one.enroll(held,2);one.set_alpha(0.25,[0])
	check(held.material_override.albedo_color.a==1,"Unselected held-model alpha does not receive invented propagation")
	one.set_alpha(0.4,[2]);check(close_enough(held.material_override.albedo_color.a,0.4),"Explicit selected child-model propagation is supported")
	one.close();var old: Color=clone.albedo_color;clone.publish_native_pose(Color.WHITE,Color.BLACK,false)
	check(clone.albedo_color==old and not one.set_alpha(1),"Retirement closes context/endpoints before later retained publication")
	two.close();first.free();second.free();held.free()
func vector_before_pose(enhanced: bool,native: bool=false) -> void:
	var base:=source_material(enhanced);var part:=Node3D.new();root.add_child(part)
	var mesh:=mesh_with(base);mesh.reparent(part,false);var owner:=Owner.new();owner.enroll(mesh,0)
	owner.set_alpha(0.5);owner.set_vector(3,[0.5,0.25,0.75])
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":source_node(1.0),"properties":{},"children":[],"transparencyHint":false}]}
	var pose:=Pose.new();pose.compiled_controls=false;pose.bulk_evaluation=false;pose.native_storage=false;pose.direct_flush=true;pose.configure(metadata,{"parts":[0]},[part])
	if native:
		var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
		var configured: Dictionary=context.call("dispatch",0,{"parts":pose.parts,"binding":[0],"root":0,"emitter_fields":{}})
		check(not configured.has("error"),"Native lazy owner captures uncomposed actor material inputs")
		pose.native_context=context;actual_native_storage_cases+=1;pose.flush()
	var actual=mesh.material_override
	check(close_enough(actual.albedo_color.r,0.1) and close_enough(actual.albedo_color.g,0.1) and close_enough(actual.albedo_color.b,0.45) and close_enough(actual.albedo_color.a,0.5),"Lazy Part owner does not multiply preexisting actor alpha/vector twice")
	owner.set_alpha(1.0);owner.set_vector(3,null);pose.flush()
	check(close_enough(actual.albedo_color.r,0.2) and actual.albedo_color.a==1 and actual.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Temporary pre-owner fade does not become a permanent blended hint")
	owner.close();pose.close();part.free()
func plain_callback_case(enhanced: bool) -> void:
	var mesh:=mesh_with(source_material(enhanced));var owner:=Owner.new();owner.enroll(mesh,0);var material=mesh.material_override
	var callbacks: Array=[]
	var callback:=func():
		if callbacks.is_empty():
			callbacks.append(true);owner.set_alpha(0.5);material.publish_native_pose(Color(0.2,0.4,0.6,0.8),Color.BLACK,false)
	mesh.visibility_changed.connect(callback);material.publish_native_pose(Color(0.2,0.4,0.6,0),Color.BLACK,false);mesh.visibility_changed.disconnect(callback)
	check(callbacks.size()==1 and mesh.visible and close_enough(material.albedo_color.a,0.4),"Plain-path callback can replace actor and raw Part state without a stale final write")
	owner.set_alpha(1.0);material.publish_native_pose(Color.WHITE,Color.BLACK,false)
	var closed_callbacks: Array=[]
	var retire:=func():
		if closed_callbacks.is_empty():closed_callbacks.append(true);owner.close()
	mesh.visibility_changed.connect(retire);material.publish_native_pose(Color(1,1,1,0),Color.BLACK,false);mesh.visibility_changed.disconnect(retire)
	check(closed_callbacks.size()==1 and owner.closed and not mesh.visible and not owner.set_alpha(1),"Plain publication can retire its context synchronously without later resurrection")
	mesh.free()
func run() -> void:
	if OS.get_cmdline_user_args().has("--existing-kernel"):
		retained_extension=load("res://native/particle_kernel.gdextension")
		check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Approved existing native storage library actually loads")
	var ordinary_actor:=Actor.new();root.add_child(ordinary_actor)
	check(not ordinary_actor.actor_alpha_enabled and ordinary_actor.actor_alpha==null,"Actual ActorInstance integration defaults to the unchanged ordinary route")
	check(not ordinary_actor.set_renderer_alpha(0.5),"Unenrolled ActorInstance cannot silently activate renderer alpha")
	ordinary_actor.retire();await process_frame
	var empty_model:=Owner.new();check(empty_model.begin_model(0) and empty_model.set_alpha(0.5) and empty_model.set_vector(3,[0.5,0.5,0.5]),"Nondrawing primary Gob retains valid renderer alpha/vector state without fabricating a mesh");empty_model.close()
	check(Owner.primary_model_indices([{}, {"partIndex":0}, {"partIndex":17}, {"partIndex":18}, {"nativeVisualScope":254}, {"equipmentSlot":16,"attachment":"pq"}, {"nativeVisualScope":243}, {"nativeVisualScope":252}, {"nativeVisualScope":253}, {"equipmentSlot":32}, {"equipmentSlot":0,"anchor":"head_g","attachment":"pq"}, {"anchor":"head_g"}])==[0,1,2,3,4,5,6,7,8,9,10],"Only proven primary Append/robe and explicit head/cloak/wing/tail/Wield/helmet roles join scope255 models")
	check(Owner.primary_model_indices([]).is_empty() and Owner.primary_model_indices([{}, {"partIndex":19}, {"partIndex":-1}, {"partIndex":"0"}, {"nativeVisualScope":251,"follow":true}, {"anchor":"head_g","equipmentSlot":0}, {"reference":true,"follow":true}])==[0],"Unknown/follow/invalid model metadata cannot invent propagation membership")
	for enhanced in [false,true]:
		material_cases(enhanced)
		plain_callback_case(enhanced)
		for direct in [false,true]:pose_case(enhanced,direct)
		vector_before_pose(enhanced)
	# Actual extension dispatch is separate and optional, never inferred from
	# calling its method signature directly on a script material.
	if ClassDB.class_exists("NwnModelPoseStorage"):
		for enhanced in [false,true]:pose_case(enhanced,true,true);vector_before_pose(enhanced,true)
	if OS.get_cmdline_user_args().has("--existing-kernel"):check(actual_native_storage_cases==4,"Both Standard and Enhanced actual native storage/lazy-input routes execute")
	print("NATIVE_PARITY_ACTOR_ALPHA_NATIVE_STORAGE ",actual_native_storage_cases)
	print("NATIVE_PARITY_ACTOR_ALPHA ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
