extends SceneTree
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or not args.has("samples") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	var samples: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.samples))
	check(FileAccess.get_sha256(args.oracle)=="13382feea7c67e22d7ba1977b884ae4300226d09639f784a973f8150d68e7df0","Exact original admission evidence is immutable")
	check(FileAccess.get_sha256(args.samples)=="3a7eb2001b0003caa113c5869327f6cb437f6ecc8faa22171e5bca778d2aa2f5","Exact original focus/vision evidence is immutable")
	check(original.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==6,"Original pinned six-sequence light-limit corpus")
	check(samples.history_sha256==FileAccess.get_sha256(args.oracle) and samples.rows.size()==8,"Original samples use these exact original admitted lights/fades")
	check(OS.get_cmdline_user_args().has("--native-light-history"),"Test exercises actual automatic world history configuration")
	check(Focus.maximum_setting(PackedStringArray()).maximum==32,"Original setting default is32 rather than128-slot storage capacity")
	for value in ["0","8","16","32","64","128"]:
		var setting:=Focus.maximum_setting(PackedStringArray(["--native-max-lights="+value]))
		check(setting.error.is_empty() and int(setting.maximum)==int(value),"Explicit original light limit "+value)
	for value in ["","-1","129","1.5","NaN"]:
		check(not Focus.maximum_setting(PackedStringArray(["--native-max-lights="+value])).error.is_empty(),"Reject invalid direct native light setting "+value)
	var observations: Array=[]; var sample_index:=0; var default_gate:=false; var capacity_gate:=true
	for sequence in original.rows.size():
		var row: Dictionary=original.rows[sequence]
		var world:=Node3D.new(); world.set_meta("native_enhanced_lighting",true); root.add_child(world)
		var owner:=Focus.new(); world.add_child(owner); owner.configure(world); owner.set_process(false)
		check(owner.history!=null and owner.history_maximum==32,"Actual world configuration starts with32 active slots, sequence "+str(sequence))
		var lamps: Array=[]; var identities: Dictionary={}
		for index in row.case.lights.size():
			var source: Dictionary=row.case.lights[index]
			var light:=Point.new(); light.set_meta("native_enhanced_light",true)
			light.configure({"color":source.color,"radius":source.radius,"fadinglight":source.fading})
			world.add_child(light); light.position=Vector3(source.position[0],source.position[2],-source.position[1]); light.force_update_transform()
			identities[light.get_instance_id()]=index; lamps.append(light)
		check(owner.members.size()==128,"All128 physical lamps register independently of the admitted-light limit")
		for frame in row.case.frames.size():
			var input: Dictionary=row.case.frames[frame]; owner.history_maximum=int(input.maximum)
			owner.history_frame(float(input.delta)); owner.refresh()
			var expected: Dictionary=row.frames[frame]; var expected_ids: Array=expected.active0.map(func(v):return int(v)); var actual: Array=[]
			for id in owner.history_result.active0: actual.append(identities[int(id)])
			check(actual==expected_ids,"Actual physical owner matches original ordered admission "+str(sequence)+"/"+str(frame))
			var visible_count:=0
			for index in lamps.size():
				var light: Node3D=lamps[index]; var admitted: bool=expected_ids.has(index)
				check(light.native_admitted==admitted and light.visible==admitted,"Actual rendered lamp visibility follows original admission "+str(sequence)+"/"+str(frame)+"/"+str(index))
				if admitted: visible_count+=1
			check(visible_count==int(input.maximum),"Physical rendered lamps respect configured maximum")
			var sample: Dictionary=samples.rows[sample_index]; sample_index+=1
			check(owner.value.distance_to(Vector3(sample.sample[0],sample.sample[1],sample.sample[2]))<.000001,"Production vision sample matches unchanged original instructions")
			var previous: bool=owner.gate.active; var reference: Dictionary=sample.gates[1 if previous else 0]
			check(owner.view_gate()==bool(reference.returned) and owner.gate.active==bool(reference.stored),"Production hysteresis matches original for actual admitted lamps")
			if sequence==2: default_gate=owner.gate.active
			if sequence==4: capacity_gate=owner.gate.active
			observations.append({"sequence":sequence,"frame":frame,"maximum":input.maximum,"focus":owner.snapshot()})
		owner.close(); world.free()
	check(default_gate and not capacity_gate,"Fixture distinguishes correct32-light vision admission from128-light over-illumination")
	check(Palette.active.is_empty(),"All physical lamp palette ownership retires")
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"scope":"Actual automatic world light-limit configuration,128 physical model lights, original ordered active slots and visible admission, and original CPU light/vision instructions. Includes32-to128-to32 changes. Headless; not GPU, live-room visual or performance acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
