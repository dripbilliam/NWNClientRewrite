extends SceneTree
const Palette = preload("res://systems/native_render/native_light_palette.gd")
var checks := 0
var failures: Array[String] = []
var report_path := ""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	Palette.ensure()
	var original_texture_id := Palette.texture.get_instance_id(); var original_rid := Palette.texture.get_rid()
	var initial := Palette.upload_snapshot(); var initial_bytes := initial.get_data()
	check(initial != Palette.image,"new Image object, not same mutable object")
	check(initial.get_width()==2 and initial.get_height()==2016 and initial.get_format()==Image.FORMAT_RGBAF and not initial.has_mipmaps(),"exact dimensions/format/mipmaps")
	var owner := Node.new(); root.add_child(owner); var slot := Palette.acquire(owner)
	var state := {"range":8.0,"inverse":2.0,"factor":0.2,"ambient":false}
	var retained: Array[Image] = []; var expected: Array[PackedByteArray] = []
	for index in 48:
		Palette.update(slot,Vector3(index,-index,index*0.5),state)
		var snapshot := Palette.upload_snapshot(); retained.append(snapshot); expected.append(snapshot.get_data())
		Palette.flush()
		check(Palette.texture.get_instance_id()==original_texture_id and Palette.texture.get_rid()==original_rid,"same GPU texture "+str(index))
		check(not Palette.dirty,"unchanged callback clears dirty "+str(index))
	check(initial.get_data()==initial_bytes,"initial immutable creation bytes remain unchanged")
	for index in retained.size():
		check(retained[index].get_data()==expected[index],"all retained upload bytes stable "+str(index))
		check(retained[index].get_pixel(0,slot)==Color(index,-index,index*0.5,8),"retained RGBAF values "+str(index))
	var before_flushes := Palette.flushes; Palette.flush()
	check(Palette.flushes==before_flushes,"clean flush does not publish")
	var edited := {"done":false}
	var listener := func():
		if not edited.done:
			edited.done=true; Palette.update(slot,Vector3(123,456,789),state)
	Palette.texture.changed.connect(listener)
	Palette.update(slot,Vector3(1,2,3),state); Palette.flush()
	check(edited.done and Palette.dirty,"changed callback publication remains dirty")
	Palette.texture.changed.disconnect(listener); listener=Callable(); Palette.flush()
	check(not Palette.dirty and Palette.image.get_pixel(0,slot)==Color(123,456,789,8),"following flush keeps callback color/position publication")
	var before_release := Palette.upload_snapshot(); var before_release_bytes := before_release.get_data()
	Palette.release(slot); Palette.flush()
	check(before_release.get_data()==before_release_bytes,"release cannot mutate queued snapshot")
	check(Palette.image.get_pixel(1,slot)==Color(0,0,0,0),"release publishes exact disabled row")
	var weak: WeakRef = weakref(retained[0]); retained.clear(); expected.clear()
	check(weak.get_ref()==null,"unreferenced snapshot Image retires")
	check(Palette.texture.get_instance_id()==original_texture_id and Palette.texture.get_rid()==original_rid,"release retains GPU texture identity")
	owner.free(); initial=null; before_release=null
	RenderingServer.global_shader_parameter_remove("nwn_native_lights")
	RenderingServer.global_shader_parameter_remove("nwn_native_ambient")
	RenderingServer.global_shader_parameter_remove("nwn_native_environment")
	Palette.image=null; Palette.texture=null; Palette.environment_texture=null; Palette.empty_environment=null; Palette.active.clear(); Palette.free_slots.clear()
	await process_frame; await process_frame
	var result := {"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"scope":"Actual palette immutable Image/COW bytes, exact values, same texture/RID, synchronous changed callback and retirement; headless no GPU race acceptance."}
	var file := FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_palette_upload_test","checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
