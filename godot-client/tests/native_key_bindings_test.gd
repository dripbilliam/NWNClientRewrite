extends SceneTree
const Bindings=preload("res://systems/native_key_bindings.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Bar=preload("res://systems/server_quickbar.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
const CameraOwner=preload("res://systems/camera_controller.gd")
const WorldInput=preload("res://systems/world_input.gd")
const Radial=preload("res://systems/server_radial.gd")
var checks:=0
var failures: Array=[]
var sent: Array=[]
var drive: Array=[]
var surface: SubViewport
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func event(code: int,down: bool=true,modifiers: int=0) -> InputEventKey:
	var key:=InputEventKey.new(); key.keycode=code; key.physical_keycode=code; key.pressed=down; key.shift_pressed=bool(modifiers&Bindings.SHIFT); key.ctrl_pressed=bool(modifiers&Bindings.CTRL); key.alt_pressed=bool(modifiers&Bindings.ALT); key.meta_pressed=bool(modifiers&Bindings.META); return key
func push(code: int,down: bool=true,modifiers: int=0) -> void:
	surface.push_input(event(code,down,modifiers),true); await process_frame
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var storage:=output+".preferences.cfg"
	if FileAccess.file_exists(storage): quit(2); return
	var unrelated:=ConfigFile.new(); unrelated.set_value("positions","barter",Vector2(23,45)); unrelated.set_value("interface","ui_scale",1.5); check(unrelated.save(storage)==OK,"Fixture preferences are private and preserve unrelated window/scale fields")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original key table mounts read-only")
	var bytes: PackedByteArray=catalog.get_resource("keymap",2017); var parser:=Table.new(); var table:=parser.parse(Binary.new(bytes).text(0,bytes.size()))
	check(parser.failure.is_empty() and catalog.failure.is_empty(),"Active original Keymap parses with named rows")
	surface=SubViewport.new(); surface.size=Vector2i(1280,800); root.add_child(surface); surface.handle_input_locally=true
	var bindings:=Bindings.new(); surface.add_child(bindings); bindings.configure(storage); bindings.install(table)
	check(bindings.bindings_ready and bindings.active.hotbar.size()==36,"Native binding owner admits source actions and all36 hotbar slots")
	var bar:=Bar.new(); surface.add_child(bar); bar.setup(); bar.set_key_bindings(bindings); bar.request.connect(func(message):sent.append(message.duplicate(true)))
	var rows: Array=[]
	for index in 36: rows.append({"label":"Slot"+str(index+1),"uses":1,"empty":false,"enabled":true})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows})
	var keyboard:=Keyboard.new(); surface.add_child(keyboard); keyboard.require_focus=false; keyboard.set_process(false); keyboard.set_key_bindings(bindings)
	var context:={"identity":"owned-test/1/1","id":42,"state":{"orientation":Vector3.RIGHT,"position":Vector3(2,3,0),"lifetime":1}}
	keyboard.context_query=func():return context
	keyboard.transmit=func(message):drive.append(message.duplicate(true))
	var camera:=Camera3D.new(); surface.add_child(camera); camera.position=Vector3(5,10,15); camera.look_at(Vector3.ZERO)
	var controller:=CameraOwner.new(); surface.add_child(controller); controller.configure(camera,Vector3.ZERO); controller.enable_follow(1,Vector3.ZERO); controller.set_key_bindings(bindings)
	var pointer:=WorldInput.new(); surface.add_child(pointer); pointer.set_key_bindings(bindings); pointer.set_physics_process(false)
	for index in 36:
		var before:=sent.size(); var modifiers:=Bindings.CTRL if index>=24 else Bindings.SHIFT if index>=12 else 0
		await push(KEY_F1+index%12,true,modifiers)
		check(sent.size()==before+1 and sent.back().kind=="quickbar-activate" and sent.back().index==index,"Default key activates its actual quickbar request slot: "+str(index))
	bar.page=1; bar.render(1); await push(KEY_F1)
	check(sent.back().index==12,"Unmodified F keys preserve the original selected-page alias")
	await push(KEY_F1,true,Bindings.CTRL|Bindings.SHIFT); check(sent.back().index==24,"Unchanged F defaults preserve native Ctrl precedence over Shift")
	bar.page=0; bar.render(0)
	await push(KEY_W); check(not drive.is_empty() and drive.back().operation=="drive" and drive.back().flags==3,"Source W mapping reaches original-compatible run flags")
	await push(KEY_S); check(drive.back().operation=="stop" and keyboard.physical_held.size()==2,"Mapped opposing keys stop while retaining physical ownership")
	await push(KEY_S,false); check(drive.back().operation=="drive","Releasing an opposing mapped key resumes the remaining direction")
	await push(KEY_W,false); check(drive.back().operation=="stop" and keyboard.physical_held.is_empty(),"Mapped release cannot leave a canonical movement key stuck")
	await push(KEY_W,true,Bindings.SHIFT); check(drive.back().flags==1,"Shift walk retains the source run binding")
	await push(KEY_W,false,Bindings.SHIFT)
	await push(KEY_LEFT); check(controller.camera_keys.has(KEY_HOME) and keyboard.held.is_empty(),"Original Left Arrow camera action does not also turn or move the actor")
	await push(KEY_LEFT,false); check(controller.camera_keys.is_empty(),"Physical camera release clears its mapped axis")
	await push(KEY_TAB); check(pointer.tab,"Source highlight binding reaches the native world input owner")
	await push(KEY_TAB,false); check(not pointer.tab,"Highlight release clears original hold behavior")
	var ticket:=bindings.begin(); var before_file:=FileAccess.get_sha256(storage)
	check(bindings.assign("hotbar",5,{"key":KEY_G,"modifiers":0},ticket),"Pending hotbar rebind accepts a physical key")
	var before:=sent.size(); await push(KEY_G)
	check(sent.size()==before and FileAccess.get_sha256(storage)==before_file,"Pending edits neither activate new bindings nor write preferences")
	bindings.retire(); check(bindings.active.hotbar[5].key==KEY_F6 and bindings.pending.is_empty(),"Cancel discards pending hotbar changes")
	ticket=bindings.begin(); await push(KEY_W)
	check(bindings.start_capture("hotbar",5,ticket) and drive.back().operation=="stop" and keyboard.held.is_empty(),"Entering assignment stops held movement and suppresses gameplay input")
	before=sent.size(); await push(KEY_F8,true,Bindings.CTRL|Bindings.SHIFT)
	check(not bindings.capturing and bindings.pending.hotbar[5]=={"key":KEY_F8,"modifiers":Bindings.CTRL|Bindings.SHIFT} and sent.size()==before and keyboard.held.is_empty(),"Actual viewport capture retains custom Ctrl+Shift without casting or moving")
	check(bindings.commit(ticket),"Close commits pending hotbar changes to replacement preferences")
	before=sent.size(); await push(KEY_F8,true,Bindings.CTRL|Bindings.SHIFT)
	check(sent.size()==before+1 and sent.back().index==5,"Committed custom chord activates the rebound slot through the real request signal")
	var editor:=LineEdit.new(); surface.add_child(editor); editor.grab_focus(); before=sent.size(); await push(KEY_F8,true,Bindings.CTRL|Bindings.SHIFT)
	check(sent.size()==before,"Text entry suppresses custom hotbar activation")
	editor.release_focus()
	ticket=bindings.begin(); check(bindings.assign("hotbar",8,{"key":KEY_R,"modifiers":0},ticket) and bindings.pending.normal.values[107]==0,"Hotbar rebinding clears the conflicting native Rest action")
	check(bindings.commit(ticket) and not bindings.action_matches(107,event(KEY_R)),"Cross-action conflict clearing becomes active only on commit")
	ticket=bindings.begin(); check(bindings.assign("normal",107,{"key":KEY_R,"modifiers":0},ticket) and bindings.pending.hotbar[8].key==0,"Reassigning a native action clears the conflicting custom hotbar key")
	check(bindings.assign("normal",90,{"key":KEY_T,"modifiers":0},ticket) and bindings.commit(ticket),"A native movement binding can be reassigned and committed")
	before=drive.size(); await push(KEY_W); check(drive.size()==before and keyboard.held.is_empty(),"Old W key no longer drives after reassignment")
	await push(KEY_T); check(drive.size()>before and drive.back().operation=="drive" and drive.back().flags==3,"Reassigned physical key drives with original run wire flags")
	await push(KEY_T,false)
	check(not bindings.assign("hotbar",1,{"key":KEY_Z,"modifiers":0},ticket),"A stale transaction cannot overwrite committed bindings")
	var reloaded:=Bindings.new(); surface.add_child(reloaded); reloaded.configure(storage); reloaded.install(table)
	check(reloaded.bindings_ready and reloaded.active.hotbar==bindings.active.hotbar and reloaded.active.normal.values[90]==98,"Fresh owner restores saved hotbar chords and the T movement mapping")
	var saved:=ConfigFile.new(); saved.load(storage)
	check(saved.get_value("positions","barter")==Vector2(23,45) and saved.get_value("interface","ui_scale")==1.5 and saved.get_section_keys("HotbarKeymapping").size()==36,"Saving all36 bindings preserves unrelated window and scale preferences")
	reloaded.close(); reloaded.free()
	ticket=bindings.begin(); bindings.defaults(ticket)
	check(bindings.pending.hotbar==Bindings.hotbar_defaults() and bindings.active.normal.values[90]!=101,"Defaults resets the pending transaction without changing active input")
	check(bindings.commit(ticket) and bindings.action_matches(90,event(KEY_W)),"Committed Defaults restores original movement and F-key defaults")
	ticket=bindings.begin()
	for index in 36:
		var code: int=KEY_A+index if index<26 else KEY_0+index-26
		check(bindings.assign("hotbar",index,{"key":code,"modifiers":0},ticket),"Hotbar slot is independently rebindable: "+str(index))
	check(bindings.commit(ticket),"All36 custom slot bindings commit together")
	for index in 36:
		var code: int=KEY_A+index if index<26 else KEY_0+index-26
		before=sent.size(); var drives_before:=drive.size(); await push(code)
		check(sent.size()==before+1 and sent.back().index==index and drive.size()==drives_before,"Rebound slot key activates its actual request without leaking movement: "+str(index))
		await push(code,false)
	ticket=bindings.begin(); bindings.start_capture("hotbar",0,ticket); bindings.cancel_requested.connect(bindings.retire); before=sent.size(); await push(KEY_ESCAPE)
	check(not bindings.capturing and bindings.pending.is_empty() and sent.size()==before,"Escape cancels the editor transaction without triggering a shortcut")
	var radial:=Radial.new(); surface.add_child(radial); radial.key_bindings=bindings
	var radial_requests: Array=[]; radial.request.connect(func(message):radial_requests.append(message))
	radial.open_at(Vector2(500,300),42,Vector3.ZERO,false); radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":1,"depth":0,"title":"Capture guard","entries":[{"slot":0,"label":"Do not select"}]})
	ticket=bindings.begin(); bindings.start_capture("hotbar",0,ticket); await push(KEY_1)
	check(radial_requests.is_empty() and not radial.pending and bindings.pending.hotbar[0].key==KEY_1,"Assignment digits do not activate an already-open radial wheel before capture")
	bindings.retire(); radial.reset(); radial.free()
	var state:=bindings.snapshot(); bindings.close(); keyboard.stop(); bar.reset(); pointer.free(); controller.free(); camera.free(); keyboard.free(); editor.free(); bar.free(); bindings.free(); surface.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"bindings":state,"quickbar_requests":sent.size(),"drive_requests":drive.size(),"preferences":storage,"physicalOSInputInjected":false,"logicalViewportInputInjected":true,"publicConnections":0,"fullKeySettingsParity":false,"scope":"Injected native SubViewport key routing,36 original and36 rebound hotbar request signals, cross-action conflicts, capture, movement/camera/highlight ownership and replacement preferences. No visible key editor, original-server acceptance or full UI parity."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
