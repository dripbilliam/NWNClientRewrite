extends "res://tests/native_staged_model_publication_test.gd"
# Verify the no-reference fast path against the frozen synchronous template.
const Original=preload("res://tests/fixtures/native_model_template_before_publication.gd")

func run()->void:
	var observations: Array=[]
	for with_reference in [false,true]:
		var input:=bundle("d" if with_reference else "e")
		if not with_reference:
			for row in input.value.nodes:
				row.erase("reference")
				if row.has("features"):row.features.erase("reference")
		var pool:=Pool.new();pool.cooperative_templates=true
		var original:=Original.new();var candidate:=Template.new()
		check(original.build(input,pool),"Frozen template builds "+str(with_reference))
		check(candidate.begin_staged_build(input,pool),"Staged template begins "+str(with_reference))
		var saw_references:=false;var first_reference_rows:=-1;var steps:=0;var progress: Dictionary={}
		while steps<512:
			var before_phase:=str(candidate._build_progress.get("phase","ready"))
			progress=candidate.staged_build_step(1,0);steps+=1
			check(int(progress.get("units",0))<=1,"One-unit publication bound")
			if before_phase=="references" and not saw_references:
				saw_references=true
				first_reference_rows=candidate._build_progress.get("reference_rows",[]).size()
				if not with_reference:check(str(candidate._build_progress.get("phase",""))!="references" and first_reference_rows==0,"No-reference model skips row allocation and publication steps")
				else:check(str(candidate._build_progress.get("phase",""))=="references" and first_reference_rows>0,"Reference model keeps ordered row construction")
			if progress.status!="pending":break
		observations.append({"with_reference":with_reference,"steps":steps,"status":progress.get("status"),"reason":progress.get("reason"),"phase":progress.get("phase"),"saw_references":saw_references,"first_reference_rows":first_reference_rows})
		check(progress.status=="ready" and (saw_references if with_reference else not saw_references),"Reference and no-reference models complete through their expected paths")
		check(candidate.reference_rows.size()==(input.value.nodes.size() if with_reference else 0),"Reference graph rows retain exact inclusion")
		var expected=original.create();var actual=candidate.create()
		check(expected!=null and actual!=null and node_rows(expected.get_child(0))==node_rows(actual.get_child(0)),"Staged graph matches frozen packed graph")
		if expected!=null:expected.free()
		if actual!=null:actual.free()
		pool.clear()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"No-reference fast path and reference graph ordering against frozen PackedScene; untimed headless correctness only"}
	var file:=FileAccess.open("res://.cache/nwn62/checks/reference-skip-a.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
