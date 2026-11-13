extends SceneTree
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const PlacementJob=preload("res://systems/native_render/model_placement_job.gd")
var checks:=0
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func graph(invalid: bool=false)->Node3D:
	var root:=Node3D.new();root.name="root"
	var outer:=Node3D.new();outer.name="outer";root.add_child(outer)
	var first:=MeshInstance3D.new();first.name="part_0";first.mesh=ArrayMesh.new();first.set_meta("native_part_index",0);outer.add_child(first)
	var nested:=Node3D.new();nested.name="part_1";nested.set_meta("native_part_index",1);nested.set_meta("native_pick_geometry",ArrayMesh.new());outer.add_child(nested)
	var decoration:=MeshInstance3D.new();decoration.name="decoration";decoration.mesh=ArrayMesh.new();nested.add_child(decoration)
	var last:=MeshInstance3D.new();last.name="part_2";last.mesh=ArrayMesh.new();last.set_meta("native_part_index",-1 if invalid else 1);root.add_child(last)
	var pick:=Node3D.new();pick.name="part_3";pick.set_meta("native_part_index",2);pick.set_meta("native_pick_geometry",ArrayMesh.new());root.add_child(pick)
	return root
func create(recipe,with_index: bool)->Dictionary:
	var creator=recipe.begin_create(with_index);check(creator!=null,"Fresh private creation begins")
	if creator==null:return {}
	while creator.status=="pending":creator.step(2,0)
	check(creator.status=="ready","Bounded recipe creation completes")
	var index: Dictionary=creator.placement_index() if with_index else {}
	var root: Node3D=creator.take()
	return {"root":root,"index":index}
func publish(created: Dictionary)->Dictionary:
	var job:=PlacementJob.new();job.configure(created.root,Template.Placement.new(),"fixture",[],[],{},created.index)
	var turns:=0;var result: Dictionary={}
	while job.status=="pending" and turns<128:
		result=job.step(1,0);turns+=1
	var value:={"status":job.status,"reason":job.failure,"turns":turns}
	if job.status=="ready":
		var placement=job.take()
		value.parts=placement.parts.map(func(node):return str(node.name))
		value.meshes=placement.meshes.map(func(node):return str(node.name))
		value.picks=placement.pick_surfaces.map(func(node):return str(node.name))
		value.root=placement
	return value
func run()->void:
	for invalid in [false,true]:
		var source:=graph(invalid);var recipe:=Recipe.new()
		check(recipe.capture(source),"Detached source captures: "+recipe.failure)
		if not recipe.failure.is_empty():source.free();continue
		var ordinary:=publish(create(recipe,false));var indexed:=publish(create(recipe,true))
		check(ordinary.status==indexed.status and ordinary.reason==indexed.reason,"Indexed placement status and error match normal traversal")
		if not invalid:
			check(ordinary.status=="ready" and ordinary.parts==indexed.parts and ordinary.parts==["part_0","part_2","part_3"],"Duplicate part slot keeps final DFS node and ascending part order: "+str(ordinary.parts)+" vs "+str(indexed.parts))
			check(ordinary.meshes==indexed.meshes and ordinary.meshes==["part_0","decoration","part_2"],"Mesh order matches depth-first traversal: "+str(ordinary.meshes)+" vs "+str(indexed.meshes))
			check(ordinary.picks==indexed.picks and ordinary.picks==["part_3"],"Pick surface result matches final duplicate part selection")
			ordinary.root.free();indexed.root.free()
		else:check(ordinary.reason=="Native placement physical part index is unavailable","Invalid physical part has the original explicit failure")
		source.free()
	var source:=graph();var recipe:=Recipe.new();check(recipe.capture(source),"Cancellation source captures")
	var created:=create(recipe,true);var weak:=weakref(created.root)
	var job:=PlacementJob.new();job.configure(created.root,Template.Placement.new(),"fixture",[],[],{},created.index)
	job.step(1,0);job.cancel()
	check(weak.get_ref()==null and job.status=="cancelled","Indexed pending placement cancellation releases its private graph")
	source.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Normal and indexed placement DFS order, duplicate and invalid part slots, mesh/pick lists, and cancellation; headless semantics only."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
