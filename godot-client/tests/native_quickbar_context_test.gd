extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
const Radial=preload("res://systems/server_radial.gd")
const Bar=preload("res://systems/server_quickbar.gd")
const Policy=preload("res://systems/native_data/quickbar_radial.gd")
class Text extends RefCounted:
	var revision:=0
	var tables: Dictionary={}
	func raw(value: Dictionary) -> String:return "TLK "+str(int(value.get("strRef",-1)))
	func name(_value: Variant,_id: int) -> String:return "Actor"
class ItemContext extends RefCounted:
	var opened: Array=[]
	var entries: Dictionary={}
	func cancel() -> void:pass
	func open_quickbar(id: int,_point: Vector2,valid: Callable,clear_slot: Callable,_binding: Dictionary={},_texture: Texture2D=null) -> void:opened.append({"id":id,"valid":valid,"clear":clear_slot})
class Inventory extends RefCounted:
	var item_context:=ItemContext.new()
class Ui extends RefCounted:
	var text:=Text.new()
	var inventory:=Inventory.new()
	var tables_ready:=true
	var hud_ready:=false
	var world_registry
class Art extends Node:
	func bind(_target: Object,_resource: String,_property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false) -> void:pass
	func close() -> void:pass
class Dialogs extends Node:
	var calls: Array=[]
	func examine(scope: Dictionary,model: Dictionary) -> void:calls.append({"scope":scope.duplicate(true),"model":model.duplicate(true)})
	func edit_macro(scope: Dictionary,part: String) -> void:calls.append({"scope":scope.duplicate(true),"part":part})
	func clear() -> void:pass
	func close() -> void:pass
var checks:=0
var failures: Array=[]
var sent: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func mouse(point: Vector2,button: MouseButton,pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
	event.button_mask=(MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event,true);await process_frame
func click(point: Vector2,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	await mouse(point,button,true);await mouse(point,button,false)
func choose(desktop,slot: int) -> void:
	await click(desktop.radial.buttons[slot].get_global_rect().get_center())
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1440,1000)
	var deadline:=create_timer(90);deadline.timeout.connect(func():quit(3))
	var desktop:=Desktop.new();root.add_child(desktop);desktop.owner_ui=Ui.new();desktop.actor_id=99;desktop.area_id=7;desktop.generation=1
	desktop.rules.text=desktop.owner_ui.text;desktop.shortcut_rules.rules=desktop.rules;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new();desktop.add_child(desktop.art);desktop.radial=Radial.new();desktop.add_child(desktop.radial);desktop.radial.request.connect(desktop.input_request)
	desktop.shortcut_dialogs=Dialogs.new();desktop.add_child(desktop.shortcut_dialogs);desktop.target_prompt=Label.new();desktop.add_child(desktop.target_prompt)
	desktop.objects={99:{"id":99,"objectType":5,"inventoryStats":{"skills":[{"index":9,"flag":true},{"index":13,"flag":false}]},"replicated":{"position":[1,2,3],"stats":{"classes":[{"id":8,"level":1}]}},"playerState":{"feats":[],"spellbooks":{}}},100:{"id":100,"objectType":5}}
	desktop.owner_ui.text.tables={"skills":{"orderedRows":[{"Name":101,"Description":201,"Icon":"server_skill"}]},"feat":{"orderedRows":[{"FEAT":102,"Description":202,"ICON":"server_feat","SpellId":-1,"UsesPerDay":0,"SUCCESSOR":-1}]},"spells":{"orderedRows":[{"Name":103,"SpellDesc":203,"IconResRef":"server_spell","TargetType":2}]}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.quick_bindings[1]={"type":3,"intParam":0};desktop.quick_bindings[2]={"type":4,"intParam":0};desktop.quick_bindings[3]={"type":18,"commandLabel":"Saved macro","commandLine":"/hello"}
	desktop.request.connect(func(message):sent.append(message))
	var bar:=Bar.new();root.add_child(bar);bar.setup();bar.assignment_requested.connect(desktop.shortcut_menu)
	var rows: Array=[]
	for binding in desktop.quick_bindings:rows.append(desktop.shortcut_row(binding))
	bar.receive({"kind":"quickbar-view","quickbarId":11,"rows":rows});await process_frame;await process_frame
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(desktop.radial.active and desktop.radial_entries.size()==8,"Physical right-click on empty quickslot opens all eight original sectors")
	check(desktop.radial_entries[4].icon=="IR_ACTION" and desktop.radial_entries[6].icon=="IR_XABILITY" and not desktop.radial_entries.values().any(func(value):return value.action=="quickbar-clear"),"Empty assignment has Actions/Abilities in source sectors and no fictitious Clear")
	await choose(desktop,4)
	check(desktop.radial_stack.size()==2 and desktop.radial_entries.has(6) and not desktop.radial_entries.has(5) and not desktop.radial_entries.has(4),"Actions submenu admits only received usable skill flags")
	await choose(desktop,6)
	check(sent.size()==1 and sent[-1].kind=="native-quickbar-assign" and sent[-1].index==0 and sent[-1].button=={"type":3,"intParam":9},"Physical nested skill click assigns exact type3 binding through the server route")
	check(desktop.quick_bindings[0]=={"type":0},"Native assignment waits for its private protocol owner's client-layout reflection")
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await choose(desktop,7)
	check(desktop.radial_entries[5].binding=={"type":8,"intParam":0} and desktop.radial_entries[5].label=="TLK 1010","Original primary class selects the correct cheer variant and real label")
	await choose(desktop,7);await choose(desktop,7)
	check(desktop.radial_stack.size()==4 and desktop.radial_entries[0].binding=={"type":8,"intParam":22},"Emotes descend two More pages with original physical IDs and slots")
	await choose(desktop,0)
	check(sent.size()==2 and sent[-1].button=={"type":8,"intParam":22},"Deep emote leaf assigns type8 without playing or spending it locally")
	await click(bar.buttons[1].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(desktop.radial_entries.keys().size()==3 and desktop.radial_entries.has(0) and desktop.radial_entries.has(3) and desktop.radial_entries.has(4) and desktop.pending_shortcuts.is_empty(),"Bound skill opens Examine/Use/Clear instead of assignment mode")
	await choose(desktop,0)
	check(desktop.shortcut_dialogs.calls.size()==1 and desktop.shortcut_dialogs.calls[-1].model=={"ready":true,"name":"TLK 101","description":"TLK 201","icon":"server_skill"},"Examine uses the active server skill data in the original information owner")
	await click(bar.buttons[1].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await choose(desktop,3)
	check(not desktop.target.is_empty() and desktop.target.type==3 and desktop.target.intParam==0 and sent.size()==2,"Bound skill Use enters actual targeting rather than reassigning or silently moving")
	desktop.cancel_target();await click(bar.buttons[2].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await choose(desktop,4)
	check(sent.size()==3 and sent[-1].index==2 and sent[-1].button=={"type":0},"Bound Clear sends the exact scoped empty shortcut request")
	await click(bar.buttons[1].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	var old_request: int=desktop.radial.request_id;var old_menu: int=desktop.radial.menu_id;desktop.quick_bindings[1]={"type":40}
	desktop.radial_select({"requestId":old_request,"menuId":old_menu,"slot":4})
	check(sent.size()==3 and not desktop.radial.active,"A slot replaced while its menu is open cannot be cleared or used by a stale selection")
	await click(bar.buttons[3].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(desktop.radial_entries.has(6) and desktop.radial_entries.has(2),"A saved text macro exposes the separate original label/text edit actions")
	await choose(desktop,6)
	check(desktop.shortcut_dialogs.calls[-1].part=="line","Original Edit Command sector opens the scoped command editor instead of activating the macro")
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await choose(desktop,0)
	check(desktop.shortcut_dialogs.calls[-1].part=="new","Empty text macro sector enters the original two-stage editor")
	desktop.quick_bindings[5]={"type":1,"itemId":123,"intParam":16711935};desktop.shortcut_menu(5,Vector2(600,300))
	check(desktop.owner_ui.inventory.item_context.opened.size()==1 and desktop.owner_ui.inventory.item_context.opened[-1].id==123 and desktop.owner_ui.inventory.item_context.opened[-1].valid.call(),"Item quickslot delegates to its dedicated validated item context")
	desktop.owner_ui.inventory.item_context.opened[-1].clear.call()
	check(sent.size()==4 and sent[-1].index==5 and sent[-1].button=={"type":0},"Item Clear retains the originating quickslot index")
	desktop.quick_bindings[5]={"type":0}
	check(not desktop.owner_ui.inventory.item_context.opened[-1].valid.call(),"Item context loses authority when its actual source binding changes")
	desktop.quick_bindings[4]=desktop.quick_bindings[3].duplicate(true);desktop.shortcut_menu(4,Vector2(600,300));await choose(desktop,3)
	check(sent.size()==5 and sent[-1].kind=="chat" and sent[-1].text=="/hello" and sent[-1].channel==2,"Macro Execute uses original default mode0/native chat dispatcher rather than the unconnected generic quickbar request")
	for type in [6,7,40,41]:
		desktop.quick_bindings[4]={"type":type};desktop.shortcut_menu(4,Vector2(600,300));await choose(desktop,3)
		check(int(desktop.target.get("type",0))==type and not desktop.target_cursor(777).valid,"Original targeted shortcut enters target selection and rejects missing objects: "+str(type))
		var before:=sent.size();desktop.world_click({"id":100,"position":Vector3.ZERO})
		check(sent.size()==before+1 and sent[-1].kind==("examine" if type==40 else "native-barter" if type==41 else "interact") and sent[-1].targetId==100,"Targeted shortcut dispatches its existing authoritative operation: "+str(type))
	desktop.activate({"type":8,"intParam":20});check(sent[-1].kind=="native-emote" and sent[-1].animation==47 and sent[-1].duration==10 and sent[-1].voice==65535 and sent[-1].position==[1,2,3],"Sit emote uses exact original animation/duration and voice sentinel without applying animation locally")
	var policy:=Policy.new();policy.rules=desktop.rules
	for id in [0,1,5,10]:check(not policy.information({"type":10,"intParam":id}).is_empty(),"Source mode Examine has a real original description: "+str(id))
	await click(bar.buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT);await choose(desktop,5)
	check(desktop.radial_entries.keys().size()==5 and desktop.radial_entries.has_all([2,3,4,5,6]) and desktop.radial_entries[5].label=="TLK 1474" and desktop.radial_entries[4].label=="TLK 1477" and desktop.radial_entries[3].label=="TLK 682" and desktop.radial_entries[2].label=="TLK 5345" and desktop.radial_entries[6].label=="TLK 1483","Original9945d0 base Commands retains physical sectors and installed-TLK references instead of sequential English rows")
	await choose(desktop,3)
	check(sent[-1].kind=="native-quickbar-assign" and sent[-1].index==0 and sent[-1].button=={"type":42,"intParam":22},"Physical Commands Follow assigns exact original type42 command22")
	check(desktop.shortcut_row({"type":42,"intParam":22}).label=="TLK 682" and desktop.shortcut_row({"type":42,"intParam":22}).icon=="IR_FOLLOW","Received Command shortcut retains active original TLK label and source icon")
	desktop.activate({"type":42,"intParam":22});check(sent[-1].kind=="native-quickchat" and sent[-1].quickChat==22,"Assigned source Command activates through existing authoritative quickchat path")
	desktop.owner_ui.text.tables.skills.orderedRows[0].Name=901;desktop.owner_ui.text.tables.skills.orderedRows[0].Icon="override_skill"
	check(policy.information({"type":3,"intParam":0}).name=="TLK 901" and policy.information({"type":3,"intParam":0}).icon=="override_skill","No base-catalog metadata cache overrides current server rows")
	var started:=Time.get_ticks_usec()
	for index in 2000:policy.empty();policy.actions(desktop.actor());policy.bound({"type":3,"intParam":0},true,"","")
	var elapsed:=Time.get_ticks_usec()-started
	check(elapsed<2000000,"Six thousand synchronous menu projections stay below a two-second pathological stall guard")
	var timings: Array=desktop.shortcut_timings.duplicate(true);bar.free();desktop.close();desktop.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"root_timings":timings,"policy_iterations":2000,"policy_elapsed_usec":elapsed,"scope":"Real Godot quickbar pointer input, original source-sector/nested routing, received active-table snapshots, stale binding and private output authority. Authored state; no original pixels, native server outcomes or wall-clock FPS claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
