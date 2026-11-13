extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
class Holder extends RefCounted:
	var entries: Array=[]
var checks:=0
var failures: Array=[]
var recipe_factory
var template_factory
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func input_bundle() -> Dictionary:
	var parser:=Ascii.new()
	var model:=parser.parse("newmodel release\nclassification tile\nbeginmodelgeom release\nnode dummy root\nparent NULL\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\nendmodelgeom release\ndonemodel release\n")
	check(parser.failure.is_empty(),"Release fixture uses original parser")
	var prepared:=Preparation.model(model);check(str(prepared.error).is_empty(),"Release fixture uses worker upload preparation")
	return {"sha256":"9".repeat(64),"resource_name":"release","value":model,"textures":{}}
func recipe_release_checks() -> void:
	var source:=Node3D.new()
	for index in 4:
		var child:=Node3D.new();child.name="part_"+str(index);source.add_child(child)
	var recipe=recipe_factory.new();check(recipe.capture(source),"Detached known-node recipe captures")
	source.free()
	var owner:=Holder.new();var owned: Array=[];var taken: Array=[]
	for index in 256:
		var creation=recipe.begin_create();check(creation!=null,"Actual Creation RefCounted is allocated")
		var result: Dictionary=creation.step(1,0)
		check(result.status=="pending" and creation.nodes.size()==1,"Creation pauses with a private owned root")
		if index%4 in [1,2]:
			while creation.status=="pending":creation.step(16,0)
		var weak:=weakref(creation.nodes[0])
		match index%4:
			0:owned.append(weak) # Partial graph released by owner destruction.
			1:owned.append(weak) # Complete, untaken graph released likewise.
			2:taken.append(creation.take())
			3:creation.cancel();check(weak.get_ref()==null,"Explicit cancellation releases private root before unref")
		owner.entries.append(creation);creation=null
	owner=null # Real nested RefCounted field disposal, not an explicit cancel loop.
	for weak in owned:check(weak.get_ref()==null,"RefCounted field destruction releases partial/ready root")
	for root_node in taken:
		check(is_instance_valid(root_node),"Taken root survives Creation destruction")
		if is_instance_valid(root_node):root_node.free()
	# Release the shared recipe after all creation references have disappeared.
	recipe=null
func template_release_checks(input: Dictionary) -> void:
	var pool:=Pool.new();var weak_owned: Array=[];var placements: Array=[];var owner:=Holder.new()
	for phase in ["install","bounds","references","move","owners","capture","commit"]:
		for repetition in 8:
			var template=template_factory.new();check(template.begin_staged_build(input,pool),"Staged release fixture begins")
			var turns:=0
			while not template._build_progress.is_empty() and str(template._build_progress.phase)!=phase and turns<128:
				template.staged_build_step(1,0);turns+=1
			check(not template._build_progress.is_empty() and str(template._build_progress.phase)==phase,"Release reaches owned phase "+phase)
			if not template._build_progress.is_empty():
				for key in ["source","root"]:
					if is_instance_valid(template._build_progress[key]):weak_owned.append(weakref(template._build_progress[key]))
			owner.entries.append(template);template=null
	for index in 64:
		var template=template_factory.new();check(template.build(input,pool),"Ready template release fixture builds")
		if index%3==0:
			var instance=template.create();check(instance!=null,"First root transfers before template release");placements.append(instance)
		elif index%3==1:weak_owned.append(weakref(template._first_root))
		else:template.cancel_staged_build();weak_owned.append(weakref(template._first_root))
		owner.entries.append(template);template=null
	owner=null
	for weak in weak_owned:check(weak.get_ref()==null,"Template RefCounted destruction releases only still-owned graphs")
	for instance in placements:
		check(is_instance_valid(instance) and instance.get_child_count()==1,"Transferred placement survives template destruction")
		if is_instance_valid(instance):instance.free()
	check(pool.native_draw_captures.is_empty(),"All suspended native capture scopes retired")
	pool.clear()
func run() -> void:
	var report:="";var red:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg=="--before=true":red=true
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var prefix:="res://.cache/native-presentation-parity/root/pause-fixes-v1/asset-publication/predelete-fix-v1/before/systems/native_render/" if red else "res://systems/native_render/"
	recipe_factory=load(prefix+"native_model_recipe.gd");template_factory=load(prefix+"model_template.gd")
	recipe_release_checks();template_release_checks(input_bundle())
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"before":red,"scope":"Real nested RefCounted release of256 Creation jobs and120 partial/ready/taken/cancelled templates; no graphical, server or FPS claim. Complete process log must be clean, not just this functional receipt."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
