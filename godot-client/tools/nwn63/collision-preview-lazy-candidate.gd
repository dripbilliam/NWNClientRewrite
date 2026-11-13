extends "res://tools/nwn63/collision-spatial-adapter-candidate.gd"
const Profile=preload("res://systems/native_render/frame_profile.gd")
class PreviewWorld:
	extends "res://systems/native_render/live_world.gd"
	func ready_for_control()->bool:return not closed
class SpyGeometry:
	extends Node
	var owner_world
	var calls: Array=[]
	func query(_id: int,_radius: float=-1)->Callable:return func(_a,_b):return true
	func query_preview(id: int,from: Vector3,target: Vector3,render: Vector3,_radius: float=-1)->Callable:
		calls.append({"id":id,"from":from,"target":target,"render":render,"orientation":owner_world.motion.objects[id].orientation})
		return func(_a,_b):return true
	func close()->void:pass
func primed_query(collision,id: int,from: Vector3,target: Vector3,render: Vector3,radius: float=-1)->Callable:
	var clear: Callable=collision.query_preview(id,from,target,render,radius)
	if clear.is_valid():clear.call(from,target);clear.call(from,target)
	return clear
func compare_input(collision,from: Vector3,target: Vector3,render: Vector3,label: String)->void:
	var old: Callable=collision.query(1);var cached: Callable=collision.query_preview(1,from,target,render)
	check(old.is_valid() and cached.is_valid(),label+" both callbacks are ready")
	if not old.is_valid() or not cached.is_valid():return
	var a: Array=[];var b: Array=[]
	var ordinary:=func(x: Vector3,y: Vector3):
		var clear: bool=old.call(x,y);a.append([x,y,clear,collision.stats.get("last_blocked",{}).get("reason","") if not clear else ""]);return clear
	var retained:=func(x: Vector3,y: Vector3):
		var clear: bool=cached.call(x,y);b.append([x,y,clear,collision.stats.get("last_blocked",{}).get("reason","") if not clear else ""]);return clear
	collision.stats.erase("last_blocked");var expected:=Plan.path(from,target,render,ordinary)
	collision.stats.erase("last_blocked");var actual:=Plan.path(from,target,render,retained)
	check(a==b,label+" exact clear order/endpoints/decisions/blocked reasons")
	check(var_to_bytes(expected)==var_to_bytes(actual),label+" exact native path target/factor/fraction result")
func fixture()->Dictionary:
	var setup:=make_world();var world=setup.world;var collision=setup.collision
	var chest:=footprint();var empty:={"vertices":[],"faces":[]}
	collision.publish_model("chest:placeable",{"states":[chest]});collision.publish_model("gate:door",{"states":[chest,empty,empty]})
	var giant:={"vertices":[Vector3(-80,0,0),Vector3(-60,0,0),Vector3(-60,3,3),Vector3(-80,3,3)],"faces":[[0,1,2],[0,2,3]]}
	collision.publish_model("giant:placeable",{"states":[giant]})
	world.receive([creature(1,Vector2(1,1)),object(2,Vector2(4,1)),object(3,Vector2(9,1),10),creature(4,Vector2(6,3)),object(5,Vector2(80,12),9,1,1)],1)
	return setup
func geometry_and_paths()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	for row in [
		[Vector3(1,7,0),Vector3(4,7,0),Vector3(1,7,0),"free"],
		[Vector3(2,1.5,0),Vector3(6,1.5,0),Vector3(2,1.5,0),"PWK"],
		[Vector3(8,1.5,0),Vector3(11,1.5,0),Vector3(8,1.5,0),"DWK"],
		[Vector3(3.6,1.5,0),Vector3(4.6,2.5,0),Vector3(3.1,1.8,0),"different-rendered-origin"],
		[Vector3(2,13,0),Vector3(7,13,0),Vector3(2,13,0),"large-model-far-anchor"],
		[Vector3(1,7,1000),Vector3(4,7,1000),Vector3(1,7,-1000),"unknown-Z-no-prefilter"]
	]:compare_input(collision,row[0],row[1],row[2],row[3])
	var seed:=RandomNumberGenerator.new();seed.seed=0x6b7f3102
	for index in 96:
		var from:=Vector3(seed.randf_range(0.5,16),seed.randf_range(0.5,16),seed.randf_range(-2,2))
		var target:=from+Vector3(seed.randf_range(-1.6,1.6),seed.randf_range(-1.6,1.6),0)
		var render:=from+Vector3(seed.randf_range(-0.8,0.8),seed.randf_range(-0.8,0.8),seed.randf_range(-1,1))
		compare_input(collision,from,target,render,"seeded-"+str(index))
	# Explicit endpoint containment makes any unexpected escape use unrestricted
	# geometry. No finite-distance or Z guess can remove collision coverage.
	var cached: Callable=primed_query(collision,1,Vector3(1,1,0),Vector3(2,1,0),Vector3(1,1,0))
	var before: int=collision.preview_stats.fallback_clears
	check(cached.call(Vector3(50,50,0),Vector3(52,50,0))==collision.query(1).call(Vector3(50,50,0),Vector3(52,50,0)),"Out-of-envelope segment uses full original query")
	check(collision.preview_stats.fallback_clears==before+1,"Envelope escape is counted, not silently clipped")
	before=collision.preview_stats.fallback_clears
	check(cached.call(Vector3(1,1,INF),Vector3(2,1,INF))==collision.query(1).call(Vector3(1,1,INF),Vector3(2,1,INF)),"Nonfinite actual probe retains original invalid-query behavior")
	check(collision.preview_stats.fallback_clears==before+1,"Unknown nonfinite endpoint uses original safety gate")
	var collections: int=collision.preview_stats.collections
	var authority: Callable=collision.query(1,1.0/64)
	check(authority.call(Vector3(1,7,0),Vector3(40,7,0))==collision.query(1,1.0/64).call(Vector3(1,7,0),Vector3(40,7,0)),"Authoritative-waypoint callback remains unrestricted")
	check(collision.preview_stats.collections==collections,"Ordinary authoritative query never creates an input envelope")
	world.free()
func corner_and_radius()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	var start:=Vector3(10,10,0);var target:=Vector3(11,10,0);var corner:=Vector3(8.6,11.6,0)
	world.receive([creature(1,Vector2(10,10)),object(90,Vector2(8.2,11.2))],1)
	var cached: Callable=primed_query(collision,1,start,target,start)
	var old: bool=collision.query(1).call(start,corner)
	check(not old and cached.call(start,corner)==old,"Off-diagonal envelope corner retains exact PWK collision")
	check(collision.preview_stats.reused_clears>0,"Off-diagonal corner uses collected geometry rather than accidental escape fallback")
	var appearance: int=collision.tables.placeables.orderedRows.size();collision.tables.placeables.orderedRows.append({"ModelName":"pending_corner"})
	world.receive([creature(1,Vector2(10,10)),object(91,Vector2(12,12),9,1,appearance)],1)
	cached=primed_query(collision,1,start,target,start)
	check(not cached.call(start,corner) and str(collision.stats.last_blocked.reason)=="pending_object","Pending corner source keeps original pending-shape gate")
	check(cached.call(start,corner)==collision.query(1).call(start,corner),"Pending corner agrees with unrestricted callback")
	collision.tables.appearance.orderedRows[1].PERSPACE="12.0"
	var actor:=creature(1,Vector2(10,10));actor.appearance.appearance=1
	world.receive([actor,object(92,Vector2(20,10))],1)
	cached=primed_query(collision,1,start,target,start)
	old=collision.query(1).call(start,target)
	check(not old and str(collision.stats.last_blocked.reason)=="object_polygon","Large-radius oracle actually reaches far exact geometry")
	check(cached.call(start,target)==old,"Large personal-space radius expands collection rather than truncating geometry")
	world.free()
func invalidations()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	var a:=Vector3(2,1.5,0);var b:=Vector3(6,1.5,0)
	var cached: Callable=primed_query(collision,1,a,b,a);var before: int=collision.preview_stats.fallback_clears
	var chest: Dictionary=world.desired[2].object.duplicate(true);chest.staticState.orientation.yaw=90;world.receive_delta([chest],[],1)
	check(cached.call(a,b)==collision.query(1).call(a,b),"Rotation-only source change invalidates prepared exact shapes")
	check(collision.preview_stats.fallback_clears==before+1,"Same-anchor rotation enters original fallback")
	cached=primed_query(collision,1,a,b,a);before=collision.preview_stats.fallback_clears
	var index_center: Vector2=collision.source_rows[4].index_center
	world.motion.objects[4].render=Vector3(4.1,1.5,0);collision.sync_motion_id(4)
	check(collision.source_rows[4].index_center==index_center,"Motion invalidation case does not reinsert the retained creature bound")
	check(cached.call(a,b)==collision.query(1).call(a,b),"Creature center changes inside retained slack invalidate input view")
	check(collision.preview_stats.fallback_clears==before+1,"Inside-slack motion is fenced without relying on tree reinsertion")
	cached=primed_query(collision,1,a,b,a);before=collision.preview_stats.fallback_clears
	collision.publish_model("chest:placeable",{"states":[{"vertices":[],"faces":[]}]})
	check(cached.call(a,b)==collision.query(1).call(a,b),"Prepared model/state replacement invalidates old exact geometry")
	check(collision.preview_stats.fallback_clears==before+1,"Model callback is fenced independently of source position")
	var far_start:=Vector3(30,30,0);var far_end:=Vector3(31,30,0)
	cached=primed_query(collision,1,far_start,far_end,far_start);before=collision.preview_stats.fallback_clears
	collision.publish_model("chest:placeable",{"states":[footprint()]})
	chest=world.desired[2].object.duplicate(true);chest.staticState.position=[30.5,30,0];world.receive_delta([chest],[],1)
	check(cached.call(far_start,far_end)==collision.query(1).call(far_start,far_end),"In-frame authoritative source movement into an old envelope is not missed")
	check(collision.preview_stats.fallback_clears==before+1,"Authoritative membership/pose changes force current unrestricted geometry")
	cached=primed_query(collision,1,a,b,a)
	world.receive_delta([], [1],1)
	check(not cached.call(a,b),"Removed controlled lifetime cannot resolve a prepared view")
	world.receive_delta([creature(1,Vector2(1,1),2)],[],1)
	check(not cached.call(a,b),"Same ID with replacement lifetime cannot revive an old input view")
	cached=primed_query(collision,1,a,b,a);collision.retire_index()
	check(not cached.call(a,b),"Area retirement invalidates prepared and fallback tickets")
	world.free()
func pending_and_height()->void:
	var setup:=make_world();var world=setup.world;var collision=setup.collision
	world.receive([creature(1,Vector2(1,1)),object(2,Vector2(4,1))],1)
	var a:=Vector3(2,1.5,0);var b:=Vector3(6,1.5,0);var cached: Callable=primed_query(collision,1,a,b,a)
	check(not cached.call(a,b) and not collision.query(1).call(a,b),"Pending near geometry retains its original conservative gate")
	collision.publish_model("chest:placeable",{"states":[{"vertices":[],"faces":[]}]})
	check(cached.call(a,b)==collision.query(1).call(a,b),"Pending model arrival falls back to current full geometry")
	world.free()
	setup=make_world();world=setup.world;collision=setup.collision
	world.surface.meshes.floor.vertices=[[0,0,1000],[10,0,1000],[10,10,1000],[0,10,1000]];world.surface.meshes.floor.constants=[-1000,-1000]
	collision.publish_model("chest:placeable",{"states":[footprint()]})
	var high:=object(2,Vector2(4,1));high.staticState.position[2]=1000
	world.receive([creature(1,Vector2(1,1)),high],1)
	compare_input(collision,Vector3(2,1.5,0),Vector3(6,1.5,0),Vector3(2,1.5,0),"high-floor-unknown-input-Z")
	check(not primed_query(collision,1,a,b,a).call(a,b),"Synthetic envelope Z never discards a high-floor obstacle")
	world.free()
func collection_once()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	for index in 40:
		var key:="far_"+str(index);collision.tables.placeables.orderedRows.append({"ModelName":key});collision.publish_model(key+":placeable",{"states":[footprint()]})
		world.receive_delta([object(100+index,Vector2(100+index*3,100),9,1,collision.tables.placeables.orderedRows.size()-1)],[],1)
	Profile.enabled=true;Profile.phases={};Profile.phase_frame=-1;Profile.collected_frame=-1
	var cached: Callable=primed_query(collision,1,Vector3(1,7,0),Vector3(2,7,0),Vector3(1,7,0))
	var group_inputs: int=int(Profile.phases.get("count_drive_model_group_inputs",0))
	check(group_inputs==collision.static_groups.size()*2,"Priming includes one unrestricted and one scoped-envelope collection")
	var reused_before: int=int(Profile.phases.get("count_drive_preview_reused_clears",0))
	for repeat in 38:check(cached.call(Vector3(1,7,0),Vector3(2,7,0)),"Cached clear retains floor result "+str(repeat))
	check(int(Profile.phases.get("count_drive_model_group_inputs",0))==group_inputs,"Thirty-eight contained probes do not repeat group collection")
	check(int(Profile.phases.get("count_drive_preview_reused_clears",0))-reused_before==38,"FrameProfile additive counter receives one per actual reuse")
	Profile.enabled=false;Profile.phases={}
	var frame:=Engine.get_process_frames()
	for attempt in 3:
		await process_frame
		if Engine.get_process_frames()!=frame:break
	check(Engine.get_process_frames()!=frame,"Cross-frame oracle actually advances the engine frame stamp")
	var before: int=collision.preview_stats.fallback_clears
	check(cached.call(Vector3(1,7,0),Vector3(2,7,0))==collision.query(1).call(Vector3(1,7,0),Vector3(2,7,0)),"Escaped callback in another frame uses original current state")
	check(collision.preview_stats.fallback_clears==before+1,"Cross-frame stale reuse is explicitly fenced")
	collision.preview_revision=0x7fffffffffffffff;collision.invalidate_preview_geometry()
	var collected: int=collision.preview_stats.collections;var safe: Callable=primed_query(collision,1,Vector3(1,7,0),Vector3(2,7,0),Vector3(1,7,0))
	check(safe.is_valid() and safe.call(Vector3(1,7,0),Vector3(2,7,0)) and collision.preview_stats.collections==collected,"Revision exhaustion disables optional reuse and keeps original collision")
	world.free()
func orientation_order()->void:
	var world:=PreviewWorld.new();world.controlled_id=1
	var collision:=Collision.new();world.add_child(collision);world.drive_collision=collision
	var received:={"position":[1,1,0],"orientation":[1,0,0],"animation":0,"walkRate":2000,"runRate":4000}
	world.desired[1]={"object":{"replicated":received}};var state: Dictionary=world.motion.ensure(1,received);var before:=var_to_bytes(state)
	check(world.preview_drive(1,3,900).is_empty() and var_to_bytes(state)==before,"Unready geometry never commits the planned heading early")
	collision.free();var spy:=SpyGeometry.new();world.add_child(spy);world.drive_collision=spy;spy.owner_world=world
	var orientation: Vector3=state.orientation;var expected:=Plan.plan(state.position,Plan.wire_facing(900),state.walkRate,state.runRate,3)
	var result:=world.preview_drive(1,3,900)
	check(spy.calls.size()==1 and spy.calls[0].orientation==orientation,"Preview collection observes the same pre-commit orientation as original query")
	check(spy.calls[0].target==expected.target and result.target==expected.target,"Local planned target and final path exactly preserve heading math")
	check(state.orientation==Plan.wire_facing(900),"Ready query commits the original heading at the original boundary")
	world.close();world.free()
func run()->void:
	geometry_and_paths();corner_and_radius();invalidations();pending_and_height();await collection_once();orientation_order()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Exact unchanged unrestricted query/path oracle versus per-input reuse: source order, blockers, native endpoints/factors, large/far and unknown-Z geometry, pending arrival, motion/pose/model/lifetime/retirement/frame invalidation, authority fallback, overflow fallback, additive counters, and unchanged orientation commit order. No timing or live-server claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
