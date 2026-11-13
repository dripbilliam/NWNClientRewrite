extends SceneTree
# Large staged recipe construction must keep the exact owned graph and
# PackedScene fallback while assigning owners during the capture walk.
const Template=preload("res://systems/native_render/model_template.gd")
const BeforeTemplate=preload("res://tests/fixtures/native_model_template_before_publication.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
class LocalPool extends Pool:
	func material(part: Dictionary,raster: Dictionary={}) -> Material:
		var value: Material=super.material(part,raster)
		if value!=null:value.resource_local_to_scene=true
		return value
var checks:=0
var failures: Array=[]
var mismatches: Array=[]
var observed_phases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)
func bundle() -> Dictionary:
	var source:="newmodel large_owner\nclassification tile\nbeginmodelgeom large_owner\nnode dummy root\nparent NULL\nposition 1 2 3\nendnode\nnode trimesh body\nparent root\nbitmap NULL\nrender 1\nshadow 1\nverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 0 0 0\nendnode\n"
	for index in 80:
		var parent:="root" if index<3 else "n"+str((index-3)/3)
		source+="node dummy n"+str(index)+"\nparent "+parent+"\nposition "+str(index%7)+" "+str(index%5)+" 0\nendnode\n"
	source+="endmodelgeom large_owner\ndonemodel large_owner\n"
	var parser:=Ascii.new();var model: Dictionary=parser.parse(source)
	check(parser.failure.is_empty(),"Large model parses")
	check(model.nodes.size()>64,"Fixture takes the large recipe branch")
	model.nodes[2].features=["emitter"]
	model.nodes[2].emitter={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"texture":"NULL","birthrate":0.0,"lifeexp":1.0,"velocity":0.1,"sizestart":0.1,"sizeend":0.1,"alphastart":1.0,"alphaend":1.0,"xgrid":1,"ygrid":1,"colorstart":[1.0,0.5,0.2]}
	model.nodes[3].features=["reference"]
	model.nodes[3].reference={"model":"child_large","reattachable":1}
	var prepared: Dictionary=Preparation.model(model)
	check(str(prepared.error).is_empty(),"Large model prepares")
	return {"sha256":"6".repeat(64),"resource_name":"large_owner","value":model,"textures":{}}
func graph_rows(placement: Node3D) -> Array:
	var root: Node=placement.get_child(0)
	var rows: Array=[];var pending: Array=[root]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		var path:=str(root.get_path_to(node))
		var owner_path:="none" if node.owner==null else str(root.get_path_to(node.owner))
		var metadata: Dictionary={}
		for key in node.get_meta_list():metadata[key]=node.get_meta(key)
		# Each independently built unnamed wrapper receives a process-global
		# generated name when attached to its Placement.
		var row:={"path":path,"class":node.get_class(),"name":"" if node==root else str(node.name),"owner":owner_path,"metadata":metadata,"transform":node.transform,"visible":node.visible,"mesh":node.mesh if node is MeshInstance3D else null}
		if node.get_script()==preload("res://systems/native_render/particle_emitter.gd"):row.emitter=[node.original_properties,node.physical_part,node.source_path,node.reference_paths,node.channel_asset]
		if node.get_script()==preload("res://systems/native_render/model_reference.gd"):row.reference=[node.original_header,node.origin_resource]
		rows.append(row)
		var children:=node.get_children()
		for child in range(children.size()-1,-1,-1):pending.append(children[child])
	return rows
func graphs_match(actual: Node3D,expected: Node3D,scope: String) -> bool:
	var left:=graph_rows(actual);var right:=graph_rows(expected)
	if left.size()!=right.size():mismatches.append({"scope":scope,"counts":[left.size(),right.size()]});return false
	for index in left.size():
		if left[index]==right[index]:continue
		var fields: Array=[]
		for key in left[index]:
			if left[index][key]!=right[index][key]:fields.append(str(key)+": "+str(left[index][key])+" / "+str(right[index][key]))
		mismatches.append({"scope":scope,"index":index,"fields":fields});return false
	return true
func staged_template(input: Dictionary,pool) -> Variant:
	var template:=Template.new()
	observed_phases.clear()
	check(template.begin_staged_build(input,pool),"Large staged template starts")
	var state: Dictionary={"status":"pending"};var turns:=0
	while state.status=="pending" and turns<5000:
		var phase:=str(template._build_progress.get("phase","ready"))
		if not observed_phases.has(phase):observed_phases.append(phase)
		state=template.staged_build_step(4,0);turns+=1
		if state.status=="failed":break
	check(state.status=="ready","Large staged template completes: "+str(state.get("reason","")))
	return template
func staged_placement(template) -> Variant:
	var pending: Dictionary={};var state: Dictionary={"status":"pending"};var turns:=0
	while state.status=="pending" and turns<5000:
		state=template.create_step(pending,4,0);turns+=1
		if state.status=="failed":break
	check(state.status=="ready","Large placement completes: "+str(state.get("reason","")))
	return state.get("instance")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(Template.configured_recipe(),"Recipe mode explicitly selected")
	var input:=bundle()
	for local in [false,true]:
		var pool: Variant=LocalPool.new() if local else Pool.new()
		var oracle:=BeforeTemplate.new()
		check(oracle.build(input,pool),"Frozen packed oracle builds")
		var template: Variant=staged_template(input,pool)
		check(template.recipe==null if local else template.recipe!=null,"Expected large template mode")
		check(observed_phases.has("fallback-owners") if local else not observed_phases.has("owners"),"Large success avoids owner pass; fallback restores it")
		for clone_index in 2:
			var actual: Variant=staged_placement(template)
			var expected: Variant=oracle.create()
			if actual!=null and expected!=null:
				check(graphs_match(actual,expected,"local="+str(local)+", clone="+str(clone_index)),"Large graph, owner, names, metadata, resources and transforms match packed oracle: local="+str(local)+", clone="+str(clone_index))
				check(actual.parts.size()==expected.parts.size() and actual.meshes.size()==expected.meshes.size(),"Large placement part and mesh counts match")
				actual.retire();expected.retire()
			else:check(false,"Both large placements are available")
		pool.clear()
	await process_frame
	var result:={"checks":checks,"failures":failures,"mismatches":mismatches,"passed":failures.is_empty(),"scope":"Large detached staged recipe and local-resource PackedScene fallback versus frozen packed construction; no timings or FPS"}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
