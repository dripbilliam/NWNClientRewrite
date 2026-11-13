extends "res://tests/native_gamma_pixels_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const TonalOriginal=preload("res://tests/original_postprocess_oracle.gd")
func frame_image() -> Image:
	await settle(8); await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var path:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	root.size=Vector2i(1280,800); var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original shader catalog mounts read-only")
	var original:=TonalOriginal.new(); var world:=Node3D.new(); root.add_child(world)
	var env:=WorldEnvironment.new(); world.add_child(env); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera)
	var layer:=CanvasLayer.new(); root.add_child(layer); var marker:=ColorRect.new(); layer.add_child(marker); marker.position=Vector2(8,8); marker.size=Vector2(24,24); marker.color=Color(.4,.2,.8)
	var outputs: Array=[]
	for native_output in [false,true]:
		var file_path:=path+(".native.cfg" if native_output else ".regular.cfg")
		var config:=ConfigFile.new(); config.set_value("interface","creature_slots",true); config.set_value("rendering","gore",2); config.set_value("rendering","gamma",2.2); config.save(file_path)
		gamma.effect.set_surface_output(native_output)
		var raw:=Color(.08,.15,.3); env.environment.background_color=raw.linear_to_srgb() if native_output else raw
		var menu:=Settings.new(); layer.add_child(menu); menu.setup(file_path,""); menu.show()
		check(gamma.bind_settings(menu),"Production gamma owner binds the actual Client Options service")
		var baseline: Image=await frame_image(); var ui_color:=baseline.get_pixel(16,16); var neutral:=baseline.get_pixel(64,16)
		for value in [1.2,3.0,2.2]:
			menu.gamma_control.value=value
			var image: Image=await frame_image(); var actual:=image.get_pixel(64,16); var expected:=Color.BLACK
			if native_output:
				var result: PackedFloat32Array=original.execute(catalog,16,TonalOriginal.inputs(TonalOriginal.Post.empty_frame(),raw,{"mask":16},value))
				check(result.size()==4 and original.failure.is_empty(),"Original retail Gamma/tonemap functions execute for actual UI value")
				if result.size()!=4: continue
				expected=Color(result[0],result[1],result[2])
			else: expected=Color(pow(neutral.r,value/2.2),pow(neutral.g,value/2.2),pow(neutral.b,value/2.2))
			var error:=0.0
			for c in 3: error=maxf(error,absf(actual[c]-expected[c]))
			check(error<.009,"Actual settings input changes final world pixels "+str([native_output,value])+" error="+str(error))
			check(image.get_pixel(16,16)==ui_color,"Gamma input leaves GUI colors unchanged")
			check(is_equal_approx(gamma.snapshot().gamma,value) and is_equal_approx(menu.gamma_value,value),"Displayed setting and actual renderer gamma agree")
			outputs.append({"native":native_output,"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":[expected.r,expected.g,expected.b],"max_error":error})
		# Keyboard commit traverses the real LineEdit/SpinBox input path.
		var edit:=menu.gamma_control.get_line_edit(); edit.grab_focus(); edit.text="1.20"
		check(menu.visible and edit.has_focus(),"Keyboard fixture opens Client Options and focuses its actual numeric editor")
		var key:=InputEventKey.new(); key.keycode=KEY_ENTER; key.pressed=true; root.push_input(key); key=key.duplicate(); key.pressed=false; root.push_input(key)
		await settle(4)
		check(is_equal_approx(menu.gamma_control.value,1.2) and is_equal_approx(gamma.snapshot().gamma,1.2),"Focused numeric keyboard commit reaches the active renderer")
		config.load(file_path); check(is_equal_approx(config.get_value("rendering","gamma"),1.2) and config.get_value("rendering","gore")==2 and config.get_value("interface","creature_slots"),"Gamma persistence preserves independent rendering/interface preferences")
		menu.close_button.pressed.emit(); await settle(2); check(not menu.visible,"Client Options close preserves its applied gamma")
		var reopened:=Settings.new(); layer.add_child(reopened); reopened.setup(file_path,""); reopened.show(); check(gamma.bind_settings(reopened),"Reopened settings replace the old signal owner")
		check(is_equal_approx(reopened.gamma_control.value,1.2) and is_equal_approx(gamma.snapshot().gamma,1.2),"Reopened control and renderer restore saved gamma")
		menu.gamma_control.value=3.4; check(is_equal_approx(gamma.snapshot().gamma,1.2),"Retired settings cannot change the newly bound renderer")
		gamma.set_gamma(3.0); check(gamma.bind_settings(reopened,true) and is_equal_approx(gamma.snapshot().gamma,3.0),"Explicit launch override retains its established precedence")
		reopened.gamma_control.value=1.8; check(is_equal_approx(gamma.snapshot().gamma,1.8),"Actual user input can change gamma after the launch override")
		var unrelated:=Node.new(); root.add_child(unrelated); check(not gamma.bind_settings(unrelated) and gamma.snapshot().settings_bound,"Rejected settings source cannot replace a working binding"); unrelated.free()
		gamma.unbind_settings(); reopened.gamma_control.value=2.2; check(not gamma.snapshot().settings_bound and is_equal_approx(gamma.snapshot().gamma,1.8),"Detached settings callbacks cannot change the renderer")
		menu.free(); reopened.free()
	var state:=gamma.snapshot(); gamma.free(); original.close(); world.free(); layer.free(); await settle(3)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":outputs,"gamma":state,"publicConnections":0,"scope":"Actual Client Options number/keyboard/close/reopen/persistence inputs through production gamma binding to real world pixels, regular and native-output modes, unchanged original retail Gamma/tonemap oracle, GUI preservation, stale ownership and explicit override priority. Complete original graphics/UI parity remains open."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
