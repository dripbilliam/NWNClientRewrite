extends SceneTree
const Gate=preload("res://systems/native_data/native_support_authored_box.gd")
const Box=preload("res://tools/native_parity/doors/native_box_hit.gd")
const Adapter=preload("res://systems/native_render/native_client_support_scene_box.gd")
const Fixtures=preload("res://tests/native_parity_client_support_scene_test.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
var checks:=0
var failures: Array=[]
var output:=""
var require_compiled:=false

class PoisonWok extends Node:
	var definition:={"width":1,"height":1,"tiles":[{"model":"authored_bridge"}]}
	var calls:=0
	func ready() -> bool:return true
	func vertical_candidates(_point: Array) -> Array:calls+=1;return []
	func height(_point: Vector3,_previous: float) -> float:calls+=1;return 999.0

func _initialize() -> void:call_deferred("run")
func check(value: bool,context: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(context)

func facts(low: Array=[0.0,0.0,0.0],high: Array=[10.0,10.0,0.0]) -> Dictionary:
	return {"node_is_aabb":false,"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{"min":low.duplicate(),"max":high.duplicate()},"native_tilefade":0,"native_tilefade_available":true}

func geometry() -> Resource:
	var data:=Geometry.new()
	data.configure({"vertices":PackedFloat32Array([0,0,0,10,0,0,10,10,0,0,10,0]),"indices":PackedInt32Array([0,1,2,0,2,3]),"native_surface_types":PackedInt32Array([30,30])})
	return data

func model(owner: Node3D,z: float,data: Resource,source: Dictionary):
	var value=Fixtures.ModelStub.new();owner.add_child(value);value.position.y=z
	var part:=Node3D.new();value.add_child(part)
	var resource:=ArrayMesh.new();resource.set_meta("native_scene_geometry",data)
	part.set_meta("native_pick_geometry",resource);part.set_meta("native_mesh_source",source);value.pick_surfaces.append(part)
	value.set_meta("native_scene_bounds",AABB(Vector3(-0.01,-0.01,-10.01),Vector3(10.02,0.02,10.02)))
	return value

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg=="--require-compiled-scene":require_compiled=true
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var source:=facts([0.0,0.0,0.0],[10.0,10.0,10.0])
	for endpoints: Array in [
		[Vector3(5,5,11),Vector3(5,5,-1)],
		[Vector3(5,5,5),Vector3(5,5,-1)],
		[Vector3(-1,5,5),Vector3(11,5,5)],
		[Vector3(5,-1,5),Vector3(5,11,5)],
		[Vector3(11,11,11),Vector3(12,12,12)],
		[Vector3(0,0,0),Vector3(10,10,10)],
		[Vector3(-1,11,5),Vector3(11,-1,5)]]:
		var a: Vector3=endpoints[0];var b: Vector3=endpoints[1]
		var before_a: Vector3=a;var before_b: Vector3=b
		var expected:=Box.hit(a,b,Vector3.ZERO,Vector3(10,10,10))
		var actual:=Gate.admit(source,[a.x,a.y,a.z],[b.x,b.y,b.z])
		check(actual.available and actual.face==expected.face and actual.admit==(expected.face!=0),"authored gate uses original finite Box face code")
		check(a==before_a and b==before_b,"four-argument admission does not clip ray endpoints")
	var zero:=Gate.admit(facts(),[5.0,5.0,1.0],[5.0,5.0,-1.0])
	check(zero.available and zero.admit,"zero-thickness authored bounds are supported")
	for invalid: Dictionary in [
		{}, {"node_is_aabb":false},
		{"node_is_aabb":false,"native_bounds_available":true,"native_bounds_valid":false},
		{"node_is_aabb":false,"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{}},
		facts([1.0,0.0,0.0],[0.0,10.0,0.0]),
		facts([0.0,0.0,0.0],[INF,10.0,0.0]),
		facts([0.0,0.0,0.0],[1.0e100,10.0,0.0])]:
		check(not Gate.admit(invalid,[5.0,5.0,1.0],[5.0,5.0,-1.0]).available,"missing/invalid/nonrepresentable authored bounds unavailable")
	check(not Gate.admit(facts(),[5.0,5.0,NAN],[5.0,5.0,-1.0]).available,"nonfinite ordinary input unavailable")
	check(Gate.admit({"node_is_aabb":true,"native_tilefade_available":true,"native_tilefade":0},[5.0,5.0,1.0],[5.0,5.0,-1.0]).route=="aabb-existing","AABB does not inherit ordinary authored-box rule")
	for fade in [2,4]:
		var excluded:=facts();excluded.native_tilefade=fade
		var excluded_result:=Gate.admit(excluded,[5.0,5.0,1.0],[5.0,5.0,-1.0])
		check(excluded_result.available and not excluded_result.admit and excluded_result.route=="static-tilefade-excluded","native SpawnTile excludes exact tilefade2/4 support membership")
	for fade in [0,1,3,5,8]:
		var retained:=facts();retained.native_tilefade=fade
		check(Gate.admit(retained,[5.0,5.0,1.0],[5.0,5.0,-1.0]).admit,"other proven tilefade values are not heuristically excluded")
	var unknown_fade:=facts();unknown_fade.native_tilefade_available=false
	check(not Gate.admit(unknown_fade,[5.0,5.0,1.0],[5.0,5.0,-1.0]).available,"missing tilefade is explicit unavailable")
	var world=Fixtures.WorldStub.new();root.add_child(world)
	world.surface=PoisonWok.new();world.add_child(world.surface)
	world.terrain=Fixtures.TerrainStub.new();world.add_child(world.terrain)
	var data:=geometry()
	var floor_model=model(world.terrain,0,data,facts())
	var bridge=model(world.terrain,11,data,facts())
	world.terrain.instances={0:floor_model,1:bridge};world.terrain.collision_index.put(floor_model);world.terrain.collision_index.put(bridge)
	var stamp:={"revision":1};var guard: Callable=func():return true
	var witness: Callable=func():return {"available":true,"scope":"published-static-scene","revision":stamp.revision}
	var binding:=Adapter.new();check(binding.configure(world,guard,witness),"new authored-box adapter binds existing owner")
	var at:=Vector3(5,5,0);var result: Dictionary=binding.query(at,11.0)
	check(result.available and result.position.z==11.0,"authored ordinary bridge surface hits with material30")
	check(result.normal==Vector3.ZERO,"ordinary polygon branch returns native zero normal instead of plane normal")
	var first_cache: Dictionary=binding.snapshot().part_trace
	result=binding.query(at,11.0)
	var repeated_cache: Dictionary=binding.snapshot().part_trace
	check(result.available and result.position.z==11.0 and result.normal==Vector3.ZERO,"same-pose support query remains identical")
	check(int(repeated_cache.inverse_builds)==int(first_cache.inverse_builds) and int(repeated_cache.inverse_reuses)>int(first_cache.inverse_reuses),"same Part pose reuses its inverse")
	check(world.surface.calls==0,"scene support never queries standalone WOK/navigation floor")
	for fade in [2,4]:
		var excluded:=facts();excluded.native_tilefade=fade;bridge.pick_surfaces[0].set_meta("native_mesh_source",excluded);stamp.revision+=1
		result=binding.query(at,11.0)
		check(result.available and result.position.z<1.0,"tilefade2/4 published bridge Part is not a native static support member")
	bridge.pick_surfaces[0].set_meta("native_mesh_source",facts());stamp.revision+=1
	bridge.pick_surfaces[0].set_meta("native_mesh_source",facts([0.0,0.0,0.0],[1.0,1.0,0.0]));stamp.revision+=1
	result=binding.query(at,11.0)
	var floor_reference: Variant=Polygon.hit(data.face(0),[data.planes[0],data.planes[1],data.planes[2]],data.planes[3],[5.0,5.0,90.0],[5.0,5.0,-9.0])
	check(result.available and floor_reference!=null and result.position.z==floor_reference[2],"authored bounds reject a vertex-face hit outside original box")
	bridge.pick_surfaces[0].set_meta("native_mesh_source",facts());stamp.revision+=1
	bridge.position=Vector3(10,11,0);bridge.rotation.y=PI/2;world.terrain.collision_index.put(bridge);stamp.revision+=1
	var before_repose: int=int(binding.snapshot().part_trace.inverse_builds)
	result=binding.query(at,11.0)
	check(result.available and result.position.z==11.0 and result.normal==Vector3.ZERO,"current Part transform applies authored local box and preserves zero normal")
	check(int(binding.snapshot().part_trace.inverse_builds)>before_repose,"changed parent pose rebuilds Part inverse")
	bridge.pick_surfaces[0].position.y=0.5;stamp.revision+=1
	var before_part_repose: int=int(binding.snapshot().part_trace.inverse_builds)
	result=binding.query(at,11.0)
	check(result.available and absf(result.position.z-11.5)<0.01,"changed Part-local pose is reflected in support hit")
	check(int(binding.snapshot().part_trace.inverse_builds)>before_part_repose,"changed Part-local pose rebuilds inverse")
	bridge.pick_surfaces[0].position.y=0.0;stamp.revision+=1
	result=binding.query(at,11.0)
	check(result.available and result.position.z==11.0,"restored Part pose restores support hit")
	bridge.pick_surfaces[0].set_meta("native_mesh_source",{"node_is_aabb":false});stamp.revision+=1
	check(not binding.query(at,11.0).available,"missing bounds explicit unavailable rather than vertex-box fallback")
	bridge.pick_surfaces[0].set_meta("native_mesh_source",facts());bridge.pick_surfaces[0].free();stamp.revision+=1
	check(not binding.query(at,11.0).available,"retired Part cannot reuse an old inverse or hit")
	var snapshot:=binding.snapshot()
	check(snapshot.part_trace.authored_box_queries>0 and snapshot.part_trace.authored_box_misses>0 and snapshot.part_trace.authored_box_unavailable>0,"actual authored box work and unsupported inputs counted")
	var native_index: bool=world.terrain.collision_index.native_ready()
	if require_compiled:check(Kernel.enabled() and Kernel.available() and native_index,"actual existing native query index activation")
	binding.retire();check(not binding.query(at,11.0).available,"retired support binding cannot reuse authored answer")
	world.terrain.collision_index.clear();world.static_collision_index.clear();world.free()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"native_scene_index":native_index,"compiled_required":require_compiled,"policy":snapshot,"scope":"Ordinary native authored-box admission and zero-normal successor; AABB policy retained; original BSP ordering/transforms/full bridge gameplay remain unaccepted"},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
