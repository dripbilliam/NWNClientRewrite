extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Builder=preload("res://systems/native_data/creation_bic.gd")
var checks:=0
var failures: Array=[]
var sent: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String,details: Variant=null) -> bool:
	checks+=1
	if not value: failures.append({"label":label,"details":details})
	return value
func wait_for(predicate: Callable,seconds: float=30.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func pick(creator,operation: String,value: Variant) -> bool:
	for id in creator.controls:
		var control: Dictionary=creator.controls[id]
		if str(control.operation)==operation and control.value==value:
			creator.view.change(int(id),null,creator.serial); return true
	return false
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1600,1000)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original install mounts read-only")
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator; creator.open(1)
	if not check(await wait_for(func():return creator.phase=="editing",90),"Native server-catalog creator becomes ready",creator.resource_errors): ui.close(); ui.free(); quit(1); return
	check(creator.view.wanted and sent[0].kind=="native-creation-begin","New Character opens native controls with a connection scope")
	for class_id in range(11):
		creator.view.navigate(3); check(pick(creator,"class",class_id),"Native class button "+str(class_id)+" is selectable")
		creator.view.choose_recommended()
		check(await wait_for(func():return creator.phase=="editing"),"Active package recommendations complete for class "+str(class_id))
		creator.rules.draft.firstName="Native"; creator.rules.draft.lastName="Class"+str(class_id)
		var errors: Array=creator.rules.errors(); check(errors.is_empty(),"Original class "+str(class_id)+" recommendations produce a valid draft",errors)
		if not errors.is_empty(): continue
		var builder:=Builder.new(); var bytes:=builder.build(creator.rules); var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC ")
		check(builder.failure.is_empty() and parser.failure.is_empty(),"Native class "+str(class_id)+" character file builds",builder.failure)
		if document.is_empty(): continue
		check(document.root.ClassList[0].Class==class_id and document.root.ClassList[0].ClassLevel==1,"Native file retains selected class and first level")
		check(int(document.field_types[1].get("Class",-1))==5 or document.field_types.values().any(func(types):return int(types.get("Class",-1))==5),"Character class uses original signed INT field")
		check(document.root.Equip_ItemList.size()==1 and not document.root.Equip_ItemList[0].has("ObjectId"),"Starting clothes come from an active UTI without fabricated object IDs")
	for page in 15:
		creator.view.navigate(page); await process_frame; check(int(creator.view.state.step)==page and creator.view.controls.size()<=10000,"Native creator page "+str(page)+" renders")
	creator.view.navigate(11)
	check(await wait_for(func():return creator.preview.diagnostics.has("ready"),60),"Native appearance preview finishes loading")
	check(bool(creator.preview.diagnostics.get("ready",false)) and int(creator.preview.diagnostics.get("meshes",0))>0,"Actual original models, palette textures and animations render in the creator",creator.preview.diagnostics)
	var preview_report: Dictionary=creator.preview.diagnostics.duplicate(true); preview_report.erase("draft")
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(str(args.report)+".appearance.png")
	for id in creator.controls:
		if creator.controls[id].type=="select":
			var unchanged: Dictionary=creator.rules.draft.duplicate(true); creator.view.change(int(id),-1,creator.serial)
			check(creator.rules.draft==unchanged,"Out-of-range selection cannot index a private native choice list"); break
	creator.view.navigate(12)
	for attempt in 49:
		creator.view.voice_sample_button.pressed.emit()
		if not await wait_for(func():return creator.voice.request_id<0,10): break
		if creator.voice.last.get("played",false): break
	check(creator.voice.last.get("played",false) and creator.view.voice_audio.player.stream!=null,"Selected original SSF voice sample resolves, decodes and plays entirely in Godot",creator.voice.last)
	var voice_report: Dictionary=creator.voice.last.duplicate(true)
	creator.view.navigate(3); pick(creator,"class",4); creator.view.choose_recommended(); await wait_for(func():return creator.phase=="editing")
	creator.rules.draft.firstName="Native"; creator.view.navigate(13)
	var old_view: int=creator.serial; creator.view.navigate(14); var before: Dictionary=creator.rules.draft.duplicate(true)
	creator.input({"operation":"control","viewId":old_view,"controlId":0,"value":"stale"})
	check(creator.rules.draft==before,"Retired creator controls cannot edit a new page")
	creator.view.finish.pressed.emit(); check(creator.phase=="preparing","Validated Play enters native worker preparation")
	creator.view.cancel.pressed.emit(); check(creator.phase=="closed","Preparation can be cancelled before a character is uploaded")
	creator.open(1); await wait_for(func():return creator.phase=="editing" and creator.build_task<0)
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Cancelled BIC work cannot submit into a reopened creator")
	creator.rules.draft.firstName="Native"; creator.view.navigate(3); pick(creator,"class",4); creator.view.choose_recommended(); await wait_for(func():return creator.phase=="editing"); creator.view.navigate(14)
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(str(args.report)+".png")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"preview":preview_report,"voice":voice_report,"resource_errors":creator.resource_errors,"publicConnections":0,"scope":"Native original-data creation controls, rules and BICs; server admission checked separately"}
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
