extends "res://tests/native_projectile_scene_test.gd"
const Index=preload("res://systems/native_render/scene_query_index.gd")
class IndexedTerrain extends Terrain:
	var index=preload("res://systems/native_render/scene_query_index.gd").new()
	var collision_index=index
	func collision_candidates(start: Vector3,end: Vector3) -> Array: return index.query(start,end)
func add_model(world,id: int,geometry,position: Vector3,box: Variant):
	var model:=Model.new(); world.terrain.add_child(model); model.position=position
	var mesh:=MeshInstance3D.new(); model.add_child(mesh); mesh.mesh=ArrayMesh.new(); mesh.mesh.set_meta("native_scene_geometry",geometry); model.meshes=[mesh]
	if box!=null: model.set_meta("native_scene_bounds",box)
	world.terrain.instances[id]=model; world.terrain.index.put(model); return model
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var world:=World.new(); root.add_child(world); world.terrain=IndexedTerrain.new(); world.add_child(world.terrain)
	var geometry:=Geometry.new(); geometry.configure({"vertices":PackedFloat32Array([0,0,0,2,0,0,0,2,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	for i in 100: add_model(world,i,geometry,Vector3((i%10)*10,0.25*(i%4),-int(i/10)*10),AABB(Vector3(0,0,-2),Vector3(2,0,2)))
	for i in 100:
		var x: float=(i%10)*10; var y: float=int(i/10)*10
		for delta in [[0.25,0.25],[0,0],[2,0],[9.9,9.9]]:
			var start: Array=[x+delta[0],y+delta[1],5.0]; var end: Array=[x+delta[0]+0.000001,y+delta[1],-5.0]
			check(JSON.stringify(Query.trace(world,start,end,true,true))==JSON.stringify(Query.trace(world,start,end,true,false)),"Indexed and exhaustive original-face query agree at tile"+str(i)+"/"+str(delta))
	var state: Dictionary=world.terrain.index.snapshot()
	check((state.native.get("queries",0)>0 and state.native.candidates<state.native.queries*state.entries/10) or (state.all_candidates>0 and state.candidates<state.all_candidates/10),"Nearby segment visits fewer than one tenth of all published tile roots")
	var wide:=Geometry.new(); wide.configure({"vertices":PackedFloat32Array([0,0,2,40,0,2,0,40,2]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,-2]),"native_surface_types":PackedInt32Array([0])})
	add_model(world,100,wide,Vector3.ZERO,AABB(Vector3(0,2,-40),Vector3(40,0,40)))
	var a: Array=[34.0,1.0,5.0]; var b: Array=[34.0,1.0,-5.0]
	check(Query.trace(world,a,b,true,true)==Query.trace(world,a,b,true,false) and Query.trace(world,a,b,true,true).position[2]==2.0,"Multi-tile original geometry overhang remains hittable")
	var unknown=add_model(world,101,geometry,Vector3(150,0,-150),null)
	check(world.terrain.index.query(Vector3.ZERO,Vector3.ONE).has(unknown),"Absent bounds stay in a conservative global fallback")
	if world.terrain.index.native_ready():
		check(world.terrain.index.nearest([150.25,150.25,1.0],[150.25,150.25,-1.0]).position==[150.25,150.25,0.0],"Native global fallback preserves unbounded original faces")
	var huge=add_model(world,102,geometry,Vector3.ZERO,AABB(Vector3(-1000000,-1,-1000000),Vector3(2000000,2,2000000)))
	check(int(world.terrain.index.snapshot().global_entries)==2 and world.terrain.index.cells.size()<2000,"Huge custom bounds do not allocate unbounded grid cells")
	check(world.terrain.index.query(Vector3(-10000,1,-10000),Vector3(10000,-1,10000)).has(unknown) and int(world.terrain.index.snapshot().fallback_queries)>0,"Long custom segments retain bounded conservative fallback")
	if world.terrain.index.native_ready():
		var native_long: Variant=world.terrain.index.nearest([-10000.0,-10000.0,10.0],[10000.0,10000.0,-10.0])
		var exhaustive:=Query.trace(world,[-10000.0,-10000.0,10.0],[10000.0,10000.0,-10.0],true,false)
		check((native_long==null and not exhaustive.hit) or (native_long!=null and exhaustive.hit and native_long.position==exhaustive.position and native_long.normal==exhaustive.normal),"Native long segment matches exhaustive hit and normal")
	var tilted:=Geometry.new(); tilted.configure({"vertices":PackedFloat32Array([0,0,0.25,2,0,-1.75,0,2,0.25]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([1,0,1,-0.25]),"native_surface_types":PackedInt32Array([0])})
	var earlier=add_model(world,103,geometry,Vector3(180,0,-180),AABB(Vector3(0,0,-2),Vector3(2,0,2)))
	var later=add_model(world,104,tilted,Vector3(180,0,-180),AABB(Vector3(0,-2,-2),Vector3(2,4,2)))
	world.terrain.index.put(earlier)
	var tie:=Query.trace(world,[180.25,180.25,1.0],[180.25,180.25,-1.0],true,true)
	check(tie.hit and tie.normal[0]>0.5 and tie==Query.trace(world,[180.25,180.25,1.0],[180.25,180.25,-1.0],true,false),"Re-registering an earlier root preserves original equal-distance hit order")
	if world.terrain.index.native_ready():
		var invalid: Variant=world.terrain.index.native_owner.call("dispatch",0,{"node":later.get_instance_id(),"model":0,"order":1})
		check(invalid is Dictionary and invalid.get("error","").contains("stale"),"Native index rejects stale model tokens without retaining pointers")
	var later_id: int=later.get_instance_id(); world.terrain.instances.erase(104); later.queue_free()
	if world.terrain.index.native_ready(): check(world.terrain.index.nearest([180.25,180.25,1.0],[180.25,180.25,-1.0]).normal==[0.0,0.0,1.0],"Queued root is ignored before its destruction")
	await process_frame
	if world.terrain.index.native_ready(): check(world.terrain.index.nearest([180.25,180.25,1.0],[180.25,180.25,-1.0]).normal==[0.0,0.0,1.0],"Freed root/model tokens cannot be dereferenced")
	world.terrain.index.erase(later_id)
	world.terrain.index.erase(earlier.get_instance_id()); world.terrain.instances.erase(103); earlier.free()
	world.terrain.index.erase(huge.get_instance_id()); world.terrain.instances.erase(102); huge.free()
	world.terrain.index.erase(unknown.get_instance_id()); world.terrain.instances.erase(101); var weak: WeakRef=weakref(unknown); unknown.free()
	check(weak.get_ref()==null and world.terrain.index.entries.size()==101,"Index removal retains no native scene ownership")
	world.terrain.index.clear(); check(world.terrain.index.entries.is_empty() and world.terrain.index.cells.is_empty(),"Area retirement clears all spatial membership")
	world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"index":state,"scope":"400 indexed-versus-exhaustive queries using unchanged original polygon predicate, edge/grazing/diagonal segments, tile overhang, conservative missing/huge bounds, long segments and retirement. Original binary BSP and moving tile roots remain separate acceptance; active tile roots are fixed until retirement."},"\t")); file.close()
	print("NATIVE_SCENE_QUERY_INDEX ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
