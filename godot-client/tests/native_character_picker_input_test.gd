extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
class UnhandledKeys extends Node:
	var pressed: Array=[]
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: pressed.append(event.keycode)
var checks:=0
var failures: Array=[]
var messages: Array=[]
var surface: SubViewport
var ui
var state: Dictionary
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func key(code: int,shift: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.shift_pressed=shift; surface.push_input(event,true); await process_frame
func present(connection: int=1) -> void:
	ui.apply_state({"connection":connection,"state":state}); await process_frame; await process_frame
func acknowledge() -> void:
	var pending: Dictionary=ui.native_selection.duplicate(); state.selected=pending.key; state.selectionAck={"key":pending.key,"requestId":pending.requestId}; await present(ui.connection)
func run() -> void:
	var output:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.get("target")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==64,"Focused chooser ownership references the exact original constructor/edit observations")
	root.size=Vector2i(1280,800); surface=SubViewport.new(); surface.size=root.size; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	ui=Lobby.new(); surface.add_child(ui); ui.preferences.open_file(""); ui.enable_picker(); ui.request.connect(func(value):messages.append(value.duplicate(true)))
	var observer:=UnhandledKeys.new(); surface.add_child(observer)
	var rows: Array=[]
	for index in 30: rows.append({"key":"server:%02d"%index,"label":"Character %02d"%index,"source":"server","serverSource":17,"classes":[{"id":10,"level":15}]})
	state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":null,"choices":rows}
	await present(); var shell=ui.picker.shell
	check(shell.has_focus() and messages.size()==1 and messages.back().key=="server:00","Immediate production picker owns internal GUI focus and requests the first real row")
	check(shell.row_portraits.size()==30 and shell.row_portraits["server:00"].size==Vector2(44,69) and shell.row_names["server:00"].text=="Character 00","Every row reserves an unstretched portrait and separate name/class/source captions before artwork")
	var first: Dictionary=ui.native_selection.duplicate(); await key(KEY_RIGHT); await key(KEY_DOWN)
	check(messages.size()==3 and messages.back().key=="server:02" and shell.play.disabled,"Right and Down advance from the pending selection without enabling Play")
	state.selected=first.key; state.selectionAck={"key":first.key,"requestId":first.requestId}; await present()
	check(ui.native_selection.key=="server:02" and shell.navigation_key=="server:02" and shell.play.disabled,"An older server acknowledgment cannot reset navigation or release pending Play")
	await key(KEY_LEFT); check(messages.back().key=="server:01","Left moves back from the pending choice rather than older acknowledged state")
	await acknowledge(); check(ui.native_selection.is_empty() and not shell.play.disabled and shell.title.text=="Character 01","Only the matching acknowledgment releases Play and updates the selected summary")
	await key(KEY_UP); await acknowledge(); await key(KEY_UP)
	check(messages.back().key=="server:00","Up clamps at the first row without wrapping")
	await acknowledge()
	for index in 18: await key(KEY_DOWN)
	await acknowledge(); await process_frame; await process_frame
	var row_rect: Rect2=shell.rows["server:18"].get_global_rect(); var list_rect: Rect2=shell.list.get_global_rect()
	check(messages.back().key=="server:18" and shell.list.scroll_vertical>0 and row_rect.position.y>=list_rect.position.y-1 and row_rect.end.y<=list_rect.end.y+1,"Repeated navigation reveals the selected row inside the roster viewport")
	var count:=messages.size(); var neighbor:=LineEdit.new(); neighbor.size=Vector2(100,25); surface.add_child(neighbor); shell.focus_next=neighbor.get_path(); shell.focus_previous=neighbor.get_path()
	for pair in [[13,KEY_ENTER],[10,KEY_KP_ENTER],[27,KEY_ESCAPE],[9,KEY_TAB],[8,KEY_BACKSPACE],[0x123,KEY_END],[0x124,KEY_HOME],[0x12e,KEY_DELETE],[65,KEY_A],[32,KEY_SPACE]]:
		for shift in [false,true]:
			observer.pressed.clear(); shell.grab_focus(); await key(pair[1],shift)
			var evidence: Array=original.rows.filter(func(row):return int(row.case.key)==pair[0] and bool(row.case.shift)==shift and not row.case.links)
			check(evidence.size()==1 and evidence[0].handled==1 and shell.has_focus() and observer.pressed.is_empty() and messages.size()==count,"Original unbound edit key is consumed without Play, disconnect or focus traversal: "+str(pair[0])+" shift="+str(shift))
	neighbor.grab_focus(); await key(KEY_A); await key(KEY_DOWN); check(neighbor.has_focus() and messages.size()==count,"Another focused text control retains ownership during picker refresh")
	neighbor.free(); await process_frame; await process_frame; check(shell.has_focus(),"Picker restores internal focus after the separate text control retires")
	state.canSelect=false; await present(); observer.pressed.clear(); await key(KEY_DOWN); await key(KEY_ESCAPE)
	check(messages.size()==count and observer.pressed.is_empty() and shell.has_focus(),"Busy picker consumes edit keys without selecting or disconnecting")
	state.canSelect=true; state.choices=[]; state.selected=null; state.selectionAck=null; await present(); observer.pressed.clear(); await key(KEY_ENTER)
	check(messages.size()==count and observer.pressed.is_empty() and shell.empty.visible and shell.play.disabled,"Empty picker consumes Enter without inventing a selectable character")
	ui.panel.hide(); await process_frame; observer.pressed.clear(); await key(KEY_ESCAPE)
	check(not shell.has_focus() and observer.pressed==[KEY_ESCAPE],"Hidden picker releases edit ownership")
	state.choices=rows; state.selected="server:00"; ui.panel.show(); await present(2)
	check(ui.native_selection.is_empty() and not shell.play.disabled,"A new authoritative selected row does not require an invented local acknowledgment")
	for dimensions in [Vector2i(800,600),Vector2i(1280,800),Vector2i(3440,1369)]:
		surface.size=dimensions; await process_frame; await process_frame; await process_frame
		var whole:=Rect2(Vector2.ZERO,Vector2(dimensions)); check(whole.encloses(shell.rows["server:00"].get_global_rect()) and whole.encloses(shell.play.get_global_rect()) and whole.encloses(shell.buttons.back.get_global_rect()),"Roster, Play and Back remain inside the native viewport at "+str(dimensions))
		check(shell.stage.visible==(dimensions.x>=1000),"Narrow layouts prioritize the roster and actions without an overflowing optional3D stage: "+str(dimensions))
	ui.close_native(); ui.free(); surface.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Actual native production picker keyboard ownership, four-arrow pending/ack navigation, roster scrolling, empty/busy/hidden/focus isolation and800/1280/3440 viewport layout. Original edit instruction observations back ownership; graphical artwork and live admission are separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
