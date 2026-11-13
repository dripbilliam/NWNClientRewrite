extends SceneTree
# Prepared for the next confirmed free-PC window. Do not run while game is open.
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
const Job=preload("res://systems/native_data/world_snapshot_metadata_job.gd")
const Preparation=preload("res://systems/native_data/world_snapshot_preparation.gd")
const Oracle=preload("res://tests/fixtures/native_world_snapshot_metadata_oracle.gd")
const Scenery=preload("res://systems/native_render/base_world_scenery.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func digest(value: Variant) -> String:return Metadata.digest(var_to_bytes(value))
func data_only(value: Variant) -> bool:
	if value is Object:return false
	if value is Dictionary:
		for key in value:
			if not data_only(key) or not data_only(value[key]):return false
	elif value is Array:
		for part in value:
			if not data_only(part):return false
	return true
func row(index: int,kind: int=9) -> Dictionary:
	var source:={"id":index,"areaId":11,"objectType":kind,"nativeLifetime":1,"clientKnownLifetime":2,"appearance":{"appearance":17,"name":"opaque-name-"+str(index),"opaque":[index,{"extra":true}]},"replicated":{"position":[float(index),2.25,3.5],"orientation":{"yaw":17.5},"animation":0,"appearance":17}}
	if kind==9:source.staticState={"id":index,"appearance":17,"position":[1.25,2.5,3.75],"orientation":[0.25,0.75,0]}
	return source
func wait_result(owner,token: Array) -> Dictionary:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		var result: Dictionary=owner.take(token)
		if not result.is_empty():return result
		await process_frame
	check(false,"Preparation completes before deadline")
	return {}
func _initialize() -> void:call_deferred("run")
func release_detached_owner(token: Array,rows: Array) -> Dictionary:
	var detached:=Preparation.new();detached.begin(token,11,64);detached.submit(rows.slice(0,64))
	# Cross a function boundary so all VM expression temporaries are released.
	# Do not explicitly close: PREDELETE must drain the actual pending borrower.
	return {"stats":detached.stats,"weak":weakref(detached)}
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var orphan_baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var oracle:=Oracle.new()
	var rows: Array=[]
	var animations: Array=[0,14,72,73,74,75,76,77,99,100,213,214,215,216,400,401,402,403,404,65535,-1,1.5,null]
	for index in 160:
		var source:=row(index,[5,6,9,10,1,9,5,10][index%8])
		source.replicated.animation=animations[index%animations.size()]
		if index%11==0:source.areaId=12
		if index%13==0:source.replicationRemoved=true
		if index%17==0:source.destroyed=true
		if index%19==0:source.replicated.position=null
		if index%5==0:source.replicated.orientation=[0.25,-0.75,9]
		if index%7==0:source.replicated.orientation={"vector":[-0.5,0.5],"yaw":45}
		if index%23==0:source.erase("nativeLifetime")
		if index%29==0:source.clientKnownLifetime=0
		if index%31==0:source.nativeLifetime="unavailable"
		if int(source.objectType)==9 and index%3==0:source.replicated.erase("position");source.replicated.erase("orientation")
		rows.append(source)
	var duplicate: Dictionary=rows[2].duplicate(true);duplicate.replicated.position=[9,8,7];rows.append(duplicate)
	var original_digest:=digest(rows)
	var prepared:=Metadata.prepare(rows,11,37)
	check(prepared.size()==rows.size(),"Every row retains an ordered metadata slot")
	for index in rows.size():
		var source: Dictionary=rows[index];var result: Dictionary=prepared[index]
		var accepted: bool=int(source.get("areaId",-1))==11 and not source.get("replicationRemoved",false) and int(source.get("objectType",0)) in [5,6,9,10] and not oracle.object_pose(source).is_empty()
		check(Metadata.validation_error(source).is_empty(),"Fixture shape can run on worker: "+str(index))
		check(result.index==index+37 and result.id==int(source.id) and result.accepted==accepted,"Original admission filter and source order: "+str(index))
		check(digest(Metadata.object_pose(source))==digest(oracle.object_pose(source)),"Exact frozen original pose: "+str(index))
		check(Metadata.signature(source)==oracle.signature(source),"Exact frozen original signature: "+str(index))
		check(digest(result.classification)==digest(Scenery.classify(source,11) if accepted else {}) and result.omission==("" if accepted else Scenery.omitted_reason(source,11)),"Scenery metadata preserves classification/omission: "+str(index))
	check(prepared[2].id==prepared[-1].id and prepared[2].index!=prepared[-1].index,"Duplicate identities preserve both ordered rows")
	check(digest(rows)==original_digest and data_only(prepared),"Preparation does not mutate source or return object owners")
	var unscoped:=row(1006,7);unscoped.erase("areaId")
	check(Metadata.validation_error(unscoped).is_empty(),"Received non-world inventory rows may omit areaId without rejecting a whole metadata batch")
	var unscoped_metadata: Dictionary=Metadata.prepare([unscoped],11)[0]
	check(not unscoped_metadata.accepted and unscoped_metadata.pose.is_empty() and unscoped_metadata.key.is_empty() and unscoped_metadata.omission.is_empty(),"Missing areaId keeps the exact original omitted-slot semantics")
	var named:=row(500,5);var renamed: Dictionary=named.duplicate(true);renamed.appearance.name="new popup name"
	check(Metadata.signature(named)==Metadata.signature(renamed),"Creature names remain outside model identity")
	renamed.appearance.opaque.append("changed")
	check(Metadata.signature(named)!=Metadata.signature(renamed),"Other opaque appearance remains part of model identity")
	var scope: Array=[1,7,11,99,0]
	var packet:=rows.duplicate();var worker:=Job.new()
	var task:=WorkerThreadPool.add_task(worker.run.bind(packet,11,37,scope.duplicate()),false,"Test snapshot metadata")
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	check(worker.result.error.is_empty() and int(worker.result.thread)!=OS.get_main_thread_id(),"Actual metadata worker runs off main")
	check(digest(worker.result.rows)==digest(prepared) and packet.is_empty() and digest(rows)==original_digest,"Worker matches original algorithms and clears only its Array")
	worker=null
	# Deterministic coalescing test without timing or a synthetic waiting worker.
	var packets: Array=[];var grouping_source: Array=[]
	for index in 10:
		var chunk: Array=[]
		for part in 64:chunk.append(index*64+part);grouping_source.append(index*64+part)
		packets.append({"rows":chunk,"offset":index*64})
	var first:=Preparation.take_packet(packets);var second:=Preparation.take_packet(packets)
	check(first.offset==0 and first.rows.size()==512 and second.offset==512 and second.rows.size()==128 and packets.is_empty(),"Queued wire chunks coalesce to bounded 512/128 jobs")
	var combined: Array=first.rows.duplicate();combined.append_array(second.rows)
	check(combined==grouping_source,"Coalescing preserves contiguous order exactly")
	var owner:=Preparation.new()
	check(not owner.begin([],11,1) and not owner.begin(scope,11,65537),"Empty scope and oversized snapshots rejected before dispatch")
	check(owner.begin(scope,11,rows.size()),"Full preparation begins with scoped row count")
	check(not owner.seal(),"Incomplete snapshot cannot seal")
	check(not owner.submit(rows),"Wire submissions larger than 64 remain rejected")
	for offset in range(0,rows.size(),64):check(owner.submit(rows.slice(offset,mini(offset+64,rows.size()))),"Owned wire chunk admitted: "+str(offset))
	check(owner.take(scope).is_empty(),"Unsealed snapshot cannot become visible")
	check(owner.seal(),"Complete raw snapshot seals")
	check(owner.take([1,7,11,100,0]).is_empty(),"Wrong serial cannot consume ready metadata")
	var complete: Dictionary=await wait_result(owner,scope)
	check(complete.get("error","missing").is_empty() and complete.count==rows.size(),"All scoped metadata completes")
	check(digest(complete.rows)==digest(Metadata.prepare(rows,11)) and int(owner.stats.peak_tasks)<=2,"Coordinator preserves ordered metadata with at most two tasks")
	var diagnostic: Dictionary=owner.snapshot()
	check(diagnostic.stats.main_thread==OS.get_main_thread_id() and not diagnostic.stats.threads.is_empty() and not diagnostic.stats.threads.has(OS.get_main_thread_id()) and diagnostic.stats.threads.size()<=64,"Bounded actual worker-thread diagnostics distinguish the main thread")
	check(owner.take(scope).is_empty(),"Completed packet transfers exactly once")
	# Cancellation changes ownership only, without modifying a borrowed graph.
	for index in 16:
		check(owner.begin([2,8,11,200+index,1],11,64),"Rapid scoped begin: "+str(index))
		check(owner.submit(rows.slice(0,64)),"Rapid scoped submit: "+str(index))
		owner.cancel()
		check(owner.running.is_empty() and owner.retired.size()<=2 and owner.pending.is_empty(),"Cancellation retires bounded handles without waiting: "+str(index))
	var new_scope: Array=[2,9,11,300,2]
	check(owner.begin(new_scope,11,1) and owner.submit([row(999)]) and owner.seal(),"New scope queues while cancelled borrowers finish")
	complete=await wait_result(owner,new_scope)
	check(complete.get("error","missing").is_empty() and complete.rows.size()==1 and complete.rows[0].id==999 and complete.scope==new_scope,"Cancelled generations cannot publish into the replacement")
	check(digest(rows)==original_digest and int(owner.stats.peak_tasks)<=2,"Rapid cancellation preserves original rows and global owner task bound")
	# Validation failures finish their complete scope, never expose partial rows.
	var bad: Array=[row(1001),row(1002),row(1003),row(1004)]
	bad[0].replicated=[];bad[1].replicated.position=[{},2,3];bad[2].replicated.orientation={"yaw":[]};bad[3].areaId=[]
	for index in bad.size():check(not Metadata.validation_error(bad[index]).is_empty(),"Unsupported worker shape marked for fallback: "+str(index))
	var bad_scope: Array=[2,10,11,301,2]
	check(owner.begin(bad_scope,11,65) and owner.submit([bad[0]]),"Malformed first packet still owns its scope")
	check(owner.submit(rows.slice(0,64)) and owner.seal(),"Other current borrowers remain covered by failure barrier")
	complete=await wait_result(owner,bad_scope)
	check(not complete.get("error","").is_empty() and complete.rows.is_empty() and complete.count==65 and owner.running.is_empty(),"Error becomes ready only after all current borrowers join, with no partial metadata")
	var wrong_row_scope: Array=[2,10,11,304,2]
	check(owner.begin(wrong_row_scope,11,2) and owner.submit([row(1005),["not-a-dictionary"]]) and owner.seal(),"Non-Dictionary JSON row is admitted only to the terminal validation barrier")
	complete=await wait_result(owner,wrong_row_scope)
	check(complete.get("error","")=="row-not-dictionary" and complete.rows.is_empty() and complete.count==2 and owner.running.is_empty(),"Non-Dictionary rows produce an exact terminal protocol-failure subtype after borrowers join")
	check(owner.begin([2,10,11,302,2],11,0) and owner.seal(),"Empty full snapshot seals without a worker")
	check(owner.take([2,10,11,302,2]).get("count",-1)==0,"Empty full snapshot transfers normally")
	check(owner.begin([2,10,11,303,2],11,64) and owner.submit(rows.slice(0,64)),"Terminal drain begins with an owned task")
	var lifetime: Dictionary=owner.stats;owner.close()
	check(lifetime.closed and owner.running.is_empty() and owner.retired.is_empty() and not owner.begin(scope,11,0),"Explicit close joins all retained task handles and rejects reuse")
	diagnostic=owner.snapshot()
	check(diagnostic.closed and diagnostic.current_tasks==0 and diagnostic.retired_tasks==0 and diagnostic.pending_rows==0,"Post-close diagnostics prove zero owned tasks and queued rows")
	owner=null
	var detached_lifetime:=release_detached_owner(scope,rows)
	check(detached_lifetime.stats.closed and detached_lifetime.weak.get_ref()==null,"Actual RefCounted release drains inline without PREDELETE self dispatch or retained owner")
	oracle=null
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_baseline,"Data-only helpers do not leak scene nodes")
	var out:=FileAccess.open(report,FileAccess.WRITE)
	out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Frozen pre-worker signature/pose oracle, immutable borrowed input, ordered grouping, actual worker, cancellation, malformed fallback and terminal ownership. No world authority/FPS acceptance."},"\t"));out.close()
	quit(0 if failures.is_empty() else 1)
