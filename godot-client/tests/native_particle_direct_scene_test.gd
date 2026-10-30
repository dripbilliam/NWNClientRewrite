extends "res://tests/native_particle_resident_scene_test.gd"
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
class Terrain extends Node3D:
	var collision_index=preload("res://systems/native_render/scene_query_index.gd").new()
	var instances: Dictionary={}
	var batcher
	func close() -> void:
		collision_index.clear()
		for node in instances.values(): node.queue_free()
		instances.clear()
class Model extends Node3D:
	var meshes: Array=[]
	var pick_surfaces: Array=[]
func bouncing(world: Node3D,reference: bool) -> Node3D:
	var part:=Node3D.new(); world.add_child(part); part.position=Vector3(2,0.1,-2)
	var out:=Emitter.new(); out.force_reference=reference; out.source_path=NodePath(".."); out.source_model_flags=0; out.frustum_enabled=false
	out.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":16|32,"birthrate":30,"lifeexp":2,"velocity":0.2,"randvel":0.1,"mass":0.5,"spread":0.8,"sizestart":0.1,"sizeend":0.2,"alphastart":1,"alphaend":0.2,"bounce_co":0.5}
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false); out.rng=Random.new(); out.providers.random=out.rng.next; return out
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	world.terrain=Terrain.new(); world.add_child(world.terrain)
	var geometry:=Geometry.new(); geometry.configure({"vertices":PackedFloat32Array([0,0,0,10,0,0,0,10,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	var floor_model:=Model.new(); world.terrain.add_child(floor_model); var mesh:=MeshInstance3D.new(); floor_model.add_child(mesh); mesh.mesh=ArrayMesh.new(); mesh.mesh.set_meta("native_scene_geometry",geometry); floor_model.meshes=[mesh]
	floor_model.set_meta("native_scene_bounds",AABB(Vector3(-10,-2,-10),Vector3(20,4,20)))
	world.terrain.instances[0]=floor_model; world.terrain.collision_index.put(floor_model)
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true; camera.position=Vector3(0,2,10); camera.look_at(Vector3.ZERO)
	var a=bouncing(world,false); var b=bouncing(world,true)
	check(world.particle_collision_indices().size()==2 and a.collision_indices_provider.is_valid(),"Actual world admits native scene tokens only for its own collision provider")
	for frame in 180:
		world.direct_particle_collision_enabled=frame<60 or frame>=90
		mesh.position.y=0.02*sin(frame*0.04)
		if frame==120:
			floor_model.position.y=-0.2; world.terrain.collision_index.put(floor_model)
		a.tick(1.0/60); b.tick(1.0/60); compare(a,b,"Direct-scene frame "+str(frame))
		if frame%30==0: await process_frame
	check(a.direct_scene_queries>0 and a.direct_scene_hits>0 and b.direct_scene_queries==0,"Actual resident particles exercise direct scene hits/misses; reference retains callback delivery")
	check(int(world.stats.get("particle_scene_queries",0))>0,"Reference/fallback queries continue through existing world owner")
	a.retire(); b.retire(); world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"180 actual resident/reference GPU frames with collisions, moving physical Part and root, direct/callback alternation; exact state/RNG/geometry parity and lifecycle"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
