extends SceneTree
# Source-only paired fixture until a NEW engine includes the optional class.
# Existing production/native outputs are never rebuilt by this test.
var checks := 0
var failures: Array[String] = []
var report_path := ""
class Lamp extends Node3D:
	var native_properties: Variant = {"radius":8.0,"color":[0.8,0.4,0.2],"multiplier":1.0}
	var native_state: Variant = {"range":12.0}
	var native_properties_revision: Variant = 0
class Facade extends Node3D:
	var properties: Variant = {"radius":8.0,"color":[0.8,0.4,0.2]}
	var state_value: Variant = {"range":12.0}
	var revision_value: Variant = 0
	var reads: Array[String] = []
	var callback: Callable
	func _get(property: StringName) -> Variant:
		if property not in [&"native_properties",&"native_state",&"native_properties_revision"]: return null
		reads.append(str(property))
		if callback.is_valid(): callback.call(property)
		if property == &"native_properties": return properties
		if property == &"native_state": return state_value
		return revision_value
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func scene(class_name_value: String, custom: bool = false) -> Dictionary:
	var owner: Object = ClassDB.instantiate(class_name_value)
	var host := Node3D.new(); root.add_child(host)
	var parent := Node3D.new(); host.add_child(parent)
	var value := {"owner":owner,"host":host,"parent":parent,"lamps":[],"ids":{parent.get_instance_id():101}}
	for index in 3:
		var lamp: Node3D = Facade.new() if custom else Lamp.new()
		lamp.position.x = float(index); lamp.set_meta("native_enhanced_light",true)
		parent.add_child(lamp); value.lamps.append(lamp); value.ids[lamp.get_instance_id()] = index+1
	for index in [2,0,1]: owner.call("dispatch",0,{"id":value.lamps[index].get_instance_id(),"source":parent.get_instance_id()})
	return value
func normalized(value: Variant,ids: Dictionary) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = normalized(value[key],ids)
		return out
	if value is Array:
		var out: Array = []
		for item in value: out.append(normalized(item,ids))
		return out
	return ids[value] if typeof(value)==TYPE_INT and ids.has(value) else value
func compare(previous: Dictionary,current: Dictionary,operation: int,a: Dictionary,b: Dictionary,label: String) -> Dictionary:
	var old: Dictionary = previous.owner.call("dispatch",operation,a)
	var next: Dictionary = current.owner.call("dispatch",operation,b)
	var old_normal: Variant = normalized(old,previous.ids); var new_normal: Variant = normalized(next,current.ids)
	var exact_bytes := var_to_bytes(old_normal) == var_to_bytes(new_normal)
	# Identical NaN payloads compare unequal numerically, but their exact Variant
	# bytes still prove equality. There is never a numeric tolerance fallback.
	check(old_normal == new_normal or exact_bytes,label+": values/order")
	check(exact_bytes,label+": exact Variant values/key and default types")
	return next
func adjacent_f32(value: float,direction: int) -> float:
	var bytes := PackedByteArray(); bytes.resize(4); bytes.encode_float(0,value)
	bytes.encode_u32(0,bytes.decode_u32(0)+direction)
	return bytes.decode_float(0)
func adjacent_positive_f64(value: float,direction: int) -> float:
	var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0,value)
	bytes.encode_u64(0,bytes.decode_u64(0)+direction)
	return bytes.decode_double(0)
func compare_any(previous: Dictionary,current: Dictionary,operation: Variant,input: Variant,label: String) -> void:
	var old: Dictionary = previous.owner.call("dispatch",operation,input)
	var next: Dictionary = current.owner.call("dispatch",operation,input)
	check(var_to_bytes(normalized(old,previous.ids)) == var_to_bytes(normalized(next,current.ids)),label+": strict raw argument/error contract")
func poll(previous: Dictionary,current: Dictionary,label: String,planes: Array = [],view_changed: bool = false) -> Dictionary:
	return compare(previous,current,1,{"planes":planes,"view_changed":view_changed},{"planes":planes,"view_changed":view_changed},label)
func dispose(value: Dictionary) -> void:
	value.owner.call("dispatch",8,{})
	for lamp in value.lamps:
		if is_instance_valid(lamp) and lamp is Facade: lamp.callback = Callable()
	value.host.free(); value.clear()
func run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	check(ClassDB.class_exists("NwnLightInputRegistry"),"old extension registry loaded")
	check(ClassDB.class_exists("NwnBuiltinLightInputRegistry"),"optional builtin registry loaded")
	if not failures.is_empty(): finish(); return
	var previous := scene("NwnLightInputRegistry"); var current := scene("NwnBuiltinLightInputRegistry")
	poll(previous,current,"initial physical order")
	poll(previous,current,"unchanged rows reused")
	for value in [previous,current]: value.parent.hide()
	poll(previous,current,"hidden parent removes rows")
	for value in [previous,current]: value.parent.show(); value.lamps[0].hide()
	poll(previous,current,"parent reentry ignores own admission visibility")
	for value in [previous,current]: value.parent.position = Vector3(1.5,2,-3); value.lamps[0].set_meta("native_light_priority",4)
	poll(previous,current,"pose and priority-only changes")
	for value in [previous,current]: value.lamps[0].native_properties = {"radius":8.0}; value.lamps[0].native_properties_revision += 1
	poll(previous,current,"integer defaults and float positions")
	for value in [previous,current]: value.lamps[1].native_properties.radius = 1000.0
	poll(previous,current,"area radius excluded without row rebuild")
	for value in [previous,current]: value.lamps[1].native_properties.radius = 999.999
	poll(previous,current,"finite radius reentry")
	for value in [previous,current]: value.owner.call("dispatch",0,{"id":value.lamps[0].get_instance_id(),"source":value.parent.get_instance_id()})
	poll(previous,current,"duplicate registration preserves order/publication")
	for value in [previous,current]: value.owner.call("dispatch",2,{"id":value.lamps[0].get_instance_id()}); value.owner.call("dispatch",0,{"id":value.lamps[0].get_instance_id(),"source":value.parent.get_instance_id()})
	poll(previous,current,"remove and same-ID re-add before frame")
	var planes: Array = [Plane(Vector3.RIGHT,10),Plane(Vector3.LEFT,10),Plane(Vector3.UP,10),Plane(Vector3.DOWN,10),Plane(Vector3.BACK,10),Plane(Vector3.FORWARD,10)]
	poll(previous,current,"six exact camera planes",planes,true)
	for value in [previous,current]: value.parent.position = Vector3.ZERO; value.lamps[2].position = Vector3(22,0,0); value.lamps[2].native_state.range = 12.0
	poll(previous,current,"exact sphere plane boundary",planes)
	compare(previous,current,4,{}, {},"reset publication")
	poll(previous,current,"reset re-publishes")
	# Old reader receives f32 Vector3/Plane, promotes the builtin distance result
	# to double, and compares against a double range. Test both boundaries.
	for coordinate in [adjacent_f32(22.0,-1),22.0,adjacent_f32(22.0,1)]:
		for range_value in [adjacent_positive_f64(12.0,-1),12.0,adjacent_positive_f64(12.0,1)]:
			for value in [previous,current]: value.lamps[0].position = Vector3(coordinate,0,0); value.lamps[0].native_state.range = range_value
			poll(previous,current,"f32 position / f64 range neighbors",planes)
	# This discriminates f32 from an invented all-double dot product: the native
	# ((1e10*n) + n) - 1e10*n result rounds to zero before comparison with0.5.
	var cancellation_planes: Array = [Plane(Vector3.ONE.normalized(),0),Plane(Vector3.ZERO,100),Plane(Vector3.ZERO,100),Plane(Vector3.ZERO,100),Plane(Vector3.ZERO,100),Plane(Vector3.ZERO,100)]
	for point in [Vector3(1e10,1,-1e10),Vector3(-0.0,0.0,-0.0),Vector3(0.0,-0.0,0.0)]:
		for value in [previous,current]: value.lamps[0].position = point; value.lamps[0].native_state.range=0.5; value.lamps[0].native_properties_revision += 1
		var cancellation := poll(previous,current,"f32 cancellation and signed zero",cancellation_planes,true)
		if point.x==1e10:
			var matching: Array = cancellation.rows.filter(func(row):return int(row.id)==current.lamps[0].get_instance_id())
			check(matching.size()==1 and bool(matching[0].in_view),"native f32 cancellation remains inside; all-double replacement would fail")
	for range_value in [NAN,INF,-INF,-0.0]:
		for value in [previous,current]: value.lamps[0].native_state.range = range_value
		poll(previous,current,"nonfinite/signed support range",planes)
	for color in [[0,0,0],[-0.0,NAN,INF],PackedFloat32Array([0.1,0.2,0.3])]:
		for value in [previous,current]: value.lamps[0].native_properties.color = color; value.lamps[0].native_properties_revision += 1
		poll(previous,current,"raw color Variant retained",planes)
	for value in [previous,current]: value.lamps[0].position = Vector3.ZERO; value.lamps[0].native_state.range = 12.0; value.lamps[0].native_properties = {"radius":8.0}; value.lamps[0].native_properties_revision += 1
	poll(previous,current,"restored ordinary values")
	for value in [previous,current]:
		var secondary := Node3D.new(); value.host.add_child(secondary); value.secondary=secondary; value.ids[secondary.get_instance_id()]=102
		value.lamps[0].reparent(secondary,true)
	poll(previous,current,"reparent changes live eligibility but retains registered source")
	for value in [previous,current]: value.secondary.hide()
	poll(previous,current,"new parent hidden")
	for value in [previous,current]: value.secondary.show()
	poll(previous,current,"new parent visible")
	compare(previous,current,0,{"id":previous.lamps[0].get_instance_id(),"source":previous.secondary.get_instance_id()},{"id":current.lamps[0].get_instance_id(),"source":current.secondary.get_instance_id()},"explicit registered source changes")
	poll(previous,current,"new registered source row")
	for arguments in [{},{"planes":[]},{"view_changed":false},{"view_changed":false,"planes":[Plane()]},{"view_changed":false,"planes":[0,0,0,0,0,0]},{"view_changed":"wrong","planes":[]}]:
		compare(previous,current,1,arguments,arguments,"malformed poll "+str(arguments.keys()))
	for identity in [1.5,NAN,INF,9007199254740992.0,"wrong",true]:
		compare(previous,current,0,{"id":identity,"source":0},{"id":identity,"source":0},"invalid identity "+str(identity))
	for value in [previous,current]: value.lamps[1].set_meta("native_light_priority",1.5)
	poll(previous,current,"priority requires integer")
	for value in [previous,current]: value.lamps[1].set_meta("native_light_priority",1); value.lamps[1].native_properties_revision = 1.5
	poll(previous,current,"revision requires integer")
	for value in [previous,current]: value.lamps[1].native_properties_revision = 2; value.lamps[2].free(); value.lamps[2] = null
	poll(previous,current,"freed node tombstone")
	for value in [previous,current]: value.owner.call("dispatch",0,{"id":value.lamps[0].get_instance_id(),"source":value.parent.get_instance_id()})
	poll(previous,current,"source reassigned before lifetime test")
	for value in [previous,current]: value.parent.free(); value.parent=null; value.lamps[1]=null
	poll(previous,current,"registered source retires while reparented lamp survives")
	compare(previous,current,3,{}, {},"all retained counters")
	for malformed in [null,42,"wrong",false]:
		for operation in [0,1,2]: compare_any(previous,current,operation,malformed,"non-Dictionary used input")
	for operation in [3.0,true,"3",null]: compare_any(previous,current,operation,{},"operation remains strict integer")
	compare_any(previous,current,3,42,"inspect ignores input type")
	compare_any(previous,current,4,"ignored","reset ignores input type")
	compare(previous,current,8,{}, {},"close")
	compare_any(previous,current,8,false,"close ignores input type")
	compare(previous,current,1,{"planes":[],"view_changed":false},{"planes":[],"view_changed":false},"closed poll")
	compare(previous,current,0,{"id":1,"source":0},{"id":1,"source":0},"closed add")
	compare(previous,current,99,{}, {},"unknown operation")
	dispose(previous); dispose(current)
	previous = scene("NwnLightInputRegistry",true); current = scene("NwnBuiltinLightInputRegistry",true)
	for value in [previous,current]:
		for lamp in value.lamps:
			lamp.callback = func(property: StringName):
				if property == &"native_properties": lamp.position.y = 2.25
				if property == &"native_state":
					lamp.position.z = 4.5; lamp.state_value.range = 13.0
					if lamp == value.lamps[0]: value.lamps[1].position.x = 7.5
				if property == &"native_properties_revision": lamp.set_meta("native_light_priority",3)
	for turn in 3:
		for value in [previous,current]:
			for lamp in value.lamps: lamp.reads.clear()
		poll(previous,current,"custom getter mutation order "+str(turn))
		for index in 3: check(previous.lamps[index].reads == current.lamps[index].reads,"custom getter sequence "+str(turn)+":"+str(index))
	for value in [previous,current]:
		value.lamps[0].callback = func(property: StringName):
			if property == &"native_state" and is_instance_valid(value.lamps[1]): value.lamps[1].free(); value.lamps[1]=null
	poll(previous,current,"getter frees a later node with stable registration vector")
	for value in [previous,current]: value.lamps[0].properties={}
	poll(previous,current,"getter returns empty authored properties")
	for value in [previous,current]: value.lamps[0].properties={"radius":8.0}; value.lamps[0].revision_value+=1
	poll(previous,current,"custom properties return")
	for value in [previous,current]: value.lamps[0].state_value = null
	poll(previous,current,"custom getter bad state return")
	dispose(previous); dispose(current)
	# Candidate-only safety assertions. Do not execute the old extension's
	# dangling-reference cases and pretend a crash is an output contract.
	var unsafe := scene("NwnBuiltinLightInputRegistry",true)
	unsafe.lamps[2].callback = func(_property: StringName): unsafe.owner.call("dispatch",8,{})
	var closed: Dictionary = unsafe.owner.call("dispatch",1,{"planes":[],"view_changed":false})
	check(closed.get("error","") == "Native light input registry is closed","close inside getter aborts explicitly")
	dispose(unsafe)
	unsafe=scene("NwnBuiltinLightInputRegistry",true)
	unsafe.lamps[2].callback = func(_property: StringName): unsafe.owner.call("dispatch",2,{"id":unsafe.lamps[2].get_instance_id()})
	var erased: Dictionary = unsafe.owner.call("dispatch",1,{"planes":[],"view_changed":false})
	check(erased.get("error","") == "Native light input registry membership changed during property read","erase inside getter aborts before using invalid Entry")
	dispose(unsafe)
	unsafe=scene("NwnBuiltinLightInputRegistry",true)
	var nested: Array = []
	unsafe.lamps[2].callback = func(_property: StringName): nested.append(unsafe.owner.call("dispatch",1,{"planes":[],"view_changed":false}))
	var outer: Dictionary = unsafe.owner.call("dispatch",1,{"planes":[],"view_changed":false})
	check(not outer.has("error") and not nested.is_empty(),"reentrant rejection leaves outer valid")
	check(nested.all(func(value): return value.get("error","") == "Native light input registry poll is reentrant"),"nested polls reject explicitly")
	dispose(unsafe)
	await process_frame; await process_frame
	finish()
func finish() -> void:
	var result := {"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Direct extension/builtin input registry values, order, Variant bytes and getter mutations; candidate-only close safety. No GPU/FPS or whole Focus acceptance."}
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_builtin_light_registry_test","checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
