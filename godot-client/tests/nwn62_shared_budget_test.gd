extends SceneTree
# Private untimed policy/accounting preflight only. No assets, rendering or FPS.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _init()->void:call_deferred("run")
func run()->void:
	var requested: int=int(ProjectSettings.get_setting("nwn/private/publication_shared_budget_us",0))
	var expected:=4000 if requested==4000 else 3000
	var pool=Pool.new();pool.cooperative_templates=true
	check(pool.publication_budget_us==expected,"ordinary private setting effective")
	check(pool.publication_budget_limit_us()==expected,"shared limit effective")
	check(pool.entry_publication_budget_us==0,"entry allowance not configured")
	check(pool.publication_callback_budget_us()==3000,"individual callback limit unchanged")
	check(Template.step_budget(pool)==1500,"individual construction step cap unchanged")
	check(pool.maximum_publications_per_frame==16,"publication count cap unchanged")
	check(pool.maximum_completion_units_per_frame==64,"completion count cap unchanged")
	pool.begin_completion_scope()
	var charged_before: int=pool.publication_us
	pool.construction_finished(0);pool.publication_finished(0)
	check(pool.publication_us==charged_before,"nested operations not double charged")
	var nested: Dictionary=pool._private_shared_audit.snapshot(pool).operations
	for kind in ["construction","publication"]:
		check(nested[kind].calls==1 and nested[kind].nested_calls==1,"nested unit counted "+kind)
		check(nested[kind].timed_calls==0 and nested[kind].cpu_us==0 and nested[kind].maximum_us==0,"nested elapsed deliberately unmeasured "+kind)
	pool._completion_began=Time.get_ticks_usec()-6000
	pool.end_completion_scope()
	check(pool.publication_us>=6000 and pool.completion_us>=6000,"oversized completion charged incl result-release boundary")
	check(not pool.can_publish(),"no second general progress after spent completion")
	check(not pool.can_consume_completion(),"spent completion denied")
	check(pool.can_publish(true),"original one priority progress reservation")
	pool.publication_finished(Time.get_ticks_usec(),true)
	check(not pool.can_publish(true),"priority reservation consumed")
	pool.publication_us=3500;pool.publications=1;pool.construction_steps=1;pool.completion_units=1;pool.priority_publications=1
	check(pool.can_publish()==(expected==4000),"3500us publication threshold differs only by shared allowance")
	check(pool.can_consume_completion()==(expected==4000),"3500us completion threshold differs only by shared allowance")
	check(Template.step_budget(pool)==(500 if expected==4000 else 1),"remaining shared time still bounds next step")
	pool.publication_us=0;pool.publications=16
	check(not pool.can_publish(),"publication quota unchanged with spare time")
	pool.completion_units=64
	check(not pool.can_consume_completion(),"completion quota unchanged with spare time")
	var audit: Dictionary=pool._private_shared_audit.snapshot(pool)
	check(audit.denials.completion.time>=1 and audit.denials.publication.time>=1,"shared-time denial counters positive")
	check(audit.denials.completion.quota>=1 and audit.denials.publication.quota>=1,"quota denial counters positive")
	pool.publication_frame=-1;pool.publication_us=0;pool.can_publish()
	check(pool.publications==0 and pool.completion_units==0 and pool.construction_steps==0,"new frame resets shared unit counters")
	var world:=Node.new();get_root().add_child(world);world.set_meta("native_entry_loading",true);pool.bind_publication_world(world)
	check(pool.publication_budget_limit_us()==expected,"loading mark does not alter ordinary private setting")
	world.set_meta("native_entry_loading",false)
	check(pool.publication_budget_limit_us()==expected,"allowance persists after firstplay only in explicit private experiment")
	pool.bind_publication_world(null);world.free()
	check(pool.publication_budget_limit_us()==expected,"released world does not create new allowance")
	var snapshot: Dictionary=pool.snapshot()
	check(snapshot.publication_budget.private_shared.requested_us==requested,"report requested setting observed")
	check(snapshot.publication_budget.private_shared.effective_ordinary_us==expected,"report effective allowance observed")
	check(snapshot.publication_budget.private_entry.activations==0,"entry activation remains zero")
	pool.clear();pool=null
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"requested_us":requested,"effective_us":expected,"scope":"Untimed actual ResourcePool policy/accounting correctness only; no assets/GPU/FPS or performance result","snapshot":snapshot.publication_budget}
	var output:="";for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"requested_us":requested,"effective_us":expected}))
	quit(0 if failures.is_empty() else 1)
