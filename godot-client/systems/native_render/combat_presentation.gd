extends Node
const Combat=preload("res://systems/combat_animation.gd")
const Facade=preload("res://systems/native_render/combat_rigs.gd")
const Actor=preload("res://systems/native_data/combat_actor.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Sound=preload("res://systems/native_data/network_combat_sound.gd")
const WorldTimer=preload("res://systems/native_data/world_timer.gd")
const SOUND_TABLES=["weaponsounds","appearancesndset","defaultacsounds","baseitems","placeableobjsnds","placeables","genericdoors","doortypes","appearance"]
var engine:=Combat.new()
var rigs
var sound_owner
var combat_timer: Variant=null
var pending_sounds: Array=[]
var pending_failures: Array=[]
var sound_tables_failed:=false
var reported_sound_failures: Dictionary={}
var sound_provider_error: String=""
var pivots: Dictionary={}
var pending: Array=[]
var last_serial:=-1
var closed:=false
var stats:={"received":0,"delivered":0,"stale":0,"overflow":0,"model_replacements":0}
func _ready() -> void:
	rigs=Facade.new(); add_child(rigs); engine.configure(rigs,pivots)
	if not engine.presentation_failure.is_connected(combat_failure): engine.presentation_failure.connect(combat_failure)
func configure_sound(owner) -> void:
	# NetworkCombatPresentation received its tables and oneShot output from
	# the world. The Godot effect owner has the same table and audio services.
	sound_owner=owner
	# NetworkCombatPresentation constructs its own WorldTimer at the default
	# five-minute rate and never applies the module's minutes-per-hour value.
	engine.day_length=7200000
	if combat_timer==null:
		combat_timer=WorldTimer.new()
		var initialized: Dictionary=combat_timer.initialize(func():return Time.get_ticks_usec())
		var reset: Dictionary=combat_timer.set_time(0,0) if initialized.get("ready",false) else initialized
		if not reset.get("ready",false):sound_failure(0,"Native combat world timer is unavailable: "+str(reset.get("reason","unknown")))
	if owner.has_method("bind_combat_timer"):owner.bind_combat_timer(combat_timer)
	engine.object_lookup=combat_object
	var clock_runtime: Variant=null
	var tree_script: Script=get_tree().get_script()
	if tree_script!=null:
		for property in tree_script.get_script_property_list():
			if property.name=="native_clock_runtime":
				clock_runtime=get_tree().get("native_clock_runtime")
				break
	if clock_runtime!=null and clock_runtime.has_method("presentation_now"):
		engine.body_clock_ms=func(id):
			var actor: Variant=combat_object(int(id))
			if not actor is Dictionary:return null
			var sampled: Dictionary=clock_runtime.presentation_now(int(id),actor)
			return int(sampled.timeMs) if sampled.get("ready",false) else null
	if not engine.presentation_event.is_connected(sound_event): engine.presentation_event.connect(sound_event)
	for row in pending_failures: combat_failure(row)
	pending_failures.clear()
	for name in SOUND_TABLES:
		if owner.tables.has(name): continue
		var job: int=owner.assets.request(name,2017,"2da")
		if job>=0: owner.jobs[job]={"kind":"table","name":name}
		else: sound_failure(0,"Native combat sound table "+name+" is unavailable: "+str(owner.assets.failure))
func sound_failure(id: int,reason: String) -> void:
	var key: String=str(id)+":"+reason
	if reported_sound_failures.has(key): return
	reported_sound_failures[key]=true
	if is_instance_valid(sound_owner): sound_owner.diagnose("network.scene-combat-audio-unhandled",reason,id)
func combat_object(id: int) -> Variant:
	if not is_instance_valid(sound_owner):return null
	var world: Variant=sound_owner.world
	if world!=null and world.raw_object_lookup.is_valid():return world.raw_object_lookup.call(id)
	return sound_owner.object(id)
func combat_failure(value: Dictionary) -> void:
	if not is_instance_valid(sound_owner): pending_failures.append(value.duplicate()); return
	sound_owner.diagnose(str(value.code),str(value.reason),int(value.id))
func sound_tables_ready() -> bool:
	if not is_instance_valid(sound_owner): return false
	for name in SOUND_TABLES:
		if not sound_owner.tables.has(name): return false
	return true
func sound_tables_pending() -> bool:
	if not is_instance_valid(sound_owner): return false
	for job in sound_owner.jobs.values():
		if job is Dictionary and str(job.get("kind",""))=="table" and str(job.get("name","")) in SOUND_TABLES:return true
	return false
func sound_event(value: Dictionary) -> void:
	if closed or str(value.get("kind",""))!="sound" or not value.get("record") is Dictionary: return
	if not sound_tables_ready():
		if sound_tables_failed: sound_failure(int(value.id),"Native combat sound tables are unavailable")
		else: pending_sounds.append(value.duplicate(true))
		return
	select_sound(value)
func select_sound(value: Dictionary) -> void:
	var id:=int(value.id)
	var actor: Variant=combat_object(id)
	if not actor is Dictionary: return
	var phase:=int(value.phase)
	sound_provider_error=""
	var selected: Dictionary=Sound.select(actor,value.record,phase,sound_providers(phase))
	if not str(selected.get("error","")).is_empty(): sound_failure(id,str(selected.error))
func sound_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)
func sound_provider_failure(reason: String) -> void:
	if sound_provider_error.is_empty():sound_provider_error=reason
func sound_int(name: String,index: int,column: String) -> Dictionary:
	var table: Dictionary=sound_owner.tables.get(name,{})
	if table.is_empty(): sound_provider_failure("Native combat sound table "+name+" is unavailable"); return {"found":false,"value":0}
	var rows: Array=table.get("orderedRows",[])
	var row: Dictionary=rows[index] if index>=0 and index<rows.size() else {}
	var cell: Variant=Rules.cell(row,column)
	return {"found":cell!=null and str(cell) not in ["","****"],"value":Actor.integer(table,index,column)}
func sound_string(name: String,index: int,column: String) -> Dictionary:
	var table: Dictionary=sound_owner.tables.get(name,{})
	if table.is_empty(): sound_provider_failure("Native combat sound table "+name+" is unavailable"); return {"found":false,"value":""}
	var rows: Array=table.get("orderedRows",[])
	var row: Dictionary=rows[index] if index>=0 and index<rows.size() else {}
	var cell: Variant=Rules.cell(row,column)
	var value: String=str(table.get("defaultValue","")) if cell==null else str(cell)
	if value in ["","****"]: value=""
	return {"found":cell!=null and not value.is_empty(),"value":value}
func sound_equipped(actor: Dictionary,slot: Variant) -> Variant:
	if slot==null:return null
	var appearance: Variant=actor.get("appearance",{})
	if not appearance is Dictionary:return null
	for equipment in appearance.get("equipment",[]):
		if int(equipment.get("slot",-1))==int(slot):return equipment.get("item")
	return null
func sound_armor_index(item: Dictionary) -> int:
	if not sound_integer(item.get("field35c")):
		sound_provider_failure("Native replicated chest armor sound index is unavailable")
		return 0
	return int(item.field35c)
func sound_appearance(actor: Dictionary) -> int:
	var type:=int(actor.get("objectType",0))
	var appearance: Variant=null
	if type==5:
		var creature: Variant=actor.get("appearance")
		if creature is Dictionary: appearance=creature.get("appearance")
	else:
		for source_name in ["replicated","staticState","lightState"]:
			var source: Variant=actor.get(source_name)
			if source is Dictionary and source.get("appearance")!=null:
				appearance=source.appearance
				break
	if not sound_integer(appearance):sound_provider_failure("Native sound appearance index is unavailable");return 0
	return int(appearance)
func sound_animation(actor: Dictionary) -> int:
	var id:=int(actor.get("id",0))
	return int(engine.states[id].visual) if engine.states.has(id) else int(actor.get("replicated",{}).get("animation",0))
func sound_door_types(actor: Dictionary) -> Dictionary:
	var state_value: Variant=actor.get("replicated")
	var fixed_value: Variant=actor.get("staticState")
	if not fixed_value is Dictionary: fixed_value=actor.get("lightState")
	var state: Dictionary=state_value if state_value is Dictionary else {}
	var fixed: Dictionary=fixed_value if fixed_value is Dictionary else {}
	var door: Variant=state.get("doorType")
	var generic: Variant=state.get("genericType")
	if door==null:door=fixed.get("doorType")
	if generic==null:generic=fixed.get("genericType")
	if not sound_integer(door) or int(door)==0 and not sound_integer(generic):sound_provider_failure("Native door sound appearance is unavailable")
	return {"doorType":int(door) if sound_integer(door) else 0,"genericType":int(generic) if sound_integer(generic) else 0}
func sound_play(actor: Dictionary,res_ref: String,delay: int,phase: int) -> void:
	if not sound_provider_error.is_empty():return
	var id:=int(actor.get("id",0))
	engine.event("sound",id,{"resRef":res_ref,"delay":delay,"phase":phase})
	var position: Variant=null
	var host: Node3D=sound_owner.host(id)
	if is_instance_valid(host):
		var point: Vector3=host.global_position
		position=[point.x,-point.z,point.y]
	elif actor.get("position") is Array and actor.position.size()==3:
		position=actor.position.duplicate()
	else:
		for source_name in ["replicated","staticState","lightState","state"]:
			var source: Variant=actor.get(source_name)
			if source is Dictionary and source.get("position") is Array:
				position=source.position.duplicate();break
	if position==null: sound_failure(id,"Native combat sound source pose is unavailable"); return
	if sound_owner.world_audio.one_shot(res_ref,position,1.5,13,delay,0,0,id,"combat")<0:
		sound_failure(id,"Native combat one-shot audio output is unavailable")
func sound_providers(phase: int) -> Dictionary:
	return {
		"object":func(id):return combat_object(int(id)),
		"currentAnimation":func(actor):return sound_animation(actor),
		"animationCategory":func(_actor,animation):return int((int(animation)&65535) in [206,207,208,262]),
		"appearance":func(actor):return sound_appearance(actor),
		"int":func(name,id,column):return sound_int(str(name),int(id),str(column)),
		"string":func(name,id,column):return sound_string(str(name),int(id),str(column)),
		"equipped":func(actor,slot):return sound_equipped(actor,slot),
		"weaponMaterial":func(item):return int(sound_int("baseitems",int(item.get("baseItem",0)),"WeaponMatType").value)&255,
		"armorIndex":func(item):return sound_armor_index(item),
		"armorOverride":func(actor):return str(engine.states.get(int(actor.id),{}).get("armorOverride","")),
		"doorTypes":func(actor):return sound_door_types(actor),
		"providerError":func():return sound_provider_error,
		"random":func():return engine.selector.random(),
		"play":func(actor,res_ref,delay):sound_play(actor,str(res_ref),int(delay),phase)
	}
func sync(id: int,object: Dictionary,instance) -> void:
	if closed or not is_instance_valid(instance): return
	var object_type:=int(object.get("objectType",0))
	var metadata: Dictionary={}
	if instance.has_meta("native_combat_actor"):
		metadata=instance.get_meta("native_combat_actor").duplicate(true)
		Actor.refresh(metadata,object,engine.actors.get(id,{}))
	elif object_type in [9,10]:
		var replicated: Dictionary=object.get("replicated",{})
		metadata={"id":id,"lifetime":int(object.get("nativeLifetime",0)),"objectType":object_type,"base":int(replicated.get("animation",0)),"animationSpeed":float(replicated.get("animationSpeed",1.0))}
	else:return
	# Creature installations own a ModelRigs facade. Plain door/placeable
	# template placements have their own animation owner and no rigs field.
	if instance.has_meta("native_combat_actor"):
		if rigs.targets.get(id)!=instance.rigs:
			if rigs.targets.has(id):stats.model_replacements+=1
			engine.retire_state(id);rigs.attach(id,instance.rigs)
		if rigs.entities.has(id):
			rigs.entities[id].object_type=object_type
			if object_type==10:rigs.entities[id].destroyed_model=int(object.get("replicated",{}).get("destroyedModel",0))
	elif rigs.targets.has(id):
		stats.model_replacements+=1;engine.retire_state(id);rigs.forget(id)
	if pivots.has(id) and pivots[id]!=instance:engine.retire_state(id)
	if engine.actors.has(id) and int(engine.actors[id].lifetime)!=int(metadata.lifetime): engine.retire_state(id)
	pivots[id]=instance; engine.actors[id]=metadata
	if object_type in [9,10]:engine.observe_object_base(id,int(metadata.base),float(metadata.animationSpeed))
func forget(id: int,removed: bool=false) -> void:
	if is_instance_valid(rigs): rigs.forget(id)
	pivots.erase(id); engine.actors.erase(id); engine.retire_state(id)
	engine.pending=engine.pending.filter(func(entry):return int(entry.row.id)!=id)
	if removed: pending=pending.filter(func(entry):return int(entry.row.id)!=id)
func receive(message: Dictionary) -> void:
	if closed: return
	var serial:=int(message.get("serial",-1))
	if serial<=last_serial: stats.stale+=message.get("events",[]).size(); return
	last_serial=serial
	# The original network combat receiver runs every cast before attacks in
	# the same delivery, retaining source order within each event family.
	for action in ["cast-animation","attack-animation"]:
		for row in message.get("events",[]):
			if row.get("action","")!=action: continue
			if pending.size()>=512: stats.overflow+=1; continue
			pending.append({"row":row.duplicate(true),"received":Time.get_ticks_msec()}); stats.received+=1
func base_frame(id: int,animation: int,speed: float,remaining_path: Variant=null) -> void:
	if not closed:
		engine.base_frame(id,animation,speed,true,remaining_path)
func visual_animation(id: int,fallback: int) -> int:
	return int(engine.states[id].visual) if not closed and engine.states.has(id) else fallback
func movement_cue(id: int,request: Dictionary) -> bool:
	# Received server attack/cast work has priority over a local movement cue.
	if closed or pending.any(func(entry):return int(entry.row.id)==id) or engine.pending.any(func(entry):return int(entry.row.id)==id): return false
	return engine.movement_cue(id,request)
func update(delta: float,desired: Dictionary) -> void:
	if closed: return
	if combat_timer!=null:
		var sampled: Dictionary=combat_timer.snapshot()
		if not sampled.get("ready",false):sound_failure(0,"Native combat world timer snapshot is unavailable: "+str(sampled.get("reason","unknown")))
	# Old NetworkCombatPresentation starts with all rule tables already loaded.
	# Hold only combat delivery while those exact tables are being admitted;
	# this also preserves selector/audio cosmetic RNG order for first use.
	if not is_instance_valid(sound_owner): return
	if not sound_tables_ready() and not sound_tables_failed:
		if sound_tables_pending(): return
		sound_tables_failed=true
		sound_failure(0,"Native combat sound tables did not load")
	if sound_tables_ready() and not pending_sounds.is_empty():
		var waiting_sounds: Array=pending_sounds; pending_sounds=[]
		for cue in waiting_sounds: select_sound(cue)
	elif sound_tables_failed and not pending_sounds.is_empty():
		for cue in pending_sounds: sound_failure(int(cue.id),"Native combat sound tables are unavailable")
		pending_sounds.clear()
	var waiting: Array=[]; var ready: Array=[]; var now:=Time.get_ticks_msec()
	for entry in pending:
		var row: Dictionary=entry.row; var id:=int(row.id); var lifetime:=int(row.lifetime)
		if not desired.has(id): waiting.append(entry); continue
		var current:=int(desired[id].object.get("nativeLifetime",0))
		if current<lifetime: waiting.append(entry); continue
		if current!=lifetime: stats.stale+=1; continue
		if not engine.actors.has(id) or not rigs.targets.has(id) or int(engine.actors[id].lifetime)!=current: waiting.append(entry); continue
		row.ageMs=int(row.get("ageMs",0))+maxi(0,now-int(entry.received)); ready.append(row); stats.delivered+=1
	pending=waiting
	if not ready.is_empty(): engine.receive({"kind":"combat-events","events":ready})
	engine.update(delta)
func snapshot() -> Dictionary:
	var result:=engine.snapshot(); result.delivery=stats.duplicate(); result.pending_delivery=pending.size(); return result
func close() -> void:
	if closed: return
	closed=true
	if engine.presentation_event.is_connected(sound_event):engine.presentation_event.disconnect(sound_event)
	if engine.presentation_failure.is_connected(combat_failure):engine.presentation_failure.disconnect(combat_failure)
	engine.reset(); pending.clear(); pending_sounds.clear(); pending_failures.clear(); reported_sound_failures.clear(); pivots.clear(); sound_owner=null
	if combat_timer!=null:
		combat_timer.close()
		combat_timer=null
	if is_instance_valid(rigs): rigs.close()
func _exit_tree() -> void: close()
