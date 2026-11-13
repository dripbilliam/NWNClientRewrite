extends Node
# One cached, data-only preparation of the actual native floaty attachment
# model. Fonts are shared by the existing UI font owner. No icon viewport.
signal loaded
const Assets=preload("res://systems/native_data/asset_service.gd")
const Model=preload("res://systems/native_data/script_floating_model.gd")
var assets
var plan: Dictionary={"ready":false,"pending":true}
var requested:=false
var job:=-1
var closed:=false
func configure(catalog,cache_path: String="") -> void:
	assets=Assets.new();add_child(assets);assets.configure(catalog);assets.cache_directory=cache_path;assets.maximum_workers=1;assets.set_process(false);assets.completed.connect(prepared)
func request() -> void:
	if closed or requested or not is_instance_valid(assets):return
	requested=true;assets.set_process(true);job=assets.request("pnl_floatytext",2002,"actor-model")
	if job<0:
		plan={"ready":false,"reason":"Original floaty attachment model could not be requested."};assets.set_process(false);loaded.emit()
func prepared(id: int,result: Dictionary) -> void:
	if closed or id!=job:return
	job=-1
	if not str(result.get("error","")).is_empty():plan={"ready":false,"reason":"Original floaty attachment model could not be prepared."}
	else:plan=Model.parse(result.get("value",{}))
	assets.set_process(not assets.pending.is_empty() or not assets.running.is_empty());loaded.emit()
func close() -> void:
	if closed:return
	closed=true
	if is_instance_valid(assets):
		if assets.completed.is_connected(prepared):assets.completed.disconnect(prepared)
		assets.close();assets.set_process(false)
	plan={};job=-1
func _exit_tree() -> void:close()
