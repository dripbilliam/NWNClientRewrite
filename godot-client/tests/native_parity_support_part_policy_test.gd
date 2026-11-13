extends SceneTree
const Triangle=preload("res://systems/native_data/native_support_triangle.gd")
const Corrected=preload("res://systems/native_render/native_client_support_scene_parts.gd")
const OriginalAdapter=preload("res://systems/native_render/native_client_support_scene.gd")
const Fixtures=preload("res://tests/native_parity_client_support_scene_test.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Provenance=preload("res://tools/native_parity/visibility/mesh_provenance.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
var checks:=0
var failures: Array=[]
var output:=""
var require_compiled:=false

func _initialize() -> void:call_deferred("run")
func check(value: bool,context: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(context)

func geometry(types: PackedInt32Array) -> Resource:
	var value:=Geometry.new()
	value.configure({"vertices":PackedFloat32Array([0,0,0,10,0,0,10,10,0,0,10,0]),"indices":PackedInt32Array([0,1,2,0,2,3]),"native_surface_types":types})
	return value

func model(owner: Node3D,z: float,data: Resource,facts: Dictionary):
	var value=Fixtures.ModelStub.new();owner.add_child(value);value.position.y=z
	var part:=Node3D.new();value.add_child(part)
	var resource:=ArrayMesh.new();resource.set_meta("native_scene_geometry",data)
	part.set_meta("native_pick_geometry",resource);part.set_meta("native_mesh_source",facts);value.pick_surfaces.append(part)
	value.set_meta("native_scene_bounds",AABB(Vector3(-0.01,-0.01,-10.01),Vector3(10.02,0.02,10.02)))
	return value

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg=="--require-compiled-scene":require_compiled=true
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var start: Array=[5.0,5.0,1.0];var end: Array=[5.0,5.0,-1.0]
	for types: PackedInt32Array in [PackedInt32Array([30,30]),PackedInt32Array([94,158]),PackedInt32Array([-34,-98])]:
		var data:=geometry(types)
		var hit: Dictionary=Triangle.nearest(data,start,end,{"node_is_aabb":false})
		check(hit.available and hit.hit and hit.position[2]==0,"ordinary trimesh does not apply mask30 or wrapping")
		check(hit.route=="gd-unmasked-trimesh" and hit.triangle_tests==2,"material-bearing ordinary mesh reports actual GDS fallback work")
		var masked: Dictionary=Triangle.nearest(data,start,end,{"node_is_aabb":true})
		check(masked.available and not masked.hit,"AABB material&63=30 remains masked")
	var allowed:=geometry(PackedInt32Array([62,62]))
	check(Triangle.nearest(allowed,start,end,{"node_is_aabb":true}).hit,"AABB surface62 is allowed by maskBFFFFFFF")
	var plain:=geometry(PackedInt32Array())
	var plain_hit: Dictionary=Triangle.nearest(plain,start,end,{"node_is_aabb":false})
	check(plain_hit.available and plain_hit.hit,"ordinary no-material table still hits")
	check(not Triangle.nearest(plain,start,end,{"node_is_aabb":true}).available,"missing AABB materials are explicit unavailable")
	for facts: Dictionary in [{},{"node_is_aabb":null},{"node_is_aabb":0}]:
		check(not Triangle.nearest(plain,start,end,facts).available,"unknown subtype never silently ordinary")
	check(not Triangle.nearest(plain,[5.0,5.0,INF],end,{"node_is_aabb":false}).available,"nonfinite segment explicit unavailable")
	var aabb_facts: Dictionary=Provenance.capture({"value":{"format":"ASCII MDL"}},{"features":["aabb"],"mesh":{}},0)
	var tri_facts: Dictionary=Provenance.capture({"value":{"format":"ASCII MDL"}},{"features":[],"mesh":{}},0)
	var absent_facts: Dictionary=Provenance.capture({"value":{}},{"mesh":{}},0)
	check(aabb_facts.node_is_aabb==true and tri_facts.node_is_aabb==false and absent_facts.node_is_aabb==null,"actual install provenance preserves exact subtype vs unavailable")
	check(Provenance.detached(aabb_facts).node_is_aabb==true,"detached provenance retains subtype")
	var world=Fixtures.WorldStub.new();root.add_child(world)
	world.surface=Fixtures.SurfaceStub.new();world.add_child(world.surface)
	world.terrain=Fixtures.TerrainStub.new();world.add_child(world.terrain)
	var floor_model=model(world.terrain,0.0,plain,tri_facts)
	var bridge=model(world.terrain,11.0,geometry(PackedInt32Array([30,30])),tri_facts)
	world.terrain.instances={0:floor_model,1:bridge};world.terrain.collision_index.put(floor_model);world.terrain.collision_index.put(bridge)
	var stamp:={"revision":1}
	var guard: Callable=func():return true
	var witness: Callable=func():return {"available":true,"scope":"published-static-scene","revision":stamp.revision}
	var legacy:=OriginalAdapter.new();check(legacy.configure(world,guard,witness),"legacy adapter binding")
	var corrected:=Corrected.new();check(corrected.configure(world,guard,witness),"corrected adapter binding")
	var at:=Vector3(5,5,0)
	# The original f32 finite-segment predicate need not return analytic zero
	# after90→-9 interpolation. Compare its exact original-plane reference.
	var floor_reference: Variant=Polygon.hit(plain.face(0),[plain.planes[0],plain.planes[1],plain.planes[2]],plain.planes[3],[5.0,5.0,90.0],[5.0,5.0,-9.0])
	check(floor_reference!=null,"independent original-plane floor reference hits")
	var before: Dictionary=legacy.query(at,11.0);var after: Dictionary=corrected.query(at,11.0)
	check(before.available and before.position.z==floor_reference[2],"existing SceneHit blanket material30 drops ordinary bridge")
	check(after.available and after.position.z==11,"support-only policy restores material30 ordinary bridge")
	bridge.pick_surfaces[0].visible=false
	check(corrected.query(at,11.0).position.z==11,"render0/hidden physical Part remains a support candidate")
	bridge.pick_surfaces[0].set_meta("native_mesh_source",aabb_facts);stamp.revision+=1
	after=corrected.query(at,11.0)
	var masked_floor_result: Dictionary=after
	check(after.available and after.position.z==floor_reference[2],"same material30 physical AABB remains masked")
	bridge.pick_surfaces[0].remove_meta("native_mesh_source");stamp.revision+=1
	check(not corrected.query(at,11.0).available,"missing published source provenance cannot silently use legacy policy")
	var snapshot: Dictionary=corrected.snapshot()
	check(snapshot.part_trace.gd_unmasked_queries>0 and snapshot.part_trace.triangle_tests>0,"GDS fallback work reported explicitly")
	var native_index: bool=world.terrain.collision_index.native_ready()
	var raw_compiled: bool=plain_hit.route=="compiled-raw"
	if require_compiled:check(Kernel.enabled() and Kernel.available() and native_index and raw_compiled,"actual compiled raw geometry and existing index activation")
	legacy.retire();corrected.retire();world.terrain.collision_index.clear();world.static_collision_index.clear();world.free()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"legacy_floor_height":before.position.z,"masked_floor_height":masked_floor_result.position.z,"native_scene_index":native_index,"compiled_raw_geometry":raw_compiled,"compiled_required":require_compiled,"policy":snapshot,"scope":"Support-only ordinary-trimesh material policy and proven AABB mask; existing static scene membership remains adaptation; no FPS/live acceptance"},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
