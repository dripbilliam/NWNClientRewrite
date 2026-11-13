extends Node
# Staged, scoped Character Information resource/worker owner. No creator imports
# this file yet. All I/O/decode/cache work stays with the existing AssetService.
signal prepared(scope:Array)
signal names_ready(request_id:int,result:Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Names=preload("res://systems/native_data/creation_character_names.gd")
const Letters=preload("res://systems/native_data/letter_table.gd")
class PairJob extends RefCounted:
	var plan:Dictionary={}
	var letters:Dictionary={}
	var filters:Array=[]
	var seed:=0
	var thread_id:=-1
	var result:Dictionary={}
	func run()->void:
		thread_id=OS.get_thread_caller_id()
		var rng:=RandomNumberGenerator.new();rng.seed=seed
		result=Names.generate_pair(plan,letters,filters,func():return rng.randi_range(0,32767))
var assets
var scope:Array=[]
var generation:=0
var plan:Dictionary={}
var letters:Dictionary={}
var filters:Array=[]
var filters_known:=false
var requests:Dictionary={}
var job:Dictionary={}
var resources_ready:=false
var failure:=""
var closed:=false
var serial:=0
var random:=RandomNumberGenerator.new()
var diagnostics:Dictionary={}
func _init()->void:random.randomize()
func configure(catalog,value_scope:Array,prepared_plan:Dictionary)->void:
	if closed:return
	generation+=1;scope=value_scope.duplicate();plan={};letters={};filters=[];filters_known=false;requests.clear();resources_ready=false;failure="";diagnostics={}
	if scope.is_empty() or catalog==null or prepared_plan.get("ready")!=true or not prepared_plan.get("resources") is Array or not prepared_plan.get("rows") is Array or prepared_plan.rows.size()!=2:failure="The current character-name scope/plan is unavailable.";return
	if prepared_plan.resources.is_empty() or prepared_plan.resources.size()>4 or prepared_plan.resources.any(func(value):return not value is String or str(value).is_empty() or str(value).length()>16):failure="The native letter-resource plan is invalid.";return
	var unique:Dictionary={}
	for resource in prepared_plan.resources:
		if unique.has(resource):failure="The native letter-resource plan contains duplicate requests.";return
		unique[resource]=true
	plan=prepared_plan.duplicate(true)
	if not is_instance_valid(assets):assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.completed.connect(received)
	assets.configure(catalog)
	for resource in plan.resources:
		var id:int=assets.request(str(resource),2036,"ltr-native-v1")
		if id<0:failure=assets.failure;return
		requests[id]={"generation":generation,"kind":"letters","resource":str(resource)}
	if catalog.has_resource("namefilter",2017):
		var id:int=assets.request("namefilter",2017,"2da")
		if id<0:failure=assets.failure;return
		requests[id]={"generation":generation,"kind":"filter"}
	else:filters_known=true;diagnostics.filterAbsent=true
func received(id:int,result:Dictionary)->void:
	if closed or not requests.has(id):return
	var request:Dictionary=requests[id];requests.erase(id)
	if int(request.generation)!=generation:return
	if not result.get("resource_error") is String or not str(result.resource_error).is_empty():failure="Current native character-name resource bytes are unavailable.";return
	if request.kind=="letters":
		if not str(result.get("error","")).is_empty() or not Letters.valid(result.get("value",{})):failure="The active native letter table cannot be decoded: "+str(request.resource);return
		letters[request.resource]=result.value
		var sources:Dictionary=diagnostics.get("letters",{});sources[request.resource]={"sha256":str(result.sha256),"thread":int(result.thread),"cacheHit":bool(result.get("memory_decode_hit",false))};diagnostics.letters=sources
	else:
		filters_known=true
		if not str(result.get("error","")).is_empty():diagnostics.filterLoadFailed=true
		else:
			var source:Dictionary=result.value;var lookup:=Tables.columns(source)
			for row in source.get("orderedRows",[]).size():
				var value:=Tables.cell(source,row,"Name",lookup)
				if value.found and str(value.text) not in ["","****"]:filters.append(str(value.text))
	if failure.is_empty() and requests.is_empty() and filters_known and letters.size()==plan.resources.size():resources_ready=true;prepared.emit(scope.duplicate())
func available(value_scope:Array)->bool:return not closed and failure.is_empty() and resources_ready and value_scope==scope and job.is_empty()
func request_names(value_scope:Array)->int:
	# A retired job is drained before another starts: configure spam cannot
	# create an unbounded generation queue or publish into a replacement draft.
	if not available(value_scope) or serial>=9007199254740991:return -1
	serial+=1;var work:=PairJob.new();work.plan=plan;work.letters=letters;work.filters=filters;work.seed=random.randi()
	job={"id":serial,"generation":generation,"scope":scope.duplicate(),"work":work,"task":WorkerThreadPool.add_task(work.run,false,"Native character names")}
	return serial
func _process(_delta:float)->void:
	if job.is_empty() or not WorkerThreadPool.is_task_completed(int(job.task)):return
	WorkerThreadPool.wait_for_task_completion(int(job.task));var completed:Dictionary=job;job={}
	if closed or int(completed.generation)!=generation or completed.scope!=scope:return
	diagnostics.generationWorkerThread=int(completed.work.thread_id)
	var result:Dictionary=completed.work.result.duplicate(true);result.scope=scope.duplicate();names_ready.emit(int(completed.id),result)
func close()->void:
	if closed:return
	closed=true;generation+=1;scope.clear();resources_ready=false
	if is_instance_valid(assets):assets.close()
	if not job.is_empty():WorkerThreadPool.wait_for_task_completion(int(job.task));job={}
	requests.clear();letters.clear();filters.clear();plan.clear()
func _exit_tree()->void:close()
