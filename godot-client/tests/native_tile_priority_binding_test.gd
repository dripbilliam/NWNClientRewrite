extends SceneTree
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const Tile=preload("res://systems/native_render/tile_lights.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(FileAccess.get_sha256(args.oracle)=="a809a96ad8c347acd99f165a7f3dc3b7b4b6d30e8e3d4c59e508e2d6299df710","Pinned original tile-priority admission observations")
	check(original.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original executable")
	var world:=Node3D.new();world.set_meta("native_enhanced_lighting",true);root.add_child(world)
	var owner:=Focus.new();world.add_child(owner);owner.configure(world);owner.set_process(false);owner.history_maximum=1
	check(owner.history!=null,"Actual production world enables history")
	var part:=Node3D.new();part.set_meta("native_part_name","tileml1");world.add_child(part)
	var lamp:=Point.new();lamp.set_meta("native_enhanced_light",true);lamp.configure({"color":[1,.8,0],"radius":10,"fadinglight":0,"lightpriority":5});part.add_child(lamp);part.position=Vector3(3,0,0);part.force_update_transform();lamp.force_update_transform()
	var other:=Point.new();other.set_meta("native_enhanced_light",true);other.configure({"color":[1,.8,0],"radius":10,"fadinglight":0,"lightpriority":4});world.add_child(other);other.position=Vector3(3.2,0,0);other.force_update_transform()
	var lamps: Array=[lamp,other];var observations: Array=[];var source_revision:=-1
	for stage in 3:
		if stage==1:
			# Force an actual palette change through SetTileLights' production
			# adapter, restoring the oracle's RGB before the next history frame.
			var props: Dictionary=lamp.native_properties.duplicate(true);props.color=[0,0,0];lamp.configure(props)
			var applied: Array=Tile.apply({"parts":[part]},"tile",[[1,.8,0],[0,0,0]])
			check(applied[0].changed and int(lamp.get_meta("native_light_priority",0))==4,"Actual tile palette adapter publishes original PartLight+90 override")
			check(int(lamp.native_properties.lightpriority)==5,"Runtime override does not overwrite the authored MDL-node priority")
			source_revision=lamp.native_properties_revision
		if stage==2:
			lamp.set_meta("native_light_priority",0)
			check(lamp.native_properties_revision==source_revision,"Reset fixture changes only the physical runtime priority, not source RGB/radius or revision")
		owner.history_frame(.3)
		var expected: Array=original.rows[stage].frames[0].active0.map(func(v):return int(v));var actual: Array=[]
		for id in owner.history_result.active0:
			for index in lamps.size():
				if lamps[index].get_instance_id()==int(id):actual.append(index)
		check(actual==expected,"Original selected lamp after runtime override stage "+str(stage))
		for index in lamps.size():check(lamps[index].native_admitted==expected.has(index) and lamps[index].visible==expected.has(index),"Actual lamp admission and visibility stage "+str(stage)+"/"+str(index))
		var published: Dictionary=owner.history_rows[lamp.get_instance_id()]
		check(int(published.override)==[0,4,0][stage],"Native selector receives the actual independent runtime override")
		var sent:=owner.history_input_rows;owner.history_frame(.3)
		check(owner.history_input_rows==sent,"Unchanged frames reuse priority input without changing active lamps")
		observations.append({"stage":stage,"winner":actual,"published_override":published.override})
	owner.close();world.free();await process_frame
	check(Palette.active.is_empty(),"Both physical lamps and palette ownership retire")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"scope":"Production tile palette adapter through actual world history to physical lamp visibility, compared with unchanged original priority/sort/fades. Metadata-only override reset and retained input covered. Headless; not live-room color or shadow-map acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
