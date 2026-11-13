extends SceneTree
var output:=""
var variant:=""
var steps: Array=[]
var failures: Array=[]
var checks:=0
var viewport: SubViewport
var world: Node3D
var skeleton: Skeleton3D
var second_skeleton: Skeleton3D
var skinned: MeshInstance3D
var rigid: MeshInstance3D
var colored: OmniLight3D
var decal: Decal
var reflection: ReflectionProbe
var mesh_source: ArrayMesh
var normal_skin: Skin
var capture_rid:=RID()
var capture_instance:=RID()
var capture_marker: Node3D
var scenario:=RID()
var frame_metrics: Array=[]
var last_probe_id:=-1
const BOUNDS=AABB(Vector3(-4,-1,-3),Vector3(8,7,6))
func _initialize()->void:call_deferred("run")
func check(okay: bool,label: String)->void:
	checks+=1
	if not okay:failures.append(label);print("FAIL ",label)
func make_mesh()->ArrayMesh:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array();var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
	var faces:=[
		[Vector3(-.6,0,.4),Vector3(.6,0,.4),Vector3(.6,3,.4),Vector3(-.6,3,.4),Vector3.BACK],
		[Vector3(.6,0,-.4),Vector3(-.6,0,-.4),Vector3(-.6,3,-.4),Vector3(.6,3,-.4),Vector3.FORWARD],
		[Vector3(.6,0,.4),Vector3(.6,0,-.4),Vector3(.6,3,-.4),Vector3(.6,3,.4),Vector3.RIGHT],
		[Vector3(-.6,0,-.4),Vector3(-.6,0,.4),Vector3(-.6,3,.4),Vector3(-.6,3,-.4),Vector3.LEFT],
		[Vector3(-.6,3,.4),Vector3(.6,3,.4),Vector3(.6,3,-.4),Vector3(-.6,3,-.4),Vector3.UP],
		[Vector3(-.6,0,-.4),Vector3(.6,0,-.4),Vector3(.6,0,.4),Vector3(-.6,0,.4),Vector3.DOWN]]
	for face in faces:
		var start:=vertices.size()
		for index in 4:
			var p: Vector3=face[index];vertices.append(p);normals.append(face[4])
			bones.append_array(PackedInt32Array([1 if p.y>1.5 else 0,0,0,0]));weights.append_array(PackedFloat32Array([1,0,0,0]))
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func make_skeleton(label: String)->Skeleton3D:
	var value:=Skeleton3D.new();value.name=label;world.add_child(value)
	value.add_bone("lower");value.add_bone("upper");value.set_bone_parent(1,0)
	value.set_bone_rest(0,Transform3D.IDENTITY);value.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,1.5,0)))
	value.set_bone_pose_position(1,Vector3(0,1.5,0));return value
func build()->void:
	viewport=SubViewport.new();viewport.name="FixtureViewport";viewport.size=Vector2i(480,360);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.positional_shadow_atlas_size=1024;root.add_child(viewport)
	world=Node3D.new();world.name="FixtureWorld";viewport.add_child(world);scenario=world.get_world_3d().scenario
	var env_node:=WorldEnvironment.new();env_node.name="Environment";var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.035,.035,.035);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.05;env_node.environment=env;world.add_child(env_node)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.7,.68,.65);material.roughness=.8;material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(18,18)
	var floor_node:=MeshInstance3D.new();floor_node.name="Receiver";floor_node.mesh=floor_mesh;floor_node.material_override=material;world.add_child(floor_node)
	skeleton=make_skeleton("SkeletonA");second_skeleton=make_skeleton("SkeletonB")
	mesh_source=make_mesh();normal_skin=Skin.new();normal_skin.add_bind(0,Transform3D.IDENTITY);normal_skin.add_bind(1,Transform3D(Basis.IDENTITY,Vector3(0,-1.5,0)))
	skinned=MeshInstance3D.new();skinned.name="DeformingBox";skinned.mesh=mesh_source;skinned.skin=normal_skin;skinned.material_override=material;skinned.custom_aabb=BOUNDS;world.add_child(skinned);skinned.skeleton=skinned.get_path_to(skeleton)
	rigid=MeshInstance3D.new();rigid.name="RigidControl";var box:=BoxMesh.new();box.size=Vector3(1,2,1);rigid.mesh=box;rigid.material_override=material;rigid.position=Vector3(-3,1,0);world.add_child(rigid)
	var key:=DirectionalLight3D.new();key.name="ShadowKey";key.light_energy=.85;key.shadow_enabled=true;key.directional_shadow_max_distance=40;key.rotation_degrees=Vector3(-55,-30,0);world.add_child(key)
	colored=OmniLight3D.new();colored.name="ColoredVolume";colored.light_color=Color(.1,.8,.2);colored.light_energy=2;colored.omni_range=3;colored.position=Vector3(2,2,0);world.add_child(colored)
	decal=Decal.new();decal.name="DecalVolume";decal.size=Vector3(4,5,4);decal.position=Vector3(0,1.5,0);var stamp:=Image.create(1,1,false,Image.FORMAT_RGBA8);stamp.fill(Color(.2,.3,.7,.5));decal.texture_albedo=ImageTexture.create_from_image(stamp);decal.visible=false;world.add_child(decal)
	reflection=ReflectionProbe.new();reflection.name="ReflectionVolume";reflection.size=Vector3(8,6,8);reflection.position=Vector3(0,2,0);reflection.visible=false;world.add_child(reflection)
	var camera:=Camera3D.new();camera.name="Camera";world.add_child(camera);camera.position=Vector3(10,10,14);camera.look_at(Vector3(0,1,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13;camera.current=true
	capture_marker=Node3D.new();capture_marker.name="CaptureVolume";world.add_child(capture_marker)
func pose(angle: float)->void:
	skeleton.set_bone_pose_position(1,Vector3(0,1.5,0));skeleton.set_bone_pose_rotation(1,Quaternion(Vector3.FORWARD,angle));skeleton.set_bone_pose_scale(1,Vector3.ONE);skeleton.force_update_all_bone_transforms()
func observe_probe()->void:
	var probe: Dictionary=ClassDB.class_call_static("NwnFrameProbe","completed_frame")
	if bool(probe.get("available",false)) and int(probe.frame_id)!=last_probe_id:last_probe_id=int(probe.frame_id);frame_metrics.append(probe)
func settle(angle: float=.55,changing: bool=true,count: int=6)->void:
	for index in count:
		pose(angle if not changing or index%2==(count-1)%2 else -.2)
		await process_frame;await RenderingServer.frame_post_draw;observe_probe()
func names(ids: PackedInt64Array)->Array:
	var result: Array=[]
	for id in ids:
		var object=instance_from_id(int(id))
		if object is Node:result.append(str(object.name))
		else:failures.append("Unknown cull result object "+str(id));result.append("UNKNOWN")
	result.sort();return result
func queries()->Dictionary:
	var result:={"all":names(RenderingServer.instances_cull_aabb(AABB(Vector3(-10,-2,-10),Vector3(20,14,20)),scenario)),"center":names(RenderingServer.instances_cull_aabb(AABB(Vector3(-1,0,-1),Vector3(2,4,2)),scenario)),"ray":names(RenderingServer.instances_cull_ray(Vector3(0,2,10),Vector3(0,2,-10),scenario))}
	var bound: AABB=skinned.global_transform*skinned.custom_aabb
	for offset in [.001,.01,.05]:result["edge_"+str(offset)]=names(RenderingServer.instances_cull_aabb(AABB(Vector3(bound.end.x+offset,bound.position.y,bound.position.z),Vector3(.001,bound.size.y,bound.size.z)),scenario))
	return result
func take(case_id: String,label: String,angle: float=.55,changing: bool=true)->void:
	frame_metrics=[];await settle(angle,changing)
	var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);var png:=case_id+"--"+label+".png";check(image.save_png(output.get_base_dir()+"/"+png)==OK,"Save "+png)
	var bound:=not skinned.skeleton.is_empty() and skinned.get_node_or_null(skinned.skeleton) is Skeleton3D
	var baked:=skinned.bake_mesh_from_current_skeleton_pose() if bound else skinned.mesh;var vertices: Array=[]
	for surface in baked.get_surface_count():
		var positions: PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for p in positions:vertices.append([p.x,p.y,p.z])
	var sample: Variant=null
	if ClassDB.class_has_method("NwnFrameProbe","dirty_instance_sample"):sample=ClassDB.class_call_static("NwnFrameProbe","dirty_instance_sample")
	steps.append({"case":case_id,"label":label,"png":png,"queries":queries(),"baked_vertices":vertices,"metrics":frame_metrics.duplicate(true),"dirty_sample":sample,"visible":skinned.visible,"layers":skinned.layers,"cast_shadow":skinned.cast_shadow,"custom_aabb":[skinned.custom_aabb.position,skinned.custom_aabb.size],"transform":str(skinned.transform),"skeleton":str(skinned.skeleton),"motion_vectors":viewport.use_taa})
func add_capture()->void:
	capture_rid=RenderingServer.lightmap_create();RenderingServer.lightmap_set_probe_bounds(capture_rid,AABB(Vector3(-5,-2,-5),Vector3(10,8,10)));RenderingServer.lightmap_set_probe_capture_data(capture_rid,PackedVector3Array(),PackedColorArray(),PackedInt32Array(),PackedInt32Array());capture_instance=RenderingServer.instance_create();RenderingServer.instance_set_base(capture_instance,capture_rid);RenderingServer.instance_attach_object_instance_id(capture_instance,capture_marker.get_instance_id());RenderingServer.instance_set_scenario(capture_instance,scenario)
func free_capture()->void:
	if capture_instance.is_valid():RenderingServer.free_rid(capture_instance);capture_instance=RID()
	if capture_rid.is_valid():RenderingServer.free_rid(capture_rid);capture_rid=RID()
func run()->void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture-variant="):variant=arg.trim_prefix("--fixture-variant=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(ClassDB.class_exists("NwnFrameProbe"),"Current private frame probe exists")
	if not ClassDB.class_exists("NwnFrameProbe"):quit(2);return
	ClassDB.class_call_static("NwnFrameProbe","set_enabled",true);build();await settle(0,false,10)
	await take("stable_bounds_deforming_shadow","pose_a",0)
	await take("stable_bounds_deforming_shadow","pose_b",.75)
	await take("stable_bounds_deforming_shadow","unchanged_republications",.75,false)
	skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await take("stable_bounds_deforming_shadow","shadow_only_pose_a",0)
	await take("stable_bounds_deforming_shadow","shadow_only_pose_b",.75)
	skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;await take("stable_bounds_deforming_shadow","negative_no_deforming_shadow",.75)
	skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for order in ["light_then_bone","bone_then_light"]:
		for near in [false,true,false]:
			if order=="bone_then_light":pose(.55)
			colored.position=Vector3(2,2,0) if near else Vector3(30,2,0)
			if order=="light_then_bone":pose(.55)
			await take("light_moves_both_drain_orders",order+"_"+str(steps.size()))
	for near in [true,false]:
		var added:=OmniLight3D.new();added.name="TemporaryLight";added.light_color=Color(.7,.1,.1);added.light_energy=2;added.omni_range=3;added.position=Vector3(-2,2,0) if near else Vector3(30,2,0);world.add_child(added)
		await take("new_and_removed_lights","added_"+str(near));added.free();await take("new_and_removed_lights","removed_"+str(near))
	colored.position=Vector3(2,2,0);decal.visible=true;reflection.visible=not OS.get_cmdline_user_args().has("--fixture-no-reflection")
	for order in ["ordinary_then_bone","bone_then_ordinary"]:
		if order=="bone_then_ordinary":pose(.55)
		skinned.layers=2;colored.light_cull_mask=1;decal.cull_mask=2;reflection.cull_mask=2;RenderingServer.instance_geometry_set_flag(skinned.get_instance(),RenderingServer.INSTANCE_FLAG_USE_DYNAMIC_GI,true)
		if order=="ordinary_then_bone":pose(.55)
		await take("layer_and_cull_mask",order+"_disjoint")
		colored.light_cull_mask=2;await take("layer_and_cull_mask",order+"_matching")
	skinned.layers=1;colored.light_cull_mask=1;decal.visible=false;reflection.visible=false
	skinned.hide();await take("visibility_and_scenario_reinsert","hidden");skinned.show();await take("visibility_and_scenario_reinsert","shown")
	skinned.hide();pose(.55);skinned.show();await take("visibility_and_scenario_reinsert","hide_show_same_frame")
	RenderingServer.instance_set_scenario(skinned.get_instance(),RID());await take("visibility_and_scenario_reinsert","no_scenario");RenderingServer.instance_set_scenario(skinned.get_instance(),scenario);await take("visibility_and_scenario_reinsert","scenario_reinserted")
	skinned.skeleton=NodePath();await take("skeleton_bind_and_topology","detached");skinned.skeleton=skinned.get_path_to(skeleton);await take("skeleton_bind_and_topology","same_rebound")
	skinned.skeleton=skinned.get_path_to(second_skeleton);second_skeleton.set_bone_pose_rotation(1,Quaternion(Vector3.FORWARD,.4));await take("skeleton_bind_and_topology","different_skeleton")
	second_skeleton.add_bone("extra");second_skeleton.set_bone_parent(2,0);await take("skeleton_bind_and_topology","topology_changed");skinned.skeleton=skinned.get_path_to(skeleton)
	skinned.custom_aabb=BOUNDS.grow(.5);await take("changed_bound_and_extra_margin","larger_custom");skinned.custom_aabb=BOUNDS;skinned.extra_cull_margin=.2;await take("changed_bound_and_extra_margin","margin");skinned.extra_cull_margin=0
	var ulp:=PackedByteArray();ulp.resize(4);ulp.encode_float(0,BOUNDS.size.x);ulp.encode_u32(0,ulp.decode_u32(0)+1);skinned.custom_aabb=AABB(BOUNDS.position,Vector3(ulp.decode_float(0),BOUNDS.size.y,BOUNDS.size.z));await take("changed_bound_and_extra_margin","one_ulp");skinned.custom_aabb=BOUNDS
	skinned.mesh=make_mesh();await take("changed_bound_and_extra_margin","replacement_mesh");skinned.mesh=mesh_source;skinned.position=Vector3(.2,0,0);await take("changed_bound_and_extra_margin","transform");skinned.position=Vector3.ZERO
	# Blendshape topology is changed through a real replacement resource below.
	var blend:=make_mesh();var arrays:=blend.surface_get_arrays(0);var morph: Array=[];morph.resize(Mesh.ARRAY_MAX);var moved: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in moved.size():
		if moved[index].y>1.5:moved[index]+=Vector3(.3,0,0)
	morph[Mesh.ARRAY_VERTEX]=moved;morph[Mesh.ARRAY_NORMAL]=arrays[Mesh.ARRAY_NORMAL]
	blend.clear_surfaces();blend.add_blend_shape("shape");blend.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[morph]);skinned.mesh=blend;skinned.set_blend_shape_value(0,.4);await take("changed_bound_and_extra_margin","blendshape");skinned.mesh=mesh_source
	skinned.position=Vector3(.05,0,0);await take("quantized_bvh_quiet_followup","moved");await take("quantized_bvh_quiet_followup","quiet_bone");skinned.position=Vector3.ZERO
	add_capture();pose(.55);await take("lightmap_capture_requeue","created_empty_safe_capture");RenderingServer.instance_set_transform(capture_instance,Transform3D(Basis.IDENTITY,Vector3(20,0,0)));pose(.55);await take("lightmap_capture_requeue","moved_disjoint");RenderingServer.instance_set_transform(capture_instance,Transform3D.IDENTITY);pose(.55);await take("lightmap_capture_requeue","moved_intersecting");free_capture();await take("lightmap_capture_requeue","removed")
	viewport.use_taa=not OS.get_cmdline_user_args().has("--fixture-no-taa");await take("teleport_and_motion_vectors","taa_before");pose(.55);RenderingServer.instance_teleport(skinned.get_instance());await take("teleport_and_motion_vectors","teleport_same_bounds");skinned.position=Vector3(.5,0,0);RenderingServer.instance_teleport(skinned.get_instance());await take("teleport_and_motion_vectors","teleport_moved");viewport.use_taa=false
	steps.append({"case":"signed_zero_and_nonfinite_predicate","label":"source_predicate_witness_only","scope":"Runner requires pinned original-agent source/queue/predicate audit; no nonfinite geometry is submitted to a GPU."})
	free_capture();viewport.free()
	for frame in 4:await process_frame;await RenderingServer.frame_post_draw
	RenderingServer.force_sync()
	ClassDB.class_call_static("NwnFrameProbe","set_enabled",false)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"variant":variant,"checks":checks,"failures":failures,"steps":steps,"gpu":true,"fpsClaim":false,"scope":"Deterministic weighted deformation/shadow/volume-membership and public coarse cull fixture; cross-variant equivalence and predicate witness are evaluated by runner."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
