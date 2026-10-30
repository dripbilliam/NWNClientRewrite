extends "res://tests/native_inventory_frame_ui_test.gd"
func key(code: int,character: int=0) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.unicode=character; event.pressed=down; event_surface().push_input(event,true); await process_frame
func additional_checks(owner,output: String,fixture: Dictionary) -> void:
	await super.additional_checks(owner,output,fixture)
	var gold=owner.gold; var frame=owner.frame_skin; var count:=requests.size()
	await click(frame.gold_button.get_global_rect().get_center())
	check(gold.modal.visible and gold.number.has_focus() and gold.number.max_length==0,"Original amount edit receives focus without an invented ten-character limit")
	check(not gold.title_label.clip_text and gold.title_label.size.x>=gold.title_label.get_minimum_size().x and absf(gold.title_label.position.x+gold.title_label.size.x*0.5-gold.entries.title.rect.position.x)<0.01,"Gold title uses the original unbounded centered caption anchor without clipping")
	gold.number.text=""; gold.number.caret_column=0
	await key(KEY_A,97); check(gold.number.text.is_empty(),"Actual native amount edit rejects alphabetic characters at the original number gate")
	await key(KEY_MINUS,45); await key(KEY_2,50)
	check(gold.number.text=="-2","Actual native numeric gate preserves the original signed punctuation path")
	await click(gold.buttons.upbutton.get_global_rect().get_center()); check(gold.number.text=="-1","Original Up applies only its upper bound rather than inventing a lower clamp")
	gold.number.text="100"; await click(gold.buttons.downbutton.get_global_rect().get_center()); check(gold.number.text=="99","Original Down applies its lower bound without clamping to the opening balance")
	gold.number.text="1e9"; await key(KEY_ENTER,13)
	check(not gold.modal.visible and event_surface().gui_is_dragging() and gold.payload.get("amount")==1 and requests.size()==count,"Actual Enter uses the original decimal prefix and starts only a private gold drag")
	await key(KEY_ESCAPE); check(not event_surface().gui_is_dragging() and gold.payload.is_empty(),"Escape cancels that typed drag without a server request")
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="9".repeat(80); await click(gold.buttons.okbutton.get_global_rect().get_center())
	check(gold.payload.get("amount")==27 and requests.size()==count,"Very long positive text saturates at the original signed limit before the balance cap")
	await key(KEY_ESCAPE)
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="-1"; await key(KEY_ENTER,13)
	check(not gold.modal.visible and not event_surface().gui_is_dragging() and requests.size()==count,"Nonpositive typed confirmation dismisses without a transfer")
	await click(frame.gold_button.get_global_rect().get_center()); gold.number.text="0"; gold.set_process(false)
	var point: Vector2=gold.buttons.upbutton.get_global_rect().get_center(); await motion(point,Vector2.ZERO,false); await mouse(point,true)
	check(gold.number.text=="1" and gold.repeat_step==1,"Actual original arrow press performs one immediate step")
	gold._process(0.5); check(gold.number.text=="1","Held arrow does not repeat at the exact500ms boundary")
	gold._process(0.000001); check(gold.number.text=="2","Held arrow repeats after crossing the original500ms delay")
	gold._process(0.05); check(gold.number.text=="2","Held arrow does not repeat at the exact50ms period")
	gold._process(0.000001); check(gold.number.text=="3","Held arrow repeats after crossing the original50ms period")
	gold._process(2.0); check(gold.number.text=="4","A late frame performs one original repeat without a burst of catch-up steps")
	await motion(point+Vector2(250,0),Vector2(250,0)); gold._process(1.0)
	check(gold.number.text=="4","Moving the captured pointer outside its arrow suspends repeat while preserving elapsed time")
	await motion(point,Vector2(-250,0)); gold._process(0.000001)
	check(gold.number.text=="5","Reentering the held arrow resumes the original accumulated timer")
	await mouse(point,false); gold._process(1.0); check(gold.number.text=="5" and gold.repeat_step==0,"Actual release stops repeats")
	gold.set_process(true); await click(gold.buttons.cancelbutton.get_global_rect().get_center())
	check(not gold.number.has_focus() and not gold.modal.visible and gold.repeat_button==null and requests.size()==count,"Cancel releases amount focus and repeat state without a request")
	check(await wait_for(func():return owner.stack_dialog.layout_ready),"The same original amount policy is ready for item splitting")
	fixture.packed.item.stackSize=27; owner.signature=""; owner.refresh(); await process_frame
	owner.stack_dialog.open_item({"viewId":owner.view_serial,"entryId":13}); owner.stack_dialog.number.text="1e9"; await key(KEY_ENTER,13)
	check(requests.size()==count+1 and requests[-1].kind=="item-action" and requests[-1].operation=="split" and requests[-1].amount==1 and fixture.packed.item.stackSize==27,"Actual split Enter uses the same decimal policy and awaits the server's item/count outcome")
	owner.pending.clear(); owner.signature=""; owner.refresh(); await process_frame
	owner.stack_dialog.open_item({"viewId":owner.view_serial,"entryId":13}); owner.stack_dialog.number.text="12.5"
	check(not owner.stack_dialog.title_label.clip_text and owner.stack_dialog.title_label.text==owner.text_owner.raw({"strRef":67496}) and owner.stack_dialog.title_label.size.x>owner.stack_dialog.entries.title.rect.size.x,"Long original stack title is retained beyond its unused source width")
	await RenderingServer.frame_post_draw
	check(event_surface().get_texture().get_image().save_png(output.trim_suffix(".json")+"-stack-amount.png")==OK,"Actual original split dialog viewport is retained")
	await key(KEY_ESCAPE); check(not owner.stack_dialog.modal.visible and not owner.stack_dialog.number.has_focus(),"Escape dismisses the original split edit and releases its focus")
