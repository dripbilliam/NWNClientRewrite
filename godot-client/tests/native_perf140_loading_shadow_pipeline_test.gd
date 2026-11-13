extends SceneTree
# Test-only readback of meshes constructed by this owned fixture. Production
# shadow preparation remains entirely on its retained CPU geometry path.
const Proxy=preload("res://systems/native_render/static_shadow_proxy.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Prepared=preload("res://systems/native_data/mesh_preparation.gd")
const Digest=preload("res://systems/native_data/prepared_cache.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var cases: Array=[]
var largest_position_error:=0.0
var largest_normal_error:=0.0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	call_deferred("run")
func quat(axis: Vector3,angle: float) -> Array:
	var value:=Quaternion(axis,angle);return [value.x,value.y,value.z,value.w]
func bundle(prepared: bool) -> Dictionary:
	var text:="newmodel real_shadow_fixture\nbeginmodelgeom real_shadow_fixture\nnode trimesh source\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom real_shadow_fixture\n"
	var parser:=ActorData.new();var value: Dictionary=parser.parse(text.to_utf8_buffer())
	check(parser.failure.is_empty(),"Real authored model fixture parses")
	var original: Dictionary=value.nodes[0].duplicate(true);var rows: Array=[]
	for index in 5:
		var row: Dictionary=original.duplicate(true);row.name="fixture_part_"+str(index);row.parent=-1 if index==0 else (1 if index==2 else 0)
		row.position=[0.0,0.0,0.0];row.orientation=[0.0,0.0,0.0,1.0];row.scale=1.0;row.alpha=1.0;row.features=[]
		if index<2:row.mesh={}
		else:
			var source_normal:=Vector3(1,2,3).normalized()
			row.mesh.vertices=PackedFloat32Array([0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,0.25,0.0,1.0,0.0]);row.mesh.indices=PackedInt32Array([0,1,2,0,2,3]);row.mesh.normals=PackedFloat32Array()
			for vertex in 4:row.mesh.normals.append_array(PackedFloat32Array([source_normal.x,source_normal.y,source_normal.z]))
			row.mesh.uv=[];row.mesh.textures=[];row.mesh.shadow=true;row.mesh.render=index!=4;row.mesh.transparency_hint=false
			row.mesh.vertex_colors=PackedByteArray();row.mesh.erase("native_upload");row.mesh.erase("native_planes");row.mesh.erase("collision_indices")
		rows.append(row)
	rows[0].position=[2.0,3.0,1.0];rows[0].orientation=quat(Vector3.BACK,PI/2)
	rows[1].position=[0.5,1.25,0.0];rows[1].orientation=quat(Vector3.RIGHT,PI/2)
	rows[2].position=[0.25,0.5,0.75];rows[2].scale=1.25
	rows[3].position=[-0.5,1.0,0.25];rows[3].orientation=quat(Vector3.UP,PI/2);rows[3].scale=0.75
	rows[4].position=[0.0,0.0,-1.0]
	value.nodes=rows;value.name="real_shadow_fixture"
	if prepared:
		var result:=Prepared.model(value);check(str(result.error).is_empty(),"Real worker mesh preparation succeeds")
	return {"value":value,"resource_name":"real_shadow_fixture","sha256":Digest.digest(var_to_bytes(value)),"textures":{},"emitter_textures":{},"error":"","animation_sources":[]}
func expected_pose(part: int) -> Transform3D:
	# Independent fixture transforms in Godot's Y-up coordinates. These match the
	# authored quarter turns/positions, rather than calling Proxy.relative_pose.
	var base:=Transform3D(Basis(Vector3.UP,PI/2),Vector3(2,1,-3))
	if part==2:return base*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0.5,0,-1.25))*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.25),Vector3(0.25,0.75,-0.5))
	return base*Transform3D(Basis(Vector3.FORWARD,PI/2).scaled(Vector3.ONE*0.75),Vector3(-0.5,0.25,-1))
func id(value) -> int:return value.get_instance_id() if value!=null else 0
func original_view(model) -> PackedByteArray:
	var parts: Array=[];var meshes: Array=[];var picks: Array=[]
	for part in model.parts:parts.append([id(part),id(part.get_parent()),part.name,part.transform,part.get_meta("native_part_index"),part.get_meta("native_part_parent"),part.get_meta("native_part_name")])
	for geometry in model.meshes:
		var hit=geometry.mesh.get_meta("native_pick_geometry",null)
		meshes.append([id(geometry),id(geometry.get_parent()),id(geometry.mesh),id(geometry.material_override),geometry.transform,geometry.visible,id(hit),hit.vertices,hit.indices,id(geometry.get_meta("native_pick_shape",null)),geometry.mesh.surface_get_arrays(0)])
	for part in model.pick_surfaces:
		var hit=part.get_meta("native_pick_geometry");picks.append([id(part),id(hit),hit.vertices,hit.indices])
	return var_to_bytes([parts,meshes,picks,model.get_meta("native_scene_bounds",null)])
func source_flags(model) -> Array:return model.meshes.map(func(geometry):return geometry.cast_shadow)
func layout_matches(model,compact: bool) -> bool:
	for geometry in model.meshes:
		if compact:
			if not geometry.has_meta("native_part_index") or geometry!=model.parts[int(geometry.get_meta("native_part_index"))]:return false
		else:
			if geometry.has_meta("native_part_index") or not geometry.get_parent().has_meta("native_part_index") or geometry.get_parent()!=model.parts[int(geometry.get_parent().get_meta("native_part_index"))]:return false
	return true
func context(compact: bool,native: bool,prepared: bool) -> Dictionary:
	var pool:=Pool.new();pool.compact_static_parts=compact;pool.native_lighting=native;pool.native_standard=native;pool.native_surface_output=native;pool.use_prepared_geometry=prepared;pool.picking=true
	var source:=bundle(prepared);var template:=Template.new();check(template.build(source,pool),"Real ModelInstance and template build")
	var a=template.create();var b=template.create();check(a!=null and b!=null,"Real independent template placements clone")
	var host:=Node3D.new();root.add_child(host);host.position=Vector3(8,2,-4);host.rotation.y=0.25
	for model in [a,b]:host.add_child(model)
	a.position=Vector3(10,0,-20);a.rotation.y=PI/2;a.set_meta("native_tile_index",10)
	b.position=Vector3(-20,1,-10);b.rotation.y=PI;b.set_meta("native_tile_index",11)
	return {"pool":pool,"source":source,"template":template,"a":a,"b":b,"host":host,"material":StandardMaterial3D.new()}
func inspect_stream(plan: Dictionary) -> void:
	check(plan.groups.size()==1 and plan.members.size()==2,"Two real opaque surfaces form one proxy group")
	if plan.groups.size()!=1:return
	var arrays: Array=plan.groups[0].mesh.surface_get_arrays(0);var actual_positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var actual_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var actual_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var points:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3(1,0.25,-1),Vector3(0,0,-1)])
	var expected_positions:=PackedVector3Array();var expected_normals:=PackedVector3Array();var expected_indices:=PackedInt32Array()
	for member in plan.members:
		var transform:=expected_pose(int(member.part));var normal: Vector3=(transform.basis.inverse().transposed()*Vector3(1,3,-2)).normalized();var base:=expected_positions.size()
		for point in points:expected_positions.append(transform*point);expected_normals.append(normal)
		for index in [0,2,1,0,3,2]:expected_indices.append(base+index)
	check(actual_positions.size()==8 and actual_normals.size()==8,"Baked real proxy retains every fixture vertex and normal")
	check(actual_indices==expected_indices,"Baked indices retain the original winding and per-member offsets exactly")
	if actual_positions.size()==expected_positions.size():
		for index in actual_positions.size():
			var error:=actual_positions[index].distance_to(expected_positions[index]);largest_position_error=maxf(largest_position_error,error)
			check(error<=0.00002,"Baked nested rotated Part positions match independently specified authored placement")
	if actual_normals.size()==expected_normals.size():
		for index in actual_normals.size():
			var error:=actual_normals[index].distance_to(expected_normals[index]);largest_normal_error=maxf(largest_normal_error,error)
			check(error<=0.0001,"Baked normals match inverse-transpose orientation within ArrayMesh octahedral upload precision")
func pipeline_case(compact: bool,native: bool,prepared: bool) -> void:
	var value:=context(compact,native,prepared);var a=value.a;var b=value.b
	check(a.parts.size()==5 and a.meshes.size()==2 and a.pick_surfaces.size()==1,"Actual template retains dummy, mesh and hidden collision Parts")
	check(layout_matches(a,compact) and layout_matches(b,compact),"Requested compact/separate physical layout is active")
	check(a.parts[2]!=b.parts[2] and a.meshes[0].mesh==b.meshes[0].mesh and a.meshes[0].material_override==b.meshes[0].material_override and a.meshes[0].mesh.get_meta("native_pick_geometry")==b.meshes[0].mesh.get_meta("native_pick_geometry"),"Real clones keep private physical Parts and exact shared immutable render/pick resources")
	check(a.meshes.all(func(geometry):return (geometry.material_override is NativeMaterial)==native),"Requested native/non-native material path is active")
	check(value.source.value.nodes[2].mesh.has("native_upload")==prepared,"Requested prepared/authored normal branch is present")
	var original_a:=original_view(a);var original_b:=original_view(b);var data_before:=var_to_bytes(value.source);var flags:=source_flags(a)
	var plan:=Proxy.prepare(a,value.source,value.material)
	check(original_view(a)==original_a and original_view(b)==original_b and source_flags(a)==flags,"Proxy preparation preserves actual parts, pick resources, mesh arrays, materials and flags")
	check(data_before==var_to_bytes(value.source),"Proxy preparation cannot mutate its authored/prepared bundle")
	inspect_stream(plan)
	var installed:=Proxy.install(b,plan);check(installed.get("installed",false),"A cached plan installs on a second differently placed real clone")
	check(original_view(a)==original_a and original_view(b)==original_b,"Installing a real clone preserves original physical/picking/data resources")
	check(source_flags(a)==flags and b.meshes.all(func(geometry):return geometry.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Only the installed clone's accepted original caster flags change")
	var proxies: Array=b.get_children().filter(func(child):return child is MeshInstance3D and child.has_meta(Proxy.INSTALLED_META))
	check(proxies.size()==1 and not b.meshes.has(proxies[0]),"Real proxy stays outside original picking/render-part enumeration")
	if not proxies.is_empty():
		var proxy: MeshInstance3D=proxies[0];check(proxy.transform==Transform3D.IDENTITY and proxy.get_parent()==b,"Proxy retains the placed model's parent transform and visibility ownership")
		check(proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"Published real proxy is shadow-only")
		var before_children: int=b.get_child_count();check(not Proxy.install(b,plan).get("installed",false) and b.get_child_count()==before_children,"Repeated installation cannot duplicate proxies")
		var observed: WeakRef=weakref(proxy);value.pool.clear();check(is_instance_valid(proxy.mesh),"Pool clear cannot destroy a live proxy resource")
		b.retire();await process_frame;check(observed.get_ref()==null and is_instance_valid(a),"Placement retirement frees its proxy while the other clone survives")
	else:b.free()
	cases.append({"compact":compact,"native_material":native,"prepared_normals":prepared,"accepted":int(plan.get("stats",{}).get("accepted_meshes",0)),"groups":plan.groups.size()})
	a.free();value.host.free();value.pool.clear()
func mutation_case(kind: String) -> void:
	var value:=context(true,true,true);var geometry: MeshInstance3D=value.a.meshes[0];var plan:=Proxy.prepare(value.a,value.source,value.material)
	check(not plan.groups.is_empty(),"Mutation fixture begins with a valid real-pipeline plan: "+kind)
	if kind=="skin":geometry.skin=Skin.new()
	elif kind=="range-begin":geometry.visibility_range_begin=1.0
	elif kind=="range-end":geometry.visibility_range_end=50.0
	elif kind=="margin":geometry.extra_cull_margin=1.0
	elif kind=="authored-render":value.source.value.nodes[2].mesh.render=false
	elif kind=="authored-shadow":value.source.value.nodes[2].mesh.shadow=false
	elif kind=="part-index":value.a.parts[2].set_meta("native_part_index",3)
	elif kind=="part-parent":value.a.parts[2].set_meta("native_part_parent",-1)
	var before:=source_flags(value.a);var children: int=value.a.get_child_count();var result:=Proxy.install(value.a,plan)
	check(not result.get("installed",false),"Changed cached-clone policy rejects atomically: "+kind)
	check(source_flags(value.a)==before and value.a.get_child_count()==children,"Rejected real clone keeps all original flags and has no partial proxy: "+kind)
	value.a.free();value.b.free();value.host.free();value.pool.clear()
func run() -> void:
	for compact in [false,true]:
		for native in [false,true]:
			for prepared in [false,true]:await pipeline_case(compact,native,prepared)
	for kind in ["skin","range-begin","range-end","margin","authored-render","authored-shadow","part-index","part-parent"]:mutation_case(kind)
	await process_frame
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"max_baked_position_error":largest_position_error,"max_baked_normal_error":largest_normal_error,"scope":"Owned real ResourcePool/ModelInstance/Template shadow stream, ownership, clone-policy and retirement fixture. Surface readback is test-only; no visual, GPU-performance, server or frame-rate acceptance."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
