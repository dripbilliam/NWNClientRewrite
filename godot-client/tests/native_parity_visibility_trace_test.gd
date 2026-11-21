extends SceneTree
const Trace=preload("res://tools/native_parity/visibility/entity_visibility_trace.gd")
const Provenance=preload("res://tools/native_parity/visibility/mesh_provenance.gd")
const Pointer=preload("res://tools/native_parity/visibility/terrain_pointer_trace.gd")
class World extends Node3D:
	var generation:=3
	var area_id:=42
	var closed:=false
	var retiring:=false
	var controlled_id:=7
	var desired:={}
	var instances:={}
	var installed:={}
	var hidden:={}
	var failed_objects:={}
	var batches: Array=[]
	var terrain: Node
	var static_collision_index:=Index.new()
class Registry extends Node:
	var entities:={}
	var native_owners:={}
class Actor extends Node3D:
	var meshes: Array=[]
	var retired:=false
	var failure:=""
class Index extends RefCounted:
	var entries:={}
class Terrain extends Node3D:
	var collision_index:=Index.new()
	var candidates: Array=[]
	func collision_candidates(_start: Vector3,_end: Vector3) -> Array:return candidates
class Geometry extends RefCounted:
	func nearest(_start: Array,_end: Array,_details: bool,_compiled: bool) -> Variant:return {"position":[0.0,0.0,0.0],"normal":[0.0,0.0,1.0]}
var count:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	count+=1
	if not value:failures.append(message)
func safe(value: Variant) -> bool:
	if value is Object:return false
	if value is Dictionary:
		for key in value:
			if not safe(key) or not safe(value[key]):return false
	elif value is Array:
		for item in value:
			if not safe(item):return false
	return true
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:=World.new();root.add_child(world)
	var registry:=Registry.new();root.add_child(registry)
	var request:={"post_window":true,"measurement_active":false,"expected_world_instance_id":world.get_instance_id(),"expected_generation":3,"expected_area_id":42,"connection_scope":"fixture","ids":[7,8]}
	world.desired[7]={"object":{"id":7,"objectType":5,"areaId":42,"nativeLifetime":11,"replicated":{"position":[1.0,2.0,3.0],"visibility":[1,0,0]},"playerState":{"visibility":{"8":[1,1,0]}}}}
	var result:=Trace.capture(world,registry,null,request)
	check(result.status=="complete","cold query completes")
	check(result.records.size()==2,"explicit missing entities retained")
	check(result.records[0].received.visibility.value==[1,0,0],"raw triple preserved")
	check(result.records[0].received.disclosure_lifetime.available==false,"missing lifetime explicit")
	check(result.records[0].instance_present==false,"known unrendered entity retained")
	check(result.records[1].known_in_current_desired==false,"absent entity distinguished")
	check(result.records[1].controlled_visibility.value==[1,1,0],"controlled perception retained")
	check(safe(result),"detached values only")
	result.records[0].received.position.value[0]=999
	check(world.desired[7].object.replicated.position[0]==1.0,"received mutation isolated")
	request.measurement_active=true;check(Trace.capture(world,registry,null,request).status=="unavailable","measured frame denied");request.measurement_active=false
	request.expected_generation=2;check(Trace.capture(world,registry,null,request).status=="unavailable","stale scope denied");request.expected_generation=3
	var actor:=Actor.new();world.add_child(actor);actor.position=Vector3(4,5,6);world.instances[7]=actor;world.installed[7]=true;registry.entities[7]={}
	var bundle:={"resource_name":"test_model","value":{"name":"test_model","format":"ASCII MDL"},"textures":{}}
	var mesh_data:={"render":true,"textures":["NULL"],"native_tilefade":1,"native_tilefade_available":true,"native_tilefade_source":"fixture","native_bounds":{"min":[0.0,0.0,0.0],"max":[1.0,2.0,3.0]},"native_bounds_available":true,"native_bounds_valid":true,"native_bounds_source":"fixture"}
	var facts:=Provenance.capture(bundle,{"name":"part","flags":33,"alpha":0.0,"mesh":mesh_data},2)
	check(facts.parsed_render==true and facts.original_alpha==0.0,"render and alpha independent")
	check(facts.texture_resolution=="no_bitmap_declared" and facts.missing_texture==false,"NULL texture distinguished")
	check(safe(facts),"install facts have no references")
	facts.native_bounds.min[0]=9;check(mesh_data.native_bounds.min[0]==0.0,"bounds detached at install")
	facts=Provenance.capture(bundle,{"name":"part","flags":33,"alpha":0.0,"mesh":mesh_data},2)
	var mesh:=MeshInstance3D.new();actor.add_child(mesh);mesh.set_meta("native_mesh_source",facts);actor.meshes.append(mesh)
	result=Trace.capture(world,registry,null,request)
	check(result.records[0].scene.position.value==[4.0,5.0,6.0],"presentation position separated")
	check(result.records[0].admission.installed.value==true,"installed owner observed")
	check(result.records[0].registry.entity_known.value==true,"registry membership observed")
	check(result.records[0].meshes[0].source.authored_bounds.available==true,"authored bounds retained")
	check(result.records[0].meshes[0].source.original_alpha.value==0.0,"zero alpha not missing")
	check(result.records[0].meshes[0].actual_drawn.available==false,"not claiming GPU visibility")
	check(safe(result),"mesh view detached")
	result.records[0].meshes[0].source.authored_bounds.value.max[0]=999;check(facts.native_bounds.max[0]==1.0,"cold bounds isolated")
	var plain:=Node3D.new();world.add_child(plain);world.instances[8]=plain
	result=Trace.capture(world,null,null,request)
	check(result.records[1].scene.retired.available==false,"unknown retirement explicit")
	check(result.records[1].registry.entity_known.available==false,"missing registry explicit")
	world.batches=[{"owner":actor,"actors":true,"keys":{8:"pending"}}]
	check(Trace.capture(world,null,null,request).records[1].admission.batches.records.size()==1,"pending stream membership")
	check(Trace.capture(world,null,null,request,{"entities":1}).status=="truncated","entity cap explicit")
	var terrain:=Terrain.new();world.add_child(terrain);world.terrain=terrain
	var owner:=Node3D.new();terrain.add_child(owner);owner.set_meta("native_tile_index",4)
	var part:=Node3D.new();owner.add_child(part);part.set_meta("native_mesh_source",facts)
	owner.set_meta("native_scene_parts",[{"node":part,"data":Geometry.new()}]);terrain.candidates=[owner];terrain.collision_index.entries[owner.get_instance_id()]={"node":weakref(owner)}
	var ray:=request.duplicate();ray.start=[0,2,0];ray.end=[0,-2,0]
	var pointer:=Pointer.capture(world,null,ray)
	check(pointer.status=="complete" and pointer.hit!=null,"one explicit terrain ray")
	check(pointer.hit.tile_index==4 and pointer.hit.source.part_name=="part","tile Part provenance")
	check(safe(pointer),"pointer returns no scene references")
	pointer.hit.source.native_bounds.min[0]=999;check(facts.native_bounds.min[0]==0.0,"pointer facts isolated")
	terrain.collision_index.entries.clear();world.static_collision_index.entries[owner.get_instance_id()]={"node":weakref(owner)};owner.set_meta("world_object_id",91)
	pointer=Pointer.capture(world,null,ray)
	check(pointer.hit!=null and pointer.hit.object_id==91,"published static placeable Part can be inspected too")
	world.static_collision_index.entries[owner.get_instance_id()].bounds=AABB(Vector3(10,10,10),Vector3.ONE)
	check(Pointer.capture(world,null,ray).hit==null,"retained broad-phase bounds reject distant scenery")
	ray.end=[1000,0,0];check(Pointer.capture(world,null,ray).status=="unavailable","ray bound enforced")
	world.closed=true;check(Trace.capture(world,null,null,request).status=="unavailable","closed scope denied")
	world.free();registry.free()
	var report:={"checks":count,"failures":failures,"source_only_fixture":true,"scope":"isolated synthetic owners; no assets, server, GPU or ordinary runtime launch"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
