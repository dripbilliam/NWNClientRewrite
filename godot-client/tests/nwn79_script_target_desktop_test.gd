extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Cursor=preload("res://systems/native_mouse_cursor.gd")
const TargetPreview=preload("res://systems/native_render/native_target_preview_shader.gd")
const INVALID:=2130706432
class ProbePointer extends RefCounted:
	var desktop
class ProbeDesktop extends Node:
	var headers: Array=[]
	func set_world(_epoch: int,_area: int,_controlled: int,_objects: Dictionary,header: Dictionary) -> void: headers.append(header.duplicate(true))
	func close() -> void: pass
class ProbeInventory extends Node:
	func set_world(_epoch: int,_area: int,_controlled: int,_objects: Array,_raw: Dictionary) -> void: pass
	func update_world(_epoch: int,_area: int,_controlled: int,_objects: Array,_removed: Array,_raw: Dictionary) -> void: pass
	func close() -> void: pass
class ProbeBarter extends Node:
	func set_world(_epoch: int,_area: int,_controlled: int,_objects: Dictionary,_state: Dictionary) -> void: pass
	func close() -> void: pass
class ProbeExamine extends Node:
	func sync() -> void: pass
	func close() -> void: pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.set_process(false)
	desktop.target_prompt=Label.new(); root.add_child(desktop.target_prompt)
	var text:=Text.new(); desktop.rules.text=text
	desktop.actor_id=101; desktop.area_id=42; desktop.generation=7
	desktop.objects={101:{"id":101,"objectType":5},102:{"id":102,"objectType":5},103:{"id":103,"objectType":6}}
	var commands: Array=[]; desktop.request.connect(func(message): commands.append(message.duplicate(true)))
	var mode:={"version":1,"objectMask":513,"cursor":95,"badCursor":97,"areaId":42,"actorId":101}
	desktop.state={"scriptTargeting":mode,"scriptTargetingData":{"shape":3,"sizeX":4.0,"sizeY":5.0,"flags":7,"range":10.0,"spellId":22,"featId":-1}}
	desktop.target={"type":45,"version":1,"objectMask":513,"cursor":95,"badCursor":97}
	check(desktop.target_cursor(102).valid and desktop.target_cursor(102).id==95,"18/23 valid creature uses server good cursor")
	check(not desktop.target_cursor(103).valid and desktop.target_cursor(103).id==97,"18/23 invalid item uses server bad cursor")
	check(desktop.target_cursor(-1,true).valid and desktop.target_cursor(-1,true).id==95,"18/23 ground mask uses server good cursor")
	check(desktop.target_preview_descriptor()==desktop.state.scriptTargetingData,"57/2 supplies the active server shape/range descriptor")
	var position:=Vector3(1,2,3)
	check(desktop.world_click({"id":103,"position":position}) and commands.is_empty() and not desktop.target.is_empty(),"Invalid world item click stays in server targeting without sending")
	check(desktop.world_click({"id":102,"position":position}) and commands.size()==1 and desktop.target.is_empty(),"Valid world creature click sends exactly one script selection")
	check(commands[0].kind=="native-script-target" and commands[0].version==1 and commands[0].targetId==102 and commands[0].position==[1.0,-3.0,2.0] and commands[0].actorId==101 and commands[0].areaId==42 and commands[0].generation==7,"World click preserves native object ID, coordinate order and ownership scope")
	desktop.target={"type":45,"version":1,"objectMask":513,"cursor":95,"badCursor":97}
	desktop.state.scriptTargeting=mode.duplicate(true); desktop.state.scriptTargeting.version=2
	check(not desktop.target_cursor(102).valid and desktop.target_cursor(102).id==97,"New server version invalidates old hover before UI sync")
	var count:=commands.size(); desktop.cast_target(102,position)
	check(commands.size()==count and desktop.target.is_empty(),"Direct stale-version selection cannot bypass the cursor gate")
	desktop.target={"type":45,"version":2,"objectMask":513,"cursor":95,"badCursor":97}
	check(desktop.world_click({"id":-1,"position":Vector3(4,5,6)}) and commands.size()==count+1 and commands[-1].targetId==INVALID and commands[-1].position==[4.0,-6.0,5.0],"Allowed ground click sends the original invalid object ID and native point")
	desktop.target={"type":45,"version":2,"objectMask":513,"cursor":95,"badCursor":97}
	desktop.state.scriptTargeting.areaId=43
	check(not desktop.target_cursor(102).valid and desktop.target_preview_descriptor().is_empty(),"Old-area mode cannot keep a world cursor or preview")
	desktop.cancel_target(); desktop.state={"spellTargetingOverrides":{"1":{"shape":2,"sizeX":9.0,"sizeY":8.0,"flags":4}}}
	text.tables={"spells":{"orderedRows":[{}, {"TargetShape":"cone","TargetSizeX":"3.0","TargetSizeY":"4.0","TargetFlags":"1","Range":"S"}, {"TargetShape":"sphere","TargetSizeX":"2.0","TargetSizeY":"2.5","TargetFlags":"2","Range":"P"}]},"ranges":{"orderedRows":[{}, {"PrimaryRange":"1.5"}, {"PrimaryRange":"12.5"}]}}
	desktop.target={"type":2,"intParam":1}
	var preview: Dictionary=desktop.target_preview_descriptor()
	check(preview=={"shape":2,"sizeX":9.0,"sizeY":8.0,"flags":4,"range":12.5,"spellId":1,"featId":-1},"57/1 replaces only target shape fields and preserves the spell's S range")
	desktop.target={"type":2,"intParam":2}; preview=desktop.target_preview_descriptor()
	check(preview=={"shape":1,"sizeX":2.0,"sizeY":2.5,"flags":2,"range":1.5,"spellId":2,"featId":-1},"Unrelated spell retains its own target shape and native P range")
	desktop.state.spellTargetingOverrides={}; desktop.target={"type":2,"intParam":1}; preview=desktop.target_preview_descriptor()
	check(preview.shape==3 and preview.sizeX==3.0 and preview.sizeY==4.0 and preview.flags==1,"Override reset restores active spell table values")
	desktop.cancel_target(); check(desktop.target_preview_descriptor().is_empty(),"Cancelled targeting has no preview descriptor")
	var ui:=Gameplay.new(); root.add_child(ui); ui.set_process(false)
	ui.generation=5; ui.area_id=42
	ui.desktop=ProbeDesktop.new(); ui.add_child(ui.desktop)
	ui.inventory=ProbeInventory.new(); ui.add_child(ui.inventory)
	ui.barter=ProbeBarter.new(); ui.add_child(ui.barter)
	ui.examine_skin=ProbeExamine.new(); ui.add_child(ui.examine_skin)
	ui.set_world(5,42,101,[],{}, {"ui":{"spellTargetingOverrides":{1:{"shape":2}}}})
	check(ui.desktop.headers.size()==1 and ui.desktop.headers[-1].spellTargetingOverrides[1].shape==2,"GameplayUI initial world publication forwards 57/1 overrides to Desktop")
	ui.update_world(5,42,101,[],[],{}, {"ui":{"spellTargetingOverrides":{1:{"shape":3}}}})
	check(ui.desktop.headers.size()==2 and ui.desktop.headers[-1].spellTargetingOverrides[1].shape==3,"GameplayUI incremental publication forwards the latest 57/1 override")
	var pointer_ui:=ProbePointer.new(); pointer_ui.desktop=desktop
	var cursor:=Cursor.new(); root.add_child(cursor); cursor.set_process(false); cursor.ui=pointer_ui
	for id in [1,95,97]: cursor.missing[id]=true
	desktop.objects[101].replicated={"position":[10.0,20.0,30.0]}
	desktop.state={"scriptTargeting":mode,"scriptTargetingData":{"shape":3,"sizeX":4.0,"sizeY":5.0,"flags":7,"range":10.0,"spellId":22,"featId":-1}}
	desktop.target={"type":45,"version":1,"objectMask":513,"cursor":95,"badCursor":97}
	var observed: Array=[]; cursor.target_preview_changed.connect(func(snapshot): observed.append(snapshot.duplicate(true)))
	cursor.world_pointer({"id":102,"position":Vector3(1,2,3)},false)
	var pointer: Dictionary=cursor.target_preview_snapshot()
	check(pointer.enabled and pointer.point==[1.0,-3.0,2.0] and pointer.player==[10.0,20.0,30.0] and pointer.type==5 and pointer.areaId==42 and pointer.generation==7 and pointer.actorId==101 and pointer.targetVersion==1,"Actual world pointer publishes scoped native shader inputs for valid server target")
	check(TargetPreview.snapshot().state.get("enabled",false) and TargetPreview.snapshot().state.shape==3 and TargetPreview.snapshot().state.point==Vector3(1,-3,2),"Cursor signal publishes the Desktop target through the actual material adapter")
	check(observed.size()==1 and observed[0]==pointer,"Pointer preview change has one immutable snapshot for render owner")
	cursor.world_pointer({"id":103,"position":Vector3(1,2,3)},false)
	check(not cursor.target_preview_snapshot().enabled,"Invalid target hides preview while retaining server cursor")
	check(not TargetPreview.snapshot().state.enabled,"Invalid target disables the global material preview")
	cursor.world_pointer({"id":102,"position":Vector3(1,2,3)},false)
	cursor.world_pointer({"id":102,"position":Vector3(1,2,3)},true)
	check(not cursor.target_preview_snapshot().enabled,"Blocked GUI pointer hides preview")
	cursor.world_pointer({"id":102,"position":Vector3(1,2,3)},false)
	desktop.state.scriptTargeting.version=2; cursor.cursor_step()
	check(not cursor.target_preview_snapshot().enabled,"Replaced server mode clears preview before the next world pick")
	desktop.state.scriptTargeting.version=1; cursor.world_pointer({"id":102,"position":Vector3(1,2,3)},false); cursor.release()
	check(not cursor.target_preview_snapshot().enabled,"Pointer/focus release clears preview")
	check(not TargetPreview.snapshot().state.enabled,"Pointer release clears the material preview")
	cursor.close(); cursor.free(); pointer_ui=null
	desktop.target_prompt.free(); desktop.free(); text.close(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"commands":commands,"scope":"Desktop type45 world cursor/click, 57/1-2 descriptor and cursor-to-material publication; original packet and 112/6/37 writer oracles are separate."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
