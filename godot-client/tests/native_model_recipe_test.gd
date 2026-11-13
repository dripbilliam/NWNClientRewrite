extends SceneTree
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
const Light=preload("res://systems/native_render/model_point_light.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Reference=preload("res://systems/native_render/model_reference.gd")
class Hub:
	extends Node
	var requests: Array=[]
	var cancellations: Array=[]
	func request_reference(owner,resource: String) -> void:requests.append([owner.get_instance_id(),resource]);owner.generation=7
	func cancel_reference(owner) -> void:cancellations.append(owner.get_instance_id())
var checks:=0
var failures: Array=[]
var report:=""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	call_deferred("run")
func original_model() -> Dictionary:
	var text:="newmodel recipe\nclassification tile\nbeginmodelgeom recipe\nnode dummy root\nparent NULL\nposition 1 2 3\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nshadow 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\nnode dummy lamp\nparent root\nposition 2 0 1\nendnode\nnode dummy sparks\nparent root\nendnode\nnode dummy link\nparent sparks\nendnode\nendmodelgeom recipe\ndonemodel recipe\n"
	var parser:=Ascii.new();var model: Dictionary=parser.parse(text)
	check(parser.failure.is_empty(),"Actual original ASCII model parses")
	model.nodes[2].features=["light"];model.nodes[2].light={"color":[0.8,0.4,0.2],"radius":6.0,"multiplier":1.5,"shadow":1.0,"ambientonly":0.0}
	model.nodes[3].features=["emitter"];model.nodes[3].emitter={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"texture":"NULL","birthrate":0.0,"lifeexp":1.0,"velocity":0.1,"sizestart":0.1,"sizeend":0.1,"alphastart":1.0,"alphaend":1.0,"xgrid":1,"ygrid":1,"colorstart":[1.0,0.5,0.2]}
	model.nodes[4].features=["reference"];model.nodes[4].reference={"model":"recipe_child","reattachable":1,"nested":[1,2]}
	model.rig_asset={"unsupported":[],"clips":[{"name":"pause","length":1.0,"emitterTracks":[{"part":3,"property":"birthrate","frames":[{"time":0.0,"value":[0.0]}]}],"emitterStorage":[]}]}
	var prepared:=Preparation.model(model);check(str(prepared.error).is_empty(),"Actual worker mesh preparation remains authoritative")
	return model
func detached_tree(model: Dictionary,pool) -> Node3D:
	var source:=Instance.new();check(source.install({"sha256":"recipe-authored-sha","resource_name":"recipe","value":model},pool),"Actual ModelInstance installs mixed original model")
	var tree:=Node3D.new();tree.name="model_root";tree.set_meta("native_scene_bounds",AABB(Vector3(-1,-2,-3),Vector3(5,6,7)))
	tree.set_meta("nested_fixture",{"rows":[{"name":"original"}],"packed":PackedFloat32Array([1,2,3])})
	for part in source.parts:
		if part.get_parent()==source:part.reparent(tree,false)
	source.parts.clear();source.meshes.clear();source.pick_surfaces.clear();source.free();return tree
func child(tree: Node,name: String):return tree.find_child(name,true,false)
func rejection_tests() -> void:
	var empty:=Recipe.new();check(empty.create()==null and not empty.failure.is_empty(),"Uncaptured recipe explicitly declines creation")
	var unnamed:=Node3D.new();var unnamed_recipe:=Recipe.new();check(unnamed_recipe.capture(unnamed),"Pristine unnamed template root captures")
	var unnamed_clone:=unnamed_recipe.create();check(unnamed_clone!=null and str(unnamed_clone.name).is_empty(),"Unnamed template root creates without assigning an invalid empty name")
	unnamed.free();unnamed_clone.free()
	var tree:=Node3D.new();var unsupported:=Camera3D.new();tree.add_child(unsupported)
	var r:=Recipe.new();check(not r.capture(tree) and r.failure.begins_with("recipe-unsupported-node"),"Unsupported node explicitly requests existing serializer fallback");tree.free()
	tree=Node3D.new();var mesh:=MeshInstance3D.new();mesh.skin=Skin.new();tree.add_child(mesh);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-managed-skeleton","Managed skin bindings explicitly fall back");tree.free()
	tree=Node3D.new();mesh=MeshInstance3D.new();var material:=StandardMaterial3D.new();material.resource_local_to_scene=true;mesh.material_override=material;tree.add_child(mesh);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-local-resource","Per-scene Resource ownership explicitly falls back");tree.free();material=null
	tree=Node3D.new();var other:=Node.new();tree.set_meta("live_owner",other);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-runtime-data-reference","Live Node metadata is never captured");tree.free();other.free()
	tree=Node3D.new();tree.set_meta("callback",func():pass);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-runtime-data-reference","Callable metadata explicitly falls back");tree.free()
	tree=Node3D.new();var cycle: Array=[];cycle.append(cycle);tree.set_meta("cycle",cycle);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-cyclic-data","Cyclic data cannot retain recursive graphs");cycle.clear();tree.free()
	tree=Node3D.new();tree.add_to_group("external");r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-configured-groups","Externally configured group state explicitly falls back");tree.free()
	tree=Node3D.new();var emitter:=Emitter.new()
	emitter.services.test=func():pass
	tree.add_child(emitter);r=Recipe.new()
	var emitter_accepted:=r.capture(tree);check(not emitter_accepted and r.failure=="recipe-active-emitter-binding","Runtime emitter services are not cloned: "+r.failure);tree.free()
	tree=Node3D.new();emitter=Emitter.new();emitter.source_path=NodePath("/root/external");tree.add_child(emitter);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-external-emitter-source","Absolute external source bindings explicitly fall back");tree.free()
	tree=Node3D.new();var reference:=Reference.new();reference.hub=Node.new();var hub=reference.hub;tree.add_child(reference);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-active-reference-binding","Already bound references explicitly fall back");tree.free();hub.free()
	tree=Node3D.new();root.add_child(tree);r=Recipe.new()
	check(not r.capture(tree) and r.failure=="recipe-detached-root-required","Already admitted source trees explicitly fall back");tree.free()
func run() -> void:
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	rejection_tests()
	var pool:=Pool.new();pool.compact_static_parts=true;var model:=original_model();var source:=detached_tree(model,pool)
	var mesh: MeshInstance3D=child(source,"part_1");var lamp=child(source,"part_2").get_child(0);var emitter=child(source,"native_emitter");var reference=child(source,"native_reference")
	check(mesh!=null and lamp.get_script()==Light and emitter.get_script()==Emitter and reference.get_script()==Reference,"Fixture exercises all five supported construction classes")
	mesh.layers=3;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;mesh.extra_cull_margin=2.0;mesh.transparency=0.2
	mesh.visibility_range_begin=3.0;mesh.visibility_range_end=80.0;mesh.custom_aabb=AABB(Vector3(-1,-1,-1),Vector3(3,3,3));mesh.set_meta("private_fixture",{"list":[1,2]})
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);emitter.original_texture=ImageTexture.create_from_image(image)
	emitter.force_reference=true;emitter.frustum_enabled=false;emitter.collision_enabled=false
	var original_texture=emitter.original_texture;var original_mesh=mesh.mesh;var original_material=mesh.material_override;var original_pick=mesh.get_meta("native_pick_geometry")
	var source_path: NodePath=emitter.source_path;var reference_paths: Array[NodePath]=emitter.reference_paths
	check(not source_path.is_empty() and reference_paths.size()==1,"Actual installer produces source and reference relative paths")
	var recipe:=Recipe.new();var captured:=recipe.capture(source);check(captured,"Detached construction graph captures without reflected properties: "+recipe.failure)
	if not captured:
		source.free();pool.clear();write_result({"failure":recipe.failure});return
	check(recipe.snapshot().nodes==9 and recipe.snapshot().shared_channel_assets==1,"Recipe retains bounded node rows and one immutable channel graph")
	check(not recipe.capture(source) and recipe.failure=="recipe-already-captured","Recipe cannot be overwritten with a different source lifetime")
	var a:=recipe.create();var b:=recipe.create();check(a!=null and b!=null,"Two private node trees create from one recipe")
	if a==null or b==null:
		if a!=null:a.free()
		if b!=null:b.free()
		source.free();pool.clear();write_result({"failure":recipe.failure});return
	var am: MeshInstance3D=child(a,"part_1");var bm: MeshInstance3D=child(b,"part_1");var ae=child(a,"native_emitter");var be=child(b,"native_emitter");var ar=child(a,"native_reference");var br=child(b,"native_reference");var al=child(a,"part_2").get_child(0);var bl=child(b,"part_2").get_child(0)
	check(a!=b and am!=bm and ae!=be and ar!=br and al!=bl,"All physical and scripted node identities are private")
	check(am.mesh==original_mesh and bm.mesh==original_mesh and am.material_override==original_material and bm.material_override==original_material,"Pool-owned immutable mesh and material Resources stay shared")
	check(am.get_meta("native_pick_geometry")==original_pick and bm.get_meta("native_pick_geometry")==original_pick and am.mesh.has_meta("native_scene_geometry"),"Original collision and picking Resources remain shared and present")
	check(am.transform==mesh.transform and am.layers==3 and am.cast_shadow==mesh.cast_shadow and am.extra_cull_margin==2.0 and am.custom_aabb==mesh.custom_aabb and is_equal_approx(am.transparency,0.2),"Known render state, transformed parts, visibility and shadow policy survive")
	check(am.get_meta("native_mesh_source")==mesh.get_meta("native_mesh_source") and am.get_meta("native_part_index")==1 and am.get_meta("native_part_name")=="body","Original part indices, names and source provenance survive")
	check(ae.original_texture==original_texture and be.original_texture==original_texture and ae.source_model_flags==2 and ae.physical_part==3 and ae.origin_resource=="recipe","Actual emitter exports retain immutable texture, flags and physical source")
	check(ae.force_reference and be.force_reference and not ae.frustum_enabled and not be.collision_enabled,"Explicit pre-admission emitter rendering policies are retained")
	check(ae.source_path==source_path and be.reference_paths==reference_paths and ae.get_node(ae.source_path)==a and ae.get_node(ae.reference_paths[0])==ar,"Source and nested reference paths resolve inside the cloned tree")
	check(is_same(ae.channel_asset,be.channel_asset) and ae.channel_asset.is_read_only() and ae.channel_asset.clips.is_read_only() and ae.channel_asset.clips[0].is_read_only(),"Large original channel input is captured once and recursively immutable")
	check(ae.channels!=be.channels and ae.rng!=be.rng and not is_same(ae.services,be.services) and not is_same(ae.parameters,be.parameters),"Fresh emitter scripts own independent channels, RNG, services and parameters")
	check(al.native_properties==lamp.native_properties and al.native_properties_revision==1 and al.native_slot==-1 and bl.native_slot==-1 and al.light_color==lamp.light_color and al.omni_range==6.0,"Fresh model lights configure authored properties without copying runtime slots")
	a.get_meta("nested_fixture").rows[0].name="changed";am.get_meta("private_fixture").list[0]=99;ae.original_properties.colorstart[0]=0.1;ar.original_header.nested[0]=9;al.native_properties.color[0]=0.1
	check(b.get_meta("nested_fixture").rows[0].name=="original" and source.get_meta("nested_fixture").rows[0].name=="original" and bm.get_meta("private_fixture").list[0]==1,"Nested metadata mutations cannot affect another clone or source")
	check(be.original_properties.colorstart[0]==1.0 and emitter.original_properties.colorstart[0]==1.0 and br.original_header.nested[0]==1 and reference.original_header.nested[0]==1 and bl.native_properties.color[0]==0.8,"Mutable emitter/reference/light authored containers stay private")
	am.position=Vector3(9,9,9);check(bm.position!=am.position and mesh.position!=am.position,"Transform edits do not affect siblings or the construction tree")
	var weak_source:=weakref(source);source.free();check(weak_source.get_ref()==null,"Recipe retains no live source-tree Node")
	var c:=recipe.create();check(c!=null and child(c,"part_1").mesh==original_mesh,"Creation still succeeds after the entire source tree is destroyed");c.free()
	var hub:=Hub.new();root.add_child(hub);var container:=Node3D.new();container.set_meta("native_reference_hub",hub);root.add_child(container)
	container.add_child(a);container.add_child(b);await process_frame
	ae.set_process(false);be.set_process(false)
	check(hub.requests.size()==2 and ar.hub==hub and br.hub==hub and ar.generation==7 and br.generation==7,"Both reference scripts enter normal hub discovery and request lifecycles")
	check(ae.failure.is_empty() and be.failure.is_empty() and ae.source==a and be.source==b and ae.surface!=null and be.surface!=null and ae.surface!=be.surface,"Both actual emitter scripts initialize independent normal particle owners")
	check(ae.channels!=be.channels and ae.channels.clips.has("pause") and be.channels.clips.has("pause") and not is_same(ae.channels.clips,be.channels.clips),"Readonly original tracks compile into private runtime clip/channel dictionaries")
	ae.parameters.velocity=99.0;check(be.parameters.velocity==0.1,"Admitted mutable particle parameters remain isolated")
	check(al.is_in_group("native_original_model_lights") and bl.is_in_group("native_original_model_lights"),"Model-light group admission remains owned by the original script")
	var diagnostic:=recipe.snapshot();check(diagnostic.created==3 and diagnostic.nodes==9 and diagnostic.capture_us>=0 and diagnostic.create_us>=0,"Recipe diagnostics contain only detached scalar counts")
	ae.retire();ar.retire();a.queue_free();await process_frame
	check(hub.cancellations.size()==1 and not be.retired and not br.retired and be.failure.is_empty(),"Retiring one cloned tree leaves the other reference and particle lifetimes live")
	be.retire();br.retire();b.queue_free();await process_frame
	check(hub.cancellations.size()==2,"Each private reference cancels exactly once")
	container.queue_free();hub.queue_free();await process_frame
	model.clear();recipe=null;pool.clear();pool=null;original_texture=null;original_mesh=null;original_material=null;original_pick=null
	write_result(diagnostic)
func write_result(diagnostic: Dictionary) -> void:
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"recipe":diagnostic,"publicConnections":0,"graphics":false,"scope":"Actual original-model parser/worker geometry/ModelInstance construction, explicit known-property recipe, two private mixed-class clones, normal local script admission/retirement and conservative fallback. No GPU timing or visual parity claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close();print("NATIVE_MODEL_RECIPE ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
