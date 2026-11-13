extends RefCounted
# One-shot post-window inspection only. Never invokes a clock/controller,
# resolves a lazy clip, advances animation, samples a particle, or writes Nodes.
static func increment(counts: Dictionary,key: String,value: int=1) -> void:
	counts[key]=int(counts.get(key,0))+value
static func box_values(box: AABB) -> Array:
	return [box.position.x,box.position.y,box.position.z,box.size.x,box.size.y,box.size.z]
static func chunk_model_row(model: Node3D) -> Dictionary:
	var out: Dictionary={"id":model.get_instance_id(),"inside_tree":model.is_inside_tree(),"meshes":[],"bounds_source":"current installed MeshInstance3D AABBs; not original child-Gob sphere"}
	if not model.is_inside_tree():return out
	out.visible=model.is_visible_in_tree();var position: Vector3=model.global_position;out.position=[position.x,position.y,position.z]
	var fields: Dictionary={}
	for info: Dictionary in model.get_property_list():fields[str(info.name)]=true
	if not fields.has("meshes"):out.unknown_mesh_owner=true;return out
	var meshes: Array=model.get("meshes");var have_bound: bool=false;var bound: AABB=AABB()
	for value: Variant in meshes:
		if not is_instance_valid(value) or not value is MeshInstance3D:continue
		var mesh: MeshInstance3D=value
		if not mesh.is_inside_tree():continue
		var local: AABB=mesh.get_aabb();var world: AABB=mesh.global_transform*local
		out.meshes.append({"id":mesh.get_instance_id(),"visible":mesh.is_visible_in_tree(),"local_aabb":box_values(local),"world_aabb":box_values(world),"has_custom_aabb":mesh.custom_aabb!=AABB()})
		bound=bound.merge(world) if have_bound else world;have_bound=true
	if have_bound:out.world_mesh_aabb=box_values(bound)
	if model.has_meta("native_scene_bounds"):
		var cached: Variant=model.get_meta("native_scene_bounds")
		if cached is AABB:out.cached_native_scene_aabb=box_values(cached)
	return out
static func capture(group: Node) -> Dictionary:
	var result: Dictionary={"version":1,"kind":"native-render-gap-particle-source-census","counts":{},"source_flags":{},"rows":[],"limitations":["One-shot live binding/state inspection, not per-entry CPU time.","A model.native_owner is required for the duplicate Part/controller opportunity. Ordinary AnimationPlayer emitter tracks are sampled separately and are not presumed duplicate."]}
	if not is_instance_valid(group):result.error="No live shared particle group";return result
	var members: Dictionary=group.get("members")
	for id: int in members:
		var member: Dictionary=members[id]
		var reference: WeakRef=member.get("emitter")
		var emitter: Node3D=reference.get_ref() if reference!=null else null
		if not is_instance_valid(emitter):increment(result.counts,"retired_members");continue
		var row: Dictionary={"id":id,"fast":bool(member.get("fast",false)),"source_model_flags":int(emitter.get("source_model_flags")),"source_id":0,"pose_id":0,"clock":"static","model_native_owner":false,"model_index":-1,"model_clip":"","selected_clip":"","selected_channels":0,"constant_channels":0,"dynamic_channels":0,"chunk":false,"gd_last_culled":bool(emitter.get("last_culled")),"culled_source":"GDScript mirror may be stale in fast shared mode; use native Step survey"}
		increment(result.counts,"members");increment(result.source_flags,str(row.source_model_flags))
		var source: Node3D=emitter.get("source")
		if is_instance_valid(source):row.source_id=source.get_instance_id()
		if is_instance_valid(emitter.get_parent()):row.pose_id=emitter.get_parent().get_instance_id()
		var particle_owner: RefCounted=emitter.get("native_owner")
		if particle_owner!=null:
			# Existing read-only owner operation: no Node getter, controller or
			# clock invocation. Count actual local conversion misses before
			# considering a shared numeric cache or typed math boundary.
			row.numeric_pose_cache=particle_owner.call("dispatch",8,{},{})
			increment(result.counts,"numeric_pose_cache_hits",int(row.numeric_pose_cache.get("hits",0)))
			increment(result.counts,"numeric_pose_conversions",int(row.numeric_pose_cache.get("conversions",0)))
		var properties: Dictionary=emitter.get("original_properties")
		row.chunk_name_raw=str(properties.get("chunkname",""));row.chunk_name_normalized=str(row.chunk_name_raw).to_lower()
		row.chunk=not str(row.chunk_name_raw).is_empty();row.chunk_null=row.chunk_name_normalized=="null";row.chunk_model_rows=[];row.chunk_allocated_models=0
		var chunk_owner: Node=emitter.get("chunk_models")
		if is_instance_valid(chunk_owner):
			row.chunk_no_model=bool(chunk_owner.get("no_model"))
			row.chunk_resource=str(chunk_owner.get("resource"))
			var children: Array=chunk_owner.get("models")
			for child: Variant in children:
				if is_instance_valid(child) and child is Node3D:row.chunk_model_rows.append(chunk_model_row(child));row.chunk_allocated_models+=1
		var clock: Callable=emitter.get("clock_provider")
		row.selected_clip=str(emitter.get("static_clip"))
		if clock.is_valid():
			row.clock="opaque";increment(result.counts,"callable_clocks")
			var producer: Object=clock.get_object()
			var args: Array=clock.get_bound_arguments()
			if is_instance_valid(producer) and clock.get_method()==&"playback_state" and args.size()==2 and args[0] is int and args[1] is int:
				var script: Script=producer.get_script()
				if script!=null and script.resource_path=="res://systems/model_rigs.gd":
					var entities: Dictionary=producer.get("entities");var actor_id: int=int(args[0]);var model_index: int=int(args[1])
					if entities.has(actor_id) and model_index>=0 and model_index<entities[actor_id].models.size():
						var model: Dictionary=entities[actor_id].models[model_index]
						row.clock="canonical-model";row.model_index=model_index;row.model_clip=str(model.get("clip",""));row.selected_clip=row.model_clip;row.model_native_owner=model.get("native_owner")!=null
						row.model_resource=str(model.get("asset_source",{}).get("name",""))
		else:increment(result.counts,"static_clocks")
		var channels: RefCounted=emitter.get("channels")
		var clips: Dictionary=channels.get("clips")
		# Inspect only this already-read compiled source. Empty selected clips
		# do not prove that every other clip is empty. Native Owner made its own
		# copy during configure, so label this separately from a native census.
		row.compiled_source_clip_count=clips.size();row.compiled_source_all_clip_channels=0;row.compiled_source_nonempty_clips=0;row.compiled_source_clip_metadata_complete=true
		for clip: Variant in clips.values():
			if not clip is Dictionary or not clip.get("channels") is Array:
				row.compiled_source_clip_metadata_complete=false;continue
			var clip_channels: Array=clip.channels
			row.compiled_source_all_clip_channels+=clip_channels.size()
			if not clip_channels.is_empty():row.compiled_source_nonempty_clips+=1
		row.compiled_source_all_clips_empty=bool(row.compiled_source_clip_metadata_complete) and int(row.compiled_source_all_clip_channels)==0
		increment(result.counts,"compiled_source_all_clip_channels",int(row.compiled_source_all_clip_channels))
		increment(result.counts,"compiled_source_all_clips_empty",1 if row.compiled_source_all_clips_empty else 0)
		increment(result.counts,"compiled_source_clip_metadata_unknown",0 if row.compiled_source_clip_metadata_complete else 1)
		for channel: Dictionary in clips.get(row.selected_clip,{}).get("channels",[]):
			row.selected_channels+=1
			if bool(channel.get("constant_eligible",false)):row.constant_channels+=1
			else:row.dynamic_channels+=1
		increment(result.counts,"canonical_model_clocks",1 if row.clock=="canonical-model" else 0)
		increment(result.counts,"native_owner_emitters",1 if row.model_native_owner else 0)
		increment(result.counts,"native_owner_selected_channels",int(row.selected_channels) if row.model_native_owner else 0)
		increment(result.counts,"selected_channels",int(row.selected_channels))
		increment(result.counts,"no_selected_channels",1 if row.selected_channels==0 else 0)
		increment(result.counts,"constant_channels",int(row.constant_channels))
		increment(result.counts,"dynamic_channels",int(row.dynamic_channels))
		increment(result.counts,"chunks",1 if row.chunk else 0)
		increment(result.counts,"chunks_null_name",1 if row.chunk_null else 0)
		increment(result.counts,"chunks_with_allocated_models",1 if row.chunk and int(row.chunk_allocated_models)>0 else 0)
		increment(result.counts,"chunks_without_allocated_models",1 if row.chunk and int(row.chunk_allocated_models)==0 else 0)
		increment(result.counts,"chunk_allocated_models",int(row.chunk_allocated_models))
		increment(result.counts,"unknown_source_flags",1 if int(row.source_model_flags)<0 else 0)
		increment(result.counts,"effect_class",1 if int(row.source_model_flags)>=0 and (int(row.source_model_flags)&1)!=0 else 0)
		result.rows.append(row)
	return result
