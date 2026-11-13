extends SceneTree
# Self-contained private small-template recipe fixture; no renderer/FPS.
const Template=preload("res://systems/native_render/model_template.gd")
const Candidate=preload("res://.cache/nwn62/small-recipe-b/systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
class LocalPool extends Pool:
	func material(part: Dictionary,raster: Dictionary={}) -> Material:
		var value: Material=super.material(part,raster)
		if value!=null:value.resource_local_to_scene=true
		return value
var checks:=0
var failures: Array[String]=[]
var rows: Array=[]
var differences: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func bundle(sha: String) -> Dictionary:
	var source: String="newmodel staged\nclassification tile\nbeginmodelgeom staged\nnode dummy root\nparent NULL\nposition 1 2 3\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nshadow 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\nnode dummy sparks\nparent root\nendnode\nnode dummy first_link\nparent sparks\nendnode\nnode dummy second_link\nparent sparks\nendnode\nendmodelgeom staged\ndonemodel staged\n"
	var parser: RefCounted=Ascii.new()
	var model: Dictionary=parser.parse(source)
	check(parser.failure.is_empty(),"Original parser builds authored graph")
	model.nodes[2].features=["emitter"]
	model.nodes[2].emitter={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"texture":"NULL","birthrate":0.0,"lifeexp":1.0,"velocity":0.1,"sizestart":0.1,"sizeend":0.1,"alphastart":1.0,"alphaend":1.0,"xgrid":1,"ygrid":1,"colorstart":[1.0,0.5,0.2]}
	for index in [3,4]:
		model.nodes[index].reference={"model":"child_"+str(index),"reattachable":1}
		model.nodes[index].features=["reference"]
	var prepared: Dictionary=Preparation.model(model)
	check(str(prepared.error).is_empty(),"Original worker geometry preparation succeeds")
	return {"sha256":sha.repeat(64),"resource_name":"staged","value":model,"textures":{}}
func normalized_path(value: String) -> String:
	var result: Array=[]
	for component in value.split("/"):
		if component.begins_with("@"):
			var pieces: PackedStringArray=component.split("@")
			if pieces.size()>=3:component="@"+pieces[1]+"@#"
		result.append(component)
	return "/".join(result)
func material_state(material: Material) -> Dictionary:
	if material==null:return {}
	var state: Dictionary={"class":material.get_class(),"local":material.resource_local_to_scene}
	if material is StandardMaterial3D:
		state.albedo=material.albedo_color;state.transparency=material.transparency;state.shading=material.shading_mode
	elif material is ShaderMaterial:
		state.shader=material.shader
	return state
func node_rows(root_node: Node) -> Array:
	var result: Array=[]
	var pending: Array=[]
	for child in root_node.get_children():pending.append(child)
	while not pending.is_empty():
		var node: Node=pending.pop_front()
		var metadata: Dictionary={}
		for key in node.get_meta_list():metadata[key]=node.get_meta(key)
		var row: Dictionary={"path":normalized_path(str(root_node.get_path_to(node))),"class":node.get_class(),"transform":node.transform,"visible":node.visible,"metadata":metadata}
		if node is MeshInstance3D:
			row.mesh=node.mesh;row.material=material_state(node.material_override);row.shadow=node.cast_shadow;row.layers=node.layers
		if node is OmniLight3D:row.light=[node.light_color,node.light_energy,node.omni_range,node.shadow_enabled]
		if node.get_script()==preload("res://systems/native_render/particle_emitter.gd"):row.emitter=[node.original_properties,node.physical_part,node.source_path,node.reference_paths,node.channel_asset]
		if node.get_script()==preload("res://systems/native_render/model_reference.gd"):row.reference=[node.original_header,node.origin_resource]
		result.append(row);pending.append_array(node.get_children())
	return result
func rows_equal(a: Array,b: Array,label: String) -> bool:
	if a==b:return true
	for index in mini(a.size(),b.size()):
		for key in a[index]:
			if a[index][key]!=b[index].get(key):
				if differences.size()<12:differences.append({"label":label,"index":index,"key":key,"left":str(a[index][key]),"right":str(b[index].get(key)),"left_class":str(type_string(typeof(a[index][key]))),"right_class":str(type_string(typeof(b[index].get(key))))})
	return false
func build_staged(template: RefCounted,input: Dictionary,pool: RefCounted,tag: String) -> Dictionary:
	var began:=Time.get_ticks_usec();var peak:=0;var steps:=0;var status:="pending"
	check(template.begin_staged_build(input,pool),tag+" begin")
	while status=="pending" and steps<512:
		var unit_began:=Time.get_ticks_usec()
		var step: Dictionary=template.staged_build_step(8,3000)
		peak=maxi(peak,Time.get_ticks_usec()-unit_began);status=str(step.status);steps+=1
	check(status=="ready",tag+" ready: "+template.failure)
	return {"status":status,"steps":steps,"max_step_us":peak,"active_us":Time.get_ticks_usec()-began,"mode":template.construction_snapshot().mode,"fallback":template.recipe_fallback_reason}
func compare_case(input: Dictionary,pool: RefCounted,tag: String,expect_recipe: bool) -> void:
	var packed: RefCounted=Template.new();var recipe: RefCounted=Candidate.new()
	var baseline: Dictionary=build_staged(packed,input,pool,tag+" packed")
	var selected: Dictionary=build_staged(recipe,input,pool,tag+" recipe")
	check(packed.scene!=null and packed.recipe==null,tag+" control stayed packed")
	check((recipe.recipe!=null)==expect_recipe and (recipe.scene!=null)==(not expect_recipe),tag+" selected expected mode")
	var packed_first: Node3D=packed.create();var packed_second: Node3D=packed.create()
	var recipe_first: Node3D=recipe.create();var recipe_second: Node3D=recipe.create()
	check(packed_first!=null and packed_second!=null and recipe_first!=null and recipe_second!=null,tag+" all placements created")
	if packed_first!=null and packed_second!=null and recipe_first!=null and recipe_second!=null:
		check(node_rows(packed_first.get_child(0)).map(func(row):return row.path)==node_rows(packed_second.get_child(0)).map(func(row):return row.path),tag+" packed clone paths stable")
		check(node_rows(recipe_first.get_child(0)).map(func(row):return row.path)==node_rows(recipe_second.get_child(0)).map(func(row):return row.path),tag+" candidate clone paths stable")
		check(rows_equal(node_rows(packed_first.get_child(0)),node_rows(recipe_first.get_child(0)),tag+" first"),tag+" first graph exact")
		check(rows_equal(node_rows(packed_second.get_child(0)),node_rows(recipe_second.get_child(0)),tag+" clone"),tag+" clone graph exact")
		check(recipe.first_instance_reuses==1 and packed.first_instance_reuses==1,tag+" original root reused once")
		check(packed_first.parts.size()==recipe_first.parts.size() and packed_first.meshes.size()==recipe_first.meshes.size() and packed_first.pick_surfaces.size()==recipe_first.pick_surfaces.size(),tag+" inventory exact")
		packed_first.parts[0].set_meta("private_edit",{"values":[99]});recipe_first.parts[0].set_meta("private_edit",{"values":[99]})
		check(not packed_second.parts[0].has_meta("private_edit") and not recipe_second.parts[0].has_meta("private_edit"),tag+" clone metadata private")
		if not recipe_first.meshes.is_empty():
			var source_material: Material=recipe_first.meshes[0].material_override
			var clone_material: Material=recipe_second.meshes[0].material_override
			check((source_material==clone_material)==(packed_first.meshes[0].material_override==packed_second.meshes[0].material_override),tag+" material sharing matches packed")
			if tag=="local-material":check(source_material!=clone_material,tag+" local material private")
	if tag=="installed-original-tile":check(recipe.recipe_fallback_reason=="recipe-autogenerated-node-name",tag+" internal light names require PackedScene fallback")
	rows.append({"case":tag,"packed":baseline,"candidate":selected,"recipe_captures":recipe.recipe_capture_successes,"packed_fallbacks":recipe.packed_template_creations})
	for item in [packed_first,packed_second,recipe_first,recipe_second]:if item!=null:item.free()
	packed=null;recipe=null;pool.clear()
func run() -> void:
	check(OS.get_cmdline_user_args().has("--model-template=recipe-small"),"Private recipe selector is active")
	var pool: RefCounted=Pool.new();pool.cooperative_templates=true
	compare_case(bundle("r"),pool,"authored-reference-emitter",true)
	var local_pool: RefCounted=LocalPool.new();local_pool.cooperative_templates=true
	compare_case(bundle("s"),local_pool,"local-material",false)
	var original_file: FileAccess=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ)
	if original_file!=null:
		var original: Dictionary=original_file.get_var(false);original_file.close()
		var original_pool: RefCounted=Pool.new();original_pool.cooperative_templates=true
		compare_case(original,original_pool,"installed-original-tile",false)
	var cancel_pool: RefCounted=Pool.new();cancel_pool.cooperative_templates=true
	var pending: RefCounted=Candidate.new();check(pending.begin_staged_build(bundle("t"),cancel_pool),"Cancellation starts candidate")
	var pending_steps:=0
	while pending_steps<256 and not pending._build_progress.is_empty() and str(pending._build_progress.phase)!="capture":
		pending.staged_build_step(1,0);pending_steps+=1
	check(not pending._build_progress.is_empty() and str(pending._build_progress.phase)=="capture","Cancellation reaches capture")
	var weak: WeakRef=weakref(pending._build_progress.root)
	pending.cancel_staged_build()
	check(pending._build_progress.is_empty() and pending.scene==null and pending.recipe==null and weak.get_ref()==null,"Cancellation releases root and publishes nothing")
	cancel_pool.clear()
	var result: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"differences":differences,"rows":rows,"scope":"Private opt-in small recipe vs packed graph/root/material/reference/clone and cancellation. Detached component only; no FPS/live entry."}
	var report:=""
	for arg in OS.get_cmdline_user_args():if arg.begins_with("--report="):report=arg.substr(9)
	if not report.is_empty():
		var file: FileAccess=FileAccess.open(report,FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"  "));file.close()
	print("NWN62_SMALL_RECIPE "+JSON.stringify({"success":result.success,"checks":checks,"failures":failures,"rows":rows}))
	quit(0 if result.success else 1)
