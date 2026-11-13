extends SceneTree
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const BASELINE_SHA="d3ac6a9b5debcf123423e214f877c4051021b4ff7d33945f1cc99e3f3b28326b"
class ObservedPoint extends Point:
	var logical:=0
	var entries: Array=[]
	func apply_native_admission(admitted: bool,fade: float)->void:
		entries.append([logical,admitted,fade])
		super.apply_native_admission(admitted,fade)
var checks:=0
var failures: Array=[]
var comparisons: Array=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func lamp(value: Dictionary,id: int,attach: bool=true):
	var node:=ObservedPoint.new();node.logical=id;node.entries=value.calls
	node.set_meta("native_enhanced_light",true)
	var static_only: bool=id in [4,9]
	node.configure({"color":[0.8,0.4,0.2],"radius":1000.0 if id==5 else 8.0,"multiplier":1.0,"fadinglight":1,"lightpriority":id%3,"isdynamic":0 if static_only else 1,"affectdynamic":0 if static_only else 1})
	node.position=Vector3(float(id)-3.0,0,0) if id!=6 else Vector3(500,0,0)
	value.lamps[id]=node;value.ids[node.get_instance_id()]=id
	if attach:value.parents[id%2].add_child(node)
	return node
func scene(script)->Dictionary:
	var room:=Node3D.new();root.add_child(room);room.set_meta("native_enhanced_lighting",true)
	var owner=script.new();room.add_child(owner);owner.configure(room);owner.set_process(false);owner.enable_history(2)
	var camera:=Camera3D.new();room.add_child(camera);camera.position=Vector3(0,3,20);camera.look_at(Vector3.ZERO)
	owner.history_camera=weakref(camera);owner.set_area([.1,.2,.3],[.3,.2,.1])
	var value: Dictionary={"room":room,"focus":owner,"camera":camera,"parents":[],"lamps":{},"ids":{},"owners":{},"calls":[]}
	for id in 2:
		var parent:=Node3D.new();parent.set_meta("native_light_source",true);room.add_child(parent);value.parents.append(parent);value.owners[parent.get_instance_id()]=id+1
	for id in 8:lamp(value,id)
	return value
func normalize_id(value: Dictionary,id: int)->int:
	return int(value.ids.get(id,-999999))
func native_result(value: Dictionary)->Dictionary:
	if value.focus.history==null:return {}
	var result: Dictionary=value.focus.history.dispatch(2,{})
	for name in ["order","collected","active0","active1"]:
		result[name]=result[name].map(func(id):return normalize_id(value,int(id)))
	for call in result.calls:
		if call.has("id"):call.id=normalize_id(value,int(call.id))
	for row in result.lights:row.id=normalize_id(value,int(row.id))
	# The diagnostic snapshot sorts physical ObjectIDs, which differ between
	# these two actual worlds; solver/registration order arrays stay untouched.
	result.lights.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return result
func rows(value: Dictionary)->Dictionary:
	var result: Dictionary={}
	for id in value.focus.history_rows:
		var row: Dictionary=value.focus.history_rows[id].duplicate(true)
		row.id=normalize_id(value,int(row.id));row.owner=int(value.owners.get(int(row.owner),0));result[row.id]=row
	return result
func states(value: Dictionary)->Dictionary:
	var result: Dictionary={}
	for id in value.lamps:
		var node: Object=value.lamps[id]
		if not is_instance_valid(node):continue
		result[id]={"admitted":node.native_admitted,"fade":node.native_fade,"visible":node.visible,"color":node.light_color,"energy":node.light_energy,"range":node.omni_range,"state":node.native_state.duplicate(true),"properties":node.native_properties.duplicate(true),"revision":node.native_properties_revision,"shadow":node.shadow_enabled}
	return result
func frame(previous: Dictionary,current: Dictionary,name: String,delta: float=0.1)->void:
	previous.calls.clear();current.calls.clear()
	previous.focus.history_frame(delta);current.focus.history_frame(delta)
	check(native_result(previous)==native_result(current),name+": exact native order/collection/calls/slots/both fade channels")
	check(rows(previous)==rows(current) and states(previous)==states(current),name+": retained inputs and actual physical light state match")
	check(previous.focus.history_static_fallbacks==current.focus.history_static_fallbacks and previous.focus.history_static_suppressed==current.focus.history_static_suppressed,name+": exact static-only counters")
	var published: Array=current.calls.map(func(row):return int(row[0]))
	var reference: Array=previous.calls.filter(func(row):return int(row[0]) in published)
	check(reference==current.calls,name+": setter entries are an order-preserving exact subset of current production")
	comparisons.append({"name":name,"previous_calls":previous.calls.size(),"current_calls":current.calls.size()})
func run()->void:
	var output:="";var baseline:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--baseline="):baseline=argument.trim_prefix("--baseline=")
	if output.is_empty() or baseline.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(FileAccess.get_sha256(baseline)==BASELINE_SHA,"Exact dirty prechange Focus owner is the reference")
	check(ClassDB.class_exists("NwnLightHistory"),"Actual existing compiled native history is loaded without a build")
	var source:=GDScript.new();source.source_code=FileAccess.get_file_as_string(baseline)
	check(source.reload()==OK,"Unmodified current production reference compiles")
	if not failures.is_empty():quit(1);return
	var previous:=scene(source);var current:=scene(Focus)
	frame(previous,current,"initial publication")
	check(not current.lamps[6].native_admitted and current.lamps[6].native_fade==0,"New out-of-collection lamp receives initial off-slot suppression")
	for turn in 3:frame(previous,current,"warming fade "+str(turn))
	frame(previous,current,"settle",10.0)
	frame(previous,current,"unchanged settled")
	check(current.calls.size()<previous.calls.size() and not current.calls.any(func(row):return int(row[0])==4 or int(row[0])==6),"Unchanged static fallback and inactive lamp avoid repeated setter entry")
	var hidden_before: Dictionary=states(current)
	for value in [previous,current]:value.parents[1].hide()
	frame(previous,current,"hidden parent")
	check(not current.calls.any(func(row):return int(row[0]) in [1,3,7]) and current.lamps[1].native_admitted==hidden_before[1].admitted and current.lamps[1].native_fade==hidden_before[1].fade,"Formerly eligible hidden lights retain own admission/fade without a new setter")
	for value in [previous,current]:value.parents[1].show()
	frame(previous,current,"parent re-entry")
	for value in [previous,current]:value.lamps[6].set_meta("native_light_priority",4)
	frame(previous,current,"metadata-only priority")
	check(current.calls.any(func(row):return int(row[0])==6),"Dirty unselected metadata row reaches actual admission facade")
	for value in [previous,current]:value.lamps[2].publish_native_light(Color(2,.3,.2),17,3,0,.7)
	frame(previous,current,"animated HDR and support radius")
	for value in [previous,current]:value.focus.focus=Vector3(495,0,0)
	frame(previous,current,"focus movement and slot transition")
	for value in [previous,current]:value.parents[0].position.x+=3;value.camera.position.x+=4;value.camera.far=110
	frame(previous,current,"source and camera movement")
	for value in [previous,current]:value.focus.set_blind_lights(value.parents[0])
	frame(previous,current,"only-owner suppresses static fallback")
	check(current.focus.history_static_suppressed==1 and not current.lamps[4].native_admitted,"Only-owner applies explicit static fallback suppression")
	frame(previous,current,"unchanged only-owner")
	check(not current.calls.any(func(row):return int(row[0])==4),"Unchanged only-owner static suppression is not republished")
	for value in [previous,current]:value.focus.set_blind_lights(null)
	frame(previous,current,"only-owner release")
	check(current.lamps[4].native_admitted and current.lamps[4].native_fade==1.0,"Only-owner release restores static fallback exactly")
	for value in [previous,current]:
		var props: Dictionary=value.lamps[4].native_properties.duplicate(true);props.isdynamic=1;props.affectdynamic=1;value.lamps[4].configure(props)
	frame(previous,current,"static becomes finite dynamic")
	for value in [previous,current]:
		var props: Dictionary=value.lamps[4].native_properties.duplicate(true);props.isdynamic=0;props.affectdynamic=0;value.lamps[4].configure(props)
	frame(previous,current,"finite becomes static-only")
	for value in [previous,current]:
		var props: Dictionary=value.lamps[0].native_properties.duplicate(true);props.radius=1000.0;value.lamps[0].configure(props)
	frame(previous,current,"finite becomes excluded area lamp")
	check(not current.calls.any(func(row):return int(row[0])==0),"Ineligible radius1000 row receives no new admission setter")
	for value in [previous,current]:
		var props: Dictionary=value.lamps[0].native_properties.duplicate(true);props.radius=8.0;value.lamps[0].configure(props)
	frame(previous,current,"finite re-entry")
	for value in [previous,current]:value.focus.disable_history()
	check(states(previous)==states(current) and current.focus.history_draw_ids.is_empty() and current.focus.history_static_ids.is_empty(),"Disable restores all actual lamps and clears publication subsets")
	for value in [previous,current]:value.focus.enable_history(2)
	frame(previous,current,"history re-enable initial publication")
	for value in [previous,current]:value.lamps[3].free();value.lamps[3]=null
	frame(previous,current,"normal unregister and retirement")
	for value in [previous,current]:value.lamps[4].focus_owner=null;value.lamps[4].free();value.lamps[4]=null
	frame(previous,current,"invalid weak tombstone cleanup")
	for value in [previous,current]:
		for id in [8,9,10]:lamp(value,id,false)
		for id in [10,8,9]:value.parents[id%2].add_child(value.lamps[id])
	frame(previous,current,"same-frame births in non-ID registration order")
	check(current.calls.filter(func(row):return int(row[0]) in [8,9,10]).map(func(row):return int(row[0]))==[10,8,9],"New publications follow physical registration order instead of numeric ID order")
	for value in [previous,current]:value.focus.register(value.lamps[8])
	frame(previous,current,"duplicate physical register")
	for value in [previous,current]:value.focus.disable_history();value.focus.enable_history(2)
	frame(previous,current,"reset after births")
	for value in [previous,current]:value.focus.close()
	check(current.focus.history_draw_ids.is_empty() and current.focus.history_static_ids.is_empty() and current.focus.members.is_empty(),"Close clears all publication subsets and physical membership")
	previous.room.free();current.room.free();previous.clear();current.clear();source=null
	await process_frame
	var result: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"comparisons":comparisons,"baseline_sha256":BASELINE_SHA,"scope":"Actual prechange versus candidate Focus history owners, existing compiled NwnLightHistory and actual ModelPointLight admission/configure facade in a headless SceneTree. Authored source mutations and setter observers; registry/native solver untouched. No GPU, server, loading or live FPS benefit acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_LIGHT_PUBLICATION_CACHE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
