extends Node
# Scoped private data jobs for mode1 child Recommended. No game
# command, received actor or shared table publication is owned here.
signal reset_skills(request: int,ticket: Array)
signal reset_choices(stage: String,request: int,ticket: Array)
signal completed(stage: String,value: Dictionary,request: int,ticket: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Context=preload("res://systems/native_data/level_up_recommendation_context.gd")
const Plan=preload("res://systems/native_data/level_up_recommendation_plan.gd")
const ClassDependencies=preload("res://systems/native_data/level_up_class_dependencies.gd")
const Post=preload("res://systems/native_data/level_up_post_recommendation.gd")
var catalog
var assets
var publisher: Callable
var serial:=0
var wanted:=false
var owner_scope: Array=[]
var ticket: Array=[]
var stage:=""
var received: Dictionary={}
var class_id:=-1
var tables: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var reset_sent:=false
var started:=0
var diagnostics: Dictionary={}
var spell_context: Dictionary={}
func configure(active_catalog,cache_path: String,publish: Callable) -> void:
	if catalog!=active_catalog:cancel()
	catalog=active_catalog;publisher=publish
	if not is_instance_valid(assets):assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.completed.connect(prepared)
	assets.configure(catalog);assets.cache_directory=cache_path
func start(kind: String,snapshot: Dictionary,selected_class: int,active_tables: Dictionary,scope: Array,identity: Array,private_spell_context: Dictionary={}) -> int:
	cancel();wanted=true;stage=kind;received=snapshot.duplicate(true);class_id=selected_class;tables=active_tables.duplicate();owner_scope=scope.duplicate();ticket=identity.duplicate();spell_context=private_spell_context.duplicate();started=Time.get_ticks_usec();diagnostics={"resources":[],"contextUsec":0};advance.call_deferred(serial);return serial
func advance(request: int) -> void:
	if not wanted or request!=serial:return
	var began:=Time.get_ticks_usec();var plan: Dictionary={"ready":false,"reason":"Native recommendation action is unavailable."}
	match stage:
		"class":plan=ClassDependencies.compose(received,class_id,tables)
		"attributes":plan=Context.attributes(received,class_id,tables)
		"skills":plan=Context.skills(received,class_id,tables)
		"feats":plan=Plan.feats(received,class_id,tables)
		"spells":plan=Plan.spells(received,class_id,tables,spell_context)
		"domains","school":plan=Post.lookup(stage,received,class_id,tables)
	diagnostics.contextUsec+=Time.get_ticks_usec()-began
	if stage in ["skills","feats","spells"] and plan.get("invoked",false) and not reset_sent:
		reset_sent=true;reset_choices.emit(stage,serial,ticket.duplicate())
		if stage=="skills":reset_skills.emit(serial,ticket.duplicate())
		if not wanted or request!=serial:return
	if plan.get("pending",false):
		for name in plan.get("dependencies",[]):request_table(str(name))
		return
	finish(plan)
func request_table(name: String) -> void:
	if not wanted or requested.has(name):return
	requested[name]=true
	if catalog==null or not is_instance_valid(assets):finish({"ready":false,"reason":"Recommended choices are unavailable."});return
	var id: int=assets.request(name,2017,"2da",{"immutable_source":true})
	if id<0:finish({"ready":false,"reason":"Recommended choices are unavailable."});return
	jobs[id]={"request":serial,"name":name,"catalog":catalog};diagnostics.resources.append(name)
func prepared(id: int,value: Dictionary) -> void:
	if not jobs.has(id):return
	var job: Dictionary=jobs[id];jobs.erase(id)
	if not wanted or int(job.request)!=serial or job.catalog!=catalog or not publisher.is_valid():return
	if stage=="class" and (not str(value.get("error","")).is_empty() or not value.get("value") is Dictionary or not value.value.get("orderedRows") is Array):
		finish({"ready":false,"reason":"Class choices could not be prepared from "+str(job.name)+".","failed":str(job.name)});return
	var data: Dictionary=value.value if str(value.get("error","")).is_empty() and value.get("value") is Dictionary else {}
	var published: Variant=publisher.call(str(job.name),data,serial,owner_scope.duplicate(),catalog)
	if not published is Dictionary or not published.get("ready",false) or not published.get("tables") is Dictionary:cancel();return
	tables=published.tables;advance(serial)
func finish(value: Dictionary) -> void:
	if not wanted:return
	var request:=serial;var answer:=value.duplicate(true);answer.elapsedUsec=Time.get_ticks_usec()-started;answer.diagnostics=diagnostics.duplicate(true)
	wanted=false;completed.emit(stage,answer,request,ticket.duplicate())
func cancel() -> void:
	serial+=1;wanted=false;owner_scope=[];ticket=[];stage="";received={};class_id=-1;tables={};spell_context={};requested={};reset_sent=false;jobs={}
func close() -> void:
	cancel()
	if is_instance_valid(assets):assets.close()
func _exit_tree() -> void:close()
