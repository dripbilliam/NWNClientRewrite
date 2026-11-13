extends SceneTree
const Classes=preload("res://systems/native_data/creation_class_state.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Pane=preload("res://systems/native_class_chooser.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Doubles=preload("res://tests/native_portrait_chooser_test.gd")
var checks:=0
var failures:Array=[]
var surface:SubViewport
class ActiveText extends RefCounted:
	const NAMES=["Sentinel","Bard","Zebra","Hidden","Fighter","Arcanist","Gloom","Acolyte","Sorcerer"]
	func raw(value:Dictionary)->String:
		var id:=int(value.get("strRef",-1))-10000
		return NAMES[id] if id>=0 and id<NAMES.size() else "Server detail "+str(value.get("strRef",-1))
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);print("FAIL: ",message)
func frames(count:int=3)->void:
	for index in count:await process_frame
func click(button:Button)->void:
	var point:=button.get_global_transform_with_canvas()*(button.size*.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;surface.push_input(event,true);await process_frame
	await frames()
func ids(values:Dictionary)->Array:return values.entries.map(func(entry):return int(entry.id))
func run()->void:
	var args:Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var rules:=Rules.new();var rows:Array=[]
	for id in 9:rows.append({"Name":str(10000+id),"Description":str(20000+id),"PlayerClass":"0" if id==3 else "1","Icon":"","PreReqTable":"blocked" if id in [1,5,7] else ""})
	rules.tables={"classes":{"orderedRows":rows},"blocked":{"orderedRows":[{"ReqType":"RACE","ReqParam1":"99"}]}}
	rules.draft={"classId":4,"raceId":6,"skills":{},"feats":[]}
	var text:=ActiveText.new();var values:=Classes.choices(rules,text)
	check(ids(values)==[4,6,0,8,2,7,5,1],"Default live class publication groups selectable rows first and sorts names within each group")
	check(ids(Classes.choices(rules,text,false))==[0,1,2,4,5,6,7,8],"Explicit physical-order source observation remains available")
	check(rows[3].PlayerClass=="0" and values.entries.size()==8,"Grouping never admits hidden/non-player server classes or mutates physical rows")
	check(int(values.recommended.id)==4,"Recommendation retains physical class4 independently of display position")
	var model:=Classes.new();model.reset(values);check(model.selected_class()==4 and model.can_accept(),"Initial selected row is available and resolves to its physical class ID")
	model.select_index(6);check(model.selected_class()==5 and not model.can_accept() and model.help_description==20005,"Unavailable row retains correct server help while acceptance is disabled")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original class artwork catalog mounts read-only")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var source_text:=preload("res://systems/native_data/talk_text.gd").new();check(source_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original frame captions load independently of custom class text")
	var pane:=Pane.new();surface.add_child(pane);pane.configure(painter,source_text,catalog,"");pane.set_context(values,true,text,null,["creation",11]);pane.start();pane.open()
	var deadline:=Time.get_ticks_msec()+20000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Actual source Class pane prepares: "+pane.failure)
	if pane.layout_ready:
		await frames(5);check(pane.row_buttons.size()==8 and pane.state.selected_class()==4,"Actual chooser consumes the default grouped publication")
		var result:Array=[];pane.finished.connect(func(accepted,id,ticket):result.append([accepted,id,ticket]))
		await click(pane.row_buttons[4]);check(pane.state.selected_class()==2 and pane.help_refs==[10002,20002],"Physical pointer chooses display row4 but resolves class2 and its server details")
		await click(pane.buttons.okbutton);check(result==[[true,2,["creation",11]]],"Actual OK returns physical class2, never the display index4")
		pane.set_context(values,true,text,null,["creation",12]);pane.open();pane.list.scroll_vertical=6*44;await frames(5);await click(pane.row_buttons[6])
		check(pane.state.selected_class()==5 and pane.buttons.okbutton.disabled and not pane.row_buttons[6].disabled,"Unavailable classes remain inspectable after grouping with OK disabled")
		await click(pane.buttons.okbutton);check(result.size()==1 and pane.wanted,"Clicking disabled OK cannot emit an unavailable class")
		pane.capture("okbutton");rules.tables.blocked.orderedRows[0].ReqParam1="6";values=Classes.choices(rules,text);pane.set_context(values,true,text,null,["creation",13]);pane.invoke("okbutton")
		check(result.size()==1 and ids(values)==[7,5,1,4,6,0,8,2],"A server prerequisite publication regroups rows and retires a held input before committing")
		pane.list.scroll_vertical=0;await frames(5);await click(pane.buttons.recommendbutton);check(pane.state.selected_class()==4 and pane.state.selected==3,"Recommended resolves physical ID after eligibility changes its visible position")
		pane.scale=Vector2(.75,.75);await click(pane.buttons.okbutton);check(result.size()==2 and result[1]==[true,4,["creation",13]],"Scaled native input commits the recommended physical class with the current scope")
	pane.close();pane.free();painter.close();painter.free();source_text.close();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Default available-first active-class publication and actual source chooser input, server prerequisite changes, help/disabled acceptance, recommendation, ID preservation, stale held input and scaling. Artwork is doubled; no pixels, server or live-client claim."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
