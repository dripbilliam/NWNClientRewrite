extends SceneTree
# Real native painter/inventory controls and viewport input, over explicitly
# authored view data. Original-server item disclosure is tested separately.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Inventory=preload("res://systems/native_inventory.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Preferences=preload("res://systems/native_data/tooltip_preferences.gd")
const Bindings=preload("res://systems/native_key_bindings.gd")
const WorldInput=preload("res://systems/world_input.gd")
const Table=preload("res://systems/native_data/two_da.gd")
var failures: Array=[]
var checks:=0
var surface: SubViewport
class InputProbe extends Node:
	var keys:=0
	var middle:=0
	var ground:=0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode==KEY_W and event.pressed: keys+=1
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_MIDDLE: middle+=1
			if event.button_index==MOUSE_BUTTON_LEFT: ground+=1
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func frames(count: int=2) -> void:
	for index in count: await process_frame
func wait_for(predicate: Callable,seconds: float=3.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if predicate.call(): return true
		await frames()
	return false
func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; surface.push_input(event,true); await frames()
func click(point: Vector2,button: int=MOUSE_BUTTON_LEFT) -> void:
	await motion(point)
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=down; event.button_mask=(1<<(button-1)) if down else 0; surface.push_input(event,true); await frames()
func visible(owner,text: String) -> bool:
	return is_instance_valid(owner.plate) and owner.plate.is_visible_in_tree() and owner.plate.caption.get_parsed_text()==text
func row(id: int,x: int) -> Dictionary:
	return {"entryId":id,"itemId":id,"channel":"R","slot":0,"x":x,"y":0,"width":1,"height":1,"stack":1,"name":"Item "+str(id),"tooltip":Rich.parse("Item "+str(id)),"price":5,"pending":false}
func key(code: int,down: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down; surface.push_input(event,true); await frames(1)
func keyboard_checks(parent: Control,inventory,other,top: Button) -> void:
	var table:=Table.new().parse(inventory.item_tooltips.catalog.read_resource("keymap",2017).get_string_from_ascii())
	var bindings:=Bindings.new(); parent.add_child(bindings); bindings.configure(""); bindings.install(table)
	var pointer:=WorldInput.new(); parent.add_child(pointer); pointer.set_key_bindings(bindings); pointer.set_physics_process(false)
	Preferences.apply(1000000); Preferences.apply_doubletap(200)
	await motion(Vector2(1200,800)); await motion(top.get_global_rect().get_center())
	check(not other.tooltips.plate.visible,"A real generic tooltip waits under the configured one-second normal delay")
	await key(KEY_TAB,true)
	check(bindings.highlighted and pointer.tab and visible(other.tooltips,"Foreground hint") and other.tooltips.router.policy.delay==1,"Actual source highlight key immediately enables both world highlighting and the shared native GUI hint")
	var source: Button=inventory.ui.item_controls.examine; await motion(source.get_global_rect().get_center())
	check(await wait_for(func():return visible(inventory.item_tooltips,"Examine an item")),"Moving to another source control while highlighting uses instant tooltip mode")
	await create_timer(0.22).timeout; await key(KEY_TAB,false)
	check(not bindings.highlighted and not pointer.tab and inventory.item_tooltips.router.policy.delay==1000000 and visible(inventory.item_tooltips,"Examine an item"),"A normal hold release restores the configured delay and leaves the original already-visible tooltip intact")
	await motion(top.get_global_rect().get_center())
	for down in [true,false,true,false]: await key(KEY_TAB,down)
	check(bindings.highlight_policy.phase==4 and bindings.highlight_policy.held==1 and bindings.highlight_key==0,"Actual double-tap enters the original latched state after physical release")
	check(await wait_for(func():return bindings.highlighted and pointer.tab and visible(other.tooltips,"Foreground hint")),"Original held refresh restores world/GUI highlighting for the latched key")
	await key(KEY_TAB,true); await key(KEY_TAB,false)
	check(not bindings.highlighted and not pointer.tab and bindings.highlight_policy.held==0,"The next real highlight-key tap releases the original latch")
	Preferences.apply_doubletap(0)
	for down in [true,false,true,false]: await key(KEY_TAB,down)
	check(not bindings.highlighted and not pointer.tab and bindings.highlight_policy.held==0 and bindings.highlight_policy.phase==0,"The source zero threshold disables latching for actual rapid highlight-key taps")
	Preferences.apply_doubletap(200)
	var ticket:=bindings.begin()
	check(bindings.assign("normal",97,{"key":KEY_H,"modifiers":0},ticket) and bindings.commit(ticket),"The active server Keymap action accepts a private highlight rebind")
	await key(KEY_TAB,true); await key(KEY_TAB,false)
	check(not bindings.highlighted and not pointer.tab,"Original Tab no longer activates a rebound highlight action")
	await motion(Vector2(1200,800)); await motion(top.get_global_rect().get_center()); await key(KEY_H,true)
	check(bindings.highlighted and pointer.tab and visible(other.tooltips,"Foreground hint"),"The rebound key drives the same world and instant native tooltip path")
	var edit:=LineEdit.new(); parent.add_child(edit); edit.position=Vector2(1000,650); edit.size=Vector2(150,32); await click(edit.get_global_rect().get_center())
	check(edit.has_focus() and not bindings.highlighted and not pointer.tab and bindings.highlight_key==0,"Actual text-field focus clears physical/latch ownership and instant mode")
	await key(KEY_H,false); await key(KEY_H,true); await key(KEY_H,false)
	check(not bindings.highlighted and not pointer.tab,"GUI-consumed highlight typing/release cannot resurrect world highlighting")
	edit.release_focus(); edit.queue_free(); await frames()
	ticket=bindings.begin(); await key(KEY_H,true)
	check(bindings.start_capture("hotbar",0,ticket) and not bindings.highlighted and not pointer.tab,"Starting actual key capture retires the shared highlight state")
	await create_timer(0.12).timeout
	check(not bindings.highlighted and not pointer.tab and not bindings.is_processing(),"A held-key refresh cannot restart highlights during assignment capture")
	await key(KEY_H,false); bindings.retire(); await key(KEY_H,true); bindings.close(); await frames()
	check(not bindings.highlighted and not pointer.tab and bindings.highlight_policy.held==0,"Closing the key/resource scope clears its world/tooltip mode before retirement")
	pointer.queue_free(); bindings.queue_free(); Preferences.apply(100000); await frames(3)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
		if argument.begins_with("--install="): install=argument.trim_prefix("--install=")
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Read-only installed original resource catalog mounted")
	var text:=Talk.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Installed original native TLK opened")
	Preferences.apply(100000)
	surface=SubViewport.new(); surface.size=Vector2i(1280,900); surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var probe:=InputProbe.new(); surface.add_child(probe)
	var parent:=Control.new(); parent.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.size=Vector2(1280,900); surface.add_child(parent)
	var inventory:=Inventory.new(); parent.add_child(inventory); inventory.configure(parent,catalog,output+".cache",text,output+".layout")
	var ready: bool=await wait_for(func():return inventory.frame_skin.layout_ready and inventory.frame_skin.failure.is_empty(),30)
	check(ready,"Actual native inventory painter loads original GUI/models and creates source controls headlessly")
	if ready:
		var ui=inventory.ui; ui.open(); ui.receive({"kind":"inventory-view","viewId":1,"title":"Tooltip input","items":[row(101,0),row(102,1)],"layout":[],"page":0,"summary":{"gold":100,"capacity":100,"weight":1},"armorClass":15,"container":{},"store":{}}); await frames(4)
		ui.position=Vector2(20,20); await frames()
		var owner=inventory.item_tooltips; var router=owner.router; var button: Button=ui.item_controls.examine
		check(button.get_meta("native_tooltip_managed",false) and button.get_class()=="Button" and button.tooltip_text=="Examine an item" and button.get_tooltip(Vector2.ZERO).is_empty(),"Shared painter preserves the real Button and hint text while suppressing its duplicate engine popup")
		await motion(button.get_global_rect().get_center())
		check(await wait_for(func():return visible(owner,"Examine an item")),"Actual source-button hover displays its native source bubble")
		var first_anchor: Vector2=owner.anchor_point; var first_position: Vector2=owner.plate.position
		await motion(first_anchor+Vector2(2,0))
		check(visible(owner,"Examine an item") and owner.anchor_point==first_anchor and owner.plate.position==first_position,"Small same-owner movement keeps the original trigger anchor instead of chasing the cursor")
		var before: bool=ui.examine_mode; await click(button.get_global_rect().get_center())
		check(ui.examine_mode!=before,"Actual source-button press still invokes its inventory controller action after tooltip script attachment")
		await click(button.get_global_rect().get_center())
		var a=ui.buttons[101]; var b=ui.buttons[102]
		var edge_a: Vector2=a.get_global_rect().end-Vector2(3,a.size.y*0.5); var edge_b: Vector2=b.get_global_rect().position+Vector2(3,b.size.y*0.5)
		await motion(edge_a); check(await wait_for(func():return visible(owner,"Item 101")),"Actual repository hover resolves the current item's rich caption")
		var repository_owner: int=router.policy.active
		check(repository_owner==a.get_parent().get_instance_id() and edge_a.distance_to(edge_b)<32,"Adjacent native item controls share their repository owner within the original movement radius")
		await motion(edge_b)
		check(not owner.plate.visible and router.policy.active==0,"Changing the hovered repository item immediately finishes its old tooltip even below the movement threshold")
		check(await wait_for(func():return visible(owner,"Item 102")),"The next repository item receives its own delayed source bubble")
		var changed: Dictionary=b.row.duplicate(true); changed.tooltip=Rich.parse("Updated caption"); b.refresh_row(changed,ui.view_id); await frames()
		check(not owner.plate.visible,"A retained item's changed presentation invalidates its visible tooltip")
		check(await wait_for(func():return visible(owner,"Updated caption")),"The retained item refreshes its text without requiring pointer exit or a new control")
		var other:=Painter.new(); parent.add_child(other); other.configure_source(catalog,output+".cache")
		var top:=Button.new(); top.position=edge_b-Vector2(10,10); top.size=Vector2(100,40); top.tooltip_text="Foreground hint"; top.focus_mode=Control.FOCUS_NONE; parent.add_child(top); other.tooltips.register_control(top)
		await frames(); await motion(edge_b)
		check(owner.router==other.tooltips.router and router.controllers.size()==2,"Independent painter scopes share one actual viewport tooltip router")
		check(await wait_for(func():return visible(other.tooltips,"Foreground hint") and not owner.plate.visible),"Actual foreground hit wins over the covered inventory without leaving two popups visible")
		var foreground_anchor: Vector2=other.tooltips.anchor_point
		await motion(foreground_anchor+Vector2(32,0))
		check(visible(other.tooltips,"Foreground hint") and other.tooltips.anchor_point==foreground_anchor,"Actual same-control movement at exactly 32 pixels preserves the visible bubble")
		await motion(foreground_anchor+Vector2(33,0))
		check(not other.tooltips.plate.visible,"Actual same-control movement beyond 32 pixels finishes the bubble and rearms its delay")
		check(await wait_for(func():return visible(other.tooltips,"Foreground hint") and other.tooltips.anchor_point==foreground_anchor+Vector2(33,0)),"The rearmed bubble captures its new trigger point")
		var key:=InputEventKey.new(); key.keycode=KEY_W; key.physical_keycode=KEY_W; key.pressed=true; surface.push_input(key,true); await frames(); key.pressed=false; surface.push_input(key,true); await frames()
		check(probe.keys==1 and visible(other.tooltips,"Foreground hint"),"Shared tooltip handling preserves unhandled movement keys and does not invent key-dismiss behavior")
		await click(Vector2(1200,800),MOUSE_BUTTON_MIDDLE); await click(Vector2(1200,800))
		check(probe.middle==1 and probe.ground==1,"Off-menu middle camera and ground clicks reach unhandled world input")
		await keyboard_checks(parent,inventory,other,top)
		var moved_parent:=Control.new(); moved_parent.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(moved_parent); var top_id:=top.get_instance_id(); top.reparent(moved_parent); await frames(3)
		check(other.tooltips.controls.has(top_id),"Reparenting a live source control preserves tooltip registration")
		await motion(top.get_global_rect().get_center()); check(await wait_for(func():return visible(other.tooltips,"Foreground hint")),"The reparented source control retains its live tooltip")
		owner.register_control(top)
		check(not other.tooltips.plate.visible and not other.tooltips.controls.has(top_id) and owner.controls.has(top_id),"Transferring a live control to another source scope immediately retires the old scope's popup and registration")
		check(await wait_for(func():return visible(owner,"Foreground hint")),"The receiving scope rearms the same control's tooltip instead of retaining old resource ownership")
		other.tooltips.register_control(top)
		check(not owner.plate.visible and not owner.controls.has(top_id) and other.tooltips.controls.has(top_id),"Returning the control preserves exclusive scope ownership and hides the previous popup")
		var retired_scope=other.tooltips; other.close(); await frames()
		check(not top.has_meta("native_tooltip_managed") and top.get_tooltip(Vector2.ZERO)=="Foreground hint" and router.controllers.size()==1 and other.tooltips==null and retired_scope.closed and not retired_scope.plate.visible,"Closing one painter restores its surviving controls, hides/releases its bubble owner and retains the other scope")
		top.queue_free(); moved_parent.queue_free(); other.queue_free(); await frames(3)
		changed.pending=true; b.refresh_row(changed,ui.view_id); await motion(edge_b)
		check(await wait_for(func():return visible(owner,"Updated caption") and b.disabled),"A disabled pending item remains inspectable by hover without enabling its input")
		changed.tooltip=Rich.parse(""); b.refresh_row(changed,ui.view_id); await frames()
		check(await wait_for(func():return not owner.plate.visible and owner.target!=null and owner.target.get_ref()==b),"An empty received replacement removes the bubble while preserving current hover ownership")
		changed.pending=false; changed.tooltip=Rich.parse("After drag"); b.refresh_row(changed,ui.view_id); await frames()
		await motion(a.get_global_rect().get_center())
		check(await wait_for(func():return visible(owner,"Item 101")),"The original item hover is ready for a real drag gesture")
		var drag_start: Vector2=a.get_global_rect().get_center()
		var down:=InputEventMouseButton.new(); down.position=drag_start; down.global_position=drag_start; down.button_index=MOUSE_BUTTON_LEFT; down.button_mask=MOUSE_BUTTON_MASK_LEFT; down.pressed=true; surface.push_input(down,true); await frames()
		var drag:=InputEventMouseMotion.new(); drag.position=drag_start+Vector2(16,0); drag.global_position=drag.position; drag.relative=Vector2(16,0); drag.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(drag,true); await frames(3)
		check(surface.gui_is_dragging() and not owner.plate.visible,"Actual inventory drag gesture suppresses the shared native tooltip")
		await motion(Vector2(1200,800)); down.position=Vector2(1200,800); down.global_position=down.position; down.pressed=false; down.button_mask=0; surface.push_input(down,true); await frames()
		check(not surface.gui_is_dragging(),"Releasing outside the menus ends the actual drag without a fabricated item result")
		await motion(edge_b); check(await wait_for(func():return visible(owner,"After drag")),"Native hover recovers after the engine drag ends")
		var removed_id: int=b.get_instance_id(); b.queue_free(); await frames(4)
		check(not owner.controls.has(removed_id) and not owner.plate.visible,"Freeing the displayed item hides its bubble and leaves no stale weak registry entry")
		inventory.close(); await frames(4)
		check(not surface.has_meta("native_tooltip_router"),"Closing the final controller retires the viewport singleton")
	else: inventory.close()
	inventory.queue_free(); parent.queue_free(); surface.queue_free(); await frames(4); text.close()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual source painter/inventory controls, native bubbles, real viewport input, shared scope/repository ownership and cleanup. Explicit authored views; no server disclosure or rendered-pixel claim."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
