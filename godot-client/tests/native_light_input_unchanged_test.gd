extends SceneTree
const SOURCE="extends Node3D\nvar native_properties: Dictionary={}\nvar native_state: Dictionary={}\nvar native_properties_revision: int=0\n"
var checks:=0
var failures: Array=[]
var options: Dictionary={}
var observations: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func scene(kind: String,count: int) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var writer:=GDScript.new();writer.source_code=SOURCE;check(writer.reload()==OK,"Typed input writer compiles")
	var registry: RefCounted=ClassDB.instantiate(kind)
	if kind=="NwnBuiltinLightInputRegistry":check(registry.call("dispatch",6,{"script":writer,"sha256":SOURCE.sha256_text()}).get("accepted",false),"Actual typed writer enrolls")
	var state:={"host":host,"registry":registry,"writer":writer,"nodes":[],"ids":{},"source":host.get_instance_id()}
	state.ids[host.get_instance_id()]=-1
	for index in count:
		var node=writer.new();host.add_child(node);node.position=Vector3(float(index%20)-10.0,0,float(index/20)-15.0)
		node.native_properties={"radius":8.0,"color":[0.8,0.4,0.2],"multiplier":1.0,"lightpriority":4,"isdynamic":1,"affectdynamic":1,"fadinglight":1}
		node.native_state={"range":12.0};node.native_properties_revision=1
		node.set_meta("native_enhanced_light",true);node.set_meta("native_light_priority",0)
		state.nodes.append(node);state.ids[node.get_instance_id()]=index
		registry.call("dispatch",0,{"id":node.get_instance_id(),"source":host.get_instance_id()})
	return state
func poll(state: Dictionary,planes: Array=[],changed: bool=false) -> Dictionary:
	return state.registry.call("dispatch",1,{"planes":planes,"view_changed":changed})
func normalize(update: Dictionary,state: Dictionary) -> Dictionary:
	var value:=update.duplicate(true);value.erase("unchanged_fast_rows")
	for row in value.get("rows",[]):row.id=state.ids.get(int(row.id),-999);row.owner=state.ids.get(int(row.owner),-999)
	for key in ["removed","retired"]:
		if value.has(key):value[key]=value[key].map(func(id):return state.ids.get(int(id),-999))
	return value
func compare(_a: Dictionary,b: Dictionary,label: String,planes: Array=[],changed: bool=false) -> Dictionary:
	var current:=poll(b,planes,changed)
	check(not current.has("error"),label)
	# Compare these normalized observations across the exact accepted D executable
	# and the changed executable; no second implementation is invented in GDScript.
	observations.append({"label":label,"update":normalize(current,b)})
	return current
func close_scene(state: Dictionary) -> void:
	state.registry.call("dispatch",8,{});state.host.free();state.clear()
func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	var a: Dictionary={};var b:=scene("NwnBuiltinLightInputRegistry",64)
	compare(a,b,"Initial output matches retained native extension")
	var quiet:=compare(a,b,"Unchanged output reuses identical rows")
	if not OS.get_cmdline_user_args().has("--light-input-unchanged=reference") and quiet.has("unchanged_fast_rows"):check(int(quiet.unchanged_fast_rows)==64,"All unchanged typed rows use the native fast path")
	for state in [b]:state.nodes[0].position.x+=2
	compare(a,b,"Direct position changes invalidate current input")
	for state in [b]:state.host.position=Vector3(2,1,-3)
	compare(a,b,"Ancestor transform changes are visible before notifications")
	for state in [b]:state.nodes[1].native_state.range=3.5
	compare(a,b,"In-place range changes invalidate without an authored revision")
	for state in [b]:state.nodes[2].set_meta("native_light_priority",9)
	compare(a,b,"Existing priority metadata changes invalidate")
	for state in [b]:state.nodes[3].set_meta("native_enhanced_light",false)
	compare(a,b,"Enhanced metadata removal hides the existing row")
	for state in [b]:state.nodes[3].set_meta("native_enhanced_light",true)
	compare(a,b,"Enhanced metadata restoration republishes")
	for state in [b]:state.nodes[4].native_properties.color=[2.0,0.0,0.0];state.nodes[4].native_properties_revision+=1
	compare(a,b,"Authored color and revision updates republish")
	for state in [b]:state.nodes[5].native_properties.radius=1000
	compare(a,b,"In-place radius eligibility changes remain visible")
	for state in [b]:state.nodes[5].native_properties.radius=8
	compare(a,b,"Finite-radius re-entry restores the row")
	var planes: Array=[Plane(Vector3(1,0,0),0),Plane(Vector3(-1,0,0),100),Plane(Vector3(0,1,0),100),Plane(Vector3(0,-1,0),100),Plane(Vector3(0,0,1),0),Plane(Vector3(0,0,-1),100)]
	compare(a,b,"Changed camera planes preserve exact view tests and rows",planes,true)
	compare(a,b,"Unchanged camera planes retain current views",planes,false)
	for state in [b]:state.host.hide()
	compare(a,b,"Hidden parents remove current rows",planes,false)
	for state in [b]:state.host.show()
	compare(a,b,"Shown parents republish current rows",planes,false)
	for state in [b]:state.nodes[6].free();state.nodes[6]=null
	compare(a,b,"Retired nodes release tombstones",planes,false)
	for state in [b]:state.registry.call("dispatch",2,{"id":state.nodes[7].get_instance_id()});state.registry.call("dispatch",0,{"id":state.nodes[7].get_instance_id(),"source":state.source})
	compare(a,b,"Same-node unregister and rebind matches original output",planes,false)
	for state in [b]:state.registry.call("dispatch",4,{})
	compare(a,b,"Reset republishes existing rows",planes,false)
	close_scene(b);await process_frame
	var benchmark:=bench()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"benchmark":benchmark,"reference":OS.get_cmdline_user_args().has("--light-input-unchanged=reference"),"scope":"Normalized current-input observations compared across accepted D and candidate executables plus normal-engine component timing. No live FPS claim."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_LIGHT_UNCHANGED ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func summary(values: Array) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in sorted:total+=float(value)
	return {"samples":sorted.size(),"mean_us":total/sorted.size(),"median_us":sorted[sorted.size()/2],"p95_us":sorted[int(sorted.size()*0.95)],"p99_us":sorted[int(sorted.size()*0.99)]}
func bench() -> Dictionary:
	var state:=scene("NwnBuiltinLightInputRegistry",600);poll(state)
	for warm in 80:poll(state)
	var output: Dictionary={}
	for mode in ["stationary","animated"]:
		var times: Array=[];var fast_rows:=0
		for turn in 600:
			if mode=="animated":
				var node=state.nodes[turn%state.nodes.size()];node.position.x+=0.01;node.native_properties_revision+=1
			var began:=Time.get_ticks_usec();var result:=poll(state);times.append(Time.get_ticks_usec()-began);fast_rows+=int(result.get("unchanged_fast_rows",0))
		output[mode]=summary(times);output[mode].fast_rows=fast_rows
	close_scene(state);return output
