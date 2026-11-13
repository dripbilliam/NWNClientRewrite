extends SceneTree
const Catalog=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const Budget=preload("res://systems/native_render/model_light_budget.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func lamp(parent: Node3D,properties: Dictionary,point: Vector3) -> Node3D:
	var light:=Point.new();light.configure(properties);parent.add_child(light);light.position=point;light.force_update_transform();return light
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","catalog"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount(args.catalog),"Sealed source catalog opens read-only")
	var bytes:=catalog.get_resource("tnp_fire_001",2002)
	check(Cache.digest(bytes)=="68532632d8506b83a1f0ff3ca41d6851fe09ee87d28644918cd89e3eb8a469ca","Exact captured original yellow flame asset")
	var parser:=Actor.new();var model:=parser.parse(bytes);var properties: Dictionary={}
	for node in model.get("nodes",[]):
		if not node.get("light",{}).is_empty():properties=node.light.duplicate(true);break
	check(parser.failure.is_empty() and not properties.is_empty() and int(properties.shadow)==1,"Original flame explicitly requests a shadow-casting light")
	check(Session!=null,"Actual session entry and point-shadow argument binding compile")
	if not failures.is_empty():quit(1);return
	var world:=Node3D.new();root.add_child(world)
	var other_world:=Node3D.new();root.add_child(other_world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,3,0);camera.force_update_transform()
	var owner:=Budget.new();world.add_child(owner);owner.camera=camera;owner.set_process(false)
	owner.focus_query=func():return {"position":Vector3(0,1,0),"source":"fixture-player"}
	var lamps: Array=[]
	# This shipped light has radius2 and no separate shadow radius. Keep the
	# four count/retirement fixtures inside its actual player-support radius.
	for n in 4:lamps.append(lamp(world,properties,Vector3((n+1)*.3,1,0)))
	var outside:=lamp(other_world,properties,Vector3(0,3,0));outside.shadow_enabled=true
	owner.maximum=1;owner._profile_process(.2)
	check(owner.active==1 and owner.lights==4,"Normal one-map scene cap remains explicit and counts only its own world")
	check(lamps.filter(func(light):return light.shadow_enabled).size()==1,"Actual physical lamps follow the one-shadow setting")
	check(outside.shadow_enabled,"Another world's light owner is never overwritten by this budget")
	owner.maximum=3;owner._profile_process(.2)
	check(owner.active==3 and lamps.filter(func(light):return light.shadow_enabled).size()==3,"Explicit three-shadow comparison reaches three actual flame lamps")
	for light in lamps:check(light.native_properties==properties and light.light_color==Color(properties.color[0],properties.color[1],properties.color[2]),"Shadow selection preserves the original flame RGB/range and source properties")
	var hidden:=Node3D.new();world.add_child(hidden);lamps[0].reparent(hidden,true);hidden.hide();owner._profile_process(.2)
	check(lamps[0].visible and not lamps[0].is_visible_in_tree() and not lamps[0].shadow_enabled,"Hidden ancestor cannot occupy a shadow slot even while the child light's local visibility remains true")
	check(owner.active==3,"Other visible lights can fill the hidden lamp's released slot")
	lamps[1].apply_native_admission(false,0);owner._profile_process(.2)
	check(owner.active==2 and not lamps[1].shadow_enabled,"Native admission removes a lamp from shadow work without changing the source request")
	owner.maximum=0;owner._profile_process(.2)
	check(owner.active==0 and lamps.all(func(light):return not light.shadow_enabled),"Disabling point shadows releases all owned maps")
	check(outside.shadow_enabled,"Repeated updates never steal or disable another world's shadow ownership")
	world.free();other_world.free();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual captured flame light metadata through production point-light and scene shadow budget; explicit1/3/0 maps, hidden ancestors, independent world ownership, native admission and unchanged source illumination. Headless; no GPU shadow pixels, native stencil selection or FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
