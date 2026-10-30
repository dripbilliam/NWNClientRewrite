extends SceneTree
const Collision=preload("res://systems/native_render/drive_collision.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const Parser=preload("res://systems/native_data/object_surface.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Motion=preload("res://systems/network_motion.gd")
const Plan=preload("res://systems/native_data/drive_preview.gd")
class TestWorld:
	extends Node
	var surface
	var desired: Dictionary={}
	var motion:=Motion.new()
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var world:=TestWorld.new(); root.add_child(world)
	var surface:=Surface.new(); world.add_child(surface); world.surface=surface; surface.done=true
	surface.table={"orderedRows":[{"Walk":"1"}]}
	surface.definition={"width":2,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3(5,0,-5)},{"model":"floor","orientation":1,"position":Vector3(15,0,-5)}]}
	surface.meshes={"floor":{"vertices":[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0],"normals":[[0,0,1],[0,0,1]],"constants":[0,0]}}
	var collision:=Collision.new(); world.add_child(collision); collision.world=world
	collision.tables={"appearance":{"orderedRows":[{"PERSPACE":"0.3","HEIGHT":"1.8"}]},"placeables":{"orderedRows":[{"ModelName":"chest"}]},"genericdoors":{"orderedRows":[{"ModelName":"gate"}]},"doortypes":{}}
	world.desired[1]={"object":{"objectType":5,"appearance":{"appearance":0}}}; world.motion.ensure(1,{"position":[1,1,0]})
	var clear:=collision.query(1)
	check(clear.is_valid() and clear.call(Vector3(1,1,0),Vector3(5,1,0)),"Native floor line is clear")
	check(clear.call(Vector3(9,3,0),Vector3(11,3,0)),"Crossing into rotated adjacent tile preserves floor coverage")
	check(not clear.call(Vector3(19,3,0),Vector3(21,3,0)),"Missing base tiles block prediction")
	# A non-interactable static chest still owns its original footprint.
	var footprint:={"vertices":[Vector3(0,0,0),Vector3(1,0,0),Vector3(1,1,1),Vector3(0,1,1)],"faces":[[0,1,2],[0,2,3]]}
	collision.models["chest:placeable"]={"states":[footprint]}
	world.desired[2]={"object":{"id":2,"objectType":9,"staticState":{"appearance":0,"position":[4,1,0],"orientation":{"yaw":0},"usable":false,"static":true}}}
	clear=collision.query(1)
	check(not clear.call(Vector3(2,1.5,0),Vector3(6,1.5,0)),"Static unhighlightable PWK blocks local prediction")
	check(clear.call(Vector3(2,3,0),Vector3(6,3,0)),"Original footprint does not become a large guessed bounding box")
	check(not clear.call(Vector3(2,0.8,0),Vector3(6,0.8,0)),"Appearance PERSPACE keeps the capsule off an obstacle edge")
	var open:={"vertices":[],"faces":[]}; collision.models["gate:door"]={"states":[footprint,open,open]}
	world.desired.erase(2); world.desired[3]={"object":{"id":3,"objectType":10,"replicated":{"doorType":0,"genericType":0,"doorOpenState":0,"position":[4,1,0],"orientation":{"yaw":0}}}}
	check(not collision.query(1).call(Vector3(2,1.5,0),Vector3(6,1.5,0)),"Closed door DWK state blocks movement")
	world.desired[3].object.replicated.doorOpenState=1
	check(collision.query(1).call(Vector3(2,1.5,0),Vector3(6,1.5,0)),"Server open-door state changes native collision")
	world.desired.erase(3); world.desired[4]={"object":{"id":4,"objectType":5,"appearance":{"appearance":0}}}; world.motion.ensure(4,{"position":[4,1,0]})
	check(not collision.query(1).call(Vector3(2,1,0),Vector3(6,1,0)),"Other displayed creature radii block a drive line")
	check(collision.query(1,1.0/64).call(Vector3(2,1,0),Vector3(6,1,0)),"Acknowledgement geometry excludes creatures")
	world.desired.erase(4); world.motion.objects.erase(4)
	var wall:=Collision.triangle(Vector3(4,0,0),Vector3(4,5,0),Vector3(4,5,3)); wall.walk=false
	collision.tiles[0].append(wall)
	check(not collision.query(1).call(Vector3(3,2,0),Vector3(5,2,0)),"Original nonwalk tile geometry blocks a line")
	var line:=collision.query(1); var path:=Plan.path(Vector3(3.6,2,0),Vector3(4.6,3,0),Vector3(3.6,2,0),line)
	check(not path.is_empty() and path.target.x<=3.701 and path.target.y>2,"Native angular search slides along a wall without crossing it")
	# Original installed PWK decoding/preparation has its own external oracle.
	if args.has("install"):
		var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original local install mounts read-only")
		var names: Array=catalog.resource_names(2053); names.sort()
		var parsed:=0; var samples: Array=[]
		for name in names.slice(0,40):
			var parser:=Parser.new(); var bytes: PackedByteArray=catalog.get_resource(name,2053); var result:=parser.parse(bytes)
			check(parser.failure.is_empty() and result.has("states"),"Original PWK parses: "+str(name))
			if not result.is_empty(): parsed+=1; samples.append({"name":name,"faces":result.states[0].faces.size()})
		check(parsed>0,"Actual installed PWK resources were exercised")
		var doors: Array=catalog.resource_names(2052); doors.sort(); var solid_doors:=0
		for name in doors.slice(0,20):
			var parser:=Parser.new(); var result:=parser.parse(catalog.get_resource(name,2052),true)
			check(parser.failure.is_empty() and result.has("states"),"Original DWK parses: "+str(name))
			if not result.is_empty() and result.states.any(func(state):return not state.faces.is_empty()): solid_doors+=1
		check(solid_doors>0,"Original DWK closed/open collision states are retained")
		set_meta("original_samples",samples)
	collision.close(); world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_samples":get_meta("original_samples",[]),"network":false,"scope":"Native original-resource parser plus authored floor/door/static/creature/wall collision and slide behavior; conservative polygons, not full original collision oracle"},"  ")+"\n"); quit(0 if failures.is_empty() else 1)
