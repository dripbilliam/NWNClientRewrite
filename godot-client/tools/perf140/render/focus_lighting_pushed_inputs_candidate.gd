extends "res://systems/native_render/focus_lighting.gd"
# Unimported candidate. Property/lifecycle/visibility/position polling is native;
# native history and the source-pinned solver/publication tail remain identical.
var input_registry: RefCounted
func _init() -> void: input_registry=ClassDB.instantiate("NwnLightInputRegistry")
func register(light: Node3D) -> void:
	if closed:return
	super.register(light)
	var id:=light.get_instance_id();var entry:Dictionary=members[id]
	var source=entry.source.get_ref() if entry.source!=null else null
	var result:Dictionary=input_registry.call("dispatch",0,{"id":id,"source":source.get_instance_id() if is_instance_valid(source) else 0})
	if result.has("error"):history_error=str(result.error);push_error(history_error)
	elif light.has_method("bind_native_input_registry"):light.bind_native_input_registry(input_registry)
func unregister(light: Node3D) -> void:
	if light.has_method("bind_native_input_registry"):light.bind_native_input_registry(null)
	if input_registry!=null:input_registry.call("dispatch",2,{"id":light.get_instance_id()})
	super.unregister(light)
func enable_history(maximum:int=DEFAULT_MAXIMUM) -> void:
	if closed or history!=null:return
	input_registry.call("dispatch",4,{})
	super.enable_history(maximum)
func close() -> void:
	super.close()
	if input_registry!=null:input_registry.call("dispatch",8,{});input_registry=null
func history_frame(delta:float) -> void:
	if history==null or closed:return
	var began:=Time.get_ticks_usec()
	var camera:Camera3D=history_camera.get_ref() if history_camera!=null else null
	var planes:Array=camera.get_frustum() if is_instance_valid(camera) else []
	var view_changed:bool=planes!=history_planes;history_planes=planes
	var update:Dictionary=input_registry.call("dispatch",1,{"planes":planes,"view_changed":view_changed})
	if update.has("error"):history_error=str(update.error);push_error(history_error);disable_history();return
	var rows:Array=update.rows;var removed:Array=update.removed
	for id in update.retired:members.erase(id)
	for id in removed:history_rows.erase(id)
	for row in rows:history_rows[int(row.id)]=row
	history_view_tests+=int(update.view_tests);history_input_rows+=rows.size();history_input_reused+=int(update.reused)
	Timing.finish("light_history_registry",began); var solve_began:=Timing.begin()
	if not removed.is_empty(): history.dispatch(3,{"ids":removed})
	var input:={"lights":rows,"collect_radius":maxf(45.0,history_radius),"focus":native_point(focus),"delta":delta,"maximum":history_maximum}
	var only_owner:=only_light_owner()
	input.only_owner=only_owner
	for name in ["ambient","diffuse"]:
		if area.has(name): input[name]={"color":area[name].color,"radius":1000000,"owner":0}
	history_result=history.dispatch(1,input)
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
