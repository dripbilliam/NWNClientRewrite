extends SceneTree
# Original installed models that produced the observed PackedScene.pack tails.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Service=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const PackedTemplate=preload("res://systems/native_render/model_template.gd")
const RecipeTemplate=preload("res://.cache/nwn62/small-recipe-b/systems/native_render/model_template.gd")
var rows: Array=[]
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func normalized_path(path: String) -> String:
	var items: Array=[]
	for component in path.split("/"):
		if component.begins_with("@"):
			var pieces: PackedStringArray=component.split("@")
			if pieces.size()>=3:component="@"+pieces[1]+"@#"
		items.append(component)
	return "/".join(items)
func material_state(material: Material) -> Dictionary:
	if material==null:return {}
	var row: Dictionary={"class":material.get_class(),"local":material.resource_local_to_scene}
	if material is StandardMaterial3D:
		row.albedo=material.albedo_color;row.transparency=material.transparency;row.shading=material.shading_mode;row.textured=material.albedo_texture!=null
	if material is ShaderMaterial:row.shader=material.shader.resource_path if material.shader!=null else ""
	return row
func graph_rows(root_node: Node) -> Array:
	var result: Array=[];var pending: Array=root_node.get_children()
	while not pending.is_empty():
		var node: Node=pending.pop_front();var metadata: Dictionary={}
		for key in node.get_meta_list():metadata[key]=node.get_meta(key)
		var row: Dictionary={"path":normalized_path(str(root_node.get_path_to(node))),"class":node.get_class(),"transform":node.transform,"visible":node.visible,"metadata":metadata,"script":str(node.get_script().resource_path) if node.get_script()!=null else ""}
		if node is MeshInstance3D:row.mesh=[node.mesh.get_surface_count(),node.mesh.get_aabb()] if node.mesh!=null else [];row.material=material_state(node.material_override);row.shadow=node.cast_shadow;row.layers=node.layers
		if node is OmniLight3D:row.light=[node.light_color,node.light_energy,node.omni_range,node.shadow_enabled]
		result.append(row);pending.append_array(node.get_children())
	return result
func parity(control: RefCounted,candidate: RefCounted,name: String) -> Dictionary:
	var a: Node3D=control.create();var a2: Node3D=control.create()
	var b: Node3D=candidate.create();var b2: Node3D=candidate.create()
	check(a!=null and a2!=null and b!=null and b2!=null,name+" placements created")
	if a==null or a2==null or b==null or b2==null:return {}
	var ar: Array=graph_rows(a.get_child(0));var ar2: Array=graph_rows(a2.get_child(0))
	var br: Array=graph_rows(b.get_child(0));var br2: Array=graph_rows(b2.get_child(0))
	check(ar==br,name+" first graph")
	check(ar2==br2,name+" clone graph")
	check(ar.map(func(row):return row.path)==ar2.map(func(row):return row.path),name+" packed paths stable")
	check(br.map(func(row):return row.path)==br2.map(func(row):return row.path),name+" candidate paths stable")
	check(control.first_instance_reuses==1 and candidate.first_instance_reuses==1,name+" first root reused")
	var result: Dictionary={"packed_rows":ar.size(),"candidate_rows":br.size(),"first_equal":ar==br,"clone_equal":ar2==br2,"packed_paths_stable":ar.map(func(row):return row.path)==ar2.map(func(row):return row.path),"candidate_paths_stable":br.map(func(row):return row.path)==br2.map(func(row):return row.path)}
	for item in [a,a2,b,b2]:item.free()
	return result
func node_paths(root_node: Node) -> Array:
	var result: Array=[];var pending: Array=[]
	for child in root_node.get_children():pending.append(child)
	while not pending.is_empty():
		var node: Node=pending.pop_front()
		result.append({"path":str(root_node.get_path_to(node)),"class":node.get_class(),"script":str(node.get_script().resource_path) if node.get_script()!=null else ""})
		pending.append_array(node.get_children())
	return result
func light_subscene_probe(source_root: Node) -> Dictionary:
	var queue: Array=source_root.get_children()
	while not queue.is_empty():
		var node: Node=queue.pop_front()
		if str(node.name).begins_with("@"):
			var scene: PackedScene=PackedScene.new()
			var began:=Time.get_ticks_usec();var error:=scene.pack(node);var pack_us:=Time.get_ticks_usec()-began
			if error!=OK:return {"error":error,"source_name":str(node.name),"pack_us":pack_us}
			var clone: Node=scene.instantiate();var before:=str(clone.name)
			var parent: Node3D=Node3D.new();parent.add_child(clone)
			var after:=str(clone.name);parent.free()
			return {"source_name":str(node.name),"before_add":before,"after_add":after,"pack_us":pack_us,"exact":before==str(node.name) and after==str(node.name)}
		queue.append_array(node.get_children())
	return {"none":true}
func build(template: RefCounted,bundle: Dictionary,pool: RefCounted) -> Dictionary:
	var status:="pending";var steps:=0;var max_us:=0;var began:=Time.get_ticks_usec()
	if not template.begin_staged_build(bundle,pool):return {"error":template.failure}
	while status=="pending" and steps<1024:
		var step_began:=Time.get_ticks_usec()
		var step: Dictionary=template.staged_build_step(8,3000)
		max_us=maxi(max_us,Time.get_ticks_usec()-step_began)
		status=str(step.status);steps+=1
	return {"status":status,"steps":steps,"active_us":Time.get_ticks_usec()-began,"max_step_us":max_us,"mode":template.construction_snapshot().mode,"fallback":template.recipe_fallback_reason,"parts":template.physical_part_count,"pack_us":int(template.staged_diagnostic_phase_max_us.get("packed_scene_pack_us",0)),"reason":template.failure}
func run() -> void:
	var install:="";var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.substr(10)
		if arg.begins_with("--report="):report=arg.substr(9)
	var catalog: RefCounted=Catalog.new()
	if not catalog.mount_install(install):failures.append("catalog: "+catalog.failure)
	var service: Node=Service.new()
	root.add_child(service)
	for name in ["ttu01_w07_01","ttu01_v06_01","gi_scrl"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002)
		if bytes.is_empty():failures.append(name+" source: "+catalog.failure);continue
		var decoded: Dictionary=service.actor_data(catalog,name,bytes,"",[])
		if not str(decoded.get("error","")).is_empty():failures.append(name+" decode: "+str(decoded.error));continue
		var source_sha: String=Cache.digest(bytes)
		var texture_slots: Dictionary={}
		var texture_sources: Array=[]
		for part in decoded.value.nodes:
			if not part.mesh.get("render",false):continue
			for texture_name in part.mesh.get("textures",[]):
				var key:=str(texture_name).to_lower()
				if key in ["","null"] or texture_slots.has(key):continue
				var location: Dictionary=catalog.raster_location(key)
				if location.is_empty():texture_slots[key]={};texture_sources.append({"name":key,"missing":true});continue
				var raster_bytes: PackedByteArray=catalog.get_resource(key,int(location.type))
				var raster: Dictionary=service.decode(raster_bytes,int(location.type),"raster","")
				if not str(raster.get("error","")).is_empty():failures.append(name+" raster "+key+": "+str(raster.error));continue
				texture_slots[key]=raster;texture_sources.append({"name":key,"type":int(location.type),"source_sha256":Cache.digest(raster_bytes)})
		var bundle: Dictionary={"sha256":source_sha,"resource_name":name,"value":decoded.value,"textures":texture_slots}
		var control_pool: RefCounted=Pool.new();control_pool.cooperative_templates=true
		# Both placement modes in one session resolve the same immutable pool resources.
		var candidate_pool: RefCounted=control_pool
		var control: RefCounted=PackedTemplate.new();var candidate: RefCounted=RecipeTemplate.new()
		var a: Dictionary=build(control,bundle,control_pool);var b: Dictionary=build(candidate,bundle,candidate_pool)
		var direct_probe: Dictionary={}
		if a.get("status")=="ready" and control.scene!=null and is_instance_valid(control._first_root):
			var packed_clone: Node=control.scene.instantiate()
			var duplicate_clone: Node=control._first_root.duplicate()
			var packed_paths: Array=node_paths(packed_clone)
			var duplicate_paths: Array=node_paths(duplicate_clone)
			direct_probe={"packed_count":packed_paths.size(),"duplicate_count":duplicate_paths.size(),"paths_equal":packed_paths==duplicate_paths,"first_path_difference":{}}
			for index in mini(packed_paths.size(),duplicate_paths.size()):
				if packed_paths[index]!=duplicate_paths[index]:direct_probe.first_path_difference={"packed":packed_paths[index],"duplicate":duplicate_paths[index]};break
			packed_clone.free();duplicate_clone.free()
		var light_probe: Dictionary=light_subscene_probe(control._first_root) if a.get("status")=="ready" else {}
		var parity_result: Dictionary=parity(control,candidate,name) if a.get("status")=="ready" and b.get("status")=="ready" else {}
		rows.append({"model":name,"source_sha256":source_sha,"nodes":decoded.value.nodes.size(),"textures":texture_sources,"control":a,"candidate":b,"direct_probe":direct_probe,"light_subscene_probe":light_probe,"parity":parity_result})
		if a.get("status")!="ready" or b.get("status")!="ready":failures.append(name+" build")
		control.cancel_staged_build();candidate.cancel_staged_build();control_pool.clear()
	service.queue_free()
	var result: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"scope":"Installed original tail-model first/clone structural, transform, light, material-descriptor and path parity with decoded original rasters; no GPU pixels, FPS or live scene."}
	var file: FileAccess=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  "));file.close()
	print("NWN62_TAIL_COVERAGE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
