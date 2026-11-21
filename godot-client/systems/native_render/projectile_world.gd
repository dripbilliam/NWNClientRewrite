extends Node
# Native private projectile ownership. Server packets decide spell, target,
# result and travel time; this owner never computes damage or sends outcomes.
const State=preload("res://systems/native_data/projectile_state.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
const WorldTimer=preload("res://systems/native_data/world_timer.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Ranged=preload("res://systems/native_data/projectile_ranged.gd")
const Impact=preload("res://systems/native_data/projectile_impact.gd")
const Orientation=preload("res://systems/native_data/projectile_orientation.gd")
const ProjectileRandom=preload("res://systems/native_data/projectile_random.gd")
const VisualType10=preload("res://systems/native_data/visual_type10.gd")
const Parts=preload("res://systems/native_data/model_random_part.gd")
const ModelReference=preload("res://systems/native_render/model_reference.gd")
const ParticleEmitter=preload("res://systems/native_render/particle_emitter.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const ScriptString=preload("res://systems/native_data/native_script_string.gd")
const SceneQuery=preload("res://systems/native_render/projectile_scene.gd")
const VisualNodePose=preload("res://systems/native_data/visual_node_pose.gd")
var manager
var table: Dictionary={}
var queue: Array=[]
var active: Dictionary={}
var history: Array=[]
var p: Dictionary={}
var impact_providers: Dictionary={}
var ranged_tables: Dictionary={}
var receiving: Dictionary={}
var tracking: Dictionary={}
var adapter_events: Array=[]
var impact_actor_id:=State.INVALID
var current_update_state: Dictionary={}
const PART_QUERY_FAILURE="Visual main model requires a single physical root part"
var part_query_failure:=""
func take_part_query_failure() -> String:
	var result:=part_query_failure
	part_query_failure=""
	return result
func _physical_root_count(model: Variant) -> int:
	if not is_instance_valid(model):return 0
	if model.has_method("physical_root_count"):return int(model.physical_root_count())
	var rigs=model.get("rigs")
	if is_instance_valid(rigs):
		var id:=int(model.get("object_id"))
		if not rigs.entities.has(id) or rigs.entities[id].model_parts.is_empty():return 0
		var entry: Dictionary=rigs.entities[id]
		var parts: Array=entry.model_parts[0]
		var roots:=0
		for index in parts:
			if not str(entry.authored_names[int(index)]).is_empty() and not parts.has(int(entry.parents[int(index)])):roots+=1
		return roots
	var parts: Variant=model.get("parts")
	if parts is Array:
		var roots:=0
		for part in parts:
			if is_instance_valid(part) and not str(part.get_meta("native_part_name","")).is_empty() and not parts.has(part.get_parent()):roots+=1
		return roots
	return 1
func _part_query(model: Variant) -> bool:
	if _physical_root_count(model)==1:return true
	part_query_failure=PART_QUERY_FAILURE
	return false
var preload_signature:=""
var preload_models: Dictionary={}
var closed:=false
var impact_fields_reported:=false
var stats:={"received":0,"spawned":0,"loaded":0,"impacts":0,"destroyed":0,"retired":0,"stale":0,"failed":0,"overflow":0,"scene_queries":0,"scene_hits":0,"scene_query_us_total":0,"scene_query_us_max":0}
func projectile_scene(s: Dictionary,on: int) -> bool:
	if not is_instance_valid(s.model): return false
	if on!=0:
		if s.model.get_parent()==null:
			# Receiver-owned models enter only at their explicit setScene step.
			if not bool(s.model.get_meta("native_scene_published",true)):
				if not manager.publish_projectile_model(s.model,manager):return false
				schedule_projectile_model(s.model)
			else:manager.add_child(s.model)
	elif s.model.get_parent()!=null: s.model.get_parent().remove_child(s.model)
	return true
func schedule_projectile_model(model: Node3D) -> void:
	# The projectile owner runs before the rig. A kind-11 node advances its
	# animator twice explicitly during the transition; the rig's scheduled
	# process supplies the one ordinary update afterward, as in the old owner.
	if not is_instance_valid(model):return
	if model.get("rigs")!=null:model.rigs.process_priority=51
	for child in model.find_children("*","Node",true,false):
		if child.has_method("reattach_references") and child.get("rigs")!=null:child.rigs.process_priority=51
		elif child.get_script()==ModelReference:child.process_priority=52
		elif child.get_script()==ParticleEmitter and int(child.process_priority)<110:
			# The ordinary world walks every emitter after projectile/visual poses.
			# Keep its registered world phase; priority 53 is only for standalone
			# or private projectile presentations without that scene owner.
			var scene_owner: Node=child.native_scene_order
			if not is_instance_valid(scene_owner):
				var ancestor:=child.get_parent()
				while ancestor!=null:
					if ancestor.has_meta("native_particle_scene_order"):
						scene_owner=ancestor.get_meta("native_particle_scene_order")
						break
					ancestor=ancestor.get_parent()
			if is_instance_valid(scene_owner):
				child.process_priority=scene_owner.process_priority
				scene_owner.register(child)
			else:child.process_priority=53
func set_stage(s: Dictionary,value: int) -> int:
	var result:int=State.stage(s,value,p)
	if result!=0:
		event("stage",s,{"stage":value})
		if value==2: stats.impacts+=1
	return result
func native_appearance(object: Dictionary) -> int:
	var appearance:Variant=object.get("appearance",null)
	if appearance is Dictionary and appearance.has("appearance"):return int(appearance.appearance)
	var creature_data:Variant=object.get("creatureData",null)
	if creature_data is Dictionary and creature_data.has("Appearance_Type"):return int(creature_data.Appearance_Type)
	var authored:Variant=object.get("authored",null)
	if authored is Dictionary and authored.has("Appearance_Type"):return int(authored.Appearance_Type)
	if appearance!=null and not appearance is Dictionary:return int(appearance)
	receiving.failure="Native ranged projectile creature appearance is unavailable"
	return 65535
func native_world_time() -> Dictionary:
	var timer:Variant=manager.combat_timer
	if timer==null or not timer.has_method("time"): return {}
	var value:Dictionary=timer.time()
	return {"day":int(value.day),"time":int(value.time)} if bool(value.get("ready",false)) else {}
func native_world_difference(a: Dictionary,b: Dictionary) -> Dictionary:
	var timer:Variant=manager.combat_timer
	if timer==null: return {"time":0}
	var value:Dictionary=WorldTimer.subtract_world_times(a,b,timer.day_length)
	return {"day":int(value.day),"time":int(value.time)} if bool(value.get("ready",false)) and bool(value.get("outputsDefined",false)) else {"time":0}
func adapter_event(value: Dictionary) -> void:
	adapter_events.append(value)
	if adapter_events.size()>64:adapter_events.pop_front()
func loop_sound_snapshot(id: int) -> Dictionary:
	var audio=manager.world_audio
	return audio.sound_source_snapshot(audio.voices[id]) if audio.voices.has(id) else {}
func create_loop_sound(name: String) -> Variant:
	var id:int=manager.world_audio.create_sound(name,0,State.INVALID,"projectile-loop")
	if id<0:return null
	stats.soundCreated=int(stats.get("soundCreated",0))+1
	adapter_event({"kind":"loopSoundCreate","resRef":name})
	return id
func play_loop_sound(id: int) -> void:
	manager.world_audio.play(id)
	stats.soundPlayRequests=int(stats.get("soundPlayRequests",0))+1
	adapter_event({"kind":"loopSoundPlay","resRef":str(manager.world_audio.voices[id].name) if manager.world_audio.voices.has(id) else ""})
func stop_loop_sound(id: int) -> void:
	stats.soundStopped=int(stats.get("soundStopped",0))+1
	adapter_event({"kind":"loopSoundStop","resRef":str(manager.world_audio.voices[id].name) if manager.world_audio.voices.has(id) else "","sound":loop_sound_snapshot(id)})
	manager.world_audio.stop(id)
func destroy_loop_sound(id: int) -> void:
	if not manager.world_audio.voices.has(id):return
	stats.soundDestroyed=int(stats.get("soundDestroyed",0))+1
	adapter_event({"kind":"loopSoundDestroy","resRef":str(manager.world_audio.voices[id].name),"sound":loop_sound_snapshot(id)})
	manager.world_audio.destroy(id)
func configure(owner) -> void:
	manager=owner; process_priority=50
	for name in ["spells","baseitems","ammunitiontypes"]:
		var job: int=manager.assets.request(name,2017,"2da"); manager.jobs[job]={"kind":"projectile-table","name":name}
	var audio=manager.world_audio
	p={"getObject":func(id):
		var object: Variant=object_view(id); return {"status":0 if object!=null else 1,"object":object},
		"clientObject":object_view,"model":model_view,"nodePose":node_pose,"allocateNode":func(_n):pass,"destroyNode":func(_n):pass,
		"partQueryFailure":take_part_query_failure,"failPartQuery":fail_projectile,
		"buildPath":func(s,path):State.build_path(s,path,p),"initializeNode":func(s,orientation):State.initialize_node(s,orientation,p),"nextNode":func(s):return State.next_node(s,p),"updatePath":func(s):State.update_path(s,p),
		"basicMotion":func(s):move(s,"basic"),"spiralMotion":func(s):move(s,"spiral"),"initializeSpecial":linked,"linkRandomModel":link_random_model,"unsupported":unsupported,"random":func():return manager.world.combat.engine.selector.random(),
		"setPosition":set_position,"setStage":set_stage,"getStage":func(s):return s.stage,
		"animateExternal":animate_external,
		"spawnNodeChildren":missing_child_spawn,
		"playAnimation":func(model,name,speed,flags,time):
			if is_instance_valid(model) and not model.play_effect_clip(name,speed,flags,time): manager.diagnose("projectile.clip-unavailable",str(name),0),
		"difference":native_world_difference,"camera":func():return manager.get_viewport().get_camera_3d(),"faceCamera":func(_s,_camera):unsupported("projectile.camera-facing",1),
		"createSound":create_loop_sound,"destroySound":destroy_loop_sound,"stopSound":stop_loop_sound,"playSound":play_loop_sound,
		"soundPriority":func(id,value):audio.setting(id,"setting1401da060",value),"sound3d":func(id,value):audio.setting(id,"setting1401d9e90",value),"soundLooping":func(id,value):audio.setting(id,"setting1401d9f90",value),"updateSound":audio.move,
		"oneShot":func(name,position,priority,height):audio.one_shot(name,position,height,priority,0,0,0,State.INVALID,"projectile"),"attachImpact":impact,"setScene":projectile_scene,"destroy":destroy}
	p.merge({"worldTime":func():return receiving.constructorTime if receiving.has("constructorTime") else native_world_time(),"register":register_ranged,"registerAI":func(_s):pass,"object":ranged_object,
		"sceneAvailable":func():return true,"trace":scene_trace,
		"rangedMetadata":func(base,appearance):return Ranged.metadata(ranged_tables,base,appearance),"shortDirection":func(_h):return [1.0,0.0,0.0],
		"appearance":native_appearance,"modelType":func(id):return SpellMetadata.native_string_entry(manager.tables.appearance,id,"modeltype").value,
		"weaponScale":func(id):return MovementRate.native_float_entry(manager.tables.appearance,id,"weaponscale"),"hitPartsEnabled":func():return 1,"modelHandle":func(o):return model_view(o),
		"randomImpactPart":random_impact_part,"receiverFailed":func():return not str(receiving.get("failure","")).is_empty(),"loadModel":load_ranged,"modelScale":func(model,value,_flags):model.scale=Vector3.ONE*value,
		"defaultMaterial":func(_s):pass, # Original loaded DEFAULT material remains selected.
		"setTarget":set_target,"trackProjectile":track_projectile,"setOrientation":orient,"configurePath":func(s,path):State.configure_path(s,path,p),"ready":ready_ranged,
		"sceneFailed":func(s):receiving.failure="Native ranged projectile scene publication failed";destroy(s)})
	impact_providers={"getObject":p.getObject,"modelHandle":p.modelHandle,"field28":impact_field28,"model":model_view,
		"creature":func(o):return o if int(o.objectType)==5 else null,"equipped":equipped_id,"item":item_view,"weaponWield":func(item):return int(Query.query(ranged_tables.baseitems,int(item.baseItem),"WeaponWield","integer").value)&255,
		"itemModel":func(item,_part,_flags):return {"actor":item.equipmentActor,"slot":item.equipmentSlot},"random":p.random,"attach":attach_impact,
		"nodePose":node_pose,"partQueryFailure":take_part_query_failure,"setNodePose":func(model,part,position,q):
			if not _part_query(model):return false
			return model.set_part_world_pose(part,position,q),"impactQuaternion":Orientation.impact,"rangedImpact":ranged_impact}
func report_path_failure(header: Dictionary,path: int) -> void:
	manager.diagnose("visual.projectile-receiver-failed","Native projectile path builder %d is unavailable" % path,0,{"header":header.duplicate(true)})
	stats.failed+=1
func impact_field28(object: Dictionary) -> int:
	if not impact_fields_reported:
		impact_fields_reported=true
		manager.diagnose("visual.projectile-impact-client-fields-incomplete","Impact uses the native client flag28 constructor value; complete client flag update replication remains unavailable",int(object.get("id",0)))
	# ClientObjectArray constructs external mirrors with nativeField28=0.
	return int(object.get("nativeField28",0))
func missing_child_spawn(s: Dictionary,_node: Dictionary) -> bool:
	stats.failed+=1
	manager.diagnose("visual.projectile-update-failed","Native projectile path provider spawnNodeChildren is unavailable",int(s.id),{"id":int(s.id),"path":int(s.path)})
	destroy(s)
	return false
func accept_table(name: String,data: Dictionary) -> void:
	if name=="spells": table=data
	else: ranged_tables[name]=data
func scene_trace(a: Array,b: Array) -> Dictionary:
	var began:=Time.get_ticks_usec(); var result:=SceneQuery.trace(manager.world,a,b); var elapsed:=Time.get_ticks_usec()-began
	stats.scene_queries+=1; stats.scene_hits+=int(result.hit); stats.scene_query_us_total+=elapsed; stats.scene_query_us_max=maxi(int(stats.scene_query_us_max),elapsed)
	return result
func prefetch_equipment() -> void:
	if ranged_tables.size()!=2 or not manager.world.desired.has(int(manager.world.controlled_id)): return
	var desired: Dictionary=manager.world.desired[int(manager.world.controlled_id)]; var signature:=str(desired.key)
	if signature!=preload_signature:
		preload_signature=signature; preload_models.clear(); var bow:=-1
		for entry in desired.object.get("appearance",{}).get("equipment",[]):
			if int(entry.slot)==16: bow=int(entry.get("item",{}).get("baseItem",-1)); break
		if bow>=0:
			var appearances: Dictionary={0:true}; var table_data: Dictionary=ranged_tables.ammunitiontypes
			var columns: Array=table_data.get("columns",[]).map(func(name):return str(name).to_lower())
			if columns.has("ammunitiontype") and columns.has("damagerangedprojectile"):
				var ammo:=int(Query.query(ranged_tables.baseitems,bow&255,"AmmunitionType","integer").value)&255; var signed:=ammo-256 if ammo>=128 else ammo
				for i in table_data.get("orderedRows",[]).size():
					var a:=Query.query(table_data,i,"AmmunitionType","integer"); var d:=Query.query(table_data,i,"DamageRangedProjectile","integer")
					if a.found and d.found and int(a.value)==signed and int(d.value)>=0 and int(d.value)<=255 and int(d.value) not in [6,7]: appearances[int(d.value)]=true
			else:
				for appearance in 6: appearances[appearance]=true
			for appearance in appearances:
				var data:=Ranged.metadata(ranged_tables,bow,int(appearance))
				if not data.is_empty() and int(data.ammunition) in [1,2,3,4,5,6] and preload_models.size()<64: preload_models[str(data.model).to_lower()]=true
	# Only the controlled equipment signature is observed. Never scan scenery or
	# other creatures every frame, and never publish GPU instances while warming.
	if not preload_models.is_empty(): manager.ensure_models(preload_models)
func ranged_object(id: int) -> Variant:
	return object_view(id)
func register_ranged(s: Dictionary) -> void:
	s.targetId=int(receiving.header.targetId); s.sourceId=int(receiving.header.sourceId); s.resource=""; s.binding=[]; s.token=0; s.targetLifetime=0; s.ranged=true
	var allocation: Dictionary=manager.client_dummies.allocate(false,8,s)
	if allocation.is_empty(): stats.overflow+=1; return
	s.id=int(allocation.id); s.token=int(allocation.token); active[s.id]=s; stats.spawned+=1
func load_ranged(s: Dictionary,resource: String,_path: int) -> int:
	if int(s.id)==State.INVALID: return 0
	s.resource=resource; s.resourceName=resource
	var model=manager.create_model(int(s.id),resource.to_lower(),false)
	if model==null:
		stats.failed+=1;manager.diagnose("visual.projectile-model-failed","Native projectile model could not be created",int(s.id),{"id":int(s.id),"resource":resource})
		return 0
	if closed or bool(s.destroyed):
		manager.release_model(model)
		if not bool(s.destroyed):destroy(s)
		return 0
	if admissible(receiving.event,int(receiving.received))<0:
		reject_loaded_model(s,model,receiving.header)
		return 0
	s.model=model
	manager.client_dummies.entries[int(s.id)].model=model; stats.loaded+=1; event("loaded",s,{"resource":resource}); return 1
func ready_ranged(s: Dictionary) -> void:
	if bool(s.get("destroyed",false)):return
	s.ready=true
	var admitted_target:Variant=canonical_lifetime(int(s.targetId)) if int(s.targetId)==int(receiving.event.id) else null
	s.targetLifetime=int(admitted_target) if admitted_target!=null else 0
	event("ready",s,{"duration":int(receiving.header.duration),"preparationMs":Time.get_ticks_msec()-int(receiving.received),"ranged":true,"packetResult":int(receiving.header.result),"baseItem":int(receiving.header.baseItem),"impactNode":s.impactNode})
func set_target(s: Dictionary,id: int,name: String) -> void:
	id=id&0xffffffff
	var target: Variant=object_view(id)
	var impact: String="impact"
	if target!=null and int(target.objectType) in [9,10]:
		var prefix:Dictionary=Query.prefix(manager.descriptor(id,int(target.get("privateToken",0))),int(target.objectType))
		if prefix.has("error"):fail_projectile(s,str(prefix.error));return
		impact=str(prefix.value)+("_impact" if int(target.objectType)==9 else "impc")
	elif not name.is_empty():
		var right:Dictionary=ScriptString.right(name,0x7fffffff)
		if right.has("error"):fail_projectile(s,str(right.error));return
		impact=right.value
	s.impactNode=impact
	s.targetId=id
func random_impact_part(model) -> Variant:
	if not model.has_method("impact_model"): receiving.failure="Native physical model selector unavailable"; return null
	var data: Dictionary=model.impact_model()
	if data.has("error"): receiving.failure=str(data.error); return null
	var selected: Variant=Parts.choose(data,p.random)
	if selected is Dictionary and selected.has("error"):
		receiving.failure=str(selected.error)
		return null
	return selected
func track_projectile(target: Dictionary,s: Dictionary) -> void:
	var id:=int(target.id)
	if not tracking.has(id): tracking[id]=[]
	tracking[id].append(int(s.id)); s.trackingTarget=id
func equipped_id(creature: Variant,slot: int) -> int:
	if creature==null: return State.INVALID
	for entry in creature.get("appearance",{}).get("equipment",[]):
		if int(entry.slot)==slot: return int(entry.id)
	return State.INVALID
func item_view(id: int) -> Variant:
	var row: Variant=manager.object(id); var item: Dictionary={}; var actor:=impact_actor_id
	if row!=null and row.has("item"): item=row.item.duplicate(); actor=int(row.get("equipmentOwnerId",actor))
	else:
		var target: Variant=object_view(actor)
		for entry in target.get("appearance",{}).get("equipment",[]) if target!=null else []:
			if int(entry.id)==id: item=entry.item.duplicate(); break
	if item.is_empty(): return null
	item.equipmentActor=actor; item.equipmentSlot=32; return item
func local_node_pose(model,name: String,point: Array,q: Array) -> int:
	if not _part_query(model):return -1
	var node: Node3D=model.node_for(0,name)
	if node==null: return 0
	point.assign([node.position.x,-node.position.z,node.position.y]); q.assign([node.quaternion.w,node.quaternion.x,-node.quaternion.z,node.quaternion.y]); return 1
func attach_impact(model,anchor,part: String,_flags: int) -> bool:
	var node: Node3D=null
	if anchor is Dictionary:
		var actor=manager.host(int(anchor.actor))
		if is_instance_valid(actor) and not _part_query(actor):return false
		if actor!=null and actor.has_method("equipment_part"): node=actor.equipment_part(int(anchor.slot),part)
	elif anchor.has_method("physical_part"):
		if not _part_query(anchor):return false
		node=anchor.physical_part(part)
	if node==null:
		model.detach(); adapter_event({"kind":"impactAttach","resource":str(model.get_meta("resource_name","")),"part":part,"attached":false}); return false
	var attached:bool=model.attach_to(node,0)
	adapter_event({"kind":"impactAttach","resource":str(model.get_meta("resource_name","")),"part":part,"attached":attached})
	return attached
func ranged_impact(target: Dictionary,s: Dictionary) -> void:
	manager.diagnose("visual.projectile-ranged-impact-effect-unimplemented","Native ranged impact blood/weapon effects are not connected",int(target.id),{"targetId":int(target.id),"effect":s.rangedEffect,"critical":s.get("impactCritical"),"damage":s.get("impactDamage")})
	s.rangedEffect=0
func unsupported(code: String,value: int) -> void: manager.diagnose(code,"Native branch remains pending: "+str(value),0)
func fail_projectile(s: Dictionary,message: String) -> void:
	if bool(s.get("destroyed",false)):return
	stats.failed+=1
	manager.diagnose("visual.projectile-update-failed" if bool(s.get("ready",false)) else "visual.projectile-receiver-failed",message,int(s.id),{"id":int(s.id),"path":int(s.path)})
	s.nativeFailure=message
	destroy(s)
func animate_external(model,delta: float) -> bool:
	if not is_instance_valid(model) or not is_instance_valid(model.rigs) or not model.rigs.has_method("_update"):
		if not current_update_state.is_empty():fail_projectile(current_update_state,"Native external model animation provider is unavailable")
		return false
	# CAurObject::AnimateExternal increments a signed int32 header counter on
	# both sides of the animator call. The ordinary rig tick is separate.
	var counter: int=int(model.get_meta("external_animation_counter",0))
	var next: int=(counter+1)&0xffffffff
	if next>=0x80000000:next-=0x100000000
	model.set_meta("external_animation_counter",next)
	model.rigs._update(M.f(delta))
	if not is_instance_valid(model) or not model.has_meta("external_animation_counter"):
		if not current_update_state.is_empty():fail_projectile(current_update_state,"Native external model header vanished during animation")
		return false
	counter=int(model.get_meta("external_animation_counter",0))
	next=(counter+1)&0xffffffff
	if next>=0x80000000:next-=0x100000000
	model.set_meta("external_animation_counter",next)
	return true
func event(kind: String,s: Dictionary,detail: Dictionary={}) -> void:
	if history.size()>=256: history.pop_front()
	var row:={"kind":kind,"id":int(s.id),"at":Time.get_ticks_msec(),"position":s.position.duplicate(),"targetId":int(s.targetId),"resource":s.resource,"path":int(s.path),"spellId":int(s.get("spellId",-1))}; row.merge(detail); history.append(row)
	var old:Dictionary={"kind":kind,"id":int(s.id)}
	match kind:
		"loaded":
			old.resource=str(detail.get("resource",s.resource));old.clips=[]
			if is_instance_valid(s.model):
				var source: Dictionary=s.model.bundle_data.get("value",{})
				for clip in source.get("animations",source.get("rig_asset",{}).get("clips",[])):
					if clip is Dictionary:old.clips.append(str(clip.get("name","")))
		"stage":old.stage=int(detail.get("stage",s.stage))
		"ready":old.position=s.position.duplicate();old.endpoint=s.endpoint.duplicate();old.path=int(s.path)
		"auxiliary":old.resource=str(detail.get("resource",""));old.alias=str(detail.get("alias",""));old.created=bool(detail.get("created",false))
		"procedural":old.programId=int(detail.get("programId",0));old.visualId=int(detail.get("visualId",0));old.sourceId=int(detail.get("sourceId",State.INVALID));old.targetId=int(detail.get("targetId",State.INVALID))
		"destroy":pass
		_:return
	adapter_event(old)
func receive(event_data: Dictionary) -> void:
	if closed: return
	var timer:Variant=manager.combat_timer
	if timer!=null and timer.has_method("snapshot"): timer.snapshot()
	if queue.size()>=128: stats.overflow+=1; return
	stats.received+=1
	var header:Dictionary=event_data.message.header
	var source_registration:bool=event_data.has("sourceRegistration")
	var target_registration:bool=event_data.has("targetRegistration")
	for entry in [[int(header.sourceId),event_data.get("sourceRegistration") if source_registration else event_data.get("sourceLifetime",0),source_registration],[int(header.targetId),event_data.get("targetRegistration") if target_registration else event_data.get("lifetime",0),target_registration]]:
		var expected:Variant=entry[1]
		# RefCounted Handle IDs may set the sign bit. Only zero is an absent
		# registration; legacy nativeLifetime remains positive-only.
		if expected==null:continue
		if bool(entry[2]):
			if int(expected)==0:continue
		elif int(expected)<=0:continue
		var current:Variant=canonical_identity(int(entry[0]),bool(entry[2]))
		if current!=null and int(current)!=int(expected):
			stats.stale+=1
			manager.diagnose("visual.projectile-target-stale","Projectile source or target was replaced before delivery",int(entry[0]),{"sourceId":int(header.sourceId),"targetId":int(header.targetId)})
			return
	# The second old guard captures the presentation's admitted canonical rows
	# after sync. A missing row stays nullable so later appearance is accepted.
	event_data.nativeSourceAtReceive=canonical_identity(int(header.sourceId),source_registration)
	event_data.nativeTargetAtReceive=canonical_identity(int(header.targetId),target_registration)
	event_data.nativeSourceRegistrationMode=source_registration
	event_data.nativeTargetRegistrationMode=target_registration
	var received:=Time.get_ticks_msec()
	if event_data.get("receivedAtMs") is int and int(event_data.receivedAtMs)>0 and int(event_data.receivedAtMs)<=received:received=int(event_data.receivedAtMs)
	queue.append({"event":event_data.duplicate(true),"received":received})
static func network_pose(row: Dictionary,private_dummy: bool=false) -> Dictionary:
	# The original network adapter reads the canonical replicated/static pose.
	# A rendered model can be interpolated or attached elsewhere and is not the
	# position returned by ClientObjectArray.getObject during path updates.
	var state: Dictionary=row.get("replicated",{}) if row.get("replicated",{}) is Dictionary else {}
	var fixed: Dictionary=row.get("staticState",{}) if row.get("staticState",{}) is Dictionary else row.get("lightState",{}) if row.get("lightState",{}) is Dictionary else {}
	var position: Variant=state.get("position",null)
	if position==null: position=fixed.get("position",null)
	# Client-only dummy objects own a flat pose, outside NetworkWorld.registry.
	if position==null and private_dummy: position=row.get("position",null)
	if not position is Array or position.size()!=3: return {}
	var orientation: Variant=state.get("orientation",null)
	if orientation==null: orientation=fixed.get("orientation",null)
	if orientation==null: orientation=row.get("orientation",null)
	var vector: Variant=orientation if orientation is Array else orientation.get("vector",null) if orientation is Dictionary else null
	if not vector is Array:
		var yaw: float=float(orientation.get("yaw",0.0)) if orientation is Dictionary else 0.0
		var radians: float=yaw*PI/180.0
		vector=[NativeMath.native_cosf(radians),NativeMath.native_sinf(radians),0.0]
		if not is_finite(vector[0]) or not is_finite(vector[1]):return {}
	if vector.size()!=3: return {}
	return {"position":position.duplicate(),"orientation":vector.duplicate()}
func canonical_for_id(id: int) -> Variant:
	var row:Variant=manager.world.raw_object_lookup.call(id) if manager.world.raw_object_lookup.is_valid() else manager.object(id)
	if not row is Dictionary or bool(row.get("replicationRemoved",false)) or int(row.get("areaId",State.INVALID))!=int(manager.world.area_id):return null
	return row if not network_pose(row).is_empty() else null
func canonical_lifetime(id: int) -> Variant:
	var row:Variant=canonical_for_id(id)
	return int(row.get("nativeLifetime",0)) if row!=null else null
func canonical_identity(id: int,use_registration: bool) -> Variant:
	var row:Variant=canonical_for_id(id)
	if row==null:return null
	return row.get("nativeProjectileRegistration") if use_registration else int(row.get("nativeLifetime",0))
func object_view(id: int) -> Variant:
	var row: Variant=canonical_for_id(id)
	var private_dummy:=false
	if row==null and manager.client_dummies.entries.has(id):
		row=manager.client_dummies.entries[id].object
		private_dummy=true
	if row==null or not row is Dictionary or bool(row.get("replicationRemoved",false)): return null
	var pose:=network_pose(row,private_dummy)
	if pose.is_empty(): return null
	var result: Dictionary=row.duplicate(); result.position=pose.position; result.orientation=pose.orientation
	# ClientObjectArray's external mirror starts nativeField28 at zero. Its
	# independent native update owner was never supplied by NetworkWorld.
	if not private_dummy:result.nativeField28=0
	return result
func model_view(object: Dictionary,_part: int=255,_flags: int=1) -> Variant:
	return object.model if object.has("model") else manager.host(int(object.id),int(object.get("privateToken",0)))
func node_pose(model: Node3D,name: String,point: Array,q: Array) -> int:
	if not _part_query(model):return -1
	var node: Node3D=null
	if model.has_method("physical_part"):
		# Gob::GetPart treats "root" as the first physical root even when its
		# authored name differs from the literal word.
		if name.to_lower()=="root" and model.get("rigs")!=null:
			node=model.rigs.node_for(int(model.object_id),0,"root")
		else: node=model.physical_part(name)
	elif model.has_method("node_for"): node=model.node_for(0,name)
	elif model.get("rigs")!=null: node=model.rigs.node_for(int(model.object_id),0,name)
	else:
		for part in model.get("parts") if model.get("parts") is Array else []:
			if str(part.get_meta("native_part_name","" )).to_lower()==name.to_lower(): node=part; break
	if node==null: return 0
	VisualNodePose.world_pose(node,point,q)
	return 1
func set_position(s: Dictionary,point: Array) -> void:
	s.position=M.values(point)
	if is_instance_valid(s.model): s.model.position=Vector3(s.position[0],s.position[2],-s.position[1])
func orient(s: Dictionary,direction: Array) -> void:
	s.orientation=M.values(direction)
	if not is_instance_valid(s.model): return
	var q: Variant=Orientation.model(s.orientation)
	if q!=null: s.model.quaternion=Quaternion(q[1],q[3],-q[2],q[0])
func orientation_quaternion(direction: Array) -> Array:
	return Orientation.impact(direction)
func move(s: Dictionary,kind: String) -> void:
	var motion_state: Dictionary=s.duplicate(); motion_state.attachment=s.node.attachment; var result:=State.motion(motion_state,kind)
	if result.has("error"): fail_projectile(s,str(result.error)); return
	s.velocity=result.velocity
	if result.orientation!=null: orient(s,result.orientation)
	set_position(s,result.position)
func linked(s: Dictionary,orientation: Array,delta: Array,time: float) -> void:
	if int(s.node.kind) in [4,9,12]:
		if not ProjectileRandom.initialize(s,orientation,delta,time,p):fail_projectile(s,"Native random projectile initialization is unavailable for kind %d"%int(s.node.kind))
		return
	s.velocity=[0.0,0.0,0.0]; s.acceleration=[0.0,0.0,0.0]
	if int(s.node.kind)!=7: fail_projectile(s,"Native random projectile initialization is unavailable for kind %d"%int(s.node.kind)); return
	bind_references(s)
func link_random_model(s: Dictionary) -> Variant:
	var endpoint=null if s.has("type10AuxReady") and not bool(s.type10AuxReady) else manager.create_model(int(s.id),"ref",false)
	s.auxiliaryModel=endpoint
	event("auxiliary",s,{"resource":"ref","alias":"","created":is_instance_valid(endpoint)})
	if not is_instance_valid(endpoint):return null
	var model=s.model
	if not is_instance_valid(model):
		fail_projectile(s,"Native random projectile source model is unavailable")
		return null
	var point:=Vector3(M.f(model.position.x),M.f(model.position.y),M.f(model.position.z))
	endpoint.position=point
	model.position=Vector3(point.x,M.f(point.y+M.f(0.01)),point.z)
	endpoint.quaternion=Quaternion(M.f(model.quaternion.x),M.f(model.quaternion.y),M.f(model.quaternion.z),M.f(model.quaternion.w))
	# initialize987f10 copies the main model's current scene parent to the
	# endpoint before binding its reference. The normal main shot is already
	# in EffectWorld here; no unrelated parent is silently substituted.
	if not manager.publish_projectile_model(endpoint,model.get_parent()):
		fail_projectile(s,"Native random projectile endpoint scene is unavailable")
		return null
	schedule_projectile_model(endpoint)
	var anchor: Node3D=endpoint.node_for(0,"root")
	var model_nodes: Array=model.bundle_data.get("value",{}).get("nodes",[])
	var has_references: bool=model_nodes.any(func(row):return row is Dictionary and row.has("reference") and (not row.has("type") or str(row.type)=="reference"))
	# The old reattach provider is a no-op for a model with no authored
	# reference Parts; only an actual linked graph needs the endpoint root.
	if has_references and (anchor==null or not model.reattach_references(anchor)):
		fail_projectile(s,"Native random projectile reference graph could not attach")
		return null
	return endpoint
func bind_references(s: Dictionary) -> void:
	if not is_instance_valid(s.model):return
	var target: Variant=object_view(int(s.targetId)); var anchor: Node3D=null
	if target!=null:
		var target_model=model_view(target)
		if target_model==null: return
		anchor=manager.anchor(int(s.targetId),int(target.get("privateToken",0)),str(s.impactNode))
		if anchor==null: anchor=manager.anchor(int(s.targetId),int(target.get("privateToken",0)),"root")
	else:
		if s.auxiliaryModel==null and not s.get("auxiliaryAttempted",false):
			s.auxiliaryAttempted=true
			s.auxiliaryModel=null if s.has("type10AuxReady") and not bool(s.type10AuxReady) else manager.create_model(int(s.id),"ref")
			event("auxiliary",s,{"resource":"ref","alias":"dummytarget","created":is_instance_valid(s.auxiliaryModel)})
			if is_instance_valid(s.auxiliaryModel):schedule_projectile_model(s.auxiliaryModel)
			if s.auxiliaryModel!=null: s.auxiliaryModel.position=Vector3(s.node.point[0],s.node.point[2],-s.node.point[1])
		if is_instance_valid(s.auxiliaryModel): anchor=s.auxiliaryModel.node_for(0,"root")
	if anchor==null: return
	var signature: Array=[anchor.get_instance_id(),s.model.reference_binding_signature()]
	if signature==s.binding: return
	# The old reattach provider rejects a model whose authored reference graph
	# cannot bind. Keep the failed binding out of the cache and retire the shot.
	if not s.model.reattach_references(anchor):
		fail_projectile(s,"Native linked projectile reference graph is unavailable")
		return
	s.binding=[anchor.get_instance_id(),s.model.reference_binding_signature()]
func impact(s: Dictionary) -> bool:
	impact_actor_id=int(s.targetId); var attached: bool=Impact.attach(s,impact_providers); impact_actor_id=State.INVALID
	if not attached:
		var query_error:=str(s.get("partQueryFailure",""))
		s.erase("partQueryFailure")
		if not query_error.is_empty():fail_projectile(s,query_error);return false
		stats.failed+=1
		manager.diagnose("visual.projectile-update-failed","Native projectile shield equipment projection is unavailable",int(s.id),{"id":int(s.id),"path":int(s.path)})
		destroy(s)
		return false
	event("impact",s); s.remaining=int(s.impactDuration)&0xffffffff
	return true
func admissible(event_data: Dictionary,received: int) -> int:
	var packet: Dictionary=event_data.message.header
	for row in [[int(packet.sourceId),event_data.get("nativeSourceAtReceive"),bool(event_data.get("nativeSourceRegistrationMode",false))],[int(packet.targetId),event_data.get("nativeTargetAtReceive"),bool(event_data.get("nativeTargetRegistrationMode",false))]]:
		if row[1]==null:continue
		var current:Variant=canonical_identity(int(row[0]),bool(row[2]))
		if current!=null and int(current)!=int(row[1]):return -1
	return 1
func reject_loaded_model(s: Dictionary,model: Node3D,header: Dictionary) -> void:
	stats.stale+=1
	manager.diagnose("visual.projectile-target-stale","Projectile source or target changed during asset loading",int(s.id),{"id":int(s.id),"sourceId":int(header.sourceId),"targetId":int(header.targetId)})
	manager.release_model(model)
	destroy(s)
func prepare_target_dummy(event_data: Dictionary) -> int:
	var header:Dictionary=event_data.message.header
	if int(header.targetId)==State.INVALID or event_data.has("nativeDummyResult"): return 1
	if not event_data.has("nativeTargetMissing"): event_data.nativeTargetMissing=object_view(int(header.targetId))==null
	if not bool(event_data.nativeTargetMissing): return 1
	if not manager.ensure_models({"c_dummy":true}): return 0
	var result:Dictionary=manager.client_dummies.create_projectile_target(int(header.targetId),header.to,int(header.duration))
	if result.is_empty(): stats.failed+=1; return -1
	event_data.nativeDummyResult=result
	return 1
func prepare_ranged(event_data: Dictionary,received: int) -> bool:
	if ranged_tables.size()!=2 or not manager.tables.has("appearance"): return false
	var header: Dictionary=event_data.message.header.duplicate(true)
	var data: Dictionary=event_data.nativeRangedStart.data if event_data.has("nativeRangedStart") else Ranged.metadata(ranged_tables,int(header.baseItem),int(header.appearance))
	if data.is_empty(): manager.diagnose("projectile.ammunition-unavailable","No active ammunition model for base "+str(header.baseItem)+" / appearance "+str(header.appearance),0); stats.failed+=1; return true
	var missing: bool=event_data.has("nativeDummyResult")
	if missing: header.targetId=int(event_data.nativeDummyResult.targetId)
	# The old ranged receiver releases ShotSound before awaiting loadModel.
	# Retain its launch computation once on this queued packet while resources
	# admit; retries must never replay the sound.
	if not event_data.has("nativeRangedStart"):
		event_data.nativeRangedStart=Ranged.begin(header,p,data)
		if event_data.nativeRangedStart.has("error"):
			manager.diagnose("visual.projectile-receiver-failed",str(event_data.nativeRangedStart.error),int(header.sourceId))
			stats.failed+=1
			return true
	if not event_data.has("nativeConstructorTime"):
		var constructor_time:Dictionary=native_world_time()
		if constructor_time.is_empty(): return false
		event_data.nativeConstructorTime=constructor_time
	var resources: Dictionary={str(data.model).to_lower():true}
	if not manager.ensure_models(resources): return false
	for name in resources:
		if not str(manager.bundles[name].get("error","")).is_empty(): manager.diagnose("projectile.model-unavailable",name,0); stats.failed+=1; return true
	receiving={"event":event_data,"header":header,"received":received,"constructorTime":event_data.nativeConstructorTime}; Ranged.receive(header,p,event_data.nativeRangedStart)
	if not str(receiving.get("failure","")).is_empty():
		stats.failed+=1
		manager.diagnose("visual.projectile-receiver-failed",str(receiving.failure),0,{"header":header.duplicate(true)})
	receiving.clear(); return true
func construct_procedural() -> Dictionary:
	var now:Dictionary=native_world_time()
	if now.is_empty():return {}
	var s:Dictionary=State.constructor_state(now)
	s.merge({"resource":"","targetId":State.INVALID,"sourceId":State.INVALID,"token":0,"binding":[],"ready":false},true)
	var allocation:Dictionary=manager.client_dummies.allocate(false,8,s)
	if allocation.is_empty():stats.overflow+=1;return {}
	s.token=int(allocation.token);active[int(s.id)]=s;stats.spawned+=1
	return s
func construct_prepared_procedural(prepared: Dictionary) -> Dictionary:
	var s:=construct_procedural()
	if not s.is_empty():
		s.type10MainReady=bool(prepared.get("main",false))
		s.type10AuxReady=bool(prepared.get("auxiliary",false))
	return s
func procedural_model(s: Dictionary,name: String,_flags: int,_mode: int) -> int:
	# CResRef keeps authored spelling; the asset index owns case folding.
	# A failed per-program factory remains absent even if another visual later
	# fills the world-wide bundle cache for the same resource.
	if s.has("type10MainReady") and not bool(s.type10MainReady):return 0
	var lookup_name:=name.to_lower()
	if not manager.bundles.has(lookup_name):return 0
	s.resource=name;s.resourceName=name;s.model=manager.create_model(int(s.id),lookup_name,false)
	if s.model==null:
		stats.failed+=1;manager.diagnose("visual.procedural-projectile-model-failed","Native procedural projectile model could not be created",int(s.id),{"resource":name})
		return 0
	s.model.set_meta("resource_name",name)
	manager.client_dummies.entries[int(s.id)].model=s.model
	stats.loaded+=1;event("loaded",s,{"resource":name})
	return 1
func procedural_spell(s: Dictionary,id: int) -> void:
	var spell:Dictionary=Spell.prepare(table,id)
	if spell.is_empty() or spell.has("error"):return
	s.spellId=id;s.loopSound=spell.projectileSound;s.impactSound=spell.projectileSound;s.faceCamera=0;s.facing=int(spell.facing)&255
func procedural_path(s: Dictionary,path: int) -> void:
	if path in [8,11,12,13]:
		s.path=path;s.procedural_error="Native projectile path builder %d is unavailable"%path
		return
	State.configure_path(s,path,p)
	if bool(s.get("destroyed",false)):
		s.procedural_error=str(s.get("nativeFailure","Native projectile path initialization failed"))
		return
	s.ready=true
	event("ready",s,{"position":s.position.duplicate(),"endpoint":s.endpoint.duplicate(),"path":int(s.path)})
func start_procedural(effect: Dictionary,program_id: int,program: Dictionary,prepared: Dictionary) -> Dictionary:
	if closed:return {"projectile":null}
	stats.proceduralReceived=int(stats.get("proceduralReceived",0))+1
	var provider:Dictionary={"clientObject":object_view,"renderObject":func(object):return object if object!=null and model_view(object)!=null else null,
		"programString":func(_id,column):return program.get("string",{}).get(column,{"found":false,"value":""}),
		"programInt":func(_id,column):return program.get("integer",{}).get(column,{"found":false,"value":0}),
		"constructProjectile":construct_prepared_procedural.bind(prepared),"configureSpell":procedural_spell,"loadProjectileModel":procedural_model,"destroyProjectile":destroy,
		"sourceModel":model_view,"sourceNodePose":node_pose,"projectilePosition":set_position,"projectileOrientation":orient,
		"partQueryFailure":take_part_query_failure,
		"controlledClient":func():return {"videoF8":{"gui248":manager}},"projectileScene":func(s,_scene):projectile_scene(s,1),
		"projectileStage":set_stage,"projectileTarget":set_target,"projectileTime":func(s,time):s.remaining=time&0xffffffff;s.totalTime=s.remaining,
		"projectilePath":procedural_path}
	var result:Dictionary=VisualType10.start(effect,program_id,provider)
	if result.get("projectile") is Dictionary and result.projectile.has("procedural_error"): result={"error":str(result.projectile.procedural_error),"projectile":result.projectile}
	if result.has("error"):
		if result.get("projectile") is Dictionary and not bool(result.projectile.get("destroyed",false)):destroy(result.projectile)
		stats.failed+=1;manager.diagnose("visual.procedural-projectile-start-failed",str(result.error),int(effect.get("target54",0)),{"programId":program_id,"sourceId":int(effect.get("source58",State.INVALID)),"targetId":int(effect.get("target54",State.INVALID))})
	elif result.get("projectile") is Dictionary:
		var projectile:Dictionary=result.projectile
		event("procedural",projectile,{"programId":program_id,"visualId":int(effect.get("visualF8",0)),"sourceId":int(effect.get("source58",State.INVALID)),"targetId":int(effect.get("target54",State.INVALID))})
	return result
func create_spell_shot(event_data: Dictionary,received: int,header: Dictionary,spell: Dictionary,path: int,target_id: int,launch: Array,direction: Array,constructor_time: Dictionary) -> bool:
	var s:Dictionary=State.constructor_state(constructor_time)
	s.merge({"resource":spell.model,"targetId":target_id,"sourceId":int(header.sourceId),"spellId":int(header.spellId),"endpoint":M.values(header.to),"remaining":int(header.duration),"totalTime":int(header.duration),"loopSound":spell.projectileSound,"impactSound":spell.projectileSound,"facing":int(spell.facing),"binding":[]},true)
	var allocation:Dictionary=manager.client_dummies.allocate(false,8,s)
	if allocation.is_empty(): stats.overflow+=1; return false
	s.token=int(allocation.token)
	active[int(s.id)]=s; stats.spawned+=1
	var model=manager.create_model(int(s.id),str(spell.model),false)
	if model==null:
		destroy(s);stats.failed+=1
		manager.diagnose("visual.projectile-model-failed","Native projectile model could not be created",int(s.id),{"id":int(s.id),"resource":str(spell.model)})
		return false
	if closed or bool(s.destroyed):
		manager.release_model(model)
		if not bool(s.destroyed):destroy(s)
		return false
	if admissible(event_data,received)<0:
		reject_loaded_model(s,model,header)
		return false
	s.model=model; s.resourceName=str(spell.model); allocation.model=model; stats.loaded+=1; event("loaded",s,{"resource":spell.model})
	set_position(s,launch)
	var admitted_target:Variant=canonical_lifetime(target_id) if target_id==int(header.targetId) else null
	s.targetLifetime=int(admitted_target) if admitted_target!=null else 0
	if path!=7: orient(s,direction)
	# Receiver7ac670 publishes the posed model before stage, target and path
	# initialization. Ranged and procedural shots use their own setScene hooks.
	if not projectile_scene(s,1):
		fail_projectile(s,"Native projectile scene publication failed")
		return false
	set_stage(s,1)
	var target:Variant=object_view(target_id)
	if target!=null and int(target.objectType) in [9,10]:
		var prefix:Dictionary=Query.prefix(manager.descriptor(target_id),int(target.objectType))
		if prefix.has("error"):
			manager.diagnose("projectile.target-prefix-unavailable",str(prefix.error),target_id)
			destroy(s); stats.failed+=1
			return false
		s.impactNode=str(prefix.value)+("_impact" if int(target.objectType)==9 else "impc")
	if path in [8,11,12,13]:
		s.path=path; destroy(s); report_path_failure(header,path)
		return false
	State.configure_path(s,path,p)
	if bool(s.get("destroyed",false)):return false
	s.ready=true
	event("ready",s,{"duration":int(header.duration),"preparationMs":Time.get_ticks_msec()-received,"sourceLifetime":int(event_data.get("sourceLifetime",0)),"targetLifetime":int(s.targetLifetime)})
	return true
func prepare(event_data: Dictionary,received: int) -> bool:
	var header: Dictionary=event_data.message.header
	var dummy_status:int=prepare_target_dummy(event_data)
	if dummy_status==0: return false
	if dummy_status<0: return true
	if int(header.appearance) not in [6,7]: return prepare_ranged(event_data,received)
	if table.is_empty(): return false
	var spell:=Spell.prepare(table,int(header.spellId))
	if spell.is_empty(): manager.diagnose("projectile.spell-unavailable",str(header.spellId),0); stats.failed+=1; return true
	if spell.has("error"): manager.diagnose("visual.projectile-receiver-failed",str(spell.error),0); stats.failed+=1; return true
	var source: Variant=object_view(int(header.sourceId))
	# Original 7ac670 releases caster visuals and sound before the Proj gate.
	# Worker retries must not replay either operation for one received packet.
	if not event_data.get("nativeCastReleased",false):
		if source!=null and int(source.objectType)==5 and manager.casts!=null: manager.casts.release(source,[spell.castHead,spell.castHand,spell.castGround],received)
		var launch:Array=M.values(header.from); launch[2]=M.f(launch[2]+1)
		if source!=null and model_view(source)!=null:
			var anchor:String="handconjure" if int(spell.spawn)==1 else "headconjure" if int(spell.spawn)==2 else "monster"+str(int(spell.spawn)-3) if int(spell.spawn)>=3 and int(spell.spawn)<=12 else "root"
			if node_pose(model_view(source),anchor,launch,[1,0,0,0])<0:
				manager.diagnose("visual.projectile-receiver-failed",take_part_query_failure(),int(header.sourceId))
				stats.failed+=1
				return true
		event_data.nativeLaunch=M.values(launch)
		if not str(spell.castSound).is_empty(): manager.world_audio.one_shot(spell.castSound,source.position if source!=null else header.from,1.5,11)
		event_data.nativeCastReleased=true
	var path:=int(spell.projectilePath) if int(header.appearance)==6 else int(header.path)&255
	if int(spell.useProjectile)==0: return true
	if not event_data.has("nativeConstructorTime"):
		var delta:Array=M.subtract(M.values(header.to),M.values(header.from))
		var length:float=M.f(sqrt(State.square(delta)))
		event_data.nativeDirection=p.shortDirection.call(header) if length<=M.f(0.001) else M.normalize(delta)
		var constructor_time:Dictionary=native_world_time()
		if constructor_time.is_empty(): return false
		event_data.nativeConstructorTime=constructor_time
	var resources: Dictionary={spell.model:true}
	# The receiver resolved this ID before model preparation began.
	var missing_target: bool=event_data.has("nativeDummyResult")
	if path in [7,10]: resources.ref=true
	if not manager.ensure_models(resources): return false
	for name in resources:
		if not str(manager.bundles[name].get("error","")).is_empty(): manager.diagnose("projectile.model-unavailable",name,0); stats.failed+=1; return true
	var target_id:=int(header.targetId)
	if missing_target: target_id=int(event_data.nativeDummyResult.targetId)
	var direction:Array=event_data.nativeDirection
	var launch:Array=M.values(event_data.nativeLaunch)
	if create_spell_shot(event_data,received,header,spell,path,target_id,launch,direction,event_data.nativeConstructorTime) and path==4:
		for shot_index in 4:
			var shot_time:Dictionary=native_world_time()
			if shot_time.is_empty(): break
			create_spell_shot(event_data,received,header,spell,path,target_id,launch,direction,shot_time)
	return true
func destroy(s: Dictionary) -> void:
	if s.destroyed: return
	s.destroyed=true; event("destroy",s); active.erase(int(s.id))
	var target:=int(s.get("trackingTarget",State.INVALID))
	if tracking.has(target):
		tracking[target].erase(int(s.id))
		if tracking[target].is_empty(): tracking.erase(target)
	if s.sound!=null: destroy_loop_sound(int(s.sound)); s.sound=null
	if is_instance_valid(s.auxiliaryModel):
		if s.auxiliaryModel.get_parent()!=null:s.auxiliaryModel.get_parent().remove_child(s.auxiliaryModel)
		manager.release_model(s.auxiliaryModel)
	s.auxiliaryModel=null; s.model=null; s.nodes.clear(); s.node=null; manager.client_dummies.remove(int(s.id)); stats.retired+=1; stats.destroyed+=1
func _process(delta: float) -> void:
	var began:=Timing.begin(); advance(delta); Timing.finish("callback_projectiles",began)
func advance(_delta: float) -> void:
	if closed: return
	prefetch_equipment()
	var now:Dictionary=native_world_time()
	if now.is_empty(): return
	var waiting: Array=[]; var started:=0
	for entry in queue:
		var admitted:=admissible(entry.event,int(entry.received))
		if admitted<0:
			stats.stale+=1
			var header:Dictionary=entry.event.message.header
			manager.diagnose("visual.projectile-target-stale","Projectile source or target changed during asset loading",int(header.targetId),{"sourceId":int(header.sourceId),"targetId":int(header.targetId)})
		elif admitted==0 or started>=2: waiting.append(entry)
		elif not prepare(entry.event,int(entry.received)): waiting.append(entry)
		else: started+=1
	queue=waiting
	for s in active.values().duplicate():
		if not bool(s.get("ready",false)) or bool(s.destroyed): continue
		if int(s.get("trackedByTarget",0))==1 and not manager.world.desired.has(int(s.targetId)): destroy(s); continue
		if int(s.targetLifetime)>0 and manager.world.desired.has(int(s.targetId)) and int(manager.world.desired[int(s.targetId)].object.get("nativeLifetime",0))!=int(s.targetLifetime): stats.stale+=1; destroy(s); continue
		if int(s.path)==7 and int(s.phase)==0:
			bind_references(s)
			if bool(s.destroyed):continue
		current_update_state=s
		State.update(s,now,p)
		current_update_state={}
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"pending":queue.size(),"active":active.size(),"tracking":tracking.duplicate(true),"preload_models":preload_models.keys(),"events":history.duplicate(true),"scope":"Native common spell, ordinary ballistic, sling bounce and deflection projectiles; complete static BSP/registration, real shield blocks, random/burst/cast release/impact effects/options/paused clock and mixed-client parity remain pending"}
func client_snapshot() -> Dictionary:
	# Old ClientProjectilePresentation.snapshot, consumed by the network scene's
	# periodic diagnostics. Keep this shape distinct from the Godot owner report.
	var result: Dictionary={}
	for key in ["received","spawned","loaded","impacts","destroyed","failed"]:result[key]=int(stats.get(key,0))
	for key in ["soundCreated","soundPlayRequests","soundStopped","soundDestroyed"]:
		if stats.has(key):result[key]=int(stats[key])
	var current: Array=[]
	for s in active.values():
		current.append({"id":int(s.id),"ready":bool(s.get("ready",false)),"stage":int(s.stage),"path":int(s.path),"remaining":int(s.remaining),"resource":str(s.get("resourceName",s.get("resource",""))),"position":s.position.duplicate(),"targetId":int(s.targetId),"impactNode":str(s.get("impactNode",""))})
	result.active=current
	result.events=adapter_events.duplicate(true)
	result.casts=manager.casts.client_snapshot() if manager.casts!=null else {}
	result.dummies=manager.client_dummies.snapshot() if is_instance_valid(manager.client_dummies) else {}
	return result
func detach_prepared_data() -> Dictionary:
	var payload:={"table":table.duplicate(),"ranged_tables":ranged_tables.duplicate()}
	table={}; ranged_tables={}; return payload
func close() -> void:
	if closed: return
	closed=true; set_process(false); queue.clear()
	for s in active.values().duplicate(): destroy(s)
	p.clear(); impact_providers.clear(); table.clear(); ranged_tables.clear(); receiving.clear(); tracking.clear(); preload_models.clear()
func _exit_tree() -> void: close()
