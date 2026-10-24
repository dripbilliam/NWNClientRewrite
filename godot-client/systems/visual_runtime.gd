extends Node

const Phases = preload("res://systems/visual_phases.gd")
const Clock = preload("res://systems/visual_clock.gd")
const Beam = preload("res://systems/visual_beam.gd")
var manager
var effect_id := 0
var definition: Dictionary
var state: Dictionary
var phase
var clock
var models: Dictionary = {}
var closed := false
var beam_signature: Array = []

func configure(owner, id: int, data: Dictionary) -> bool:
	manager = owner
	effect_id = id
	definition = data
	state = data.state.duplicate(true)
	var handles := {}
	for index in 3:
		var row: Variant = state.models88[index]
		if row == null:
			continue
		if not handles.has(int(row.id)):
			handles[int(row.id)] = _new_model(str(row.resource))
		state.models88[index] = handles[int(row.id)]
	var p := {
		"clientObject": _view,
		"renderObject": func(view): return view,
		"playAnimation": _play,
		"animationInfo": func(model, clip): return {"length": model.clip_length(clip) if is_instance_valid(model) else 0.0},
		"programType": func(_effect, id): return _type(id),
		"loadProgram": _load_program,
		"clearProgram": _clear_program,
		"startProgram": _start_program,
		"stopProgram": _stop_program,
		"currentProgram": func(_effect): return current_program(),
		"updateProgram": func(_effect, id, _delta):
			if _type(id) in [5, 6]: _diagnose("visual.program-update-unimplemented", str(_type(id))),
		"detachProcedural": func(model, _a, _b, _c): _unparent(model),
		"unsceneProcedural": func(model, _scene): _unscene(model),
		"destroyProcedural": func(model, _flags): _destroy(model),
		"setParent": func(model, _parent, _name, _flags): _unparent(model),
		"setScene": func(model, _scene): _unscene(model),
		"destroyModel": func(model, _flags): _destroy(model),
		"destroyControllers": func(_controllers): pass,
		"detach": func(_effect): detach_models(),
		"visualString": func(_id, column): return definition.visual.string.get(column, {"found": false, "value": ""}),
		"visualInt": func(_id, column): return definition.visual.integer.get(column, {"found": false, "value": 0}),
		"visualFloat": func(_id, column): return definition.visual.float.get(column, {"found": false, "value": 0}),
		"controlledClient": func(): return manager.client,
		"shakeOnce": func(_client, _delay): _diagnose("visual.camera-shake-unimplemented", "once"),
		"shakeLoop": func(_client, _delay, _duration): _diagnose("visual.camera-shake-unimplemented", "loop"),
		"positionalSound": func(name, position, height, priority, delay, volume): manager.client.world_audio.one_shot(name,position,height,priority,delay,volume,effect_id),
		"createSound": func(name):return manager.client.world_audio.create_sound(name,effect_id),
		"soundSetting": func(sound, name, value): manager.client.world_audio.setting(sound,name,value),
		"playSound": func(sound): manager.client.world_audio.play(sound),
		"stopSound": func(sound): manager.client.world_audio.stop(sound),
		"destroySound": func(sound, _flags): manager.client.world_audio.destroy(sound),
		"updateSound": func(sound, position, _flags): manager.client.world_audio.move(sound,position),
	}
	phase = Phases.new(state, p)
	clock = Clock.new()
	add_child(clock)
	clock.configure(phase)
	clock.set_process(false) # The physical effect list advances clocks in order.
	return true

func _diagnose(code: String, detail: String) -> void:
	manager.diagnose(code, detail, effect_id)

func _new_model(resource: String):
	var model = manager.create_model(effect_id, resource)
	if model != null:
		models[model.get_instance_id()] = model
		model.visible = false
	return model

func _destroy(model) -> void:
	if not is_instance_valid(model):
		return
	var id: int = model.get_instance_id()
	if not models.has(id):
		return
	models.erase(id)
	manager.release_model(model)

func _unparent(model) -> void:
	if is_instance_valid(model):
		model.detach()

func _unscene(model) -> void:
	if is_instance_valid(model):
		model.visible = false

func _view(id: int) -> Variant:
	var row: Dictionary = definition.get("hosts", {}).get(str(id), {})
	var token := int(row.get("privateToken",0))
	var pivot: Node3D = manager.host(id,token)
	if pivot == null: return null
	var position: Vector3 = pivot.global_position
	return {"id": id, "privateToken":token, "type": int(row.get("type", 5)), "prefix": str(row.get("prefix", "")), "position38": [position.x, -position.z, position.y]}

func _anchor(view: Dictionary, name: String) -> Node3D:
	return manager.anchor(int(view.id),int(view.get("privateToken",0)),name)

func _attach(model, view: Dictionary, name: String, flags: int) -> void:
	if not is_instance_valid(model):
		return
	var anchor := _anchor(view, name)
	if anchor == null:
		model.detach()
		model.visible = false
		_diagnose("visual.native-anchor-unavailable", "%s/%s" % [view.id, name])
		return
	model.attach_to(anchor, flags)
	model.visible = true

func _slot_anchor(view: Dictionary, index: int) -> String:
	if view.type == 9:
		return view.prefix + ["_ground", "_impact", "_head_hit"][index]
	if view.type == 10:
		return view.prefix + ["grnd", "impc", "hhit"][index]
	return ["root", "impact", "head"][index]

func _geometry(view: Dictionary) -> void:
	for index in 3:
		var model = state.models88[index]
		if not is_instance_valid(model):
			continue
		_attach(model, view, _slot_anchor(view, index), 0 if state.orient120 else 3)
		if not state.orient120:
			model.reset_part_world_orientation("root")

func begin() -> void:
	clock.start()
	place_models()
	detach_models()

func place_models() -> void:
	if state.updateProgramD8:
		return
	var view: Variant = _view(int(state.target54))
	if view == null:
		return
	_geometry(view)
	if is_instance_valid(state.proceduralB8):
		_attach(state.proceduralB8, view, _slot_anchor(view, 0), 0)
	state.updateProgramD8 = 1
	state.attached114 = 1
	_start_program(state, current_program())
	_diagnose("visual.renderer-controller-parity-pending", "animated lights, depth/blend pipeline and specialized finalization pending")

func attach_models() -> void:
	var view: Variant = _view(int(state.target54))
	if view == null or _anchor(view, "root") == null:
		return
	state.attached114 = 1
	_geometry(view)
	var type := _type(current_program())
	if type == 4:
		_attach_type4(view)
	elif type == 7:
		_attach_beam()
	elif type in [1, 2, 3, 5, 6]:
		_diagnose("visual.program-attach-unimplemented", str(type))
	elif is_instance_valid(state.proceduralB8):
		_attach(state.proceduralB8, view, str(state.targetAnchor38), 0)

func detach_models() -> void:
	state.attached114 = 0
	for model in state.models88:
		_unparent(model)
		_unscene(model)
	_unparent(state.proceduralB8)
	_unscene(state.proceduralB8)

func current_program() -> int:
	var active := int(state.programPhaseFa) & 255
	return int(state.programsD0[active - 1]) & 65535 if active >= 1 and active <= 3 else 65535

func _program(id: int) -> Dictionary:
	return definition.programs.get(str(id & 65535), {})

func _type(id: int) -> int:
	return int(_program(id).get("type", {}).get("value", 0)) & 255

func _query(id: int, kind: String, column: String, fallback: Variant = 0) -> Variant:
	return _program(id).get(kind, {}).get(column, {}).get("value", fallback)

func _load_program(_effect: Dictionary, id: int) -> int:
	var type := _type(id)
	if type in [4, 7, 12]:
		var resource: Variant = _program(id).get("resource")
		state.proceduralB8 = _new_model(str(resource)) if resource != null else null
		return 1 if is_instance_valid(state.proceduralB8) else 0
	if type == 5:
		state.field104 = Phases.f32(float(_query(id, "float", "param1")))
	return 1

func _clear_program(_effect: Dictionary) -> void:
	beam_signature.clear()
	if is_instance_valid(state.proceduralB8):
		_unparent(state.proceduralB8)
		_unscene(state.proceduralB8)
		_destroy(state.proceduralB8)
	state.proceduralB8 = null

func _play(model, name: String, speed: float, flags: int, time: float) -> int:
	if not is_instance_valid(model):
		return 0
	var result: bool = model.play_effect_clip(name, speed, flags, time)
	if result and not model.playback_limitations.is_empty():
		_diagnose("visual.single-clip-profile", "original stacked runs/blend weights still pending")
	return 1 if result else 0

func _attach_type4(view: Dictionary) -> void:
	var model = state.proceduralB8
	if not is_instance_valid(model):
		return
	var name: String = "headconjure" if view.type == 5 else (view.prefix + "_head_hit" if view.type == 9 else (view.prefix + "hhit" if view.type == 10 else ""))
	var position := [0.0, 0.0, 0.0]
	var quaternion := [1.0, 0.0, 0.0, 0.0]
	if name != "":
		var node := _anchor(view, name)
		if node != null:
			position = [node.position.x, -node.position.z, node.position.y]
			quaternion = [node.quaternion.w, node.quaternion.x, -node.quaternion.z, node.quaternion.y]
		position[1] = Phases.f32(Phases.f32(position[1]) + (0.75 if view.type == 5 else 0.375))
		position[2] = Phases.f32(Phases.f32(position[2]) + (0.5 if view.type == 5 else 0.25))
	model.set_part_local_pose("root", position, quaternion)
	_attach(model, view, _slot_anchor(view, 0), 0)

func _start_program(_effect: Dictionary, id: int) -> void:
	if not state.updateProgramD8:
		return
	var type := _type(id)
	if type == 4 and is_instance_valid(state.proceduralB8):
		var view: Variant = _view(int(state.target54))
		if view == null:
			return
		state.field110 = int(_query(id, "integer", "param5"))
		state.scope10c = int(_query(id, "integer", "param4")) & 255
		state.shadow108 = 1 if int(_query(id, "integer", "param3")) != 0 else 0
		_attach_type4(view)
		_play(state.proceduralB8, str(_query(id, "string", "param1", "")), float(_query(id, "float", "param2")), 3, 0)
		if int(_query(id, "integer", "param6")):
			_diagnose("visual.selected-view-gui-unimplemented", "native view context registration pending")
	elif type == 7 and is_instance_valid(state.proceduralB8):
		Beam.start(state,id,_beam_providers())
		beam_signature = _beam_signature()
	elif type >= 1 and type <= 13:
		_diagnose("visual.program-start-unimplemented", str(type))

func _stop_program(_effect: Dictionary, id: int) -> void:
	if not state.updateProgramD8:
		return
	if _type(id) == 7:
		Beam.stop(state,_beam_providers());beam_signature.clear()
	elif _type(id) == 4:
		_unparent(state.proceduralB8)
		_unscene(state.proceduralB8)
	elif _type(id) >= 1 and _type(id) <= 13:
		_diagnose("visual.program-stop-unimplemented", str(_type(id)))

func _beam_providers() -> Dictionary:
	return {"clientObject":_view,"renderObject":func(view):return view,"modelHandle":func(view,_part,_mode):return view if _anchor(view,"root") != null else null,
		"setParent":func(model,parent,name,flags):
			if not is_instance_valid(model):return
			if parent == null:model.detach();return
			_attach(model,parent,str(name),int(flags)),
		"reattachReferences":func(model,target,name):
			if not is_instance_valid(model):return
			var anchor: Node3D = _anchor(target,name) if target != null else null
			if target != null and anchor == null:model.visible = false;_diagnose("visual.beam-target-anchor-unavailable",str(name));return
			if not model.reattach_references(anchor):model.visible = false;_diagnose("visual.beam-reference-graph-unavailable",str(name)),
		"programString":func(id,column):return _program(id).get("string",{}).get(column,{"found":false,"value":""}),"playAnimation":_play,"setScene":func(model,_scene):_unscene(model)}

func _beam_signature() -> Array:
	if not is_instance_valid(state.proceduralB8):return []
	var target = _view(int(state.target54));var source = _view(int(state.source58))
	if target == null or source == null:return []
	var from := _anchor(source,str(state.sourceAnchor28));var to := _anchor(target,str(state.targetAnchor38))
	if not is_instance_valid(from) or not is_instance_valid(to):return []
	return [state.proceduralB8.get_instance_id(),from.get_instance_id(),to.get_instance_id()]

func _attach_beam() -> void:
	Beam.attach(state,_beam_providers());beam_signature = _beam_signature()

func refresh_bindings() -> void:
	if not state.attached114 or _type(current_program()) != 7 or not is_instance_valid(state.proceduralB8):return
	var signature := _beam_signature()
	if signature.is_empty():
		state.proceduralB8.detach();state.proceduralB8.visible = false;beam_signature.clear();return
	if signature != beam_signature:_attach_beam()

func close() -> void:
	if closed:
		return
	closed = true
	if clock != null:
		clock.close()
	for model in models.values().duplicate():
		_destroy(model)
	models.clear()
	queue_free()
