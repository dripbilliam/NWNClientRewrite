extends SceneTree
const TileLights=preload("res://systems/native_render/tile_lights.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func rgb(row: int) -> Array: return [TileLights.f(row/255.0),TileLights.f((255-row)/255.0),TileLights.f((row%3)/2.0)]
func fixture(prefix: String,names: Array,colors: Array,present: int=3) -> Dictionary:
	var root_node:=Node3D.new(); var parts: Array=[]; var lights: Array=[]
	for index in names.size():
		var part:=Node3D.new(); part.set_meta("native_part_name",names[index]); root_node.add_child(part); parts.append(part)
		var light:=PointLight.new(); light.configure({"color":colors[index],"radius":17,"shadowradius":19,"shadow":7,"affectdynamic":7,"lightpriority":7})
		if present&(1<<index): part.add_child(light); lights.append(light)
		else: light.free(); lights.append(null)
	return {"root":root_node,"parts":parts,"lights":lights,"model":prefix}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.loader.resource=="LightColor","Original binary identity and table selection")
	var table:={"columns":["RED","GREEN","BLUE"],"orderedRows":[],"defaultValue":"0"}
	for index in 256:
		var color_value:=rgb(index); table.orderedRows.append({"RED":str(color_value[0]),"GREEN":str(color_value[1]),"BLUE":str(color_value[2])})
	for row in oracle.matching:
		var instance:=fixture(str(row.prefix),[row.node],[rgb(0)],1 if row.cast else 0)
		var result:=TileLights.apply(instance,str(row.prefix),[rgb(0),rgb(1)])
		check(result.map(func(slot):return slot.present)==row.slots.slice(0,2),"Original physical suffix/case/truncation/light match")
		instance.root.free()
	for row in oracle.updates:
		var source: Dictionary=row.case; var indices: Array=[source.first,source.second]; var palette:=TileLights.colors(indices,table); var before: Array=[]
		for index in 2: before.append(rgb(int(indices[index])&255) if int(source.equal)&(1<<index) else [-1,-1,-1])
		var instance:=fixture("tile",["tileml1","tileML2"],before,int(source.present)); var result:=TileLights.apply(instance,"tile",palette); var changed: Array=[]
		for index in 2:
			if result[index].changed: changed.append(index)
			if not result[index].present: continue
			var actual: Dictionary=result[index]; var expected: Dictionary=row.lights[index]
			check(PackedFloat32Array(actual.color)==PackedFloat32Array(expected.color),"Original tile palette RGB output")
			check(float(actual.radius)==float(expected.radius) and float(actual.shadowRadius)==float(expected.shadowRadius),"Original changed/equal tile radius contract")
			check(int(actual.shadow)==int(expected.field78) and int(actual.affectDynamic)==int(expected.field88) and int(actual.priority)==int(expected.priority),"Original shadow/dynamic/priority writes")
		check(PackedInt32Array(changed)==PackedInt32Array(row.invalidated),"Original only-change-when-RGB-differs invalidation")
		instance.root.free()
	# Changing one placement must leave another instance's authored baseline.
	var first:=fixture("tile",["tileml1"],[[0.1,0.2,0.3]]); var second:=fixture("tile",["tileml1"],[[0.1,0.2,0.3]])
	TileLights.apply(first,"tile",[[0.5,0.6,0.7],[0,0,0]])
	check(second.lights[0].get_meta("native_model_light_properties").color==[0.1,0.2,0.3],"Palette changes are placement-local")
	first.root.free(); second.root.free()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"matching_cases":oracle.matching.size(),"update_cases":oracle.updates.size(),"native_only":true,"scope":"Original binary tile-light selection and update executions; no FPS or full lighting parity acceptance","sourceSha256":{}}
	for name in ["systems/native_render/tile_lights.gd","systems/native_render/model_point_light.gd","tests/native_tile_lights_test.gd"]: report.sourceSha256[name]=FileAccess.get_sha256("res://"+name)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures})); quit(0 if report.passed else 1)
