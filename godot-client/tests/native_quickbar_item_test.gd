extends SceneTree
const Context=preload("res://systems/native_item_context.gd")
const Radial=preload("res://systems/server_radial.gd")
class Text extends RefCounted:
	var tables: Dictionary={"baseitems":{"orderedRows":[{"EquipableSlots":48,"Stacking":1}]},"classes":{"orderedRows":[]}}
	func raw(value: Dictionary) -> String:return "TLK "+str(int(value.get("strRef",-1)))
	func name(_value: Variant,id: int) -> String:return "Item "+str(id)
class Art extends RefCounted:
	func bind(_target: Object,_resource: String,_property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false) -> void:pass
class TestSkin extends RefCounted:
	var art:=Art.new()
class Ui extends RefCounted:
	var wanted:=false
	var textures: Dictionary={}
class Inventory extends RefCounted:
	var generation:=1
	var area_id:=7
	var controlled_id:=99
	var text_owner:=Text.new()
	var frame_skin:=TestSkin.new()
	var ui:=Ui.new()
	var objects: Dictionary={99:{"id":99,"objectType":5},13:{"id":13,"objectType":6,"item":{"baseItem":0,"canUse":true,"properties":[]},"inventoryLocation":{"channel":"R","ownerId":99}}}
	var inventories: Dictionary={}
	var containers: Dictionary={}
	var store: Dictionary={}
	var sent: Array=[]
	func send_command(message: Dictionary) -> void:sent.append(message.duplicate(true))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true);await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	create_timer(30).timeout.connect(func():quit(3));root.size=Vector2i(1100,800)
	var owner:=Inventory.new();var context:=Context.new();root.add_child(context);context.inventory=owner;context.rules.text=owner.text_owner;context.policy.rules=context.rules
	context.wheel=Radial.new();context.add_child(context.wheel);context.wheel.request.connect(context.input)
	var binding: Dictionary={"type":1,"itemId":13,"intParam":16711935};var received: Dictionary={"binding":binding.duplicate(true)};var clears: Array=[]
	var valid: Callable=func():return received.binding==binding
	var clear_slot: Callable=func():clears.append(35)
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame
	check(context.wheel.active and context.quickbar_owned and not owner.ui.wanted,"Item shortcut opens independently while inventory is closed")
	check(context.entries[4].action=="quickbar-clear" and context.entries[0].action=="examine" and context.entries[2].payload==16 and context.entries[6].payload==32,"Source item quickbar keeps Examine, Clear and both equipment sectors")
	await click(context.wheel.buttons[0]);check(owner.sent==[{"kind":"examine","targetId":13}] and not context.wheel.active,"Physical quickbar item Examine uses the canonical server command without a repository view")
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame;await click(context.wheel.buttons[2])
	check(owner.sent[-1]=={"kind":"item-action","itemId":13,"operation":"equip","slot":16} and owner.objects[13].inventoryLocation.channel=="R","Physical quickbar Equip sends actual item/slot without predicting ownership")
	owner.objects[13].inventoryLocation.channel="I";owner.objects[13].equipmentOwnerId=99;binding.secondaryItemId=14;received.binding=binding.duplicate(true)
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame
	check(context.entries[6].action=="unequip" and context.entries[4].action=="quickbar-clear","Equipped shortcut substitutes source Unequip while retaining Clear")
	await click(context.wheel.buttons[6]);check(owner.sent.slice(-2)==[{"kind":"item-action","itemId":13,"operation":"unequip"},{"kind":"item-action","itemId":14,"operation":"unequip"}],"Physical paired-item Unequip emits both original item operations")
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame;await click(context.wheel.buttons[4])
	check(clears==[35] and not context.wheel.active and not owner.ui.wanted,"Physical Clear retains its quickbar source and does not open inventory")
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);var stale:={"kind":"radial-select","requestId":context.wheel.request_id,"menuId":context.wheel.menu_id,"slot":4};received.binding.type=0;context.input(stale)
	check(clears==[35] and not context.wheel.active,"Changed received binding rejects a held shortcut-owned item result")
	received.binding=binding.duplicate(true);context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);stale={"kind":"radial-select","requestId":context.wheel.request_id,"menuId":context.wheel.menu_id,"slot":6};var sent_before:=owner.sent.size();owner.objects[13].equipmentOwnerId=null;context.input(stale)
	check(owner.sent.size()==sent_before and not context.wheel.active,"Received attachment change retires an old equipped menu even if last disclosed channel remains I")
	context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame
	check(context.entries[2].action=="equip" and context.entries[6].action=="equip" and owner.objects[13].inventoryLocation.channel=="I","Current unequipped attachment opens Equip despite retained last-disclosed I coordinates")
	owner.objects[13].inventoryLocation=null;context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);await process_frame
	check(context.entries[2].action=="equip" and context.entries[4].action=="quickbar-clear","Actual GI widget removal with null spatial location keeps the independent quickslot context usable")
	received.binding=binding.duplicate(true);context.open_quickbar(13,Vector2(550,350),valid,clear_slot,binding);stale={"kind":"radial-select","requestId":context.wheel.request_id,"menuId":context.wheel.menu_id,"slot":0};owner.objects[13].item.canUse=false;var before:=owner.sent.size();context.input(stale)
	check(owner.sent.size()==before and not context.wheel.active,"Replaced item metadata retires the old menu rather than dispatching against stale powers")
	context.close();context.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real item-context wheel and physical Godot button input with authored received item/slot scope; no original pixels, source artwork, server outcomes or inventory/store policy acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
