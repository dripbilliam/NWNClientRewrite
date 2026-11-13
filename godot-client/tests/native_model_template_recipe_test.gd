extends SceneTree
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
class LocalResourcePool:
	extends Pool
	func material(part: Dictionary,raster: Dictionary={}) -> Material:
		var value: Material=super.material(part,raster)
		if value!=null:value.resource_local_to_scene=true
		return value
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func bundle() -> Dictionary:
	var text:="newmodel template_recipe\nsetsupermodel template_recipe null\nclassification tile\nbeginmodelgeom template_recipe\nnode dummy root\nparent NULL\nposition 1 2 3\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nshadow 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\nendmodelgeom template_recipe\ndonemodel template_recipe\n"
	var parser:=Ascii.new();var model:=parser.parse(text);check(parser.failure.is_empty(),"Actual original model parser constructs the integration fixture")
	var prepared:=Preparation.model(model);check(str(prepared.error).is_empty(),"Actual native worker geometry preparation succeeds")
	return {"sha256":"7".repeat(64),"resource_name":"template_recipe","value":model,"textures":{}}
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var input:=bundle();var pool:=Pool.new();var before:=Template.construction_totals();var template:=Template.new()
	check(template.build(input,pool),"Original ResourcePool/ModelInstance template build succeeds")
	var state:=template.construction_snapshot();var requested:=Template.configured_recipe()
	check(state.mode==("known-node-recipe" if requested else "packed-scene") and state.ready,"Actual template mode reflects the selected successful constructor")
	check(template.recipe_capture_successes==(1 if requested else 0) and template.packed_template_creations==(0 if requested else 1),"Successful recipe path skips PackedScene packing, ordinary default retains it")
	var original: Node3D=template._first_root;var first=template.create();check(first!=null and first.get_child(0)==original and template.first_instance_reuses==1,"First placement still takes the untouched original root exactly once")
	var authored_transform: Transform3D=first.meshes[0].transform;var shared_mesh: Mesh=first.meshes[0].mesh;var shared_material: Material=first.meshes[0].material_override;var shared_pick: Resource=shared_mesh.get_meta("native_pick_geometry")
	first.meshes[0].position.x+=99;first.meshes[0].set_meta("private_mutation",true);first.meshes[0].material_override=StandardMaterial3D.new()
	var second=template.create();check(second!=null and second!=first and second.get_child(0)!=original,"Subsequent placement owns a different physical root")
	check(second.meshes[0].transform==authored_transform and not second.meshes[0].has_meta("private_mutation") and second.meshes[0].material_override==shared_material,"Later creation uses immutable pre-admission state despite first-placement mutation")
	check(second.meshes[0].mesh==shared_mesh and shared_mesh.get_meta("native_pick_geometry")==shared_pick,"Mesh, material and picking resources remain shared through existing pool ownership")
	check(first.parts.size()==second.parts.size() and first.meshes.size()==second.meshes.size() and first.get_meta("native_scene_bounds")==second.get_meta("native_scene_bounds"),"Part collections, mesh inventory and original bounds remain available")
	check(template.recipe_instance_creations==(1 if requested else 0) and template.packed_instance_creations==(0 if requested else 1),"Actual clone counters distinguish recipe from PackedScene creation")
	var local_pool:=LocalResourcePool.new();var fallback:=Template.new();check(fallback.build(input,local_pool),"Unsupported recipe-owned Resource still builds through faithful PackedScene fallback")
	var fallback_state:=fallback.construction_snapshot();check(fallback_state.mode=="packed-scene" and fallback.packed_template_creations==1,"Fallback always publishes an actual PackedScene")
	check(fallback.recipe_fallback_reason==("recipe-local-resource" if requested else ""),"Fallback reason is explicit only when recipe capture was attempted")
	var fallback_first=fallback.create();var fallback_second=fallback.create();check(fallback_first!=null and fallback_second!=null and fallback.packed_instance_creations==1,"Fallback first reuse and ordinary later instantiate remain usable")
	check(fallback_first.meshes[0].material_override!=fallback_second.meshes[0].material_override,"Fallback retains local-to-scene Resource cloning semantics")
	var counts:=Template.construction_totals();check(counts.templates_built-before.templates_built==2 and counts.first_root_reuses-before.first_root_reuses==2,"Process counters measure actual successful builds and first-root reuse")
	check(counts.recipe_templates_built-before.recipe_templates_built==(1 if requested else 0) and counts.recipe_clones-before.recipe_clones==(1 if requested else 0),"Actual recipe build/clone process counters cannot be satisfied by a flag alone")
	check(counts.recipe_capture_fallbacks-before.recipe_capture_fallbacks==(1 if requested else 0),"Process counters expose unsupported capture fallbacks")
	var detached_counts:=Template.construction_totals();detached_counts.recipe_templates_built=-999;check(Template.construction_totals().recipe_templates_built>=0,"Diagnostics are detached from live counters")
	for instance in [first,second,fallback_first,fallback_second]:instance.retire()
	await process_frame
	var unused:=Template.new();check(unused.build(input,pool),"Unused-template ownership fixture builds")
	var weak:=weakref(unused._first_root);unused=null;check(weak.get_ref()==null,"Dropping an unused template releases its never-admitted original root")
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"requested_recipe":requested,"template":state,"fallback":fallback_state,"totals":Template.construction_totals(),"scope":"Actual original parser, worker geometry, pool/model/template integration; first-root ownership, immutable subsequent clones, explicit PackedScene fallback and counters. Native headless, no GPU/FPS claim."},"\t")+"\n");output.close();print("NATIVE_MODEL_TEMPLATE_RECIPE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
