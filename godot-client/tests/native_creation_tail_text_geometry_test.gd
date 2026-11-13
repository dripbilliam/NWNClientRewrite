extends "res://tests/native_creation_appearance_view_test.gd"
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
const Inspect=preload("res://tests/native_font_ink_probe.gd")
func find_label(pane:Control,value:String)->Label:
	for child in pane.get_children():
		if child is Label and child.text==value:return child
	return null
func original_label(pane,tag:String)->Label:return find_label(pane,pane.caption(pane.plan.entries[tag]))
func source_images(pane:Control,rect:Rect2)->Array:
	return pane.get_children().filter(func(child):return child is TextureRect and child.get_meta("native_gui_static_image",false) and child.get_rect().is_equal_approx(rect))
func above_background(label:Label,pane:Control,ink:Rect2)->bool:
	for image in pane.get_children():
		if image is TextureRect and image.get_meta("native_gui_static_image",false) and image.get_index()>label.get_index() and image.get_rect().intersects(ink):return false
	return true
func inspect_label(pane,tag:String,diagnostic:Dictionary)->void:
	var label:=original_label(pane,tag)
	if not check_label(label,tag):return
	var entry:Dictionary=pane.plan.entries[tag];var value:=Inspect.label_view(label,entry);var ink:=Inspect.glyph_ink(label);value.ink=ink;value.siblingIndex=label.get_index();diagnostic[tag]=value
	check(not value.fontApplied.is_empty() and value.missing.is_empty(),"Real original font covers "+pane.get_script().resource_path+"/"+tag)
	check(ink.present and Rect2(Vector2.ZERO,pane.size).grow(1).encloses(ink.rect),"Literal original atlas ink stays in the native frame: "+tag)
	check(above_background(label,pane,ink.rect),"No later source background obscures literal text: "+tag)
func check_label(label:Label,tag:String)->bool:
	var valid:=is_instance_valid(label);check(valid,"The actual source Label exists: "+tag);return valid
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original tail captions open")
	surface=SubViewport.new();surface.size=Vector2i(1600,900);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var appearance:=Pane.new();surface.add_child(appearance);appearance.configure(painter,text,catalog,"")
	var parts:Array=[];parts.resize(19);parts.fill(1);var skin:Dictionary=Pane.State.tattoo_parts(0,parts)
	appearance.set_context({"appearanceValid":true,"modelType":"P","customizeMode":0,"enabledPhenotypes":5,"headIndexComplete":true,"heads":{1:true,2:true},"paletteSizes":{"skin":176,"hair":176,"tattoo1":176,"tattoo2":176},"clothing":[],"value":{"phenotype":0,"head":1,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"tattooPattern":0,"bodyParts":parts,"skinParts":skin.skinParts,"clothingIndex":0}},["tail",1]);appearance.open();appearance.start()
	var info:=Information.new();surface.add_child(info);info.configure(painter,text,catalog,"");info.position=Vector2(800,0)
	info.set_context({"value":{"firstName":"Native","lastName":"View","ageText":"129","description":"Original biography text","deity":"Known deity","soundset":123},"voices":[{"id":123,"name":"Active voice sample","resRef":"test_voice"}],"randomReady":false},["tail",2]);info.open();info.start()
	var deadline:=Time.get_ticks_msec()+20000
	while (not appearance.layout_ready or not info.layout_ready or not info.deity.layout_ready or not fonts.pending.is_empty()) and appearance.failure.is_empty() and info.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(appearance.layout_ready and info.layout_ready and info.deity.layout_ready and appearance.failure.is_empty() and info.failure.is_empty() and fonts.failed.is_empty() and fonts.pending.is_empty(),"Both original tail views and actual installed fonts prepare")
	await frames(5)
	var diagnostic:Dictionary={"fonts":fonts.snapshot(),"appearance":{},"info":{}}
	if appearance.layout_ready:
		for tag in ["title"]+Pane.Layout.ROWS.keys():inspect_label(appearance,tag,diagnostic.appearance)
		for tag in Pane.Layout.ROWS:
			var entry:Dictionary=appearance.plan.entries[tag];var images:=source_images(appearance,entry.rect);var label:=original_label(appearance,tag)
			check(images.size()==1 and is_instance_valid(label) and images[0].get_index()<label.get_index(),"Exactly one original Appearance row background draws below its name: "+tag)
	if info.layout_ready:
		for tag in Information.Layout.LABELS:inspect_label(info,tag,diagnostic.info)
		for tag in Information.Layout.EDITS:
			var edit:LineEdit=info.edits[tag];var font:Font=edit.get_theme_font("font");var height:=edit.get_theme_font_size("font_size");diagnostic.info[tag]={"text":edit.text,"rect":edit.get_rect(),"sourceTextRect":info.plan.entries[tag].text_rect,"font":str(edit.get_meta("native_font_applied","")),"shapeSize":font.get_string_size(edit.text,HORIZONTAL_ALIGNMENT_LEFT,-1,height)}
			check(not str(edit.get_meta("native_font_applied","")).is_empty() and not edit.text.is_empty() and edit.get_theme_color("font_color").a>0,"Original info edit has literal native-font text: "+tag)
		var voice:Dictionary=info.rows[0];var label:Label=voice.label;var ink:=Inspect.glyph_ink(label);diagnostic.info.voice={"text":label.text,"ink":ink,"row":voice.button.get_rect(),"label":label.get_rect()}
		check(ink.present and voice.button.get_rect().grow(1).encloses(ink.rect),"Literal voice text ink stays inside its original source button")
	appearance.close();info.close();appearance.free();info.free();painter.close();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(Inspect.packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"gpu":false,"serverConnections":0,"realInstalledFonts":true,"artworkDouble":true,"scope":"Tail view original font atlas ink, claimed-title/label geometry and source background ordering. No production creator integration, actual3D, selected-swatch pixels, audio or server acceptance."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
