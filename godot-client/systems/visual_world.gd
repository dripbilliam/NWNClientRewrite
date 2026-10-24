extends Node3D

const Resources = preload("res://systems/visual_resources.gd")
const Runtime = preload("res://systems/visual_runtime.gd")
const AreaRuntime = preload("res://systems/area_visual_runtime.gd")
const Selection = preload("res://systems/visual_selection.gd")
var client
var cache := Resources.new()
var entries: Dictionary = {}
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
			for entry in entries.values():
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

func select_actor(actor: int,token: int = 0) -> void:
	var selected: Array = entries.values().filter(func(entry): return not entry.areaVisual and entry.actor == actor and entry.privateToken == token and entry.runtime != null and _bound(entry))
	if selected.is_empty():
		return
	var states: Array = selected.map(func(entry): return entry.runtime.state)
	var runtime_for := func(state):
		for entry in selected:
			if is_same(entry.runtime.state, state): return entry.runtime
		return null
	var p := {"programType": func(state): return int(state.programType10d) & 255,
		"selectedObjectId1406ac1c0": func(): return client.controlled_id,
		"viewGate1407dadb0": func(): diagnose("visual.view-gate-unimplemented", "native view context pending", 0); return false,
		"attach": func(state): runtime_for.call(state).attach_models(),
		"detach": func(state): runtime_for.call(state).detach_models(),
		"start": func(state): runtime_for.call(state).clock.start(),
		"stop": func(state, requested): runtime_for.call(state).clock.stop(requested)}
	var types := {}
	for state in states:
		types[int(state.programType10d) & 255] = true
	for type in types:
		Selection.select({"id": actor, "suppressed108": 0, "visuals80": states}, type, p)

func detach_competing(current: Dictionary) -> void:
	if current.runtime == null: return
	var selected: Array = entries.values().filter(func(entry): return not entry.areaVisual and entry.actor == current.actor and entry.privateToken == current.privateToken and entry.runtime != null and _bound(entry))
	var states: Array = selected.map(func(entry): return entry.runtime.state)
	Selection.detach_competing({"visuals80": states}, current.runtime.state, {"programType": func(state): return int(state.programType10d) & 255,
		"detach": func(state):
			for entry in selected:
				if is_same(entry.runtime.state, state): entry.runtime.detach_models(); return})

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
	for row in models.values().duplicate(): release_model(row.model)
	models.clear()
	cache.clear()

func _exit_tree() -> void:
	close()
