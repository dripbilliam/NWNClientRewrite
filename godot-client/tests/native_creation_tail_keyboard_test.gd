extends "res://tests/native_creation_character_info_view_test.gd"
const ModalOrder=preload("res://systems/native_data/modal_order.gd")
func key(code:int,shift:bool=false,echo:bool=false)->void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.shift_pressed=shift;event.echo=echo if pressed else false;surface.push_input(event,true);await process_frame
	await frames()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual source captions load")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=Fonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var order:=ModalOrder.new();var appearance:=Pane.new();surface.add_child(appearance);appearance.configure(painter,text,catalog,"");appearance.set_modal_owner(order,"other")
	var parts:Array=[];parts.resize(19);parts.fill(1);var skin:Dictionary=Pane.State.tattoo_parts(0,parts)
	var context:Dictionary={"appearanceValid":true,"modelType":"P","customizeMode":0,"enabledPhenotypes":5,"headIndexComplete":true,"heads":{1:true,2:true},"paletteSizes":{"skin":176,"hair":176,"tattoo1":176,"tattoo2":176},"clothing":[{"id":3,"resRef":"first","bodyParts":parts.duplicate(),"colors":[1,2,3,4,5,6]}],"value":{"phenotype":0,"head":1,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"tattooPattern":0,"bodyParts":parts.duplicate(),"skinParts":skin.skinParts,"clothes":3,"clothingIndex":0}}
	var appearance_answers:Array=[];appearance.finished.connect(func(accepted,value,ticket):appearance_answers.append([accepted,value,ticket]))
	appearance.set_context(context,["keys",1]);appearance.open();appearance.start()
	var info:=Information.new();surface.add_child(info);info.configure(painter,text,catalog,"");info.set_modal_owner(order,"other");info.start()
	var end:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<end and (not appearance.layout_ready or not info.layout_ready or not info.deity.layout_ready) and appearance.failure.is_empty() and info.failure.is_empty():await process_frame
	check(appearance.layout_ready and info.layout_ready and info.deity.layout_ready and appearance.failure.is_empty() and info.failure.is_empty() and info.deity.failure.is_empty(),"Actual Appearance/Information/Deity source controls prepare")
	if appearance.layout_ready and info.layout_ready and info.deity.layout_ready:
		await frames(4)
		await key(KEY_ESCAPE,false,true);check(appearance.wanted and appearance_answers.is_empty(),"Echo Escape cannot cancel the current Appearance owner")
		await click(appearance.buttons.skin);check(is_instance_valid(appearance.palette),"Physical source color button opens captured board")
		var old_head:int=appearance.state.value.head;await click(appearance.buttons.head_right)
		check(appearance.state.value.head==old_head and not is_instance_valid(appearance.palette),"Captured color-board release consumes underlying arrow input")
		await click(appearance.buttons.skin);await key(KEY_ESCAPE)
		check(not appearance.wanted and not is_instance_valid(appearance.palette) and appearance_answers.size()==1 and not appearance_answers[0][0] and appearance_answers[0][2]==["keys",1],"Original Appearance Escape cancels its modal and attached board exactly once")
		appearance.set_context(context,["keys",2]);appearance.open();await frames();await click(appearance.buttons.hair);appearance.set_context(context,["keys",3]);appearance.palette_release(Vector2(40,24))
		check(appearance.state.value.hair==0 and not is_instance_valid(appearance.palette),"Replaced Appearance ticket retires captured palette release")
		await key(KEY_ESCAPE);check(appearance_answers.size()==2 and appearance_answers[1][2]==["keys",3] and context.value.head==1,"Keyboard cancellation returns only current private scope")
		var info_context:Dictionary={"value":{"firstName":"Keep","lastName":"Name","ageText":"25","description":"Biography","deity":"Initial","soundset":40},"voices":[{"id":40,"name":"Owned voice","resRef":"owned_voice"}],"randomReady":false}
		var info_answers:Array=[];var voices:Array=[];info.finished.connect(func(accepted,value,ticket):info_answers.append([accepted,value,ticket]));info.voice_requested.connect(func(id,resref,sample,ticket):voices.append([id,resref,sample,ticket]))
		info.set_context(info_context,["keys",4]);info.open();await frames()
		check(info.available() and info.edits.firstnameedit.has_focus() and voices==[[40,"owned_voice",0,["keys",4]]],"Current Information owner focuses first name and preserves exact voice request metadata")
		for control in [info.edits.ageedit,info.edits.lastnameedit,info.biography,info.edits.firstnameedit]:
			await key(KEY_TAB);check(control.has_focus(),"Native Information Tab sequence reaches "+str(control==info.biography))
		await key(KEY_TAB,true);check(info.biography.has_focus(),"Shift-Tab reverses native Information edit order")
		info.capture("cancelbutton");await click(info.buttons.deitybutton);await frames()
		check(info.deity.wanted and info.deity.available() and not info.available() and info.deity.get_index()>info.biography_bar.get_index(),"Nested Deity is the current logical/input and foreground child")
		var before_first:String=info.state.fields.firstName;await click(info.edits.firstnameedit);await key(KEY_TAB)
		check(info.state.fields.firstName==before_first and info.deity.wanted and info_answers.is_empty(),"Top Deity child masks lower Information input")
		await type_text(info.deity.edit,"Accepted",true);await key(KEY_ENTER)
		check(not info.deity.wanted and info.available() and info.state.fields.deity=="Accepted" and info_answers.is_empty(),"Deity Enter commits its current child without submitting the parent")
		info.invoke("cancelbutton");check(info.wanted and info_answers.is_empty(),"Opening the modal child retires a previously held parent callback")
		await click(info.buttons.deitybutton);await type_text(info.deity.edit,"Discard",true);await key(KEY_ESCAPE)
		check(info.wanted and not info.deity.wanted and info.state.fields.deity=="Accepted" and info_answers.is_empty(),"Deity Escape cancels only the top child and preserves the parent transaction")
		await click(info.edits.firstnameedit);await key(KEY_ENTER)
		check(info.wanted and info.edits.firstnameedit.has_focus() and info_answers.is_empty(),"Single-line Enter preserves editing without inventing a screen submission")
		await click(info.biography);await key(KEY_ESCAPE)
		check(not info.wanted and info_answers.size()==1 and not info_answers[0][0] and info_answers[0][2]==["keys",4],"Information Escape from focused multiline edit cancels exactly its current owner")
		check(info_context.value.deity=="Initial" and info_context.value.firstName=="Keep","Keyboard/modal work leaves supplied draft fields immutable")
		info.set_context(info_context,["keys",5]);info.open();await frames();await click(info.buttons.deitybutton);var stale:Array=info.deity_ticket.duplicate();info.set_context(info_context,["keys",6]);info.deity_result(true,"Late",stale)
		check(info.state.fields.deity=="Initial" and not info.deity.wanted,"Retired child result cannot modify replacement Information scope")
		await key(KEY_ESCAPE)
	appearance.close();appearance.free();info.close();info.free();order.close();painter.free();surface.queue_free();text.close();await frames(4)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"sourceArtworkDouble":true,"serverConnections":0,"scope":"Actual installed tail controls with physical key/mouse events and real modal leases. Artwork/fonts doubled; no audible output, generated swatch/preview pixel or live BIC acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
