extends Node
# Optional decorative planning after active-area admission. A task borrows the
# immutable accepted terrain tiles/SET and a private catalog fork, never World.
signal completed(ticket: int,scope: Array,result: Dictionary)
const Border=preload("res://systems/native_data/area_border.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var generation:=0
var serial:=0
var task:=-1
var pending: Dictionary={}
var result: Dictionary={}
var mutex:=Mutex.new()
var closed:=false
var stats:={"submitted":0,"accepted":0,"stale":0,"coalesced":0,"worker_ms":0.0,"last_thread":0}
static func render_plan(value: Dictionary)->Dictionary:
	if not value.get("ready",false):return value
	if not value.get("placements") is Array:return {"ready":false,"reason":"Original decorative placements are unavailable."}
	var rows: Array=[];var models: Dictionary={}
	for entry in value.placements:
		if not entry is Dictionary or not entry.get("model") is String or str(entry.model).is_empty() or str(entry.model).length()>16 or not entry.get("position") is Vector3 or not entry.position.is_finite():return {"ready":false,"reason":"Invalid original decorative model or position."}
		var turn: Variant=entry.get("orientation")
		if not (turn is int or turn is float) or not is_finite(float(turn)) or float(turn)!=floorf(float(turn)) or turn<0 or turn>3 or entry.get("nativeSpawnFlags")!=1:return {"ready":false,"reason":"Invalid original decorative orientation/flags."}
		var index:=rows.size();var name:=str(entry.model)
		rows.append({"index":index,"model":name,"position":entry.position,"orientation":int(turn),"sourceIndex":entry.get("sourceIndex")})
		if not models.has(name):models[name]=[]
		models[name].append(index)
	return {"ready":true,"enabled":value.get("enabled",false),"loaded":value.get("loaded",false),"placements":rows,"models":models}
func request(catalog,definition: Dictionary,gate: Dictionary,scope: Array)->int:
	if closed or catalog==null or not catalog.has_method("fork") or scope.size()!=3:return -1
	var reader=catalog.fork()
	if reader==null:return -1
	serial+=1
	if not pending.is_empty():stats.coalesced+=1
	pending={"ticket":serial,"generation":generation,"scope":scope.duplicate(),"catalog":reader,"definition":definition,"gate":gate.duplicate()}
	pump();set_process(true);return serial
func pump()->void:
	if closed or task!=-1 or pending.is_empty():return
	var job:=pending;pending={};stats.submitted+=1
	task=WorkerThreadPool.add_task(load_plan.bind(job),false,"Original decorative area border plan")
func load_plan(job: Dictionary)->void:
	var began:=Time.get_ticks_usec();var definition: Dictionary=job.definition
	var value:={"ready":false,"reason":"Original border source definition is unavailable."};var resource:="";var known_missing:=false
	if definition.has_all(["width","height","tiles","tileset","tileset_name"]) and job.gate.get("enabled") is bool and job.gate.get("disabled") is bool:
		var area:={"width":definition.width,"height":definition.height,"tiles":definition.tiles}
		resource=Border.resource_name(str(definition.tileset_name))
		if not job.gate.enabled or job.gate.disabled:
			value=Border.plan(area,definition.tileset,null,job.gate)
		elif not job.catalog.has_resource(resource,2017):
			known_missing=true;value=Border.plan(area,definition.tileset,null,job.gate)
		else:
			var bytes: PackedByteArray=job.catalog.get_resource(resource,2017)
			if not str(job.catalog.failure).is_empty():value={"ready":false,"reason":"Original optional Edge2DA could not be read."}
			else:
				var parser:=Table.new();var table:=parser.parse(Binary.new(bytes).text(0,bytes.size()))
				if not parser.failure.is_empty():value={"ready":false,"reason":"Original optional Edge2DA could not be decoded."}
				else:value=Border.plan(area,definition.tileset,table,job.gate)
	var prepared:={"ticket":job.ticket,"generation":job.generation,"scope":job.scope,"plan":value,"render":render_plan(value),"edge_resource":resource,"known_missing":known_missing,"worker_ms":(Time.get_ticks_usec()-began)/1000.0,"thread":OS.get_thread_caller_id()}
	mutex.lock();result=prepared;mutex.unlock()
func poll()->void:
	if task==-1 or not WorkerThreadPool.is_task_completed(task):return
	WorkerThreadPool.wait_for_task_completion(task);task=-1
	mutex.lock();var prepared:=result;result={};mutex.unlock()
	if not closed and int(prepared.get("generation",-1))==generation and int(prepared.get("ticket",-1))==serial:
		stats.accepted+=1;stats.worker_ms+=float(prepared.worker_ms);stats.last_thread=prepared.thread
		completed.emit(int(prepared.ticket),prepared.scope,prepared)
	else:stats.stale+=1
	pump();set_process(not closed and (task!=-1 or not pending.is_empty()))
func _process(_delta: float)->void:
	var began:=Timing.begin();poll();Timing.finish("callback_area_border",began)
func retire_scope()->void:
	generation+=1;pending={};set_process(false)
func worker_tasks()->Array:return [task] if task!=-1 else []
func detach_prepared_data()->Dictionary:
	if task!=-1 and not WorkerThreadPool.is_task_completed(task):return {}
	mutex.lock();var detached:=result;result={};mutex.unlock()
	return {"border_plan_result":detached} if not detached.is_empty() else {}
func close()->void:
	if closed:return
	closed=true;retire_scope()
	if task!=-1:WorkerThreadPool.wait_for_task_completion(task);task=-1
	mutex.lock();result={};mutex.unlock()
func _exit_tree()->void:close()
