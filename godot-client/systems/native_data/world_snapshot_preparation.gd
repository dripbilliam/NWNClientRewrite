extends RefCounted
# Session-owned preparation only. This owner cannot admit state or send ACKs.
# Callers may submit only private decoded-JSON rows and must keep every nested
# row immutable while borrowed. Direct/authored callers use synchronous receive.
const Job=preload("res://systems/native_data/world_snapshot_metadata_job.gd")
const VerifiedPacket=preload("res://systems/native_data/world_snapshot_verified_packet.gd")
const MAXIMUM_ROWS:=65536
const CHUNK_ROWS:=64
const JOB_ROWS:=512
const MAXIMUM_TASKS:=2
const VERSION:=1
const MAXIMUM_THREAD_IDS:=64
var scope: Array=[]
var area_id:=-1
var expected_count:=0
var submitted_count:=0
var completed_count:=0
var pending: Array=[]
var running: Array=[]
var retired: Array=[]
var prepared: Array=[]
var prepared_sources: Array=[]
var verified_all:=true
var active:=false
var sealed:=false
var closed:=false
var error:=""
var stats:={"submitted":0,"completed":0,"discarded":0,"peak_tasks":0,"worker_ms":0.0,"max_worker_ms":0.0,"main_thread":OS.get_main_thread_id(),"last_thread":0,"threads":[],"max_packet_rows":0,"closed":false}

func begin(value: Array,target_area: int,count: int) -> bool:
	if closed or value.is_empty() or count<0 or count>MAXIMUM_ROWS:return false
	# Tokens contain only caller-owned scalar coordinates; never share an Object
	# or nested mutable token through the worker result.
	for coordinate in value:
		if not coordinate is int and not coordinate is String:return false
	cancel()
	scope=value.duplicate();area_id=target_area;expected_count=count
	prepared.resize(count);prepared_sources.resize(count);verified_all=true;active=true
	return true

func submit(rows: Array) -> bool:
	if closed or not active or sealed or rows.size()>CHUNK_ROWS or submitted_count+rows.size()>expected_count:return false
	if rows.is_empty():return true
	# Private Array ownership, cheap borrowed immutable nested JSON. No deep copy
	# or freeze of canonical rows on the presentation thread.
	pending.append({"rows":rows.duplicate(),"offset":submitted_count})
	submitted_count+=rows.size()
	poll()
	return true

func seal() -> bool:
	if closed or not active or submitted_count!=expected_count:return false
	sealed=true
	poll()
	return true

static func take_packet(packets: Array) -> Dictionary:
	if packets.is_empty():return {}
	var packet: Dictionary=packets.pop_front()
	var owned_rows: Array=packet.rows
	# The wire still admits at most 64 rows per chunk. Combine only queued,
	# unstarted private Arrays to reduce completion-poll frame latency.
	while not packets.is_empty() and owned_rows.size()+packets[0].rows.size()<=JOB_ROWS:
		var next: Dictionary=packets.pop_front();owned_rows.append_array(next.rows);next.rows.clear()
	return packet

func poll() -> bool:
	# Reap cancelled tasks first. They count against the same two-task limit,
	# including across rapid begin/cancel cycles. Normal cancellation never waits.
	for entry in retired.duplicate():
		if not WorkerThreadPool.is_task_completed(int(entry.task)):continue
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
		retired.erase(entry);stats.discarded+=1
		var retired_result: Dictionary=entry.job.result
		var retired_thread:=int(retired_result.get("thread",0))
		if retired_thread!=0 and not stats.threads.has(retired_thread) and stats.threads.size()<MAXIMUM_THREAD_IDS:stats.threads.append(retired_thread)
	for entry in running.duplicate():
		if not WorkerThreadPool.is_task_completed(int(entry.task)):continue
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
		running.erase(entry)
		var result: Dictionary=entry.job.result
		stats.completed+=1;stats.worker_ms+=float(result.get("worker_ms",0));stats.max_worker_ms=maxf(float(stats.max_worker_ms),float(result.get("worker_ms",0)));stats.last_thread=int(result.get("thread",0))
		if int(stats.last_thread)!=0 and not stats.threads.has(int(stats.last_thread)) and stats.threads.size()<MAXIMUM_THREAD_IDS:stats.threads.append(int(stats.last_thread))
		var failure:=str(result.get("error","worker-result-unavailable"))
		if int(result.get("version",-1))!=VERSION:failure="worker-result-version-mismatch"
		if result.get("scope",[])!=scope or int(result.get("area_id",-1))!=area_id or int(result.get("offset",-1))!=int(entry.offset):failure="worker-result-scope-mismatch"
		var rows: Variant=result.get("rows",[])
		var source_refs: Variant=result.get("source_refs",[])
		var worker_verified: bool=result.get("worker_verified",false)==true
		if not rows is Array or rows.size()!=int(entry.count):
			if failure.is_empty():failure="worker-result-count-mismatch"
		if worker_verified and (not source_refs is Array or source_refs.size()!=int(entry.count)) and failure.is_empty():failure="worker-source-count-mismatch"
		if not worker_verified:verified_all=false
		if failure.is_empty():
			for index in rows.size():
				var row: Variant=rows[index]
				if not row is Dictionary or not row.get("index") is int or int(row.index)!=int(entry.offset)+index:
					failure="worker-result-order-mismatch";break
		if failure.is_empty():
			for index in rows.size():
				var position: int=int(entry.offset)+index
				prepared[position]=rows[index]
				if worker_verified:prepared_sources[position]=source_refs[index]
		elif error.is_empty():error=failure
		# An errored packet is complete, but fallback/admission stays barred until
		# every current packet has finished and all borrowed row readers joined.
		completed_count+=int(entry.count)
	while not closed and active and not pending.is_empty() and running.size()+retired.size()<MAXIMUM_TASKS:
		var packet:=take_packet(pending);var job:=Job.new()
		var owned_rows: Array=packet.rows
		var packet_count:=owned_rows.size()
		var task:=WorkerThreadPool.add_task(job.run.bind(owned_rows,area_id,int(packet.offset),scope.duplicate()),false,"Native world snapshot metadata")
		running.append({"task":task,"job":job,"offset":int(packet.offset),"count":packet_count});stats.submitted+=1;stats.peak_tasks=maxi(int(stats.peak_tasks),running.size()+retired.size());stats.max_packet_rows=maxi(int(stats.max_packet_rows),packet_count)
	return active and sealed and completed_count==expected_count and pending.is_empty() and running.is_empty()

func take(expected_scope: Array) -> Dictionary:
	if expected_scope!=scope or not poll():return {}
	var verified: bool=error.is_empty() and verified_all
	if verified:prepared.make_read_only();prepared_sources.make_read_only()
	var proof=VerifiedPacket.new(scope,area_id,prepared,prepared_sources) if verified else null
	var result:={"version":VERSION,"error":error,"scope":scope,"area_id":area_id,"count":expected_count,"rows":prepared if error.is_empty() else [],"proof":proof}
	scope=[];prepared=[];prepared_sources=[];pending=[];active=false;sealed=false;verified_all=true
	expected_count=0;submitted_count=0;completed_count=0;error=""
	return result

func cancel() -> void:
	# Do not touch a running job or its owned input Array. Discarding its owner
	# token is enough; poll joins and releases the completed stale packet later.
	retired.append_array(running);running=[];pending=[];prepared=[];prepared_sources=[];verified_all=true;scope=[]
	expected_count=0;submitted_count=0;completed_count=0;active=false;sealed=false;error=""

func snapshot() -> Dictionary:
	# Bounded counters only. Diagnostic reads never wait, dispatch a job, expose
	# received rows, or consume a prepared snapshot.
	var pending_rows:=0
	for packet in pending:pending_rows+=packet.rows.size()
	return {"version":VERSION,"active":active,"sealed":sealed,"closed":closed,"current_tasks":running.size(),"retired_tasks":retired.size(),"pending_rows":pending_rows,"expected_rows":expected_count,"submitted_rows":submitted_count,"completed_rows":completed_count,"error":error,"stats":stats.duplicate(true)}

func close() -> void:
	if closed:return
	closed=true;stats.closed=true;cancel()
	for entry in retired:WorkerThreadPool.wait_for_task_completion(int(entry.task))
	stats.discarded+=retired.size();retired=[]

func _notification(what: int) -> void:
	if what!=NOTIFICATION_PREDELETE:return
	# RefCounted PREDELETE cannot dispatch a method on self at refcount zero.
	# Inline the terminal task drain; ordinary cancel remains strictly nonblocking.
	for entry in running:WorkerThreadPool.wait_for_task_completion(int(entry.task))
	for entry in retired:WorkerThreadPool.wait_for_task_completion(int(entry.task))
	stats.closed=true;stats.discarded+=running.size()+retired.size()
	running=[];retired=[];pending=[];prepared=[];prepared_sources=[];verified_all=true;scope=[]
