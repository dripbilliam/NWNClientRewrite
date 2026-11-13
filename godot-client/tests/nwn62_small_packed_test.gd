extends "res://tests/nwn62_construction_test.gd"
const OriginalTemplate=preload("res://.cache/nwn62/before/systems/native_render/model_template.gd")
func run()->void:
	check(not Template.configured_recipe(),"Small native path fixture uses default cooperative policy, not explicit recipe override")
	var input:=bundle("e");var pool:=Pool.new();pool.cooperative_templates=true
	var original:=OriginalTemplate.new();check(original.build(input,pool),"Frozen native PackedScene baseline builds")
	var candidate:=Template.new();check(candidate.begin_staged_build(input,pool),"Small graph begins cooperative source assembly")
	var progress: Dictionary={};var turns:=0
	while turns<256:
		progress=candidate.staged_build_step(1,0);turns+=1
		if progress.status!="pending":break
	check(progress.status=="ready" and candidate.small_native_packed and candidate.recipe==null and candidate.scene!=null and candidate.recipe_capture_attempts==0,"Only bounded small graph bypasses recipe capture and commits actual PackedScene")
	var pending: Dictionary={};var baseline=original.create();var first: Dictionary=candidate.create_step(pending,1,0);var second: Dictionary=candidate.create_step(pending,1,0)
	check(first.status=="ready" and second.status=="ready" and node_rows(first.instance.get_child(0))==node_rows(baseline.get_child(0)) and node_rows(second.instance.get_child(0))==node_rows(baseline.get_child(0)),"First root reuse and native clone preserve exact full physical/helper/material/metadata output")
	check(candidate.first_instance_reuses==1 and candidate.packed_instance_creations==1,"Bounded native first and subsequent units use the actual engine clone path")
	first.instance.parts[0].set_meta("private_edit",{"values":[99]})
	check(not second.instance.parts[0].has_meta("private_edit"),"Small native placements retain private mutable node/metadata ownership")
	first.instance.free();second.instance.free();baseline.free()
	for count in [64,65]:
		var oversized:=bundle("f");oversized.value.nodes=oversized.value.nodes.slice(0,2)
		while oversized.value.nodes.size()<count:
			var row: Dictionary=oversized.value.nodes[0].duplicate(true);row.parent=0;row.name="extra_"+str(oversized.value.nodes.size());oversized.value.nodes.append(row)
		var large:=Template.new();large.begin_staged_build(oversized,pool)
		while not large._build_progress.is_empty():large.staged_build_step(64,0)
		check(large.small_native_packed==(count==64) and (large.recipe!=null)==(count==65),"Physical part boundary selects bounded native or cooperative construction at "+str(count))
	var many:=bundle("g");many.value.nodes=many.value.nodes.slice(0,2)
	while many.value.nodes.size()<64:
		var row: Dictionary=many.value.nodes[1].duplicate(true);row.parent=0;row.name="mesh_"+str(many.value.nodes.size());many.value.nodes.append(row)
	var wide:=Template.new();wide.begin_staged_build(many,pool)
	while not wide._build_progress.is_empty():wide.staged_build_step(64,0)
	check(not wide.small_native_packed and wide.recipe!=null,"Actual node count above96 keeps cooperative construction even within64physical parts")
	pool.clear();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Default cooperative small graph uses real native PackedScene pack/first reuse/clone with full frozen-source parity; exact64part/96actual-node eligibility and private ownership. No FPS measurement."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
