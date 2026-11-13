extends SceneTree
const Preferences=preload("res://systems/native_data/tooltip_preferences.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Tooltip=preload("res://systems/native_item_tooltip.gd")
const Plate=preload("res://systems/native_nameplate.gd")
var checks:=0
var failures: Array=[]
var input_observations: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func frames() -> void: await process_frame; await process_frame
func enter_value(surface: Viewport,control: SpinBox,value: String) -> void:
	var point:=control.get_line_edit().get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	for down in [true,false]:
		var click:=InputEventMouseButton.new(); click.position=point; click.global_position=point; click.button_index=MOUSE_BUTTON_LEFT; click.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; click.pressed=down; surface.push_input(click,true); await frames()
	for down in [true,false]:
		var select:=InputEventKey.new(); select.keycode=KEY_A; select.physical_keycode=KEY_A; select.ctrl_pressed=true; select.pressed=down; surface.push_input(select,true); await frames()
	for character in value:
		for down in [true,false]:
			var typed:=InputEventKey.new(); typed.keycode=character.unicode_at(0); typed.physical_keycode=typed.keycode; typed.unicode=character.unicode_at(0) if down else 0; typed.pressed=down; surface.push_input(typed,true); await frames()
	for down in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.physical_keycode=KEY_ENTER; event.pressed=down; surface.push_input(event,true); await frames()
	input_observations.append({"requested":value,"value":control.value,"text":control.get_line_edit().text,"delay":ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var oracle_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="): oracle_path=arg.trim_prefix("--oracle=")
	if output.is_empty() or oracle_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var observed: Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(observed is Dictionary and observed.get("binarySha256","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.get("callbacks",[]).size()==4 and observed.get("clocks",[]).size()==5,"Tooltip observations pin unchanged original configuration/callback/clock instructions")
	if observed is Dictionary:
		check(int(observed.defaultUsec)==Preferences.DEFAULT_USEC and int(observed.minimumUsec)==Preferences.MIN_USEC and int(observed.maximumUsec)==Preferences.MAX_USEC,"Native preference default/range match executed original registration slices")
		check(observed.callbacks.all(func(row):return int(row.delay)==int(row.input) and int(row.saved)==int(row.input) and int(row.counter)==12345),"Executed original callback changes configured delays while preserving the active counter")
		check(observed.clocks.all(func(row):return int(row.observedMicrosecondDelta)==int(row.providedMicrosecondDelta) if int(row.fixedRate)==0 else int(row.observedMicrosecondDelta)==1000000/int(row.fixedRate)),"Executed original snapshot writer/getter establish real and fixed-rate microsecond units")
	var path:=output+".preferences.cfg"; var layout:=output+".layout.cfg"
	check(Preferences.DEFAULT_USEC==100000 and Preferences.MIN_USEC==1000 and Preferences.MAX_USEC==5000000,"Original registration default/range are represented in microseconds")
	for value in [null,"100000",true,NAN,INF,0.1]: check(Preferences.clean(value)==100000,"Malformed typed preference restores the original default: "+str(value))
	for value in [null,"200",true,NAN,INF,0.1]: check(Preferences.clean_doubletap(value)==200,"Malformed typed double-tap preference restores the original default: "+str(value))
	check(Preferences.clean_doubletap(-1)==0 and Preferences.clean_doubletap(9223372036854775807)==1000,"Double-tap preference uses the executed original zero-to-one-second range")
	check(Preferences.clean(-1)==1000 and Preferences.clean(9223372036854775807)==5000000,"Persisted integer values stay within the original range")
	var config:=ConfigFile.new(); config.set_value("unrelated","keep",42); config.set_value("interface","tooltip_delay_usec","bad"); config.set_value("interface","tooltip_doubletap_ms","bad"); config.save(path)
	var surface:=SubViewport.new(); surface.size=Vector2i(1024,800); root.add_child(surface)
	var parent:=Control.new(); parent.size=Vector2(1024,800); surface.add_child(parent)
	var options:=Settings.new(); parent.add_child(options); options.setup(path,layout); options.show(); options.tabs.current_tab=2; await frames(); await frames()
	check(options.tooltip_delay_usec==100000 and options.tooltip_delay_control.value==100 and is_equal_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),0.1),"Actual Client Options startup applies the original100ms default to the shared tooltip setting")
	check(options.tooltip_doubletap_ms==200 and options.tooltip_doubletap_control.value==200 and Preferences.doubletap_ms==200,"Actual Client Options startup applies the original200ms double-tap default")
	await enter_value(surface,options.tooltip_delay_control,"275")
	config.load(path)
	check(options.tooltip_delay_usec==275000 and config.get_value("interface","tooltip_delay_usec")==275000 and is_equal_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),0.275),"Actual numeric Enter changes and persists the shared tooltip delay without losing milliseconds/microseconds")
	check(config.get_value("unrelated","keep")==42,"Saving tooltip delay preserves unrelated settings")
	await enter_value(surface,options.tooltip_doubletap_control,"350"); config.load(path)
	check(options.tooltip_doubletap_ms==350 and Preferences.doubletap_ms==350 and config.get_value("interface","tooltip_doubletap_ms")==350 and config.get_value("interface","tooltip_delay_usec")==275000 and config.get_value("unrelated","keep")==42,"Actual double-tap input persists independently without changing tooltip delay or unrelated settings")
	await enter_value(surface,options.tooltip_doubletap_control,"10000")
	check(options.tooltip_doubletap_control.value==1000 and Preferences.doubletap_ms==1000,"Actual double-tap input clamps to the original1000ms maximum")
	await enter_value(surface,options.tooltip_doubletap_control,"-10")
	check(options.tooltip_doubletap_control.value==0 and Preferences.doubletap_ms==0,"Actual double-tap input permits the original zero threshold that disables latching")
	var tooltip:=Tooltip.new(); parent.add_child(tooltip); tooltip.set_process(false)
	tooltip.plate=Plate.new(); tooltip.add_child(tooltip.plate); tooltip.plate.configure()
	var target:=Button.new(); parent.add_child(target); tooltip.enter(target)
	check(tooltip.wait_usec==275000,"Actual native tooltip owner captures the configured delay when hover begins")
	await enter_value(surface,options.tooltip_delay_control,"10000")
	check(options.tooltip_delay_control.value==5000 and options.tooltip_delay_usec==5000000 and is_equal_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),5.0),"Actual numeric input clamps to the original five-second maximum")
	check(tooltip.wait_usec==275000,"Changing configuration preserves the existing native hover countdown's delay")
	tooltip.enter(target); check(tooltip.wait_usec==5000000,"A subsequent native hover captures the new configured delay")
	tooltip.close(); tooltip.queue_free(); target.queue_free(); await frames()
	await enter_value(surface,options.tooltip_delay_control,"-10")
	check(options.tooltip_delay_control.value==1 and options.tooltip_delay_usec==1000 and is_equal_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),0.001),"Actual numeric input clamps to the original one-millisecond minimum")
	await enter_value(surface,options.tooltip_delay_control,"150")
	await enter_value(surface,options.tooltip_doubletap_control,"375")
	options.queue_free(); await frames()
	options=Settings.new(); parent.add_child(options); options.setup(path,layout); await frames()
	check(options.tooltip_delay_usec==150000 and options.tooltip_delay_control.value==150 and is_equal_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),0.15),"A new native Options owner immediately restores the saved shared tooltip preference")
	check(options.tooltip_doubletap_ms==375 and options.tooltip_doubletap_control.value==375 and Preferences.doubletap_ms==375,"A new native Options owner immediately restores the saved double-tap threshold")
	options.queue_free(); parent.queue_free(); surface.queue_free(); await frames()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"inputs":input_observations,"scope":"Actual native Client Options input, original-source delay units/default/range, persistence and shared engine/item tooltip setting; full movement/ownership/pixel policy remains separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
