extends SceneTree
const Baseline=preload("res://baseline/native_light_palette.gd")
const Candidate=preload("res://candidate/native_light_palette.gd")
var checks:=0
var failures: Array=[]
var output:=""
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func snapshot(palette,label: String,rows: Array)->void:
	var data: PackedByteArray=palette.image.get_data()
	rows.append({"label":label,"image":data.hex_encode().sha256_text(),"active":palette.active.keys(),"free":palette.free_slots.duplicate(),"revision":palette.revision,"flushes":palette.flushes})
func execute(palette)->Array:
	palette.ensure()
	var owner:=Node.new();root.add_child(owner)
	var slots: Array=[];var rows: Array=[]
	var state:={"range":16.0,"inverse":.4,"factor":12.0,"ambient":false,"color":Vector3(.3,.5,.7)}
	for index in 8:
		var slot: int=palette.acquire(owner);slots.append(slot)
		palette.update(slot,Vector3(index,0,0),state)
	palette.flush();snapshot(palette,"initial active palette",rows)
	for step in 40:
		state.color=Vector3(float(step)/40.0,.3,.7)
		for index in slots.size():palette.update(slots[index],Vector3(index,0,0),state)
		palette.flush();snapshot(palette,"color/fade-only publication "+str(step),rows)
	state.range=32.0
	for slot in slots:palette.update(slot,Vector3(2,-3,4),state)
	palette.flush();snapshot(palette,"new position and support",rows)
	for entry in [[-.1,.4,12.0,false],[0.0,.2,5.0,true],[1000.0,.5,7.0,false],[.5,.4,12.0,false]]:
		state.range=entry[0];state.inverse=entry[1];state.factor=entry[2];state.ambient=entry[3]
		for slot in slots:palette.update(slot,Vector3(2,-3,4),state)
		palette.flush();snapshot(palette,"support/falloff/ambient "+str(entry),rows)
	for slot in slots:palette.release(slot)
	palette.flush();snapshot(palette,"all released",rows)
	for slot in slots:palette.update(slot,Vector3(99,0,0),state);palette.release(slot)
	palette.flush();snapshot(palette,"stale writes and repeated release ignored",rows)
	var reused: int=palette.acquire(owner)
	palette.update(reused,Vector3(2,-3,4),state);palette.flush();snapshot(palette,"same-value slot lifetime reuse restores active alpha",rows)
	check(palette.image.get_pixel(1,reused).a==1.0,"Reused slot is enabled even when shape matches retired lifetime")
	palette.release(reused);palette.flush();snapshot(palette,"retired reused slot",rows)
	check(palette.active.is_empty() and palette.free_slots.size()==palette.CAPACITY,"All palette lifetimes retire without capacity leak")
	owner.free()
	for name in ["nwn_native_lights","nwn_native_ambient","nwn_native_environment"]:RenderingServer.global_shader_parameter_remove(name)
	return rows
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var previous:=execute(Baseline);var current:=execute(Candidate)
	check(previous.size()==current.size(),"Same exact authored boundary sequence executes")
	for index in previous.size():
		var a: Dictionary=previous[index].duplicate();var b: Dictionary=current[index].duplicate()
		a.erase("revision");a.erase("flushes");b.erase("revision");b.erase("flushes")
		check(a==b,"Byte-exact palette image, membership and allocation order: "+a.label)
		check(current[index].revision<=previous[index].revision and current[index].flushes<=previous[index].flushes,"Candidate never adds uploads or revisions: "+a.label)
	check(previous[40].flushes-previous[0].flushes==40,"Original uploads identical palette once for each color-only frame")
	check(current[40].flushes-current[0].flushes==0,"Retained values eliminate all 40 identical image uploads")
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"stages":previous.size(),"baseline":previous,"candidate":current,"gpu":false,"serverConnections":0,"scope":"Isolated headless actual palette implementation comparison. Hashes compare every image byte plus exact slot membership/allocation order. Upload/revision counters are expected to differ because redundant updates are removed. GPU texture execution, room pixels and FPS remain untested."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_PERF140_RENDER_LIGHT_PALETTE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
