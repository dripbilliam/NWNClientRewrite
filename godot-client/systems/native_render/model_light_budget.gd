extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Godot owns its shadow map allocation; the authored model-light selection and
# two original shadow passes are retained here before map publication.
const Priority=preload("res://systems/native_data/light_priority.gd")
var use_engine_group_order:=not OS.get_cmdline_user_args().has("--shadow-group-order=script")
var camera: Camera3D
var focus_query: Callable
var selection_origin:=Vector3.ZERO
var origin_source:="unavailable"
var selected_lights: Array=[]
var eligible:=0
var model_shadow_requested:=0
var model_policy_limited:=0
var maximum:=0
var active:=0
var lights:=0
var _root: WeakRef
var _previous: Array=[[],[]]
var _fades: Dictionary={}
var _opacity: Dictionary={}
var _native_state: Dictionary={}
func _init() -> void:process_priority=101 # Light admission publishes at 100 first.
func snapshot() -> Dictionary:
	return {"configured_maximum":maximum,"maximum":clampi(maximum,0,3),"active":active,"lights":lights,"eligible":eligible,"model_shadow_requested":model_shadow_requested,"model_policy_limited":model_policy_limited,"origin":[selection_origin.x,selection_origin.y,selection_origin.z],"origin_source":origin_source,"selected":selected_lights.duplicate(true),"native":_native_state.duplicate(true),"policy":"Original model-light priority, dynamic/normal shadow passes and shared fades; Godot owns hardware shadow-map admission"}
func _process(delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(delta)
	Timing.finish("callback_lights",began)
func _ordered_lights(scope: Node) -> Array:
	var nodes: Array = []
	# The group includes lights from previews and other worlds. Filter by the
	# live parent before assigning shadow slots.
	for light in get_tree().get_nodes_in_group("native_original_model_lights"):
		if is_instance_valid(scope) and scope.is_ancestor_of(light):
			nodes.append(light)
	# Godot sorts the group with b.is_greater_than(a). Reverse that order
	# to retain the shadow budget's existing a.is_greater_than(b) tie order.
	if use_engine_group_order:
		nodes.reverse()
		Timing.count("count_shadow_group_order_reused", nodes.size())
	else:
		nodes.sort_custom(func(a,b):return a.is_greater_than(b))
	return nodes
func _profile_process(delta: float) -> void:
	Timing.count("count_model_lights",lights); Timing.count("count_point_shadows",active)
	var focus: Dictionary=focus_query.call() if focus_query.is_valid() else {}
	var available: bool=focus.get("position") is Vector3 and focus.position.is_finite()
	if not available and is_instance_valid(camera) and camera.global_position.is_finite():
		focus={"position":camera.global_position,"source":"camera-fallback"};available=true
	origin_source=str(focus.get("source","unavailable"))
	if available:selection_origin=focus.position
	var native_focus: Array=[selection_origin.x,-selection_origin.z,selection_origin.y]
	var candidates: Array=[]; var scope:=get_parent()
	if _root==null or _root.get_ref()!=scope:
		_reset_selection()
		_root=weakref(scope) if is_instance_valid(scope) else null
	var nodes := _ordered_lights(scope)
	lights=nodes.size()
	# setAreaLighting traverses the loaded area once. The gate tags its current
	# lights and the first matching model from its already received population;
	# later scene births and replacement models have no such tag.
	var capture_epoch:=int(scope.get_meta("native_area_model_shadow_capture_epoch",-1)) if is_instance_valid(scope) else -1
	if capture_epoch>=0:
		var area_opacity:=clampf(float(scope.get_meta("native_initial_area_shadow_opacity",1.0)),0.0,1.0)
		for light in nodes:
			if not light.get_meta("native_shadow_requested",false) or int(light.get_meta("native_initial_area_shadow_epoch",-1))!=capture_epoch or int(light.get_meta("native_initial_area_shadow_applied_epoch",-1))==capture_epoch:continue
			var id: int=light.get_instance_id()
			if _opacity.has(id):
				var previous: Dictionary=_opacity[id]
				previous.requested=area_opacity
				_opacity[id]=previous
			light.shadow_opacity=area_opacity
			light.set_meta("native_initial_area_shadow_applied_epoch",capture_epoch)
	var present: Dictionary={};var order:=0
	model_shadow_requested=0
	for light in nodes:
		var id: int=light.get_instance_id()
		if light.is_visible_in_tree():present[id]=true
		if not available or not light.is_visible_in_tree() or not light.get_meta("native_shadow_requested",false):continue
		if is_instance_valid(camera) and (light.layers&camera.cull_mask)==0:continue
		model_shadow_requested+=1
		var properties: Dictionary=light.get_meta("native_model_light_properties",{})
		var colour: Array=properties.get("color",[1,1,1])
		if float(properties.get("ambientonly",0))!=0 or colour.size()<3 or not (Priority.f(float(colour[0]))>Priority.f(0.1) or Priority.f(float(colour[1]))>Priority.f(0.1) or Priority.f(float(colour[2]))>Priority.f(0.1)):continue
		var p: Vector3=light.global_position;var source: Node=light.get_parent();var generated_id:=-1
		while source!=null and source!=scope:
			if source.has_meta("native_generated_placeable_id"):generated_id=int(source.get_meta("native_generated_placeable_id"))
			if source.get_meta("native_light_source",false):break
			source=source.get_parent()
		var score:=Priority.rank(properties,[p.x,-p.z,p.y],native_focus,int(light.get_meta("native_light_priority",0)),is_instance_valid(source) and source.get_instance_id()==int(focus.get("only_owner",0)))
		var support:=float(properties.get("shadowradius",0))
		if support<=0:support=float(properties.get("radius",0))
		candidates.append({"light":light,"priority":float(score.priority),"distance":float(score.distance),"radius":support,"dynamic":float(properties.get("isdynamic",0))!=0,"order":order,"id":id,"placeable_id":generated_id,"position":[p.x,p.y,p.z]})
		order+=1
	for id in _fades.keys():
		if not present.has(id):_fades.erase(id)
	for mode in 2:
		_previous[mode]=_previous[mode].filter(func(id):return present.has(id))
	candidates.sort_custom(func(a,b):return a.priority<b.priority if a.priority!=b.priority else a.order<b.order)
	eligible=candidates.size();selected_lights=[]
	var limit:=clampi(maximum,0,3)
	# main.js:408 passes min(frameDelta,0.1) to the old budget once the
	# simulation is ready; the native shadow selector itself is unclamped.
	var step:=minf(maxf(delta,0),0.1) if is_finite(delta) else 0.0
	# GetShadowLights runs dynamic mode before the ordinary mode, sharing fades.
	_previous[1]=_select(candidates,_previous[1],limit,1,step)
	_previous[0]=_select(candidates,_previous[0],limit,0,step)
	var selected: Dictionary={}
	for mode in [1,0]:
		for id in _previous[mode]:selected[id]=true
	active=selected.size()
	model_policy_limited=maxi(0,model_shadow_requested-active)
	for entry in candidates:
		if selected.has(entry.id):selected_lights.append({"id":entry.id,"placeable_id":entry.placeable_id,"priority":entry.priority,"distance":entry.distance,"position":entry.position})
	_native_state={"maximum":limit,"eligible":eligible,"normal":_previous[0].size(),"dynamic":_previous[1].size(),"selected":active}
	for light in nodes:
		# traverseVisible skips hidden lights, while a visible light outside the
		# camera's layers remains tracked but is not changed by the old budget.
		if not light.is_visible_in_tree() or is_instance_valid(camera) and (light.layers&camera.cull_mask)==0:continue
		var id: int=light.get_instance_id();var enabled:=selected.has(id)
		var opacity: Dictionary=_opacity.get(id,{})
		if opacity.is_empty():opacity={"light":weakref(light),"requested":light.shadow_opacity,"applied":light.shadow_opacity,"shadow_requested":light.shadow_enabled,"shadow_applied":light.shadow_enabled}
		else:
			if light.shadow_opacity!=float(opacity.applied):opacity.requested=light.shadow_opacity
			if light.shadow_enabled!=bool(opacity.shadow_applied):opacity.shadow_requested=light.shadow_enabled
		var applied:=Priority.f(float(opacity.requested)*float(_fades.get(id,0))) if enabled else float(opacity.requested)
		if light.shadow_opacity!=applied:light.shadow_opacity=applied
		# This is the raw pre-budget flag. The authored request metadata is an
		# override for admission and must not replace the value restored on exit.
		if light.shadow_enabled!=enabled: light.shadow_enabled=enabled
		opacity.applied=applied;opacity.shadow_applied=enabled;_opacity[id]=opacity
	for id in _opacity.keys():
		if present.has(id):continue
		_restore_light(_opacity[id])
		_opacity.erase(id)

func _select(candidates: Array,previous: Array,limit: int,mode: int,delta: float) -> Array:
	var chosen: Array=[]
	if limit>0:
		for row in candidates:
			if mode==1 and not bool(row.dynamic):continue
			if float(row.distance)<=float(row.radius):
				chosen.append(int(row.id))
				if mode==1 or chosen.size()>=limit:break
	var before:=previous.duplicate()
	for id in chosen:
		if not before.has(id):_fades[id]=0.0
	for id in before.slice(0,limit):
		if chosen.has(id):continue
		var fade:=Priority.f(maxf(0,Priority.f(Priority.f(float(_fades.get(id,0)))-Priority.f(Priority.f(Priority.f(delta)*2.0)/Priority.f(0.3)))))
		_fades[id]=fade
		if fade>0:chosen.push_front(id)
	if chosen.size()>limit:chosen.resize(limit)
	for id in chosen:_fades[id]=Priority.f(minf(1,Priority.f(Priority.f(float(_fades.get(id,0)))+Priority.f(Priority.f(delta)/Priority.f(0.3)))))
	return chosen

func _restore_light(state: Dictionary) -> void:
	var light: OmniLight3D=state.light.get_ref()
	if not is_instance_valid(light):return
	if light.shadow_opacity==float(state.applied):light.shadow_opacity=float(state.requested)
	if light.shadow_enabled==bool(state.shadow_applied):light.shadow_enabled=bool(state.shadow_requested)

func _reset_selection() -> void:
	for state in _opacity.values():_restore_light(state)
	_previous=[[],[]];_fades.clear();_opacity.clear();_native_state.clear()
	selected_lights.clear();eligible=0;model_shadow_requested=0;model_policy_limited=0;active=0;lights=0

func _exit_tree() -> void:_reset_selection()
