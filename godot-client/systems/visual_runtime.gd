extends Node

const Phases = preload("res://systems/visual_phases.gd")
const Clock = preload("res://systems/visual_clock.gd")
const Beam = preload("res://systems/visual_beam.gd")
const VisualNodePose=preload("res://systems/native_data/visual_node_pose.gd")
const VisualDefinition=preload("res://systems/native_data/visual_definition.gd")
var manager
var effect_id := 0
var definition: Dictionary
var state: Dictionary
var phase
var clock
var models: Dictionary = {}
var closed := false
var beam_signature: Array = []
var part_query_failure := ""

func take_part_query_failure() -> String:
	var result:=part_query_failure
	part_query_failure=""
	return result

func _part_query_error() -> Dictionary:
	if part_query_failure.is_empty():
		part_query_failure="Visual main model requires a single physical root part"
	return {"error":part_query_failure}

func _effect_part(model, name: String) -> Dictionary:
	if not is_instance_valid(model):return {"node":null}
	if not model.has_method("physical_root_count") or int(model.physical_root_count())!=1:
		return _part_query_error()
	return {"node":model.node_for(0,name)}

func _host_part(view: Dictionary, name: String) -> Dictionary:
	var id:=int(view.id)
	var token:=int(view.get("privateToken",0))
	var host_model=manager.host(id,token)
	if not is_instance_valid(host_model):return {"node":null}
	var roots:=0
	if host_model.has_method("physical_root_count"):
		roots=int(host_model.physical_root_count())
	else:
		var rigs=host_model.get("rigs")
		if is_instance_valid(rigs):
			if not rigs.entities.has(id):return {"node":null}
			var rig: Dictionary=rigs.entities[id]
			if rig.model_parts.is_empty():return {"node":null}
			var parts: Array=rig.model_parts[0]
			for index in parts:
				if not parts.has(int(rig.parents[int(index)])):roots+=1
		else:
			var parts: Variant=host_model.get("parts")
			if parts is Array:
				for part in parts:
					if is_instance_valid(part) and not parts.has(part.get_parent()):roots+=1
			else:
				# The non-rig world root is itself the single physical part.
				roots=1
	if roots!=1:return _part_query_error()
	return {"node":_anchor(view,name)}

func configure(owner, id: int, data: Dictionary) -> bool:
	manager = owner
	effect_id = id
	definition = data
	state = data.state.duplicate(true)
	var handles := {}
	var prepared_models: Dictionary=data.get("prepared_models",{})
	for index in 3:
		var row: Variant = state.models88[index]
		if row == null:
			continue
		if not handles.has(int(row.id)):
			var prepared: Variant=prepared_models.get(index)
			if is_instance_valid(prepared):
				handles[int(row.id)]=prepared
				models[prepared.get_instance_id()]=prepared
				prepared.visible=false
			else:handles[int(row.id)] = _new_model(str(row.resource))
		var model = handles[int(row.id)]
		state.models88[index] = model
		if is_instance_valid(model):
			# LoadVisualEffect assigns all three ordinary node models priority 3.
			for light in model.find_children("*", "OmniLight3D", true, false):
				light.set_meta("native_light_priority", 3)
			state.retiredDc[index] = 0
		else:
			state.retiredDc[index] = 1
			_diagnose("visual.native-model-warning", "CNWCVisualEffectOnObject::LoadVisualEffect: Failed to load %s node visual." % ["ground", "impact", "head"][index])
	var p := {
		"clientObject": _view,
		"renderObject": func(view): return view,
		"playAnimation": _play,
		"animationInfo": func(model, clip): return {"length": model.scene_clip_length(clip) if is_instance_valid(model) else 0.0},
		"programType": func(_effect, id): return _type(id),
		"loadProgram": _load_program,
		"clearProgram": _clear_program,
		"startProgram": _start_program,
		"partQueryFailed": func():return not part_query_failure.is_empty(),
		"stopProgram": _stop_program,
		"currentProgram": func(_effect): return current_program(),
		"updateProgram": _update_program,
		"detachProcedural": func(model, _a, _b, _c): _unparent(model),
		"unsceneProcedural": func(model, _scene): _set_scene(model),
		"destroyProcedural": func(model, _flags): _destroy(model),
		"setParent": func(model, _parent, _name, _flags): _unparent(model),
		"setScene": func(model, _scene): _set_scene(model),
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

func _unsupported_program(operation: String, id: int) -> void:
	manager.diagnose("visual.program-%s-unimplemented" % operation,"Native procedural visual %s is not implemented" % operation,effect_id,{"programId":id&65535,"type":_type(id)})

func _new_model(resource: String):
	# A rejected getAsset Promise resolves to null for this visual's later
	# LoadProgram calls, even when a parsed scene bundle exists elsewhere.
	if definition.get("asset_failures",{}).has(resource.to_lower()):return null
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

func _set_scene(model) -> void:
	if not is_instance_valid(model):
		return
	_unparent(model)
	_unscene(model)
	if model.bundle_data.get("value",{}).get("nodes",[]).any(func(node):return str(node.get("type",""))=="emitter"):
		_diagnose("visual.detached-particles-unverified", "Detached emitter scene/lifetime handling has not been verified: %s" % str(model.bundle_data.get("value",{}).get("name","")))

func _view(id: int) -> Variant:
	var row: Dictionary = definition.get("hosts", {}).get(str(id), {})
	var token := int(row.get("privateToken",0))
	var pivot: Node3D = manager.host(id,token)
	var position: Vector3
	if pivot == null:
		# A current canonical actor can briefly lose its model during a
		# replacement. The old render facade uses the previous wrapper's
		# position until a new current wrapper appears, unless the model failed.
		if token!=0 or not manager.has_method("last_render_position"):return null
		var retained: Variant=manager.last_render_position(id)
		if not retained is Vector3:return null
		position=retained
	else:position=pivot.global_position
	# The old render facade reads the current loaded model name on every call.
	# A model replacement can change placeable/door anchor prefixes mid-effect.
	if (row.is_empty() or int(row.get("type",5)) in [9,10]) and manager.has_method("descriptor"):
		var live: Dictionary=manager.descriptor(id,token)
		if not live.is_empty():
			var live_type:=int(live.get("type",row.get("type",5)))
			var result: Dictionary=VisualDefinition.prefix(live,live_type)
			if result.has("error"):
				_diagnose("visual.native-model-prefix-unavailable",str(result.error))
				return null
			row={"type":live_type,"prefix":str(result.value),"privateToken":token}
	return {"id": id, "privateToken":token, "type": int(row.get("type", 5)), "prefix": str(row.get("prefix", "")), "position38": [Phases.f32(position.x), Phases.f32(-position.z), Phases.f32(position.y)]}

func _anchor(view: Dictionary, name: String) -> Node3D:
	return manager.anchor(int(view.id),int(view.get("privateToken",0)),name)

func _attach(model, view: Dictionary, name: String, flags: int, preserve_missing: bool=false) -> bool:
	if not is_instance_valid(model):
		return true
	var query:=_host_part(view,name)
	if query.has("error"):return false
	var anchor: Variant=query.node
	var root_anchor := _anchor(view, "root")
	if root_anchor != null:
		_diagnose("visual.attachment-lifetime-unimplemented", "Native attachment event propagation, handle invalidation and behavior lifetime are not implemented")
	if anchor == null:
		model.detach()
		if not preserve_missing: model.visible = false
		if root_anchor != null:
			_diagnose("visual.native-anchor-unavailable", "%s/%s" % [view.id, name])
		return true
	model.attach_to(anchor, flags)
	model.visible = true
	return true

func _slot_anchor(view: Dictionary, index: int) -> String:
	if view.type == 9:
		return view.prefix + ["_ground", "_impact", "_head_hit"][index]
	if view.type == 10:
		return view.prefix + ["grnd", "impc", "hhit"][index]
	return ["root", "impact", "head"][index]

func _geometry(view: Dictionary, preserve_missing: bool=false) -> bool:
	for index in 3:
		var model = state.models88[index]
		if not is_instance_valid(model):
			continue
		if not _attach(model, view, _slot_anchor(view, index), 0 if state.orient120 else 3, preserve_missing):return false
		if not state.orient120:
			# The old placement/selection adapter queries the effect's root only
			# after the parent attachment, and only in this orientation mode.
			if _effect_part(model,"root").has("error"):return false
			model.reset_part_world_orientation("root")
	return true

func _selected_creature_context(view: Variant) -> bool:
	return view is Dictionary and int(view.type)==5 and int(view.id)==int(manager.client.controlled_id)

func _selected_creature_target(id: int) -> bool:
	# Type4 stop checks the selected client object even when its render binding
	# has disappeared; the target-render gate applies only to context refresh.
	var selected: Variant=manager.client.object(int(manager.client.world.controlled_id))
	return selected is Dictionary and int(selected.get("objectType",0))==5 and int(selected.id)==id

func _refresh_type4_context(view: Variant) -> void:
	if _selected_creature_context(view):
		# visual_scene_runtime.js supplies a reporting provider for this native
		# renderer hook. Preserve its reached diagnostic and invocation gate.
		_diagnose("visual.context-renderer-unimplemented", "Native dynamic-projection/shadow context refresh is not implemented")

func _model_light_priority(model, priority: int) -> void:
	if not is_instance_valid(model):return
	for light in model.find_children("*", "OmniLight3D", true, false):
		light.set_meta("native_light_priority", priority)

func begin() -> bool:
	clock.start()
	if not part_query_failure.is_empty():return false
	place_models()
	if not part_query_failure.is_empty():return false
	detach_models()
	return true

func place_models() -> void:
	if state.updateProgramD8:
		return
	var view: Variant = _view(int(state.target54))
	if view == null:
		return
	if not _geometry(view):return
	if is_instance_valid(state.proceduralB8):
		if not _attach(state.proceduralB8, view, _slot_anchor(view, 0), 0):return
	state.updateProgramD8 = 1
	state.attached114 = 1
	_start_program(state, current_program())
	if not part_query_failure.is_empty():return
	# The old placement adapter applies per-effect material metadata after the
	# program starts, once for every allocated ordinary, procedural and extra
	# model. Its renderer metadata is not consumed by the current model owner.
	var has_model: bool=is_instance_valid(state.proceduralB8)
	for model in state.models88:
		has_model=has_model or is_instance_valid(model)
	for model in state.extraModelsA0:
		has_model=has_model or is_instance_valid(model)
	if has_model:
		_diagnose("visual.material-state-unimplemented", "Native resource/material visual metadata application is incomplete")

func attach_models() -> bool:
	var view: Variant = _view(int(state.target54))
	if view == null:
		return true
	# Selection attachment asks for the main model handle before setting the
	# attached flag; initial placement can still complete without that model.
	if not is_instance_valid(manager.host(int(view.id),int(view.get("privateToken",0)))):
		return true
	state.attached114 = 1
	if not _geometry(view, true):return false
	# The original tests the old procedural pointer, then reads the live field
	# after the lower program callback. Type4 and Type7 return before this step.
	var previous = state.proceduralB8
	var type := _type(current_program())
	if type == 4:
		return _attach_type4(view)
	elif type == 7:
		return _attach_beam()
	elif type in [1, 2, 3, 5, 6]:
		_unsupported_program("attach",current_program())
	if previous != null:
		if not _attach(state.proceduralB8, view, str(state.targetAnchor38), 0, true):return false
	return true

func detach_models() -> void:
	state.attached114 = 0
	for model in state.models88:
		_unparent(model)
		_unscene(model)
	if state.proceduralB8 == null:
		return
	# The old detach refreshes the selected creature's view context before
	# removing a Type4 procedural model. Its renderer hook currently reports
	# this missing native projection/shadow operation.
	if (int(state.programType10d) & 255) == 4:
		_refresh_type4_context(_view(int(state.target54)))
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
	if type==4 and _view(int(state.target54))==null:
		return 1 if state.proceduralB8!=null else 0
	if type in [4, 7, 12]:
		var resource: Variant = _program(id).get("resource")
		state.proceduralB8 = _new_model(str(resource)) if resource != null else null
		if type==7 and is_instance_valid(state.proceduralB8):
			_model_light_priority(state.proceduralB8,3)
		return 1 if is_instance_valid(state.proceduralB8) else 0
	if type == 5:
		# LoadProgram stores the table output even when the query found no row.
		state.field104=Phases.f32(float(_query(id,"float","param1")))
	return 1

func _update_program(_effect: Dictionary,id: int,delta_ms: int) -> void:
	if _type(id) in [5,6]:
		_diagnose("visual.program-update-unimplemented", "Native Type5 visual update is not implemented" if _type(id)==5 else "Native Type6 visual update is not implemented")

func _clear_program(_effect: Dictionary) -> void:
	beam_signature.clear()
	if is_instance_valid(state.proceduralB8):
		_unparent(state.proceduralB8)
		_unscene(state.proceduralB8)
		_destroy(state.proceduralB8)
	state.proceduralB8 = null

func _play(model, name: String, speed: float, flags: int, time: float) -> int:
	if not is_instance_valid(model) or not model.has_scene_clip(name):
		return 0
	var result: bool = model.play_effect_clip(name, speed, flags, time)
	if result and not model.playback_limitations.is_empty():
		_diagnose("visual.single-clip-profile", "original stacked runs/blend weights still pending")
	return 1 if result else 0

func _attach_type4(view: Dictionary) -> bool:
	var model = state.proceduralB8
	if not is_instance_valid(model):
		return true
	if not is_instance_valid(manager.host(int(view.id),int(view.get("privateToken",0)))):
		return true
	var name: String = "headconjure" if view.type == 5 else (view.prefix + "_head_hit" if view.type == 9 else (view.prefix + "hhit" if view.type == 10 else ""))
	var position := [0.0, 0.0, 0.0]
	var quaternion := [1.0, 0.0, 0.0, 0.0]
	if name != "":
		var query:=_host_part(view,name)
		if query.has("error"):return false
		var node: Variant=query.node
		VisualNodePose.local_pose(node, position, quaternion)
		position[1] = Phases.f32(Phases.f32(position[1]) + (0.75 if view.type == 5 else 0.375))
		position[2] = Phases.f32(Phases.f32(position[2]) + (0.5 if view.type == 5 else 0.25))
	if _effect_part(model,"root").has("error"):return false
	model.set_part_local_pose("root", position, quaternion)
	if not _attach(model, view, _slot_anchor(view, 0), 0):return false
	_refresh_type4_context(view)
	return true

func _start_program(_effect: Dictionary, id: int) -> void:
	if not state.updateProgramD8:
		return
	var type := _type(id)
	if type == 4 and is_instance_valid(state.proceduralB8):
		var view: Variant = _view(int(state.target54))
		if view == null:
			return
		var animation: String=str(_query(id,"string","param1",""))
		var speed: float=Phases.f32(float(_query(id,"float","param2")))
		var shadow: bool=int(_query(id,"integer","param3"))!=0
		var scope: int=int(_query(id,"integer","param4"))
		state.field110 = int(_query(id, "integer", "param5"))
		var gui: bool=int(_query(id,"integer","param6"))!=0
		state.scope10c = scope & 255
		if gui and _selected_creature_context(view):
			# startType4Visual registers before the program attaches. The old
			# scene adapter reports this unsupported native GUI operation.
			_diagnose("visual.gui-attachment-unimplemented", "Native selected-view visual GUI attachment is not implemented")
		if not _attach_type4(view):return
		_play(state.proceduralB8, animation, speed, 3, 0)
		if is_instance_valid(state.proceduralB8):
			manager.client.type4_shadowing(state.proceduralB8,shadow)
			state.shadow108=1 if shadow else 0
		_model_light_priority(state.proceduralB8,2 if _selected_creature_context(view) else 4)
	elif type == 7 and is_instance_valid(state.proceduralB8):
		if not Beam.start(state,id,_beam_providers()):return
		beam_signature = _beam_signature()
	elif type == 5:
		_unsupported_program("start",id)
	elif type == 10:
		manager.start_type10(effect_id,state,id,_program(id))
	elif type >= 1 and type <= 13:
		_diagnose("visual.program-start-unimplemented", str(type))

func _stop_program(_effect: Dictionary, id: int) -> void:
	if not state.updateProgramD8:
		return
	if _type(id) == 7:
		Beam.stop(state,_beam_providers());beam_signature.clear()
	elif _type(id) == 4:
		if state.proceduralB8 != null and state.attached114:
			_refresh_type4_context(_view(int(state.target54)))
		if state.proceduralB8 != null and int(_query(id,"integer","param6")) and _selected_creature_target(int(state.target54)):
			# Stop unregisters even when the target render binding disappeared.
			_diagnose("visual.gui-attachment-unimplemented", "Native selected-view visual GUI attachment is not implemented")
		_unparent(state.proceduralB8)
		_unscene(state.proceduralB8)
	elif _type(id) == 5:
		_unsupported_program("stop",id)
	elif _type(id) >= 1 and _type(id) <= 13:
		_diagnose("visual.program-stop-unimplemented", str(_type(id)))

func _beam_providers() -> Dictionary:
	return {"clientObject":_view,"renderObject":func(view):return view,"modelHandle":func(view,_part,_mode):return view if _anchor(view,"root") != null else null,
		"setParent":func(model,parent,name,flags):
			if not is_instance_valid(model):return true
			if parent == null:model.detach();return true
			return _attach(model,parent,str(name),int(flags)),
		"reattachReferences":func(model,target,name):
			if not is_instance_valid(model):return
			if model.bundle_data.get("value",{}).get("nodes",[]).any(func(node):return node.has("reference")) and (model.reference_graphs.is_empty() or model.reference_graphs[0]==null):
				model.visible=false;_diagnose("visual.beam-reference-graph-unavailable",str(name));return
			var anchor: Node3D = _anchor(target,name) if target != null else null
			if target != null and anchor == null:model.visible = false;_diagnose("visual.beam-target-anchor-unavailable",str(name));return
			if not model.reattach_references(anchor):model.visible = false;_diagnose("visual.beam-reference-graph-unavailable",str(name)),
		"programString":func(id,column):return _program(id).get("string",{}).get(column,{"found":false,"value":""}),"playAnimation":_play,"setScene":func(model,_scene):_set_scene(model)}

func _beam_signature() -> Array:
	if not is_instance_valid(state.proceduralB8):return []
	var target = _view(int(state.target54));var source = _view(int(state.source58))
	if target == null or source == null:return []
	var from := _anchor(source,str(state.sourceAnchor28));var to := _anchor(target,str(state.targetAnchor38))
	if not is_instance_valid(from) or not is_instance_valid(to):return []
	var signature: Array=[state.proceduralB8.get_instance_id(),from.get_instance_id(),to.get_instance_id()]
	if state.proceduralB8.has_method("reference_binding_signature"): signature.append(state.proceduralB8.reference_binding_signature())
	return signature

func _attach_beam() -> bool:
	if not Beam.attach(state,_beam_providers()):return false
	beam_signature = _beam_signature()
	return true

func refresh_bindings() -> void:
	if not state.attached114 or _type(current_program()) != 7 or not is_instance_valid(state.proceduralB8):return
	var signature := _beam_signature()
	if signature.is_empty():
		state.proceduralB8.detach();state.proceduralB8.visible = false;beam_signature.clear();return
	if signature != beam_signature:_attach_beam()

func _collect_reference_models(part: Dictionary,result: Array) -> void:
	var helper: Variant=part.get("helper")
	if is_instance_valid(helper) and is_instance_valid(helper.model68):result.append({"helper":helper,"model":helper.model68})
	for child in part.get("children38",[]):_collect_reference_models(child,result)

func _direct_reference_models(model: Variant) -> Array:
	var result: Array=[]
	if not is_instance_valid(model):return result
	var graphs: Variant=model.get("reference_graphs")
	if not graphs is Array:return result
	for graph in graphs:
		if graph!=null and not graph.root_part.is_empty():_collect_reference_models(graph.root_part,result)
	return result

func _advance_referenced_models_zero(model: Variant) -> bool:
	var children: Array=_direct_reference_models(model)
	# ModelReferenceScene.update animates all of this model's immediate
	# referenced models before synchronizing their attachments, then descends.
	for row in children:
		if closed:return false
		var child: Variant=row.model
		if is_instance_valid(child) and not bool(child.get("retired")) and is_instance_valid(child.get("rigs")):child.rigs._update(0.0)
	for row in children:
		if closed:return false
		if is_instance_valid(row.helper) and is_instance_valid(row.model):row.helper.synchronize_reference_pose()
	for row in children:
		if closed:return false
		if is_instance_valid(row.model) and not bool(row.model.get("retired")) and not _advance_referenced_models_zero(row.model):return false
	return true

func advance_owned_pose_zero() -> bool:
	if closed:return false
	var owned: Array=models.values().duplicate()
	# createVisualSceneRuntime.update first updates scene-root attachments,
	# then each owned animator and its reference tree, before phase time.
	for model in owned:
		if closed:return false
		if is_instance_valid(model) and not bool(model.get("retired")):model._process(0.0)
	for model in owned:
		if closed:return false
		if not is_instance_valid(model) or bool(model.get("retired")) or not models.has(model.get_instance_id()):continue
		if is_instance_valid(model.get("rigs")):model.rigs._update(0.0)
		if closed or not is_instance_valid(model) or not models.has(model.get_instance_id()):return false
		if not _advance_referenced_models_zero(model):return false
	return not closed

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
