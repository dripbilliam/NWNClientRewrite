extends SceneTree
# Deferred actual existing SceneGeometry/SceneQueryIndex adapter fixture. These
# authored bridge models prove this adapter's path, not original BSP membership.
const Adapter=preload("res://systems/native_render/native_client_support_scene.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Index=preload("res://systems/native_render/scene_query_index.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var checks:=0
var failures: Array=[]
var output:=""
var require_compiled:=false

class SurfaceStub extends Node:
	var definition:={"width":1,"height":1,"tiles":[{"model":"authored_bridge"}]}
	func ready() -> bool: return false # Deliberately isolates the real MDL scene path.

class ModelStub extends Node3D:
	var meshes: Array=[]
	var pick_surfaces: Array=[]

class TerrainStub extends Node3D:
	var collision_index=Index.new()
	var instances: Dictionary={}
	var batcher=null
	func collision_candidates(a: Vector3,b: Vector3) -> Array: return collision_index.query(a,b)

class WorldStub extends Node3D:
	var generation:=1
	var area_id:=25
	var closed:=false
	var retiring:=false
	var terrain
	var surface
	var static_collision_index=Index.new()
	var instances: Dictionary={}
	var desired: Dictionary={}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,context: String) -> void:
	checks+=1
	if not value and failures.size()<40: failures.append(context)

func model(owner: Node3D,height: float,slope: float=0.0) -> ModelStub:
	var instance:=ModelStub.new(); owner.add_child(instance)
	instance.position.y=height
	var part:=Node3D.new(); instance.add_child(part)
	var data:=Geometry.new()
	data.configure({"vertices":PackedFloat32Array([0,0,0,10,0,10*slope,10,10,10*slope,0,10,0]),"indices":PackedInt32Array([0,1,2,0,2,3])})
	var resource:=ArrayMesh.new(); resource.set_meta("native_scene_geometry",data)
	part.set_meta("native_pick_geometry",resource); instance.pick_surfaces.append(part)
	instance.set_meta("native_scene_bounds",AABB(Vector3(-0.01,-0.01,-10.01),Vector3(10.02,10*slope+0.02,10.02)))
	return instance

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg=="--require-compiled-scene": require_compiled=true
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	var world:=WorldStub.new(); root.add_child(world)
	world.terrain=TerrainStub.new(); world.add_child(world.terrain)
	world.surface=SurfaceStub.new(); world.add_child(world.surface)
	var base:=model(world.terrain,0.0)
	var bridge:=model(world.terrain,11.0)
	world.terrain.instances={0:base,1:bridge}
	world.terrain.collision_index.put(base); world.terrain.collision_index.put(bridge)
	var lifetime:={"current":true,"available":true,"revision":1,"witness_calls":0,"invalidate_at":-1}
	var guard: Callable=func():return lifetime.current
	var witness: Callable=func():
		lifetime.witness_calls+=1
		if lifetime.witness_calls==lifetime.invalidate_at:lifetime.revision+=1
		return {"available":lifetime.available,"scope":"published-static-scene","revision":lifetime.revision,"reason":"query service unavailable"}
	var binding:=Adapter.new()
	check(binding.configure(world,guard,witness),"one weak world/scope binding")
	check(not binding.configure(world,guard,witness),"cannot rebind existing lifetime")
	var at:=Vector3(5,5,0)
	var result: Dictionary=binding.query(at,11.0)
	check(result.available and result.branch=="original" and absf(result.position.z-11.0)<0.00001,"actual SceneGeometry finds raised bridge, not lower floor")
	check(result.normal.z>0.99,"actual normal returned")
	result=binding.query(at,0.0)
	check(result.available and absf(result.position.z)<0.00001,"prior support window chooses lower floor beneath bridge")
	result=binding.query(at,35.0)
	check(result.available and result.rays==2 and absf(result.position.z-11.0)<0.00001,"actual broad ray fallback uses original direction")
	bridge.position=Vector3(10,11,0); bridge.rotation.y=PI/2
	world.terrain.collision_index.put(bridge); lifetime.revision+=1
	result=binding.query(at,11.0)
	check(result.available and absf(result.position.z-11.0)<0.00001,"current root rotation/translation participates")
	world.terrain.collision_index.erase(bridge.get_instance_id()); world.terrain.instances.erase(1); bridge.free(); lifetime.revision+=1
	bridge=model(world.terrain,10.0,0.2); world.terrain.instances[1]=bridge; world.terrain.collision_index.put(bridge); lifetime.revision+=1
	result=binding.query(at,11.0)
	check(result.available and absf(result.position.z-11.0)<0.00002 and result.normal.x<0,"sloped bridge uses real transformed plane/normal")
	bridge.scale=Vector3(2,1,1); world.terrain.collision_index.put(bridge); lifetime.revision+=1
	result=binding.query(at,11.0)
	check(result.available and absf(result.position.z-10.5)<0.00002,"nonuniform scale is current geometry input")
	lifetime.available=false
	result=binding.query(at,11.0)
	check(not result.available and result.position.z==11 and not result.has("normal"),"unknown query service preserves support without claiming native miss")
	lifetime.available=true; lifetime.current=false
	check(not binding.query(at,11.0).available,"connection scope guard rejects old owner")
	lifetime.current=true; lifetime.invalidate_at=lifetime.witness_calls+4
	result=binding.query(at,11.0)
	check(not result.available and result.reason=="Client support source changed during projection","source revision change after ray rejects stale hit")
	lifetime.invalidate_at=-1
	world.generation=2
	check(not binding.query(at,11.0).available,"same world area generation invalidates binding")
	world.generation=1; world.area_id=26
	check(not binding.query(at,11.0).available,"same world area identity invalidates binding")
	world.area_id=25; world.retiring=true
	check(not binding.query(at,11.0).available,"retiring world invalidates binding")
	world.retiring=false
	var detached: Dictionary=binding.snapshot(); detached.queries=-1
	check(binding.snapshot().queries>=0,"cold diagnostics detached")
	var before_queries: int=binding.snapshot().queries
	var worker:=Thread.new()
	check(worker.start(func():return binding.query(at,11.0))==OK,"bounded wrong-thread fixture starts")
	var worker_result: Variant=worker.wait_to_finish()
	check(worker_result is Dictionary and not worker_result.available and binding.snapshot().queries==before_queries,"wrong thread never touches scene/counters")
	check(binding.retire(),"retire clears weak binding/callables")
	check(not binding.query(at,11.0).available,"retired binding never resolves replacement")
	world.generation=2
	var reentry:=Adapter.new(); check(reentry.configure(world,guard,witness),"fresh binding on area reentry")
	result=reentry.query(at,11.0)
	check(result.available and absf(result.position.z-10.5)<0.00002,"reentry uses current geometry, not old support cache")
	var actual_native: bool=world.terrain.collision_index.native_ready()
	if require_compiled:
		check(Kernel.enabled() and Kernel.available() and actual_native,"compiled activation asserted, not inferred from output")
	check(str(world.terrain.collision_index.native_failure).is_empty(),"no native scene-index failure")
	var weak_only:=Adapter.new();check(weak_only.configure(world,guard,witness),"additional weak-only lifetime witness")
	var final: Dictionary=reentry.snapshot(); reentry.retire()
	world.terrain.collision_index.clear(); world.static_collision_index.clear(); world.free()
	check(not reentry.query(at,11.0).available,"freed world does not revive")
	check(not weak_only.query(at,11.0).available,"unretired weak binding cannot retain freed world")
	weak_only.retire()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"native_scene_index":actual_native,"compiled_required":require_compiled,"adapter":final,"scope":"Authored real SceneGeometry/static-index adapter, lifecycle/transform/slope/reentry; not original BSP membership or live-server acceptance"},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
