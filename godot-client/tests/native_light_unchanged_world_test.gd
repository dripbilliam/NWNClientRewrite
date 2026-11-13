extends SceneTree
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
var options: Dictionary={}
var observations: Array=[]
var failures: Array=[]
var checks:=0
var world: Node3D
var owner
var camera: Camera3D
var parents: Array=[]
var lamps: Array=[]
var identities: Dictionary={}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func normalized(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:
			if key in ["id","owner"] and value[key] is int:result[key]=identities.get(int(value[key]),-999)
			elif key in ["order","collected","active0","active1"] and value[key] is Array:result[key]=value[key].map(func(id):return identities.get(int(id),-999))
			else:result[key]=normalized(value[key])
		return result
	if value is Array:return value.map(normalized)
	return value
func frame(label: String,delta: float=0.1) -> void:
	owner.history_frame(delta)
	check(owner.history_error.is_empty(),label+": actual history owner remains valid")
	var history: Dictionary=normalized(owner.history.dispatch(2,{}));history.lights.sort_custom(func(a,b):return int(a.id)<int(b.id))
	var physical: Array=[]
	for lamp in lamps:
		if not is_instance_valid(lamp):continue
		physical.append({"id":identities[lamp.get_instance_id()],"admitted":lamp.native_admitted,"fade":lamp.native_fade,"visible":lamp.visible,"color":lamp.light_color,"energy":lamp.light_energy,"range":lamp.omni_range,"state":lamp.native_state.duplicate(true)})
	observations.append({"label":label,"history":history,"physical":physical})
func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	world=Node3D.new();root.add_child(world);world.set_meta("native_enhanced_lighting",true)
	owner=Focus.new();world.add_child(owner);owner.configure(world);owner.set_process(false);owner.enable_history(8)
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,3,20);camera.look_at(Vector3.ZERO);owner.history_camera=weakref(camera)
	owner.set_area([0.1,0.2,0.3],[0.3,0.2,0.1])
	for index in 2:
		var parent:=Node3D.new();parent.set_meta("native_light_source",true);world.add_child(parent);parents.append(parent);identities[parent.get_instance_id()]=100+index
	for index in 48:
		var lamp:=Point.new();lamp.set_meta("native_enhanced_light",true)
		lamp.configure({"radius":1000.0 if index==47 else 8.0,"color":[0.8,0.4,0.2],"multiplier":1.0,"isdynamic":0 if index==46 else 1,"affectdynamic":0 if index==46 else 1,"lightpriority":index%3,"fadinglight":1})
		lamp.position=Vector3(float(index%8)-4,0,float(index/8)-3);parents[index%2].add_child(lamp);lamps.append(lamp);identities[lamp.get_instance_id()]=index
	check(owner.input_registry_snapshot().effective=="builtin","Actual Focus uses builtin input registry")
	frame("initial")
	for index in 8:frame("warming "+str(index))
	frame("settled",10.0);frame("unchanged settled")
	parents[0].position=Vector3(3,0,-2);frame("moving source before transform notifications")
	lamps[2].position.x+=2;frame("moving lamp")
	lamps[3].publish_native_light(Color(0.2,1.4,0.7),6.0,4.0,1.0,1.8);frame("actual animated color/radius publication")
	lamps[4].set_meta("native_light_priority",9);frame("priority metadata")
	camera.position.x+=8;camera.look_at(Vector3.ZERO);frame("moving camera")
	camera.fov=42;frame("camera projection")
	parents[0].hide();frame("hidden parent")
	parents[0].show();frame("shown parent")
	owner.set_blind_lights(parents[1]);frame("only owner")
	frame("only-owner fades advance with unchanged inputs")
	owner.set_blind_lights();frame("only-owner release")
	lamps[5].reparent(parents[0],true);frame("reparent and re-register")
	lamps[6].free();lamps[6]=null;frame("retirement")
	owner.disable_history();owner.enable_history(8);frame("history reset")
	var state: Dictionary=owner.input_registry_snapshot();var fast:=int(state.get("typed_reader",{}).get("unchanged_fast_rows_total",0))
	if state.get("typed_reader",{}).has("unchanged_fast_rows_total"):check(fast>0,"Real canonical lights use the unchanged native path")
	owner.close();check(owner.members.is_empty() and owner.input_registry_snapshot().closed,"World close releases registry membership")
	world.free();world=null;owner=null;lamps.clear();parents.clear();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"fast_rows":fast,"scope":"Actual Focus, canonical Point lights and original native history/fades/publication. Normalized snapshots compared across accepted and optimized engines; no live FPS claim."}
	var output:=FileAccess.open(options.report,FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close();print("NATIVE_LIGHT_UNCHANGED_WORLD ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
