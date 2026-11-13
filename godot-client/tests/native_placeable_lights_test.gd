extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Captured=preload("res://systems/native_data/recorded_catalog.gd")
const Lights=preload("res://systems/native_render/placeable_lights.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const Budget=preload("res://systems/native_render/model_light_budget.gd")
const Session=preload("res://native_session_world.gd")
class TestWorld:
	extends Node3D
	signal instance_ready(id: int,source: Dictionary,instance)
	signal instance_removed(id: int)
	var area_id:=2147564222
	var instances: Dictionary={}
class Body:
	extends Node3D
	var parts: Array=[]
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void:call_deferred("run")
func settle(owner,minimum: int) -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while (owner.instances.size()!=minimum or owner.dirty or not owner.requests.is_empty()) and owner.errors.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(owner.errors.is_empty() and owner.instances.size()==minimum and not owner.dirty,"Generated light owner settles to "+str(minimum)+" actual instances: "+JSON.stringify(owner.errors))
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install","catalog","scene"]) or FileAccess.file_exists(args.report):quit(2);return
	check(Session!=null,"Actual native session and live-world integration compile")
	var captured:=Captured.new();check(captured.mount(args.catalog),"Sealed original Arelith catalog opens read-only")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed fx_placeable01 provider mounts read-only")
	# This test deliberately mounts the two captured tables over the install.
	# Production uses its already active catalog; it never gets this fallback.
	var folder: String=str(args.report).trim_suffix(".json")+".inputs"
	check(DirAccess.make_dir_recursive_absolute(folder)==OK,"Isolated test table layer is inside the report workspace")
	for name in ["placeables","lightcolor"]:
		var bytes: PackedByteArray=captured.get_resource(name,2017)
		check(captured.failure.is_empty() and not bytes.is_empty(),"Actual captured "+name+" table exists")
		var file:=FileAccess.open(folder.path_join(name+".2da"),FileAccess.WRITE);file.store_buffer(bytes);file.close()
	check(catalog.mount_directory(folder,50000000),"Captured active tables override installed base tables")
	var scene: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.scene)).scene
	var fixtures: Array=[]
	for object in scene.objects:
		if object.family=="placeableLights" and int(object.appearance)==78 and fixtures.size()<2:
			check(object.model=="plc_k06" and object.model_metadata.lights.is_empty() and int(object.model_metadata.emitters)==3,"Actual affected Pillar1 has three flame emitters but zero model lamps")
			fixtures.append({"id":int(object.id),"appearance":int(object.appearance),"position":object.position})
	check(fixtures.size()==2,"Exact two nearest captured Pillar1 fixtures selected")
	var world:=TestWorld.new();root.add_child(world);world.add_child(Palette.new())
	var pool:=Pool.new();pool.native_lighting=true
	var owner:=Lights.new();world.add_child(owner);owner.configure(world,catalog,pool,"",fixtures)
	await settle(owner,2)
	var source_snapshot:=owner.snapshot()
	check(not owner.bundle.is_empty() and owner.bundle.sha256=="b8d2e0447751546caf728393b346b9de8589069809e83d6ac2827843b7f1d7be","Exact installed original generated light model was prepared natively")
	check(Lights.definition({"orderedRows":[{"LightColor":"****"}]},{},0).is_empty(),"Missing LightColor creates no generated light")
	var zero:=Lights.definition({"orderedRows":[{"LightColor":"0"}]},{"orderedRows":[{"RED":".2","GREEN":".3","BLUE":".4"}]},0)
	check(zero.color==[.2,.3,.4] and zero.offset==[0.0,0.0,3.0],"Successful colour row zero is enabled and missing offsets use original0/0/3 defaults")
	var missing:=Lights.definition({"orderedRows":[{"LightColor":"99"}]},{},65536)
	check(missing.appearance==0 and missing.color==[0.0,0.0,0.0],"Appearance is WORD masked and absent colour channels preserve initialized zero")
	for fixture in fixtures:
		var id: int=fixture.id
		if not owner.instances.has(id):continue
		var model: Node3D=owner.instances[id];var plan: Dictionary=owner.configurations[id]
		check(int(plan.colour_row)==6 and plan.offset==[.003989,.011001,.573451],"Captured active appearance supplies exact colour-row6 and original XYZ offsets")
		var lamp: Node3D=model.node_for(0,"auroralight01").get_child(0)
		var properties: Dictionary=lamp.native_properties
		check(properties.color==plan.color and float(properties.radius)==10 and float(properties.shadowradius)==15 and int(properties.shadow)==1 and int(properties.lightpriority)==4,"Generated light retains original colour/radius/shadow request/priority")
		check(lamp.native_slot>=0 and lamp.visible and lamp.native_state.enabled,"This is an actual admitted enhanced world light, not an emissive flame image")
		var expected:=Vector3(fixture.position[0]+plan.offset[0],fixture.position[2]+plan.offset[2],-fixture.position[1]-plan.offset[1])
		check(lamp.global_position.is_equal_approx(expected),"Generated lamp has the original root offset and native-to-Godot world position")
		var response: Dictionary=Policy.point(properties)
		check(response.color.x>response.color.z and response.color.y>response.color.z and Policy.attenuation(2,response)>0,"Captured light supplies a warm nonzero surface illumination contribution")
	var id: int=fixtures[0].id;var identity: int=owner.instances[id].get_instance_id()
	owner.receive_area(fixtures);await settle(owner,2)
	check(owner.instances[id].get_instance_id()==identity and owner.created==2,"Repeated area packets reuse each canonical light without duplicate ownership")
	var body:=Body.new();world.add_child(body);body.position=Vector3(10,2,3);body.rotation.y=.7
	var anchor:=Node3D.new();anchor.set_meta("native_part_parent",-1);body.add_child(anchor);anchor.position=Vector3(0,.2,0);body.parts.append(anchor);world.instances[id]=body
	var dynamic:={"id":id,"areaId":world.area_id,"objectType":9,"replicated":{"appearance":78,"position":[10,-3,2],"lightOn":true}}
	owner.receive([dynamic]);world.instance_ready.emit(id,dynamic,body);await settle(owner,2)
	check(owner.instances[id].get_instance_id()==identity and owner.instances[id].anchor_node==anchor,"Static-to-dynamic handoff reuses the area light and attaches to the actual root Part")
	var model: Node3D=owner.instances[id];model._process(0)
	check(model.global_position.is_equal_approx(anchor.global_position),"Attached generated light follows the actual object's model anchor")
	dynamic.replicated.lightOn=false;owner.receive([dynamic]);await settle(owner,1)
	check(not owner.instances.has(id),"Authoritative LightOn false removes both attached light and area-light fallback")
	dynamic.replicated.lightOn=true;owner.receive([dynamic]);await settle(owner,2)
	check(owner.created==3,"Authoritative LightOn true recreates exactly one light")
	owner.receive([], [id]);owner.receive_area([fixtures[1]]);world.instances.erase(id);world.instance_removed.emit(id);await settle(owner,1)
	check(not owner.instances.has(id),"Removed canonical entity and area record cannot leave a ghost light")
	var all_fixtures: Array=[]
	for object in scene.objects:
		if object.family=="placeableLights":all_fixtures.append({"id":int(object.id),"appearance":int(object.appearance),"position":object.position})
	owner.receive_area(all_fixtures);await settle(owner,all_fixtures.size())
	check(all_fixtures.size()==27 and owner.instances.size()==27,"All27 actual captured area lights publish independently of static mesh streaming and flame particles")
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(65,6,-129)
	var budget:=Budget.new();world.add_child(budget);budget.camera=camera;budget.maximum=3;budget.set_process(false);budget._profile_process(.2)
	check(budget.active==mini(3,budget.eligible) and budget.active>=2 and budget.lights==27,"Actual nearby generated lamps participate within the three-map budget and original shadow support")
	owner.receive_area([]);await settle(owner,0)
	check(owner.instances.is_empty(),"Replacing the area's light list with empty removes all27 static lamps")
	owner.close();await process_frame
	check(owner.instances.is_empty() and owner.assets.running.is_empty(),"World close joins native preparation and removes all generated light owners")
	world.free();pool.clear();await process_frame;await process_frame
	check(Palette.active.is_empty(),"Generated light retirement releases every enhanced palette slot")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"source_lights":source_snapshot,"publicConnections":0,"scope":"Headless actual installed fx_placeable01 through production native worker/model/light ownership with exact captured active tables and affected fixture positions; physical enhanced light RGB/range/shadow requests, root offset, static/dynamic handoff, authoritative on/off/removal and retirement. No GPU pixels or full-room/native-shadow parity acceptance."}
	var report:=FileAccess.open(args.report,FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close();quit(0 if result.success else 1)
