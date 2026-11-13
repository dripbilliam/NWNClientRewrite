extends SceneTree
const Baseline=preload("res://.cache/nwn63/collision-group-index-a/control.gd")
const Candidate=preload("res://.cache/nwn63/collision-group-index-a/candidate.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func signature(result: Dictionary)->Array:
	var rows: Array=[]
	for row in result.rows:rows.append([row.id,row.kind,row.order,row.witness])
	return [result.ready,rows]
func timing(collision,positions: Array)->Dictionary:
	var samples: Array=[]
	for i in 120:
		var x: float=positions[i%positions.size()]
		var began:=Time.get_ticks_usec()
		collision.static_candidates(Vector3(x,0,0),Vector3(x+12,0,0),0.4,-1)
		samples.append(Time.get_ticks_usec()-began)
	samples.sort()
	return {"median_us":samples[60],"p95_us":samples[113],"max_us":samples[-1]}
func run()->void:
	var control=Baseline.new();var candidate=Candidate.new()
	var worlds: Array=[]
	for collision in [control,candidate]:
		var world:=GroupWorld.new();root.add_child(world);world.add_child(collision);collision.world=world
		check(collision.ensure_spatial_scope(),"scope accepted")
		worlds.append(world)
	var groups:=1024
	for index in groups:
		var key: String="model_%04d:placeable"%index
		var id:=index+10000
		var point:=Vector3(float(index)*20.0,0.0,0.0)
		for collision in [control,candidate]:
			var group: Dictionary=collision.static_group(key)
			var publication: Dictionary=group.index.upsert_shape(group.ticket,id,[id,1],1,"static",point,point,false,index)
			check(publication.get("accepted",false),"source group publication %d"%index)
			collision.source_rows[id]={"witness":[id,1]}
			collision.dirty_groups[key]=true
	# Two published shapes overlap the same probe. The second has the earlier
	# source order, but group enumeration still dictates this intermediate list.
	for collision in [control,candidate]:
		for index in 2:
			var key: String="model_%04d:placeable"%index
			var id:=index+10000
			var x:=float(index)*20.0
			var group: Dictionary=collision.static_groups[key]
			var point:=Vector3(x,0,0)
			check(group.index.upsert_shape(group.ticket,id,[id,1],2,"static",point,point,false,100 if index==0 else 1).get("accepted",false),"reordered published source")
			collision.models[key]={"states":[]}
			collision.model_bounds[key]=[{"min":Vector3(-12,-1,-1),"max":Vector3(12,1,1),"radius":12.1}]
			collision.source_rows[id]={"witness":[id,1],"model_key":key,"spec":{"door":false,"state":0},"pose":{"position":Vector3(x,0,0),"rotation":0.0}}
			collision.dirty_groups[key]=true
	var build_us: Array=[];var max_step_us: Array=[]
	for collision in [control,candidate]:
		collision._received_full={"phase":"bounds","keys":collision.dirty_groups.keys(),"index":0,"order":groups}
		var began:=Time.get_ticks_usec();var worst:=0;var done:=false
		while not done:
			var step_began:=Time.get_ticks_usec();done=collision.received_full_step();worst=maxi(worst,Time.get_ticks_usec()-step_began)
		build_us.append(Time.get_ticks_usec()-began);max_step_us.append(worst)
	check(candidate.static_group_index.snapshot().entries==groups,"all group bounds indexed")
	var overlap_old: Dictionary=control.static_candidates(Vector3(0,0,0),Vector3(12,0,0),0.4,-1)
	var overlap_new: Dictionary=candidate.static_candidates(Vector3(0,0,0),Vector3(12,0,0),0.4,-1)
	check(var_to_bytes(signature(overlap_old))==var_to_bytes(signature(overlap_new)),"published overlapping shape order and bounds")
	check(overlap_old.rows.size()>=2 and int(overlap_old.rows[0].id)==10000 and int(overlap_old.rows[1].id)==10001,"reversed source order retains group enumeration")
	var selected:=0
	for probe in 48:
		var x:=float(probe*17)*20.0
		var start:=Vector3(x,0,0);var stop:=Vector3(x+12,0,0)
		var old: Dictionary=control.static_candidates(start,stop,0.4,-1)
		var next: Dictionary=candidate.static_candidates(start,stop,0.4,-1)
		check(var_to_bytes(signature(old))==var_to_bytes(signature(next)),"ordered static result %d"%probe)
		selected+=int(candidate.static_group_index.snapshot().last_query.matched_rows)
	check(selected<groups,"index selected fewer groups than one full scan")
	# A known model with invalid bounds makes the entire old result unready,
	# including when that model is far from the queried route.
	for collision in [control,candidate]:
		collision.models["model_1023:placeable"]={"states":[]}
		collision.model_bounds["model_1023:placeable"]=[{"pending":true}]
		if collision==candidate:collision._refresh_static_group_index("model_1023:placeable")
	var origin:=Vector3.ZERO;var nearby:=Vector3(10,0,0)
	check(var_to_bytes(signature(control.static_candidates(origin,nearby,0.4,-1)))==var_to_bytes(signature(candidate.static_candidates(origin,nearby,0.4,-1))),"far invalid state readiness")
	check(not control.static_candidates(origin,nearby,0.4,-1).ready,"far invalid state rejects")
	for collision in [control,candidate]:collision.publish_model("model_1023:placeable",{"states":[{"vertices":[],"faces":[]}]})
	check(var_to_bytes(signature(control.static_candidates(origin,nearby,0.4,-1)))==var_to_bytes(signature(candidate.static_candidates(origin,nearby,0.4,-1))),"model arrival restores exact result")
	for collision in [control,candidate]:
		collision.static_group("empty:placeable");collision.dirty_groups["empty:placeable"]=true;collision.flush_group_bounds()
	check(candidate.static_group_index_unsafe.is_empty() and candidate.static_group_index.snapshot().entries==groups,"empty-bounds withdrawal remains indexable")
	var timed: Array=[]
	var positions: Array=[]
	for index in 16:positions.append(float(index*17)*20.0)
	for collision in [control,candidate,candidate,control]:timed.append(timing(collision,positions))
	for collision in [control,candidate]:
		for key in collision.static_groups:collision.dirty_groups[key]=true
		collision.flush_group_bounds()
	check(candidate.static_group_build_pending and candidate.static_group_index_unsafe.has(-1),"dense synchronous refresh queues bounded index build")
	check(var_to_bytes(signature(control.static_candidates(origin,nearby,0.4,-1)))==var_to_bytes(signature(candidate.static_candidates(origin,nearby,0.4,-1))),"dense synchronous fallback keeps exact answer")
	var async_steps:=0;var async_worst:=0
	while candidate.static_group_build_pending and async_steps<groups+16:
		var step_began:=Time.get_ticks_usec();candidate._step_static_group_index()
		async_worst=maxi(async_worst,Time.get_ticks_usec()-step_began);async_steps+=1
	check(not candidate.static_group_build_pending and candidate.static_group_index_unsafe.is_empty(),"queued index becomes ready after bounded steps")
	check(var_to_bytes(signature(control.static_candidates(origin,nearby,0.4,-1)))==var_to_bytes(signature(candidate.static_candidates(origin,nearby,0.4,-1))),"queued index preserves exact result")
	var saved_ticket: Dictionary=candidate.static_group_ticket
	candidate.static_group_ticket={}
	check(var_to_bytes(signature(control.static_candidates(origin,nearby,0.4,-1)))==var_to_bytes(signature(candidate.static_candidates(origin,nearby,0.4,-1))),"unavailable coarse index falls back exactly")
	candidate.static_group_ticket=saved_ticket
	for world in worlds:world.area_id=92
	for collision in [control,candidate]:check(collision.ensure_spatial_scope() and collision.static_groups.is_empty(),"area reset clears static groups")
	check(candidate.static_group_index.snapshot().entries==0 and candidate.static_group_keys.is_empty(),"area reset clears coarse index")
	var report_path: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"probes":48,"indexed_group_visits":selected,"full_group_visits":groups*48,"staged_build_us":build_us,"staged_max_step_us":max_step_us,"async_steps":async_steps,"async_worst_us":async_worst,"timed":timed,"control_sha256":FileAccess.get_sha256("res://.cache/nwn63/collision-group-index-a/control.gd"),"candidate_sha256":FileAccess.get_sha256("res://.cache/nwn63/collision-group-index-a/candidate.gd")}
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	for world in worlds:world.free()
	print(JSON.stringify({"passed":report.passed,"checks":checks,"indexed_group_visits":selected,"full_group_visits":groups*48}));quit(0 if failures.is_empty() else 1)
class GroupWorld:
	extends Node
	var generation:=1
	var area_id:=91
