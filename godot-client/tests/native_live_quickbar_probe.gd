extends RefCounted
# Owned original-server quickslot outcomes. Native controls receive real input;
# no frame_post_draw/raster/GPU wait, injected actor state or public endpoints.
var probe
var desktop
func click(point: Vector2,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var tree: SceneTree=probe.get_tree();var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;tree.root.push_input(motion,true);await tree.process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed;event.button_mask=(MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0;tree.root.push_input(event,true);await tree.process_frame
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;probe.get_tree().root.push_input(event,true);await probe.get_tree().process_frame
func open(index: int) -> bool:
	desktop.quickbar.render(2);await probe.get_tree().process_frame;await click(desktop.quickbar.buttons[index].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	return probe.check(desktop.radial.active or probe.ui.inventory.item_context.wheel.active,"Physical quickslot context opens from actual received index "+str(index))
func choose(slot: int) -> bool:
	if not probe.check(desktop.radial_entries.has(slot),"Source radial sector exists: "+str(slot)):return false
	await click(desktop.radial.buttons[slot].get_global_rect().get_center());return true
func macro_state(dialogs) -> Dictionary:
	var focus=probe.get_tree().root.gui_get_focus_owner()
	return {"stage":dialogs.stage,"scope":dialogs.scope.duplicate(true),"scopeValid":not dialogs.scope.is_empty() and desktop.shortcut_scope_valid(dialogs.scope),"identity":dialogs.identity(),"editorScope":dialogs.edit.scope.duplicate(),"wanted":dialogs.edit.wanted,"visible":dialogs.edit.is_visible_in_tree(),"focused":dialogs.edit.edit.has_focus(),"focusClass":focus.get_class() if is_instance_valid(focus) else "","focusPath":str(focus.get_path()) if is_instance_valid(focus) else "","text":dialogs.edit.edit.text,"caption":dialogs.edit.message.text,"receivedBinding":desktop.quick_bindings[35].duplicate(true)}
func run(owner) -> void:
	probe=owner;desktop=probe.desktop
	if not probe.check(DisplayServer.get_name()=="headless","Quickbar local acceptance runs without GPU/visible client"):return
	if not await probe.wait_for(func():return desktop.quick_bindings.size()==36 and desktop.quickbar_frame.layout_ready,"Original quickslot geometry and all36 received bindings prepare"):return
	var index:=35;var previous: Dictionary=desktop.quick_bindings[index].duplicate(true)
	if int(previous.get("type",0))!=0:
		desktop.assign(index,{"type":0})
		if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==0,"Protocol owner publishes the client-owned cleared scratch layout"):return
	if not await open(index):return
	if not await choose(4) or not await choose(2):return
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==6,"Nested native Actions/Talk publishes its client-owned shortcut layout"):return
	if not await open(index) or not await choose(3):return
	if not probe.check(int(desktop.target.get("type",0))==6,"Bound Talk Use enters actual native target selection"):return
	var speaker:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==5 and probe.ui.text.name(null,int(id))=="Native Speaker":speaker=int(id);break
	if not probe.check(speaker>=0,"Authoritative dialogue fixture creature is received"):return
	var conversation=probe.ui.conversation;var dialogue_timeline: Array=[];var dialogue_started:=Time.get_ticks_usec()
	var observe_dialogue: Callable=func(kind):
		if dialogue_timeline.size()<32:dialogue_timeline.append({"kind":kind,"usec":Time.get_ticks_usec()-dialogue_started,"entryId":conversation.entry_id,"pending":conversation.pending,"opened":conversation.opened,"visible":conversation.visible,"replies":conversation.reply_ids.size()})
	conversation.rendered.connect(observe_dialogue)
	desktop.world_click({"id":speaker,"position":Vector3.ZERO})
	if not await probe.wait_for(func():return conversation.visible and conversation.body.get_parsed_text().contains("FIRST_ENTRY"),"Quickslot Talk target opens the original server dialogue"):conversation.rendered.disconnect(observe_dialogue);return
	probe.check(true,"Dialogue body milestone retains actual pre-abort protocol readiness",{"entryId":conversation.entry_id,"pending":conversation.pending,"opened":conversation.opened,"replies":conversation.reply_ids.size(),"timeline":dialogue_timeline.duplicate(true)})
	if not await probe.wait_for(func():return conversation.entry_id>=0 and not conversation.pending and not conversation.end_button.disabled,"Original server replies make dialogue actions available"):conversation.rendered.disconnect(observe_dialogue);return
	conversation.choose(4294967295,true)
	if not probe.check(conversation.pending,"Actionable native abort dispatches through the real dialogue owner",{"entryId":conversation.entry_id,"timeline":dialogue_timeline.duplicate(true)}):conversation.rendered.disconnect(observe_dialogue);return
	var aborted: bool=await probe.wait_for(func():return not conversation.visible and probe.dialogue_history("GODOT_ABORT_ACK"),"Server acknowledges dialogue abort with its real abort script")
	probe.check(aborted,"Dialogue lifecycle timeline retained",{"timeline":dialogue_timeline.duplicate(true)})
	conversation.rendered.disconnect(observe_dialogue)
	if not aborted:return
	if not await open(index) or not await choose(4):return
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",-1))==0,"Bound quickslot Clear publishes the client-owned empty layout"):return
	desktop.assign(index,{"type":0})
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",-1))==0,"Client-owned scratch layout clears before macro creation"):return
	if not await open(index) or not await choose(0):return
	var dialogs=desktop.shortcut_dialogs
	if not await probe.wait_for(func():return dialogs.edit.layout_ready and dialogs.edit.wanted and dialogs.edit.edit.has_focus(),"Original macro Enter Label control becomes ready without raster/GPU waits"):return
	var macro_timeline: Array=[];var macro_started:=Time.get_ticks_usec()
	var observe_finished: Callable=func(accepted,value,ticket):
		if macro_timeline.size()<24:macro_timeline.append({"event":"finished-after-owner","usec":Time.get_ticks_usec()-macro_started,"accepted":accepted,"value":value,"ticket":ticket.duplicate(),"state":macro_state(dialogs)})
	var observe_request: Callable=func(message):
		if message.get("kind","")=="native-quickbar-assign" and int(message.get("index",-1))==index and macro_timeline.size()<24:macro_timeline.append({"event":"assignment-request","usec":Time.get_ticks_usec()-macro_started,"message":message.duplicate(true)})
	dialogs.edit.finished.connect(observe_finished);desktop.request.connect(observe_request)
	dialogs.edit.edit.text="Native macro";macro_timeline.append({"event":"before-label-enter","usec":Time.get_ticks_usec()-macro_started,"state":macro_state(dialogs)});await key(KEY_ENTER)
	macro_timeline.append({"event":"after-label-enter","usec":Time.get_ticks_usec()-macro_started,"state":macro_state(dialogs)})
	if not probe.check(dialogs.edit.message.text=="Input Command","Source macro second stage is the actual installed Input Command",{"timeline":macro_timeline.duplicate(true)}):dialogs.edit.finished.disconnect(observe_finished);desktop.request.disconnect(observe_request);return
	dialogs.edit.edit.text="/tk NATIVE_QUICKBAR_MACRO_ACK";macro_timeline.append({"event":"before-command-enter","usec":Time.get_ticks_usec()-macro_started,"state":macro_state(dialogs)});await key(KEY_ENTER)
	macro_timeline.append({"event":"after-command-enter","usec":Time.get_ticks_usec()-macro_started,"state":macro_state(dialogs)})
	var assigned: bool=await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==18 and str(desktop.quick_bindings[index].get("commandLabel",""))=="Native macro" and str(desktop.quick_bindings[index].get("commandLine",""))=="/tk NATIVE_QUICKBAR_MACRO_ACK","Client-owned macro layout contains separate source label and command fields")
	probe.check(assigned,"Macro source input/finished/request timeline retained",{"timeline":macro_timeline.duplicate(true),"afterWait":macro_state(dialogs)})
	dialogs.edit.finished.disconnect(observe_finished);desktop.request.disconnect(observe_request)
	if not assigned:return
	var sequence: int=probe.ui.chat.sequence
	if not await open(index) or not await choose(3):return
	if not await probe.wait_for(func():return probe.ui.chat.rows.any(func(row):return int(row.get("chat_sequence",0))>sequence and str(row.get("text","")).contains("NATIVE_QUICKBAR_MACRO_ACK")),"Macro Execute produces a new authoritative original-server chat echo"):return
	var export_before: int=probe.session.export_receipt_serial;probe.session.lobby_request({"kind":"lobby-export"})
	if not await probe.wait_for(func():return probe.session.export_receipt_serial>export_before and not probe.session.character_lobby.state.get("busy",true),"Original server exports its BIC while the source macro remains assigned",25):return
	var chest:=-1;var equipped_slot:=0
	for id in probe.ui.inventory.views:
		if str(probe.ui.inventory.views[id].row.channel)=="I":chest=int(id);equipped_slot=int(probe.ui.inventory.views[id].row.slot);break
	if not probe.check(chest>=0,"Original character supplies an actual equipped item",{"itemId":chest,"slot":equipped_slot,"baseItem":probe.item(chest).get("baseItem"),"location":desktop.objects.get(chest,{}).get("inventoryLocation"),"replicationRemoved":desktop.objects.get(chest,{}).get("replicationRemoved",false)}):return
	desktop.assign(index,{"type":1,"itemId":chest,"intParam":16711935})
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==1,"Client-owned item shortcut publishes without asserting a server echo"):return
	if not probe.check(int(desktop.quick_bindings[index].get("secondaryItemId",0))==2130706432,"Unpaired item layout agrees with original wire OBJECT_INVALID rather than retaining zero"):return
	probe.ui.inventory.ui.close_inventory()
	if not await probe.wait_for(func():return not probe.ui.inventory.ui.wanted,"Inventory closes before the quickslot-owned item test"):return
	if not await open(index):return
	var item_menu=probe.ui.inventory.item_context
	if not probe.check(item_menu.quickbar_owned and item_menu.entries.has(4) and item_menu.entries[4].action=="quickbar-clear" and not probe.ui.inventory.ui.wanted,"Item quickslot has its own valid Clear context while inventory remains closed"):return
	if not probe.check(item_menu.entries.has(6) and item_menu.entries[6].action=="unequip","Actual equipped quickslot exposes original Unequip"):return
	var unequip_at:=Time.get_ticks_usec();await click(item_menu.wheel.buttons[6].get_global_rect().get_center())
	var unequipped: bool=await probe.wait_for(func():return desktop.objects.get(chest,{}).get("equipmentOwnerId")==null and int(probe.current().get("clientEquipmentSlots",{}).get(str(equipped_slot),2130706432))==2130706432,"Received equipment result detaches this exact item while inventory stays closed")
	probe.check(unequipped,"Unequip retains exact canonical state and elapsed response time",{"itemId":chest,"slot":equipped_slot,"elapsedUsec":Time.get_ticks_usec()-unequip_at,"location":desktop.objects.get(chest,{}).get("inventoryLocation"),"locationStatus":desktop.objects.get(chest,{}).get("inventoryLocationStatus"),"attachmentOwner":desktop.objects.get(chest,{}).get("equipmentOwnerId"),"cachedGuiSlot":desktop.objects.get(chest,{}).get("inventoryEquipmentSlot"),"animation":probe.current().get("replicated",{}).get("animation"),"actionQueue":probe.current().get("playerState",{}).get("actionQueue",[])})
	if not unequipped:return
	if not await open(index):return
	var equip_sector:=-1
	for sector in item_menu.entries:
		var entry: Dictionary=item_menu.entries[sector]
		if entry.action=="equip" and int(entry.payload)==equipped_slot:equip_sector=int(sector);break
	if not probe.check(equip_sector>=0,"Source equipment builder offers the previous real equipment slot"):return
	var equip_at:=Time.get_ticks_usec();await click(item_menu.wheel.buttons[equip_sector].get_global_rect().get_center())
	var equipped: bool=await probe.wait_for(func():return desktop.objects.get(chest,{}).get("equipmentOwnerId")==desktop.actor_id and int(probe.current().get("clientEquipmentSlots",{}).get(str(equipped_slot),2130706432))==chest,"Received equipment result restores this exact item and slot through the original server")
	probe.check(equipped,"Equip retains exact canonical state and elapsed response time",{"itemId":chest,"slot":equipped_slot,"elapsedUsec":Time.get_ticks_usec()-equip_at,"attachmentOwner":desktop.objects.get(chest,{}).get("equipmentOwnerId"),"cachedGuiSlot":desktop.objects.get(chest,{}).get("inventoryEquipmentSlot")})
	if not equipped:return
	if not await open(index):return
	await click(item_menu.wheel.buttons[4].get_global_rect().get_center())
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",-1))==0,"Item quickslot Clear publishes the client-owned empty layout"):return
	# Isolate associate responsiveness before the existing ten-second Sit.
	if not await preload("res://tests/native_live_associate_quickbar_probe.gd").new().run(probe,self,index):return
	# Run the ten-second Sit only after item responsiveness is measured, so
	# the server's queued emote cannot delay an unrelated equipment action.
	if not await open(index):return
	for slot in [7,7,7,2]:
		if not await choose(slot):return
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==8 and int(desktop.quick_bindings[index].get("intParam",-1))==20,"Two native More pages publish the exact client-owned Sit shortcut"):return
	if not await open(index) or not await choose(3):return
	if not await probe.wait_for(func():return int(probe.current().get("replicated",{}).get("animation",-1))==47,"Original server replicates the quickslot emote animation",10):
		probe.check(false,"Emote diagnostic retains received animation",{"animation":probe.current().get("replicated",{}).get("animation"),"queue":probe.current().get("playerState",{}).get("actionQueue",[])});return
	desktop.assign(index,previous)
	await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",-1))==int(previous.get("type",0)),"Client-owned layout restores the previous scratch-slot type")
	probe.check(true,"Quickbar control timings retained",{"menus":desktop.shortcut_timings.duplicate(true),"scope":"CPU construction and headless actual-control input; renderer FPS/original pixels are separate."})
