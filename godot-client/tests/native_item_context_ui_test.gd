extends "res://tests/native_inventory_equipment_ui_test.gd"
var abilities: Array=[]
func drag_item(from: Vector2,to: Vector2) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=from; root.push_input(motion,true); await process_frame
	var button:=InputEventMouseButton.new(); button.position=from; button.button_index=MOUSE_BUTTON_LEFT; button.pressed=true; root.push_input(button,true); await process_frame
	for point in [from+Vector2(12,0),to]:
		motion=InputEventMouseMotion.new(); motion.position=point; motion.relative=Vector2(12,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion,true); await process_frame; await process_frame
	button=InputEventMouseButton.new(); button.position=to; button.button_index=MOUSE_BUTTON_LEFT; button.pressed=false; root.push_input(button,true); await process_frame
func choose(owner,action: String) -> bool:
	for slot in owner.item_context.entries:
		if owner.item_context.entries[slot].action==action:
			owner.item_context.wheel.choose(int(slot)); return true
	return false
func additional_checks(owner,output: String,fixture: Dictionary) -> void:
	var context=owner.item_context; var wheel=context.wheel
	context.ability_selected.connect(func(binding):abilities.append(binding.duplicate(true)))
	fixture.packed.item.canUse=true; owner.signature=""; owner.refresh()
	check(await wait_for(func():return wheel.layout_ready and wheel.center_frame.texture!=null),"Original item wheel layout/frame resources finish natively")
	await click(owner.ui.buttons[13].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(wheel.active and context.entries.has(0) and context.entries[0].action=="examine" and context.entries.has(4) and context.entries[4].action=="drop","Actual inventory right click uses original Examine/Drop slot layout")
	var before:=requests.size(); await click(wheel.buttons[0].get_global_rect().get_center())
	check(requests.size()==before+1 and requests[-1].kind=="examine" and requests[-1].targetId==13 and not wheel.active,"Actual item wheel Examine emits its canonical request and dismisses")
	owner.pending[13]={"operation":"learn","at":Time.get_ticks_msec()}; owner.receive({"kind":"inventory-ack","operation":"learn","itemId":13,"alternate":1})
	check(owner.pending.has(13),"Alternate-inventory learn acknowledgements cannot clear controlled-item pending state")
	owner.receive({"kind":"inventory-ack","operation":"learn","itemId":13,"alternate":0}); check(not owner.pending.has(13),"Controlled learn acknowledgement releases only its own pending learn")
	owner.pending[13]={"operation":"drop","at":Time.get_ticks_msec()}; owner.receive({"kind":"inventory-ack","operation":"learn","itemId":13,"alternate":0})
	check(owner.pending.has(13),"A late learn reply cannot clear a later unrelated item action"); owner.pending.clear(); owner.signature=""; owner.refresh()
	owner.item_menu(13,Vector2(680,360)); var stale:={"kind":"radial-select","requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":4}; owner.view_serial+=1; before=requests.size(); context.input(stale)
	check(requests.size()==before and not wheel.active,"Repository generation change rejects stale menu commands")
	owner.signature=""; owner.refresh()
	# Server-specific item powers deliberately include a negative subradial cell.
	# Skipping that missing spell must retain the child's physical high WORD.
	owner.text_owner.tables.spells={"orderedRows":[{"Name":"549","IconResRef":"is_light","TargetType":"3","SubRadSpell1":"-1","SubRadSpell2":"1","SubRadSpell3":"2"},{"Name":"550","IconResRef":"is_light","TargetType":"1"},{"Name":"551","IconResRef":"is_light","TargetType":"2"}]}
	var properties: Array=[]; var rows: Array=[]
	for index in 10: properties.append({"type":15,"subtype":index,"costValue":2,"remaining":1}); rows.append({"SpellIndex":0 if index==0 else 1,"Name":549+index})
	owner.text_owner.tables.iprp_spells={"orderedRows":rows}; fixture.packed.item.properties=properties; fixture.packed.item.propertyUses=[5,4,3,2,1,6,7,8]; owner.signature=""; owner.refresh(); owner.item_menu(13,Vector2(680,360))
	check(context.entries[3].action=="variants" and context.entries[3].uses=="5" and context.entries[7].action=="more","Item root uses original power slots, authoritative counts and More from the third cast property")
	wheel.choose(7)
	check(wheel.depth==1 and int(context.entries[0].payload)&65535==2 and context.entries[7].action=="more","More page keeps physical property indices and a seven-entry page")
	wheel.back(); wheel.choose(3)
	check(wheel.depth==1 and not context.entries.has(0) and context.entries.has(1) and context.entries.has(2),"Missing child spell does not shift the original item-family variant slots")
	var drag: Dictionary=wheel.buttons[2].payload.duplicate(true)
	check(context.can_shortcut(drag) and int(context.binding(drag).intParam)==131072,"Item-family child can drag a distinct original packed variant to quickbars")
	var quickbar=preload("res://systems/server_quickbar.gd").new(); root.add_child(quickbar); quickbar.setup(); quickbar.radial_valid=context.can_shortcut
	var shortcuts: Array=[]
	for index in 36: shortcuts.append({"label":"Empty","empty":true,"enabled":true,"uses":null})
	var shortcut_requests: Array=[]; quickbar.request.connect(func(message):shortcut_requests.append(message.duplicate(true)))
	quickbar.receive({"kind":"quickbar-view","quickbarId":71,"rows":shortcuts}); quickbar.position=Vector2(20,700); await process_frame
	await drag_item(wheel.buttons[2].get_global_rect().get_center(),quickbar.buttons[0].get_global_rect().get_center())
	check(shortcut_requests.size()==1 and shortcut_requests[0].kind=="item-radial-shortcut" and shortcut_requests[0].slot==2 and shortcut_requests[0].quickbarId==71,"Actual native drag from a child power reaches the quickbar with its item-menu lifetime")
	quickbar.free()
	before=abilities.size(); await click(wheel.buttons[2].get_global_rect().get_center())
	check(abilities.size()==before+1 and int(abilities[-1].intParam)==131072 and int(abilities[-1].itemId)==13 and not wheel.active,"Native child selection carries the actual item, property and physical child index")
	owner.item_menu(13,Vector2(680,360)); wheel.choose(3); drag=wheel.buttons[2].payload.duplicate(true); context.cancel()
	check(not context.can_shortcut(drag),"Dismissed family menu cannot assign a stale item power")
	fixture.packed.item.properties=[]; fixture.packed.item.stackSize=4; owner.signature=""; owner.refresh(); owner.item_menu(13,Vector2(680,360))
	# Equipable test items may replace Split at slot6, exactly as native6af0.
	owner.views[13].row.slotMask=0; context.refresh()
	check(choose(owner,"split"),"Native Split action opens the original amount owner")
	check(await wait_for(func():return owner.stack_dialog.layout_ready and owner.stack_dialog.modal.visible),"Original INV_STACKSPLIT artwork and controls are shown")
	owner.stack_dialog.number.text="2"; before=requests.size(); owner.stack_dialog.buttons.okbutton.pressed.emit()
	check(requests.size()==before+1 and requests[-1].kind=="item-action" and requests[-1].operation=="split" and requests[-1].amount==2 and fixture.packed.item.stackSize==4,"Amount confirmation sends an original-compatible split without changing the local stack")
	owner.receive({"kind":"inventory-result","itemId":13,"operation":"move","success":false}); owner.signature=""; owner.refresh()
	owner.stack_dialog.open_item({"viewId":owner.view_serial,"entryId":13}); owner.view_serial+=1; before=requests.size(); owner.stack_dialog.confirm()
	check(requests.size()==before and not owner.stack_dialog.modal.visible,"Stale split dialog cannot act on a replaced repository view")
	owner.signature=""; owner.refresh()
	owner.store={"open":true,"generation":31,"sellRate":100,"buyRate":50,"identifyPrice":10,"gold":-1,"panel":0,"page":0}; fixture.packed.item.cost=8; fixture.packed.inventoryLocation={"channel":"M","ownerId":77,"x":0,"y":0}; owner.inventories.R.entries=[]; owner.inventories.M={"entries":[{"id":13,"x":0,"y":0}],"pageCount":1}; owner.signature=""; owner.refresh()
	owner.ui.item_menu(13,Vector2(700,350))
	check(wheel.active and context.entries.size()==2 and context.entries[0].action=="examine" and context.entries[2].action=="buy","Merchant right click is enabled and uses original Examine/Buy slots")
	before=requests.size(); await click(wheel.buttons[2].get_global_rect().get_center())
	check(requests.size()==before+1 and requests[-1].kind=="native-store" and requests[-1].operation=="buy" and requests[-1].storeGeneration==31 and fixture.packed.inventoryLocation.channel=="M","Native merchant wheel sends a current store request without predicting ownership")
	owner.pending.clear(); owner.signature=""; owner.refresh(); owner.item_menu(13,Vector2(700,350)); stale={"kind":"radial-select","requestId":wheel.request_id,"menuId":wheel.menu_id,"slot":2}; owner.store.generation=32; before=requests.size(); context.input(stale)
	check(requests.size()==before and not wheel.active,"A replaced store generation rejects an old purchase wheel")
	owner.store={}; fixture.packed.inventoryLocation={"channel":"R","ownerId":1,"x":0,"y":0}; owner.inventories.erase("M"); owner.inventories.R.entries=[{"id":13,"x":0,"y":0}]; fixture.packed.item.properties=properties; owner.signature=""; owner.refresh()
	for scale in [1.0,1.5,2.0]:
		root.content_scale_factor=scale; await process_frame; owner.item_menu(13,Vector2(400,250)); wheel.choose(3)
		check(await wait_for(func():return owner.frame_skin.art.waiting.is_empty() and owner.frame_skin.art.models.pending.is_empty() and not owner.frame_skin.art.models.active),"Original item family artwork finishes at scale "+str(scale))
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-family-"+str(scale)+".png")
		check(wheel.stage.visible and wheel.buttons[1].visible and wheel.icons[1].texture!=null and wheel.buttons[1].get_global_rect().encloses(wheel.icons[1].get_global_rect()),"Item family icon remains rendered inside its original button at scale "+str(scale))
		context.cancel()
	root.content_scale_factor=1.0; additional_evidence={"item_context":context.snapshot(),"abilities":abilities.duplicate(true),"full_item_parity":false}
