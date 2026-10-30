extends Node
# Native private projectile ownership. Server packets decide spell, target,
# result and travel time; this owner never computes damage or sends outcomes.
const State=preload("res://systems/native_data/projectile_state.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Ranged=preload("res://systems/native_data/projectile_ranged.gd")
const Impact=preload("res://systems/native_data/projectile_impact.gd")
const Orientation=preload("res://systems/native_data/projectile_orientation.gd")
const Parts=preload("res://systems/native_data/model_random_part.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const SceneQuery=preload("res://systems/native_render/projectile_scene.gd")
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
var impact_actor_id:=State.INVALID
var preload_signature:=""
var preload_models: Dictionary={}
var closed:=false
var stats:={"received":0,"spawned":0,"impacts":0,"retired":0,"stale":0,"failed":0,"overflow":0,"scene_queries":0,"scene_hits":0,"scene_query_us_total":0,"scene_query_us_max":0}
func configure(owner) -> void:
	manager=owner; process_priority=50
	for name in ["spells","baseitems","ammunitiontypes"]:
		var job: int=manager.assets.request(name,2017,"2da"); manager.jobs[job]={"kind":"projectile-table","name":name}
	var audio=manager.world_audio
	p={"getObject":func(id):
		var object: Variant=object_view(id); return {"status":0 if object!=null else 1,"object":object},
		"clientObject":object_view,"model":model_view,"nodePose":node_pose,"allocateNode":func(_n):pass,"destroyNode":func(_n):pass,
		"buildPath":func(s,path):State.build_path(s,path,p),"initializeNode":func(s,orientation):State.initialize_node(s,orientation,p),"nextNode":func(s):return State.next_node(s,p),"updatePath":func(s):State.update_path(s,p),
		"basicMotion":func(s):move(s,"basic"),"spiralMotion":func(s):move(s,"spiral"),"initializeSpecial":linked,"unsupported":unsupported,"random":func():return manager.world.get_meta("native_particle_random").next(),
		"setPosition":set_position,"setStage":func(s,value):var result:=State.stage(s,value,p); event("stage",s,{"stage":value}); return result,"getStage":func(s):return s.stage,
		"animateExternal":func(model,_delta):
			if is_instance_valid(model): model.rigs.advance_external(1.0) if model.rigs.has_method("advance_external") else unsupported("projectile.external-animation",1),
		"spawnNodeChildren":func(_s,n):unsupported("projectile.child-spawn",int(n.childPath)),
		"playAnimation":func(model,name,speed,flags,time):
			if is_instance_valid(model) and not model.play_effect_clip(name,speed,flags,time): manager.diagnose("projectile.clip-unavailable",str(name),0),
		"difference":func(a,b):return {"time":(int(a.time)-int(b.time))&0xffffffff},"camera":func():return manager.get_viewport().get_camera_3d(),"faceCamera":func(_s,_camera):unsupported("projectile.camera-facing",1),
		"createSound":func(name):var id: int=audio.create_sound(name); return id if id>=0 else null,"destroySound":audio.destroy,"stopSound":audio.stop,"playSound":audio.play,
		"soundPriority":func(id,value):audio.setting(id,"setting1401da060",value),"sound3d":func(id,value):audio.setting(id,"setting1401d9e90",value),"soundLooping":func(id,value):audio.setting(id,"setting1401d9f90",value),"updateSound":audio.move,
		"oneShot":func(name,position,priority,height):audio.one_shot(name,position,height,priority),"attachImpact":impact,"setScene":func(s,on):if is_instance_valid(s.model):s.model.visible=on!=0,"destroy":destroy}
	p.merge({"worldTime":func():return {"time":Time.get_ticks_msec()},"register":register_ranged,"registerAI":func(_s):pass,"object":ranged_object,
		"sceneAvailable":func():return true,"trace":scene_trace,
		"rangedMetadata":func(base,appearance):return Ranged.metadata(ranged_tables,base,appearance),"shortDirection":func(_h):return [1.0,0.0,0.0],
		"appearance":func(o):return int(o.get("appearance",{}).get("appearance",65535)),"modelType":func(id):return Query.query(manager.tables.appearance,id,"modeltype","string").value,
		"weaponScale":func(id):return Query.query(manager.tables.appearance,id,"weaponscale","float"),"hitPartsEnabled":func():return 1,"modelHandle":func(o):return model_view(o),
		"randomImpactPart":random_impact_part,"loadModel":load_ranged,"modelScale":func(model,value,_flags):model.scale=Vector3.ONE*value,
		"defaultMaterial":func(_s):pass, # Original loaded DEFAULT material remains selected.
		"setTarget":set_target,"trackProjectile":track_projectile,"setOrientation":orient,"configurePath":func(s,path):State.configure_path(s,path,p),"ready":ready_ranged})
	impact_providers={"getObject":p.getObject,"modelHandle":p.modelHandle,"field28":func(o):return int(o.get("nativeField28",0)),"model":model_view,
		"creature":func(o):return o if int(o.objectType)==5 else null,"equipped":equipped_id,"item":item_view,"weaponWield":func(item):return int(Query.query(ranged_tables.baseitems,int(item.baseItem),"WeaponWield","integer").value)&255,
		"itemModel":func(item,_part,_flags):return {"actor":item.equipmentActor,"slot":item.equipmentSlot},"random":p.random,"attach":attach_impact,
		"nodePose":local_node_pose,"setNodePose":func(model,part,position,q):model.set_part_local_pose(part,position,q),"impactQuaternion":Orientation.impact,"rangedImpact":ranged_impact}
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
				if not data.is_empty() and int(data.ammunition) in [1,2,3,4,5,6] and preload_models.size()<64: preload_models[data.model]=true
	# Only the controlled equipment signature is observed. Never scan scenery or
	# other creatures every frame, and never publish GPU instances while warming.
	if not preload_models.is_empty(): manager.ensure_models(preload_models)
func ranged_object(id: int) -> Variant:
	if not receiving.is_empty() and id==int(receiving.event.message.header.sourceId) and int(receiving.event.get("sourceLifetime",0))==0: return null
	return object_view(id)
func register_ranged(s: Dictionary) -> void:
	var allocation: Dictionary=manager.client_dummies.allocate(false,8)
	s.targetId=int(receiving.header.targetId); s.sourceId=int(receiving.header.sourceId); s.resource=""; s.binding=[]; s.token=0; s.targetLifetime=0; s.ranged=true
	if allocation.is_empty(): stats.overflow+=1; return
	s.id=int(allocation.id); s.token=int(allocation.token); active[s.id]=s; stats.spawned+=1
func load_ranged(s: Dictionary,resource: String,_path: int) -> int:
	if int(s.id)==State.INVALID: return 0
	s.resource=resource; s.model=manager.create_model(int(s.id),resource)
	if s.model==null: stats.failed+=1; return 0
	manager.client_dummies.entries[int(s.id)].model=s.model; return 1
func ready_ranged(s: Dictionary) -> void:
	s.lastTime.time=int(receiving.received); s.targetLifetime=int(receiving.event.lifetime) if int(s.targetId)==int(receiving.event.id) else 0
	event("ready",s,{"duration":int(receiving.header.duration),"preparationMs":Time.get_ticks_msec()-int(receiving.received),"ranged":true,"packetResult":int(receiving.header.result),"baseItem":int(receiving.header.baseItem),"impactNode":s.impactNode})
func set_target(s: Dictionary,id: int,name: String) -> void:
	var target: Variant=object_view(id); s.impactNode=name if not name.is_empty() else "impact"; s.targetId=id
	if target!=null and int(target.objectType) in [9,10]: s.impactNode=Query.prefix(manager.descriptor(id,int(target.get("privateToken",0))),int(target.objectType))+("_impact" if int(target.objectType)==9 else "impc")
func random_impact_part(model) -> Variant:
	if not model.has_method("impact_model"): manager.diagnose("projectile.impact-parts-unavailable","Native physical model selector unavailable",0); return null
	var data: Dictionary=model.impact_model()
	if data.has("error"): manager.diagnose("projectile.impact-parts-unavailable",str(data.error),0); return null
	return Parts.choose(data,p.random)
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
	var node: Node3D=model.node_for(0,name)
	if node==null: return 0
	point.assign([node.position.x,-node.position.z,node.position.y]); q.assign([node.quaternion.w,node.quaternion.x,-node.quaternion.z,node.quaternion.y]); return 1
func attach_impact(model,anchor,part: String,_flags: int) -> bool:
	var node: Node3D=null
	if anchor is Dictionary:
		var actor=manager.host(int(anchor.actor))
		if actor!=null and actor.has_method("equipment_part"): node=actor.equipment_part(int(anchor.slot),part)
	elif anchor.has_method("physical_part"): node=anchor.physical_part(part)
	if node==null: model.detach(); return false
	return model.attach_to(node,0)
func ranged_impact(target: Dictionary,s: Dictionary) -> void:
	# Original AI983860 constructs a zeroed attack record, setting only result
	# (normal/critical) and WORD damage. Its weapon-attack selector stays zero.
	if manager.blood!=null: manager.blood.receive(int(target.id),{"result":3 if int(s.get("impactCritical",0))!=0 else 1,"damage":int(s.get("impactDamage",0))&65535,"attackType":0,"killingBlow":0,"weaponAttackType":0},M.subtract(s.position,s.previousPosition),str(s.impactNode),true)
	event("ranged-impact",s,{"actor":int(target.id),"critical":int(s.get("impactCritical",0))}); s.rangedEffect=0
func unsupported(code: String,value: int) -> void: manager.diagnose(code,"Native branch remains pending: "+str(value),0)
func event(kind: String,s: Dictionary,detail: Dictionary={}) -> void:
	if history.size()>=256: history.pop_front()
	var row:={"kind":kind,"id":int(s.id),"at":Time.get_ticks_msec(),"position":s.position.duplicate(),"targetId":int(s.targetId),"resource":s.resource,"path":int(s.path),"spellId":int(s.get("spellId",-1))}; row.merge(detail); history.append(row)
func receive(event_data: Dictionary) -> void:
	if closed: return
	if queue.size()>=128: stats.overflow+=1; return
	queue.append({"event":event_data.duplicate(true),"received":Time.get_ticks_msec()}); stats.received+=1
func object_view(id: int) -> Variant:
	var row: Variant=manager.object(id)
	if row==null and manager.client_dummies.entries.has(id): row=manager.client_dummies.entries[id].object
	if row==null: return null
	var result: Dictionary=row.duplicate(); var model=model_view(result)
	if is_instance_valid(model): result.position=[model.global_position.x,-model.global_position.z,model.global_position.y]
	else: result.position=row.get("replicated",{}).get("position",row.get("position",[0,0,0])).duplicate()
	return result
func model_view(object: Dictionary,_part: int=255,_flags: int=1) -> Variant:
	return object.model if object.has("model") else manager.host(int(object.id),int(object.get("privateToken",0)))
func node_pose(model: Node3D,name: String,point: Array,q: Array) -> int:
	var node: Node3D=null
	if model.has_method("physical_part"): node=model.physical_part(name)
	elif model.has_method("node_for"): node=model.node_for(0,name)
	elif model.get("rigs")!=null: node=model.rigs.node_for(int(model.object_id),0,name)
	else:
		for part in model.get("parts") if model.get("parts") is Array else []:
			if str(part.get_meta("native_part_name","" )).to_lower()==name.to_lower(): node=part; break
	if node==null: return 0
	var rotation:=node.global_basis.orthonormalized().get_rotation_quaternion()
	point.assign([M.f(node.global_position.x),M.f(-node.global_position.z),M.f(node.global_position.y)]); q.assign([rotation.w,rotation.x,-rotation.z,rotation.y]); return 1
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
	if result.has("error"): manager.diagnose("projectile.motion-unavailable",result.error,int(s.id)); return
	s.velocity=result.velocity
	if result.orientation!=null: orient(s,result.orientation)
	set_position(s,result.position)
func linked(s: Dictionary,_orientation: Array,_delta: Array,_time: float) -> void:
	s.velocity=[0.0,0.0,0.0]; s.acceleration=[0.0,0.0,0.0]
	if int(s.node.kind)!=7: unsupported("projectile.random-initialization",int(s.node.kind)); return
	bind_references(s)
func bind_references(s: Dictionary) -> void:
	var target: Variant=object_view(int(s.targetId)); var anchor: Node3D=null
	if target!=null:
		var target_model=model_view(target)
		if target_model==null: return
		anchor=manager.anchor(int(s.targetId),int(target.get("privateToken",0)),str(s.impactNode))
		if anchor==null: anchor=manager.anchor(int(s.targetId),int(target.get("privateToken",0)),"root")
	else:
		if s.auxiliaryModel==null:
			s.auxiliaryModel=manager.create_model(int(s.id),"ref")
			if s.auxiliaryModel!=null: s.auxiliaryModel.position=Vector3(s.node.point[0],s.node.point[2],-s.node.point[1])
		if is_instance_valid(s.auxiliaryModel): anchor=s.auxiliaryModel.node_for(0,"root")
	if anchor==null: return
	var signature: Array=[anchor.get_instance_id(),s.model.reference_binding_signature()]
	if signature==s.binding: return
	s.model.reattach_references(anchor); s.binding=[anchor.get_instance_id(),s.model.reference_binding_signature()]
func impact(s: Dictionary) -> void:
	impact_actor_id=int(s.targetId); Impact.attach(s,impact_providers); impact_actor_id=State.INVALID
	stats.impacts+=1; event("impact",s); s.remaining=int(s.impactDuration)&0xffffffff
func admissible(event_data: Dictionary,received: int) -> int:
	var packet: Dictionary=event_data.message.header
	for row in [[int(packet.sourceId),int(event_data.get("sourceLifetime",0))],[int(packet.targetId),int(event_data.lifetime)]]:
		if row[1]==0: continue
		if not manager.world.desired.has(row[0]): return -1 if Time.get_ticks_msec()-received>5000 else 0
		if int(manager.world.desired[row[0]].object.get("nativeLifetime",0))!=row[1]: return -1
	return 1
func prepare_ranged(event_data: Dictionary,received: int) -> bool:
	if ranged_tables.size()!=2 or not manager.tables.has("appearance"): return false
	var header: Dictionary=event_data.message.header.duplicate(true); var data:=Ranged.metadata(ranged_tables,int(header.baseItem),int(header.appearance))
	if data.is_empty(): manager.diagnose("projectile.ammunition-unavailable","No active ammunition model for base "+str(header.baseItem)+" / appearance "+str(header.appearance),0); stats.failed+=1; return true
	var missing: bool=int(header.targetId)!=State.INVALID and int(event_data.lifetime)==0
	var resources: Dictionary={data.model:true}
	if missing: resources.c_dummy=true
	if not manager.ensure_models(resources): return false
	for name in resources:
		if not str(manager.bundles[name].get("error","")).is_empty(): manager.diagnose("projectile.model-unavailable",name,0); stats.failed+=1; return true
	if missing:
		var dummy: Variant=manager.client_dummies.create("target",header.to,(int(header.duration)+500)&0xffffffff)
		if dummy==null: stats.failed+=1; return true
		header.targetId=int(dummy.id)
	receiving={"event":event_data,"header":header,"received":received}; Ranged.receive(header,p); receiving.clear(); return true
func prepare(event_data: Dictionary,received: int) -> bool:
	var header: Dictionary=event_data.message.header
	if int(header.appearance) not in [6,7]: return prepare_ranged(event_data,received)
	if table.is_empty(): return false
	var spell:=Spell.prepare(table,int(header.spellId))
	if spell.is_empty(): manager.diagnose("projectile.spell-unavailable",str(header.spellId),0); stats.failed+=1; return true
	var source: Variant=object_view(int(header.sourceId)) if int(event_data.get("sourceLifetime",0))>0 else null
	# Original 7ac670 releases caster visuals and sound before the Proj gate.
	# Worker retries must not replay either operation for one received packet.
	if not event_data.get("nativeCastReleased",false):
		event_data.nativeCastReleased=true
		if source!=null and int(source.objectType)==5 and manager.casts!=null: manager.casts.release(source,[spell.castHead,spell.castHand,spell.castGround],received)
		if not str(spell.castSound).is_empty(): manager.world_audio.one_shot(spell.castSound,source.position if source!=null else header.from,1.5,11)
	var path:=int(spell.projectilePath) if int(header.appearance)==6 else int(header.path)&255
	if int(spell.useProjectile)==0: return true
	if path not in [1,2,3,5,6,7]: unsupported("projectile.path-receiver",path); stats.failed+=1; return true
	var resources: Dictionary={spell.model:true}
	# Missing-at-receive stays a private target even if the real object appears
	# while worker data is pending. A late actor must not steal this projectile.
	var missing_target: bool=int(header.targetId)!=State.INVALID and int(event_data.lifetime)==0
	if missing_target: resources.c_dummy=true
	if path==7: resources.ref=true
	if not manager.ensure_models(resources): return false
	for name in resources:
		if not str(manager.bundles[name].get("error","")).is_empty(): manager.diagnose("projectile.model-unavailable",name,0); stats.failed+=1; return true
	var target_id:=int(header.targetId)
	if missing_target:
		var dummy: Variant=manager.client_dummies.create("target",header.to,(int(header.duration)+500)&0xffffffff)
		if dummy==null: stats.failed+=1; return true
		target_id=int(dummy.id)
	var allocation: Dictionary=manager.client_dummies.allocate(false,8)
	if allocation.is_empty(): stats.overflow+=1; return true
	var model=manager.create_model(int(allocation.id),str(spell.model))
	if model==null: manager.client_dummies.remove(int(allocation.id)); stats.failed+=1; return true
	allocation.model=model
	var launch:=M.values(header.from); launch[2]=M.f(launch[2]+1)
	if source!=null and model_view(source)!=null:
		var anchor: String="handconjure" if int(spell.spawn)==1 else "headconjure" if int(spell.spawn)==2 else "monster"+str(int(spell.spawn)-3) if int(spell.spawn)>=3 else "root"
		node_pose(model_view(source),anchor,launch,[1,0,0,0])
	var s:={"id":int(allocation.id),"token":int(allocation.token),"objectType":8,"resource":spell.model,"model":model,"targetId":target_id,"sourceId":int(header.sourceId),"spellId":int(header.spellId),"position":[0,0,0],"orientation":[0,0,0],"endpoint":M.values(header.to),"previousPosition":[0,0,0],"velocity":[0,0,0],"acceleration":[0,0,0],"nodes":[],"node":null,"stage":0,"lastTime":{"time":Time.get_ticks_msec()},"remaining":int(header.duration),"totalTime":int(header.duration),"elapsed":0,"tracked":1,"loopStarted":0,"phase":0,"faceCamera":0,"path":0,"attachOnImpact":1,"impactDuration":1,"sound":null,"loopSound":spell.projectileSound,"impactSound":spell.projectileSound,"result":0,"rangedEffect":0,"spiralSide":0,"facing":int(spell.facing),"impactNode":"impact","auxiliaryModel":null,"destroyed":false,"binding":[]}
	var target: Variant=object_view(target_id)
	if target!=null and int(target.objectType) in [9,10]: s.impactNode=preload("res://systems/native_data/visual_definition.gd").prefix(manager.descriptor(target_id),int(target.objectType))+("_impact" if int(target.objectType)==9 else "impc")
	active[s.id]=s; stats.spawned+=1; set_position(s,launch)
	s.targetLifetime=int(event_data.lifetime) if target_id==int(header.targetId) else 0
	# The original constructor snapshots its clock before LoadModel. Worker
	# preparation must not restart a server-timed projectile at zero elapsed.
	s.lastTime.time=received
	var direction:=M.normalize(M.subtract(M.values(header.to),M.values(header.from)))
	if path!=7: orient(s,direction)
	State.stage(s,1,p); State.configure_path(s,path,p); event("ready",s,{"duration":int(header.duration),"preparationMs":Time.get_ticks_msec()-received,"sourceLifetime":int(event_data.get("sourceLifetime",0)),"targetLifetime":int(event_data.lifetime)}); return true
func destroy(s: Dictionary) -> void:
	if s.destroyed: return
	s.destroyed=true; event("destroy",s); active.erase(int(s.id))
	var target:=int(s.get("trackingTarget",State.INVALID))
	if tracking.has(target):
		tracking[target].erase(int(s.id))
		if tracking[target].is_empty(): tracking.erase(target)
	if s.sound!=null: manager.world_audio.destroy(int(s.sound)); s.sound=null
	if is_instance_valid(s.auxiliaryModel): manager.release_model(s.auxiliaryModel)
	s.auxiliaryModel=null; s.model=null; s.nodes.clear(); s.node=null; manager.client_dummies.remove(int(s.id)); stats.retired+=1
func _process(delta: float) -> void:
	var began:=Timing.begin(); advance(delta); Timing.finish("callback_projectiles",began)
func advance(_delta: float) -> void:
	if closed: return
	prefetch_equipment()
	var waiting: Array=[]; var started:=0
	for entry in queue:
		var admitted:=admissible(entry.event,int(entry.received))
		if admitted<0: stats.stale+=1
		elif admitted==0 or started>=2: waiting.append(entry)
		elif not prepare(entry.event,int(entry.received)): waiting.append(entry)
		else: started+=1
	queue=waiting
	var now:={"time":Time.get_ticks_msec()}
	for s in active.values().duplicate():
		if int(s.get("trackedByTarget",0))==1 and not manager.world.desired.has(int(s.targetId)): destroy(s); continue
		if int(s.targetLifetime)>0 and manager.world.desired.has(int(s.targetId)) and int(manager.world.desired[int(s.targetId)].object.get("nativeLifetime",0))!=int(s.targetLifetime): stats.stale+=1; destroy(s); continue
		if int(s.path)==7 and int(s.phase)==0: bind_references(s)
		State.update(s,now,p)
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"pending":queue.size(),"active":active.size(),"tracking":tracking.duplicate(true),"preload_models":preload_models.keys(),"events":history.duplicate(true),"scope":"Native common spell, ordinary ballistic, sling bounce and deflection projectiles; complete static BSP/registration, real shield blocks, random/burst/cast release/impact effects/options/paused clock and mixed-client parity remain pending"}
func detach_prepared_data() -> Dictionary:
	var payload:={"table":table.duplicate(),"ranged_tables":ranged_tables.duplicate()}
	table={}; ranged_tables={}; return payload
func close() -> void:
	if closed: return
	closed=true; set_process(false); queue.clear()
	for s in active.values().duplicate(): destroy(s)
	p.clear(); impact_providers.clear(); table.clear(); ranged_tables.clear(); receiving.clear(); tracking.clear(); preload_models.clear()
func _exit_tree() -> void: close()
