extends RefCounted
# Private experiment: only the immutable ModelInstance path used by terrain.
# The normal meshes, materials, pick/collision resources and lights stay intact.
# Alpha/scissor, skin/deformation, mirrored and unproven surfaces retain their
# original shadow path. This module never reads geometry back from the GPU.
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Prepared=preload("res://systems/native_data/mesh_preparation.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const INSTALLED_META="perf140_static_shadow_proxy"
static func relative_pose(geometry: Node3D,model: Node3D) -> Variant:
	var pose:=geometry.transform
	var parent:=geometry.get_parent()
	while parent!=model:
		if not parent is Node3D:return null
		pose=parent.transform*pose
		parent=parent.get_parent()
	return pose
static func shown(geometry: Node3D,model: Node3D) -> bool:
	var current: Node=geometry
	while current!=model:
		if not current is Node3D or not current.visible:return false
		current=current.get_parent()
	return model.visible
static func opaque(material: Material) -> bool:
	if material==null or material.next_pass!=null:return false
	if material is NativeMaterial:
		return material.get_script()==NativeMaterial and material.shader!=null and NativeMaterial.shaders.values().has(material.shader) and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not material.scissor and material.albedo_color.a==1.0 and material.get_shader_parameter("native_alpha")==1.0
	return material is StandardMaterial3D and material.get_class()=="StandardMaterial3D" and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK and not material.grow and not material.heightmap_enabled and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not material.fixed_size and material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED and not material.proximity_fade_enabled and material.albedo_color.a==1.0
static func finite_pose(pose: Transform3D) -> bool:
	return pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() and is_finite(pose.basis.determinant()) and pose.basis.determinant()>0.0
static func reject(stats: Dictionary,reason: String) -> void:
	stats.rejected[reason]=int(stats.rejected.get(reason,0))+1
static func eligibility(geometry: MeshInstance3D,model: Node3D,rows: Array) -> Dictionary:
	if geometry.mesh==null or geometry.mesh.get_surface_count()!=1 or geometry.mesh.get_blend_shape_count()!=0 or not shown(geometry,model) or geometry.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON:return {"reason":"not-visible-single-sided-caster"}
	if not opaque(geometry.material_override) or geometry.material_overlay!=null or geometry.skin!=null or geometry.transparency!=0.0:return {"reason":"unproven-material-or-skin"}
	if geometry.visibility_range_begin!=0 or geometry.visibility_range_end!=0 or geometry.extra_cull_margin!=0 or geometry.top_level or not geometry.visibility_parent.is_empty():return {"reason":"nondefault-visibility"}
	var part: Node=geometry if geometry.has_meta("native_part_index") else geometry.get_parent()
	var part_index:=int(part.get_meta("native_part_index",-1))
	if part_index<0 or part_index>=rows.size():return {"reason":"missing-authored-part"}
	var row: Dictionary=rows[part_index]
	var features: Array=row.get("features",[])
	if features.any(func(value):return value in ["skin","animated-mesh","dangly"]):return {"reason":"deformed-part"}
	var data: Dictionary=row.get("mesh",{})
	if not data.get("shadow",false) or not data.get("render",false):return {"reason":"authored-noncaster"}
	var pose: Variant=relative_pose(geometry,model)
	if not pose is Transform3D or not finite_pose(pose):return {"reason":"mirrored-singular-or-nonfinite-pose"}
	return {"part":part_index,"parent":part.get_meta("native_part_parent") if part.has_meta("native_part_parent") else null,"data":data,"pose":pose}
static func prepare(model: Node3D,bundle: Dictionary,shadow_material: StandardMaterial3D) -> Dictionary:
	var began:=Time.get_ticks_usec()
	if not model is Template.Placement or model.retired:return {"groups":[],"members":[],"stats":{"rejected":{"unsupported-owner":1}}}
	var stats:={"source_meshes":model.meshes.size(),"accepted_meshes":0,"groups":0,"triangles":0,"vertices":0,"rejected":{}}
	var groups: Dictionary={}
	var rows: Array=bundle.get("value",{}).get("nodes",[])
	for index in model.meshes.size():
		var geometry: MeshInstance3D=model.meshes[index]
		var eligible:=eligibility(geometry,model,rows)
		if eligible.has("reason"):reject(stats,eligible.reason);continue
		var part_index: int=eligible.part
		var data: Dictionary=eligible.data
		var hit=geometry.mesh.get_meta("native_pick_geometry") if geometry.mesh.has_meta("native_pick_geometry") else null
		if hit==null or not hit.vertices is PackedVector3Array or not hit.indices is PackedInt32Array or hit.vertices.is_empty() or hit.indices.is_empty() or hit.indices.size()%3!=0:reject(stats,"missing-retained-geometry");continue
		var pose: Transform3D=eligible.pose
		var normals:=PackedVector3Array()
		var upload: Dictionary=data.get("native_upload",{})
		if upload.get("revision")==Prepared.REVISION and upload.get("normals") is PackedVector3Array and upload.normals.size()==hit.vertices.size():
			normals=upload.normals
		else:
			var original: PackedFloat32Array=data.get("normals",PackedFloat32Array())
			if original.size()!=hit.vertices.size()*3:reject(stats,"missing-authored-normals");continue
			normals.resize(hit.vertices.size())
			for vertex in normals.size():normals[vertex]=Vector3(original[vertex*3],original[vertex*3+2],-original[vertex*3+1])
		var valid:=true
		for vertex in hit.vertices:
			if not vertex.is_finite():valid=false;break
		for normal in normals:
			if not normal.is_finite():valid=false;break
		for vertex in hit.indices:
			if vertex<0 or vertex>=hit.vertices.size():valid=false;break
		if not valid:reject(stats,"invalid-retained-stream");continue
		var normal_basis: Basis=pose.basis.inverse().transposed()
		var baked_positions:=PackedVector3Array();var baked_normals:=PackedVector3Array()
		for vertex in hit.vertices.size():
			var position: Vector3=pose*hit.vertices[vertex]
			var normal: Vector3=(normal_basis*normals[vertex]).normalized()
			if not position.is_finite() or not normal.is_finite():valid=false;break
			baked_positions.append(position);baked_normals.append(normal)
		if not valid:reject(stats,"nonfinite-baked-stream");continue
		var key:=str(geometry.layers)
		if not groups.has(key):groups[key]={"layers":geometry.layers,"positions":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array(),"members":[]}
		var group: Dictionary=groups[key]
		if group.positions.size()+hit.vertices.size()>100000:reject(stats,"bounded-prototype-capacity");continue
		var base: int=group.positions.size()
		group.positions.append_array(baked_positions);group.normals.append_array(baked_normals)
		for vertex in hit.indices:group.indices.append(base+vertex)
		group.members.append({"index":index,"mesh":geometry.mesh,"pose":pose,"layers":geometry.layers,"part":part_index,"parent":eligible.parent})
	var result:={"groups":[],"members":[],"stats":stats,"bundle":bundle,"scope":"Immutable direct terrain ModelInstance only; no main surface, light, collision or entity changes"}
	for group in groups.values():
		if group.members.size()<2:reject(stats,"singleton-group");continue
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=group.positions;arrays[Mesh.ARRAY_NORMAL]=group.normals;arrays[Mesh.ARRAY_INDEX]=group.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if mesh.get_surface_count()!=1:reject(stats,"proxy-publication-failed");continue
		result.groups.append({"mesh":mesh,"material":shadow_material,"layers":group.layers})
		result.members.append_array(group.members)
		stats.accepted_meshes+=group.members.size();stats.groups+=1;stats.vertices+=group.positions.size();stats.triangles+=group.indices.size()/3
	stats.prepare_ms=(Time.get_ticks_usec()-began)/1000.0
	return result
static func install(model: Node3D,plan: Dictionary) -> Dictionary:
	if not model is Template.Placement or model.retired:return {"installed":false,"reason":"unsupported-owner"}
	if model.has_meta(INSTALLED_META):return {"installed":false,"reason":"already-installed"}
	if plan.get("groups",[]).is_empty():return {"installed":false,"reason":"no-proven-group"}
	var rows: Array=plan.get("bundle",{}).get("value",{}).get("nodes",[])
	# Validate the complete plan before changing any original caster flag. A
	# later clone with a changed material/transform/resource uses the full path.
	for member in plan.members:
		if int(member.index)<0 or int(member.index)>=model.meshes.size():return {"installed":false,"reason":"structure-changed"}
		var geometry: MeshInstance3D=model.meshes[int(member.index)]
		var eligible:=eligibility(geometry,model,rows)
		if eligible.has("reason") or eligible.part!=member.part or var_to_bytes(eligible.parent)!=var_to_bytes(member.parent) or geometry.mesh!=member.mesh or geometry.layers!=member.layers:return {"installed":false,"reason":"caster-policy-changed"}
		if var_to_bytes(eligible.pose)!=var_to_bytes(member.pose):return {"installed":false,"reason":"pose-changed"}
	for group in plan.groups:
		var proxy:=MeshInstance3D.new();proxy.name="static_shadow_proxy";proxy.mesh=group.mesh;proxy.material_override=group.material;proxy.layers=group.layers;proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.set_meta(INSTALLED_META,true);model.add_child(proxy)
	for member in plan.members:model.meshes[int(member.index)].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var summary:={"installed":true,"source_casters":plan.members.size(),"proxy_groups":plan.groups.size(),"triangles":plan.stats.triangles}
	model.set_meta(INSTALLED_META,summary)
	return summary
