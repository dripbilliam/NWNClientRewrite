extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Legacy=preload("res://systems/native_render/drive_collision.gd")
const Indexed=preload("res://systems/native_render/drive_collision_indexed.gd")
const Oracle=preload("res://tests/native_perf140_loading_drive_legacy.gd")
const Plan=preload("res://systems/native_data/drive_preview.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const Motion=preload("res://systems/network_motion.gd")
class QueryWorld:
	extends Node
	var desired: Dictionary={}
	var surface
	var motion:=Motion.new()
class PreviewWorld:
	extends World
	func ready_for_control()->bool:return not closed
class FreeCollision:
	extends Node
	func query(_id: int)->Callable:return func(_from,_to):return true
	func close()->void:pass
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var filename:="";var selected:=World.configured_drive_collision(OS.get_cmdline_user_args());var expected_index: bool=selected.valid and selected.requested=="indexed"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):filename=arg.trim_prefix("--report=")
	if filename.is_empty() or FileAccess.file_exists(filename):quit(2);return
	var world:=World.new()
	# The live viewport installs this metadata owner before snapshots. Use an
	# explicitly expired WeakRef for the off-tree fixture's absent shadow owner.
	var former_shadow:=Node.new();world.set_meta("native_point_shadow_budget",weakref(former_shadow));former_shadow.free()
	check(world.drive_spatial_enabled==expected_index,"CLI selection is initialized before World.open")
	var owner: Node=world._new_drive_collision()
	check(owner.get_script()==(Indexed if expected_index else Legacy),"The actual open factory creates the explicitly selected collision owner")
	world.drive_collision=owner;world.add_child(owner)
	check(world.snapshot(false).drive_collision_route==("indexed" if expected_index else "legacy"),"Snapshot reports the actual instantiated owner")
	world.drive_spatial_enabled=not expected_index
	check(world.drive_collision==owner and world.snapshot(false).drive_collision_route==("indexed" if expected_index else "legacy"),"Changing the future preference never hot-switches the live owner")
	world.close();world.free()
	# The separate exact geometry hoist/probe path must return identical numeric
	# vertices/triangles/bounds/signatures to the original unchanged flat code.
	Profile.enabled=true;Profile.phases={};Profile.phase_frame=-1;Profile.collected_frame=-1
	var actual:=Legacy.new();var oracle:=Oracle.new()
	var state:={"vertices":[Vector3(-1,-2,-3),Vector3.ZERO,Vector3(1.25,0.125,4),Vector3(6,-8,10)],"faces":[[0,1,2],[1,2,3]]}
	actual.models["shape:placeable"]={"states":[state]};oracle.models["shape:placeable"]={"states":[state]}
	var id:=1
	for yaw in [-1000000.0,-360.0,-180.0,-90.0,-0.0,0.0,0.001,45.0,90.0,180.0,360.0,1000000.0]:
		for position in [[0.0,0.0,0.0],[-15.0,30.0,0.25],[100000.0,-200000.0,32.0]]:
			var object:={"objectType":9,"staticState":{"position":position,"orientation":{"yaw":yaw}}}
			var spec:={"model":"shape","door":false,"state":0}
			var old: Dictionary=oracle.obstacle(id,object,spec);var value: Dictionary=actual.obstacle(id,object,spec)
			check(var_to_bytes(value)==var_to_bytes(old),"Exact transformed shape/signature/bounds bits yaw="+str(yaw)+" position="+str(position))
			check(is_same(actual.obstacle(id,object,spec),value),"Unchanged pose reuses the exact cached shape owner")
			id+=1
	check(int(Profile.phases.get("count_drive_shape_builds",0))==36,"Shape-build counter records only real signature misses")
	check(int(Profile.phases.get("count_drive_shape_cache_hits",0))==36,"Shape-cache counter records exact reuse")
	check(int(Profile.phases.get("count_drive_shape_vertices",0))==144 and int(Profile.phases.get("count_drive_shape_faces",0))==72,"Aggregate source vertex/face counters preserve actual shape work")
	check(Profile.phases.has("drive_shape_build"),"Detailed shape phase is recorded")
	var query_world:=QueryWorld.new();var floor:=Surface.new();query_world.add_child(floor);query_world.surface=floor;floor.set_process(false);floor.done=true
	floor.table={"orderedRows":[{"Walk":"1"}]}
	floor.definition={"width":1,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3(5,0,-5)}]}
	floor.meshes={"floor":{"vertices":[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0],"normals":[[0,0,1],[0,0,1]],"constants":[0,0]}}
	actual.world=query_world;actual.tables={"appearance":{"orderedRows":[{"PERSPACE":"0.3","HEIGHT":"1.8"}]},"placeables":{},"genericdoors":{},"doortypes":{}}
	query_world.desired[1]={"object":{"objectType":5,"appearance":{"appearance":0}}};query_world.motion.ensure(1,{"position":[1,1,0]})
	var line: Callable=actual.query(1)
	check(line.is_valid() and line.call(Vector3(1,1,0),Vector3(5,1,0)),"Profiled flat clear retains actual WOK floor coverage")
	check(Plan.path(Vector3(1,1,0),Vector3(2,1,0),Vector3(1,1,0),line)=={"target":Vector3(2,1,0),"factor":1.0},"Profiled path result remains exact")
	check(int(Profile.phases.get("count_drive_factory_rows",0))==1,"Factory source-row count is explicit")
	check(int(Profile.phases.get("count_drive_clear_calls",0))==2,"Every completed narrow-phase call is counted")
	check(int(Profile.phases.get("count_drive_tile_builds",0))==1 and int(Profile.phases.get("count_drive_tile_cache_hits",0))==1,"Tile first touch and subsequent reuse remain distinct")
	for field in ["drive_query_factory","drive_clear","drive_clear_heights","drive_tile_build"]:check(Profile.phases.has(field),"Detailed collision subphase recorded: "+field)
	var preview_world:=PreviewWorld.new();preview_world.controlled_id=1
	var preview_collision:=FreeCollision.new();preview_world.add_child(preview_collision);preview_world.drive_collision=preview_collision
	var received:={"position":[1,1,0],"orientation":[1,0,0],"animation":0,"walkRate":2000,"runRate":4000};var before:=var_to_bytes(received)
	preview_world.desired[1]={"object":{"replicated":received}};preview_world.motion.ensure(1,received)
	check(not preview_world.preview_drive(1,3,-1).is_empty(),"Actual World.preview_drive accepts the unchanged free query")
	check(Profile.phases.has("keyboard_preview_query") and Profile.phases.has("keyboard_preview_path") and Profile.phases.has("keyboard_preview"),"Actual World reports query/path within its unchanged total span")
	check(var_to_bytes(received)==before,"Detailed prediction never mutates received server state")
	preview_world.close();preview_world.free()
	actual.close();oracle.close();actual.free();oracle.free();query_world.free()
	Profile.enabled=false;Profile.phases={}
	await process_frame;await process_frame
	var file:=FileAccess.open(filename,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"indexed":expected_index,"scope":"Actual CLI constructor/open factory and snapshot owner identity; no hot switch. Exact frozen-original obstacle transform/cache bits. Headless correctness only; full loading, streaming, authoritative gameplay and measured timing remain separate."},"  "));file.close();quit(0 if failures.is_empty() else 1)
