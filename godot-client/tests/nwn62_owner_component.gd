extends "res://tests/nwn62_descendant_order_test.gd"
func summary(values: Array)->Dictionary:
	var ordered:=values.duplicate();ordered.sort();var total:=0.0
	for value in ordered:total+=float(value)
	return {"samples":ordered.size(),"mean_us":total/maxi(1,ordered.size()),"median_us":ordered[ordered.size()/2],"p95_us":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],"maximum_us":ordered.back()}
func owner_sample(script,input: Dictionary,pool)->Dictionary:
	var value=script.new();value.begin_staged_build(input,pool);var prepare_began:=Time.get_ticks_usec();var turns:=0
	while turns<8192:
		var state: Dictionary=value._build_progress
		if str(state.phase)=="move" and int(state.index)==state.source.parts.size():break
		value.staged_build_step(1,0);turns+=1
	var setup_us:=Time.get_ticks_usec()-prepare_began;var began:=Time.get_ticks_usec();var owner_steps:=0
	while turns<16384:
		value.staged_build_step(1,0);turns+=1;owner_steps+=1
		if not value._build_progress.is_empty() and value._build_progress.phase=="owners" and value._build_progress.owners.is_empty():break
	var elapsed:=Time.get_ticks_usec()-began;var state: Dictionary=value._build_progress
	var nodes:=int(state.node_count)-1;var valid: bool=state.phase=="owners" and state.owners.is_empty() and turns<16384
	value.cancel_staged_build()
	return {"owner_us":elapsed,"setup_us":setup_us,"nodes":nodes,"steps":owner_steps,"valid":valid}
func run()->void:
	var original=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ).get_var(false)
	var cases:={"original-tile":original,"five-family32":helper_input(32),"five-family64":helper_input(64),"large-fallback65":helper_input(65)}
	var rows: Array=[];var repetitions:=24
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--repetitions="):repetitions=maxi(1,int(argument.trim_prefix("--repetitions=")))
	for name in cases:
		var pool:=Pool.new();pool.cooperative_templates=true;var input: Dictionary=cases[name]
		for leg in ["before","after","after","before"]:
			var script=Prior if leg=="before" else RejectedCandidate
			for warmup in 2:owner_sample(script,input,pool)
			var owners: Array=[];var setups: Array=[];var node_count:=0;var step_count:=0
			for repetition in repetitions:
				var sample:=owner_sample(script,input,pool);check(sample.valid,"Actual owner-only boundary reached without pack/capture")
				owners.append(sample.owner_us);setups.append(sample.setup_us);node_count=sample.nodes;step_count=sample.steps
			rows.append({"case":name,"leg":leg,"owner":summary(owners),"setup_excluded":summary(setups),"nodes":node_count,"one_unit_calls":step_count})
		pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"construction":RejectedCandidate.construction_totals(),"scope":"REJECTED PERFORMANCE EXPERIMENT retained as frozen source only. Normal-engine headless ABBA component CPU only. Exact pre/post staged builder through actual owner preparation/per-node1-unit API, excluding all source install, pack/capture/admission. API overhead shared by both legs. No FPS/overall-loading claim."}
	var path:="res://.cache/nwn62/checks/owner-component-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"rows":rows}));quit(0 if failures.is_empty() else 1)

