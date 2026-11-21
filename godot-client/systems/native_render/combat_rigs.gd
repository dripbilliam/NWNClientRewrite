extends Node
# One facade over private per-creature rig owners. Retains the existing native
# selector/queue/event contracts without copying models into a second renderer.
signal animation_event(id: int,name: String,serial: int)
var entities: Dictionary={}
var targets: Dictionary={}
var listeners: Dictionary={}
func attach(id: int,rigs) -> void:
	if targets.get(id)==rigs: return
	forget(id); targets[id]=rigs; entities[id]=rigs.entities[id]
	var listener:=func(actor: int,event: String,serial: int):
		if actor==id and targets.get(id)==rigs: animation_event.emit(id,event,serial)
	listeners[id]=listener; rigs.animation_event.connect(listener)
func forget(id: int) -> void:
	var rigs=targets.get(id)
	if is_instance_valid(rigs) and listeners.has(id) and rigs.animation_event.is_connected(listeners[id]): rigs.animation_event.disconnect(listeners[id])
	entities.erase(id); targets.erase(id); listeners.erase(id)
func clip_length(id: int,animation: int,side: int=-1) -> float:
	return targets[id].clip_length(id,animation,side) if targets.has(id) else 0.0
func clip_name(id: int,animation: int,side: int=-1) -> String:
	return targets[id].clip_name(id,animation,side) if targets.has(id) else ""
func set_animation(id: int,animation: int,speed: float=1.0) -> void:
	if targets.has(id): targets[id].set_animation(id,animation,speed)
func set_playback(id: int,animation: int,speed: float,loop: bool,restart: bool,side: int) -> void:
	if targets.has(id): targets[id].set_playback(id,animation,speed,loop,restart,side)
func close() -> void:
	for id in targets.keys(): forget(id)
func _exit_tree() -> void: close()
