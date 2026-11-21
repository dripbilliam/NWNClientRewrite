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
	# The body supplies hit events when it has clips. A clipless body keeps its
	# hierarchy, while the first animated robe/tail/wing supplies the clock.
	var source_index:=-1
	var models: Array=entities[id].get("models",[])
	for index in models.size():
		var model: Dictionary=models[index]
		if bool(model.get("follow",false)) and model.get("player")!=null:
			source_index=index
			break
	for index in models.size(): models[index].event_source=index==source_index
	entities[id].relay_animation_source=source_index
	if source_index>=0:
		var listener:=func(_owner: Variant,event: String,_data: Variant):
			if targets.get(id)==rigs and rigs.entities.has(id):
				var serial:=int(rigs.entities[id].models[source_index].get("play_serial",0))
				animation_event.emit(id,event,serial)
		listeners[id]={"index":source_index,"record":rigs.add_model_event_listener(id,source_index,"*",listener)}
func forget(id: int) -> void:
	var rigs=targets.get(id)
	if is_instance_valid(rigs) and listeners.has(id):
		var listener: Dictionary=listeners[id]
		rigs.remove_model_event_listener(id,int(listener.index),listener.record)
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
