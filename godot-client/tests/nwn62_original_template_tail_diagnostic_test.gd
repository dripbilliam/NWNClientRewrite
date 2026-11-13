extends "res://tests/native_staged_model_publication_test.gd"
# A small original-format model exercises the same synchronous ModelTemplate
# and ModelInstance construction path as the historical long callback.
func run() -> void:
	var enabled:=OS.get_cmdline_user_args().has("--publication-completion-diagnose")
	var input:=bundle("q")
	var pool:=Pool.new();pool.cooperative_templates=false
	var template=pool.model_template(input)
	check(template!=null and template.scene!=null and template.recipe==null,"Original PackedScene template builds")
	if template!=null:
		check(template.preparation_timings.is_empty()!=enabled,"Template phases follow only diagnostic flag")
		if enabled:
			var phases: Dictionary=template.preparation_timings
			check(phases.has("source_install_ms") and phases.has("owners_ms") and phases.has("pack_ms") and phases.has("total_ms"),"Template receipt separates source, owner and pack phases")
			check(phases.install.has("parts_ms") and phases.install.has("geometry_ms") and phases.install.has("material_ms"),"Source install receipt separates part, geometry and material phases")
			check(float(phases.total_ms)>=float(phases.source_install_ms) and float(phases.source_install_ms)>=float(phases.install.get("material_ms",0)),"Nested phase times fit outer construction")
			pool._record_completion_template(input,template,10000,false)
			var top: Array=pool.snapshot().completion_template_peaks
			check(top.size()<=8 and top.any(func(row):return str(row.model)=="staged" and str(row.sha256)==str(input.sha256) and int(row.callback_us)==10000),"Bounded template tail identifies model and original SHA")
		else:check(not pool.snapshot().has("completion_template_peaks") and pool.completion_template_peaks.is_empty(),"Default-off pool allocates no template receipt")
		var oracle:=BeforeTemplate.new();check(oracle.build(input,pool),"Original PackedScene oracle builds")
		var actual=template.create();var expected=oracle.create()
		check(actual!=null and expected!=null and node_rows(actual.get_child(0))==node_rows(expected.get_child(0)),"Diagnostic leaves physical graph and resources unchanged")
		if actual!=null:actual.retire()
		if expected!=null:expected.retire()
	pool.clear()
	var path:="res://.cache/nwn62/original-template-diagnostic-"+("on" if enabled else "off")+".json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"enabled":enabled,"scope":"Synchronous original-format PackedScene template/source-install phase attribution and graph parity; no original-world FPS claim."}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write report: "+path);quit(2);return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NWN62_ORIGINAL_TEMPLATE_DIAGNOSTIC ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
