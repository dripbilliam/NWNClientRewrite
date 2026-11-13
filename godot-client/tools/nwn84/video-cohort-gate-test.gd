extends SceneTree
const Page=preload("res://systems/native_video_options.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Scrollbar=preload("res://systems/native_scrollbar.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var painter:=Painter.new(); root.add_child(painter)
	var art:=Art.new(); painter.add_child(art); art.models=Icons.new(); art.add_child(art.models); painter.art=art
	var fonts:=Fonts.new(); painter.add_child(fonts); painter.fonts=fonts
	var page:=Page.new(); root.add_child(page); page.frame=painter
	check(not page.art_ready() and page.cohort_snapshot().pending==["GFF/model layout"],"Cold video page waits for its layout")
	page.layout_ready=true; page.requested={"options_vidmodes":true}; page.models={"options_vidmodes":{}}
	var picture:=TextureRect.new(); page.add_child(picture); var key:=Icons.model_key("vidmodes",""); picture.set_meta("native_gui_art_key",key)
	var label:=Label.new(); label.text="Resolution"; label.set_meta("native_font_resource","fnt_galahad14"); page.add_child(label)
	var button:=Button.new(); page.add_child(button); var style:=StyleBoxTexture.new(); var button_key:=Icons.model_key("ctl_vid","up")
	painter.button_geometry[button.get_instance_id()]={"resource":"ctl_vid","overrides":{},"styles":{"normal":[style,"up"]}}
	page.buttons={"okbutton":button}
	var scrollbar:=Scrollbar.new(); page.add_child(scrollbar); page.scrollbar=scrollbar
	scrollbar.thumb_key="thumb-a"; scrollbar.thumb_image_key="thumb-a"; scrollbar.art_ready=true
	var cold: Dictionary=page.cohort_snapshot()
	check(not cold.ready and cold.images_expected==2 and cold.fonts_expected==1 and cold.pending.has("image:"+key),"Only constructed video artwork and fonts form the gate")
	var pixels:=Image.create(2,2,false,Image.FORMAT_RGBA8); pixels.fill(Color.WHITE); var texture:=ImageTexture.create_from_image(pixels)
	picture.texture=texture; style.texture=texture; label.set_meta("native_font_applied","fnt_galahad14")
	art.waiting["unrelated"]=[1]; art.models.pending["unrelated"]=true; fonts.pending["unrelated"]=true
	check(page.art_ready(),"Unrelated UI artwork and font jobs do not delay a ready video page")
	scrollbar.thumb_key="thumb-b"
	check(not page.art_ready() and page.cohort_snapshot().pending.has("video scrollbar"),"New scrollbar thumb must finish before admission")
	scrollbar.thumb_image_key="thumb-b"; check(page.art_ready(),"Completed scrollbar thumb restores readiness")
	picture.texture=null; art.failed[key]=true
	check(not page.art_ready() and str(page.cohort_snapshot().failures[0]).contains(key),"Corrupt video image names its exact key")
	art.failed.erase(key); picture.texture=texture; label.remove_meta("native_font_applied"); fonts.failed["fnt_galahad14"]="Broken atlas"
	check(not page.art_ready() and str(page.cohort_snapshot().failures[0]).contains("Broken atlas"),"Corrupt page font names its cause")
	fonts.failed.clear(); label.set_meta("native_font_applied","fnt_galahad14"); page.models.clear()
	check(not page.art_ready() and page.cohort_snapshot().failures.has("Resolved video model cohort is incomplete"),"Missing source model blocks admission")
	page.close(); page.free(); painter.close(); painter.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
