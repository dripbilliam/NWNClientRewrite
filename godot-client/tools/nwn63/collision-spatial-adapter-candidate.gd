extends SceneTree
const Collision=preload("res://.cache/nwn63/collision-group-index-a/candidate.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const Plan=preload("res://systems/native_data/drive_preview.gd")
class QuietCombat:
	extends Node
	func forget(_id: int,_removed: bool=false)->void:pass
	func sync(_id: int,_source: Dictionary,_instance)->void:pass
	func close()->void:pass
class QuietWorld:
	extends World
	func _enter_tree()->void:pass
class FrozenLegacy:
	extends "res://tests/native_drive_collision_legacy.gd"
	func demand(_spec: Dictionary)->void:pass
var checks:=0
var failures: Array=[]
var measurements: Dictionary={}
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<50:failures.append(label)
func _initialize()->void:call_deferred("run")
func tables()->Dictionary:
	return {"appearance":{"orderedRows":[{"PERSPACE":"0.3","HEIGHT":"1.8"},{"PERSPACE":"1.2","HEIGHT":"2.5"}]},"placeables":{"orderedRows":[{"ModelName":"chest"},{"ModelName":"giant"}]},"genericdoors":{"orderedRows":[{"ModelName":"gate"}]},"doortypes":{}}
func footprint(width: float=1.0)->Dictionary:
	return {"vertices":[Vector3(0,0,0),Vector3(width,0,0),Vector3(width,1,2),Vector3(0,1,2)],"faces":[[0,1,2],[0,2,3]]}
func creature(id: int,point: Vector2,known: int=1)->Dictionary:
	return {"id":id,"areaId":91,"objectType":5,"nativeLifetime":id+100,"clientKnownLifetime":known,"appearance":{"appearance":0},"replicated":{"position":[point.x,point.y,0],"orientation":[1,0],"animation":0,"walkRate":2000,"runRate":4000}}
func object(id: int,point: Vector2,kind: int=9,known: int=1,appearance: int=0)->Dictionary:
	var row:={"id":id,"areaId":91,"objectType":kind,"nativeLifetime":id+100,"clientKnownLifetime":known}
	if kind==9:row.staticState={"appearance":appearance,"position":[point.x,point.y,0],"orientation":{"yaw":0},"usable":false,"static":true}
	else:row.replicated={"doorType":0,"genericType":0,"doorOpenState":0,"position":[point.x,point.y,0],"orientation":{"yaw":0}}
	return row
func make_world(indexed: bool=true)->Dictionary:
	var world:=QuietWorld.new();root.add_child(world);world.set_process(false);world.generation=3;world.area_id=91
	world.combat=QuietCombat.new();world.add_child(world.combat)
	var floor:=Surface.new();world.add_child(floor);world.surface=floor;floor.done=true;floor.set_process(false)
	floor.table={"orderedRows":[{"Walk":"1"}]}
	var tiles: Array=[]
	for i in 4096:tiles.append({"model":"floor","orientation":0,"position":Vector3((i%64)*10+5,0,-(i/64)*10-5)})
	floor.definition={"width":64,"height":64,"tiles":tiles}
	floor.meshes={"floor":{"vertices":[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0],"normals":[[0,0,1],[0,0,1]],"constants":[0,0]}}
	var collision
	if indexed:
		collision=Collision.new();world.add_child(collision);collision.world=world;collision.tables=tables();world.drive_collision=collision;collision.ensure_spatial_scope();collision.set_process(false)
	return {"world":world,"collision":collision}
func legacy_for(world)->Node:
	var legacy:=FrozenLegacy.new();world.add_child(legacy);legacy.world=world;legacy.tables=tables();legacy.set_process(false)
	return legacy
func same_lines(collision,legacy,lines: Array,label: String)->void:
	for override in [-1.0,1.0/64.0]:
		var actual: Callable=collision.query(1,override)
		var previous: Callable=legacy.query(1,override)
		check(actual.is_valid() and previous.is_valid(),label+" query readiness")
		if not actual.is_valid() or not previous.is_valid():continue
		for line in lines:
			var accepted: bool=actual.call(line[0],line[1])
			var old_accepted: bool=previous.call(line[0],line[1])
			check(accepted==old_accepted,label+" exact legacy clear equivalence "+str(override))
			if not accepted and not old_accepted:check(collision.stats.last_blocked.reason==legacy.stats.last_blocked.reason,label+" exact first blocked reason")
	var a: Callable=collision.query(1)
	var b: Callable=legacy.query(1)
	if a.is_valid() and b.is_valid():
		var start:=Vector3(3.6,1.5,0)
		var target:=Vector3(4.6,2.5,0)
		check(Plan.path(start,target,start,a)==Plan.path(start,target,start,b),label+" exact selected path/factor equivalence")
func lifecycle()->void:
	var setup:=make_world()
	var world=setup.world
	var collision=setup.collision
	var legacy=legacy_for(world)
	var chest:=footprint()
	var empty:={"vertices":[],"faces":[]}
	collision.publish_model("chest:placeable",{"states":[chest]});legacy.models["chest:placeable"]={"states":[chest]}
	collision.publish_model("gate:door",{"states":[chest,empty,empty]});legacy.models["gate:door"]={"states":[chest,empty,empty]}
	var a:=creature(1,Vector2(1,1))
	var chest_row:=object(2,Vector2(4,1))
	var door:=object(3,Vector2(9,1),10)
	var other:=creature(4,Vector2(6,3))
	world.receive([a,chest_row,door,other],1)
	check(collision.ready(),"Actual World.receive publishes the initial collision membership")
	check(collision.objects.is_empty(),"Full receive does not triangulate every static object")
	var lines: Array=[[Vector3(2,1.5,0),Vector3(6,1.5,0)],[Vector3(2,3,0),Vector3(8,3,0)],[Vector3(8,1.5,0),Vector3(11,1.5,0)],[Vector3(1,7,0),Vector3(8,7,0)]]
	same_lines(collision,legacy,lines,"Initial PWK/DWK/creature")
	check(collision.objects.has(2),"Precise PWK is lazy on an actually selected query")
	door=door.duplicate(true);door.replicated.doorOpenState=1
	world.receive_delta([door],[],1)
	same_lines(collision,legacy,lines,"Door opened")
	door.replicated.doorOpenState=0;world.receive_delta([door],[],1)
	same_lines(collision,legacy,lines,"Door reclosed same lifetime")
	world.motion.objects[4].render=Vector3(100,100,0);collision.sync_motion()
	same_lines(collision,legacy,lines,"Moving creature updated before query")
	var held: Callable=collision.query(1)
	var fresh:=a.duplicate(true);fresh.clientKnownLifetime=2
	world.receive_delta([fresh],[2],1)
	check(not held.call(Vector3(1,7,0),Vector3(8,7,0)),"Old actor-lifetime closure cannot act after same-ID redisclosure")
	check(not collision.source_rows.has(2) and not collision.objects.has(2),"Actual delta removal retires source and precise cache")
	chest_row=object(2,Vector2(30,30),9,2)
	world.receive_delta([chest_row],[],1)
	check(collision.source_rows[2].witness==[102,2],"Actual same-ID new lifetime rebinds exact witness")
	check(collision.query(1).call(Vector3(2,1.5,0),Vector3(6,1.5,0)),"Reused source cannot keep old obstacle pose")
	# Prepared source is globally known before its potentially far origin is near.
	var giant:=object(9,Vector2(100,1),9,1,1)
	world.receive_delta([giant],[],1)
	legacy.models.erase("giant:placeable")
	check(collision.query(1).call(Vector3(2,1.5,0),Vector3(3,1.5,0)),"Unknown far model retains only legacy pending12m admission")
	var giant_mesh:={"vertices":[Vector3(-100,0,0),Vector3(1,0,0),Vector3(1,1,2),Vector3(-100,1,2)],"faces":[[0,1,2],[0,2,3]]}
	collision.publish_model("giant:placeable",{"states":[giant_mesh]});legacy.models["giant:placeable"]={"states":[giant_mesh]}
	check(not collision.query(1).call(Vector3(2,1.5,0),Vector3(3,1.5,0)),"Known large geometry replaces pending12m and reaches far-from-origin footprint")
	same_lines(collision,legacy,lines,"Completed large PWK")
	# Invalid explicit native identity remains unavailable until a valid receipt.
	var malformed:=fresh.duplicate(true);malformed.clientKnownLifetime=null
	world.receive_delta([malformed],[],1);collision.sync_motion()
	check(not collision.query(1).is_valid(),"Malformed received lifetime cannot be erased by motion refresh")
	world.receive_delta([fresh],[],1)
	check(collision.query(1).is_valid(),"Current valid publication restores collision admission")
	var stale_ticket: Dictionary=collision.spatial_ticket.duplicate(true)
	collision.requests[900]={"model":"giant:placeable","ticket":stale_ticket}
	collision.retire_index()
	collision.prepared(900,{"error":"","value":{"states":[chest]}})
	check(not collision.ready() and collision.spatial.snapshot().entries==0,"Late actual prepared callback cannot repopulate retired scope")
	world.free()
func boundary_measurements()->void:
	var rows: Array=[creature(1,Vector2(1,1))]
	for i in 2000:rows.append(object(1000+i,Vector2(100+(i%50)*10,100+(i/50)*10)))
	var baseline:=make_world(false)
	var began:=Time.get_ticks_usec();baseline.world.receive(rows,1)
	measurements.authored_full_world_without_index_ms=(Time.get_ticks_usec()-began)/1000.0
	baseline.world.free()
	var setup:=make_world()
	var world=setup.world
	var collision=setup.collision
	began=Time.get_ticks_usec();world.receive(rows,1)
	measurements.authored_full_world_with_pending_index_ms=(Time.get_ticks_usec()-began)/1000.0
	measurements.initial_tree_build_ms=collision.snapshot().static_last_bulk_ms+collision.spatial.snapshot().last_bulk_ms
	check(collision.ready() and collision.source_rows.size()==2001,"Cold full source membership is complete before ready")
	check(collision.objects.is_empty(),"Cold full boundary leaves distant precise shapes unbuilt")
	var model:=footprint(2)
	var retained_revision: int=collision.static_groups["chest:placeable"].index._rows[1000].revision
	began=Time.get_ticks_usec();collision.publish_model("chest:placeable",{"states":[model]})
	measurements.one_model_2000_users_publication_ms=(Time.get_ticks_usec()-began)/1000.0
	check(collision.static_groups["chest:placeable"].index._rows[1000].revision==retained_revision,"Model completion does not republish source center leaves")
	check(collision.ready() and collision.objects.is_empty(),"Known model cohort has complete coarse coverage without far triangulation")
	var legacy=legacy_for(world);legacy.models["chest:placeable"]={"states":[model]}
	began=Time.get_ticks_usec();var old_query: Callable=legacy.query(1)
	measurements.legacy_query_factory_2001_rows_ms=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec();var new_query: Callable=collision.query(1)
	measurements.index_query_factory_ms=(Time.get_ticks_usec()-began)/1000.0
	var from:=Vector3(1,1,0)
	var to:=Vector3(3,1,0)
	began=Time.get_ticks_usec()
	for i in 40:check(new_query.call(from,to)==old_query.call(from,to),"Warm dense-scene legacy boolean equivalence")
	measurements.paired_40_clear_calls_ms=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec()
	for i in 40:new_query.call(from,to)
	measurements.index_only_40_clear_calls_ms=(Time.get_ticks_usec()-began)/1000.0
	collision.retained_flat_control=true
	began=Time.get_ticks_usec();var flat_query: Callable=collision.query(1)
	measurements.retained_flat_query_factory_ms=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec()
	for i in 40:check(flat_query.call(from,to)==old_query.call(from,to),"Retained flat control exact legacy boolean equivalence")
	measurements.paired_flat_40_clear_calls_ms=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec()
	for i in 40:flat_query.call(from,to)
	measurements.retained_flat_only_40_clear_calls_ms=(Time.get_ticks_usec()-began)/1000.0
	collision.retained_flat_control=false
	check(collision.objects.is_empty(),"Warm near queries do not triangulate faraway geometry")
	measurements.spatial=collision.spatial.snapshot()
	measurements.static_groups=collision.snapshot().static_groups
	measurements.static_entries=collision.snapshot().static_entries
	world.free()
func streaming_motion()->void:
	var setup:=make_world()
	var world=setup.world;var collision=setup.collision
	var legacy=legacy_for(world)
	var rows: Array=[creature(1,Vector2(1,1))]
	for i in 72:rows.append(creature(100+i,Vector2(20+(i%12)*3,20+(i/12)*3)))
	world.receive(rows,1)
	var initial_revision: int=collision.spatial._rows[100].revision
	var began:=Time.get_ticks_usec()
	for frame in 60:
		for i in 72:world.motion.objects[100+i].render=Vector3(20+(i%12)*3+float(frame)/100,20+(i/12)*3,0)
		collision.sync_motion()
	measurements.authored_72_creatures_60_motion_sync_ms=(Time.get_ticks_usec()-began)/1000.0
	check(collision.spatial._rows[100].revision==initial_revision,"Current exact creature circle moves within conservative tree slack without reinsertion")
	check(collision.source_rows[100].point==Vector2(world.motion.objects[100].render.x,world.motion.objects[100].render.y),"Creature narrowphase point remains current inside slack")
	world.motion.objects[100].render=Vector3(4,1,0);collision.sync_motion()
	check(collision.spatial._rows[100].revision>initial_revision,"Movement beyond retained slack republishes covering bound")
	var lines: Array=[[Vector3(2,1,0),Vector3(6,1,0)],[Vector3(2,3,0),Vector3(8,3,0)]]
	same_lines(collision,legacy,lines,"Current moving creatures with fat coarse bounds")
	var far:=object(500,Vector2(400,400))
	began=Time.get_ticks_usec();world.receive_delta([far],[],1)
	measurements.authored_far_spawn_delta_ms=(Time.get_ticks_usec()-began)/1000.0
	check(collision.query(1).is_valid(),"Far pending spawn does not globally suspend already-ready drive prediction")
	same_lines(collision,legacy,lines,"Far pending spawn")
	var revision: int=collision.static_groups["chest:placeable"].index._rows[500].revision
	var mesh:=footprint();collision.publish_model("chest:placeable",{"states":[mesh]});legacy.models["chest:placeable"]={"states":[mesh]}
	check(collision.query(1).is_valid() and collision.static_groups["chest:placeable"].index._rows[500].revision==revision,"Far model arrival updates geometry metadata without prediction readiness barrier")
	far.staticState.position=[4,1,0];world.receive_delta([far],[],1)
	same_lines(collision,legacy,lines,"Static source transform update")
	var changed:=creature(500,Vector2(8,3))
	world.receive_delta([changed],[],1)
	same_lines(collision,legacy,lines,"Same-witness static to creature kind change")
	check(not collision.static_groups["chest:placeable"].index._rows.has(500),"Kind change withdraws old static-group membership")
	world.free()
func run()->void:
	lifecycle();boundary_measurements();streaming_motion()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"scope":"Actual World.receive/receive_delta and collision adapter versus exact frozen legacy query/path code over authored geometry, plus CPU boundary diagnostics. No original server, original collision oracle, GPU or clean performance acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
