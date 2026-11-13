extends "res://tests/native_staged_model_publication_test.gd"
# Private small-template recipe route versus current packed route. No renderer/FPS.
const Candidate=preload("res://.cache/nwn62/small-recipe-a/systems/native_render/model_template.gd")
var rows: Array=[]

func build_staged(template,input: Dictionary,pool,tag: String) -> Dictionary:
	var began:=Time.get_ticks_usec();var peak:=0;var steps:=0;var status:="pending"
	check(template.begin_staged_build(input,pool),tag+" begin")
	while status=="pending" and steps<512:
		var unit_began:=Time.get_ticks_usec()
		var result: Dictionary=template.staged_build_step(8,3000)
		peak=maxi(peak,Time.get_ticks_usec()-unit_began);status=str(result.status);steps+=1
	check(status=="ready",tag+" ready: "+template.failure)
	return {"status":status,"steps":steps,"max_step_us":peak,"active_us":Time.get_ticks_usec()-began,"mode":template.construction_snapshot().mode,"fallback":template.recipe_fallback_reason}

func compare_case(input: Dictionary,pool,tag: String,expect_recipe: bool) -> void:
	var packed:=Template.new();var recipe:=Candidate.new()
	var baseline:=build_staged(packed,input,pool,tag+" packed")
	var selected:=build_staged(recipe,input,pool,tag+" recipe")
	check(packed.scene!=null and packed.recipe==null,tag+" control stayed packed")
	check((recipe.recipe!=null)==expect_recipe and (recipe.scene!=null)==not expect_recipe,tag+" selected expected mode")
	var packed_first=packed.create();var packed_second=packed.create()
	var recipe_first=recipe.create();var recipe_second=recipe.create()
	check(packed_first!=null and packed_second!=null and recipe_first!=null and recipe_second!=null,tag+" all placements created")
	if packed_first!=null and packed_second!=null and recipe_first!=null and recipe_second!=null:
		check(node_rows(packed_first.get_child(0))==node_rows(recipe_first.get_child(0)),tag+" first graph exact")
		check(node_rows(packed_second.get_child(0))==node_rows(recipe_second.get_child(0)),tag+" clone graph exact")
		check(recipe.first_instance_reuses==1 and packed.first_instance_reuses==1,tag+" original detached root reused once")
		check(packed_first.parts.size()==recipe_first.parts.size() and packed_first.meshes.size()==recipe_first.meshes.size() and packed_first.pick_surfaces.size()==recipe_first.pick_surfaces.size(),tag+" placement inventories exact")
		packed_first.parts[0].set_meta("private_edit",{"values":[99]})
		recipe_first.parts[0].set_meta("private_edit",{"values":[99]})
		check(not packed_second.parts[0].has_meta("private_edit") and not recipe_second.parts[0].has_meta("private_edit"),tag+" clone metadata private")
		if not recipe_first.meshes.is_empty():
			var source_material=recipe_first.meshes[0].material_override
			var clone_material=recipe_second.meshes[0].material_override
			check((source_material==clone_material)==(packed_first.meshes[0].material_override==packed_second.meshes[0].material_override),tag+" material sharing matches packed")
			if not expect_recipe:check(source_material!=clone_material,tag+" local material retains packed private clone")
	rows.append({"case":tag,"packed":baseline,"candidate":selected,"recipe_captures":recipe.recipe_capture_successes,"packed_fallbacks":recipe.packed_template_creations})
	for item in [packed_first,packed_second,recipe_first,recipe_second]:if item!=null:item.free()
	packed=null;recipe=null;pool.clear()

func run() -> void:
	check(OS.get_cmdline_user_args().has("--model-template=recipe-small"),"Private recipe selector is active")
	var simple:=bundle("r")
	var pool:=Pool.new();pool.cooperative_templates=true
	compare_case(simple,pool,"authored-reference-emitter",true)
	var local_pool:=LocalPool.new();local_pool.cooperative_templates=true
	compare_case(bundle("s"),local_pool,"local-material",false)
	var original_file:=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ)
	if original_file!=null:
		var original: Dictionary=original_file.get_var(false);original_file.close()
		var original_pool:=Pool.new();original_pool.cooperative_templates=true
		compare_case(original,original_pool,"installed-original-tile",true)
	var cancel_pool:=Pool.new();cancel_pool.cooperative_templates=true
	var pending:=Candidate.new();check(pending.begin_staged_build(bundle("t"),cancel_pool),"Cancellation starts private candidate")
	var pending_steps:=0
	while pending_steps<256 and not pending._build_progress.is_empty() and str(pending._build_progress.phase)!="capture":
		pending.staged_build_step(1,0);pending_steps+=1
	check(not pending._build_progress.is_empty() and str(pending._build_progress.phase)=="capture","Cancellation reaches recipe capture")
	var weak=weakref(pending._build_progress.root)
	pending.cancel_staged_build()
	check(pending._build_progress.is_empty() and pending.scene==null and pending.recipe==null and weak.get_ref()==null,"Cancellation releases detached root and publishes nothing")
	cancel_pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"scope":"Private opt-in small recipe versus default packed graph/root/material/reference/clone and cancellation. Active detached component only; no FPS or live entry."}
	var report:=""
	for arg in OS.get_cmdline_user_args():if arg.begins_with("--report="):report=arg.substr(9)
	if not report.is_empty():
		var file:=FileAccess.open(report,FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"  "));file.close()
	print("NWN62_SMALL_RECIPE "+JSON.stringify({"success":result.success,"checks":checks,"failures":failures,"rows":rows}))
	quit(0 if result.success else 1)
