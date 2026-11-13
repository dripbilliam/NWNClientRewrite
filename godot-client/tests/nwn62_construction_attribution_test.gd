extends SceneTree
# Untimed private attribution plumbing. Synthetic timestamps are correctness
# inputs, not benchmark durations. No models/assets or rendering are launched.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Area=preload("res://systems/native_render/area_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const NativeLive=preload("res://native_live_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _init()->void:call_deferred("run")
func run()->void:
	check(Objects!=null and Area!=null and Creatures!=null and NativeLive!=null,"all changed source parsers loaded")
	var pool=Pool.new()
	check(pool.publication_budget_us==4000 and pool.publication_callback_budget_us()==3000,"same private4ms/callback3ms policy")
	pool.construction_finished(Time.get_ticks_usec(),"small","small",1,"start","end")
	check(pool._private_shared_audit.maximum_construction.is_empty(),"sub5ms operation does not allocate peak record")
	pool.begin_completion_scope();pool.construction_finished(0,"nested","nested",2,"start","end");pool.end_completion_scope()
	check(pool._private_shared_audit.maximum_construction.is_empty(),"untimed nested operation cannot become a peak")
	pool.construction_finished(Time.get_ticks_usec()-6000,"objects.template","original_model",3,"install/parts:12","install")
	var first: Dictionary=pool._private_shared_audit.maximum_construction.duplicate()
	check(first.elapsed_us>=6000,"existing outer elapsed captured")
	check(first.caller=="objects.template" and first.model=="original_model" and first.id==3,"caller/model/id captured")
	check(first.phase_before=="install/parts:12" and first.phase_after=="install","phase before/after preserved")
	check(first.ended_us-first.began_us==first.elapsed_us,"timestamps derive from existing elapsed")
	pool.construction_finished(Time.get_ticks_usec(),"smaller","smaller",4,"start","end")
	check(pool._private_shared_audit.maximum_construction==first,"smaller operation preserves single largest peak")
	pool.construction_finished(Time.get_ticks_usec()-8000,"terrain.clone","tile_model",5,"recipe","placement")
	check(pool._private_shared_audit.maximum_construction.id==5,"larger operation replaces single peak")
	var roundtrip: Dictionary=JSON.parse_string(JSON.stringify(pool._private_shared_audit.maximum_construction))
	check(roundtrip.id==5 and roundtrip.model=="tile_model","peak is primitive JSON data without owner references")
	for index in 12:
		var template=Template.new();template.source_model_name="model_"+str(index);template.staged_max_step_us=index*1000;template.staged_steps=index+1;template.physical_part_count=index
		pool.templates[str(index)]=template
	var census: Dictionary=pool.private_template_peak_snapshot()
	check(census.cached_templates==12 and census.top8.size()==8,"final-only census bounded to top8")
	check(census.top8[0].model=="model_11" and census.top8[7].model=="model_4","census preserves top8 existing staged maxima")
	check(pool.private_template_peak_snapshot()==census,"report-only census does not mutate cache or maxima")
	var source:=Instance.new();source._installation={"phase":"parts","index":12}
	var template=Template.new();template._build_progress={"phase":"install","source":source}
	check(Pool.private_pending_phase({"template":template})=="install/parts:12","template phase label includes existing child part boundary")
	template._build_progress={};source._installation={};source.free()
	check(Pool.private_pending_phase({"placement_job":true})=="placement","placement label")
	check(Pool.private_pending_phase({"job":true})=="recipe","recipe label")
	check(Pool.private_pending_phase({})=="begin","begin label")
	check(Pool.private_actor_phase(null)=="begin","no actor reference label")
	check(Pool.private_plan_model({"pieces":[{"key":"first_model"}]})=="first_model","scalar first plan model label")
	pool.clear()
	check(pool.private_template_peak_snapshot().cached_templates==0,"cleared cache census does not retain template owners")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"peak":pool._private_shared_audit.maximum_construction,"census":census,"scope":"Untimed PRIVATE attribution parse/plumbing correctness with synthetic timestamp inputs; no CPU/FPS performance measurement"}
	var output:="";for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
