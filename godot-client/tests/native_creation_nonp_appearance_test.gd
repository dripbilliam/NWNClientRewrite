extends "res://tests/native_creation_appearance_view_test.gd"
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed source catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original source captions load")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=Fonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Pane.new();surface.add_child(pane);pane.configure(painter,text,catalog,"")
	var results:Array=[];var previews:Array=[];pane.finished.connect(func(accepted,value,ticket):results.append([accepted,value,ticket]));pane.preview_changed.connect(func(value,ticket):previews.append([value,ticket]))
	var context:Dictionary={"appearanceValid":true,"modelType":"F","customizeMode":0,"headIndexComplete":false,"heads":{},"paletteSizes":{},"clothing":[],"value":{"phenotype":2,"head":300,"skin":17,"hair":19,"tattoo1":21,"tattoo2":23,"skinParts":range(19),"bodyParts":range(400,419),"materialColors":[1,2,3,4,5,6],"clothes":313,"clothingResRef":"physical_outfit"}}
	pane.set_context(context,["draft",1]);pane.open();pane.start()
	var end:=Time.get_ticks_msec()+20000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<end:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Original CG_APPEARANCE prepares for a non-P source choice")
	if pane.layout_ready:
		for model in ["F","C"]:
			context.modelType=model;var scope:Array=["draft",model];pane.set_context(context,scope);pane.open();await frames()
			check(pane.plan.controls.keys().all(func(tag):return pane.buttons[tag].disabled) and not pane.buttons.okbutton.disabled and not pane.buttons.cancelbutton.disabled,"Non-P "+model+" needs no head/palette choices while retaining original OK/Cancel")
			var before:=previews.size();await click(pane.buttons.head_right);await click(pane.buttons.skin)
			check(previews.size()==before and not is_instance_valid(pane.palette) and pane.state.value.head==300,"Disabled non-P controls cannot invent a head/color or publish an edit")
			await click(pane.buttons.okbutton);check(results[-1][0] and results[-1][1]==context.value and results[-1][2]==scope,"Physical non-P "+model+" OK returns only known private fields unchanged")
		pane.set_context(context,["draft",9]);pane.open();await frames();await click(pane.buttons.cancelbutton);check(not results[-1][0] and results[-1][2]==["draft",9],"Non-P Cancel retains exact current scope")
	pane.close();pane.free();painter.free();surface.queue_free();await frames(4)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"benchmark":false,"scope":"Actual installed CG_APPEARANCE source/input with detached non-P F/C contexts, absent unused choice metadata, disabled action suppression and physical OK/Cancel. No actual model rendering/creator/BIC/server acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
