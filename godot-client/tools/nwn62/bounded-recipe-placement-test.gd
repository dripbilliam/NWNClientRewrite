extends "res://tests/native_staged_model_publication_test.gd"
const FrozenTemplate=preload("res://.cache/nwn62/bounded-placement-a/before/model_template.gd")

func make_wide_bundle()->Dictionary:
	var input:=bundle("w")
	# Retain authored emitter and reference helpers, then add enough mesh parts
	# to exceed the descendant threshold without exceeding 64 physical parts.
	while input.value.nodes.size()<64:
		var row: Dictionary=input.value.nodes[1].duplicate(true)
		row.parent=0
		row.name="wide_"+str(input.value.nodes.size())
		input.value.nodes.append(row)
	return input

func stage(template,input: Dictionary,pool)->bool:
	if not template.begin_staged_build(input,pool):return false
	for turn in 4096:
		var step: Dictionary=template.staged_build_step(8,0)
		if step.status=="ready":return true
		if step.status=="failed":return false
	return false

func placement(template,limit: int)->Dictionary:
	var pending: Dictionary={}
	var result: Dictionary={}
	var turns:=0
	var maximum_units:=0
	while turns<4096:
		result=template.create_step(pending,limit,0)
		maximum_units=maxi(maximum_units,int(result.get("units",0)))
		turns+=1
		if result.status!="pending":break
	return {"result":result,"turns":turns,"pending":pending,"maximum_units":maximum_units}

func signature(value)->Dictionary:
	var root_node: Node=value.get_child(0)
	var references: Array=[]
	if value.reference_graph!=null:
		for row in value.reference_graph.rows:
			references.append([row.name,str(root_node.get_path_to(row.object)),str(root_node.get_path_to(row.helper)) if is_instance_valid(row.helper) else "",row.header8,row.children38.map(func(child):return child.name)])
	return {"rows":node_rows(root_node),
		"parts":value.parts.map(func(node):return str(root_node.get_path_to(node))),
		"meshes":value.meshes.map(func(node):return str(root_node.get_path_to(node))),
		"picks":value.pick_surfaces.map(func(node):return str(root_node.get_path_to(node))),
		"bounds":value.get_meta("native_scene_bounds",null),
		"model":value.get_meta("native_model_name",null),
		"limitations":value.limitations,"references":references}

func run()->void:
	check(Template.configured_bounded_recipe_placement(),"Fixture explicitly selects bounded large-recipe placement")
	var input:=make_wide_bundle();var pool:=Pool.new();pool.cooperative_templates=true
	var baseline:=FrozenTemplate.new();var candidate:=Template.new()
	check(stage(baseline,input,pool) and stage(candidate,input,pool),"Frozen and candidate staged templates complete")
	check(baseline.recipe!=null and candidate.recipe!=null and candidate.physical_part_count==64 and int(candidate.recipe.snapshot().nodes)>96,"Graph exercises many descendants with at most 64 physical parts")
	var old_first:=placement(baseline,1);var new_first:=placement(candidate,1)
	check(old_first.result.status=="ready" and new_first.result.status=="ready" and new_first.turns>1,"First root uses bounded placement steps")
	check(new_first.maximum_units<=1,"First root respects one-unit publication cap")
	if old_first.result.status=="ready" and new_first.result.status=="ready":
		check(signature(old_first.result.instance)==signature(new_first.result.instance),"First root output, order and metadata equal frozen route")
	var old_clone:=placement(baseline,1);var new_clone:=placement(candidate,1)
	check(old_clone.result.status=="ready" and new_clone.result.status=="ready" and new_clone.turns>old_clone.turns,"Cloned root uses bounded indexed placement")
	check(new_clone.maximum_units<=1,"Cloned root respects one-unit publication cap")
	if old_clone.result.status=="ready" and new_clone.result.status=="ready":
		check(signature(old_clone.result.instance)==signature(new_clone.result.instance),"Clone output, order and metadata equal frozen route")
	var cancelling:=Template.new();check(stage(cancelling,input,pool),"Cancellation template builds")
	var pending: Dictionary={};var first: Dictionary=cancelling.create_step(pending,1,0)
	check(first.status=="pending" and pending.has("placement_job"),"First placement yields with detached root held by job")
	if pending.has("placement_job"):
		var weak:=weakref(pending.placement_job.root_node)
		Template.cancel_creation(pending)
		check(weak.get_ref()==null and pending.is_empty(),"Cancellation frees pending first root and clears state")
	var after_cancel:=placement(cancelling,1)
	check(after_cancel.result.status=="ready","Recipe can create a clean clone after first-root cancellation")
	for value in [old_first.result.get("instance"),new_first.result.get("instance"),old_clone.result.get("instance"),new_clone.result.get("instance"),after_cancel.result.get("instance")]:
		if is_instance_valid(value):value.free()
	pool.clear();await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"nodes":candidate.recipe.snapshot().nodes,"physical_parts":candidate.physical_part_count,"old_first_turns":old_first.turns,"new_first_turns":new_first.turns,"old_clone_turns":old_clone.turns,"new_clone_turns":new_clone.turns,"scope":"Headless frozen-source first/clone output, order, bounded yield and cancellation. No GPU or FPS measurement."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
