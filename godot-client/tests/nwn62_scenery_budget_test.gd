extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
class Scope extends Node:
	var closed:=false
	var retiring:=false
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var setting:="nwn/private/publication_scenery_budget_us"
	var previous: Variant=ProjectSettings.get_setting(setting,0)
	ProjectSettings.set_setting(setting,0)
	var ordinary:=Pool.new()
	check(ordinary.scenery_publication_budget_us==0 and ordinary.publication_budget_limit_us()==3000,"Default remains the ordinary 3 ms publication budget")
	ProjectSettings.set_setting(setting,5000)
	var pool:=Pool.new();var first:=Scope.new()
	first.set_meta("native_publication_loading",true);pool.bind_publication_world(first)
	check(pool.scenery_publication_budget_us==5000 and pool.publication_budget_limit_us()==5000 and pool.publication_callback_budget_us()==5000,"Private scenery mark admits exactly the configured shared allowance")
	pool.construction_finished(Time.get_ticks_usec()-4000)
	check(pool.can_publish() and pool.can_consume_completion() and pool.remaining_publication_us()>0,"Construction and completion consume the same temporary allowance")
	first.set_meta("native_publication_loading",false)
	check(pool.publication_budget_limit_us()==3000 and pool.publication_callback_budget_us()==3000 and not pool.can_publish() and not pool.can_consume_completion(),"Clearing the mark restores 3 ms without waiting for a new frame")
	var transitions: Dictionary=pool.snapshot().publication_budget.scenery_transitions
	check(int(transitions.activations)==1 and int(transitions.clears)==1 and not transitions.active,"Scalar diagnostics prove the private allowance activated and then cleared")
	var second:=Scope.new();second.set_meta("native_publication_loading",true);pool.bind_publication_world(second);first.closed=true
	check(pool.publication_budget_limit_us()==5000,"A previous world cannot cancel the current generation's mark")
	second.retiring=true;check(pool.publication_budget_limit_us()==3000,"Retirement immediately revokes the allowance")
	second.retiring=false;second.closed=true;check(pool.publication_budget_limit_us()==3000,"Close immediately revokes the allowance")
	second.closed=false;var weak:=weakref(second);second.free()
	check(weak.get_ref()==null and pool.publication_budget_limit_us()==3000,"The weak pool binding does not retain a released world")
	first.free();pool.clear();ordinary.clear()
	ProjectSettings.set_setting(setting,previous)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Private scenery publication allowance; shared completion/construction guard and immediate one-way clear, retirement and weak-owner release. Does not measure loading, visuals or FPS."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
