extends RefCounted
# Explicit cold observation of existing owners, not another entity registry.
# SOURCE ONLY: no parser/test/engine execution has validated this helper yet.
const MAX_ENTITIES:=64
const MAX_MESHES:=512
const MAX_BATCHES:=16
const MAX_MODELS:=32
const MAX_STRING:=2048

static func property(owner: Object,name: String,fallback: Variant=null) -> Variant:
	if not is_instance_valid(owner): return fallback
	for field in owner.get_property_list():
		if str(field.name)==name: return owner.get(name)
	return fallback
static func text(value: Variant) -> Dictionary:
	if not value is String and not value is StringName: return {"available":false,"value":null,"reason":"not_received_or_not_text"}
	var result:=str(value)
	return {"available":true,"value":result.substr(0,MAX_STRING),"truncated":result.length()>MAX_STRING}
static func field(source: Dictionary,key: String) -> Dictionary:
	if not source.has(key): return {"available":false,"value":null,"reason":"not_received"}
	var value: Variant=source[key]
	if value==null or value is bool or value is int or value is String: return {"available":true,"value":value}
	if value is float and is_finite(value): return {"available":true,"value":value}
	return {"available":false,"value":null,"reason":"unsupported_or_nonfinite_scalar"}
static func owner_field(owner: Object,name: String) -> Dictionary:
	if not is_instance_valid(owner): return {"available":false,"value":null,"reason":"owner_unavailable"}
	for item in owner.get_property_list():
		if str(item.name)==name: return field({name:owner.get(name)},name)
	return {"available":false,"value":null,"reason":"property_unavailable"}
static func membership(value: Variant,id: int) -> Dictionary:
	return {"available":true,"value":value.has(id)} if value is Dictionary else {"available":false,"value":null,"reason":"owner_dictionary_unavailable"}
static func point(value: Variant,space: String) -> Dictionary:
	if value is Vector3:
		return {"available":true,"value":[value.x,value.y,value.z],"space":space} if value.is_finite() else {"available":false,"value":null,"reason":"nonfinite","space":space}
	if value is Array and value.size()==3:
		var result: Array=[]
		for component in value:
			if not (component is int or component is float) or not is_finite(float(component)): return {"available":false,"value":null,"reason":"invalid_components","space":space}
			result.append(component)
		return {"available":true,"value":result,"space":space}
	return {"available":false,"value":null,"reason":"not_received_or_not_vector","space":space}
static func triple(value: Variant) -> Dictionary:
	if not value is Array or value.size()!=3: return {"available":false,"value":null,"reason":"visibility_triple_unavailable"}
	var result: Array=[]
	for component in value:
		if component is bool: result.append(component)
		elif (component is int or component is float) and is_finite(float(component)) and float(component) in [0.0,1.0]: result.append(component)
		else: return {"available":false,"value":null,"reason":"visibility_triple_invalid"}
	return {"available":true,"value":result,"interpretation":"raw_received_order; not a Boolean draw command"}
static func box(value: AABB) -> Dictionary:
	return {"position":[value.position.x,value.position.y,value.position.z],"size":[value.size.x,value.size.y,value.size.z]}
static func error_record(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"available":false,"reason":"no_record"}
	var result:={"available":true}
	for key in ["reason","model","key"]: result[key]=text(value.get(key))
	return result
static func material_view(value: Material) -> Dictionary:
	if value==null: return {"available":false,"reason":"no_material"}
	var result:={"available":true,"class":value.get_class(),"instance_id":str(value.get_instance_id()),"resource_path":text(value.resource_path),"missing_texture":{"available":false,"value":null,"reason":"source_resolution_status_not_retained"}}
	if value is BaseMaterial3D:
		result.alpha=value.albedo_color.a; result.transparency=value.transparency
		result.bound_texture=value.albedo_texture!=null
	elif value is ShaderMaterial:
		result.shader_path=text(value.shader.resource_path if value.shader!=null else null)
		for uniform in ["native_alpha","native_has_texture"]:
			var data: Variant=value.get_shader_parameter(uniform)
			result[uniform]={"available":true,"value":data} if data is bool or data is int or data is float and is_finite(data) else {"available":false,"value":null,"reason":"not_a_retained_scalar"}
	return result
static func source_view(mesh: MeshInstance3D,actor: Node) -> Dictionary:
	var owner: Node=mesh if mesh.has_meta("native_part_index") else mesh.get_parent()
	var names: Variant=property(actor,"model_names",[])
	var model_index: Variant=mesh.get_meta("native_source_model_index") if mesh.has_meta("native_source_model_index") else null
	var part_index: Variant=mesh.get_meta("native_source_part_index") if mesh.has_meta("native_source_part_index") else owner.get_meta("native_part_index") if owner!=null and owner.has_meta("native_part_index") else null
	var resource: Variant=names[model_index] if names is Array and model_index is int and model_index>=0 and model_index<names.size() else actor.get_meta("native_model_name") if actor.has_meta("native_model_name") else null
	# Proposed install-boundary plain metadata; absent in the current cce71 tree.
	# Unknown parsed flags must remain unknown, never inferred from white pixels.
	var facts: Variant=mesh.get_meta("native_mesh_source") if mesh.has_meta("native_mesh_source") else null
	var known: Dictionary=facts if facts is Dictionary else {}
	var authored: Variant=known.get("native_bounds")
	var native_bounds: Dictionary={"available":false,"value":null,"reason":"source_header_unavailable"}
	if authored is Dictionary:
		var low:=point(authored.get("min"),"nwn_model_z_up"); var high:=point(authored.get("max"),"nwn_model_z_up")
		if low.available and high.available: native_bounds={"available":true,"value":{"min":low.value,"max":high.value},"valid":field(known,"native_bounds_valid"),"source":text(known.get("native_bounds_source"))}
	return {"resource":text(known.get("resource",resource)),"model_index":known.get("model_index",model_index),"part_index":known.get("part_index",part_index),"part_name":text(owner.get_meta("native_part_name") if owner!=null and owner.has_meta("native_part_name") else known.get("part_name")),"parsed_render":field(known,"parsed_render"),"original_alpha":field(known,"original_alpha"),"tilefade":field(known,"native_tilefade"),"tilefade_source":text(known.get("native_tilefade_source")),"node_flags":field(known,"node_flags"),"source_format":text(known.get("source_format")),"texture_name":text(known.get("texture_name")),"texture_resolution":text(known.get("texture_resolution")),"missing_texture":field(known,"missing_texture"),"authored_bounds":native_bounds}
static func mesh_view(mesh: MeshInstance3D,actor: Node,camera: Camera3D) -> Dictionary:
	var result:={"instance_id":str(mesh.get_instance_id()),"name":text(str(mesh.name)),"source":source_view(mesh,actor),"inside_tree":mesh.is_inside_tree(),"local_visible":mesh.visible,"visible_in_tree":mesh.is_visible_in_tree(),"layers":mesh.layers,"cast_shadow":mesh.cast_shadow,"transparency":mesh.transparency,"material":material_view(mesh.material_override),"position":point(mesh.global_position if mesh.is_inside_tree() else mesh.position,"godot_world" if mesh.is_inside_tree() else "godot_local"),"actual_drawn":{"available":false,"value":null,"reason":"Node visibility is not a renderer draw/readback witness"}}
	if mesh.mesh==null: result.bounds={"available":false,"reason":"no_mesh"}; return result
	var local: AABB=mesh.mesh.get_aabb()
	result.bounds={"available":true,"local":box(local),"custom":box(mesh.custom_aabb),"kind":"CPU resource AABB, not GPU/skinning/occlusion output"}
	if mesh.is_inside_tree() and mesh.global_transform.is_finite():
		var world_box: AABB=mesh.global_transform*local
		result.bounds.world=box(world_box)
		result.bounds.camera_center_behind=camera.is_position_behind(world_box.get_center()) if is_instance_valid(camera) and camera.is_inside_tree() else null
	return result
static func rig_view(actor: Node,id: int) -> Dictionary:
	var rig: Variant=property(actor,"rigs")
	if not rig is Node or not is_instance_valid(rig): return {"available":false,"reason":"no_rig"}
	var entities: Variant=property(rig,"entities",{})
	var entry: Dictionary=entities.get(id,{}) if entities is Dictionary else {}
	var result:={"available":true,"processing":rig.is_processing(),"animation":field(entry,"animation"),"side":field(entry,"side"),"models":[],"models_truncated":false}
	var models: Variant=entry.get("models")
	if not models is Array: result.model_state={"available":false,"reason":"no_models_array"}; return result
	result.models_truncated=models.size()>MAX_MODELS
	for index in mini(models.size(),MAX_MODELS):
		var model: Variant=models[index]
		if not model is Dictionary: result.models.append({"available":false,"index":index}); continue
		result.models.append({"available":true,"index":index,"active_clip":text(model.get("clip")),"time":field(model,"last_time"),"speed":field(model,"speed"),"loop":field(model,"loop"),"serial":field(model,"play_serial")})
	return result
static func capture(world: Node,registry: Node,camera: Camera3D,request: Dictionary,limits: Dictionary={}) -> Dictionary:
	var result:={"version":1,"status":"unavailable","read_only":true,"scope":"explicit cold per-entity observation; no policy changes or new world store","records":[],"errors":[],"truncated":false}
	if OS.get_thread_caller_id()!=OS.get_main_thread_id(): result.errors.append("main_thread_required"); return result
	if request.get("post_window")!=true or request.get("measurement_active")!=false: result.errors.append("explicit_post_window_required"); return result
	if not is_instance_valid(world) or not world.is_inside_tree(): result.errors.append("active_world_required"); return result
	var generation: Variant=property(world,"generation"); var area_id: Variant=property(world,"area_id")
	if request.get("expected_world_instance_id")!=world.get_instance_id() or request.get("expected_generation")!=generation or request.get("expected_area_id")!=area_id: result.errors.append("scope_mismatch"); return result
	if property(world,"closed",true)!=false or property(world,"retiring",true)!=false: result.errors.append("world_retiring_or_closed"); return result
	var ids: Variant=request.get("ids")
	if not ids is Array: result.errors.append("explicit_ids_required"); return result
	var maximum:=clampi(int(limits.get("entities",32)),1,MAX_ENTITIES); var mesh_limit:=clampi(int(limits.get("meshes",128)),1,MAX_MESHES)
	result.truncated=ids.size()>maximum
	var desired: Variant=property(world,"desired"); var instances: Variant=property(world,"instances"); var installed: Variant=property(world,"installed"); var hidden: Variant=property(world,"hidden"); var failed: Variant=property(world,"failed_objects")
	if not desired is Dictionary or not instances is Dictionary: result.errors.append("world_owner_dictionaries_unavailable"); return result
	var registry_entities: Variant=property(registry,"entities"); var registry_owners: Variant=property(registry,"native_owners")
	var pending: Variant=property(world,"batches")
	var known: Variant=request.get("known_objects")
	var controlled: Variant=property(world,"controlled_id"); var controlled_source: Dictionary=known.get(controlled,{}) if known is Dictionary else desired.get(controlled,{}).get("object",{}) if desired.has(controlled) else {}
	var player_visibility: Variant=controlled_source.get("playerState",{}).get("visibility")
	result.world={"instance_id":str(world.get_instance_id()),"generation":generation,"area_id":area_id,"connection_scope":field(request,"connection_scope"),"controlled_id":controlled}
	var total_meshes:=0
	for offset in mini(ids.size(),maximum):
		var id: Variant=ids[offset]
		if not id is int or id<0 or id>4294967295: result.errors.append("invalid_object_id_at_"+str(offset)); continue
		var entry: Variant=desired.get(id); var source: Dictionary=entry.get("object",{}) if entry is Dictionary else {}; var wire: Dictionary=source.get("replicated",{})
		if known is Dictionary:
			source=known.get(id,{});wire=source.get("replicated",{})
		var actor: Variant=instances.get(id)
		var admission:={"installed":membership(installed,id),"hidden_mark":membership(hidden,id),"failure":error_record(failed.get(id)) if failed is Dictionary else {"available":false},"batches":{"available":pending is Array,"records":[],"truncated":pending.size()>MAX_BATCHES if pending is Array else false}}
		if pending is Array:
			for batch_index in mini(pending.size(),MAX_BATCHES):
				var batch: Variant=pending[batch_index]
				if not batch is Dictionary: continue
				var keys: Variant=batch.get("keys")
				if not keys is Dictionary or not keys.has(id): continue
				var owner: Variant=batch.get("owner")
				admission.batches.records.append({"index":batch_index,"actors":field(batch,"actors"),"owner_present":owner is Node and is_instance_valid(owner),"failure":text(property(owner,"failure")) if owner is Node else {"available":false},"done":owner_field(owner,"done") if owner is Node else {"available":false}})
		var row:={"object_id":str(id),"known_in_current_desired":desired.has(id),"received":{"area_id":field(source,"areaId"),"lifetime":field(source,"nativeLifetime"),"disclosure_lifetime":field(source,"disclosureLifetime"),"removed":field(source,"replicationRemoved"),"object_type":field(source,"objectType"),"position":point(wire.get("position"),"nwn_z_up"),"visibility":triple(wire.get("visibility"))},"controlled_visibility":triple(player_visibility.get(str(id),player_visibility.get(id)) if player_visibility is Dictionary else null),"admission":admission,"registry":{"available":is_instance_valid(registry),"entity_known":membership(registry_entities,id),"native_owner_known":membership(registry_owners,id)},"instance_present":actor is Node and is_instance_valid(actor),"meshes":[],"meshes_truncated":false}
		if actor is Node and is_instance_valid(actor):
			row.scene={"instance_id":str(actor.get_instance_id()),"inside_tree":actor.is_inside_tree(),"retired":owner_field(actor,"retired"),"failure":text(property(actor,"failure")),"can_process":actor.can_process() if actor.is_inside_tree() else null}
			if actor is Node3D:
				row.scene.local_visible=actor.visible; row.scene.visible_in_tree=actor.is_visible_in_tree()
				row.scene.position=point(actor.global_position if actor.is_inside_tree() else actor.position,"godot_world" if actor.is_inside_tree() else "godot_local")
			row.rig=rig_view(actor,id)
			var meshes: Variant=property(actor,"meshes")
			if meshes is Array:
				var count:=mini(meshes.size(),maxi(0,mesh_limit-total_meshes)); row.meshes_truncated=count<meshes.size()
				for index in count:
					if meshes[index] is MeshInstance3D and is_instance_valid(meshes[index]): row.meshes.append(mesh_view(meshes[index],actor,camera)); total_meshes+=1
			else: row.mesh_source_unavailable=true
		row.known_received=membership(known,id)
		row.source_owner="client_known_registry" if known is Dictionary else "renderer_desired_only"
		result.records.append(row)
	result.mesh_records=total_meshes
	if not is_instance_valid(world) or generation!=property(world,"generation") or area_id!=property(world,"area_id"):
		result.records=[]; result.errors.append("scope_changed_during_observation"); return result
	result.status="truncated" if result.truncated or result.records.any(func(row):return row.meshes_truncated) else "complete"
	return result
