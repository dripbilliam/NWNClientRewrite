extends RefCounted
# Connects the boundary-driven scene-reveal owner to existing World/effect/
# actor-alpha owners. This is not an entity store, timer, generic hide policy or
# a guessed replacement for native scene virtuals/tile fog.
const Reveal=preload("res://systems/native_render/native_scene_visibility.gd")
const Fade=preload("res://tools/native_parity/visibility/reveal_fade.gd")
const Alpha=preload("res://tools/native_parity/visibility/alpha_program.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const ShadowHooks=preload("res://systems/native_render/native_scene_shadow_hooks.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const EFFECT_OWNER="res://systems/native_render/effect_world.gd"
var _world: WeakRef
var _scope: Dictionary={}
var _ports: Dictionary={}
var _owner
var _shadow_models: Dictionary={} # Weak visual endpoints/Part baselines only.
var _reveal_shadow: Dictionary={} # Native F4 hook state, scoped by lifetime.
var _closed:=true
var _issues: Array=[]
var stats:={"targets":0,"effect_queries":0,"effect_members":0,"alpha_publications":0,"shadow_publications":0,"scene_publications":0,"fog_publications":0,"unavailable":0,"stale":0,"timing_unavailable":0}

static func _uint(value: Variant,maximum: int=4294967295) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floor(float(value))

func _unavailable(reason: String,id: int=-1) -> Dictionary:
	stats.unavailable+=1
	if _issues.size()<64:_issues.append({"reason":reason,"id":id})
	return {"available":false,"accepted":false,"reason":reason}

func configure(world: Node,scope: Dictionary,area: Dictionary,ports: Dictionary) -> Dictionary:
	if not _closed or _owner!=null:return _unavailable("bridge-already-configured")
	var normalized:=Reveal.scope_value(scope)
	if not is_instance_valid(world) or normalized.is_empty():return _unavailable("world-scope-unavailable")
	for key in ["scope_current","tile_center"]:
		if not ports.get(key) is Callable or not ports[key].is_valid():return _unavailable("required-owner-port-unavailable/"+key)
	_world=weakref(world);_scope=normalized;_ports=ports.duplicate();_closed=false
	_owner=Reveal.new()
	var result: Dictionary=_owner.configure(world,_scope,area,{"scope_current":_scope_current,"tile_center":_tile_center,"target_alpha":target_alpha,"publish":publish,"tile_fog":_tile_fog})
	if not result.available:
		_owner.close();_owner=null;_world=null;_scope={};_ports={};_closed=true
	return result

func _current() -> Node:
	var world: Node=_world.get_ref() if _world!=null else null
	if _closed or not is_instance_valid(world) or world.get("closed")==true or world.get("retiring")==true:return null
	if world.get("generation")!=_scope.area_generation or world.get("area_id")!=_scope.area_id or world.get("controlled_id")!=_scope.controlled_id:return null
	var desired: Variant=world.get("desired")
	if not desired is Dictionary or not desired.get(_scope.controlled_id) is Dictionary or not desired[_scope.controlled_id].get("object") is Dictionary:return null
	if Lifetime.token(desired[_scope.controlled_id].object)!=_scope.controlled_lifetime:return null
	var accepted: Variant=_ports.scope_current.call(_scope.duplicate(true))
	return world if accepted==true and not _closed and _world!=null and _world.get_ref()==world else null

func _scope_current(scope: Dictionary) -> bool:
	return scope==_scope and _current()!=null

func _source(id: int,lifetime: Array) -> Dictionary:
	var world:=_current()
	if world==null:return {}
	var desired: Variant=world.get("desired")
	var row: Variant=desired.get(id)
	if not row is Dictionary or not row.get("object") is Dictionary:return {}
	var source: Dictionary=row.object
	if source.get("replicationRemoved",false) or source.get("areaId")!=_scope.area_id or source.get("id")!=id or Lifetime.token(source)!=lifetime:return {}
	return source

func _tile_center(index: int,x: int,y: int) -> Variant:
	if _current()==null:return null
	var result: Variant=_ports.tile_center.call(index,x,y)
	return result if _current()!=null else null

func _port(name: String,args: Array) -> Variant:
	if _current()==null:return null
	var callback: Variant=_ports.get(name)
	if not callback is Callable or not callback.is_valid():return null
	var result: Variant=callback.callv(args)
	return result if _current()!=null else null

func effect_override(id: int,lifetime: Array) -> Dictionary:
	# Original763420 iterates the existing native effect list backwards. Do not
	# infer this from rendered opacity or reuse the general attach selector.
	var source:=_source(id,lifetime)
	if source.is_empty():return _unavailable("effect-target-lifetime-retired",id)
	var world:=_current();var effects=world.get("effects")
	if not is_instance_valid(effects) or effects.get("closed")==true or effects.get_script()==null or effects.get_script().resource_path!=EFFECT_OWNER:return _unavailable("native-effect-owner-unavailable",id)
	if not effects.has_method("_member_entries") or not effects.has_method("_bound"):return _unavailable("native-effect-list-unavailable",id)
	var members: Variant=effects.call("_member_entries",id,0)
	if not members is Array:return _unavailable("native-effect-list-unavailable",id)
	stats.effect_queries+=1
	var priority:=255;var selected: Variant=null
	for at in range(members.size()-1,-1,-1):
		if _source(id,lifetime).is_empty() or _current()!=world or world.get("effects")!=effects:return _unavailable("effect-owner-retired-during-query",id)
		var entry: Variant=members[at];stats.effect_members+=1
		if not entry is Dictionary:return _unavailable("malformed-native-effect-member",id)
		if entry.get("actor")!=id or entry.get("privateToken")!=0 or entry.get("areaVisual")==true:continue
		# The original knows program/type synchronously. Our async definition
		# arrival is not proof that an unprepared effect has no Type5 alpha.
		if not effects.call("_bound",entry):continue
		var runtime: Variant=entry.get("runtime")
		if not is_instance_valid(runtime) or runtime.get("closed")==true:return _unavailable("native-effect-not-prepared",id)
		var state: Variant=runtime.get("state")
		if not state is Dictionary or not _uint(state.get("finishedF4")) or not _uint(state.get("programType10d"),255):return _unavailable("native-effect-state-unavailable",id)
		if int(state.finishedF4)!=0 or int(state.programType10d)!=5:continue
		if not _uint(state.get("attached114")) or not _uint(state.get("scope10c"),255):return _unavailable("native-alpha-effect-state-unavailable",id)
		if int(state.attached114)==0 or int(state.scope10c)>=priority:continue
		var alpha: Variant=state.get("field100")
		if not alpha is int and not alpha is float:return _unavailable("native-alpha-effect-word-unavailable",id)
		selected=Alpha.word(float(alpha));priority=int(state.scope10c)
	if _source(id,lifetime).is_empty() or _current()!=world or world.get("effects")!=effects:return _unavailable("effect-owner-retired-during-query",id)
	return {"available":true,"alpha_word":Alpha.word(-1.0) if selected==null else selected,"selected":selected!=null,"scope":priority if selected!=null else null,"source":"native-reverse-attached-type5-selector763420"}

func target_alpha(id: int,lifetime: Array,revealed: int) -> Dictionary:
	var source:=_source(id,lifetime)
	if source.is_empty():return _unavailable("target-lifetime-retired",id)
	if not _uint(source.get("objectType"),255):return _unavailable("target-kind-unavailable",id)
	stats.targets+=1
	var input:={"is_creature":int(source.objectType)==5,"revealed":revealed}
	var immediate:=Fade.target_alpha(input)
	if immediate.available:return immediate
	if input.is_creature:
		# Presence belongs to the admitted PlayerInfo owner; an absent visibility
		# key or empty Dictionary is not proof that PlayerInfo is absent.
		var player: Variant=_port("player_info",[])
		if not player is Dictionary or player.get("available")!=true or not player.get("present") is bool:return _unavailable("native-player-info-presence-unavailable",id)
		input.player_info_present=player.present
		if player.present:
			var visibility: Variant=player.get("visibility")
			if not visibility is Dictionary:return _unavailable("native-player-info-perception-unavailable",id)
			var flags: Variant=visibility.get(str(id),visibility.get(id))
			input.matching_perception_present=flags!=null
			if flags!=null:input.perception=flags
			# Let the original pure branch return.5 before requesting fields it
			# does not read in that branch. No default110/114 is manufactured.
			var early:=Fade.target_alpha(input)
			if early.available:return early
			var fields: Variant=_port("creature_fields",[id,lifetime.duplicate(true)])
			if fields is Dictionary and fields.get("available")==true:
				for key in ["creature110","creature114"]:
					if fields.has(key):input[key]=fields[key]
			var before_override:=Fade.target_alpha(input)
			if before_override.available:return before_override
			for key in ["creature110","creature114"]:
				if not _uint(input.get(key)):return _unavailable("native-creature-state-unavailable/"+key,id)
	var effect:=effect_override(id,lifetime)
	if not effect.available:return effect
	input.effect_override_word=effect.alpha_word
	if _source(id,lifetime).is_empty():return _unavailable("target-retired-during-provider",id)
	var result:=Fade.target_alpha(input)
	return result if result.available else _unavailable("native-target-fields-unavailable",id)

func publish(id: int,lifetime: Array,command: Dictionary) -> bool:
	if _source(id,lifetime).is_empty():stats.stale+=1;return false
	var world:=_current()
	match str(command.get("kind")):
		"native_shadow":
			return command.get("enabled") is bool and set_native_shadow(id,lifetime,command.enabled).available
		"set_alpha":
			if command.get("scope")!=255 or not _uint(command.get("alpha_word")):return false
			var desired: Dictionary=world.get("desired");var installed: Variant=world.get("installed");var instances: Variant=world.get("instances")
			if not installed is Dictionary or not instances is Dictionary or not installed.has(id) or str(installed[id])!=str(desired[id].get("key","")):return false
			var instance: Variant=instances.get(id)
			if not is_instance_valid(instance) or instance.get("retired")==true or not instance.has_method("set_renderer_alpha") or not instance.has_method("renderer_alpha_model_indices"):return false
			var indices: Variant=instance.call("renderer_alpha_model_indices")
			if not indices is Array or indices.is_empty():return false
			var accepted: Variant=instance.call("set_renderer_alpha",Alpha.scalar(int(command.alpha_word)),indices)
			if accepted!=true or _source(id,lifetime).is_empty() or world.get("instances").get(id)!=instance:return false
			stats.alpha_publications+=1;return true
		"native_reveal_hooks":
			if _ports.get("native_shadow_detail") is Callable:return apply_native_scene_hooks(id,lifetime,command).available
			# Explicit legacy fixture/provider seam; no fallback guessed mode.
			var result: Variant=_port("scene_hook",[id,lifetime.duplicate(true),command.duplicate(true)])
			if result!=true:_unavailable("native-scene-hook-unavailable/"+str(command.kind),id);return false
			stats.scene_publications+=1;return not _source(id,lifetime).is_empty()
		"render_owner_virtual8":
			var result: Variant=_port("scene_hook",[id,lifetime.duplicate(true),command.duplicate(true)])
			if result!=true:_unavailable("native-scene-hook-unavailable/"+str(command.kind),id);return false
			stats.scene_publications+=1;return not _source(id,lifetime).is_empty()
	_unavailable("unknown-native-visibility-command",id);return false

func apply_native_scene_hooks(id: int,lifetime: Array,command: Dictionary) -> Dictionary:
	if _source(id,lifetime).is_empty():return _unavailable("scene-hook-lifetime-retired",id)
	var mode: Variant=_port("native_shadow_detail",[])
	var selected:=ShadowHooks.plan(command,mode,id==_scope.controlled_id)
	if not selected.available:return _unavailable(str(selected.reason),id)
	var primary_available:=true;var secondary_available:=true
	for operation in selected.commands:
		if operation.kind=="native_shadow":
			primary_available=set_native_shadow(id,lifetime,operation.enabled).available
		else:
			# D0's resource/owner is not the primary Actor. Absence of a Godot
			# child does not certify that the original had a null shadowblob.
			var applied: Variant=_port("shadowblob",[id,lifetime.duplicate(true),operation.duplicate(true)])
			secondary_available=applied is Dictionary and applied.get("available")==true
			if not secondary_available:_unavailable("native-shadowblob-owner-unavailable",id)
	if selected.store_revealF4!=null:_reveal_shadow[id]={"lifetime":lifetime.duplicate(true),"revealed":selected.store_revealF4}
	stats.scene_publications+=1
	return {"available":primary_available and secondary_available,"primary_available":primary_available,"secondary_available":secondary_available,"plan":selected,"alpha_not_blocked":true}

func _shadow_model_index(instance: Node3D,mesh: MeshInstance3D) -> Variant:
	if mesh.has_meta("native_source_model_index"):return mesh.get_meta("native_source_model_index")
	# The existing static factory installs exactly one original model, then
	# packs/clones those Parts. It records ModelInstance's source provenance
	# on both the original physical Part and its mesh. This authenticates its
	# model0 ownership without classifying an arbitrary unknown mesh as model0.
	if not instance is Template.Placement or not mesh.has_meta("native_mesh_source") or not instance.has_meta("native_model_name"):return null
	var source: Variant=mesh.get_meta("native_mesh_source")
	if not source is Dictionary or source.get("version")!=1 or not _uint(source.get("model_index")) or source.model_index!=0 or not _uint(source.get("part_index")) or source.get("resource")!=instance.get_meta("native_model_name"):return null
	var parts: Array=instance.parts
	if int(source.part_index)>=parts.size():return null
	var part: Variant=parts[int(source.part_index)]
	if not part is Node3D or not part.has_meta("native_part_index") or part.get_meta("native_part_index")!=source.part_index or not part.has_meta("native_mesh_source") or part.get_meta("native_mesh_source")!=source:return null
	if mesh!=part and mesh.get_parent()!=part:return null
	return 0

func capture_shadow_model(id: int,lifetime: Array) -> Dictionary:
	# Call exactly at the existing cold model-adoption boundary, before any
	# bridge shadow operation. Gob on/off multiplies authored Part shadow flags;
	# restoring ON indiscriminately would incorrectly enable authored noncasters.
	if _source(id,lifetime).is_empty():return _unavailable("shadow-model-lifetime-retired",id)
	var world:=_current();var installed: Variant=world.get("installed");var instances: Variant=world.get("instances")
	if not installed is Dictionary or not instances is Dictionary or not installed.has(id) or str(installed[id])!=str(world.get("desired")[id].get("key","")):return _unavailable("shadow-model-not-admitted",id)
	var instance: Variant=instances.get(id)
	if not instance is Node3D or instance.get("retired")==true or not instance.has_method("renderer_alpha_model_indices") or not instance.get("meshes") is Array:return _unavailable("shadow-physical-actor-unavailable",id)
	if _shadow_models.has(id):
		var existing: Dictionary=_shadow_models[id]
		if existing.lifetime==lifetime and existing.instance.get_ref()==instance:return {"available":true,"accepted":false,"reason":"existing-cold-shadow-baseline"}
	var primary: Variant=instance.call("renderer_alpha_model_indices")
	if not primary is Array or primary.is_empty():return _unavailable("shadow-primary-models-unavailable",id)
	var endpoints: Array=[]
	for mesh in instance.get("meshes"):
		if not mesh is MeshInstance3D:return _unavailable("shadow-mesh-unavailable",id)
		var model: Variant=_shadow_model_index(instance,mesh)
		if not _uint(model):return _unavailable("shadow-original-model-index-unavailable",id)
		if primary.has(int(model)):endpoints.append({"mesh":weakref(mesh),"setting":int(mesh.cast_shadow)})
	if _source(id,lifetime).is_empty() or world.get("instances").get(id)!=instance:return _unavailable("shadow-model-retired-during-capture",id)
	_shadow_models[id]={"lifetime":lifetime.duplicate(true),"instance":weakref(instance),"parts":endpoints}
	return {"available":true,"accepted":true,"parts":endpoints.size()}

func set_native_shadow(id: int,lifetime: Array,enabled: bool) -> Dictionary:
	if _source(id,lifetime).is_empty() or not _shadow_models.has(id):return _unavailable("cold-shadow-model-baseline-unavailable",id)
	var record: Dictionary=_shadow_models[id];var instance: Node3D=record.instance.get_ref();var world:=_current()
	if record.lifetime!=lifetime or not is_instance_valid(instance) or instance.get("retired")==true or world.get("instances").get(id)!=instance:return _unavailable("shadow-visual-replaced",id)
	if str(world.get("installed").get(id,""))!=str(world.get("desired")[id].get("key","")):return _unavailable("shadow-visual-not-admitted",id)
	# Validate all actual endpoints before the first sparse publication.
	for endpoint in record.parts:
		if not endpoint.mesh.get_ref() is MeshInstance3D:return _unavailable("shadow-part-retired",id)
	preload("res://systems/native_render/static_draw_invalidation.gd").withdraw(instance,"native-shadow-state")
	for endpoint in record.parts:
		if _source(id,lifetime).is_empty() or world.get("instances").get(id)!=instance:return _unavailable("shadow-visual-retired-during-publication",id)
		var mesh: MeshInstance3D=endpoint.mesh.get_ref()
		mesh.cast_shadow=endpoint.setting if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats.shadow_publications+=1
	return {"available":not _source(id,lifetime).is_empty(),"parts":record.parts.size(),"native_virtual":"CNWC+210/GobTurnOnShadows" if enabled else "CNWC+218/GobTurnOffShadows"}

func _tile_fog(event: Dictionary) -> bool:
	var result: Variant=_port("tile_fog",[event.duplicate(true)])
	if result!=true:_unavailable("native-tile-fog-operation-unavailable");return false
	stats.fog_publications+=1;return true

func observe(source: Dictionary,position_native: Array,reason: String) -> Dictionary:
	if _closed or _owner==null:return _unavailable("visibility-bridge-not-configured")
	var id: Variant=source.get("id")
	if not _uint(id):return _unavailable("object-id-unavailable")
	var world:=_current();var instance: Node3D=null
	if world!=null and world.get("instances") is Dictionary:instance=world.get("instances").get(int(id))
	return _owner.observe_object(source,position_native,instance,reason)

func model_ready(id: int,lifetime: Array) -> Dictionary:
	var world:=_current()
	if world==null or _owner==null or _source(id,lifetime).is_empty():return _unavailable("model-scope-retired",id)
	var instances: Variant=world.get("instances")
	if not instances is Dictionary or not instances.get(id) is Node3D:return _unavailable("model-instance-unavailable",id)
	var shadows:=capture_shadow_model(id,lifetime)
	# Shadow ownership is independent of the real model/alpha adoption. An
	# unsupported secondary or missing authored baseline must stay partial
	# without blocking the retained opacity's existing physical endpoint.
	var adopted: Dictionary=_owner.bind_instance(id,lifetime,instances[id])
	adopted.shadow_available=shadows.available
	adopted.shadow_reason=shadows.get("reason")
	adopted.partial=shadows.available!=true
	return adopted

func receive_wire(frame: Dictionary) -> Dictionary:
	return _owner.receive_wire(frame) if _owner!=null and not _closed else _unavailable("visibility-bridge-not-configured")

func set_native_gates(id: int,lifetime: Array,temporary104: Variant,blocked108: Variant) -> Dictionary:
	return _owner.set_native_gates(id,lifetime,temporary104,blocked108) if _owner!=null and not _closed else _unavailable("visibility-bridge-not-configured")

func set_area_flags(flags: Variant) -> Dictionary:
	return _owner.set_area_flags(flags) if _owner!=null and not _closed else _unavailable("visibility-bridge-not-configured")

func advance() -> Dictionary:
	if _closed or _owner==null or _current()==null:return _unavailable("visibility-bridge-not-configured")
	var timing: Variant=_port("fade_timing",[])
	if not timing is Dictionary or timing.get("available")!=true or not _uint(timing.get("snapshot_us"),9223372036854775807):
		stats.timing_unavailable+=1;return _unavailable("native-world-snapshot-time-unavailable")
	_owner.advance(timing)
	return {"available":_current()!=null}

func remove(id: int,lifetime: Array) -> Dictionary:
	if _shadow_models.has(id) and _shadow_models[id].lifetime==lifetime:_shadow_models.erase(id)
	if _reveal_shadow.has(id) and _reveal_shadow[id].lifetime==lifetime:_reveal_shadow.erase(id)
	return _owner.remove(id,lifetime) if _owner!=null and not _closed else _unavailable("visibility-bridge-not-configured")

func snapshot() -> Dictionary:
	return {"closed":_closed,"scope":_scope.duplicate(true),"stats":stats.duplicate(),"issues":_issues.duplicate(true),"shadow_models":_shadow_models.size(),"owner":_owner.snapshot() if _owner!=null else {},"missing_lower_policy":"Explicit unavailable; no default creature fields, OS clock, generic Node.hide or no-op scene/fog success"}

func close() -> void:
	if _closed:return
	_closed=true
	if _owner!=null:_owner.close()
	_shadow_models.clear();_reveal_shadow.clear();_ports.clear();_scope={};_world=null
