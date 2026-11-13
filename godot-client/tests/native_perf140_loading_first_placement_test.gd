extends SceneTree
const Template=preload("res://systems/native_render/model_template.gd")
const Before=preload("res://tests/fixtures/native_perf140_loading_model_template_before.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
class Hub:
	extends Node
	var requests: Dictionary={}
	func request_reference(owner: Node,resource: String) -> void:requests[owner.get_instance_id()]=resource
	func cancel_reference(owner: Node) -> void:requests.erase(owner.get_instance_id())
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	call_deferred("run")
func bundle(name: String,helpers: bool=false) -> Dictionary:
	var text:="newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n"
	var parser:=ActorData.new();var model:=parser.parse(text.to_utf8_buffer())
	check(parser.failure.is_empty(),"Authored source fixture parses")
	if helpers:
		for index in 4:
			var row: Dictionary=model.nodes[0].duplicate(true);row.name="helper_"+str(index);row.parent=0;row.mesh={};row.features=[];row.position=[float(index),0.25,0.5];row.scale=1.0;row.flags=0
			if index==0:row.features=["light"];row.light={"color":[1.0,0.5,0.25],"radius":5.0,"shadow":1.0,"multiplier":0.8}
			elif index==1:row.features=["emitter"];row.emitter={"texture":"","render":"Normal","update":"Fountain","blend":"Normal","birthrate":0.0,"lifeexp":1.0,"flags":0,"xgrid":1,"ygrid":1}
			elif index==2:row.parent=2;row.reference={"model":"fixture_reference","reattachable":1}
			elif index==3:row.mesh=model.nodes[0].mesh.duplicate(true);row.mesh.render=false
			model.nodes.append(row)
	return {"value":model,"resource_name":name,"sha256":Cache.digest(text.to_utf8_buffer())+str(helpers),"textures":{},"emitter_textures":{},"error":"","animation_sources":[]}
func view(placement) -> Dictionary:
	var rows: Array=[]
	for part in placement.parts:
		var helpers: Array=[]
		for child in part.get_children():
			if child is OmniLight3D:helpers.append({"kind":"light","color":child.light_color,"range":child.omni_range,"energy":child.light_energy,"shadow":child.shadow_enabled,"properties":child.get_meta("native_model_light_properties",{})})
			elif child.name=="native_reference":helpers.append({"kind":"reference","header":child.original_header,"origin":child.origin_resource})
			elif child.name=="native_emitter":helpers.append({"kind":"emitter","properties":child.original_properties,"channels":child.channel_asset,"physical":child.physical_part,"source":child.source_path,"references":child.reference_paths,"origin":child.origin_resource,"flags":child.source_model_flags})
		rows.append({"name":part.name,"transform":part.transform,"index":part.get_meta("native_part_index"),"parent":part.get_meta("native_part_parent"),"part_name":part.get_meta("native_part_name"),"area":part.get_meta("native_part_area") if part.has_meta("native_part_area") else null,"helpers":helpers})
	var meshes: Array=[]
	for mesh in placement.meshes:meshes.append({"name":mesh.name,"transform":mesh.transform,"mesh":mesh.mesh,"material":mesh.material_override,"shadow":mesh.cast_shadow,"visible":mesh.visible,"pick":mesh.get_meta("native_pick_geometry",null)})
	var picks: Array=[]
	for part in placement.pick_surfaces:picks.append({"index":part.get_meta("native_part_index"),"geometry":part.get_meta("native_pick_geometry")})
	return {"rows":rows,"meshes":meshes,"picks":picks,"bounds":placement.get_meta("native_scene_bounds",null),"limitations":placement.limitations,"reference_rows":placement.reference_graph.rows.size() if placement.reference_graph!=null else 0}
func retained_root(template) -> Node:
	for property in template.get_property_list():
		if property.name=="_first_root":return template.get("_first_root")
	return null
func pair_checks(helpers: bool,compact: bool) -> void:
	var pool:=Pool.new();pool.compact_static_parts=compact;pool.use_prepared_geometry=false;pool.picking=true
	var value:=bundle("fixture_template",helpers);var before:=Before.new();var target:=Template.new()
	check(before.build(value,pool),"Original template builds")
	check(target.build(value,pool),"Target template builds")
	var packed_nodes:=target.scene.get_state().get_node_count()
	check(packed_nodes==before.scene.get_state().get_node_count(),"Packed immutable topology is unchanged")
	var initial:=retained_root(target);var first_id:=initial.get_instance_id() if initial!=null else 0
	check((initial!=null)==(args.get("expect-first","false")=="true"),"Only candidate retains detached construction hierarchy")
	if initial!=null:check(not initial.is_inside_tree() and initial.get_parent()==null,"Retained hierarchy has never entered a scene")
	var original=before.create();var a=target.create();var b=target.create()
	check(original!=null and a!=null and b!=null,"First and subsequent placements are available")
	check(view(a)==view(original),"First placement retains original transforms, source properties, metadata and exact immutable resources")
	check(view(b)==view(original),"Packed subsequent placement retains original view")
	check(retained_root(target)==null,"First placement consumes retained ownership exactly once")
	if first_id!=0:
		check(a.get_child(0).get_instance_id()==first_id,"First placement uses the actual already-constructed tree")
		check(target.first_instance_reuses==1 and target.packed_instance_creations==1,"Subsequent creation takes the ordinary PackedScene route")
	check(a.parts[0]!=b.parts[0] and a.meshes[0].mesh==b.meshes[0].mesh and a.meshes[0].material_override==b.meshes[0].material_override,"Physical instances remain private while immutable GPU resources are shared")
	a.parts[0].position=Vector3(9,8,7)
	var c=target.create();check(view(b)==view(original) and view(c)==view(original),"Mutating consumed first placement cannot mutate packed rest state or later instances")
	# Helpers must register/initialize under their real SceneTree ownership too.
	var host:=Node3D.new();var hub:=Hub.new();host.set_meta("native_reference_hub",hub);root.add_child(host);host.add_child(hub)
	var camera:=Camera3D.new();host.add_child(camera);camera.current=true;camera.position=Vector3(0,5,10)
	host.add_child(original);host.add_child(b);host.add_child(c)
	check(view(b)==view(original) and view(c)==view(original),"Tree entry preserves ordinary light/reference/emitter export state")
	if helpers:
		check(hub.requests.size()==3,"Every independently instantiated reference requests its own binding")
		for placement in [original,b,c]:
			var emitter=placement.parts[2].get_node("native_emitter")
			check(emitter.failure.is_empty() and emitter.source==placement.get_child(0),"Emitter keeps its own source path and initializes correctly")
	# First placement is distinct after its intentional mutation; attach it too.
	host.add_child(a)
	if helpers:check(hub.requests.size()==4,"Consumed first reference registers normally when admitted")
	for placement in [original,a,b,c]:placement.free()
	check(hub.requests.is_empty(),"Reference retirement cancels all private bindings")
	before=null;target=null;host.free();pool.clear()
func lifetime_checks() -> void:
	var pool:=Pool.new();pool.use_prepared_geometry=false;var source:=bundle("unused_template")
	var unused:=Template.new();check(unused.build(source,pool),"Unconsumed template builds")
	var prepared:=retained_root(unused);var observed: WeakRef=weakref(prepared) if prepared!=null else null;prepared=null
	unused=null
	check(observed==null or observed.get_ref()==null,"Template destruction releases an unused retained hierarchy")
	pool.maximum_templates=1
	var kept=pool.model_template(source);var live=kept.create();var root_id: int=live.get_child(0).get_instance_id();kept=null
	pool.model_template(bundle("replacement_template"));pool.clear()
	check(is_instance_valid(live.get_child(0)) and live.get_child(0).get_instance_id()==root_id,"Eviction and explicit pool clear do not destroy consumed live placements")
	live.free();pool.clear()
func run() -> void:
	for helpers in [false,true]:
		for compact in [false,true]:pair_checks(helpers,compact)
	lifetime_checks()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_first":args.get("expect-first","false")=="true","scope":"Headless first-placement topology/export/resource/ownership/retirement equivalence; no pixels, server connection, GPU or FPS acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
