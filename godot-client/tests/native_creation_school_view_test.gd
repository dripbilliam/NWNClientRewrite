extends "res://tests/native_portrait_chooser_test.gd"
const SchoolPane=preload("res://systems/native_school_chooser.gd")
func wait_school(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await process_frame
	return false
func school_key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original School resources mount read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_school",2047))=="e8a39577f48a35ab4c71fb04c07e2bff41593d1930a02d0f970dcddf156b43af","Original School hierarchy has the expected immutable digest")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=HeadlessArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var active=preload("res://systems/native_data/talk_text.gd").new();var model:={"ready":true,"entries":[],"recommended":2}
	for id in 9:model.entries.append({"title":9000+id,"description":9100+id});active.overrides[9000+id]="Active school "+str(id);active.overrides[9100+id]="Active school description "+str(id)
	active.overrides[381]="Original introductory school help"
	var pane:=SchoolPane.new();surface.add_child(pane);pane.position=Vector2(30,30);pane.configure(painter,captions,catalog,"");var results: Array=[];pane.finished.connect(func(accepted,id,ticket):results.append([accepted,id,ticket.duplicate()]));pane.set_context(model,true,active,[300,1]);pane.open();pane.start()
	var finished:=await wait_school(func():return pane.layout_ready or not pane.failure.is_empty());check(finished,"Actual School resource workers finish");check(pane.failure.is_empty(),"School layout and every required original helper parse")
	if finished and pane.failure.is_empty():
		await frames()
		check(pane.state.selected==0 and pane.help.current.slice(1)==[381,381] and pane.buttons.general.button_pressed,"Original preparation selects General without firing its click-help callback")
		check(pane.buttons.size()==12 and pane.plan.entries.size()==14,"All9 original school tabs and3 action buttons are retained")
		await click(pane.buttons.necromancy);check(pane.state.selected==7 and pane.help.title.text=="Active school 7" and pane.help.body.get_parsed_text()=="Active school description 7","Physical school input displays active metadata independently from pregame artwork/captions")
		await click(pane.buttons.recommendbutton);check(pane.state.selected==2 and pane.buttons.conjuration.button_pressed,"Actual Recommended selects the supplied active package school")
		pane.set_context(model,false,active,[300,2]);await click(pane.buttons.recommendbutton);check(pane.state.selected==0 and pane.buttons.recommendbutton.disabled,"Active recommended setting disables its real source control")
		pane.set_context(model,true,active,[300,3]);await click(pane.buttons.abjuration);active.overrides[9101]="Changed active help";active.revision+=1;pane.set_context(model,true,active,[300,4],true)
		check(pane.state.selected==1 and pane.help.body.get_parsed_text()=="Changed active help","A text-only reticket preserves the candidate and refreshes help")
		pane.capture("illusion");pane.set_context(model,true,active,[301,1]);pane.invoke("illusion");check(pane.state.selected==0 and results.is_empty(),"Held input cannot select a school in a replacement draft")
		pane.scale=Vector2(.6,.6);pane.position=Vector2(10,10);surface.size=Vector2i(640,480);await frames();await click(pane.buttons.transmutation);await click(pane.buttons.okbutton)
		check(results==[[true,8,[301,1]]] and not pane.wanted,"Scaled source hit regions commit only the selected physicalID and scoped result")
		pane.set_context(model,true,active,[302,1]);pane.open();await school_key(KEY_ESCAPE);check(results[-1]==[false,0,[302,1]] and not pane.wanted,"School Escape cancels its own source lifetime")
		var broken: Dictionary=pane.models.duplicate();broken.erase("ctl_cg_help");check(not str(preload("res://systems/native_data/creation_school_layout.gd").parse(pane.source,broken).error).is_empty(),"Missing source help geometry fails explicitly")
	pane.close();pane.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"sourceArtworkDouble":true,"scope":"Original installed School resources and physical native controls with active help/recommendation/scaling/lifetime fixtures. Headless artwork doubles; no draft/controller/server/pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
