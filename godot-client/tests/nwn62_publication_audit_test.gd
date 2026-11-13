extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func sample(pool)->Array:
	return [pool.publications,pool.construction_steps,pool.completion_units,pool.priority_publications,pool._completion_depth]
func run()->void:
	var audit_root:="res://.cache/nwn62/publication-audit-a"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audit-source="):audit_root=argument.trim_prefix("--audit-source=")
	for relative in ["object_stream","area_stream","creature_stream","live_world"]:
		# The overlay is not installed into this main project. Redirect only its
		# typed Pool import for this parser check; staged capsules use the usual
		# canonical res:// path after the overlay is applied.
		var source:=FileAccess.get_file_as_string(audit_root+"/systems/native_render/"+relative+".gd")
		source=source.replace("preload(\"res://systems/native_render/resource_pool.gd\")","preload(\""+audit_root+"/systems/native_render/resource_pool.gd\")")
		var script:=GDScript.new();script.source_code=source
		check(script.reload()==OK and script.can_instantiate(),"Private tagged callsites parse with actual source: "+relative)
	var audit_script=load(audit_root+"/systems/native_render/resource_pool.gd")
	check(audit_script!=null and audit_script.can_instantiate(),"Actual private ResourcePool parses")
	if audit_script==null or not audit_script.can_instantiate():quit(1);return
	var original:=Pool.new();var audited=audit_script.new()
	original._publication_frame();audited._publication_frame()
	check(original.can_publish()==audited.can_publish(false,"initial"),"Initial progress decision unchanged")
	for pool in [original,audited]:pool.publications=16;pool.publication_us=1
	check(not original.can_publish() and not audited.can_publish(false,"quota"),"Spare-time publication-count denial unchanged")
	for pool in [original,audited]:pool.publications=1;pool.publication_us=4000
	check(not original.can_publish() and not audited.can_publish(false,"time"),"Time-only denial unchanged")
	for pool in [original,audited]:pool.publications=16
	check(not original.can_publish() and not audited.can_publish(false,"both"),"Combined quota/time denial unchanged")
	for pool in [original,audited]:pool.completion_units=64;pool.publication_us=0
	check(not original.can_consume_completion(true) and not audited.can_consume_completion(true),"Priority cannot evade absolute completion count")
	for pool in [original,audited]:pool.completion_units=0;pool.publications=0;pool.construction_steps=0;pool.publication_us=0;pool.begin_completion_scope();pool._completion_began=Time.get_ticks_usec()-4000
	check(original.can_publish()==audited.can_publish(false,"nested-first") and audited.can_publish(false,"nested-first"),"First necessary nested construction remains possible")
	for pool in [original,audited]:pool.construction_finished(Time.get_ticks_usec());pool.end_completion_scope()
	check(sample(original)==sample(audited) and not original.can_publish() and not audited.can_publish(false,"after-completion"),"Completed owning scope consumes first progress reservation equally")
	for pool in [original,audited]:pool.publication_us=0;pool.publications=0;pool.construction_steps=0;pool.completion_units=0
	for turn in 20:
		original.construction_finished(Time.get_ticks_usec());audited.construction_finished(Time.get_ticks_usec(),"template")
	check(sample(original)==sample(audited) and audited.publications==0 and audited.can_publish(false,"after-construction"),"Twenty cheap construction stages do not exhaust publication quota")
	original.publication_finished(Time.get_ticks_usec());audited.publication_finished(Time.get_ticks_usec(),false,"stream-final")
	original.publication_finished(Time.get_ticks_usec());audited.publication_finished(Time.get_ticks_usec(),false,"adoption")
	check(sample(original)==sample(audited) and audited.publications==2,"Stream finalization and World adoption expose two existing canonical quota units")
	var before:=sample(audited);var first: Dictionary=audited.snapshot().publication_budget.audit;var second: Dictionary=audited.snapshot().publication_budget.audit
	check(first==second and before==sample(audited),"Repeated diagnostic snapshots do not consume frame or mutate schedule")
	check(first.denials["publish:quota"].quota==1 and first.denials["publish:quota"].time==0,"Quota-only attribution is explicit")
	check(first.denials["publish:time"].time==1 and first.denials["publish:time"].quota==0,"Time-only attribution is explicit")
	check(first.denials["publish:both"].time_and_quota==1,"Combined denial attribution is explicit")
	check(first.phases["construction:template"].units==20 and first.phases["publication:adoption"].units==1,"Actual construction and adoption call boundaries are separately counted")
	audited.publication_audit.finish_frame(audited)
	var finalized: Dictionary=audited.snapshot().publication_budget.audit
	check(finalized.frames==first.frames and finalized.publication_units==first.publication_units and finalized.construction_units==first.construction_units,"Frame finalization and provisional snapshot represent each ledger once")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"audit":finalized,"scope":"Untimed parser and actual ResourcePool scheduling decision/count equivalence; private diagnostic overlay only"}
	var path:="res://.cache/nwn62/checks/publication-audit-preflight-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
