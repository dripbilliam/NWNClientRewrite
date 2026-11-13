extends Node3D

const Resources = preload("res://systems/visual_resources.gd")
const Runtime = preload("res://systems/visual_runtime.gd")
const AreaRuntime = preload("res://systems/area_visual_runtime.gd")
const Selection = preload("res://systems/visual_selection.gd")
const SelectionTiming=preload("res://systems/native_render/frame_profile.gd")
var client
var cache := Resources.new()
var entries: Dictionary = {}
var actor_effects: Dictionary = {}
# Validated against original selection/lifetime traces and repeated full-scene
# localhost measurements. Roll back only candidate lookup with "scan".
var indexed_membership := OS.get_cmdline_user_args().has("--effect-membership=indexed") or (not OS.get_cmdline_user_args().has("--effect-membership=scan") and OS.get_environment("NWN_EFFECT_MEMBERSHIP")!="scan")
static func configured_compiled_selection() -> bool:
	return OS.get_cmdline_user_args().has("--visual-selection=compiled") or OS.get_environment("NWN_VISUAL_SELECTION")=="compiled"
var compiled_selection:=configured_compiled_selection()
var compiled_selection_available:=ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","visual_select") and ClassDB.class_has_method("NwnParticleKernel","visual_detach_competing")
var compiled_selection_calls:=0
var compiled_selection_failures:=0
# Callback objects are immutable plumbing. Only their invocation-local member
# snapshot lives on this stack; nested selection/removal gets its own context.
# Never cache a runtime, host, lifetime decision or mutable state by effect ID.
var reused_selection_setup:=OS.get_cmdline_user_args().has("--visual-setup=reused") or OS.get_environment("NWN_VISUAL_SETUP")=="reused"
var reused_selection_calls:=0
var selection_context_peak:=0
var selection_contexts: Array=[]
var selection_ports: Dictionary={}
var competing_ports: Dictionary={}
var compiled_snapshot:=OS.get_cmdline_user_args().has("--visual-snapshot=compiled") or OS.get_environment("NWN_VISUAL_SNAPSHOT")=="compiled"
var compiled_snapshot_available:=ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","visual_snapshot")
var compiled_snapshot_calls:=0
var compiled_snapshot_failures:=0
var compiled_snapshot_noops:=0
var models: Dictionary = {}
var next_model := 0
var closed := false
var diagnostics: Dictionary = {}
var stats := {"reserved": 0, "started": 0, "removed": 0, "retired": 0, "canceled": 0, "failed": 0, "rebound": 0}

func configure(owner) -> void:
	client = owner
	cache.configure({"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket})
	process_priority = 45

func receive(message: Dictionary) -> void:
	if closed:
		return
	match message.kind:
		"visual-reserve":
			var id := int(message.effectId)
			if entries.has(id):
				return
			entries[id] = {"id": id, "actor": int(message.actorId), "privateToken":int(message.get("privateToken",0)), "areaVisual":bool(message.get("areaVisual",false)), "visual": int(message.visualId), "transient": bool(message.transient), "runtime": null, "definition": {}, "removed": false, "binding": null, "signature": ""}
			if indexed_membership: _index_effect(entries[id])
			stats.reserved += 1
		"visual-ready":
			var id := int(message.effectId)
			if not entries.has(id) or entries[id].removed:
				return
			var definition := cache.prepare_definition(str(message.file), str(message.sha256))
			var entry: Dictionary = entries[id]
			var matches_entry: bool = not definition.is_empty() and ((entry.areaVisual and definition.kind == "area-visual-definition" and int(definition.state.visual180) == int(entry.visual)) or (not entry.areaVisual and definition.kind == "visual-definition" and int(definition.state.target54) == int(entry.actor) and int(definition.get("hosts",{}).get(str(entry.actor),{}).get("privateToken",0)) == int(entry.privateToken)))
			if not matches_entry:
				diagnose("visual.definition-rejected", cache.error, id)
				stats.failed += 1
				_forget(id, "failed")
				return
			entries[id].definition = definition
			_begin(entries[id])
		"visual-remove":
			# Original client removal scans the physical HEAD, skipping effects
			# already finished or in cessation. Pending reservations participate.
			for entry in _member_entries(int(message.actorId),0):
				if message.has("effectId") and int(entry.id)!=int(message.effectId):continue
				if entry.privateToken != 0 or entry.actor != int(message.actorId) or entry.visual != int(message.visualId) or entry.removed:
					continue
				var runtime = entry.runtime
				if runtime != null and (runtime.state.finishedF4 or runtime.phase.has_cessation()):
					continue
				entry.removed = true
				stats.removed += 1
				if runtime == null:
					stats.canceled += 1
					_forget(entry.id, "canceled")
				else:
					detach_competing(entry)
					runtime.clock.stop(1)
					select_actor(entry.actor,entry.privateToken)
				break
		"visual-cancel":
			var id := int(message.effectId)
			if entries.has(id):
				stats.canceled += 1
				_forget(id, "canceled")
		"visual-model-particles":
			var model_id := int(message.modelId)
			if models.has(model_id) and int(models[model_id].effect) == int(message.effectId) and is_instance_valid(client.particles):
				var model = models[model_id].model
				client.particles.adopt({"particles": {"emitters": message.emitters}}, model.meshes)

func _bound(entry: Dictionary) -> bool:
	return host(entry.actor,entry.privateToken) != null

func host(id: int,token: int = 0) -> Node3D:
	if token != 0: return client.client_dummies.host(id,token) if is_instance_valid(client.client_dummies) else null
	return client.pivots.get(id) if not client.removed_states.get(id,false) else null

func anchor(id: int,token: int,part: String) -> Node3D:
	if token != 0: return client.client_dummies.anchor(id,token,part) if is_instance_valid(client.client_dummies) else null
	return client.model_rigs.node_for(id,0,part) if is_instance_valid(client.model_rigs) else null

func _begin(entry: Dictionary) -> void:
	if entry.areaVisual:
		if entry.runtime != null or entry.definition.is_empty(): return
		var runtime := AreaRuntime.new();add_child(runtime);entry.runtime = runtime
		runtime.configure(self,entry.id,entry.definition);stats.started += 1;_status(entry,"started");return
	if entry.runtime != null or entry.definition.is_empty() or not _bound(entry) or anchor(entry.actor,entry.privateToken,"root") == null:
		return
	var runtime := Runtime.new()
	add_child(runtime)
	entry.runtime = runtime
	entry.binding = host(entry.actor,entry.privateToken)
	runtime.configure(self, entry.id, entry.definition)
	runtime.begin()
	stats.started += 1
	select_actor(entry.actor,entry.privateToken)
	_status(entry, "started")

func _index_effect(entry: Dictionary) -> void:
	var actor:=int(entry.actor); var token:=int(entry.privateToken)
	if not actor_effects.has(actor): actor_effects[actor]={}
	var tokens: Dictionary=actor_effects[actor]
	if not tokens.has(token): tokens[token]=[]
	tokens[token].append(entry)
func _unindex_effect(entry: Dictionary) -> void:
	var actor:=int(entry.actor); var token:=int(entry.privateToken)
	if not actor_effects.has(actor): return
	var tokens: Dictionary=actor_effects[actor]
	if not tokens.has(token): return
	var members: Array=tokens[token]
	for index in members.size():
		if is_same(members[index],entry): members.remove_at(index); break
	if members.is_empty(): tokens.erase(token)
	if tokens.is_empty(): actor_effects.erase(actor)
func _member_entries(actor: int,token: int) -> Array:
	if not indexed_membership: return entries.values()
	if not actor_effects.has(actor): return []
	# Snapshot entry references before callbacks. This preserves physical list
	# order and old filter behavior when selection causes reentrant retirement.
	var members: Array=actor_effects[actor].get(token,[])
	return members.duplicate()
func select_actor(actor: int,token: int = 0) -> void:
	var began:=SelectionTiming.begin(); _select_actor(actor,token); SelectionTiming.finish("effect_selection_total",began)
func _select_actor(actor: int,token: int) -> void:
	var setup:=SelectionTiming.begin()
	var snapshot: Variant=_selection_snapshot(actor,token) if compiled_snapshot else null
	if snapshot!=null and snapshot.has("error"):
		compiled_snapshot_failures+=1;push_error("Native visual snapshot failed: "+str(snapshot.error));SelectionTiming.finish("effect_selection_setup",setup);return
	var prepared: bool=snapshot!=null and not snapshot.is_empty()
	var selected: Array = snapshot.selected if prepared else _selection_entries(actor,token)
	if selected.is_empty():
		SelectionTiming.finish("effect_selection_setup",setup)
		return
	if prepared and snapshot.get("no_actions_proven",false):
		# The native proof reads this invocation's complete state snapshot.
		# It rejects observable view/selection gates and every possible action.
		compiled_snapshot_noops+=1;SelectionTiming.finish("effect_selection_setup",setup);return
	var states: Array = snapshot.states if prepared else _selection_states(selected)
	var p: Dictionary
	if reused_selection_setup:
		_selection_push(selected); p=_selection_ports()
	else:
		var runtime_for := func(state):
			for entry in selected:
				if is_same(entry.runtime.state, state): return entry.runtime
			return null
		p={"programType": func(state): return int(state.programType10d) & 255,
			"selectedObjectId1406ac1c0": func(): return client.controlled_id,
			"viewGate1407dadb0": _selection_view_gate,
			"attach": func(state): runtime_for.call(state).attach_models(),
			"detach": func(state): runtime_for.call(state).detach_models(),
			"start": func(state): runtime_for.call(state).clock.start(),
			"stop": func(state, requested): runtime_for.call(state).clock.stop(requested)}
	var types: Variant
	if prepared: types=snapshot.types
	else:
		types={}
		for state in states: types[int(state.programType10d) & 255] = true
	SelectionTiming.finish("effect_selection_setup",setup)
	for type in types:
		var began:=SelectionTiming.begin()
		if compiled_selection and compiled_selection_available:
			compiled_selection_calls+=1
			var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","visual_select",{"id":actor,"suppressed108":0,"visuals80":states},int(type),p)
			_compiled_selection_result(result)
		else:
			if compiled_selection: _compiled_selection_result({"error":"Native selector unavailable"})
			Selection.select({"id": actor, "suppressed108": 0, "visuals80": states}, type, p)
		SelectionTiming.finish("effect_selection_core",began)
	if reused_selection_setup: selection_contexts.pop_back()

func _selection_snapshot(_actor: int,_token: int) -> Dictionary:
	# Custom owners/bound callbacks retain the general imperative setup path.
	return {}

func _selection_entries(actor: int,token: int) -> Array:
	if not reused_selection_setup:
		return _member_entries(actor,token).filter(func(entry): return not entry.areaVisual and entry.actor == actor and entry.privateToken == token and entry.runtime != null and _bound(entry))
	var selected: Array=[]
	for entry in _member_entries(actor,token):
		if not entry.areaVisual and entry.actor==actor and entry.privateToken==token and entry.runtime!=null and _bound(entry): selected.append(entry)
	return selected
func _selection_states(selected: Array) -> Array:
	if not reused_selection_setup: return selected.map(func(entry): return entry.runtime.state)
	# Keep this AFTER the entire bound-filter pass. A later bound callback can
	# replace the state/runtime of an earlier selected entry.
	var states: Array=[]
	for entry in selected: states.append(entry.runtime.state)
	return states
func _competing_entries(current: Dictionary) -> Array:
	if not reused_selection_setup:
		return _member_entries(int(current.actor),int(current.privateToken)).filter(func(entry): return not entry.areaVisual and entry.actor == current.actor and entry.privateToken == current.privateToken and entry.runtime != null and _bound(entry))
	var selected: Array=[]
	for entry in _member_entries(int(current.actor),int(current.privateToken)):
		# Read current after each bound callback, as the retained closure does.
		if not entry.areaVisual and entry.actor==current.actor and entry.privateToken==current.privateToken and entry.runtime!=null and _bound(entry): selected.append(entry)
	return selected
func _selection_push(selected: Array) -> void:
	selection_contexts.append(selected); reused_selection_calls+=1; selection_context_peak=maxi(selection_context_peak,selection_contexts.size())
func _selection_runtime(state: Dictionary):
	for entry in selection_contexts.back():
		if is_same(entry.runtime.state,state): return entry.runtime
	return null
func _selection_type(state: Dictionary) -> int: return int(state.programType10d)&255
func _selection_controlled() -> int: return client.controlled_id
func _selection_view_gate() -> bool:
	diagnose("visual.view-gate-unimplemented","native view context pending",0); return false
func _selection_attach(state: Dictionary) -> void: _selection_runtime(state).attach_models()
func _selection_detach(state: Dictionary) -> void: _selection_runtime(state).detach_models()
func _selection_start(state: Dictionary) -> void: _selection_runtime(state).clock.start()
func _selection_stop(state: Dictionary,requested: int) -> void: _selection_runtime(state).clock.stop(requested)
func _selection_detach_competing(state: Dictionary) -> void:
	for entry in selection_contexts.back():
		if is_same(entry.runtime.state,state): entry.runtime.detach_models(); return
func _selection_ports() -> Dictionary:
	if selection_ports.is_empty():
		selection_ports={"programType":_selection_type,"selectedObjectId1406ac1c0":_selection_controlled,"viewGate1407dadb0":_selection_view_gate,"attach":_selection_attach,"detach":_selection_detach,"start":_selection_start,"stop":_selection_stop}
	return selection_ports

func _compiled_selection_result(result: Dictionary) -> void:
	if not result.has("error"): return
	compiled_selection_failures+=1
	diagnose("visual.compiled-selection-failed",str(result.error),0)
	# Never replay a selection after native callbacks have begun: that could
	# duplicate restart/stop/attachment events. Invalid native results are explicit.
	push_error("Compiled visual selection failed: "+str(result.error))

func detach_competing(current: Dictionary) -> void:
	if current.runtime == null: return
	var selected: Array = _competing_entries(current)
	var states: Array = _selection_states(selected)
	var p: Dictionary
	if reused_selection_setup:
		_selection_push(selected)
		if competing_ports.is_empty(): competing_ports={"programType":_selection_type,"detach":_selection_detach_competing}
		p=competing_ports
	else:
		p={"programType": func(state): return int(state.programType10d) & 255,
			"detach": func(state):
				for entry in selected:
					if is_same(entry.runtime.state, state): entry.runtime.detach_models(); return}
	var began:=SelectionTiming.begin()
	if compiled_selection and compiled_selection_available:
		compiled_selection_calls+=1
		_compiled_selection_result(ClassDB.class_call_static("NwnParticleKernel","visual_detach_competing",{"visuals80":states},current.runtime.state,p))
	else:
		if compiled_selection: _compiled_selection_result({"error":"Native selector unavailable"})
		Selection.detach_competing({"visuals80":states},current.runtime.state,p)
	SelectionTiming.finish("effect_competing_selection",began)
	if reused_selection_setup: selection_contexts.pop_back()

func _process(delta: float) -> void:
	if closed:
		return
	# Match the retained local presenter: active entries first, retiring entries
	# second; select after each individual phase update, preserving list order.
	for retiring in [false, true]:
		for id in entries.keys():
			if not entries.has(id): continue
			var entry: Dictionary = entries[id]
			if bool(entry.removed) != retiring: continue
			if entry.areaVisual:
				_begin(entry)
				if entry.runtime == null: continue
				entry.runtime.advance();_status(entry,"phase")
				if entry.runtime.state.destroyed: _forget(id,"retired")
				continue
			if (entry.privateToken != 0 and not _bound(entry)) or (entry.privateToken == 0 and client.removed_states.get(entry.actor, false)) or (entry.runtime != null and not _bound(entry)):
				_forget(id, "retired")
				continue
			_begin(entry)
			var runtime = entry.runtime
			if runtime == null: continue
			if entry.binding != host(entry.actor,entry.privateToken):
				entry.binding = host(entry.actor,entry.privateToken)
				if runtime.state.attached114: runtime.attach_models()
				stats.rebound += 1
			runtime.refresh_bindings()
			runtime.clock.advance(delta)
			select_actor(entry.actor,entry.privateToken)
			_status(entry, "phase")
			if (entry.transient or retiring) and runtime.phase.is_retired():
				if entry.transient and runtime.state.durationFc == 0:
					detach_competing(entry)
					select_actor(entry.actor,entry.privateToken)
				_forget(id, "retired")
				select_actor(entry.actor,entry.privateToken)

func _status(entry: Dictionary, stage: String) -> void:
	var state: Dictionary = entry.runtime.state if entry.runtime != null else {}
	var signature := "%s/%s/%s/%s" % [state.get("phase184",state.get("programPhaseFa", -1)), state.get("retiring188",state.get("finishedF4", -1)), state.get("closedEc", -1), state.get("attached114", -1)]
	if stage == "phase" and signature == entry.signature: return
	entry.signature = signature
	client.command({"kind": "visual-status", "effectId": entry.id, "stage": stage, "visualId": entry.visual, "phase": state.get("phase184",state.get("programPhaseFa", 0)), "finished": state.get("retiring188",state.get("finishedF4", 0)), "attached": state.get("attached114", 0)})

func _forget(id: int, reason: String) -> void:
	if not entries.has(id): return
	var entry: Dictionary = entries[id]
	if indexed_membership: _unindex_effect(entry)
	entries.erase(id)
	if entry.runtime != null: entry.runtime.close()
	if reason == "retired": stats.retired += 1
	if not closed: client.command({"kind": "visual-status", "effectId": id, "stage": reason, "visualId": entry.visual})

func create_model(effect_id: int, resource: String):
	var model = cache.instantiate_model(resource, self)
	if model == null:
		diagnose("visual.model-instantiation-failed", cache.error, effect_id)
		return null
	next_model += 1
	model.set_meta("visual_model_id", next_model)
	models[next_model] = {"model": model, "effect": effect_id}
	client.command({"kind": "visual-model-created", "effectId": effect_id, "modelId": next_model, "resource": resource})
	if is_instance_valid(client.particles): client.particles.watch_visual_model(next_model, model.rigs)
	return model

func release_model(model) -> void:
	var id := int(model.get_meta("visual_model_id"))
	if not models.has(id): return
	var effect_id: int = models[id].effect
	models.erase(id)
	if is_instance_valid(client.particles):
		client.particles.unwatch_visual_model(id, model.rigs)
		client.particles.forget_entity(-id)
	if not closed: client.command({"kind": "visual-model-release", "effectId": effect_id, "modelId": id})
	model.retire()

func model_for(id: int):
	return models[id].model if models.has(id) and is_instance_valid(models[id].model) and not models[id].model.retired else null

func diagnose(code: String, detail: String, id: int) -> void:
	var key := code + ":" + detail
	if diagnostics.has(key): return
	diagnostics[key] = true
	if diagnostics.size() <= 128:
		client.command({"kind": "visual-diagnostic", "effectId": id, "code": code, "detail": detail})

func sample() -> Dictionary:
	var native_animation := {"models": 0, "runs": 0, "diagnostics": []}
	for record in models.values():
		for model in record.model.rigs.entities[0].models:
			if not model.has("native_owner"): continue
			native_animation.models += 1
			native_animation.runs += model.native_owner.gob.runsE0.size()
			for detail in model.native_owner.diagnostics + model.native_owner.pose.diagnostics:
				if not native_animation.diagnostics.has(detail): native_animation.diagnostics.append(detail)
	return {"stats": stats.duplicate(true), "entries": entries.size(), "models": models.size(), "cache": cache.stats.duplicate(true), "diagnostics": diagnostics.keys(), "nativeAnimation": native_animation}

func close() -> void:
	if closed: return
	closed = true
	set_process(false)
	for id in entries.keys(): _forget(id, "retired")
	actor_effects.clear()
	for row in models.values().duplicate(): release_model(row.model)
	models.clear()
	cache.clear()

func _exit_tree() -> void:
	close()
