extends Node
# One data-only preparation owner per bound HUD/catalog, shared by every plate.
signal loaded(name: String)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Model=preload("res://systems/native_data/nameplate_model.gd")
const Bubble=preload("res://systems/native_data/radial_text.gd")
var assets
var plans: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var failures: Dictionary={}
var closed:=false
func configure(catalog,cache_path: String="") -> void:
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
func request(name: String) -> void:
	if closed or requested.has(name) or not is_instance_valid(assets): return
	if name!="but_popup_prtrt" and not Bubble.BUBBLES.any(func(row):return row[2]==name): return
	requested[name]=true
	var id: int=assets.request(name,2002,"actor-model")
	if id<0: failures[name]=str(assets.failure); return
	jobs[id]=name
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failures[name]=str(result.error); loaded.emit(name); return
	var plan:=Model.parse(result.value)
	if not str(plan.error).is_empty(): failures[name]=str(plan.error)
	else: plan.resource=name; plans[name]=plan
	loaded.emit(name)
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	jobs.clear(); plans.clear(); requested.clear()
func _exit_tree() -> void: close()
