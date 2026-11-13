extends Node
# Private plain CNWFeat decoding only. Accepted parsed tables are immutable
# publications: workers borrow one exact table and never touch a Node, TLK,
# catalog, actor, candidate result or presentation model.
signal completed(request: int)
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
class Work extends RefCounted:
	var source: Dictionary={}
	var releases: Array=[]
	var result: Dictionary={}
	var elapsed_usec:=0
	var thread_id:=0
	func run() -> void:
		# Drop only wrappers/references, never clear a borrowed decoded graph.
		releases.clear()
		if source.is_empty():return
		var began:=Time.get_ticks_usec();thread_id=OS.get_thread_caller_id()
		result=Tables.decode(source);elapsed_usec=Time.get_ticks_usec()-began
var serial:=0
var wanted: Dictionary={}
var pending: Dictionary={}
var accepted: Dictionary={}
var decoded: Dictionary={}
var active: Work
var active_key: Dictionary={}
var task:=-1
var releases: Array=[]
var closed:=false
var stats:={"submitted":0,"accepted":0,"stale":0,"coalesced":0,"workerUsec":0,"lastWorkerUsec":0,"requestUsec":0,"lastThread":0,"closeUsec":0,"peakActive":0}
static func same_key(left: Dictionary,right: Dictionary) -> bool:
	return not left.is_empty() and not right.is_empty() and left.scope==right.scope and left.catalog==right.catalog and left.generation==right.generation and is_same(left.source,right.source)
func release_decoded() -> void:
	if not decoded.is_empty():releases.append({"decoded":decoded})
	decoded={};accepted={}
func warm(scope: Array,catalog: Object,generation: int,source: Variant) -> int:
	if closed:return -1
	var began:=Time.get_ticks_usec();var key:={"scope":scope.duplicate(),"catalog":catalog,"generation":generation,"source":source}
	if same_key(key,wanted):return serial
	serial+=1;key.request=serial;wanted=key;release_decoded()
	if not pending.is_empty():stats.coalesced+=1
	pending={}
	if scope.is_empty() or not is_instance_valid(catalog):
		decoded={"ready":false,"reason":"Private feat definitions have no current resource owner."};accepted=key
	elif source==null:pass
	elif not source is Dictionary or not source.get("orderedRows") is Array:
		decoded={"ready":false,"reason":"Active feat metadata is malformed."};accepted=key
	else:pending=key
	stats.requestUsec+=Time.get_ticks_usec()-began;dispatch();return serial
func view(scope: Array,catalog: Object,generation: int,source: Variant) -> Dictionary:
	var key:={"scope":scope,"catalog":catalog,"generation":generation,"source":source}
	if closed or not same_key(key,wanted):return {"ready":false,"pending":true,"reason":"Private feat definitions are not prepared for this level-up."}
	if same_key(key,accepted):return decoded
	return {"ready":false,"pending":true,"reason":"Preparing level-up choices…"}
func dispatch() -> void:
	if closed or task>=0 or pending.is_empty() and releases.is_empty():return
	active=Work.new();active.releases=releases;releases=[];active_key=pending;pending={}
	if not active_key.is_empty():active.source=active_key.source;stats.submitted+=1
	task=WorkerThreadPool.add_task(active.run,false,"Private level-up feat definitions");stats.peakActive=1
func poll() -> void:
	if closed or task<0 or not WorkerThreadPool.is_task_completed(task):return
	WorkerThreadPool.wait_for_task_completion(task);task=-1
	var done:=active;var key:=active_key;active=null;active_key={}
	if not key.is_empty():
		stats.workerUsec+=done.elapsed_usec;stats.lastWorkerUsec=done.elapsed_usec;stats.lastThread=done.thread_id
		if same_key(key,wanted) and int(key.request)==serial:
			release_decoded();decoded=done.result;done.result={};accepted=key;stats.accepted+=1;completed.emit(serial)
		else:stats.stale+=1
	if not done.result.is_empty():releases.append({"decoded":done.result});done.result={}
	dispatch()
func _process(_delta: float) -> void:poll()
func retire() -> void:
	serial+=1;wanted={};pending={};release_decoded();dispatch()
func snapshot() -> Dictionary:
	var value:=stats.duplicate();value.running=task>=0;value.pending=not pending.is_empty();value.closed=closed;value.serial=serial;return value
func close() -> void:
	if closed:return
	var began:=Time.get_ticks_usec();closed=true;serial+=1;wanted={};pending={};release_decoded()
	# Cancel/transition only calls retire(). Actual owner destruction drains its
	# single data-only task; no unrelated pool task or asset worker is joined.
	if task>=0:
		WorkerThreadPool.wait_for_task_completion(task);task=-1
		if active!=null and not active.result.is_empty():releases.append({"decoded":active.result});active.result={}
	active=null;active_key={}
	if not releases.is_empty():
		var cleanup:=Work.new();cleanup.releases=releases;releases=[]
		var cleanup_task:=WorkerThreadPool.add_task(cleanup.run,false,"Release private level-up definitions")
		WorkerThreadPool.wait_for_task_completion(cleanup_task)
	stats.closeUsec=Time.get_ticks_usec()-began
func _exit_tree() -> void:close()
