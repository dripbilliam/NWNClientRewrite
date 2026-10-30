extends Node3D
const ModelPointLight=preload("res://systems/native_render/model_point_light.gd")
const ParticleEmitter=preload("res://systems/native_render/particle_emitter.gd")
const ModelReference=preload("res://systems/native_render/model_reference.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Direct original-data scene assembly. Physical parts/instances stay private;
# immutable mesh/texture/material resources are shared by the native pool.
var failure := ""
var parts: Array = []
var meshes: Array = []
var pick_surfaces: Array=[]
var limitations: Array = []
var installed := false
var retired := false
var install_timings: Dictionary={}
func install(bundle: Dictionary, pool) -> bool:
	if installed or retired: failure = "Native model owner already used"; return false
	if not str(bundle.get("error","")).is_empty(): failure = bundle.error; return false
	var model: Dictionary = bundle.value
	set_meta("native_model_name",str(bundle.get("resource_name",model.name)))
	limitations.append_array(model.get("rig_asset",{}).get("unsupported",[]))
	var basis := Quaternion(Vector3.RIGHT,-PI/2)
	var parents: Dictionary={}
	if pool.compact_static_parts:
		for row in model.nodes:
			if int(row.parent)>=0: parents[int(row.parent)]=true
	for index in model.nodes.size():
		var phase_began:=Timing.begin()
		var row: Dictionary = model.nodes[index]
		# A leaf renderable can be the physical Part itself, as in a native
		# PartTriMesh. Keep source transforms/data unchanged; never absorb a
		# parent, hidden collision part, emitter, reference or model light.
		var compact: bool=pool.compact_static_parts and not parents.has(index) and not row.mesh.is_empty() and not row.mesh.indices.is_empty() and bool(row.mesh.render) and not row.has("emitter") and not row.has("reference") and row.get("light",{}).is_empty() and not row.features.any(func(feature):return feature in ["skin","animated-mesh","dangly"])
		var part: Node3D=MeshInstance3D.new() if compact else Node3D.new()
		part.name = "part_"+str(index); part.set_meta("native_part_name",row.name); part.set_meta("native_part_index",index)
		part.set_meta("native_part_parent",int(row.parent)); part.set_meta("native_part_area",row.mesh.get("native_area") if (int(row.flags)&0x21)==0x21 or int(row.flags)==0 and not row.mesh.is_empty() else 0.0)
		var parent := int(row.parent)
		if parent >= index or parent < -1: part.free(); failure = "Invalid physical native model parent"; _clear_parts(); return false
		if parent == -1: add_child(part)
		else: parts[parent].add_child(part)
		parts.append(part)
		part.position = Vector3(row.position[0],row.position[2],-row.position[1])
		var q := Quaternion(row.orientation[0],row.orientation[1],row.orientation[2],row.orientation[3])
		if q.length_squared() < 1e-16: q = Quaternion.IDENTITY
		part.quaternion = basis * q.normalized() * basis.inverse(); part.scale = Vector3.ONE * float(row.scale)
		for feature in row.features:
			if not limitations.has(feature): limitations.append(feature)
		if row.features.has("light") and not row.get("light",{}).is_empty():
			var light:=ModelPointLight.new(); light.configure(row.light); part.add_child(light)
		if row.has("reference"):
			var reference:=ModelReference.new(); reference.name="native_reference"; reference.original_header=row.reference; reference.origin_resource=str(bundle.get("resource_name",model.name)); part.add_child(reference)
		if row.has("emitter"):
			var emitter:=ParticleEmitter.new(); emitter.name="native_emitter"; emitter.original_properties=row.emitter; emitter.channel_asset=model.get("rig_asset",{}); emitter.physical_part=index
			emitter.origin_resource=str(bundle.get("resource_name",model.name))
			emitter.source_model_flags=int(model.get("classification_flags",-1))
			var texture_name:=str(row.emitter.get("texture","")).to_lower(); var emitter_raster: Dictionary=bundle.get("emitter_textures",{}).get(texture_name,{})
			if not emitter_raster.is_empty():
				emitter.original_texture=pool.texture(emitter_raster)
				if emitter.original_texture==null: emitter.free(); failure=pool.failure; _clear_parts(); return false
			emitter.source_path=NodePath("../"+str(part.get_path_to(self))); part.add_child(emitter)
		var data: Dictionary = row.mesh
		if phase_began>0: install_timings.parts_ms=float(install_timings.get("parts_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
		if data.is_empty() or data.indices.is_empty(): continue
		if not data.render:
			var hit=pool.hidden_geometry(str(bundle.sha256),index,data)
			if phase_began>0: install_timings.hidden_ms=float(install_timings.get("hidden_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0
			if hit==null: failure=pool.failure; _clear_parts(); return false
			# Retain hit data on the existing physical part: scenery does not
			# need a new scene node just to support a possible later flag change.
			part.set_meta("native_pick_geometry",hit); pick_surfaces.append(part)
			continue
		var mesh = pool.geometry(str(bundle.sha256),index,data)
		if phase_began>0: install_timings.geometry_ms=float(install_timings.get("geometry_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
		if mesh == null: failure = pool.failure; _clear_parts(); return false
		var raster := {}; var texture_names: Array = data.textures
		if not texture_names.is_empty():
			var texture_name := str(texture_names[0]).to_lower()
			if not texture_name.is_empty() and texture_name != "null":
				if not bundle.get("textures",{}).has(texture_name): failure = "Original bitmap not prepared: "+texture_name; _clear_parts(); return false
				raster = bundle.textures[texture_name]
		var material = pool.material(row,raster)
		if phase_began>0: install_timings.material_ms=float(install_timings.get("material_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0; phase_began=Time.get_ticks_usec()
		if material == null: failure = pool.failure; _clear_parts(); return false
		var binding_began:=Timing.begin()
		var geometry: MeshInstance3D=part if compact else MeshInstance3D.new()
		if not compact: geometry.name="mesh"
		if binding_began>0: install_timings.node_create_ms=float(install_timings.get("node_create_ms",0.0))+(Time.get_ticks_usec()-binding_began)/1000.0; binding_began=Time.get_ticks_usec()
		geometry.mesh=mesh
		if binding_began>0: install_timings.mesh_bind_ms=float(install_timings.get("mesh_bind_ms",0.0))+(Time.get_ticks_usec()-binding_began)/1000.0; binding_began=Time.get_ticks_usec()
		geometry.material_override=material
		if binding_began>0: install_timings.material_bind_ms=float(install_timings.get("material_bind_ms",0.0))+(Time.get_ticks_usec()-binding_began)/1000.0
		if mesh.has_meta("native_pick_shape"): geometry.set_meta("native_pick_shape",mesh.get_meta("native_pick_shape"))
		geometry.set_meta("native_pick_geometry",mesh.get_meta("native_pick_geometry"))
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visible = data.render and float(row.alpha)>0
		if not compact: part.add_child(geometry)
		meshes.append(geometry)
		if phase_began>0: install_timings.mesh_nodes_ms=float(install_timings.get("mesh_nodes_ms",0.0))+(Time.get_ticks_usec()-phase_began)/1000.0
	for index in model.nodes.size():
		var emitter=parts[index].get_node_or_null("native_emitter")
		if emitter==null: continue
		for child in model.nodes.size():
			if int(model.nodes[child].parent)==index and model.nodes[child].has("reference"): emitter.reference_paths.append(emitter.get_path_to(parts[child].get_node("native_reference")))
	installed = true; return true
func _clear_parts() -> void:
	for part in parts:
		if is_instance_valid(part) and part.get_parent() == self: part.free()
	parts.clear(); meshes.clear(); pick_surfaces.clear()
func retire() -> void:
	if retired: return
	retired = true; _clear_parts(); queue_free()
