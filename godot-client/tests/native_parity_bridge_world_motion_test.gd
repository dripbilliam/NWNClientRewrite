extends SceneTree
# Integrated production receiver -> Motion -> support scene -> displayed pose.
# Authored numeric surfaces use the actual pooled ModelTemplate/physical Parts.
# Only area-readiness scaffolding, navigation clearance and the animation sink
# are fixture ports; no height callback, server acknowledgment or world store is
# replaced. This is not a loaded original campaign or a live bridge comparison.
const World=preload("res://systems/native_render/live_world_support.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Index=preload("res://systems/native_render/scene_query_index.gd")
const Motion=preload("res://systems/network_motion.gd")
class TerrainPort extends Node3D:
	var collision_index=Index.new()
	var instances: Dictionary={}
	var batcher=null
	var done:=true
	var diagnostics:={"errors":[]}
	func collision_candidates(a: Vector3,b: Vector3) -> Array:return collision_index.query(a,b)
	func close() -> void:
		collision_index.clear()
		for instance in instances.values():
			if is_instance_valid(instance):instance.retire()
		instances.clear()
class SurfacePort extends Node:
	var definition:={"width":4,"height":4,"tiles":[]}
	var published:=true
	var height_calls:=0
	func _init() -> void:
		for at in 16:definition.tiles.append({"model":"authored-world-fixture"})
	func ready() -> bool:return published
	func height(_point: Vector3,_previous: float) -> float:height_calls+=1;return -777.0
	func close() -> void:published=false
class RigsPort extends RefCounted:
	func clip_length(_id: int,_animation: int) -> float:return 1.0
class ActorPort extends Node3D:
	var rigs=RigsPort.new()
	var selected: Array=[]
	func set_animation(code: int,speed: float) -> void:selected=[code,speed]
	func retain_decoded_data() -> Dictionary:return {}
	func retire() -> void:queue_free()
class CombatPort extends Node:
	func forget(_id: int,_removed: bool=false) -> void:pass
	func sync(_id: int,_source: Dictionary,_actor) -> void:pass
	func base_frame(_id: int,_code: int,_speed: float,_path: float) -> void:pass
	func movement_cue(_id: int,_cue: Dictionary) -> void:pass
	func visual_animation(_id: int,code: int) -> int:return code
	func close() -> void:pass
class NavigationPort extends Node:
	func query(_id: int,_radius: float=0.0) -> Callable:return func(_from: Vector3,_to: Vector3):return true
	func ready() -> bool:return true
	func sync_full() -> void:pass
	func sync_delta(_objects: Array,_removed: Array) -> void:pass
	func sync_motion_id(_id: int) -> void:pass
	func close() -> void:pass
var checks:=0
var failures: Array=[]
var output:=""
var observations: Array=[]
var retained_extension: Resource
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func near(a: float,b: float) -> bool:return absf(a-b)<0.0002
func progress(label: String) -> void:
	print("BRIDGE_WORLD_PHASE ",label)
	if not output.is_empty():FileAccess.open(output+".progress.json",FileAccess.WRITE).store_string(JSON.stringify({"phase":label,"checks":checks,"failures":failures,"observations":observations}))
func _initialize() -> void:run.call_deferred()
func bundle(name: String,length: float,width: float,z0: float,z1: float) -> Dictionary:
	var mesh:={"vertices":PackedFloat32Array([0,0,z0,length,0,z1,length,width,z1,0,width,z0]),"indices":PackedInt32Array([0,1,2,0,2,3]),"native_surface_types":PackedInt32Array([30,30]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":false,"shadow":false,"diffuse":[1.0,1.0,1.0],"ambient":[1.0,1.0,1.0],"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{"min":[0.0,0.0,minf(z0,z1)],"max":[length,width,maxf(z0,z1)]},"native_bounds_source":"authored-fixture","native_tilefade_available":true,"native_tilefade":0}
	var node:={"name":"support","parent":-1,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"features":[],"flags":33,"alpha":1.0,"selfillum":[0.0,0.0,0.0],"mesh":mesh}
	return {"sha256":"bridge-world-"+name,"resource_name":name,"value":{"name":name,"format":"dedicated-authored-fixture","nodes":[node]}}
func publish(world,name: String,length: float,width: float,z0: float,z1: float,at: Vector3):
	print("BRIDGE_WORLD_PHASE template ",name)
	var template=world.pool.model_template(bundle(name,length,width,z0,z1))
	check(template!=null and world.pool.failure.is_empty(),"Actual pooled template prepares "+name)
	if template==null:return null
	print("BRIDGE_WORLD_PHASE clone ",name)
	var instance=template.create();world.terrain.add_child(instance);instance.position=Vector3(at.x,at.z,-at.y)
	world.terrain.instances[name]=instance;world.terrain.collision_index.put(instance)
	print("BRIDGE_WORLD_PHASE published ",name)
	check(instance.parts.size()==1 and instance.pick_surfaces.size()==1 and instance.parts[0].has_meta("native_mesh_source"),"Actual physical Part/provenance survives template publication "+name)
	return instance
func make_world(epoch: int=1,area: int=25):
	var world:=World.new();root.add_child(world);world.set_process(false);world.generation=epoch;world.area_id=area
	world.combat=CombatPort.new();world.add_child(world.combat)
	world.surface=SurfacePort.new();world.add_child(world.surface);world.motion.height_query=world.surface.height
	world.terrain=TerrainPort.new();world.add_child(world.terrain)
	world.drive_collision=NavigationPort.new();world.add_child(world.drive_collision)
	check(world._bind_client_support() and world.motion.support_query.is_valid(),"Exact production cold support binder installs actual scene callback")
	return world
func source(world,lifetime: int,position: Vector3) -> Dictionary:
	return {"id":7,"objectType":5,"areaId":world.area_id,"nativeLifetime":lifetime,"disclosureLifetime":1,"appearance":{"appearance":1},"replicated":{"position":[position.x,position.y,position.z],"orientation":[1.0,0.0,0.0],"animation":0,"walkRate":5000,"runRate":5000}}
func actor(world,row: Dictionary,delta: bool=false):
	if delta:world.receive_delta([row],[],7)
	else:world.receive([row],7)
	var instance:=ActorPort.new();world.add_child(instance);world.instances[7]=instance;world.installed[7]=world.desired[7].key;world.apply_pose(7)
	return instance
func received_path(world,target: Vector3,revision: int=1) -> void:
	world.observe_movement([{"id":7,"revision":revision,"created":false,"changes":{"animation":4,"path":[[target.x,target.y,target.z]],"field8F4":1,"field8EC":1.0},"initial":world.desired[7].object.replicated}])
func step(world,seconds: float=0.04) -> void:
	world.motion.update(seconds);world.apply_pose(7);world.motion.finish_frame(7)
func display_matches(world) -> bool:
	var point: Vector3=world.motion.objects[7].render
	return world.instances[7].position.is_equal_approx(Vector3(point.x,point.z,-point.y))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	if OS.get_cmdline_user_args().has("--existing-kernel"):
		retained_extension=load("res://native/particle_kernel.gdextension")
		check(retained_extension!=null and ClassDB.class_exists("NwnSceneIndex"),"Compatible existing native scene library loads without rebuilding")
	print("BRIDGE_WORLD_PHASE make-world")
	var world=make_world()
	var floor_model=publish(world,"base",40,40,0,0,Vector3.ZERO)
	var entry=publish(world,"entry-ramp",10,6,0,5,Vector3(0,2,0))
	var deck=publish(world,"bridge-deck",10,6,0,0,Vector3(10,2,5))
	var exit=publish(world,"exit-ramp",10,6,5,0,Vector3(20,2,0))
	print("BRIDGE_WORLD_PHASE actor")
	var row:=source(world,1,Vector3(1,5,0));var received:=row.duplicate(true);actor(world,row)
	print("BRIDGE_WORLD_PHASE received-path")
	received_path(world,Vector3(29,5,0))
	var samples: Array=[]
	for at in 140:
		if at==0:print("BRIDGE_WORLD_PHASE first-step")
		step(world)
		var position: Vector3=world.motion.objects[7].position
		var expected: float=position.x*0.5 if position.x<10 else 5.0 if position.x<20 else (30-position.x)*0.5
		check(near(position.z,expected),"Actual accepted movement follows authored entry/deck/exit support at tick"+str(at))
		check(display_matches(world),"World.apply_pose displays actual Motion support at tick"+str(at))
		if at in [0,24,49,74,99,124,139]:samples.append([position.x,position.y,position.z])
	check(near(world.motion.objects[7].position.x,29) and near(world.motion.objects[7].position.z,0.5),"Bridge traversal reaches authored exit without snapping to base floor")
	check(row==received and world.desired[7].object.replicated.position==[1.0,5.0,0.0],"Support movement never rewrites received canonical XYZ")
	check(world.surface.height_calls==0,"Actual scene support never invokes poisoned base-WOK height")
	observations.append({"case":"received-entry-deck-exit","samples":samples,"received_position":row.replicated.position.duplicate(),"displayed":str(world.instances[7].position)})
	# Actual W input dispatch takes the same Motion update and display path.
	row=source(world,2,Vector3(5,5,2.5));actor(world,row,true)
	var preview: Dictionary=world.preview_drive(7,3,0)
	check(preview.has("target") and world.motion.objects[7].script==1,"Actual World.preview_drive accepts controlled input through its navigation owner")
	step(world)
	check(near(world.motion.objects[7].position.z,world.motion.objects[7].position.x*0.5) and display_matches(world),"Predicted input also walks on the authored ramp")
	check(world.desired[7].object.replicated.position==[5.0,5.0,2.5],"Predicted input keeps received state separate")
	# Current transformed physical Parts and index revision, no cached height.
	deck.position=Vector3(20,5,-10);deck.rotation.y=PI/2;deck.scale=Vector3(1.25,1.0,0.75);world.terrain.collision_index.put(deck)
	var center: Vector3=deck.global_transform*Vector3(5,0,-3)
	var native_center:=Vector3(center.x,-center.z,center.y)
	row=source(world,3,native_center);actor(world,row,true);received_path(world,native_center+Vector3(0.1,0,0),2);step(world,0.01)
	check(near(world.motion.objects[7].position.z,native_center.z) and display_matches(world),"Translated rotated nonuniformly scaled published bridge supports actual movement")
	# Overlap selection retains the prior support layer before far fallback.
	var roof=publish(world,"upper-overlap",12,12,0,0,Vector3(9,8,12))
	progress("overlap-actor")
	row=source(world,4,native_center);actor(world,row,true);received_path(world,native_center+Vector3(0.1,0,0),3);step(world,0.01)
	progress("overlap-supported")
	check(near(world.motion.objects[7].position.z,5),"Higher overlapping surface does not steal support within the previous-Z window")
	world.surface.published=false;var previous: float=world.motion.objects[7].position.z;step(world,0.01)
	check(world.motion.objects[7].position.z==previous and world.motion.support_stats.unavailable>0,"Unavailable area support preserves prior presentation Z explicitly")
	world.surface.published=true
	progress("pending-preserved")
	# Published static object pose/removal flows through the actual receiver.
	var template=world.pool.model_template(bundle("static-platform",8,8,0,0));progress("static-template")
	var platform=template.create();world.add_child(platform);world.instances[20]=platform;progress("static-clone")
	var fixed:={"id":20,"objectType":9,"areaId":25,"nativeLifetime":1,"staticState":{"appearance":1},"replicated":{"position":[25.0,25.0,9.0],"orientation":[0.0,1.0,0.0],"appearance":1}}
	world.receive_delta([fixed],[],7);world.installed[20]=world.desired[20].key;progress("static-received")
	row=source(world,5,Vector3(28,28,9));actor(world,row,true);received_path(world,Vector3(28.1,28,9),4);step(world,0.01)
	check(near(world.motion.objects[7].position.z,9) and world.static_collision_index.entries.has(platform.get_instance_id()),"Actual static receiver publication is included in support")
	world.receive_delta([],[20],7);received_path(world,Vector3(28.2,28,9),5);step(world,0.01)
	progress("static-removed")
	check(near(world.motion.objects[7].position.z,0),"Static removal retires support and next movement reaches published lower surface")
	progress("lower-surface-accepted")
	var old_callback: Callable=world.motion.support_query;var old_support: RefCounted=world.client_support_scene;var old_area: int=world.area_id
	world.retiring=true
	check(not old_callback.call(Vector3(5,5,5),5.0).available,"Retiring world immediately fences the real Motion callback")
	progress("retiring-fenced")
	world.retiring=false;world.area_id=26
	check(not old_callback.call(Vector3(5,5,5),5.0).available,"Changed area cannot reuse the old support binding")
	progress("area-fenced")
	world.area_id=old_area
	var policy: Dictionary=world.client_support_scene.snapshot()
	# Production closes owners, then lets queued physical-node retirement drain
	# before freeing the containing host. Exercise that actual lifetime order.
	progress("close-begin");world.close();progress("close-complete");await process_frame;await process_frame;world.free();progress("free-complete");await process_frame;await process_frame
	check(old_callback.is_valid() and old_support.snapshot().retired and not old_callback.call(Vector3(5,5,5),5.0).available,"Explicitly retained support owner stays retired after containing world is freed")
	old_support=null
	check(not old_callback.is_valid() or not old_callback.call(Vector3(5,5,5),5.0).available,"Released callback is invalid or explicitly retired, never rebound to another world")
	var fresh=make_world(2,26);publish(fresh,"fresh-floor",20,20,0,0,Vector3.ZERO)
	row=source(fresh,1,Vector3(5,5,0));actor(fresh,row);received_path(fresh,Vector3(5.2,5,0));step(fresh)
	check(near(fresh.motion.objects[7].position.z,0) and display_matches(fresh),"Fresh area/same object ID uses fresh geometry and display lifetime")
	fresh.close();await process_frame;await process_frame;fresh.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"policy":policy,"serverConnections":0,"nativeBuilds":0,"gpuDraws":0,"scope":"Actual default World receivers/cold support binder/Motion/preview/apply_pose with actual pooled authored physical Parts and existing scene indexes. Readiness/navigation/animation sink are fixture ports; no original campaign load, native BSP tie oracle, live bridge, idle correction or authoritative server outcome claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_PARITY_BRIDGE_WORLD_MOTION ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
