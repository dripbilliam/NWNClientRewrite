extends SceneTree
const Priority=preload("res://systems/native_data/light_priority.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const Budget=preload("res://systems/native_render/model_light_budget.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func ids(owner) -> Array:return owner.snapshot().selected.map(func(row):return int(row.id))
func lamp(world: Node3D,x: float,colour: Array=[1.9,1.9,1.0]) -> Node3D:
	var light:=Point.new();light.configure({"color":colour,"radius":10.0,"shadowradius":15.0,"shadow":1,"ambientonly":0,"lightpriority":4,"fadinglight":1,"multiplier":1,"isdynamic":0})
	world.add_child(light);light.position=Vector3(x,1,0);light.force_update_transform();return light
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	check(Session!=null,"Actual live entry and new focus-query binding compile")
	check(FileAccess.get_sha256(args.oracle)=="c4102f8ffe217bf455579d5681659cb51a12d042e19376930a1f5073d87ea07f","Pinned unchanged original-instruction light priority corpus")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==864,"Original corpus covers864 executions of the pinned binary")
	for observation in original.rows:
		var source: Dictionary=observation.case
		var score:=Priority.rank({"color":source.color,"radius":source.radius,"multiplier":source.multiplier,"lightpriority":source.priority,"fadinglight":source.fading,"isdynamic":source.dynamic},source.position,source.focus,int(source.priorityOverride),bool(source.onlyOwner))
		# The oracle stores native float32 fields as JSON decimal numbers. Restore
		# that field width before exact equality; the JSON parser's double may
		# differ in its last decimal place despite the same original float bits.
		var expected:=PackedFloat32Array([observation.distance,observation.priority])
		check(score.distance==expected[0],"Original float32 distance "+str(checks))
		check(score.priority==expected[1],"Original float32 priority "+str(checks)+" actual="+str(score.priority)+" expected="+str(observation.priority)+" case="+JSON.stringify(source))
	var world:=World.new();root.add_child(world);world.set_process(false);world.controlled_id=7
	var actor:=Node3D.new();world.add_child(actor);world.instances[7]=actor
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(10,6,8)
	var owner:=Budget.new();world.add_child(owner);owner.camera=camera;owner.focus_query=world.shadow_focus;owner.maximum=2;owner.set_process(false)
	var lamps: Array=[]
	for x in [-4,4,15,22]:lamps.append(lamp(world,x))
	var dark:=lamp(world,0,[.1,.1,.1]);var negative:=lamp(world,0,[-2,-2,-2])
	owner._profile_process(.2)
	var baseline:=ids(owner)
	check(owner.origin_source=="controlled-actor" and owner.selection_origin==actor.global_position,"Production world chooses actual controlled model position")
	check(owner.active==2 and baseline.has(lamps[0].get_instance_id()) and baseline.has(lamps[1].get_instance_id()),"Nearby original flame lights receive both local shadow slots")
	check(not dark.shadow_enabled and not negative.shadow_enabled,"Original positive raw RGB>.1 filter excludes dim and negative-color shadow requests")
	check(not lamps[2].shadow_enabled and not lamps[3].shadow_enabled,"Original shadow-radius support excludes lamps that cannot reach the player")
	var old_winners: Dictionary={}
	for index in 48:
		var angle:=TAU*index/48;camera.position=Vector3(cos(angle)*18,3+index*.1,sin(angle)*18);camera.look_at(actor.global_position);camera.force_update_transform()
		var old: Array=lamps.duplicate();old.sort_custom(func(a,b):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position));old_winners[old[0].get_instance_id()]=true
		owner._profile_process(.2)
		check(ids(owner)==baseline,"Orbit/height/rotation cannot reassign player-focused shadows "+str(index))
	check(old_winners.size()>1,"The same camera orbit reproduces the previous camera-distance slot swapping")
	actor.position=Vector3(20,0,0);actor.force_update_transform();owner._profile_process(.2)
	check(ids(owner)!=baseline and lamps[2].shadow_enabled and lamps[3].shadow_enabled,"Moving the actual player legitimately selects nearby new shadow sources")
	var point: Node3D=actor;world.instances.erase(7)
	world.desired[7]={"object":{"objectType":9,"replicated":{"position":[3,4,5]}}}
	var pending:=world.shadow_focus();check(pending.source=="controlled-pose" and pending.position==Vector3(3,5,-4),"Received player pose supplies focus while its actual model is preparing")
	world.desired.clear();world.set_priority_origin(Vector3(8,0,9));check(world.shadow_focus().source=="area-entry","Area-entry position supplies focus before player replication")
	world.has_priority_origin=false;owner._profile_process(.2)
	check(owner.origin_source=="unavailable" and owner.active==0 and lamps.all(func(light):return not light.shadow_enabled),"Unavailable live-world focus releases maps instead of reverting to orbit-camera selection")
	owner.maximum=0;world.instances[7]=point;owner._profile_process(.2);check(owner.active==0,"Configured shadows-off remains authoritative")
	var outsider:=Node3D.new();root.add_child(outsider);var outside:=lamp(outsider,0);outside.shadow_enabled=true;owner._profile_process(.2)
	check(outside.shadow_enabled,"Current world's budget never changes another world's shadow flags")
	world.instances.clear();world.close();world.free();outsider.free();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":original.rows.size(),"oldOrbitWinners":old_winners.size(),"publicConnections":0,"scope":"Executed original float32 rank corpus and production actual lamp/world shadow-focus binding: camera orbit, player movement, original raw RGB/support filters, pending actor/entry fallback, unavailable focus, shadows-off and world isolation. Headless; scene-wide Godot cap remains an approximation, without original per-pass stencil/fades or GPU shadow-pixel acceptance."}
	var report:=FileAccess.open(args.report,FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close();quit(0 if result.success else 1)
