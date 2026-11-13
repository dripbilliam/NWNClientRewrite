extends RefCounted
# Real original-server merchant and two-participant trade; no authored replies,
# fabricated inventory membership or tooltip control calls in the input path.
const Rich=preload("res://systems/native_data/rich_text.gd")
const Placement=preload("res://systems/native_data/item_tooltip.gd")
var p
var partner:=-1
var last_pointer:=Vector2.ZERO
func motion(point: Vector2) -> void:
	# Original window input supplies integer cursor coordinates. Keep the exact
	# injected point for fixed-anchor assertions rather than sampling it later.
	last_pointer=Vector2(Vector2i(point))
	var event:=InputEventMouseMotion.new(); event.position=last_pointer; event.global_position=last_pointer; Input.parse_input_event(event); await p.get_tree().process_frame
func click(button: Control) -> void:
	var point:=button.get_global_rect().get_center(); await motion(point)
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; Input.parse_input_event(event); await p.get_tree().process_frame
func hover(button,expected: Dictionary,label: String) -> bool:
	var bound: WeakRef=weakref(button)
	await motion(Vector2(1,1))
	var current=bound.get_ref()
	if not is_instance_valid(current): return p.check(false,label,{"failure":"The received item control retired before pointer entry"})
	await motion(current.get_global_rect().get_center())
	var owner=p.ui.inventory.item_tooltips
	return await p.wait_for(func():var live_target=bound.get_ref(); return is_instance_valid(live_target) and owner.target!=null and owner.target.get_ref()==live_target and owner.plate.is_visible_in_tree() and owner.plate.data.caption==expected and owner.plate.caption.get_parsed_text()==str(expected.text),label)
func run(probe,partner_id: int) -> bool:
	p=probe; partner=partner_id
	if not await merchant(): return false
	return await trade()
func merchant() -> bool:
	var icons=p.ui.inventory.icons
	if not await p.wait_for(func():return icons.requests.is_empty() and icons.assets.pending.is_empty() and icons.assets.running.is_empty(),"Real inventory icon workers finish native source preparation",30): return false
	if not p.check(icons.stats.errors.is_empty(),"Actual inventory icon source preparation has no errors",{"errors":icons.stats.errors}): return false
	await p.chat_enter("-native-store-setup")
	if not await p.wait_for(func():return p.ui.chat.rows.any(func(row):return str(row.get("text","")).contains("GODOT_STORE_READY")),"Original server creates the owned merchant stock before tooltip checks"): return false
	await p.chat_enter("-native-hud-merchant-prefix"); await p.chat_enter("-native-store")
	if not await p.wait_for(func():return p.ui.inventory.store.get("open",false) and p.ui.inventory.store_skin.built() and p.ui.inventory.ui.store_panel.visible,"Original OpenStore publishes the native merchant controls",30): return false
	var stock:=-1
	if not await p.wait_for(func():return p.ui.inventory.ui.buttons.values().any(func(button):return button.current() and button.row.get("channel","")=="M" and str(button.row.get("tooltip",{}).get("text","")).begins_with("NATIVE_MERCHANT_PREFIX\n")),"Actual merchant item metadata carries the server prefix into its native row"): return false
	for id in p.ui.inventory.ui.buttons:
		var button=p.ui.inventory.ui.buttons[id]
		if button.current() and button.row.get("channel","")=="M" and str(button.row.tooltip.text).begins_with("NATIVE_MERCHANT_PREFIX\n"): stock=int(id); break
	var button=p.ui.inventory.ui.buttons[stock]; var expected:=Rich.parse("NATIVE_MERCHANT_PREFIX\n"+p.ui.text.raw(p.item(stock).get("name",{}),p.desktop.actor_id))
	if not await hover(button,expected,"Actual merchant hover displays original server-authored rich tooltip text"): return false
	var panel=p.ui.inventory.ui.store_panel
	if not p.check(int(p.ui.inventory.store_view().get("pageCount",1))>1 and not panel.next.disabled,"Original server supplies multiple merchant pages and enables native Next",{"pages":p.ui.inventory.store_view().get("pageCount"),"disabled":panel.next.disabled}): return false
	var first_page: Array=[]
	for slot in panel.stock_buttons.values(): first_page.append(int(slot.row.entryId))
	await click(panel.next)
	if not await p.wait_for(func():return int(p.ui.inventory.store.get("page",-1))==1 and p.ui.inventory.ui.buttons.values().any(func(slot):return slot.current() and slot.row.get("channel","")=="M" and not first_page.has(int(slot.row.entryId)) and int(slot.row.get("y",99))%10<2),"Actual Next input receives distinct stock for the merchant's second page"): return false
	for slot in p.ui.inventory.ui.buttons.values():
		if slot.current() and slot.row.get("channel","")=="M" and not first_page.has(int(slot.row.entryId)) and int(slot.row.get("y",99))%10<2: button=slot; break
	if not await hover(button,button.row.tooltip,"Actual second-page merchant hover uses the current received item"): return false
	var owner=p.ui.inventory.item_tooltips; var scale_value:=maxf(0.01,absf(button.get_global_transform_with_canvas().get_scale().x))
	var expected_position:=Placement.position_at(last_pointer,p.get_viewport().get_visible_rect().size,owner.plate.size,true,scale_value)
	if not p.check(owner.anchor_point==last_pointer and owner.display_below and owner.plate.position.is_equal_approx(expected_position),"Original first-two-local-row tooltip placement applies on the second merchant page",{"actual":str(owner.plate.position),"expected":str(expected_position),"anchor":str(owner.anchor_point),"injected_pointer":str(last_pointer),"current_pointer":str(p.get_viewport().get_mouse_position()),"below":owner.display_below,"scale":scale_value,"plate_scale":str(owner.plate.scale),"size":str(owner.plate.size),"row":button.row.get("y"),"channel":button.row.get("channel"),"target":owner.target.get_ref().get_instance_id() if owner.target!=null and is_instance_valid(owner.target.get_ref()) else -1,"button":button.get_instance_id()}): return false
	await click(panel.close_button)
	return await p.wait_for(func():return not p.ui.inventory.store.get("open",true) and not panel.visible and owner.target==null and not owner.plate.visible,"Actual merchant Close reaches the original server and retires the tooltip")
func trade() -> bool:
	p.ui.inventory.ui.open()
	if not await p.wait_for(func():return p.ui.inventory.inventories.get("I",{}).get("entries",[]).any(func(row):return int(row.get("slot",0))==2),"Controlled original chest item is available for trade tooltip checks"): return false
	var own_item:=-1
	for row in p.ui.inventory.inventories.I.entries:
		if int(row.get("slot",0))==2: own_item=int(row.id); break
	await p.chat_enter("-native-hud-item-suffix")
	if not await p.wait_for(func():return str(p.item(own_item).get("field2c0",""))=="\nNATIVE_ITEM_SUFFIX","Original server assigns the main participant's trade-item suffix"): return false
	p.barter_peer_command("hud-command","item-prefix")
	if not await p.wait_for(func():var caption: Dictionary=p.session.test_barter_peer.get("equipmentCaption",{}); return int(caption.get("mode",-1))==2 and str(caption.get("text",""))=="NATIVE_ITEM_PREFIX\n","Second real participant receives its original server item-caption prefix"): return false
	p.inventory_action(own_item,"unequip"); p.barter_peer_command("prepare-item")
	if not await p.wait_for(func():return p.channel(own_item)=="R" and p.session.test_barter_peer.get("preparedItemId")!=null and p.session.test_barter_peer.backpack.has(p.session.test_barter_peer.preparedItemId),"Both original-server items are carried before offering them"): return false
	var peer_item:=int(p.session.test_barter_peer.preparedItemId)
	p.desktop.open_radial({"id":partner,"position":p.session.world.instances[partner].position},Vector2(650,350))
	if not p.check(p.desktop.radial_entries.get(7,{}).get("action","")=="barter","Native other-player radial retains the source Barter action"): return false
	p.desktop.radial.choose(7)
	if not await p.wait_for(func():return p.ui.barter.active() and p.ui.barter.view.visible and p.ui.barter.layout_ready,"Native radial opens a real original-server trade",30): return false
	if not await p.barter_offer(own_item): return false
	p.barter_peer_command("add",peer_item)
	if not await p.wait_for(func():return p.ui.barter.all_rows.has(peer_item) and p.channel(peer_item)=="A" and p.ui.barter.view.item_buttons.has(peer_item),"Other participant's real offer reaches the remote native trade grid"): return false
	var own_expected:=Rich.parse(p.ui.text.raw(p.item(own_item).get("name",{}),p.desktop.actor_id)+"\nNATIVE_ITEM_SUFFIX")
	var peer_expected:=Rich.parse("NATIVE_ITEM_PREFIX\n"+p.ui.text.raw(p.item(peer_item).get("name",{}),p.desktop.actor_id))
	if not await hover(p.ui.barter.view.item_buttons[own_item],own_expected,"Actual own-offer hover retains its original server suffix"): return false
	if not await hover(p.ui.barter.view.item_buttons[peer_item],peer_expected,"Actual remote-offer hover retains the other participant's server prefix"): return false
	await click(p.ui.barter.view.buttons.leftdeclinebut); p.barter_peer_command("lock",true)
	if not await p.wait_for(func():return p.ui.barter.state.ownLocked and p.ui.barter.state.otherLocked and not p.ui.barter.view.buttons.leftacceptbut.disabled,"Both original-server offer locks update native trade control availability"):
		p.check(false,"Retain live trade locking state before teardown",{"active":p.ui.barter.active(),"state":p.ui.barter.state,"pending":p.ui.barter.pending,"stats":p.ui.barter.stats,"peer":p.session.test_barter_peer.get("barter",{}),"accept_disabled":p.ui.barter.view.buttons.leftacceptbut.disabled})
		return false
	if not await hover(p.ui.barter.view.item_buttons[own_item],own_expected,"Locked own-offer control still exposes its native tooltip"): return false
	await click(p.ui.barter.view.buttons.leftcancelbut)
	if not await p.wait_for(func():return not p.ui.barter.active() and p.channel(own_item)=="R" and p.barter_peer_has(peer_item) and not p.ui.inventory.item_tooltips.plate.visible,"Actual Cancel returns both real items and retires the trade tooltip"): return false
	if not await p.wait_for(func():return p.ui.inventory.ui.items.has(own_item) and p.ui.inventory.ui.items[own_item].channel=="R" and not p.ui.inventory.ui.items[own_item].pending and p.ui.inventory.ui.buttons.has(own_item) and p.ui.inventory.ui.buttons[own_item].current(),"Returned original item publishes a current carried control before equipment restoration"): return false
	var sent_before: int=p.ui.inventory.stats.commands
	p.ui.inventory.ui.operation(own_item,"equip",{"slot":2}); p.barter_peer_command("restore-item")
	if not await p.wait_for(func():return p.channel(own_item)=="I","Original server restores the controlled actor's equipment after the canceled test"):
		p.check(false,"Retain actual equipment-restoration state",{"sent":int(p.ui.inventory.stats.commands)-sent_before,"channel":p.channel(own_item),"row":p.ui.inventory.ui.items.get(own_item,{}),"notice":p.ui.inventory.ui.notice.text,"pending":p.ui.inventory.pending.get(own_item,{}),"stale":p.ui.inventory.stats.stale_input})
		return false
	p.barter_peer_command("hud-command","item-clear"); await p.chat_enter("-native-hud-item-clear")
	if not await p.wait_for(func():var caption: Dictionary=p.session.test_barter_peer.get("equipmentCaption",{}); return int(caption.get("mode",-1))==0 and int(p.item(own_item).get("field2b8",-1))==0,"Both original participants clear test captions on their restored items"): return false
	p.ui.inventory.ui.close_inventory(); return true
