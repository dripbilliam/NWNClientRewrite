extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Doubles=preload("res://tests/native_portrait_chooser_test.gd")
const FeatPopup=preload("res://systems/native_feat_popup.gd")
class Art extends Doubles.HeadlessArt:
	func close() -> void:bindings.clear()
const COLORS=["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]
var checks:=0
var failures: Array=[]
var surface: SubViewport
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func frames(count: int=3) -> void:
	for index in count:await process_frame
func mouse(button: Button,pressed: bool) -> void:
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await process_frame
func click(button: Button) -> void:await mouse(button,true);await mouse(button,false);await frames()
func collect(node: Dictionary,resources: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty():resources[name]=true
	for child in node.get("Obj_ChildList",[]):collect(child,resources)
func selection_visible(pane,selected_color: Color,normal: Color) -> bool:
	for index in pane.row_buttons.size():
		var button: Button=pane.row_buttons[index]
		if button.button_pressed!=(index==pane.selected):return false
		for state in COLORS:
			if not button.get_theme_color(state).is_equal_approx(selected_color if index==pane.selected else normal):return false
	return true
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or oracle.get("binarySha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":quit(2);return
	var rgba: Array=oracle.colors["1"];var highlight:=Color(float(rgba[0]),float(rgba[1]),float(rgba[2]),float(rgba[3]));check(highlight==Color(1,1,0,1),"Unchanged original constructor sets selection palette1 to opaque yellow")
	check(oracle.rows.all(func(row):return int(row.selected)<0 or int(row.palettes[str(int(row.selected))])==1),"Unchanged original selected-row setter actually selects constructor palette1")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original popup resources mount read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Source captions retain original TLK owner")
	surface=SubViewport.new();surface.size=Vector2i(1000,800);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=FeatPopup.new();surface.add_child(pane);pane.position=Vector2(80,70);pane.configure(painter,text,catalog,"")
	var parser:=Gff.new();var bytes: PackedByteArray=catalog.get_resource("cg_feats_popup",2047);check(preload("res://systems/native_data/prepared_cache.gd").digest(bytes)=="ff319e5d9d69beff70242e6dcd8c705092cd13bd0d1ac2c480dc0b959ebc3385","Actual original CG_FEATS_POPUP hierarchy is pinned")
	pane.source=parser.parse(bytes).root;check(parser.failure.is_empty(),"Actual original popup hierarchy decodes")
	var resources: Dictionary={};collect(pane.source,resources)
	for name in pane.extra_models:resources[name]=true
	for name in resources:
		var decoder:=Model.new();pane.models[name]=decoder.parse(catalog.get_resource(name,2002));check(decoder.failure.is_empty(),"Actual original popup model decodes: "+str(name))
	pane.plan=pane.parse_layout();check(str(pane.plan.get("error","")).is_empty(),"Actual original popup source hooks/layout remain available")
	if not str(pane.plan.get("error","")).is_empty():quit(1);return
	pane.size=pane.plan.size;pane.custom_minimum_size=pane.size;pane.assemble();pane.layout_ready=true;check(pane.failure.is_empty(),"Original popup controls assemble without a rendering wait")
	var names: Array=["Abyssal","Fathomless","Infernal","Night Hag","Star","Undying","Unseelie Fey"];var entries: Array=[]
	for index in names.size():entries.append({"id":20001+index*37,"name":names[index]})
	var model:={"ready":true,"entries":entries};var finishes: Array=[];pane.finished.connect(func(accepted,id,ticket):finishes.append([accepted,id,ticket]))
	pane.set_context(model,text,painter.art,[91,7]);pane.open();await frames()
	var caption: Dictionary=pane.plan.entries.featslist.caption;var normal:=Color(float(caption.get("AurString_ColorR",1)),float(caption.get("AurString_ColorG",1)),float(caption.get("AurString_ColorB",1)),float(caption.get("AurString_ColorA",1)))
	check(pane.selected==-1 and pane.buttons.okbutton.disabled and pane.row_buttons.size()==7,"Multiple active server subtype choices require an explicit selection")
	for index in names.size():
		await click(pane.row_buttons[index]);check(pane.selected==index and not pane.buttons.okbutton.disabled,"Physical custom subtype row is selected: "+names[index])
		check(selection_visible(pane,highlight,normal),"Chosen custom subtype alone visibly retains original yellow through normal/hover/pressed draw states: "+names[index])
		check(pane.row_buttons[index].text==names[index] and int(pane.model.entries[index].id)==20001+index*37,"Custom active names/physical IDs remain paired")
	var before:=pane.selected;var old_rows: Array=pane.row_buttons.map(func(button):return button.get_instance_id());painter.fonts.metrics["fnt_galahad14"]={"height":18};painter.fonts.loaded.emit("fnt_galahad14");await frames()
	check(old_rows!=pane.row_buttons.map(func(button):return button.get_instance_id()) and pane.selected==before and selection_visible(pane,highlight,normal),"Late native font metrics rebuild preserves selected-row draw state and physical identity")
	await click(pane.buttons.okbutton);check(finishes==[[true,20223,[91,7]]] and not pane.wanted,"Original OK commits the selected active physical subtype ID once")
	pane.set_context({"ready":true,"entries":[{"id":3456,"name":"Only active subtype"}]},text,painter.art,[91,8]);pane.open();await frames();check(pane.selected==0 and selection_visible(pane,highlight,normal),"A sole original auto-selection has the same visible indicator")
	pane.set_context(model,text,painter.art,[91,9]);await frames();await mouse(pane.row_buttons[2],true);pane.set_context(model,text,painter.art,[92,1]);await mouse(pane.row_buttons[2],false);await frames();check(pane.selected==-1 and finishes.size()==1 and selection_visible(pane,highlight,normal),"Held input cannot highlight or commit a replacement scope")
	await click(pane.row_buttons[3]);pane.set_busy(true);check(pane.selected==3 and pane.row_buttons.all(func(button):return button.disabled),"Pending owner work retains choice but blocks repeat input")
	pane.set_context({"ready":false},text,painter.art,[92,2]);check(pane.selected==-1 and pane.row_buttons.is_empty() and pane.buttons.okbutton.disabled,"Unavailable replacement model retires old selected rows and commit")
	pane.close();pane.queue_free();painter.art.close();painter.close();painter.queue_free();text.close();await frames(5);surface.queue_free();await frames()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalSelectionPalette":[highlight.r,highlight.g,highlight.b,highlight.a],"scope":"Actual installed popup controls plus physical subtype input and original-backed theme/draw state, held/rebind/dependency and late-font cases under controlled nonrendering publication. No original rendered pixel or full creator/server acceptance.","gpu":false,"serverConnections":0})+"\n");file.close();quit(0 if failures.is_empty() else 1)
