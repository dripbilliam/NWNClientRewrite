extends RefCounted
var client
var stopped := false
func stop() -> void: stopped = true
func run(value, message: Dictionary) -> void:
	client = value
	var checks: Array = []
	await client.get_tree().physics_frame
	var registry = client.owner_scene.registry
	var camera: Camera3D = client.owner_scene.camera
	var found := -1
	var point := Vector2.ZERO
	var samples: Array = []
	for id in registry.eligible_ids():
		if int(registry.entities[id].get("type",-1)) != 7: continue
		var center: Vector3 = registry.bounds[id].get_center()
		var size: Vector3 = registry.bounds[id].size
		# Persisted camera/chat positions can cover the polygon's exact center.
		# Find a real unobscured face; never bypass the normal menu/input guard.
		for offset in [Vector2.ZERO,Vector2(-.4,-.4),Vector2(0,-.4),Vector2(.4,-.4),Vector2(-.4,0),Vector2(.4,0),Vector2(-.4,.4),Vector2(0,.4),Vector2(.4,.4)]:
			point = camera.unproject_position(center+Vector3(offset.x*size.x,0,offset.y*size.z))
			var picked: Dictionary = registry.pick(camera,point)
			var blocked: bool = client.owner_scene.world_input.extra_pointer_block.call(point)
			samples.append({"id":id,"point":[point.x,point.y],"center":[center.x,center.y,center.z],"hitId":picked.get("id",-1),"hitPoint":str(picked.get("position")),"camera":str(camera.global_position),"menuBlocked":blocked})
			if int(picked.get("id",-1)) == id and not blocked: found = id; break
		if found >= 0: break
	checks.append({"name":"Real replicated transition has native pick geometry", "passed":found >= 0})
	if found >= 0:
		registry.mark([found])
		checks.append({"name":"Transition highlights without inventing a model", "passed":registry.marked.has(found)})
		checks.append({"name":"Portal pointer is outside all native menus", "passed":not client.owner_scene.world_input.extra_pointer_block.call(point)})
	checks.append({"name":"Previous world owners have actually been freed", "passed":client.retired_world_refs.all(func(row): return row.get_ref() == null)})
	if found >= 0 and not message.get("final",false):
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point
		client.owner_scene.world_input._unhandled_input(event); client.owner_scene.world_input._physics_process(.1)
		checks.append({"name":"Actual native left click resolves the portal logical ID", "passed":client.owner_scene.world_input.last_hit.get("id",-1) == found})
	if stopped: return
	client.send({"kind":"portal-region-tested","connection":client.connection,"areaId":message.areaId,"generation":message.generation,"result":{"checks":checks,"samples":samples,"completed":checks.all(func(row): return row.passed),"portalId":found,"final":message.get("final",false)}})
