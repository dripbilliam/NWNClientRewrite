extends SceneTree
const ControlScript=preload("res://tools/nwn62/drive_collision_indexed_before_reindex.gd")
const CandidateScript=preload("res://tools/nwn62/drive_collision_indexed_staged_candidate.gd")
const Motion=preload("res://systems/network_motion.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
class TestWorld extends Node:
	var generation:=3
	var area_id:=91
	var surface
	var desired: Dictionary={}
	var motion:=Motion.new()
var output:=""
var checks:=0
var failures: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func make(script: Script,count: int)->Dictionary:
	var world:=TestWorld.new();root.add_child(world)
	var surface:=Surface.new();world.add_child(surface);world.surface=surface
	surface.done=true;surface.table={"orderedRows":[{"Walk":"1"}]}
	surface.definition={"width":1,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3.ZERO}]}
	surface.meshes={"floor":{"vertices":[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0],"normals":[[0,0,1],[0,0,1]],"constants":[0,0]}}
	for i in count:
		var id:=i+1
		if count==1918 and i<1908 or count==2047 and i<2037 or count==2000 and i%8==0 or count not in [1918,2047,2000] and i%4==0:
			world.desired[id]={"object":{"id":id,"objectType":9,"staticState":{"appearance":i%463 if count==1918 else 0,"position":[float(i%40),float(i/40),0.0],"orientation":{"yaw":0},"static":true}}}
		else:
			world.desired[id]={"object":{"id":id,"objectType":5,"appearance":{"appearance":0}}}
			world.motion.ensure(id,{"position":[float(i%40),float(i/40),0.0]})
	var collision=script.new();world.add_child(collision);collision.world=world
	collision.models["chest:placeable"]={"states":[{"vertices":[],"faces":[]}]}
	collision.sync_full()
	var placeable_rows: Array=[]
	for i in (463 if count==1918 else 1):placeable_rows.append({"ModelName":"model"+str(i) if count==1918 else "chest"})
	collision.tables={"appearance":{"orderedRows":[{"PERSPACE":"0.3","HEIGHT":"1.8"}]},"placeables":{"orderedRows":placeable_rows},"genericdoors":{"orderedRows":[]}}
	collision.requests[999]={"table":"doortypes","ticket":collision.spatial_ticket.duplicate(true)}
	return {"world":world,"collision":collision}
func edit_sources(setup: Dictionary,count: int)->void:
	var world=setup.world;var collision=setup.collision
	var moving_id:=count if count==1918 else 2
	world.motion.objects[moving_id].render=Vector3(17,21,0)
	collision.sync_motion_id(moving_id)
	world.desired.erase(4);world.motion.objects.erase(4);collision.sync_delta([],[4])
	var id:=count+1
	world.desired[id]={"object":{"id":id,"objectType":5,"appearance":{"appearance":0}}}
	world.motion.ensure(id,{"position":[2.0,3.0,0.0]})
	collision.sync_delta([world.desired[id].object],[])
func leg(script: Script,count: int,edit_phase: String)->Dictionary:
	var setup:=make(script,count);var collision=setup.collision;var world=setup.world
	var before:=Time.get_ticks_usec()
	collision.prepared(999,{"value":{"orderedRows":[]},"error":""})
	var completion_us:=Time.get_ticks_usec()-before
	var callback_us: Array=[];var callback_phases: Array=[];var callback_spatial_phases: Array=[]
	var initial_ready: bool=collision.ready()
	var initial_query_valid: bool=collision.query(count if count==1918 else 2).is_valid()
	if edit_phase!="none" and script==ControlScript:edit_sources(setup,count)
	var edit_applied:=script==ControlScript or edit_phase=="none"
	var steps:=0
	while not collision.ready() and steps<2000:
		var phase:=str(collision._reindex.get("phase","done")) if collision.get_script()==CandidateScript else "control"
		var spatial_phase:=str(collision.spatial._finalize.get("phase","none")) if collision.get_script()==CandidateScript else "none"
		before=Time.get_ticks_usec();collision._process(0.016);callback_us.append(Time.get_ticks_usec()-before);callback_phases.append(phase);callback_spatial_phases.append(spatial_phase);steps+=1
		if not edit_applied and (edit_phase=="rows" and steps==2 or edit_phase=="finalize" and not collision.spatial._finalize.is_empty()):
			edit_sources(setup,count);edit_applied=true
	var spatial=collision.spatial.query(collision.spatial_ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0)
	var groups: Array=[]
	for key in collision.static_groups.keys():
		var group: Dictionary=collision.static_groups[key]
		groups.append([key,group.index.query(group.ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0).ids])
	groups.sort_custom(func(a,b):return str(a[0])<str(b[0]))
	var bindings: Array=[]
	for id in collision.source_rows.keys():
		var row: Dictionary=collision.source_rows[id]
		bindings.append([id,row.get("point"),row.get("dimensions"),row.get("published"),row.get("published_order"),row.get("model_key")])
	var result:={"ready":collision.ready(),"initial_ready":initial_ready,"initial_query_valid":initial_query_valid,"count":count,"edit_phase":edit_phase,"edit_applied":edit_applied,"completion_us":completion_us,"callbacks":steps,"max_callback_us":callback_us.max() if not callback_us.is_empty() else 0,"callback_us":callback_us,"callback_phases":callback_phases,"callback_spatial_phases":callback_spatial_phases,"sum_callback_us":callback_us.reduce(func(a,b):return a+b,0),"spatial_build_max_us":collision.spatial.stage_build_max_us if script==CandidateScript else 0,"fallbacks":collision.reindex_fallbacks if script==CandidateScript else {},"signature":var_to_bytes([spatial.ids,groups,bindings,collision.source_errors,collision.model_users.size()]).hex_encode(),"sources":collision.source_rows.size(),"entries":int(collision.spatial.snapshot().entries),"group_count":collision.static_groups.size()}
	collision.close();world.free()
	return result
func lifecycle()->Dictionary:
	var setup:=make(CandidateScript,512);var world=setup.world;var collision=setup.collision
	collision.prepared(999,{"value":{"orderedRows":[]},"error":""})
	collision._process(0.016)
	check(not collision.ready() and not collision._reindex.is_empty(),"reindex remains fenced mid-batch")
	var old_ticket: Dictionary=collision.spatial_ticket.duplicate(true)
	collision.retire_index()
	check(collision._reindex.is_empty() and collision.source_rows.is_empty() and not collision.ready() and not collision.spatial.snapshot().active,"retirement cancels partial batch")
	world.generation+=1
	collision.sync_full()
	check(collision.ready() and collision.spatial_ticket!=old_ticket and collision.source_rows.size()==512,"new scope builds without old reindex")
	collision._process(0.016)
	check(collision.ready() and collision._reindex.is_empty(),"old callback cannot revive retired scope")
	var result:={"retired_old_epoch":int(old_ticket.epoch),"new_epoch":int(collision.spatial_ticket.epoch),"new_sources":collision.source_rows.size()}
	collision.close();world.free()
	return result
func restart_full_mid_reindex(count: int,target: String)->Dictionary:
	var setup:=make(CandidateScript,count);var world=setup.world;var collision=setup.collision
	collision.prepared(999,{"value":{"orderedRows":[]},"error":""})
	if target=="early":collision._process(0.016)
	else:
		var advance_steps:=0
		while advance_steps<10000:
			var at_global:=target=="global" and str(collision._reindex.get("phase",""))=="finish_spatial" and str(collision.spatial._finalize.get("phase",""))=="centroids"
			var at_group:=target=="groups" and str(collision._reindex.get("phase",""))=="end_groups" and int(collision._reindex.get("index",0))>=20
			if at_global or at_group:break
			collision._reindex_step();advance_steps+=1
		check(advance_steps<10000,"deep cancellation phase reached")
	check(not collision.ready() and not collision._reindex.is_empty(),"full restart begins with partial reindex")
	var before:=Time.get_ticks_usec()
	check(collision.begin_received_full(),"full restart cancels reindex and begins staged source batch")
	var cancel_us:=Time.get_ticks_usec()-before
	var steps:=0
	while not collision.received_full_step() and steps<10000:steps+=1
	check(collision.ready() and collision._reindex.is_empty() and collision.source_rows.size()==count,"full restart converges without leftover reindex")
	var spatial=collision.spatial.query(collision.spatial_ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0)
	var result:={"count":count,"target":target,"cancel_us":cancel_us,"steps":steps,"ready":collision.ready(),"sources":collision.source_rows.size(),"entries":collision.spatial.snapshot().entries,"groups":collision.static_groups.size(),"ids":spatial.ids}
	collision.close();world.free()
	return result
func final_table_during_full(script: Script)->Dictionary:
	var setup:=make(script,64);var world=setup.world;var collision=setup.collision
	check(collision.begin_received_full(),"received full begins before fourth table")
	for i in 8:collision.received_full_step()
	collision.prepared(999,{"value":{"orderedRows":[]},"error":""})
	var full_steps:=0
	while not collision.received_full_step() and full_steps<512:full_steps+=1
	var reindex_steps:=0
	while not collision.ready() and reindex_steps<512:collision._process(0.016);reindex_steps+=1
	var spatial=collision.spatial.query(collision.spatial_ticket,Vector3(-20,-20,0),Vector3(100,100,0),1.0)
	var result:={"ready":collision.ready(),"sources":collision.source_rows.size(),"entries":collision.spatial.snapshot().entries,"groups":collision.static_groups.size(),"ids":spatial.ids,"full_steps":full_steps,"reindex_steps":reindex_steps}
	collision.close();world.free()
	return result
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var cases: Array=[]
	for count in [1918,1919,2048,2047,2000,4096]:
		for edit_phase in (["none","rows"] if count==1918 else ["none","rows","finalize"] if count==1919 else ["none"]):
			var control:=leg(ControlScript,count,edit_phase)
			var candidate:=leg(CandidateScript,count,edit_phase)
			check(control.ready and candidate.ready,"both reindexes become ready")
			check(candidate.edit_applied,"requested source edit reached the staged candidate")
			if count not in [2000,4096]:check(control.initial_ready and control.initial_query_valid and not candidate.initial_ready and not candidate.initial_query_valid,"candidate gates queries while batch is incomplete")
			else:check(candidate.initial_ready and candidate.fallbacks.count==1 and candidate.fallbacks.reasons.has("creature-limit" if count==2000 else "source-limit"),"upper-size source or creature limit falls back with explicit reason")
			if count==2047:check(candidate.fallbacks.count==1 and candidate.fallbacks.reasons.has("group-limit"),"oversized static group falls back with explicit reason")
			check(control.signature==candidate.signature,"ordered rows, bindings and query results match")
			check(control.sources==candidate.sources and control.entries==candidate.entries and control.group_count==candidate.group_count,"owner/entry/group counts match")
			if count not in [2000,4096]:check(candidate.completion_us<control.completion_us,"completion callback gets shorter")
			cases.append({"control":control,"candidate":candidate})
		await process_frame
	var retired:=lifecycle()
	var restarted: Array=[restart_full_mid_reindex(512,"early"),restart_full_mid_reindex(1919,"global"),restart_full_mid_reindex(1918,"groups")]
	var overlap_control:=final_table_during_full(ControlScript)
	var overlap_candidate:=final_table_during_full(CandidateScript)
	check(overlap_control.ready and overlap_candidate.ready and overlap_control.ids==overlap_candidate.ids and overlap_control.sources==overlap_candidate.sources and overlap_control.entries==overlap_candidate.entries and overlap_control.groups==overlap_candidate.groups,"fourth table during received full converges to exact indexed results")
	var abba: Array=[]
	for source in [ControlScript,CandidateScript,CandidateScript,ControlScript]:
		abba.append(leg(source,1918,"none"))
		await process_frame
	for row in abba:check(row.signature==abba[0].signature,"captured-shape ABBA output parity")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"retired":retired,"restarted":restarted,"overlap":{"control":overlap_control,"candidate":overlap_candidate},"abba":abba,"scope":"Actual current DriveCollision/Spatial in headless SceneTree, frozen pre-edit control, authored captured-shape 1918 and dense-dynamic 1919 source rows, no FPS or original-asset claim"},"\t"))
	file.close();quit(0 if failures.is_empty() else 1)
