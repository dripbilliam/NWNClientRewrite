extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
class Scope extends Node:
	var closed:=false
	var retiring:=false
var checks:=0
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func run()->void:
	var pool:=Pool.new();var first:=Scope.new();first.set_meta("native_entry_loading",true);pool.bind_publication_world(first)
	pool.entry_publication_budget_us=0
	check(pool.publication_budget_limit_us()==3000 and pool.publication_callback_budget_us()==3000,"Loading metadata never changes unconfigured ordinary publication policy")
	pool.entry_publication_budget_us=8000
	check(pool.publication_budget_limit_us()==8000 and pool.publication_callback_budget_us()==8000,"Explicit private8ms configuration applies only to marked loading world")
	pool.construction_finished(Time.get_ticks_usec()-4000)
	check(pool.can_publish() and pool.can_consume_completion() and pool.remaining_publication_us()>0,"Scene and completion paths use the same entry allowance ledger")
	first.set_meta("native_entry_loading",false)
	check(pool.publication_budget_limit_us()==3000 and pool.publication_callback_budget_us()==3000 and not pool.can_publish() and not pool.can_consume_completion(),"One-way ready mark immediately restores ordinary3ms guards without a new frame or fresh free unit")
	first.set_meta("native_entry_commit_pending",true)
	check(pool.publication_budget_limit_us()==3000,"Commit/API fence does not itself enable an entry loading allowance")
	var second:=Scope.new();second.set_meta("native_entry_loading",true);pool.bind_publication_world(second);first.closed=true
	check(pool.publication_budget_limit_us()==8000,"Retiring previous generation cannot reset the new shared-pool world's policy")
	second.retiring=true;check(pool.publication_budget_limit_us()==3000,"Retiring current world cannot retain loading allowance")
	second.retiring=false;second.closed=true;check(pool.publication_budget_limit_us()==3000,"Closed current world cannot retain loading allowance")
	second.closed=false;var weak:=weakref(second);second.free()
	check(weak.get_ref()==null and pool.publication_budget_limit_us()==3000,"Pool's weak world association cannot keep an old generation alive")
	first.free();pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"PRIVATE opt-in loading publication allowance; exact one-way metadata fence, shared completion/scene deadline, immediate ready/retire/close rollback and weak shared-generation ownership. No policy promotion or FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
