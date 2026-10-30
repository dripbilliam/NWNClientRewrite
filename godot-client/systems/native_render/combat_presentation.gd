extends Node
const Combat=preload("res://systems/combat_animation.gd")
const Facade=preload("res://systems/native_render/combat_rigs.gd")
const Actor=preload("res://systems/native_data/combat_actor.gd")
var engine:=Combat.new()
var rigs
var pivots: Dictionary={}
var pending: Array=[]
var last_serial:=-1
var closed:=false
var stats:={"received":0,"delivered":0,"stale":0,"overflow":0,"model_replacements":0}
func _ready() -> void:
	rigs=Facade.new(); add_child(rigs); engine.configure(rigs,pivots)
func sync(id: int,object: Dictionary,instance) -> void:
	if closed or not is_instance_valid(instance) or not instance.has_meta("native_combat_actor"): return
	var metadata: Dictionary=instance.get_meta("native_combat_actor").duplicate(true); Actor.refresh(metadata,object)
	if rigs.targets.get(id)!=instance.rigs:
		if rigs.targets.has(id): stats.model_replacements+=1
		engine.states.erase(id); rigs.attach(id,instance.rigs)
	if engine.actors.has(id) and int(engine.actors[id].lifetime)!=int(metadata.lifetime): engine.states.erase(id)
	pivots[id]=instance; engine.actors[id]=metadata
func forget(id: int,removed: bool=false) -> void:
	if is_instance_valid(rigs): rigs.forget(id)
	pivots.erase(id); engine.actors.erase(id); engine.states.erase(id)
	engine.pending=engine.pending.filter(func(entry):return int(entry.row.id)!=id)
	if removed: pending=pending.filter(func(entry):return int(entry.row.id)!=id)
func receive(message: Dictionary) -> void:
	if closed: return
	var serial:=int(message.get("serial",-1))
	if serial<=last_serial: stats.stale+=message.get("events",[]).size(); return
	last_serial=serial
	for row in message.get("events",[]):
		if row.get("action","") not in ["cast-animation","attack-animation"]: continue
		if pending.size()>=512: stats.overflow+=1; continue
		pending.append({"row":row.duplicate(true),"received":Time.get_ticks_msec()}); stats.received+=1
func base_frame(id: int,animation: int,speed: float) -> void:
	if not closed: engine.base_frame(id,animation,speed)
func visual_animation(id: int,fallback: int) -> int:
	return int(engine.states[id].visual) if not closed and engine.states.has(id) else fallback
func movement_cue(id: int,request: Dictionary) -> bool:
	# Received server attack/cast work has priority over a local movement cue.
	if closed or pending.any(func(entry):return int(entry.row.id)==id) or engine.pending.any(func(entry):return int(entry.row.id)==id): return false
	return engine.movement_cue(id,request)
func update(delta: float,desired: Dictionary) -> void:
	if closed: return
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
	closed=true; engine.reset(); pending.clear(); pivots.clear()
	if is_instance_valid(rigs): rigs.close()
func _exit_tree() -> void: close()
