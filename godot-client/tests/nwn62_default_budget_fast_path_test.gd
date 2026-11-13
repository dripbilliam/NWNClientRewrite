extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
class Probe extends Node:
	var reads:=0
	var closed_state:=false
	var retiring_state:=false
	func _get(property: StringName) -> Variant:
		if property==&"closed":reads+=1;return closed_state
		if property==&"retiring":reads+=1;return retiring_state
		return null
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var key:="nwn/private/publication_scenery_budget_us"
	var previous: Variant=ProjectSettings.get_setting(key,0)
	ProjectSettings.set_setting(key,0)
	var ordinary:=Pool.new();ordinary.entry_publication_budget_us=0
	var world:=Probe.new();world.set_meta("native_publication_loading",true);ordinary.bind_publication_world(world)
	var default_queries:=0;var all_ordinary:=true
	for index in 64:
		var observed:=ordinary.publication_budget_limit_us();all_ordinary=all_ordinary and observed==3000;default_queries+=1
	check(all_ordinary,"Default budget remains 3 ms across all queries")
	var default_reads:=world.reads
	check(default_reads==0,"Default policy skips live-world property reads")
	check(ordinary.publication_callback_budget_us()==3000 and ordinary.remaining_publication_us()>0,"Default callback and remaining budgets stay ordinary")
	check(world.reads==0,"All default budget queries skip live-world property reads")
	ProjectSettings.set_setting(key,5000)
	var private_pool:=Pool.new();private_pool.entry_publication_budget_us=0;private_pool.bind_publication_world(world)
	check(private_pool.publication_budget_limit_us()==5000 and world.reads>0,"Private active allowance still inspects the live world")
	world.set_meta("native_publication_loading",false)
	check(private_pool.publication_budget_limit_us()==3000,"Private inactive allowance returns 3 ms")
	world.set_meta("native_publication_loading",true);world.retiring_state=true
	check(private_pool.publication_budget_limit_us()==3000,"Retirement revokes private allowance")
	world.retiring_state=false;world.closed_state=true
	check(private_pool.publication_budget_limit_us()==3000,"Close revokes private allowance")
	var private_reads:=world.reads
	world.closed_state=false;var weak:=weakref(world);world.free()
	check(weak.get_ref()==null and private_pool.publication_budget_limit_us()==3000,"Released world cannot retain private allowance")
	ordinary.clear();private_pool.clear();ProjectSettings.set_setting(key,previous)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"default_budget_queries":default_queries,"default_world_property_reads":default_reads,"private_world_property_reads":private_reads,"scope":"Budget result and default-path property-read proof only; no loading, frame or FPS timing."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
