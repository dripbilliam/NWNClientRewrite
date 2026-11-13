extends "res://tests/native_staged_model_publication_test.gd"
const Frozen=preload("res://.cache/nwn62/packed-staged-a/before/model_template.gd")
var results: Array=[]
var differences: Array=[]
func _canonical_rows(rows: Array) -> Array:
	var normalized: Array=[]
	for row in rows:
		var copy: Dictionary=row.duplicate()
		var path: String=str(copy.path)
		var slash:=path.find("/")
		copy.path="<root>" if slash<0 else "<root>"+path.substr(slash)
		normalized.append(copy)
	return normalized
func _difference(left: Array,right: Array) -> Dictionary:
	if left.size()!=right.size():return {"length_left":left.size(),"length_right":right.size()}
	for index in left.size():
		if left[index]==right[index]:continue
		var a: Dictionary=left[index];var b: Dictionary=right[index]
		for key in a:
			if a[key]==b.get(key):continue
			return {"index":index,"path":str(a.get("path","")),"key":str(key),"left_type":type_string(typeof(a[key])),"right_type":type_string(typeof(b.get(key))),"left_value":str(a[key]).left(180),"right_value":str(b.get(key)).left(180)}
		return {"index":index,"path":str(a.get("path","")),"other_keys":b.keys()}
	return {}
func _case(input: Dictionary,label: String) -> void:
	var pool:=Pool.new();pool.cooperative_templates=true
	var old:=Frozen.new();var next:=Template.new()
	check(old.build(input,pool),label+": frozen recipe builds")
	check(next.begin_staged_build(input,pool),label+": packed staged begins detached")
	var turns:=0;var status: Dictionary={}
	while turns<4096:
		status=next.staged_build_step(8,1500);turns+=1
		check(int(status.get("units",-1))<=8,label+": construction unit bound")
		if status.status!="pending":break
		check(not next.construction_snapshot().ready and not is_instance_valid(next._first_root),label+": no partial template escapes")
	check(status.status=="ready" and next.recipe==null and next.scene!=null,label+": complete packed template commits")
	check(next.construction_snapshot().requested_packed_staged and next.construction_snapshot().mode=="packed-scene",label+": explicit path engaged")
	for n in 2:
		var baseline=old.create();var pending: Dictionary={};var made:=next.create_step(pending,8,1500)
		check(made.status=="ready" and made.instance!=null and pending.is_empty(),label+": clone "+str(n)+" fully published")
		if baseline!=null and made.instance!=null:
			var old_rows:=_canonical_rows(node_rows(baseline));var new_rows:=_canonical_rows(node_rows(made.instance))
			if old_rows!=new_rows and differences.size()<8:differences.append({"case":label,"clone":n,"difference":_difference(old_rows,new_rows)})
			check(old_rows==new_rows,label+": clone "+str(n)+" exact node/resource/metadata rows")
			check(baseline.parts.size()==made.instance.parts.size() and baseline.meshes.size()==made.instance.meshes.size(),label+": clone "+str(n)+" full part/mesh counts")
			baseline.free();made.instance.free()
	results.append({"case":label,"nodes":input.value.nodes.size(),"staged_steps":next.staged_steps,"max_step_us":next.staged_max_step_us,"mode":next.construction_snapshot().mode})
	var aborted:=Template.new();check(aborted.begin_staged_build(input,pool),label+": cancel job begins")
	var progress:=aborted.staged_build_step(1,1)
	check(progress.status=="pending",label+": cancel job yielded")
	aborted.cancel_staged_build()
	check(aborted._build_progress.is_empty() and aborted.scene==null and aborted.recipe==null and not is_instance_valid(aborted._first_root),label+": cancellation releases partial template")
	aborted=null;next=null;old=null;pool.clear()
func run() -> void:
	check(Template.configured_packed_staged(),"Private packed-staged flag selected")
	var file:=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ)
	check(file!=null,"Sealed original tile input present")
	if file!=null:
		var original: Dictionary=file.get_var(false);file.close();_case(original,"original-tile")
	var authored:=bundle("d");authored.value.nodes=authored.value.nodes.slice(0,2)
	for index in 256:
		var row: Dictionary=authored.value.nodes[1].duplicate(true);row.name="copy_"+str(index);row.parent=0;row.position=[index*0.001,0.0,0.0];authored.value.nodes.append(row)
	_case(authored,"authored-257-mesh")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"results":results,"differences":differences,"scope":"Same-process restored recipe versus explicit packed-staged exact detached graph/resource/order and cancellation. Original sealed tile plus authored large graph; no loading/FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var output:=FileAccess.open(argument.substr(9),FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
