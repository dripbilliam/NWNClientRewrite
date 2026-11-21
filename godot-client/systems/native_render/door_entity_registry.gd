extends "res://systems/entity_registry.gd"
# Selection subset only. Authoritative entities still belong to World, and
# existing target/floor physics still belong to the base selection registry.
var _door_targets: Dictionary={}
func register_native(id: int,row: Dictionary,instance) -> bool:
	var changed:=super.register_native(id,row,instance)
	if entities.has(id) and row.get("eligible",false) and int(row.get("type",-1))==10 and is_instance_valid(instance) and instance.has_method("native_door_pick"):
		if not _door_targets.has(id) or _door_targets[id].get_ref()!=instance:_door_targets[id]=weakref(instance)
	else:_door_targets.erase(id)
	return changed
func forget_entity(id: int) -> bool:
	_door_targets.erase(id)
	return super.forget_entity(id)
func pick(camera: Camera3D,screen: Vector2) -> Dictionary:
	var best:=super.pick(camera,screen)
	var origin:=camera.project_ray_origin(screen)
	var end: Vector3=best.position if best.get("position") is Vector3 else origin+camera.project_ray_normal(screen)*camera.far
	var distance:=origin.distance_squared_to(end)
	# Pointer picking already runs at a bounded cadence. Visit only admitted
	# doors, never scan or copy the client-known world on each frame.
	for id in _door_targets:
		var owner: Node3D=_door_targets[id].get_ref() as Node3D
		if not is_instance_valid(owner) or native_owners.get(id)!=owner or not entities.get(id,{}).get("eligible",false):continue
		var hit: Dictionary=owner.call("native_door_pick",origin,end)
		if not hit.get("available",false) or not hit.get("hit",false):continue
		var next_distance:=origin.distance_squared_to(hit.position)
		if not best.is_empty() and next_distance>=distance:continue
		end=hit.position;distance=next_distance
		best={"id":int(id),"position":end,"entity":entities[id],"native_door_region":{"part":hit.part,"face":hit.face}}
	return best
