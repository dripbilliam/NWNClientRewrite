extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
var completed: Dictionary={}

func _initialize() -> void:call_deferred("run")
func read_only_graph(value: Variant,depth: int=0) -> bool:
	if depth>64:return false
	if value is Dictionary:
		if not value.is_read_only():return false
		for key in value:
			if not read_only_graph(value[key],depth+1):return false
	if value is Array:
		if not value.is_read_only():return false
		for item in value:
			if not read_only_graph(item,depth+1):return false
	return true
func run() -> void:
	var args: Dictionary={}
	for item in OS.get_cmdline_user_args():
		var pair:=item.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var result: Dictionary={"success":false,"model":"plc_hoist","checks":[],"steps":[],"max_node_us":0,"max_node_name":"","max_node_kind":"","scope":"Exact recorded original plc_hoist static model; detached ModelInstance graph, staged recipe capture with per-node attribution only. Headless component receipt, no FPS claim."}
	var catalog:=Recorded.new()
	if not catalog.mount(str(args.catalog)):result.failure=catalog.failure;write_result(args.report,result);return
	var service:=Assets.new();root.add_child(service);service.configure(catalog)
	service.completed.connect(func(id,value):completed[id]=value)
	var id:=service.request("plc_hoist",2002,"static-model");var deadline:=Time.get_ticks_msec()+30000
	while not completed.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	if not completed.has(id):result.failure="original-hoist-worker-timeout";service.close();service.free();write_result(args.report,result);return
	var bundle: Dictionary=completed[id]
	if not str(bundle.get("error","")).is_empty():result.failure=str(bundle.error);service.close();service.free();write_result(args.report,result);return
	result.source_sha256=str(bundle.sha256)
	var pool:=Pool.new();pool.compact_static_parts=false # Match the selected normal client's separate-Part layout.
	var source:=Instance.new()
	if not source.install(bundle,pool):result.failure=source.failure;source.free();pool.clear();service.close();service.free();write_result(args.report,result);return
	var tree:=Node3D.new()
	for child in source.get_children():child.reparent(tree,false)
	result.physical_parts=source.parts.size()
	source.parts.clear();source.meshes.clear();source.pick_surfaces.clear();source.free()
	var recipe:=Recipe.new()
	if not recipe.begin_capture(tree):result.failure=recipe.failure;tree.free();pool.clear();service.close();service.free();write_result(args.report,result);return
	var status:="pending"
	for step in 256:
		var step_began:=Time.get_ticks_usec()
		var progress: Dictionary=recipe.capture_step(16,3000,true)
		var step_wall_us:=Time.get_ticks_usec()-step_began
		status=str(progress.status)
		result.steps.append({"units":int(progress.units),"wall_us":step_wall_us,"maximum_node_us":int(progress.get("maximum_node_us",0)),"maximum_node_name":str(progress.get("maximum_node_name","")),"maximum_node_kind":str(progress.get("maximum_node_kind","")),"status":status})
		if int(progress.get("maximum_node_us",0))>int(result.max_node_us):
			result.max_node_us=int(progress.maximum_node_us);result.max_node_name=str(progress.maximum_node_name);result.max_node_kind=str(progress.maximum_node_kind)
		if status!="pending":break
	result.checks.append({"name":"staged-capture-completes","ok":status=="ready"})
	var ordinary:=Recipe.new();var original_ok:=ordinary.capture(tree)
	result.checks.append({"name":"ordinary-capture-completes","ok":original_ok})
	if original_ok and status=="ready":
		result.staged_capture_us=recipe.snapshot().capture_us;result.ordinary_capture_us=ordinary.snapshot().capture_us
		result.staged_nodes=recipe.snapshot().nodes;result.ordinary_nodes=ordinary.snapshot().nodes
		result.checks.append({"name":"identical-node-count","ok":result.staged_nodes==result.ordinary_nodes})
		var staged_clone=recipe.create();var ordinary_clone=ordinary.create()
		result.checks.append({"name":"both-create","ok":staged_clone!=null and ordinary_clone!=null})
		if staged_clone!=null and ordinary_clone!=null:
			var pending_pairs: Array=[[staged_clone,ordinary_clone]];var pairs:=0;var equal:=true
			while not pending_pairs.is_empty():
				var pair: Array=pending_pairs.pop_back();var left: Node3D=pair[0];var right: Node3D=pair[1];pairs+=1
				if left.get_class()!=right.get_class() or left.get_script()!=right.get_script() or left.name!=right.name or left.transform!=right.transform or left.visible!=right.visible or left.get_meta_list()!=right.get_meta_list():equal=false
				for key in left.get_meta_list():
					if left.get_meta(key)!=right.get_meta(key):equal=false
				if left is MeshInstance3D and (left.mesh!=right.mesh or left.material_override!=right.material_override or left.cast_shadow!=right.cast_shadow):equal=false
				if left.get_script()==preload("res://systems/native_render/particle_emitter.gd") and (left.channel_asset!=right.channel_asset or left.original_properties!=right.original_properties or left.source_path!=right.source_path or left.reference_paths!=right.reference_paths):equal=false
				if left.get_script()==preload("res://systems/native_render/particle_emitter.gd") and not read_only_graph(left.channel_asset):equal=false
				var left_children:=left.get_children();var right_children:=right.get_children()
				if left_children.size()!=right_children.size():equal=false;break
				for index in left_children.size():pending_pairs.append([left_children[index],right_children[index]])
			result.node_pairs=pairs;result.checks.append({"name":"staged-and-ordinary-authored-tree-equal","ok":equal and pairs==result.staged_nodes})
		if staged_clone!=null:staged_clone.free()
		if ordinary_clone!=null:ordinary_clone.free()
	var cancelled:=Recipe.new();var cancel_started:=cancelled.begin_capture(tree)
	if cancel_started:cancelled.capture_step(1,100,true);cancelled.cancel_capture()
	result.checks.append({"name":"mid-copy-cancellation-releases-state","ok":cancel_started and cancelled.snapshot().nodes==0 and cancelled.create()==null})
	result.success=result.checks.all(func(row):return bool(row.ok))
	if not result.success:result.failure=recipe.failure
	tree.free();pool.clear();service.close();service.free();completed.clear()
	write_result(args.report,result)
func write_result(path: String,result: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NWN62_HOIST_CAPTURE ",result.success," steps ",result.steps.size()," max_node_us ",result.max_node_us)
	quit(0 if result.success else 1)
