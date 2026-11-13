extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# The map count remains a scene-wide Godot approximation. Rank at the player,
# using original authored priorities and shadow support, never the orbit eye.
const Priority=preload("res://systems/native_data/light_priority.gd")
var camera: Camera3D
var focus_query: Callable
var selection_origin:=Vector3.ZERO
var origin_source:="unavailable"
var selected_lights: Array=[]
var eligible:=0
var maximum:=0
var elapsed:=1.0
var active:=0
var lights:=0
func snapshot() -> Dictionary:
	return {"configured_maximum":maximum,"maximum":clampi(maximum,0,4),"active":active,"lights":lights,"eligible":eligible,"origin":[selection_origin.x,selection_origin.y,selection_origin.z],"origin_source":origin_source,"selected":selected_lights.duplicate(true),"policy":"Player-focus original light ranking/support within a scene-wide Godot map budget; original per-pass/stencil/fades pending"}
func _process(delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(delta)
	Timing.finish("callback_lights",began)
func _profile_process(delta: float) -> void:
	Timing.count("count_model_lights",lights); Timing.count("count_point_shadows",active)
	elapsed+=delta
	if elapsed<0.2: return
	elapsed=0
	var focus: Dictionary=focus_query.call() if focus_query.is_valid() else {"position":camera.global_position,"source":"preview-camera"} if is_instance_valid(camera) else {}
	origin_source=str(focus.get("source","unavailable"))
	var available: bool=focus.get("position") is Vector3 and focus.position.is_finite()
	if available:selection_origin=focus.position
	var native_focus: Array=[selection_origin.x,-selection_origin.z,selection_origin.y]
	var candidates: Array=[]; var nodes: Array=[]; var scope:=get_parent()
	# A retiring/hidden world or a private preview must never steal this world's
	# shadow slots merely because its lamps share the SceneTree group.
	for light in get_tree().get_nodes_in_group("native_original_model_lights"):
		if is_instance_valid(scope) and scope.is_ancestor_of(light): nodes.append(light)
	lights=nodes.size()
	for light in nodes:
		if not available or not light.is_visible_in_tree() or not light.get_meta("native_shadow_requested",false):continue
		var properties: Dictionary=light.get_meta("native_model_light_properties",{})
		if not Priority.casts(properties):continue
		var p: Vector3=light.global_position;var source: Node=light.get_parent();var generated_id:=-1
		while source!=null and source!=scope:
			if source.has_meta("native_generated_placeable_id"):generated_id=int(source.get_meta("native_generated_placeable_id"))
			if source.get_meta("native_light_source",false):break
			source=source.get_parent()
		var score:=Priority.rank(properties,[p.x,-p.z,p.y],native_focus,int(light.get_meta("native_light_priority",0)),is_instance_valid(source) and source.get_instance_id()==int(focus.get("only_owner",0)))
		var support:=float(properties.get("shadowradius",0))
		if support<=0:support=float(properties.get("radius",0))
		if float(score.distance)>support:continue
		candidates.append({"light":light,"priority":float(score.priority),"distance":float(score.distance),"id":light.get_instance_id(),"placeable_id":generated_id,"position":[p.x,p.y,p.z]})
	candidates.sort_custom(func(a,b):return a.priority<b.priority if a.priority!=b.priority else a.id<b.id)
	eligible=candidates.size();selected_lights=[]
	active=mini(clampi(maximum,0,4),candidates.size())
	var selected: Dictionary={}
	for index in active:
		var entry: Dictionary=candidates[index];selected[entry.id]=true
		selected_lights.append({"id":entry.id,"placeable_id":entry.placeable_id,"priority":entry.priority,"distance":entry.distance,"position":entry.position})
	for light in nodes:
		var enabled:=selected.has(light.get_instance_id())
		if light.shadow_enabled!=enabled: light.shadow_enabled=enabled
