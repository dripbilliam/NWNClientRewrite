extends Node
# Keep the capture's point-shadow budget; retain every original light/color.
var camera: Camera3D
var maximum:=0
var elapsed:=1.0
var active:=0
var lights:=0
func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<0.2 or not is_instance_valid(camera): return
	elapsed=0
	var candidates: Array=[]; var nodes:=get_tree().get_nodes_in_group("native_original_model_lights"); lights=nodes.size()
	for light in nodes:
		if light.visible and light.get_meta("native_shadow_requested",false): candidates.append(light)
	candidates.sort_custom(func(a,b): return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	active=mini(clampi(maximum,0,4),candidates.size())
	var selected: Dictionary={}
	for index in active: selected[candidates[index].get_instance_id()]=true
	for light in nodes:
		var enabled:=selected.has(light.get_instance_id())
		if light.shadow_enabled!=enabled: light.shadow_enabled=enabled
