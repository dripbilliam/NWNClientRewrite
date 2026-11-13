extends "res://tests/native_creation_character_info_view_test.gd"
const Generic=preload("res://systems/native_generic_edit.gd")
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
func press_key(code:int)->void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await process_frame
	await frames()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed catalog opens read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual generic and Subrace prompt captions load")
	surface=SubViewport.new();surface.size=Vector2i(1100,700);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Generic.new();surface.add_child(pane);pane.configure(painter,text,catalog,"");pane.set_context("existing subrace text beyond20",8185,20,["subrace",1]);pane.open();pane.start()
	var end:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<end and (not pane.layout_ready or not fonts.pending.is_empty()) and pane.failure.is_empty():await process_frame
	check(pane.layout_ready and pane.failure.is_empty() and fonts.pending.is_empty() and fonts.failed.is_empty(),"Original UTIL_EDITPOPUP/actual fonts prepare without errors")
	var answers:Array=[]
	if pane.layout_ready:
		pane.finished.connect(func(accepted,value,ticket):
			answers.append([accepted,value,ticket])
			if accepted and ticket==["name",1]:pane.set_context("",8156,20,["name",2]);pane.open())
		await frames(5)
		check(pane.edit.text=="existing subrace text beyond20" and pane.edit.max_length==0,"Subrace initial SetEditText preserves an existing value beyond the typing limit")
		check(Rect2(Vector2.ZERO,pane.size).encloses(pane.message.get_rect()) and not pane.plan.entries.messagelabel.has("floating"),"Subrace prompt preserves its claimed source bounds with real fonts")
		await press_key(KEY_END);await type_text(pane.edit,"x")
		check(pane.edit.text=="existing subrace text beyond20","Original over-limit typed character is blocked")
		# End is not in this owner's original over-limit navigation whitelist.
		# Move using the admitted Right key before exercising physical deletion.
		for index in pane.edit.text.length():await press_key(KEY_RIGHT)
		await press_key(KEY_BACKSPACE);check(pane.edit.text=="existing subrace text beyond2","Backspace remains available above the source character limit")
		await press_key(KEY_ESCAPE);check(answers.size()==1 and not answers[0][0] and answers[0][2]==["subrace",1] and not pane.wanted,"Physical Subrace Escape cancels only the exact generic edit scope")
		pane.set_context("",8156,20,["name",1]);pane.open();await frames();await type_text(pane.edit,"First");await press_key(KEY_ENTER)
		check(answers.size()==2 and answers[1]==[true,"First",["name",1]] and pane.wanted and pane.scope==["name",2],"First Enter returns original data and can synchronously reopen the same edit owner")
		await type_text(pane.edit,"Second");await press_key(KEY_ENTER)
		check(answers.size()==3 and answers[2]==[true,"Second",["name",2]] and not pane.wanted,"Second physical Enter retains the reentrant editing session")
		pane.set_context("saved",8185,20,["subrace",2]);pane.open();await frames();await click(pane.buttons.okbutton)
		check(answers[-1]==[true,"saved",["subrace",2]],"Physical generic OK retains Subrace text and current ticket")
		pane.set_context("current",8185,20,["subrace",3]);pane.open();await frames();pane.capture("okbutton");pane.set_context("replacement",8185,20,["subrace",4]);pane.open();pane.invoke("okbutton")
		check(answers.size()==4 and pane.wanted and pane.edit.text=="replacement","Held old generic OK cannot submit a replaced scope")
		await click(pane.buttons.cancelbutton);check(answers.size()==5 and answers[-1]==[false,"replacement",["subrace",4]],"Physical Cancel reports only replacement scope without accepting text")
	pane.close();pane.free();painter.close();painter.free();surface.queue_free();text.close();await frames(4)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"realInstalledFonts":true,"artworkDouble":true,"scope":"Actual source GenericEdit with Subrace's8185/20 contract, original message bounds, over-limit/backspace, physical Enter/Escape/OK/Cancel and two-stage synchronous reopening; no unrelated profile UI, full creator or network acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
