extends SceneTree
const Point=preload("res://systems/native_render/model_point_light.gd")
var checks:=0
var failures: Array=[]
var output:=""
var witnesses: Array=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func scene(script)->Dictionary:
	var room:=Node3D.new();root.add_child(room);room.set_meta("native_enhanced_lighting",true)
	var focus=script.new();room.add_child(focus);focus.configure(room);focus.set_process(false);focus.enable_history(2)
	focus.set_area([.1,.2,.3],[.3,.2,.1])
	var parent:=Node3D.new();parent.set_meta("native_light_source",true);room.add_child(parent)
	var result:={"room":room,"focus":focus,"parent":parent,"lamps":[],"ids":{},"records":[]}
	for index in 2:
		var lamp:=Point.new();lamp.set_meta("native_enhanced_light",true)
		lamp.configure({"color":[.8,.4,.2],"radius":8,"multiplier":1,"isdynamic":1,"affectdynamic":1,"fadinglight":1})
		lamp.position=Vector3(index,0,0);parent.add_child(lamp)
		result.lamps.append(lamp);result.ids[lamp.get_instance_id()]=index
	focus.history_frame(.1)
	return result
func snapshot(value: Dictionary)->Dictionary:
	var rows: Array=[]
	for id in value.focus.history_rows:
		var row: Dictionary=value.focus.history_rows[id].duplicate(true)
		row.id=int(value.ids[id]);row.owner=1 if row.owner==value.parent.get_instance_id() else 0;rows.append(row)
	rows.sort_custom(func(a,b):return int(a.id)<int(b.id))
	var states: Array=[]
	for lamp in value.lamps:states.append({"admitted":lamp.native_admitted,"fade":lamp.native_fade,"visible":lamp.visible,"color":lamp.light_color,"range":lamp.omni_range})
	var native: Dictionary=value.focus.history.dispatch(2,{})
	for field in ["order","collected","active0","active1"]:native[field]=native[field].map(func(id):return int(value.ids.get(int(id),-1)))
	for call in native.calls:
		if call.has("id"):call.id=int(value.ids.get(int(call.id),-1))
	for lamp in native.lights:lamp.id=int(value.ids.get(int(lamp.id),-1))
	native.lights.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return {"rows":rows,"states":states,"native":native}
func attach_callback(value: Dictionary)->void:
	var callback:Callable=func():
		# Node3D emits this ancestor signal before descendant visibility signals.
		# The original query must already observe the new live ancestor flag.
		value.focus.history_frame(.1)
		value.records.append(snapshot(value))
	value.callback=callback
	value.room.visibility_changed.connect(callback)
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var a:=scene(load("res://systems/native_render/focus_lighting.gd"))
	var b:=scene(load("res://systems/native_render/focus_lighting_native_input_candidate.gd"))
	check(snapshot(a)==snapshot(b),"Initial source/native registry inputs and physical lights match")
	attach_callback(a);attach_callback(b)
	a.room.hide();b.room.hide()
	check(a.records.size()==1 and b.records.size()==1,"Both polls execute inside the earlier ancestor signal")
	check(a.records[0]==b.records[0],"Ancestor hide callback sees exact original live parent visibility before descendant notifications")
	witnesses.append({"boundary":"ancestor hide callback","baseline_rows":a.records[0].rows.size(),"candidate_rows":b.records[0].rows.size()})
	a.room.show();b.room.show()
	check(a.records.size()==2 and b.records.size()==2,"Both return polls execute inside the ancestor signal")
	check(a.records[1]==b.records[1],"Ancestor show callback sees exact original live parent visibility before descendant notifications")
	witnesses.append({"boundary":"ancestor show callback","baseline_rows":a.records[1].rows.size(),"candidate_rows":b.records[1].rows.size()})
	for value in [a,b]:
		value.room.visibility_changed.disconnect(value.callback);value.erase("callback")
		value.focus.close();value.room.free();value.clear()
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"witnesses":witnesses,"gpu":false,"serverConnections":0,"scope":"Actual Node3D ancestor visibility signal callback reenters the original GDScript versus native input registry before descendant notification propagation. Compares full normalized rows/history/fades and physical lamps; no graphics or FPS acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_PERF140_RENDER_VISIBILITY_REENTRANCY ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
