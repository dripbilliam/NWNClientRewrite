extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
const Wheel=preload("res://systems/server_radial.gd")
const Access=preload("res://systems/native_gui_panel_access.gd")
const Quickbar=preload("res://systems/server_quickbar.gd")
class Text extends RefCounted:
	var tables: Dictionary={}
	var revision:=1
	func raw(value: Variant) -> String:return str(int(value.get("strRef",0))) if value is Dictionary else str(value)
	func name(_value: Variant,id: int=-1) -> String:return "Actor "+str(id)
class Cancel extends RefCounted:
	var count:=0
	func cancel() -> void:count+=1
class Inventory extends RefCounted:
	var item_context:=Cancel.new()
class Art extends RefCounted:
	func bind(_control,_resource: String,_property: String="texture",_model: bool=false,_clip: String="") -> void:pass
	func close() -> void:pass
class View extends RefCounted:
	func reset() -> void:pass
	func close() -> void:pass
class Owner extends Node:
	var desktop
	var gui_panel_access
	var generation:=1
	var area_id:=10
	var controlled_id:=99
	var hud_ready:=false
	var text:=Text.new()
	var inventory:=Inventory.new()
	var world_registry
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func click(wheel,slot: int) -> void:
	var point: Vector2=wheel.buttons[slot].get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true);await process_frame
func open_self(d,origin: String="world") -> void:d.open_radial({"id":99,"position":Vector3(1,3,-2),"origin":origin},Vector2(500,400))
func drag_to_bar(wheel,bar,slot: int,index: int) -> void:
	var source: Vector2=wheel.buttons[slot].get_global_rect().get_center();var destination: Vector2=bar.buttons[index].get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=source;motion.global_position=source;root.push_input(motion,true);await process_frame
	var down:=InputEventMouseButton.new();down.position=source;down.global_position=source;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(down,true);await process_frame
	for point in [source+Vector2(20,0),destination]:
		var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;move.relative=point-source;move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true);await process_frame
	check(root.gui_is_dragging(),"Physical viewport motion starts native self CancelShape drag")
	var up:=InputEventMouseButton.new();up.position=destination;up.global_position=destination;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true);await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1280,900)
	var owner:=Owner.new();root.add_child(owner)
	var d:=Desktop.new();var wheel:=Wheel.new();root.add_child(wheel);var access:=Access.new();root.add_child(access);var bar:=Quickbar.new();root.add_child(bar);bar.setup();bar.radial_valid=wheel.can_shortcut;bar.request.connect(d.input_request)
	owner.desktop=d;owner.gui_panel_access=access;access.configure(owner);d.owner_ui=owner;d.radial=wheel;d.art=Art.new();d.rules.text=owner.text;d.shortcut_rules.rules=d.rules;d.ability_rules.rules=d.rules
	d.feat_rules.rules=d.rules;d.ability_rules.feats=d.feat_rules;d.spell_rules.rules=d.rules;d.spell_rules.abilities=d.ability_rules
	d.target_prompt=Label.new();root.add_child(d.target_prompt);d.actor_id=99;d.generation=1;d.area_id=10
	var view:=View.new()
	for key in ["party","quickbar","sheet","book","journal","area_map","players","buffs","level_up","action_queue"]:d.set(key,view)
	d.quickbar=bar;var rows: Array=[]
	for index in 36:rows.append({"index":index,"label":"Empty shortcut","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows})
	var actor:={"id":99,"objectType":5,"areaId":10,"replicated":{"field8D4":128,"field8D6":0,"field8E0":0,"position":[1,2,3],"stats":{"classes":[{"id":4,"level":1}]}}}
	d.objects={99:actor};var sent: Array=[];d.request.connect(func(message):sent.append(message));wheel.request.connect(d.input_request)
	open_self(d);await process_frame
	check(wheel.active and d.radial_entries.keys().size()==7 and [0,1,2,3,5,6,7].all(func(slot):return d.radial_entries.has(slot)),"Actual owner publishes native normal-self sectors including Emotes, without Rest/Inventory placeholders")
	check(sent.size()==1 and sent[0].panel=="context-attempt" and int(sent[0].guiPanelId)==18 and sent[0].position==[0,0,0] and int(sent[0].targetId)==99,"World creature open routes canonical panel18 and GUI26 intent with object zeroXYZ")
	await click(wheel,5)
	check(wheel.active and wheel.depth==1 and d.radial_entries.size()==5 and d.radial_entries.has(3),"Actual Godot pointer click enters original five-command submenu")
	await click(wheel,3)
	check(not wheel.active and sent[-1].kind=="native-quickchat" and int(sent[-1].quickChat)==22,"World Follow command activates source quickchat immediately")
	open_self(d);await click(wheel,7)
	check(wheel.active and d.radial_entries[7].menu.kind=="world-emotes-more","World Emotes has its own nested route rather than assignment context")
	await click(wheel,5)
	check(sent[-1].kind=="native-emote" and int(sent[-1].animation)==44 and int(sent[-1].voice)==44 and sent[-1].position==[1,2,3] and d.target.is_empty(),"Actual emote click dispatches animation/voice immediately without target cursor")
	open_self(d);await click(wheel,2)
	check(int(d.target.get("type",0))==7 and not wheel.active and sent[-1].panel=="context-attempt","Self Attack enters source targeting and sends no attack on self")
	d.cancel_target();actor.replicated.field8D6=2;actor.replicated.field8D8=99;open_self(d);await click(wheel,2)
	check(sent[-1].kind=="native-disengage" and int(sent[-1].actorId)==99 and int(sent[-1].generation)==1,"Source Disengage has a distinct scoped host intent")
	actor.playerState={"playerFlags":1024};actor.replicated.field908=0;open_self(d)
	check(d.radial_entries.has(4) and d.radial_entries[4].icon=="IR_SKILLSELF","Received playerFlags bit10 publishes source CancelShape role4")
	check(d.radial_entries[4].binding=={"type":43,"intParam":-1} and d.radial_entries[4].canDrag,"Original9960c0→861350 keeps exact type43/-1 drag data")
	var before_drag:=sent.size();await drag_to_bar(wheel,bar,4,5)
	check(sent.size()==before_drag+1 and sent[-1].kind=="native-quickbar-assign" and int(sent[-1].index)==5 and sent[-1].button=={"type":43,"intParam":-1},"Actual self-wheel drop uses private current menu tokens and exact native binding")
	check(wheel.active and d.target.is_empty() and not root.gui_is_dragging(),"Drop neither activates CancelShape nor creates a target cursor")
	await click(wheel,4)
	check(sent[-1].kind=="native-cancel-polymorph" and int(sent[-1].actorId)==99,"Actual role4 pointer uses direct typed command without a quickbar index")
	actor.playerState.playerFlags=1024+131072;open_self(d)
	check(not d.radial_entries.has(4),"Received locked-shape bit17 suppresses CancelShape")
	wheel.reset();actor.playerState.playerFlags=0;actor.replicated.party={"player":true,"field8D4Bit6":true,"singleton":false,"leader":false,"field7DC":false};open_self(d);await click(wheel,4)
	check(sent[-1].kind=="native-party" and sent[-1].operation=="leave","Source normal-party role4 dispatches existing scoped Leave action")
	actor.replicated.erase("party")
	actor.replicated.field8D6=0;open_self(d);await click(wheel,7)
	actor.replicated.field8E0=16;var old_count:=sent.size();await click(wheel,5)
	check(sent.size()==old_count,"Receive-time loss of emote availability prevents stale leaf activation")
	actor.replicated.field8E0=0;wheel.reset();access.policy.disabled={18:{99:"received"}};old_count=sent.size();open_self(d)
	check(not wheel.active and sent.size()==old_count+1 and sent[-1].panel=="context-attempt","Canonical disabled creature context emits one blocked intent and opens no wheel")
	access.policy.disabled.clear();open_self(d,"portrait")
	check(wheel.active and sent.size()==old_count+1,"Portrait source opens UI without invented world GUI26")
	wheel.reset();open_self(d,"keyboard")
	check(wheel.active and sent.size()==old_count+1,"Unverified keyboard callback preserves its UI without claimed world event parity")
	wheel.reset()
	for context in [["ground",-1,-1,16],["trigger",100,7,17],["item",101,6,19],["placeable",102,9,20],["door",103,10,21]]:
		if int(context[1])>=0:d.objects[int(context[1])]={"id":int(context[1]),"objectType":int(context[2]),"areaId":10,"replicated":{}}
		var before:=sent.size();d.open_radial({"id":int(context[1]),"position":Vector3(4,6,-5)},Vector2(500,400))
		check(wheel.active and sent.size()==before+1 and sent[-1].sourceKind==context[0] and int(sent[-1].guiPanelId)==int(context[3]),"Actual Desktop open preserves original "+str(context[0])+" caller mapping")
		check(Vector3(sent[-1].position[0],sent[-1].position[1],sent[-1].position[2])==(Vector3(4,5,6) if context[0]=="ground" else Vector3.ZERO),"Only ground maps actual Godot point to native XYZ: "+str(context[0]))
		wheel.reset()
	open_self(d,"keyboard");var retire_count:=sent.size()
	var stale:={"requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":2};owner.generation=2;d.set_world(2,10,99,{99:actor},{})
	d.radial_select(stale);check(not wheel.active and sent.size()==retire_count,"Transition retires open wheel and rejects old selection token")
	owner.gui_panel_access=null;access.close();access.free();var prompt=d.target_prompt;d.closed=true;d.free();prompt.free();bar.free();wheel.free();owner.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"requests":sent,"scope":"Actual Desktop+ServerRadial+canonical access adapter and synthetic viewport mouse input; captured request boundary, no network/server/gameplay outcome or graphical-pixel acceptance."},"  "));file.close();quit(0 if failures.is_empty() else 1)
