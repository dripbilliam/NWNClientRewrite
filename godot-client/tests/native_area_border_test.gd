extends SceneTree
const Border=preload("res://systems/native_data/area_border.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func bits(value: float) -> String:return PackedFloat32Array([value]).to_byte_array().hex_encode()
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-area-border-installed-v1.json"))
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-area-border-original-v2.json"))
	if not fixture is Dictionary or not oracle is Dictionary or oracle.get("rows",[]).size()!=9:quit(3);return
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original routine identity")
	for observation in oracle.rows:
		var sample: Dictionary={}
		for source in fixture.samples:
			if source.setName==observation.setName:sample=source;break
		if sample.is_empty():failures.append("Missing actual installed table sample");break
		var table: Variant={"columns":sample.columns,"orderedRows":sample.rows,"defaultValue":sample.defaultValue} if observation.loaded else null
		var set_data:={"transition":float(sample.general.Transition),"tiles":sample.tiles}
		var before: Dictionary=observation.area.duplicate(true);var original_set: Dictionary=set_data.duplicate(true)
		var original_table: Variant=table.duplicate(true) if table is Dictionary else null
		var result:=Border.plan(observation.area,set_data,table,{"enabled":true,"disabled":false})
		check(result.get("ready",false),str(observation.name)+" prepared native plan")
		if not result.get("ready",false):continue
		check(result.attempts.size()==observation.calls.size(),str(observation.name)+" exact native SpawnTile count")
		if result.attempts.size()!=observation.calls.size():continue
		for index in result.attempts.size():
			var plan: Dictionary=result.attempts[index];var expected: Dictionary=observation.calls[index]
			check(plan.rawModel==expected.model,str(observation.name)+" native physical model choice")
			for axis in 3:check(bits(float(plan.nativePosition[axis]))==expected.positionBits[axis],str(observation.name)+" original position float bits")
			if not str(plan.rawModel).is_empty():check(int(plan.orientation)==int(expected.orientation),str(observation.name)+" native quarter-turn")
			check(plan.nativeSpawnFlags==1,str(observation.name)+" original decorative spawn flag")
			check(plan.position==Vector3(plan.nativePosition[0],plan.nativePosition[2],-plan.nativePosition[1]),str(observation.name)+" one native-to-Godot conversion")
		check(before==observation.area and original_set==set_data and original_table==table,str(observation.name)+" inputs remain immutable")
		for gate in [{"enabled":false,"disabled":false},{"enabled":true,"disabled":true}]:
			check(Border.plan(observation.area,set_data,table,gate).attempts.is_empty(),"Native settings/area gate skips all geometry")
		check(not Border.plan(observation.area,set_data,table,{"enabled":true}).ready,"Missing received disable field stays unavailable")
	check(Border.resource_name("1234567890123456")=="1234567890123456","Native CResRef length follows suffix-before16byte truncation")
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:quit(4);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure native GDScript plans versus original LoadBorder instructions over installed SET/Edge2DA values; no streaming/rendering/pixels/current server acceptance."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
