extends "res://tests/native_creation_spells_binding_test.gd"
func submissions() -> int:
	return sent.filter(func(message):return message.kind=="native-creation-submit").size()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var active:=Catalog.new()
	check(base.mount_install(args.install) and active.mount_install(args.install),"Unchanged installed catalogs mount for the actual submission owner")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(1701)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready,20),"Actual default creation entry and resource jobs prepare",creator.resource_errors):
		var identity: Array=creator.summary_identity();var retained: Dictionary=creator.rules.draft.duplicate(true)
		# A forged direct Main intent must still be rejected by the real worker,
		# even though the normal physical Play control correctly remains disabled.
		creator.source_command("finish",identity)
		check(creator.phase=="preparing" and submissions()==0,"Input enters progress immediately without synchronously evaluating the invalid draft")
		var task: int=creator.build_task;creator.source_command("finish",identity)
		check(creator.build_task==task and creator.phase=="preparing","Repeated submit is fenced while preparation owns the draft")
		check(await wait_for(func():return creator.phase=="editing" and creator.build_task<0,10),"Mandatory real BIC worker returns its validation failure")
		check(creator.status.contains("Enter a first name.") and submissions()==0 and creator.rules.draft==retained and creator.source_frontend.wanted,"Worker failure is visible in the source pane, preserves choices and cannot upload")
		check(int(creator.build_timings.get("workerUsec",0))>0 and int(creator.build_timings.get("captureUsec",-1))>=0,"Detached worker and main snapshot durations describe the actual completed task")
		creator.source_command("finish",identity)
		check(creator.phase=="preparing","A corrected/retried intent can start preparation again")
		# This is the same guarded handler wired to Main's preparing Cancel.
		creator.source_finished(true,identity)
		check(creator.phase=="closed" and not creator.source_frontend.wanted and creator.summary_identity()!=identity,"Cancel retires the current in-flight request and its source scope synchronously")
		check(await wait_for(func():return creator.build_task<0,10) and submissions()==0,"Late cancelled worker completion cannot upload or reopen the draft")
		creator.open(1701)
		check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.wanted,10),"A fresh creation scope can reopen after worker cancellation")
		var current: Array=creator.summary_identity();var status_before: String=creator.status
		creator.source_command("finish",identity)
		creator.result({"kind":"native-creation-result","connection":identity[0],"draft":identity[1],"operation":"native-creation-submit","accepted":false,"text":"stale failure"})
		check(creator.summary_identity()==current and creator.phase=="editing" and creator.status==status_before and creator.build_task<0 and submissions()==0,"Stale Main intent and upload reply cannot alter the replacement draft")
	var timings: Dictionary=creator.build_timings.duplicate(true)
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timings":timings,"scope":"Actual Creator/Frontend and detached Builder validation with installed rules; invalid/repeated submit, visible worker failure, preparing Cancel, late completion and replacement-scope fences. Controlled artwork; physical preparing Cancel is separately covered by phase27. No network or server claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
