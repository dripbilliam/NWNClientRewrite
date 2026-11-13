extends Node
# Scoped asynchronous familiar-name owner. Existing native assets retain all
# resource I/O/decoding/cache ownership; generation jobs own only private data.
signal prepared(scope: Array)
signal name_ready(request_id: int,result: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Letters=preload("res://systems/native_data/letter_table.gd")
const Generator=preload("res://systems/native_data/name_generation.gd")
class NameJob extends RefCounted:
	var table: Dictionary={}
	var filters: Array=[]
	var seed:=0
	var thread_id:=-1
	var result: Dictionary={}
	func run() -> void:
		thread_id=OS.get_thread_caller_id()
		var rng:=RandomNumberGenerator.new();rng.seed=seed
		result=Generator.new().generate(table,func():return rng.randi_range(0,32767),filters)
var assets
var scope: Array=[]
var generation:=0
var requests: Dictionary={}
var jobs: Dictionary={}
var table: Dictionary={}
var filters: Array=[]
var filter_known:=false
var resources_ready:=false
var failure:=""
var closed:=false
var serial:=0
var random:=RandomNumberGenerator.new()
var diagnostics: Dictionary={}
func _init() -> void:random.randomize()
func configure(catalog,value_scope: Array) -> void:
	if closed:return
	generation+=1;scope=value_scope.duplicate();requests.clear();table={};filters=[];filter_known=false;resources_ready=false;failure="";diagnostics={}
	if scope.is_empty() or catalog==null:failure="Native associate name scope is unavailable.";return
	if not is_instance_valid(assets):assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.completed.connect(received)
	assets.configure(catalog)
	var id: int=assets.request("familiar",2036,"ltr-native-v1")
	if id<0:failure=assets.failure;return
	requests[id]={"generation":generation,"kind":"letters"}
	if catalog.has_resource("namefilter",2017):
		id=assets.request("namefilter",2017,"2da")
		if id<0:failure=assets.failure;return
		requests[id]={"generation":generation,"kind":"filter"}
	else:filter_known=true;diagnostics.filterAbsent=true
func received(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id):return
	var request: Dictionary=requests[id];requests.erase(id)
	if int(request.generation)!=generation:return
	# A genuine NameFilter Load2DArray failure is optional in the original.
	# Missing captured bytes/read failures are different and remain unavailable.
	if not result.get("resource_error") is String or not str(result.resource_error).is_empty():failure="Native associate name resource could not be read.";return
	if request.kind=="letters":
		if not str(result.get("error","")).is_empty() or not Letters.valid(result.get("value",{})):failure="Native associate letter table is unavailable.";return
		table=result.value;diagnostics.letterSha256=str(result.sha256);diagnostics.workerThread=int(result.thread);diagnostics.decodeCacheHit=bool(result.get("memory_decode_hit",false))
	else:
		filter_known=true
		if not str(result.get("error","")).is_empty():filters=[];diagnostics.filterLoadFailed=true
		else:
			var source: Dictionary=result.value;var lookup:=Tables.columns(source)
			for row in source.get("orderedRows",[]).size():
				var value:=Tables.cell(source,row,"Name",lookup)
				if value.found and not str(value.text).is_empty():filters.append(str(value.text))
	if failure.is_empty() and requests.is_empty() and filter_known and not table.is_empty():resources_ready=true;prepared.emit(scope.duplicate())
func request_name(value_scope: Array) -> int:
	if closed or not resources_ready or not failure.is_empty() or value_scope!=scope or jobs.values().any(func(row):return int(row.generation)==generation) or serial>=9007199254740991:return -1
	serial+=1;var work:=NameJob.new();work.table=table;work.filters=filters;work.seed=random.randi()
	jobs[serial]={"generation":generation,"scope":scope.duplicate(),"work":work,"task":WorkerThreadPool.add_task(work.run,false,"Native associate name")}
	return serial
func _process(_delta: float) -> void:
	for id in jobs.keys():
		var job: Dictionary=jobs[id]
		if not WorkerThreadPool.is_task_completed(int(job.task)):continue
		WorkerThreadPool.wait_for_task_completion(int(job.task));jobs.erase(id)
		if closed or int(job.generation)!=generation or job.scope!=scope:continue
		diagnostics.generationWorkerThread=int(job.work.thread_id)
		var result: Dictionary=job.work.result.duplicate(true);result.scope=scope.duplicate();name_ready.emit(int(id),result)
func close() -> void:
	if closed:return
	closed=true;generation+=1;scope.clear();resources_ready=false
	if is_instance_valid(assets):assets.close()
	for job in jobs.values():WorkerThreadPool.wait_for_task_completion(int(job.task))
	jobs.clear();requests.clear();table.clear();filters.clear()
func _exit_tree() -> void:close()
