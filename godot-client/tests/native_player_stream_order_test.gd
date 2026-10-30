extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const References=preload("res://systems/native_render/reference_assets.gd")
class TestWorld:
	extends World
	func ready_for_control() -> bool: return true
class Body:
	extends Node3D
	func retire() -> void: queue_free()
class Owner:
	extends Node
	var instances: Dictionary={}
	var invisible_ids: Array=[]
	var done:=true
	var stats:={"errors":[],"scope_errors":[]}
	func set_priority_origin(_value: Vector3) -> void: pass
	func detach_prepared_data() -> Dictionary: return {}
	func close() -> void: pass
class Reference:
	extends Node3D
	var generation:=0
	var retired:=false
	var installed:=false
	func install_bundle(_value: Dictionary,_generation: int) -> bool: installed=true; return true
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func bundle(name: String) -> Dictionary:
	var text: String="newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n"
	var model: Dictionary=ActorData.new().parse(text.to_utf8_buffer())
	return {"value":model,"sha256":Cache.digest(text.to_utf8_buffer()),"textures":{},"error":"","animation_sources":[],"worker_ms":0.0,"cache_hit":false}
func object(id: int,kind: int,x: float) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":1,"replicated":{"position":[x,0,0]}}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var host:=Node3D.new(); root.add_child(host); var pool:=Pool.new()
	var terrain:=Terrain.new(); host.add_child(terrain); terrain.set_process(false); terrain.pool=pool
	terrain.assets=Assets.new(); terrain.add_child(terrain.assets); terrain.assets.set_process(false)
	terrain.definition={"models":{"auth_a":[0,2],"auth_b":[1],"auth_c":[3]},"tiles":[]}
	for row in [{"model":"auth_a","x":90},{"model":"auth_b","x":2},{"model":"auth_a","x":1},{"model":"auth_c","x":100}]:
		terrain.definition.tiles.append({"model":row.model,"position":Vector3(row.x,0,0),"rotation_y":0.0,"main_lights":[0,0]})
	terrain.waiting=["auth_c","auth_b","auth_a"]; terrain.set_priority_origin(Vector3.ZERO); terrain.refresh_priority()
	check(terrain.waiting==["auth_a","auth_b","auth_c"],"Terrain source requests rank each shared model by its closest placement")
	terrain.waiting.clear(); terrain.light_table={"orderedRows":[]}; terrain.diagnostics={"worker_ms":0.0,"cache_hits":0,"errors":[],"templates_built":0,"templates_reused":0,"template_ms":0.0,"clone_ms":0.0,"attach_ms":0.0,"tile_lights":[],"limitations":[],"max_tile_publish_ms":0.0,"publish_frames":0,"publish_ms":0.0,"max_publish_ms":0.0}
	# Reverse worker completion and interleaved placements must not dictate order.
	for index in 3:
		var name: String=["auth_c","auth_b","auth_a"][index]; terrain.requests[index]=name; terrain.model_prepared(index,bundle(name))
	terrain.refresh_priority()
	check(terrain.publish_queue.map(func(row):return row.index)==[2,1,0,3],"Ready tiles publish by player distance across out-of-order model completions")
	var published: Array=[]; terrain.tile_published.connect(func(index,_body):published.append(index)); terrain.maximum_tiles_per_frame=1
	terrain._profile_process(0)
	check(published==[2] and terrain.bundles.has("auth_a") and terrain.publication_remaining.auth_a==1,"Publishing a model's last file-order tile first retains the bundle for its other placement")
	terrain.set_priority_origin(Vector3(100,0,0)); terrain._profile_process(0)
	check(published==[2,3],"Walking toward distant tiles reprioritizes remaining ready terrain")
	for turn in 2: terrain._profile_process(0)
	check(published==[2,3,0,1] and terrain.instances.size()==4 and terrain.bundles.is_empty(),"All original tiles eventually publish exactly once; bundles release only after actual final use")
	terrain.close(); terrain.queue_free(); await process_frame; await process_frame
	var owner:=Objects.new(); host.add_child(owner); owner.set_process(false); owner.pool=pool
	owner.assets=Assets.new(); owner.add_child(owner.assets); owner.assets.set_process(false)
	for row in [{"id":10,"model":"auth_a","x":90},{"id":11,"model":"auth_b","x":2},{"id":12,"model":"auth_a","x":1},{"id":13,"model":"auth_c","x":100}]:
		if not owner.groups.has(row.model): owner.groups[row.model]=[]
		owner.groups[row.model].append({"id":row.id,"model":row.model,"position":Vector3(row.x,0,0),"rotation":0.0,"object":object(row.id,9,row.x)})
	owner.waiting=["auth_c","auth_b","auth_a"]; owner.set_priority_origin(Vector3.ZERO); owner.refresh_priority()
	check(owner.waiting==["auth_a","auth_b","auth_c"],"Scenery preparation ranks shared models by nearest placement")
	owner.waiting.clear()
	for index in 3:
		var name: String=["auth_c","auth_b","auth_a"][index]; owner.model_requests[index]=name; owner.prepared(index,bundle(name))
	owner._profile_process(0)
	check(owner.instances.keys()==[12,11,10,13] and owner.stats.errors.is_empty(),"Actual private scenery instances publish nearest first, interleaving shared models")
	owner.close(); owner.queue_free(); await process_frame; await process_frame
	var actors:=Creatures.new(); host.add_child(actors); actors.set_process(false); actors.assets=Assets.new(); actors.add_child(actors.assets); actors.assets.set_process(false)
	actors.plans=[{"id":1,"position":Vector3(90,0,0),"pieces":[{"key":"far"}]},{"id":2,"position":Vector3(1,0,0),"pieces":[{"key":"near"}]}]; actors.waiting=["far","near"]
	actors.set_priority_origin(Vector3.ZERO); actors.refresh_priority()
	check(actors.plans[0].id==2 and actors.waiting==["near","far"],"Actor plans and complete model dependencies both prioritize nearby actors")
	actors.controlled_priority=1; actors.priority_dirty=true; actors.refresh_priority()
	check(actors.plans[0].id==1 and actors.waiting==["far","near"],"Controlled appearance always outranks distance")
	actors.controlled_priority=-1; actors.set_priority_origin(Vector3(100,0,0)); actors.refresh_priority()
	check(actors.plans[0].id==1,"Moving player reprioritizes pending complete actors")
	actors.close(); actors.queue_free(); await process_frame
	var refs:=References.new(); host.add_child(refs); refs.set_process(false); refs.assets=Assets.new(); refs.add_child(refs.assets); refs.assets.set_process(false)
	var far:=Reference.new(); host.add_child(far); far.position=Vector3(80,0,0)
	var near:=Reference.new(); host.add_child(near); near.position=Vector3(2,0,0)
	refs.requests={"far":[{"node":weakref(far),"generation":0,"resource":"far","kind":"bundle"}],"near":[{"node":weakref(near),"generation":0,"resource":"near","kind":"bundle"}]}; refs.waiting={"far":true,"near":true}
	refs.set_priority_origin(Vector3.ZERO); refs.refresh_priority()
	check(refs.waiting.keys()==["near","far"],"Referenced model preparation follows its nearest live physical owner")
	refs.waiting.clear(); refs.jobs={1:"far",2:"near"}; refs.completed(1,bundle("auth_a")); refs.completed(2,bundle("auth_b")); refs.refresh_priority()
	check(refs.publication[0].request.resource=="near","Reversed reference completion still publishes the nearest ready dependency first")
	refs.maximum_publications=1; refs._profile_process(0)
	check(near.installed and not far.installed,"Actual reference bundle dispatch respects the distance publication quota")
	refs._profile_process(0)
	check(far.installed and refs.publication.is_empty(),"Distant referenced dependencies eventually publish")
	var detached: Dictionary=refs.detach_prepared_data()
	check(refs.prepared.is_empty() and detached.prepared.size()==2 and near.installed,"Retired decoded reference cache detaches without clearing live instances or shared data")
	detached.clear(); refs.close(); refs.queue_free(); far.queue_free(); near.queue_free(); await process_frame
	var service:=Assets.new(); host.add_child(service); service.set_process(false)
	service.pending=[{"id":1},{"id":2},{"id":3}]; service.prioritize([3,1,2])
	check(service.pending.map(func(row):return row.id)==[3,1,2],"Native data service reorders unstarted requests without canceling running work")
	service.pending.clear(); service.close(); service.queue_free()
	var world:=TestWorld.new(); host.add_child(world); world.set_process(false); world.controlled_id=999; world.area_id=1; world.set_priority_origin(Vector3.ZERO)
	var player:=Body.new(); world.add_child(player); world.instances[999]=player
	for id in range(1,72):
		var row:=object(id,9,float(id)); world.desired[id]={"key":str(id),"object":row}
	world.desired[80]={"key":"far-actor","object":object(80,5,1000)}
	var plan: Dictionary=world.pending_plan({})
	check(plan.actors.is_empty() and plan.statics.size()==64 and plan.statics[0].id==1,"Shared distance wave keeps distant actors behind nearby scenery")
	world.instances.clear(); player.free(); world.desired.clear(); world.maximum_adoptions_per_frame=1; world.adoption_budget_ms=1000
	var admitted: Array=[]; world.instance_ready.connect(func(id,_source,_body):admitted.append(id))
	for rows in [[{"id":1,"x":90},{"id":2,"x":4}],[{"id":3,"x":1}]]:
		var ready:=Owner.new(); world.add_child(ready); var keys: Dictionary={}
		for row in rows:
			var body:=Body.new(); world.add_child(body); body.hide(); ready.instances[row.id]=body; keys[row.id]=str(row.id)
			world.desired[row.id]={"key":str(row.id),"object":object(row.id,9,row.x)}
		world.batches.append({"owner":ready,"actors":false,"keys":keys})
	world._profile_process(0)
	check(admitted==[3],"Final visible-world admission chooses the closest ready object across independently completed owners")
	world.set_priority_origin(Vector3(100,0,0)); world._profile_process(0)
	check(admitted==[3,1],"Visible admission follows the moved player rather than original batch order")
	world._profile_process(0)
	check(admitted==[3,1,2] and world.batches.is_empty(),"Bounded cross-owner admission preserves every object and owner cleanup")
	world.close(); world.queue_free(); await process_frame; await process_frame; pool.clear(); host.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"Actual native terrain/scenery publication with authored meshes, reversed model completion, interleaved placements, moved origin, complete actor dependency ordering, queued native jobs, shared distance wave and cross-owner visible admission. No server/FPS acceptance."},"\t")); file.close(); print("NATIVE_PLAYER_STREAM_ORDER ",checks," checks"); quit(0 if failures.is_empty() else 1)
