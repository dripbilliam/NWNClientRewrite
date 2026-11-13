extends Node
# Mode-independent UTC/LTR readers with a private mode1 menu lifetime.
# Nothing here creates a live actor, changes the received draft, or publishes
# a fallback player stat block. Tables are loaded from the active catalog.
signal preview_ready(value: Dictionary,ticket: Array,selection: int)
signal name_ready(value: Dictionary,ticket: Array,revision: int,accept_after: bool)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Work=preload("res://systems/native_data/character_picker_work.gd")
const Names=preload("res://systems/native_associate_names.gd")
const Preview=preload("res://systems/native_data/creation_associate_preview.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
class ActiveText extends RefCounted:
	var tables: Dictionary={}
	var revision:=0
	var source
	func raw(value: Variant) -> String:return source.raw(value)
	func rich(value: Dictionary,id: int=-1):return source.rich(value,id)
var assets
var projection
var names
var scope: Array=[]
var generation:=0
var closed:=false
var tables: Dictionary={}
var text
var revision:=0
var requested: Dictionary={}
var pending: Dictionary={}
var template: Dictionary={}
var jobs: Dictionary={}
var name_jobs: Dictionary={}
var pending_name: Dictionary={}
var failure:=""
var failure_kind:=""
var diagnostics: Dictionary={}
func configure(catalog,active_tables: Dictionary,active_text,ticket: Array,cache_path: String="") -> void:
	if closed:return
	retire();scope=ticket.duplicate();tables=active_tables.duplicate();text=active_text;failure="";failure_kind="";diagnostics={}
	if scope.is_empty() or catalog==null or text==null:failure="Active mode1 associate resources are unavailable.";return
	if not is_instance_valid(assets):assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.completed.connect(received)
	if not is_instance_valid(projection):projection=Work.new();add_child(projection);projection.completed.connect(projected)
	if not is_instance_valid(names):names=Names.new();add_child(names);names.prepared.connect(names_prepared);names.name_ready.connect(generated_name)
	assets.configure(catalog);assets.cache_directory=cache_path;names.configure(catalog,scope)
	if is_instance_valid(names.assets) and not names.assets.completed.is_connected(name_resource_changed):names.assets.completed.connect(name_resource_changed)
	for name in ["classes","racialtypes","skills","ruleset","spells","exptable","feat","portraits"]:request_table(str(name))
func current(ticket: Array) -> bool:return not closed and not scope.is_empty() and ticket==scope
func request_table(name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or tables.has(name) or requested.has(name) or not failure.is_empty():return
	requested[name]=true;var id: int=assets.request(name,2017,"2da")
	if id<0:failure=str(assets.failure);return
	jobs[id]={"generation":generation,"kind":"table","name":name,"selection":int(pending.get("selection",-1))}
func preview(value: Dictionary,ticket: Array) -> void:
	if not current(ticket) or not value.get("resource") is String or not value.get("selection") is int or int(value.get("type",-1))!=2027:return
	if failure_kind=="template":failure="";failure_kind=""
	pending=value.duplicate(true);template={};projection.retire()
	var id: int=assets.request(str(value.resource),2027,"gff")
	if id<0:failure=str(assets.failure);return
	jobs[id]={"generation":generation,"kind":"template","resource":str(value.resource),"selection":int(value.selection)}
func received(id: int,value: Dictionary) -> void:
	if closed or not jobs.has(id):return
	var request: Dictionary=jobs[id];jobs.erase(id)
	if int(request.generation)!=generation or scope.is_empty():return
	if request.kind=="template" and (pending.is_empty() or int(request.selection)!=int(pending.selection) or str(request.resource)!=str(pending.resource)):return
	if not str(value.get("error","")).is_empty():
		if request.kind=="table" and int(request.selection)>=0 and int(request.selection)!=int(pending.get("selection",-1)):requested.erase(str(request.name));revision+=1;project_current();return
		failure=str(value.error);failure_kind=str(request.kind);emit_pending_failure();return
	if request.kind=="table":tables[request.name]=value.value;revision+=1
	else:
		var decoded:=Preview.source(value.value)
		if not decoded.get("ready",false):failure=str(decoded.get("reason","Native associate UTC is unavailable."));failure_kind="template";emit_pending_failure();return
		template=decoded.value;diagnostics.templateResource=request.resource;diagnostics.templateSha256=str(value.get("sha256",""));diagnostics.templateWorker=int(value.get("thread",0))
	project_current()
func emit_pending_failure() -> void:
	if not pending.is_empty() and current(scope):preview_ready.emit({"ready":false,"reason":failure},scope.duplicate(),int(pending.selection))
func project_current() -> void:
	if scope.is_empty() or template.is_empty() or not failure.is_empty() or jobs.values().any(func(job):return job.kind=="table"):return
	projection.observe(scope+[int(pending.selection),int(text.revision)],template,tables,revision)
func projected() -> void:
	if scope.is_empty() or template.is_empty() or pending.is_empty():return
	var missing: Array=projection.result.get("dependencies",[])
	if not missing.is_empty():
		for name in missing:request_table(str(name))
		if jobs.is_empty():failure="Original associate projection dependencies could not be satisfied.";emit_pending_failure()
		return
	var view:=ActiveText.new();view.tables=tables;view.revision=int(text.revision);view.source=text
	var rules:=Game.new();rules.text=view
	var model:=Preview.compose(template,projection.result,text,rules,int(text.revision));diagnostics.projection=projection.snapshot()
	preview_ready.emit(model,scope.duplicate(),int(pending.selection))
func generate(value: Dictionary,ticket: Array) -> void:
	if not current(ticket) or not value.get("revision") is int:return
	pending_name=value.duplicate(true);dispatch_name()
func cancel_pending_name(ticket: Array) -> void:
	if current(ticket):pending_name={}
func names_prepared(ticket: Array) -> void:
	if current(ticket):dispatch_name()
func name_resource_changed(_id: int,_value: Dictionary) -> void:
	# NativeNames publishes prepared only on success. An actual LTR/read
	# failure must also retire the current generating indicator explicitly.
	dispatch_name.call_deferred()
func dispatch_name() -> void:
	if pending_name.is_empty() or scope.is_empty() or not is_instance_valid(names):return
	if not names.failure.is_empty():
		var failed:=pending_name;pending_name={};name_ready.emit({"ready":false,"reason":str(names.failure)},scope.duplicate(),int(failed.revision),bool(failed.get("acceptAfter",false)));return
	if not names.resources_ready:return
	var id: int=names.request_name(scope)
	if id>=0:name_jobs[id]={"generation":generation,"ticket":scope.duplicate(),"request":pending_name};pending_name={}
func generated_name(id: int,value: Dictionary) -> void:
	if not name_jobs.has(id):return
	var job: Dictionary=name_jobs[id];name_jobs.erase(id)
	if int(job.generation)!=generation or not current(job.ticket):return
	diagnostics.names=names.diagnostics.duplicate(true);name_ready.emit(value,scope.duplicate(),int(job.request.revision),bool(job.request.get("acceptAfter",false)));dispatch_name()
func retire() -> void:
	generation+=1;scope=[];jobs.clear();requested.clear();pending={};template={};name_jobs.clear();pending_name={}
	if is_instance_valid(projection):projection.retire()
func close() -> void:
	if closed:return
	closed=true;retire()
	if is_instance_valid(assets):assets.close()
	if is_instance_valid(names):names.close()
	if is_instance_valid(projection):projection.close()
	tables={};text=null
func _exit_tree() -> void:close()
