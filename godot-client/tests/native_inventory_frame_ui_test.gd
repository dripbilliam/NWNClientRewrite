extends "res://tests/native_inventory_equipment_ui_test.gd"
var surface: SubViewport
var surface_holder: TextureRect
func parent_surface() -> Node:
	surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	surface.gui_disable_input=false; surface.handle_input_locally=true; surface.notify_mouse_entered()
	surface_holder=TextureRect.new(); surface_holder.mouse_filter=Control.MOUSE_FILTER_IGNORE; surface_holder.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; surface_holder.texture=surface.get_texture(); root.add_child(surface_holder); surface_holder.size=root.size
	return surface
func event_surface() -> Viewport: return surface if is_instance_valid(surface) else root
func motion(point: Vector2,relative: Vector2,held: bool=true) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=relative; event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; event_surface().push_input(event,true); await process_frame
func mouse(point: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; event_surface().push_input(event,true); await process_frame
func hovered() -> String:
	var control: Variant=event_surface().call("gui_get_hovered_control") if event_surface().has_method("gui_get_hovered_control") else null
	return str(control.get_path()) if is_instance_valid(control) else "none"
func additional_checks(owner,output: String,fixture: Dictionary) -> void:
	var ui=owner.ui; var frame=owner.frame_skin
	var title_events: Array=[]
	ui.heading.gui_input.connect(func(event):
		if event is InputEventMouseButton: title_events.append({"pressed":event.pressed,"global":str(event.global_position),"position":str(event.position),"dragging":ui.dragging}))
	check(frame.layout_ready and frame.failure.is_empty() and not ui.window_column.visible,"Original native inventory frame replaces the generic window layout")
	check(await wait_for(func():return frame.fonts.fonts.has("fnt_galahad14")),"Original inventory bitmap font finishes native preparation")
	check(ui.heading.get_meta("native_font_applied","")=="fnt_galahad14" and ui.heading.get_theme_font("font")==frame.fonts.fonts.get("fnt_galahad14") and ui.heading.get_theme_font_size("font_size")==17,"Inventory title uses the original Galahad glyph atlas and17-pixel source metrics")
	check(frame.labels.gplabel.get_theme_font("font")==frame.fonts.fonts.get("fnt_galahad14") and frame.labels.gplabel.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Inventory footer uses the shared original bitmap font rather than a generic fallback")
	check(ui.size.distance_to(Vector2(360,470))<0.001 and ui.repository.cell_size==33 and ui.repository.bottom_origin,"Original extent and33px bottom-origin backpack are active")
	check(frame.labels.gplabel.text=="GP: 27" and frame.labels.weightlabel.text=="15" and frame.labels.maxweightlabel.text=="100","Original footer controls use only received gold and rounded weight/capacity")
	check(ui.close_button.size.distance_to(frame.button_geometry[ui.close_button.get_instance_id()].rect.size)<0.001,"Icon-only close button retains its rendered original up-pose footprint")
	var item: Dictionary=ui.items[13]
	check(ui.buttons[13].position.distance_to(Vector2(0,(6-int(item.height))*33))<0.001,"Received backpack row zero displays from the native bottom edge")
	var sent_before:=requests.size(); await click(ui.item_controls.examine.get_global_rect().get_center())
	if not check(ui.examine_mode and requests.size()==sent_before,"Original Examine button starts selection without sending a fabricated item action"):
		additional_evidence={"surface_mouse":str(event_surface().get_mouse_position()),"root_mouse":str(root.get_mouse_position()),"hover":hovered(),"scope":"Failed isolated input setup; remaining interaction checks were not executed"}; return
	await click(ui.buttons[11].get_global_rect().get_center())
	check(not ui.examine_mode and requests.back().kind=="examine" and int(requests.back().targetId)==11,"Examine mode sends the clicked authoritative item and resets after selection")
	await click(ui.pages[1].get_global_rect().get_center())
	check(await wait_for(func():return int(ui.state.page)==1),"Original page-tab click switches the active repository page")
	check(requests.back().kind=="inventory-page" and int(requests.back().page)==1 and owner.inventories.R.entries.size()==1,"Page selection sends the real typed request without inventing membership")
	await click(ui.pages[0].get_global_rect().get_center())
	check(await wait_for(func():return int(ui.state.page)==0 and ui.buttons.has(13)),"Returning through the original tab restores current item controls")
	var source: Vector2=ui.buttons[13].get_global_rect().get_center(); var target: Vector2=ui.repository.global_position+Vector2(3*33+16,33+16)
	await motion(source,Vector2.ZERO,false); await mouse(source,true); await motion(source+Vector2(12,-12),Vector2(12,-12)); await motion(target,target-source-Vector2(12,-12)); await process_frame
	check(event_surface().gui_is_dragging() and int(event_surface().gui_get_drag_data().get("entryId",-1))==13,"Real item drag retains the private current view/item payload")
	var drop_hover:=hovered(); var valid_drop: bool=ui.can_drop(event_surface().gui_get_drag_data(),0)
	await mouse(target,false)
	additional_evidence.drop={"request":requests.back().duplicate(true),"source_row":item.duplicate(true),"source":str(source),"target":str(target),"view":ui.view_id,"dragging_after_release":event_surface().gui_is_dragging(),"hover":drop_hover,"valid":valid_drop,"repository":str(ui.repository.get_global_rect()),"visible":ui.repository.is_visible_in_tree(),"callback":ui.repository.last_drop.duplicate(true)}
	check(requests.back().kind=="item-action" and requests.back().operation=="move" and int(requests.back().x)==3 and int(requests.back().y)==4 and int(fixture.packed.inventoryLocation.y)==0,"Actual drop converts screen rows to native coordinates and waits for authoritative transfer")
	owner.receive({"kind":"inventory-result","itemId":13,"operation":"move","success":false}); owner.refresh(); await process_frame
	check(ui.notice.visible and ui.notice.text=="The server rejected that item action.","Actual server rejection remains visible beside the original frame")
	var initial: Vector2=ui.position; var heading: Vector2=ui.heading.get_global_rect().get_center()
	await motion(heading,Vector2.ZERO,false); var title_hover:=hovered(); await mouse(heading,true); await motion(heading+Vector2(70,40),Vector2(70,40)); await mouse(heading+Vector2(70,40),false)
	additional_evidence.title_drag={"initial":str(initial),"after":str(ui.position),"mouse":str(ui.get_global_mouse_position()),"target":str(heading+Vector2(70,40)),"events":title_events,"hover":title_hover,"heading":str(ui.heading.get_global_rect())}
	check(ui.position.distance_to(initial+Vector2(70,40))<1 and not ui.dragging,"Original title still drags and releases the actual inventory window")
	var config:=ConfigFile.new(); check(config.load(output+".layout.cfg")==OK and config.get_value("positions","inventory",Vector2.ZERO)==ui.position,"Native-frame dragging persists the existing inventory position key")
	var retained: Vector2=ui.position
	await click(ui.close_button.get_global_rect().get_center())
	check(not ui.wanted and requests.back().kind=="inventory-close","Original close control retires the real inventory session")
	ui.open(); owner.refresh(); await process_frame
	check(ui.wanted and ui.position==retained,"Reopening preserves the dragged native window position")
	ui.creature_slots=true; ui.render(); await process_frame
	check(ui.size.distance_to(Vector2(360,550))<0.001 and frame.top.visible and frame.bottom.visible and not frame.full.visible,"Optional creature targets expand the frame without stretching its original footer artwork")
	for draw in 3: await process_frame
	root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-creature-slots.png")
	ui.creature_slots=false; ui.render()
	var bag:={"id":20,"objectType":6,"item":fixture.weapon_item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":0,"y":2}}; bag.item.name={"text":"Original container"}
	for index in owner.text_owner.tables.baseitems.orderedRows.size():
		if owner.IconPlan.number(owner.IconPlan.row(owner.text_owner.tables,"baseitems",index).get("Container"))!=0: bag.item.baseItem=index; break
	var content:={"id":14,"objectType":6,"item":fixture.weapon_item.duplicate(true),"inventoryLocation":{"ownerId":20,"channel":"C","x":2,"y":0}}
	var container_raw: Dictionary=fixture.raw.duplicate(true); container_raw.containers=[["C",20]]; container_raw.inventories.append(["C",{"entries":[{"id":14,"x":2,"y":0}],"pageCount":2}])
	owner.set_world(1,3,1,[fixture.actor,fixture.equipped,fixture.held,fixture.packed,bag,content],container_raw); owner.refresh()
	check(await wait_for(func():return frame.container_stage.visible and ui.buttons.has(14) and ui.buttons[14].image.texture!=null),"Received container state opens original container controls and native icons")
	check(not ui.equipment.visible and ui.container_repository.cell_size==33 and ui.container_repository.bottom_origin and ui.container_repository.size==Vector2(231,165),"Original container replaces equipment with its7×5 bottom-origin repository")
	check(ui.container_page.text=="01/02" and ui.container_title.text==owner.text_owner.raw({"strRef":6685}) and frame.container_drag.tooltip_text=="Original container","Original container caption/page format preserves the received name in its tooltip")
	var before_container_drag: Vector2=ui.position; var container_title_point: Vector2=frame.container_drag.get_global_rect().get_center()
	await motion(container_title_point,Vector2.ZERO,false); await mouse(container_title_point,true); await motion(container_title_point+Vector2(20,15),Vector2(20,15)); await mouse(container_title_point+Vector2(20,15),false)
	check(ui.position.distance_to(before_container_drag+Vector2(20,15))<1 and not ui.dragging,"Container header retains native-window dragging")
	for draw in 3: await process_frame
	root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-container.png")
	await click(ui.container_controls.next.get_global_rect().get_center())
	check(await wait_for(func():return int(ui.state.container.page)==1),"Original container right arrow selects the next page")
	check(requests.back().kind=="inventory-container" and requests.back().operation=="next" and int(requests.back().targetId)==20,"Container page control retains the received owner identity")
	await click(ui.container_controls.previous.get_global_rect().get_center()); check(await wait_for(func():return int(ui.state.container.page)==0),"Original container left arrow returns to the first page")
	check(await wait_for(func():return owner.gold.layout_ready),"Native gold amount controls are available for an open container")
	await click(frame.gold_button.get_global_rect().get_center()); owner.gold.number.text="5"; await click(owner.gold.buttons.okbutton.get_global_rect().get_center())
	var gold_container_count:=requests.size(); var gold_container_point: Vector2=ui.container_repository.get_global_transform()*Vector2(181,49)
	await motion(gold_container_point,Vector2.ZERO,false); await click(gold_container_point)
	check(requests.size()==gold_container_count+1 and requests.back().kind=="inventory-gold" and requests.back().targetId==20 and requests.back().amount==5 and not requests.back().placement,"Actual container gold drop uses the original target/default flag and waits for the server")
	await click(ui.container_controls.close.get_global_rect().get_center())
	check(requests.back().kind=="inventory-container" and requests.back().operation=="close" and int(owner.containers.C)==20,"Container close sends the original typed operation and waits for replication")
	owner.set_world(1,3,1,[fixture.actor,fixture.equipped,fixture.held,fixture.packed],fixture.raw); owner.refresh(); await process_frame
	check(not frame.container_stage.visible and ui.equipment.visible and ui.size.distance_to(Vector2(360,470))<0.001,"Authoritative container closure restores original equipment and frame geometry")
	var gold=owner.gold
	check(await wait_for(func():return gold.layout_ready or not gold.failure.is_empty()),"Original gold amount resources finish native preparation")
	check(gold.layout_ready and gold.failure.is_empty() and not frame.gold_button.disabled,"Original gold amount/drag action is connected: "+JSON.stringify(gold.snapshot()))
	await click(frame.gold_button.get_global_rect().get_center())
	check(gold.modal.visible and gold.maximum==27 and gold.number.text=="1","Actual gold button opens the original amount panel with received balance")
	await click(gold.buttons.allbutton.get_global_rect().get_center())
	check(gold.number.text=="27","Original All control selects the received balance")
	await RenderingServer.frame_post_draw
	event_surface().get_texture().get_image().save_png(output.trim_suffix(".json")+"-gold-amount.png")
	await click(gold.buttons.downbutton.get_global_rect().get_center())
	check(gold.number.text=="26","Original Down control decrements the amount")
	await click(gold.buttons.upbutton.get_global_rect().get_center())
	check(gold.number.text=="27","Original Up control increments and clamps to the balance")
	await click(gold.buttons.cancelbutton.get_global_rect().get_center())
	check(not gold.modal.visible and not event_surface().gui_is_dragging(),"Cancel closes the amount panel without a transfer")
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="7"
	gold.world_pick=func(_point):return {"id":-1,"position":Vector3(4,0,-5)}
	var request_count:=requests.size()
	await click(gold.buttons.okbutton.get_global_rect().get_center())
	check(not gold.modal.visible and event_surface().gui_is_dragging() and int(gold.payload.get("amount",0))==7,"Original OK starts a private gold drag instead of changing the balance")
	await motion(Vector2(1000,550),Vector2.ZERO,false); await click(Vector2(1000,550))
	check(requests.size()==request_count+1 and requests.back().kind=="inventory-gold" and requests.back().amount==7 and requests.back().targetId==2130706432 and requests.back().position==[4.0,5.0,0.0],"Actual GUI gold drop sends the original ground destination and amount: "+JSON.stringify({"last":requests.back(),"gold":gold.snapshot()}))
	check(int(fixture.actor.playerState.combat.field898)==27 and frame.labels.gplabel.text=="GP: 27","Gold drag never predicts a local balance change")
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="0"; await click(gold.buttons.okbutton.get_global_rect().get_center())
	check(not event_surface().gui_is_dragging() and requests.size()==request_count+1,"Zero amount returns without sending or starting a drag")
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="5"; await click(gold.buttons.okbutton.get_global_rect().get_center())
	var stale: Dictionary=gold.payload.duplicate(true); owner.generation+=1; await process_frame
	check(not event_surface().gui_is_dragging() and not gold.valid(stale) and requests.size()==request_count+1,"Area generation change cancels the private drag and rejects its stale payload")
	owner.generation-=1
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="6"; await click(gold.buttons.okbutton.get_global_rect().get_center())
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; event_surface().push_input(escape,true); await process_frame
	check(not event_surface().gui_is_dragging() and gold.payload.is_empty() and requests.size()==request_count+1,"Escape cancels the native gold drag without a world click or transfer")
	for data in frame.button_geometry.values():
		var button: Button=data.control; var size: Vector2=button.get_theme_stylebox("normal").texture.get_size()
		check(button.size.distance_to(size)<0.001,"Original "+str(data.resource)+" button displays at its native raster size without stretching")
		for name in data.styles:
			var style: StyleBoxTexture=data.styles[name][0]
			var state: Rect2=frame.rendered_rect(str(data.resource),str(data.styles[name][1]),data.offset)
			check(state.size.distance_to(style.texture.get_size())<0.001 and not style.draw_center,"Original "+str(data.resource)+" "+str(name)+" pose keeps native texture proportions")
	for draw in 3: await process_frame
	var selected: Dictionary=frame.button_geometry[ui.pages[0].get_instance_id()]
	var selected_rect: Rect2=frame.rendered_rect(str(selected.resource),"down",selected.offset)
	check(selected.has("drawn") and selected.drawn.state=="disabled" and selected.drawn.rect.size.distance_to(selected_rect.size)<0.001,"Actual selected-tab draw uses its own down-pose dimensions instead of stretching into the up rectangle")
	owner.notice_text=""; owner.signature=""; owner.refresh(); await process_frame
	additional_evidence.merge({"frame":frame.snapshot(),"scope":"Original inventory/container GUI, real pointer mode/page/drag/drop/close actions and server-shaped authored state. Gold drag/transfer remains unported; real server transfers require the separate local test."})
