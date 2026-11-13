extends "res://tests/native_staged_model_publication_test.gd"
# Run the actual before/after ResourcePool bodies. The sole instrumentation is a
# wrapper around actual Template.identity calls; source control flow is intact.
var call_counts: Dictionary={}
func instrument_pool(path: String):
	var source:=FileAccess.get_file_as_string(path)
	check(not source.is_empty(),"Exact source is readable: "+path)
	source=source.replace("Template.identity(","_test_identity(")
	source+="\nvar identity_test_calls:=0\nfunc _test_identity(input: Dictionary,pool) -> String:\n\tidentity_test_calls+=1\n\treturn Template.identity(input,pool)\n"
	var script:=GDScript.new();script.source_code=source
	var error:=script.reload()
	check(error==OK,"Instrumented actual pool parses: "+path)
	return script.new() if error==OK else null
func step_count(pool,input: Dictionary,pending: Dictionary)->Dictionary:
	var before:=int(pool.identity_test_calls)
	var result: Dictionary=pool.model_template_step(input,pending,1,0)
	return {"result":result,"calls":int(pool.identity_test_calls)-before,"pending":not pending.is_empty()}
func inspect_scenario(pool,scenario: String)->Dictionary:
	pool.cooperative_templates=true
	var input:=bundle("a");var pending: Dictionary={}
	var first:=step_count(pool,input,pending)
	check(first.result.status=="pending" and first.result.phase=="begin","Actual pool begins private staged request")
	var weak_source=weakref(pending.template._build_progress.source)
	var supplied: Dictionary=input
	match scenario:
		"mutated_same":input.sha256="b".repeat(64)
		"mutated_texture":input.textures["changed"]={"sha256":"t".repeat(64)}
		"different_request":supplied=input.duplicate(true);supplied.sha256="b".repeat(64)
		"distinct_equal":supplied=input.duplicate(true)
		"mutated_pending_other":supplied=input.duplicate(true);input.sha256="b".repeat(64)
		"policy":pool.unshaded=true
	var resumed:=step_count(pool,supplied,pending)
	var result: Dictionary=resumed.result
	var observation:={"status":result.status,"phase":result.get("phase",""),"pending":resumed.pending,"source_alive":weak_source.get_ref()!=null,"calls":resumed.calls}
	if scenario in ["mutated_same","mutated_texture","mutated_pending_other","policy"]:
		check(result.get("phase","")=="policy-invalidated" and pending.is_empty() and weak_source.get_ref()==null,"Mutated source/policy cancels and releases exact pending graph: "+scenario)
	elif scenario=="different_request":
		check(result.get("phase","")=="resume-original-source" and not pending.is_empty() and weak_source.get_ref()!=null,"Different request cannot consume pinned result or cancel its owner")
	else:
		check(result.status=="pending" and result.get("phase","")!="policy-invalidated" and weak_source.get_ref()!=null,"Unchanged/equal content resumes actual staged construction: "+scenario)
	pool.cancel_template_step(pending);pool.clear()
	return observation
func run()->void:
	var scenarios:=["same","mutated_same","mutated_texture","different_request","distinct_equal","mutated_pending_other","policy"]
	for scenario in scenarios:
		var before=instrument_pool("res://.cache/nwn62/identity-reuse-before/resource_pool.gd")
		var candidate=instrument_pool("res://systems/native_render/resource_pool.gd")
		if before==null or candidate==null:continue
		var original:=inspect_scenario(before,scenario);var optimized:=inspect_scenario(candidate,scenario)
		call_counts[scenario]={"original":original.calls,"optimized":optimized.calls}
		var expected:=1 if scenario in ["same","mutated_same","mutated_texture","policy"] else 2
		check(original.calls==2 and optimized.calls==expected,"Real identity calls reduced only for same Dictionary: "+scenario)
		original.erase("calls");optimized.erase("calls")
		check(original==optimized,"Actual before/after statuses, graph lifetime and pinned-request behavior match: "+scenario)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"identity_calls":call_counts,"scope":"Untimed actual ResourcePool source instrumentation; mutation/policy fencing and private graph lifetimes; no rendering or FPS claim"}
	var path:="res://.cache/nwn62/checks/template-identity-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
