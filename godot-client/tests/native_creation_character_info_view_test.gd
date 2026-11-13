extends "res://tests/native_creation_appearance_view_test.gd"
func type_text(control:Control,value:String,replace:bool=false)->void:
	await click(control)
	if replace:
		for pressed in [true,false]:
			var select:=InputEventKey.new();select.keycode=KEY_A;select.physical_keycode=KEY_A;select.ctrl_pressed=true;select.pressed=pressed;surface.push_input(select,true);await process_frame
	for index in value.length():
		for pressed in [true,false]:
			var event:=InputEventKey.new();event.pressed=pressed;event.keycode=value.unicode_at(index);event.physical_keycode=event.keycode;event.unicode=value.unicode_at(index);surface.push_input(event,true);await process_frame
	await frames()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original Character Information captions are available")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=Fonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Information.new();surface.add_child(pane);pane.configure(painter,text,catalog,"")
	var context:={"value":{"firstName":"","lastName":"","ageText":"-7","description":"","deity":"Existing deity","soundset":40},"voices":[{"id":40,"name":"Active custom voice A","resRef":"active_a"},{"id":120,"name":"Active custom voice B","resRef":"active_b"}],"randomReady":true}
	var results:Array=[];var voices:Array=[];var randoms:Array=[]
	pane.finished.connect(func(accepted,value,ticket):results.append([accepted,value,ticket]))
	pane.voice_requested.connect(func(id,resref,sample,ticket):voices.append([id,resref,sample,ticket]))
	pane.random_requested.connect(func(id,ticket):randoms.append([id,ticket]))
	pane.set_context(context,["draft",1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while (not pane.layout_ready or not pane.deity.layout_ready) and pane.failure.is_empty() and pane.deity.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.deity.layout_ready and pane.failure.is_empty() and pane.deity.failure.is_empty(),"Installed Character Information and original Deity edit prepare: "+pane.failure+pane.deity.failure)
	if pane.layout_ready and pane.deity.layout_ready:
		await frames(5)
		check(randoms.size()==1 and pane.pending_random==randoms[0][0],"Opening an empty first+last name scope requests exactly one original automatic Random operation")
		pane.generation_failed(int(randoms[0][0]),randoms[0][1]);randoms.clear()
		check(pane.size.distance_to(Vector2(742,526))<.01 and pane.plan.entries.firstnameedit.rect.size.distance_to(Vector2(225,25))<.01 and pane.plan.entries.firstnameedit.text_rect.size.distance_to(Vector2(212,19))<.01,"Original frame, edit artwork and separate native text hooks retain source dimensions")
		check(pane.rows.size()<16 and pane.state.voices.size()==2 and pane.rows[0].label.text=="Active custom voice A","Voice rows use a bounded pool and active-owner names/physical IDs")
		check(voices==[[40,"active_a",0,["draft",1]]],"Original initial soundset selection requests sample0 exactly once")
		await click(pane.rows[0].button);await click(pane.rows[1].button);check(voices.size()==3 and voices[1][2]==1 and voices[2]==[120,"active_b",0,["draft",1]],"Repeated real voice click cycles samples; changed voice starts at0 with actual physical ID")
		await type_text(pane.edits.firstnameedit,"First");await type_text(pane.edits.lastnameedit,"Last");await type_text(pane.biography,"Biography")
		check(pane.state.fields.firstName=="First" and pane.state.fields.lastName=="Last" and pane.state.fields.description=="Biography" and context.value.firstName.is_empty(),"Actual source text controls edit a detached transaction")
		await click(pane.edits.firstnameedit);var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.physical_keycode=KEY_TAB;tab.pressed=true;surface.push_input(tab,true);await frames();check(pane.edits.ageedit.has_focus(),"Original first-name→age Tab order is retained")
		await click(pane.buttons.deitybutton);await frames();check(pane.deity.wanted and pane.deity.edit.text=="Existing deity" and pane.deity.title_ref==8156,"Physical Deity button opens original GenericEdit with current field and native title")
		await type_text(pane.deity.edit,"New deity",true);await click(pane.deity.buttons.okbutton);check(pane.state.fields.deity=="New deity" and not pane.deity.wanted,"Physical nested Deity OK applies only its current child ticket")
		await click(pane.buttons.randombutton);check(randoms.size()==1 and pane.buttons.randombutton.disabled,"Physical Random requests one bounded scoped native generation job")
		check(pane.generated_names(int(randoms[0][0]),"Generated","Surname",randoms[0][1]) and pane.edits.firstnameedit.text=="Generated" and pane.edits.lastnameedit.text=="Surname","Current owner can publish asynchronous generated names into original edits")
		await click(pane.buttons.okbutton);check(results.size()==1 and results[0][0] and results[0][1].firstName=="Generated" and results[0][1].soundset==120 and results[0][1].age== -7 and results[0][2]==["draft",1],"Physical OK returns current fields, signed native atoi and exact soundset selection")
		check(context.value.description.is_empty() and context.value.soundset==40,"No accepted or previewed edit mutates the supplied owner dictionary")
		pane.set_context(context,["draft",2]);pane.open();await frames();await click(pane.buttons.randombutton);var pending:Array=randoms[-1];await click(pane.buttons.cancelbutton)
		check(results.size()==2 and not results[1][0] and not pane.generated_names(int(pending[0]),"Late","Work",pending[1]),"Cancel retires pending generation and leaves owner fields unchanged")
		pane.set_context(context,["draft",3]);pane.open();await frames();pane.capture_row(0);pane.set_context(context,["draft",4]);var count:=voices.size();pane.invoke_row(0);check(voices.size()==count,"Held pooled voice input cannot select in a replacement draft")
		context.voices=[];context.randomReady=false;pane.set_context(context,["draft",5]);check(pane.state.voices.is_empty() and pane.buttons.randombutton.disabled and not pane.buttons.okbutton.disabled,"No available voices/name generator is explicit without fabricating a selection or blocking valid typed fields")
		context.value.erase("deity");pane.set_context(context,["draft",6]);check(not pane.state.ready and pane.buttons.okbutton.disabled,"Missing Character Information field remains unavailable")
		context.value.deity="";pane.set_context(context,["draft",7]);pane.open();await frames();await type_text(pane.edits.firstnameedit,"Typed")
		var before:=randoms.size();check(pane.set_random_ready(true,["draft",7]) and randoms.size()==before and pane.edits.firstnameedit.text=="Typed" and pane.state.fields.firstName=="Typed","Late resource readiness preserves typed names without resetting fields or starting automatic generation")
		check(not pane.set_random_ready(false,["draft",6]) and not pane.buttons.randombutton.disabled,"Stale resource completion cannot change the current name-generation availability")
		await click(pane.buttons.randombutton);var pending_edit:Array=randoms[-1];await type_text(pane.edits.firstnameedit,"Later",true)
		check(not pane.generated_names(int(pending_edit[0]),"Old","Reply",pending_edit[1]) and pane.edits.firstnameedit.text=="Later","Async generation cannot overwrite names edited after its request")
		pane.set_context(context,["draft",8]);var initial_count:=randoms.size();check(pane.set_random_ready(true,["draft",8]) and randoms.size()==initial_count+1,"Late preparation starts original automatic names only while both fields remain empty")
		check(pane.set_random_ready(true,["draft",8]) and randoms.size()==initial_count+1,"Repeated readiness publication does not duplicate automatic generation")
		var automatic:Array=randoms[-1];check(pane.generated_names(int(automatic[0]),"Native","Names",automatic[1]) and pane.edits.firstnameedit.has_focus(),"Successful asynchronous pair returns focus to the original first-name edit")
	var state:=Information.State.new();state.reset({"value":{"firstName":"<cabc>First</c>","lastName":" Last ","ageText":"  -2147483649tail","description":"<C>kept</C><cxyz>clear</c>","deity":"","soundset":40},"voices":[]})
	var result:=state.result();check(result.available and result.value.firstName=="First" and result.value.lastName==" Last " and result.value.age== -2147483648 and result.value.description=="<C>kept</C>clear","Native ASCII truncation/filter/atoi source semantics preserve whitespace and unrelated tags")
	check(Information.State.byte_prefix("x".repeat(251),250).length()==250 and Information.State.byte_prefix("x".repeat(8193),8192).length()==8192,"Native first/last250 and biography8192 encoded-byte bounds are enforced")
	pane.close();pane.free();painter.free();surface.queue_free();await frames(4)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"sourceArtworkDouble":true,"scope":"Actual installed Character Information and Deity source controls, typed fields, pooled voice input, original automatic names and scoped async readiness/result handoff preserving newer typed edits. Active voice/name choices are authored owner fixtures; audio, generated swatch/3D pixels and live creator commit/BIC/server are not accepted."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
