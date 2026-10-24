extends SceneTree
const Controller = preload("res://systems/camera_controller.gd")
const Options = preload("res://systems/native_options.gd")
const Client = preload("res://systems/local_connection.gd")
class World extends Node3D:
	var camera_controller
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		root.push_input(event,true); await process_frame
func choose(options,mode: int) -> bool:
	options.show(); await process_frame; await process_frame
	var choice: OptionButton = options.camera_choice
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = choice.get_global_rect().get_center(); event.global_position = event.position
		root.push_input(event,true); await process_frame
	var popup: PopupMenu = choice.get_popup()
	if not popup.visible: return false
	for i in 5:
		if popup.get_focused_item() == choice.get_item_index(mode): break
		await key(KEY_DOWN)
	await key(KEY_ENTER)
	return not popup.visible and choice.get_selected_id() == mode
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1100,850)
	var world := World.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.position = Vector3(0,12,14); camera.look_at(Vector3.ZERO)
	var control := Controller.new(); world.add_child(control); control.configure(camera,Vector3.ZERO); control.set_process(false)
	world.camera_controller = control
	control.enable_follow(1,Vector3(2,0,-3),1.7)
	control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_valid(Vector3(2,0,-3)),"Native camera conversion looks at the original follow focus in Godot axes")
	world.rotation.y = 0.4; control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_valid(Vector3(2,0,-3)),"The native camera uses world orientation even under a transformed scene parent")
	world.rotation.y = 0
	check(absf(control.target.y-1.2) < 0.0001,"Top-down appearance height retains the original half-unit adjustment")
	var yaw: float = control.follow_state.state.yaw
	for i in 20: control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_state.state.yaw == yaw,"Top-down does not auto-turn toward the controlled creature")
	var updates := control.view_updates
	control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.view_updates == updates,"An exactly unchanged native view does not dirty the camera transform again")
	var options := Options.new(); root.add_child(options); options.setup("",output+".cfg")
	options.camera_preference.connect(func(mode): control.set_follow_mode(mode))
	var chosen := await choose(options,0)
	check(chosen and options.camera_mode == 0 and control.follow_state.state.mode == 0,"Actual popup pointer/keyboard selection updates the displayed Chase mode and frame owner")
	check(control.follow_state.state.distance == 20 and control.follow_state.state.pitch == 50,"Mode change uses the original distance and pitch defaults")
	for i in 30: control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_state.state.yaw > yaw,"Chase steering turns toward the controlled creature")
	control.orbit(Vector2(30,10)); control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_state.state.manualLatch == 1,"A manual orbit latches automatic steering off")
	var latched: float = control.follow_state.state.yaw
	for i in 4: control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_state.state.yaw == latched,"Chase respects the manual latch while movement continues")
	control.follow_frame(Vector3(2,0,-3),90,0,1.0/60.0,1.7); control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(control.follow_state.state.manualLatch == 0 and control.follow_state.state.yaw > latched,"Stopping and resuming movement releases the original manual latch")
	await choose(options,2)
	for i in 60: control.follow_frame(Vector3(2,0,-3),90,4,1.0/60.0,1.7)
	check(absf(control.follow_state.state.yaw-90) < 1,"Stiff chase converges toward the controlled facing")
	var memory := control.remembered_pose(); control.enable_follow(2,Vector3(5,0,-6),1.7,memory)
	check(control.remembered_pose() == memory,"A replacement area frame owner retains its native pose")
	var key := InputEventKey.new(); key.keycode = KEY_HOME; key.pressed = true; control._input(key)
	check(control.camera_keys.has(KEY_HOME),"Native Home key selects the original camera yaw rate")
	key.pressed = false; control._input(key); check(control.camera_keys.is_empty(),"Key release retires the held camera rate")
	var edit := LineEdit.new(); root.add_child(edit); edit.grab_focus(); await process_frame; key.pressed = true; control._input(key)
	check(control.camera_keys.is_empty(),"Editing text does not add gameplay camera input")
	edit.release_focus(); control._input(key); control._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(control.camera_keys.is_empty(),"Window blur cannot leave a camera key held")
	var bridge := Client.new(); root.add_child(bridge); bridge.set_process(false); bridge.owner_scene = world; bridge.options = options; bridge.connection = 3
	bridge.receive({"kind":"camera-mode","connection":3,"mode":0})
	check(control.follow_state.state.mode == 0 and options.camera_choice.get_selected_id() == 0 and options.camera_mode == 2,"A current decoded server mode changes presentation without overwriting the saved user preference")
	bridge.receive({"kind":"camera-mode","connection":2,"mode":2})
	check(control.follow_state.state.mode == 0,"A retired connection cannot change the native camera mode")
	bridge.receive({"kind":"camera-mode","connection":3,"mode":255})
	check(control.follow_state.state.mode == 0,"Invalid native server mode bytes are ignored")
	control.follow_state.state.yaw = 123.0; control.follow_state.state.pitch = 60.0; control.follow_state.state.distance = 15.0
	bridge.camera_memory = {"mode":0,"yaw":30.0,"pitch":50.0,"distance":20.0}; bridge.last_controlled = Vector3(8,0,6)
	bridge._enable_player_camera()
	check(control.remembered_pose() == {"mode":0,"yaw":123.0,"pitch":60.0,"distance":15.0},"Replacing the controlled binding preserves the current manual view rather than an older area pose")
	bridge.free()
	edit.free(); options.free(); var fresh := Options.new(); root.add_child(fresh); fresh.setup("",output+".cfg")
	check(fresh.camera_mode == 2 and fresh.camera_choice.get_selected_id() == 2,"Camera preference survives a new native Options owner")
	fresh.show_camera_mode(0); check(fresh.camera_mode == 2,"A displayed server mode does not overwrite the user's stored preference")
	check(fresh.camera_choice.focus_mode == Control.FOCUS_NONE,"Camera selection does not take movement text focus")
	fresh.free(); world.free(); await process_frame; await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Authored native mode selection/persistence, follow conversion and input lifetime; synthetic controls, no server or physical-device acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
