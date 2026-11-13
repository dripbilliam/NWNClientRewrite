extends "res://tests/native_staged_model_publication_test.gd"
# Tiny opt-in receipt. The same construction and packed-scene oracle run with
# and without --publication-template-diagnose; no frame/FPS timing is inferred.

func run() -> void:
	var enabled:=Template.configured_staged_diagnostics()
	var receipt: Dictionary={}
	var input:=bundle("f")
	var pool:=Pool.new();pool.cooperative_templates=true
	var pending: Dictionary={};var result: Dictionary={};var turns:=0
	while turns<512:
		result=pool.model_template_step(input,pending,1,0);turns+=1
		if result.status!="pending":break
	check(result.status=="ready" and result.template!=null,"Staged model publishes")
	if result.status=="ready":
		var template=result.template
		var snapshot: Dictionary=template.construction_snapshot()
		var pool_snapshot: Dictionary=pool.snapshot()
		check(snapshot.has("staged_diagnostic_peak_step")==enabled,"Template diagnostic receipt follows opt-in")
		check(pool_snapshot.has("template_diagnostic_peaks")==enabled,"Pool diagnostic receipt follows opt-in")
		if not enabled:check(template.staged_diagnostic_peak_step==null and template.staged_diagnostic_phase_max_us==null and pool.template_diagnostic_peaks==null,"Default path allocates no diagnostic containers")
		if enabled:
			var peaks: Array=pool_snapshot.template_diagnostic_peaks
			if not peaks.is_empty():receipt=peaks[0].duplicate(true)
			check(peaks.size()==1 and str(peaks[0].model)=="staged" and str(peaks[0].sha256)==str(input.sha256),"Bounded receipt identifies source model and SHA")
			check(int(snapshot.staged_diagnostic_peak_step.get("step_us",0))==int(template.staged_max_step_us) and not snapshot.staged_diagnostic_peak_step.phases_us.is_empty(),"Peak step contains phase attribution")
			check(peaks.size()<=8 and peaks[0].phase_max_us.size()<=8,"Receipt remains bounded")
		var oracle:=BeforeTemplate.new()
		check(oracle.build(input,pool),"Frozen packed template builds")
		var expected=oracle.create();var actual=template.create()
		check(expected!=null and actual!=null and node_rows(expected.get_child(0))==node_rows(actual.get_child(0)),"Diagnostic mode preserves graph and resources")
		if expected!=null:expected.free()
		if actual!=null:actual.free()
	pool.clear()
	var report:={"issue":"NWN-62","success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics_enabled":enabled,"steps":turns,"scope":"Small staged/template parity and default-off diagnostic receipt; no performance or original-world claim"}
	if enabled:report.receipt=receipt
	var path:="res://.cache/nwn62/checks/template-diagnostic-on-a.json" if enabled else "res://.cache/nwn62/checks/template-diagnostic-off-a.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.substr(9)
	if FileAccess.file_exists(path):quit(2);return
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
