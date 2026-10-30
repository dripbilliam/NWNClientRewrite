extends "res://tests/native_projectile_scene_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
class StaticModel extends Model:
	func retire() -> void: queue_free()
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var geometry:=Geometry.new(); geometry.configure({"vertices":PackedFloat32Array([0,0,0,2,0,0,0,2,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	for i in 100:
		var model:=StaticModel.new(); world.add_child(model)
		var mesh:=MeshInstance3D.new(); model.add_child(mesh); mesh.mesh=ArrayMesh.new(); mesh.mesh.set_meta("native_scene_geometry",geometry); model.meshes=[mesh]
		model.set_meta("native_scene_bounds",AABB(Vector3(0,0,-2),Vector3(2,0,2)))
		world.instances[i]=model; world.desired[i]={"key":"test","object":{"objectType":9,"staticState":{"position":[(i%10)*10,int(i/10)*10,0.25*(i%4)]}}}; world.apply_pose(i)
	for i in 100:
		for delta in [0.0,0.25,9.9]:
			var a: Array=[(i%10)*10+delta,int(i/10)*10+0.25,5.0]; var b: Array=[a[0]+0.000001,a[1],-5.0]
			check(Query.trace(world,a,b,true,true)==Query.trace(world,a,b,true,false),"Static index agrees with exhaustive physical queries "+str(i)+"/"+str(delta))
	var node: Node3D=world.instances[0]; var a: Array=[0.25,0.25,5.0]; var b: Array=[0.25,0.25,-5.0]
	check(Query.trace(world,a,b,true,true).hit,"Initial cached static hit")
	world.desired[0].object.staticState.position=[150,150,2]; world.apply_pose(0)
	check(not Query.trace(world,a,b,true,true).hit,"Same-frame authoritative pose invalidates old cell cache")
	a=[150.25,150.25,5.0]; b=[150.25,150.25,-5.0]
	check(Query.trace(world,a,b,true,true)==Query.trace(world,a,b,true,false) and Query.trace(world,a,b,true,true).hit,"Moved static is hittable in its new cell")
	world.desired[0].object.staticState.orientation={"yaw":90}; world.apply_pose(0)
	check(Query.trace(world,a,b,true,true)==Query.trace(world,a,b,true,false),"Same-frame rotated authoritative bounds remain conservative")
	world.desired[0].object={"objectType":9,"replicated":{"position":[150,150,2]}}; world.apply_pose(0)
	check(not world.static_collision_index.entries.has(node.get_instance_id()) and not Query.trace(world,a,b,true,true).hit,"Losing static membership removes collision registration")
	world.desired[0].object.staticState={"position":[150,150,2]}; world.apply_pose(0)
	node.remove_meta("native_scene_bounds"); world.static_collision_index.put(node)
	check(world.static_collision_index.query(Vector3.ZERO,Vector3.ONE).has(node),"Unknown static bounds retain global conservative fallback")
	var id:=node.get_instance_id(); world.remove_instance(0); await process_frame
	check(not world.static_collision_index.entries.has(id),"Actual instance removal clears indexed membership without retaining scene ownership")
	var stats: Dictionary=world.static_collision_index.snapshot()
	check((stats.native.get("queries",0)>0 and stats.native.candidates<stats.native.queries*stats.entries/10 and stats.native.cache_hits>0) or (stats.all_candidates>0 and stats.candidates<stats.all_candidates/10 and stats.cell_cache_hits>0),"Nearby repeated queries prune static scenery and reuse candidate lists")
	world.close(); check(world.static_collision_index.entries.is_empty() and world.static_collision_index.cell_candidates.is_empty(),"World retirement clears membership and candidate caches")
	world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"index":stats,"publicConnections":0,"scope":"Actual LiveWorld static admission/pose/membership/removal lifecycle, 300 indexed vs exhaustive exact geometry queries, cache invalidation and retirement"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
