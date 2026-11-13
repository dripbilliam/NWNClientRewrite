extends "res://tests/native_staged_model_publication_test.gd"
class SlowInstance extends Instance:
	var starts: Array[int]=[]
	func _install_part(input: Dictionary,pool,model: Dictionary,index: int,parents: Dictionary,basis: Quaternion)->bool:
		starts.append(Time.get_ticks_usec());OS.delay_usec(2500)
		return super._install_part(input,pool,model,index,parents,basis)
func large_input()->Dictionary:
	var input:=bundle("f")
	for index in 80:
		var row: Dictionary=input.value.nodes[0].duplicate(true);row.name="extra_"+str(index);row.parent=0;row.position=[index*0.001,0.0,0.0];input.value.nodes.append(row)
	return input
func construct(input: Dictionary,pool,cap: int)->Dictionary:
	var template:=Template.new();check(template.begin_staged_build(input,pool),"Bounded template begins with cap "+str(cap))
	var result: Dictionary={};var turns:=0;var phases: Dictionary={}
	while turns<2048:
		result=template.staged_build_step(cap,1500);turns+=1
		check(int(result.get("units",0))<=cap,"Template unit cap remains exact")
		phases[str(result.get("phase","ready"))]=true
		if result.status!="pending":break
	check(result.status=="ready","Full template finishes cap "+str(cap))
	var pending: Dictionary={};var instances: Array=[]
	for clone in 2:
		turns=0
		while turns<2048:
			result=template.create_step(pending,cap,1500);turns+=1
			check(int(result.get("units",0))<=cap,"Clone and placement share exact unit cap")
			if result.status!="pending":break
		check(result.status=="ready" and pending.is_empty(),"Complete first/subsequent placement only escapes at commit")
		if result.status=="ready":instances.append(result.instance)
	return {"template":template,"instances":instances,"phases":phases.keys()}
func run()->void:
	var input:=large_input();var pool:=Pool.new();pool.cooperative_templates=true
	var before:=BeforeTemplate.new();check(before.build(input,pool),"Exact original synchronous PackedScene oracle builds")
	var original=before.create();var eight:=construct(input,pool,8);var larger:=construct(input,pool,32)
	for family in [eight,larger]:
		for instance in family.instances:check(node_rows(instance.get_child(0))==node_rows(original.get_child(0)),"Original graph/resource/metadata/helper/reference output remains exact for both batch caps")
	check(eight.instances.size()==2 and larger.instances.size()==2,"No physical/helper family is suppressed")
	# Test the actual virtual construction-unit boundary with one deliberately
	# indivisible 2.5ms part against a 1ms step deadline. Batch32 must return
	# after that one part, exactly like batch8; it cannot start32 expensive parts.
	var compact_input:=bundle("d");compact_input.value.nodes=compact_input.value.nodes.slice(0,2)
	for cap in [1,8,32]:
		var slow:=SlowInstance.new();check(slow.begin_install(compact_input,pool),"Actual expensive-unit fixture starts")
		var progress: Dictionary=slow.install_step(cap,1000)
		check(progress.status=="pending" and slow.starts.size()==1 and int(progress.units)==1,"Deadline stops before a second expensive unit regardless of batch cap "+str(cap))
		slow.cancel_install();check(slow.get_child_count()==0 and slow._installation.is_empty(),"Cancellation releases expensive phase graph after deadline yield")
		slow.free()
	# Cheap work still obeys a caller's requested one-unit API after the live
	# callsites choose32; this covers the template's inner phase transitions.
	var single:=Template.new();check(single.begin_staged_build(input,pool),"One-unit rollback/correctness API remains usable")
	for turn in 5:
		var progress: Dictionary=single.staged_build_step(1,1)
		check(progress.status=="pending" and int(progress.units)<=1,"One-unit caller remains bounded independently of live batch size")
	var weak_source=weakref(single._build_progress.source);single.cancel_staged_build()
	check(weak_source.get_ref()==null and single._build_progress.is_empty(),"Partial large template cancels without retaining a source graph")
	for family in [eight,larger]:
		for instance in family.instances:instance.free()
	original.free();pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual original PackedScene vs staged8/32 graph/resource/helper output, one-unit API, deliberate indivisible-unit deadline and cancellation; untimed correctness, no performance/FPS claim"}
	var path:="res://.cache/nwn62/checks/batch32-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
