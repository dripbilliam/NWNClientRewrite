extends "res://tests/native_staged_model_publication_test.gd"
const Prior=preload("res://.cache/nwn62/descendants-before/model_template.gd")
const RejectedCandidate=preload("res://.cache/nwn62/descendants-rejected-source/model_template.gd")
func ownership_order(node: Node)->Array:
	var pending: Array=node.get_children();var result: Array=[]
	while not pending.is_empty():
		var next: Node=pending.pop_back();result.append(next);pending.append_array(next.get_children())
	return result
func ordinal_path(node: Node,root_node: Node)->Array:
	var result: Array=[]
	while node!=root_node:result.push_front(node.get_index());node=node.get_parent()
	return result
func normalized_rows(node: Node)->Array:
	var rows:=node_rows(node);var nodes: Array=node.get_children();var index:=0
	while not nodes.is_empty():
		var current: Node=nodes.pop_front();rows[index].path=ordinal_path(current,node);index+=1;nodes.append_array(current.get_children())
	return rows
func helper_input(count: int)->Dictionary:
	var input:=bundle("e");var mesh_row: Dictionary=input.value.nodes[1].duplicate(true);var emitter: Dictionary=input.value.nodes[2].emitter.duplicate(true)
	input.value.nodes=[]
	for index in count:
		var row: Dictionary=mesh_row.duplicate(true);row.name="all_families_"+str(index);row.parent=index-1;row.position=[0.0,0.0,0.0];row.features=["light","emitter","reference"]
		row.light={"color":[1.0,0.5,0.2],"radius":1.0,"multiplier":1.0};row.emitter=emitter.duplicate(true);row.reference={"model":"child_"+str(index),"reattachable":1};input.value.nodes.append(row)
	return input
func build_with_order(script,input: Dictionary,pool)->Dictionary:
	var value=script.new();check(value.begin_staged_build(input,pool),"Detached exact static constructor begins")
	var transitions: Array=[];var turns:=0;var previous: Dictionary={};var actual_root: Node
	while turns<8192:
		var progress: Dictionary=value.staged_build_step(1,0);turns+=1
		check(int(progress.get("units",0))<=1,"Native discovery retains per-owner one-unit cap")
		actual_root=value._build_progress.get("root") if not value._build_progress.is_empty() else value._first_root
		if is_instance_valid(actual_root):
			for node in actual_root.find_children("*","",true,false):
				if node.owner==actual_root and not previous.has(node):previous[node]=true;transitions.append(ordinal_path(node,actual_root))
		if progress.status!="pending":check(progress.status=="ready","All native/helper families finish construction");break
	check(turns<8192,"Construction terminates without suppressing nodes")
	var instance=value.create();check(instance!=null,"Fully owned root transfers only after complete construction")
	return {"template":value,"instance":instance,"transitions":transitions}
func run()->void:
	# Order proof covers multiple roots, variable sibling widths and deep trees.
	for width in [1,2,5,16]:
		var node:=Node3D.new()
		for sibling in width:
			var branch:=Node3D.new();node.add_child(branch)
			for leaf in sibling%5+1:
				var parent: Node=branch
				for depth in leaf+1:var child:=Node3D.new();parent.add_child(child);parent=child
		var expected:=ownership_order(node);var prepared:=RejectedCandidate.reverse_sibling_ownership_order(node,node.find_children("*","",true,false));var actual: Array=[]
		while not prepared.is_empty():actual.append(prepared.pop_back())
		check(actual==expected,"Native prepared order equals exact old reverse-sibling parent-first traversal")
		node.free()
	var pool:=Pool.new();pool.cooperative_templates=true
	for count in [1,4,64,65]:
		var input:=helper_input(count);var original:=build_with_order(Prior,input,pool);var candidate:=build_with_order(RejectedCandidate,input,pool)
		check(original.transitions==candidate.transitions,"Every owner assignment occurs in original order for family-rich graph "+str(count))
		# Light nodes are unnamed constructors and Godot assigns distinct @ID
		# names to independent trees. Compare the exact child ordinal/class and
		# every resource/transform/helper/path field rather than those global IDs.
		check(normalized_rows(original.instance.get_child(0))==normalized_rows(candidate.instance.get_child(0)),"Original resources, helper/reference paths, physical graph and metadata remain exact")
		var snapshot: Dictionary=candidate.template.construction_snapshot()
		check(snapshot.owner_discovery_mode==("bounded-native" if count<=64 else "incremental"),"Only proven <=64-part static family enters native discovery")
		check(candidate.instance.get_child(0).find_children("*","",true,false).size()==count*5,"All five constructor families are retained per physical part")
		if count==64:check(not snapshot.small_native_packed,"320 descendants still exceed96-node native-pack threshold")
		original.instance.free();candidate.instance.free()
		var cancelled:=RejectedCandidate.new();cancelled.begin_staged_build(input,pool)
		for turn in 8192:
			cancelled.staged_build_step(1,0)
			if not cancelled._build_progress.is_empty() and cancelled._build_progress.phase=="owners":break
		check(not cancelled._build_progress.is_empty(),"Cancellation fixture reaches private owner assignment phase")
		var pending_root=weakref(cancelled._build_progress.root);var pending_source=weakref(cancelled._build_progress.source)
		cancelled.cancel_staged_build();check(pending_root.get_ref()==null and pending_source.get_ref()==null,"Cancellation frees native order references, detached source and partial root")
	pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"construction":RejectedCandidate.construction_totals(),"scope":"REJECTED PERFORMANCE EXPERIMENT retained as frozen source only. Native <=320-node discovery bound for exact static five-node constructor; actual per-owner sequence,1-unit caps, full original helper/resource output,64/65 boundary and cancellation. No timing/FPS claim."}
	var path:="res://.cache/nwn62/checks/descendants-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
