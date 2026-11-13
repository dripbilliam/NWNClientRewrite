extends "res://tests/native_particle_schedule_test.gd"
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const BASELINE_SHA="253be5a2a0d6467e95de927a0731e8ed4db13c7084c200b7e61a785ededa2a88"
func authored_rows(value: Dictionary) -> Dictionary:
	var rows: Dictionary=value.duplicate(true)
	for row in rows.values():
		if int(row.get("override",0))==0: row.erase("override")
	return rows
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("baseline") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(FileAccess.get_sha256(args.baseline)==BASELINE_SHA,"Reference is the verified prior source checkpoint")
	var archive:=ZIPReader.new(); check(archive.open(args.baseline)==OK,"Prior source checkpoint opens read-only")
	var source:=archive.read_file("systems/native_render/focus_lighting.gd"); archive.close()
	var original:=GDScript.new(); original.source_code=source.get_string_from_utf8()
	check(original.reload()==OK,"Unchanged prior production history owner compiles as the comparison")
	if not failures.is_empty(): quit(1); return
	var world:=Node3D.new(); root.add_child(world); world.set_meta("native_enhanced_lighting",true)
	var previous: Node=original.new(); world.add_child(previous); previous.configure(world); previous.set_process(false); previous.enable_history(24)
	var current:=Focus.new(); world.add_child(current); current.configure(world); current.set_process(false); current.enable_history(24)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,4,18); camera.look_at(Vector3.ZERO); camera.make_current()
	previous.history_camera=weakref(camera); current.history_camera=weakref(camera)
	var parents: Array=[]
	for n in 3:
		var owner:=Node3D.new(); owner.set_meta("native_light_source",true); world.add_child(owner); parents.append(owner)
	var lamps: Array=[]
	for n in 421:
		var light:=Point.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.2+float(n%7)*.1,.3,.5],"radius":3.0+n%9,"fadinglight":int(n%4!=0),"lightpriority":n%5,"isdynamic":int(n%7!=0),"affectdynamic":int(n%7!=0)})
		parents[n%3].add_child(light); light.position=Vector3(float(n%21)-10,float(n%3),float(n/21)-10); light.force_update_transform(); previous.register(light); lamps.append(light)
	var timings:={"previous_usec":[],"current_usec":[]}; var visibility_checks:=0
	for frame in 240:
		if frame==20: lamps[0].publish_native_light(Color(2.0,.4,.1),7,0,0,.8)
		if frame==30: parents[1].hide()
		if frame==35: parents[1].show()
		if frame==40: lamps[3].free(); lamps[3]=null
		if frame==45:
			var light:=Point.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.7,.1,.2],"radius":5,"fadinglight":0}); parents[0].add_child(light); previous.register(light); lamps[3]=light
		if frame in [50,60]:
			var owner: Node3D=parents[0] if frame==50 else null
			check(previous.set_blind_lights(owner) and current.set_blind_lights(owner),"Both owners accept the same physical only-Gob scope")
		if frame in [70,80]:
			var props: Dictionary=lamps[2].get_meta("native_model_light_properties").duplicate(true); props.radius=1000 if frame==70 else 6; lamps[2].configure(props)
		if frame==90: lamps[4].position=Vector3(120,0,120); lamps[4].force_update_transform()
		if frame==100: camera.position=Vector3(0,3,-18); camera.look_at(Vector3.ZERO); camera.force_update_transform()
		if frame==110: parents[2].position=Vector3(4,0,2); parents[2].force_update_transform()
		if frame==120:
			previous.disable_history(); current.disable_history(); previous.enable_history(24); current.enable_history(24)
		if frame==150:
			var props: Dictionary=lamps[1].get_meta("native_model_light_properties").duplicate(true); props.isdynamic=0; props.affectdynamic=0; lamps[1].configure(props)
		if frame==160:
			var props: Dictionary=lamps[1].get_meta("native_model_light_properties").duplicate(true); props.isdynamic=1; lamps[1].configure(props)
		var point:=Vector3(sin(frame*.01)*4,0,cos(frame*.01)*4)
		for owner in [previous,current]: owner.focus=point; owner.set_area([.3,.4,.5],[.2,.1,.3])
		var prior_states: Array=[]; var next_states: Array=[]
		var began:=Time.get_ticks_usec(); previous.history_frame(.016); var prior_usec:=Time.get_ticks_usec()-began
		for light in lamps:
			if is_instance_valid(light): prior_states.append([light.get_instance_id(),light.native_admitted,light.native_fade,light.visible])
		began=Time.get_ticks_usec(); current.history_frame(.016); var next_usec:=Time.get_ticks_usec()-began
		for light in lamps:
			if is_instance_valid(light): next_states.append([light.get_instance_id(),light.native_admitted,light.native_fade,light.visible])
		check(previous.history.dispatch(2,{})==current.history.dispatch(2,{}),"Exact prior solver ordering, collected identities, both fade channels and draw/disable calls at frame "+str(frame))
		check(prior_states==next_states,"Exact physical lamp admission/fade/visibility at frame "+str(frame)); visibility_checks+=prior_states.size()
		check(authored_rows(previous.history_rows)==authored_rows(current.history_rows),"Exact live input rows, normalizing the added neutral override field at frame "+str(frame))
		if frame>=180: timings.previous_usec.append(prior_usec); timings.current_usec.append(next_usec)
		if frame%30==0: await process_frame
	var state:=current.snapshot(); check(current.history_input_reused>current.history_input_rows*5,"Unchanged authored inputs are reused while the history still steps every frame")
	check(int(current.history_result.steps)==120,"Re-enabled history keeps exact rendered-frame step count")
	previous.close(); current.close(); world.free(); original=null; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"visibility_comparisons":visibility_checks,"focus":state,"timings":timings,"baseline_sha256":BASELINE_SHA,"publicConnections":0,"scope":"Paired actual production history owners: prior verified checkpoint versus incremental publication across421 lights, authored animation/HDR/range, focus/frustum/source transforms, hidden parents, retirement/replacement, exact only-Gob scope, static/dynamic and finite/area changes, and disable/re-enable. Headless CPU fixture; no GPU or dense-room FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
