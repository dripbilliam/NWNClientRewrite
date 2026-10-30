extends SceneTree
const Policy=preload("res://systems/native_data/mouse_cursor.gd")
const Cursor=preload("res://systems/native_mouse_cursor.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Slot=preload("res://systems/inventory_slot.gd")
class Owner:
	extends RefCounted
	var desktop
class Inventory:
	extends Node
	var wanted:=true
	var view_id:=1
	var examine_mode:=false
	var selections:=0
	func select_item(_id: int) -> void: selections+=1
var checks:=0
var failures: Array=[]
var commands: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var output:=str(args.get("report",""))
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.unfocusable=true
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.get("oracle",""))))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Target oracle identifies unchanged shipped original")
	for row in oracle.spells:
		for kind in [0,2,5,6,7,9,10,11,12,13,14]:
			for self_target in [false,true]:
				var value:=Policy.target({"type":2},kind,self_target,int(row.mask))
				var expected:=false
				for entry in row.entries:
					if int(entry.kind)==kind: expected=true
				if kind==5:
					for predicate in row.predicate:
						if predicate.creature and int(predicate.id)==(101 if self_target else 102): expected=expected and not predicate.rejected
				check(value.valid==expected and value.id==(29 if expected else int(row.badCursor)) and value.centered==row.centered,"Original spell mask/self predicate "+str([row.mask,kind,self_target]))
	for row in oracle.scripts:
		for kind in [0,2,5,6,7,9,10,11,12,13,14]:
			var value:=Policy.target({"type":45,"objectMask":int(row.mask),"cursor":95,"badCursor":int(row.badCursor)},kind,false)
			var expected:=false
			for entry in row.entries:
				if int(entry.kind)==kind: expected=true
			check(value.valid==expected and value.id==(95 if expected else int(row.badCursor)),"Original script target mask and custom cursor "+str([row.mask,kind]))
	for tuple in [[55,10,41,43],[70,2,33,35],[80,5,55,57]]:
		check(Policy.target({"type":1},int(tuple[1]),false,0,int(tuple[0])).id==int(tuple[2]) and Policy.target({"type":1},6,false,0,int(tuple[0])).id==int(tuple[3]),"Original lock/trap/healing item cursor "+str(tuple))
	check(Policy.target({"type":3,"intParam":9},10,false).id==37 and Policy.target({"type":3,"intParam":9},5,false).id==39,"Native skill valid/invalid cursor kinds")
	check(Policy.target({"type":4,"spellId":12},5,false,2).id==29 and Policy.target({"type":4,"spellId":12},2,false,2).id==39,"Spell-backed feat uses magic success and action failure cursor")
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.set_process(false); desktop.target_prompt=Label.new(); root.add_child(desktop.target_prompt)
	var text:=Text.new(); desktop.rules.text=text
	text.tables={"spells":{"orderedRows":[{"TargetType":"8"},{"TargetType":"1"},{"TargetType":"2"}]}}
	desktop.actor_id=101; desktop.area_id=42; desktop.generation=7; desktop.objects={101:{"id":101,"objectType":5},102:{"id":102,"objectType":5},103:{"id":103,"objectType":6},104:{"id":104,"objectType":9}}
	desktop.request.connect(func(message): commands.append(message.duplicate(true)))
	var owner:=Owner.new(); owner.desktop=desktop
	var cursor:=Cursor.new(); root.add_child(cursor); cursor.ui=owner; cursor.set_process(false); cursor.publisher=func(_packet):pass
	var inventory:=Inventory.new(); root.add_child(inventory)
	var slot:=Slot.new(); root.add_child(slot); slot.position=Vector2(100,100); slot.size=Vector2(40,40); slot.setup(inventory,{"entryId":103,"itemId":103,"name":"Target item"})
	desktop.target={"type":2,"intParam":0,"classIndex":2,"metamagic":4,"domainLevel":3}
	check(cursor.hovered_selection(slot.image,false).id==29,"Active-server spell TargetType replaces pickup cursor over item slots")
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(110,110); root.push_input(motion,true); await process_frame
	var click:=InputEventMouseButton.new(); click.position=motion.position; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; root.push_input(click,true); click=click.duplicate(); click.pressed=false; root.push_input(click,true); await process_frame
	check(commands.size()==1 and commands[0].kind=="native-cast" and commands[0].targetId==103 and commands[0].spellId==0 and commands[0].actorId==101 and commands[0].areaId==42 and commands[0].generation==7,"Native input on an inventory target emits the original-compatible cast request with current owner context")
	check(desktop.target.is_empty() and inventory.selections==0,"Target click consumes selection without activating or moving the item")
	desktop.target={"type":2,"intParam":1}; var before:=commands.size()
	check(cursor.hovered_selection(slot,false).id==31 and cursor.target_slot(slot) and commands.size()==before and not desktop.target.is_empty(),"Invalid item target is gray and cannot fabricate a cast or select the item")
	check(cursor.hovered_selection(desktop.target_prompt,false).id==31,"Unmapped GUI controls retain the invalid targeting cursor instead of pretending to be a world action")
	check(desktop.target_cursor(101).valid and not desktop.target_cursor(102).valid,"Native cursor applies active self-only TargetType")
	text.tables.spells.orderedRows[1].TargetType="2"
	check(not desktop.target_cursor(101).valid and desktop.target_cursor(102).valid,"Changing the active server's table changes the target policy without stock spell IDs")
	before=commands.size()
	check(desktop.world_click({"id":101,"position":Vector3.ZERO}) and commands.size()==before and not desktop.target.is_empty(),"Invalid world target remains in selection mode without sending a cast")
	check(desktop.world_click({"id":102,"position":Vector3.ZERO}) and commands.size()==before+1 and commands[-1].targetId==102 and desktop.target.is_empty(),"Valid world target emits its canonical cast and leaves targeting mode")
	desktop.target={"type":45,"objectMask":2,"cursor":95,"badCursor":97,"version":9}
	check(cursor.hovered_selection(slot,false).id==95 and desktop.target_cursor(102).id==97,"Script target uses server-selected custom cursors, not hardcoded magic art")
	check(cursor.target_slot(slot) and commands[-1].kind=="native-script-target" and commands[-1].version==9 and commands[-1].targetId==103,"Inventory script target routes to its canonical server selection request")
	desktop.target={"type":2,"intParam":0}; inventory.view_id=2; before=commands.size()
	check(not cursor.target_slot(slot) and commands.size()==before,"Stale slot cannot submit targeting after repository view changes")
	var cancel:=InputEventMouseButton.new(); cancel.button_index=MOUSE_BUTTON_RIGHT; cancel.pressed=true; root.push_input(cancel,true); await process_frame
	check(desktop.target.is_empty() and cursor.hovered_selection(slot,false).id==1,"Right-click cancels targeting even while the pointer is over a menu")
	cursor.close(); cursor.free(); desktop.close(); desktop.target_prompt.free(); desktop.free(); slot.free(); inventory.free(); owner=null; text.close(); text=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"commands":commands,"publicConnections":0,"physical_pointer_changes":0,"scope":"Unchanged spell/script target cursor setup oracle, active-table projection and synthetic native viewport input through inventory targeting. Emitted requests are inspected here; owned local-server checks separately prove accepted gameplay actions. Range/LOS/associate/DM, complete UI target widgets and full UI parity remain unproven."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
