extends Node
# Last rendered-frame CPU illumination, requested only by gated visual programs.
# Native arithmetic is independently verified. Original main-world sphere
# collection/history is a separate research candidate; static BSP baking and
# special view-volume policy remain open. No race-based or global boost.
const Sample=preload("res://systems/native_render/focus_light_sample.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const InputRegistry=preload("res://systems/native_render/native_light_input_registry.gd")
const LightPolicy=preload("res://systems/native_render/native_light_policy.gd")
const DEFAULT_MAXIMUM:=32 # Original graphics.lighting.max-lights default, not its128-slot storage capacity.
var world: Node3D
var members: Dictionary={}
var gate:=Sample.new()
var focus:=Vector3.ZERO
var controlled: WeakRef
var blind_light_owner: WeakRef
var area: Dictionary={}
var requested:=false
var closed:=false
var value:=Vector3.ZERO
var samples:=0
var sampled_lights:=0
var excluded_lights:=0
var peak_ms:=0.0
var history
var history_maximum:=DEFAULT_MAXIMUM
var history_radius:=45.0
var history_camera: WeakRef
var history_environment: WeakRef
var history_result: Dictionary={}
var history_rows: Dictionary={}
var history_peak_ms:=0.0
var history_error:=""
var history_static_fallbacks:=0
var history_static_suppressed:=0
var history_input_rows:=0
var history_input_reused:=0
var history_planes: Array=[]
var history_view_tests:=0
var history_draw_ids: Dictionary={}
var history_static_ids: Dictionary={}
var history_publication_owner: Variant=null
var member_order_serial:=0
var dirty_light_inputs: Dictionary={}
var light_bounds: Dictionary={}
var mobile_light_inputs: Dictionary={}
var native_fade_view:=false
var prefer_native_fade_view:=false
var _input_registry
func _init() -> void:
	configure_input_registry(OS.get_cmdline_user_args())
func configure_input_registry(arguments: PackedStringArray) -> bool:
	# Selection is fixed before any physical world/member/history binding.
	if world!=null or history!=null or not members.is_empty():return false
	if _input_registry!=null:_input_registry.close()
	_input_registry=InputRegistry.new()
	var accepted: bool=_input_registry.configure(arguments)
	prefer_native_fade_view=_input_registry.effective=="script" and not arguments.has("--light-fade-view=script")
	if not accepted:history_error=_input_registry.failure
	else:history_error=""
	return accepted
func input_registry_snapshot() -> Dictionary:
	var result: Dictionary=_input_registry.snapshot()
	result.history_enabled=history!=null
	result.native_fade_view=native_fade_view
	result.focus_counts={"registered":members.size(),"input_rows":history_input_rows,"reused":history_input_reused,"view_tests":history_view_tests}
	return result
func _input_registry_failure(reason: String) -> void:
	history_error=reason
	# A failed explicit native request never silently changes to script polling.
	if history!=null:disable_history()
	set_process(false)
func configure(owner: Node3D) -> void:
	if _input_registry.effective=="unavailable":history_error=_input_registry.failure;set_process(false);return
	world=owner; world.set_meta("native_focus_light_owner",weakref(self)); process_priority=100
	for light in world.get_tree().get_nodes_in_group("native_original_model_lights"):
		if world.is_ancestor_of(light): register(light)
	# Separate research candidate until native BSP collection is mapped. The
	# enhanced material switch alone does not silently replace world admission.
	if world.get_meta("native_enhanced_lighting",false) and OS.get_cmdline_user_args().has("--native-light-history"):
		var setting:=maximum_setting(OS.get_cmdline_user_args())
		if not str(setting.error).is_empty(): history_error=setting.error; push_error(history_error); return
		enable_history(int(setting.maximum))
static func maximum_setting(arguments: PackedStringArray) -> Dictionary:
	var maximum:=DEFAULT_MAXIMUM
	for argument in arguments:
		if not argument.begins_with("--native-max-lights="): continue
		var text:=argument.trim_prefix("--native-max-lights=")
		if not text.is_valid_int() or int(text)<0 or int(text)>128: return {"error":"Native maximum lights must be an integer from 0 through 128"}
		maximum=int(text)
	return {"error":"","maximum":maximum}
func enable_history(maximum: int=DEFAULT_MAXIMUM) -> void:
	if closed or history!=null: return
	if _input_registry.effective=="unavailable":history_error=_input_registry.failure;return
	if _input_registry.effective=="builtin":
		var reset: Dictionary=_input_registry.reset_publications()
		if reset.has("error"):_input_registry_failure(str(reset.error));return
	history=ClassDB.instantiate("NwnLightHistory"); history_maximum=clampi(maximum,0,128)
	history_rows.clear()
	history_planes.clear()
	light_bounds.clear(); mobile_light_inputs.clear()
	if _input_registry.effective=="script":
		for id in members: dirty_light_inputs[id]=true
	var initial: Dictionary=history.dispatch(0,{"enhanced":true,"request_fade_view_support":prefer_native_fade_view})
	native_fade_view=prefer_native_fade_view and bool(initial.get("fade_view_supported",false))
func disable_history() -> void:
	native_fade_view=false
	blind_light_owner=null
	if history!=null: history.dispatch(8,{}); history=null
	for entry in members.values():
		var light=entry.light.get_ref()
		if is_instance_valid(light): light.apply_native_admission(true,1.0)
	var environment: Node=history_environment.get_ref() if history_environment!=null else null
	if is_instance_valid(environment) and not area.is_empty():
		var policy=preload("res://systems/native_render/native_light_policy.gd")
		environment.apply_native_area_light(policy.linear_rgb(area.ambient.color),policy.linear_rgb(area.diffuse.color))
	history_rows.clear(); history_result.clear()
	light_bounds.clear(); mobile_light_inputs.clear()
	history_draw_ids.clear(); history_static_ids.clear(); history_publication_owner=null
func mark_light_input_changed(id: int) -> void:
	if not closed and _input_registry.effective=="script" and members.has(id):
		dirty_light_inputs[id]=true
func _refresh_light_input(id: int,planes: Array,changed_rows: Dictionary,removed: Array) -> void:
	var entry: Dictionary=members[id]
	var light: Node3D=entry.light.get_ref()
	var parent: Node3D=entry.parent.get_ref() if entry.parent!=null else null
	if not is_instance_valid(light) or not light.is_inside_tree() or (is_instance_valid(parent) and not parent.is_visible_in_tree()):
		if history_rows.erase(id): removed.append(id)
		light_bounds.erase(id); mobile_light_inputs.erase(id)
		return
	var props: Dictionary=light.native_properties
	# Area-radius lights belong to the area's separate ambient/diffuse channels.
	if props.is_empty() or not light.get_meta("native_enhanced_light",false) or float(props.get("radius",0))>=1000:
		if history_rows.erase(id): removed.append(id)
		light_bounds.erase(id); mobile_light_inputs.erase(id)
		return
	var position:=light.global_position
	var support:=float(light.native_state.get("range",0))
	var bounds:=Vector4(position.x,position.y,position.z,support)
	var row: Dictionary={
		"id":id,"owner":entry.owner_id,"position":native_point(position),
		"color":props.get("color",[0,0,0]),"radius":props.get("radius",0),
		"multiplier":props.get("multiplier",1),"priority":props.get("lightpriority",4),
		"dynamic":props.get("isdynamic",1),"affect":props.get("affectdynamic",1),
		"fading":props.get("fadinglight",1),"override":int(light.get_meta("native_light_priority",0))
	}
	if native_fade_view: row.fade_view_bounds=bounds
	else: row.in_view=_light_in_view(bounds,planes)
	light_bounds[id]=bounds
	var source: Node3D=entry.source.get_ref() if entry.source!=null else null
	if is_instance_valid(source) and source.has_meta("native_tile_index"): mobile_light_inputs.erase(id)
	else: mobile_light_inputs[id]=entry.light
	if history_rows.get(id)!=row:
		history_rows[id]=row
		changed_rows[id]=row
func _light_in_view(bounds: Vector4,planes: Array) -> bool:
	history_view_tests+=1
	var center:=Vector3(bounds.x,bounds.y,bounds.z)
	for plane: Plane in planes:
		if plane.distance_to(center)>bounds.w: return false
	return true
func history_frame(delta: float) -> void:
	if history==null or closed: return
	var began:=Time.get_ticks_usec(); var rows: Array=[]; var removed: Array=[]
	var view_began:=Timing.begin()
	var camera: Camera3D=history_camera.get_ref() if history_camera!=null else null
	var planes: Array=camera.get_frustum() if is_instance_valid(camera) else []
	var view_changed:=planes!=history_planes
	history_planes=planes
	Timing.finish("light_history_view_ms",view_began)
	if _input_registry.effective=="builtin":
		var poll_began:=Timing.begin()
		var update: Dictionary=_input_registry.poll(planes,view_changed)
		Timing.finish("light_history_input_poll_ms",poll_began)
		if update.has("error"):_input_registry_failure(str(update.error));return
		var apply_began:=Timing.begin()
		rows=update.rows;removed=update.removed
		for id in update.retired:members.erase(id)
		for id in removed:history_rows.erase(id)
		for row in rows:history_rows[int(row.id)]=row
		history_view_tests+=int(update.view_tests);history_input_rows+=rows.size();history_input_reused+=int(update.reused)
		Timing.finish("light_history_input_apply_ms",apply_began)
	else:
		var collect_began:=Timing.begin()
		var changed_rows: Dictionary={}
		var previous_count:=history_rows.size()
		# Actor and placeable motion can be written earlier in this same process
		# pass. Godot flushes its transform notifications after the pass.
		for id in mobile_light_inputs:
			if dirty_light_inputs.has(id): continue
			var light: Node3D=mobile_light_inputs[id].get_ref()
			var bounds: Vector4=light_bounds[id]
			if not is_instance_valid(light) or light.global_position!=Vector3(bounds.x,bounds.y,bounds.z):
				dirty_light_inputs[id]=true
		for id in dirty_light_inputs: _refresh_light_input(id,planes,changed_rows,removed)
		if view_changed and not native_fade_view:
			# A moving camera changes the plane test, not the authored lamp data.
			for id in light_bounds:
				if dirty_light_inputs.has(id): continue
				var row: Dictionary=history_rows[id]
				var in_view:=_light_in_view(light_bounds[id],planes)
				if in_view!=bool(row.in_view):
					row.in_view=in_view
					changed_rows[id]=row
		dirty_light_inputs.clear()
		rows=changed_rows.values()
		# New solver rows retain physical registration order for equal ranks,
		# even if visibility changes were delivered in a different order.
		if history_rows.size()+removed.size()>previous_count:
			rows.sort_custom(func(a,b):return int(members[int(a.id)].publication_order)<int(members[int(b.id)].publication_order))
		history_input_rows+=rows.size()
		history_input_reused+=history_rows.size()-rows.size()
		Timing.finish("light_history_script_collect_ms",collect_began)
	Timing.finish("light_history_registry",began); var solve_began:=Timing.begin()
	if not removed.is_empty(): history.dispatch(3,{"ids":removed})
	var input:={"lights":rows,"collect_radius":maxf(45.0,history_radius),"focus":native_point(focus),"delta":delta,"maximum":history_maximum}
	if native_fade_view and view_changed: input.fade_view_planes=planes
	var only_owner:=only_light_owner()
	input.only_owner=only_owner
	for name in ["ambient","diffuse"]:
		if area.has(name): input[name]={"color":area[name].color,"radius":1000000,"owner":0}
	history_result=history.dispatch(1,input)
	if native_fade_view and not history_result.has("error"):
		if history_result.has("fade_view_tests"): history_view_tests+=int(history_result.fade_view_tests)
		else: history_result={"error":"Native fade visibility requires the matching light history kernel"}
	Timing.finish("light_history_solver",solve_began); var publish_began:=Timing.begin()
	if history_result.has("error"):
		history_error=str(history_result.error); push_error(history_error); disable_history(); return
	var selected: Dictionary={}
	for call in history_result.calls:
		if call.kind=="draw": selected[int(call.id)]=float(call.fade)
	# Revisit only previous/current draws and changed/new rows. Nonselected
	# unchanged lamps already retain their last admission in the physical owner.
	var publication_ids: Dictionary=history_draw_ids.duplicate()
	for id in selected: publication_ids[id]=true
	for id in removed: history_static_ids.erase(id)
	for row in rows:
		var id:=int(row.id); publication_ids[id]=true
		if int(row.dynamic)==0 and int(row.affect)==0: history_static_ids[id]=true
		else: history_static_ids.erase(id)
	if history_publication_owner!=only_owner:
		for id in history_static_ids: publication_ids[id]=true
	history_publication_owner=only_owner
	history_static_fallbacks=history_static_ids.size() if only_owner==0 else 0
	history_static_suppressed=history_static_ids.size() if only_owner!=0 else 0
	var publication_order: Array=publication_ids.keys().filter(func(id):return history_rows.has(id) and members.has(id))
	# Preserve the existing physical registry's setter order, never notification
	# or native score order. Ineligible/hidden rows retain their prior own fade.
	publication_order.sort_custom(func(a,b):return int(members[a].publication_order)<int(members[b].publication_order))
	for id in publication_order:
		var light=members[id].light.get_ref()
		if not is_instance_valid(light): continue
		var row: Dictionary=history_rows[id]
		if int(row.dynamic)==0 and int(row.affect)==0:
			# Original static-only lamps light baked vertices, outside finite
			# dynamic slots. Keep their existing renderer contribution until that
			# separate bake path is implemented; do not black out static scenery.
			if only_owner!=0:
				# Static-only lamps never enter native finite collection; native
				# mesh baking is disabled while only-Gob lighting is active. The
				# temporary baseline fallback must not bypass that restriction.
				light.apply_native_admission(false,0.0)
			else: light.apply_native_admission(true,1.0)
		else: light.apply_native_admission(selected.has(id),float(selected.get(id,0)))
	history_draw_ids=selected
	var environment: Node=history_environment.get_ref() if history_environment!=null else null
	if is_instance_valid(environment) and not area.is_empty():
		var policy=preload("res://systems/native_render/native_light_policy.gd")
		var ambient: Array=area.ambient.color; var diffuse: Array=area.diffuse.color
		var ambient_fade: float=history_result.area_fades[0][0]; var diffuse_fade: float=history_result.area_fades[1][0]
		environment.apply_native_area_light(policy.linear_rgb(ambient.map(func(v):return policy.f(v*ambient_fade))),policy.linear_rgb(diffuse.map(func(v):return policy.f(v*diffuse_fade))))
	Timing.finish("light_history_publication",publish_began)
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0; history_peak_ms=maxf(history_peak_ms,elapsed); Timing.record("callback_light_history",elapsed)
func register(light: Node3D) -> void:
	if closed: return
	var parent:=light.get_parent()
	var source:=parent
	while source!=null and source!=world and not source.get_meta("native_light_source",false): source=source.get_parent()
	var id:=light.get_instance_id(); var order: int
	if members.has(id): order=int(members[id].publication_order)
	else: order=member_order_serial; member_order_serial+=1
	var owner_id:=source.get_instance_id() if source!=null and source!=world else 0
	if members.has(id): _disconnect_light_parent(members[id])
	var parent_3d:=parent as Node3D
	# Each sibling needs its own callback when several lamps share the parent.
	var changed:=func(): mark_light_input_changed(id)
	members[id]={"light":weakref(light),"source":weakref(source) if owner_id!=0 else null,"owner_id":owner_id,
		"publication_order":order,"parent":weakref(parent_3d) if parent_3d!=null else null,"changed":changed}
	light.focus_owner=weakref(self)
	if _input_registry.effective=="builtin":
		var result: Dictionary=_input_registry.register_light(id,owner_id)
		if result.has("error"):_input_registry_failure(str(result.error))
	else:
		if parent_3d!=null: parent_3d.visibility_changed.connect(changed)
		mark_light_input_changed(id)
func _disconnect_light_parent(entry: Dictionary) -> void:
	var parent: Node3D=entry.parent.get_ref() if entry.parent!=null else null
	if is_instance_valid(parent) and parent.visibility_changed.is_connected(entry.changed):
		parent.visibility_changed.disconnect(entry.changed)
func unregister(light: Node3D) -> void:
	var id:=light.get_instance_id()
	if not closed and _input_registry.effective=="builtin":
		var result: Dictionary=_input_registry.erase_light(id)
		if result.has("error"):_input_registry_failure(str(result.error))
	if history!=null: history.dispatch(3,{"ids":[id]})
	if members.has(id): _disconnect_light_parent(members[id])
	members.erase(id)
	dirty_light_inputs.erase(id); light_bounds.erase(id); mobile_light_inputs.erase(id); history_rows.erase(id)
	history_draw_ids.erase(id); history_static_ids.erase(id)
func set_controlled(owner: Node3D) -> void: controlled=weakref(owner) if is_instance_valid(owner) else null
func set_blind_lights(owner: Node3D=null) -> bool:
	# Scene::SetBlindLights sets the exact physical Gob identity, not a race,
	# effect ID, logical character ID or every attached visual model. Its caller
	# policy remains separate; do not infer blindness from a vision light model.
	if closed or (owner!=null and (not is_instance_valid(owner) or not is_instance_valid(world) or not world.is_ancestor_of(owner))): return false
	if owner!=null and not owner.get_meta("native_light_source",false): return false
	if owner!=null and not world.get_meta("native_enhanced_lighting",false): return false
	blind_light_owner=weakref(owner) if owner!=null else null
	if owner!=null: enable_history(history_maximum)
	return true
func only_light_owner() -> int:
	var owner: Node3D=blind_light_owner.get_ref() if blind_light_owner!=null else null
	return owner.get_instance_id() if is_instance_valid(owner) and owner.is_inside_tree() and is_instance_valid(world) and world.is_ancestor_of(owner) else 0
func set_area(ambient: Array,diffuse: Array) -> void:
	if not area.is_empty() and area.ambient.color==ambient and area.diffuse.color==diffuse: return
	area={"ambient":{"color":ambient.duplicate(),"fade":1.0},"diffuse":{"color":diffuse.duplicate(),"fade":1.0}}
func view_gate() -> bool:
	if closed: return false
	requested=true
	return gate.select(value,is_instance_valid(world) and not closed)
func own_light(actor: Node3D,light: Node3D,source: Node3D) -> bool:
	if actor==null: return false
	if actor==light or actor.is_ancestor_of(light): return true
	var visited: Dictionary={}
	while is_instance_valid(source) and not visited.has(source.get_instance_id()):
		visited[source.get_instance_id()]=true
		var reference: WeakRef=source.get_meta("native_light_anchor") if source.has_meta("native_light_anchor") else null
		var anchor: Node3D=reference.get_ref() if reference!=null else null
		if not is_instance_valid(anchor): return false
		if actor==anchor or actor.is_ancestor_of(anchor): return true
		source=anchor
		while source!=null and source!=world and not source.get_meta("native_light_source",false): source=source.get_parent()
	return false
static func native_point(point: Vector3) -> Array: return [point.x,-point.z,point.y]
func particle_lighting() -> Dictionary:
	# Original RenderEmitter passes no exclusion list. In particular, attached
	# lamps must not use the vision gate's own-character exclusion rule.
	var input: Dictionary=area.duplicate(true); var rows: Array=[]
	var ids: Array=members.keys()
	if history!=null:
		ids=[]
		for call in history_result.get("calls",[]):
			if call.kind=="draw": ids.append(int(call.id))
	for id in ids:
		if not members.has(id): continue
		var light: Node3D=members[id].light.get_ref()
		if not is_instance_valid(light) or not light.is_inside_tree() or not light.is_visible_in_tree(): continue
		var properties: Dictionary=light.get_meta("native_model_light_properties",{})
		if properties.is_empty(): continue
		rows.append({"position":native_point(light.global_position),"color":properties.get("color",[0,0,0]),"radius":properties.get("radius",0),"fade":light.get_meta("native_light_fade",1.0)})
	input.lights=rows
	if history!=null and history_result.has("area_fades"):
		for index in 2:
			var name: String=["ambient","diffuse"][index]
			if input.has(name): input[name].fade=history_result.area_fades[index][0]
	return input
func cx_particle_sun() -> DirectionalLight3D:
	var environment=history_environment.get_ref() if history_environment!=null else null
	return environment.sunlight if is_instance_valid(environment) else null
func cx_particle_lighting() -> PackedByteArray:
	var packed:=PackedFloat32Array()
	var shadow_identities: Dictionary={}
	var ids: Dictionary=members if history==null else history_draw_ids
	packed.resize(12+12*ids.size())
	var offset:=12
	for id in ids:
		if not members.has(id): continue
		var light: Node3D=members[id].light.get_ref()
		if not is_instance_valid(light) or not light.is_visible_in_tree(): continue
		var state: Variant=light.get("native_state")
		if not state is Dictionary or state.is_empty():
			var properties: Dictionary=light.get_meta("native_model_light_properties",{})
			if properties.is_empty(): continue
			state=LightPolicy.point(properties,2.0,0.2,1.5,float(light.get_meta("native_light_fade",1.0)))
		if not state.enabled: continue
		var position:=light.global_position
		var color: Vector3=state.color
		packed[offset]=position.x
		packed[offset+1]=position.y
		packed[offset+2]=position.z
		packed[offset+3]=state.range
		packed[offset+4]=color.x
		packed[offset+5]=color.y
		packed[offset+6]=color.z
		packed[offset+7]=1.0 if state.ambient else 0.0
		packed[offset+8]=state.inverse
		packed[offset+9]=state.factor
		if light is OmniLight3D and light.shadow_enabled and not state.ambient:
			shadow_identities[(offset+10)*4]=light.get_base().get_id()
		offset+=12
	if area.is_empty() and offset==12: return PackedByteArray()
	packed.resize(offset)
	packed[3]=1.0
	packed[7]=float(shadow_identities.size())
	packed[11]=float(offset-12)/12.0
	var fades: Array=history_result.get("area_fades",[])
	var sun:=cx_particle_sun()
	var direction:=Vector3.ZERO
	if is_instance_valid(sun) and sun.light_energy>0.0: direction=sun.global_basis.z.normalized()
	packed[8]=direction.x
	packed[9]=direction.y
	packed[10]=direction.z
	if not area.is_empty():
		for index in 2:
			var channel: Array=area.ambient.color if index==0 else area.diffuse.color
			var fade: float=fades[index][0] if index<fades.size() else 1.0
			for axis in 3: packed[index*4+axis]=LightPolicy.linear(float(channel[axis])*fade)
	var bytes:=packed.to_byte_array()
	for address in shadow_identities: bytes.encode_u64(int(address),int(shadow_identities[address]))
	return bytes
func refresh() -> void:
	if closed or not is_instance_valid(world): return
	var began:=Time.get_ticks_usec(); var actor: Node3D=controlled.get_ref() if controlled!=null else null
	var rows: Array=[]; var excluded: Array=[]
	var ids: Array=members.keys()
	if history!=null:
		ids=[]
		for call in history_result.get("calls",[]):
			if call.kind=="draw": ids.append(int(call.id))
	for id in ids:
		if not members.has(id): continue
		var entry: Dictionary=members[id]; var light: Node3D=entry.light.get_ref()
		if not is_instance_valid(light): members.erase(id); continue
		if not light.is_inside_tree() or not light.is_visible_in_tree(): continue
		var properties: Dictionary=light.get_meta("native_model_light_properties",{})
		if properties.is_empty(): continue
		var source: Node3D=entry.source.get_ref() if entry.source!=null else null
		if own_light(actor,light,source): excluded.append(rows.size())
		rows.append({"position":native_point(light.global_position),"color":properties.get("color",[0,0,0]),"radius":properties.get("radius",0),"fade":light.get_meta("native_light_fade",1.0)})
	var input: Dictionary=area.duplicate(true); input.point=native_point(focus); input.lights=rows; input.excluded=excluded
	if history!=null and history_result.has("area_fades"):
		for index in 2:
			var name: String=["ambient","diffuse"][index]
			if input.has(name): input[name].fade=history_result.area_fades[index][0]
	value=Sample.sample(input); samples+=1; sampled_lights=rows.size(); excluded_lights=excluded.size()
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0; peak_ms=maxf(peak_ms,elapsed)
	Timing.record("callback_focus_lighting",elapsed); Timing.count("count_focus_sample_lights",sampled_lights)
func _process(_delta: float) -> void:
	history_frame(_delta)
	if not requested or closed: return
	requested=false; refresh()
func snapshot() -> Dictionary:
	var result: Dictionary={"sample":[value.x,value.y,value.z],"active":gate.active,"samples":samples,"lights":sampled_lights,"excluded":excluded_lights,"registered":members.size(),"only_light_owner":only_light_owner(),"peak_ms":peak_ms,"closed":closed,"history":{"enabled":history!=null,"maximum":history_maximum,"radius":history_radius,"steps":history_result.get("steps",0),"active":history_result.get("active0",[]).size(),"static_fallbacks":history_static_fallbacks,"static_suppressed":history_static_suppressed,"input_rows":history_input_rows,"reused_input_rows":history_input_reused,"view_tests":history_view_tests,"peak_ms":history_peak_ms,"error":history_error},"admission":"Original dynamic sphere collection/priority/fades (research switch); static-only lamps retain baseline pending vertex bake; special view plane pending" if history!=null else "Current world lamp registry; original main-world history not selected"}
	result.light_input_registry=input_registry_snapshot()
	result.input_registry_class=result.light_input_registry["class"]
	return result
func close() -> void:
	_input_registry.close()
	if history!=null: history.dispatch(8,{}); history=null
	for entry in members.values(): _disconnect_light_parent(entry)
	closed=true; requested=false; members.clear(); controlled=null; blind_light_owner=null; set_process(false)
	dirty_light_inputs.clear(); light_bounds.clear(); mobile_light_inputs.clear(); history_rows.clear()
	history_draw_ids.clear(); history_static_ids.clear(); history_publication_owner=null
	if is_instance_valid(world) and world.has_meta("native_focus_light_owner"): world.remove_meta("native_focus_light_owner")
func _exit_tree() -> void: close()
