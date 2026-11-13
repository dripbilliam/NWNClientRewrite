extends SceneTree
const Page=preload("res://systems/native_entry_menu_frame.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
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
	var page:=Page.new(); root.add_child(page); page.frame=painter; page.kind="options_pregame"
	check(not page.art_ready() and page.cohort_snapshot().pending==["GFF/model layout"],"Cold options page cannot admit before static layout/model completion")
	page.layout_ready=true; page.requested={"pnl_options":true}; page.models={"pnl_options":{}}
	page.stage=Control.new(); page.add_child(page.stage)
	page.confirmation=Control.new(); page.add_child(page.confirmation); page.confirmation.hide()
	var picture:=TextureRect.new(); page.stage.add_child(picture); var image_key:=Icons.model_key("pnl_options",""); picture.set_meta("native_gui_art_key",image_key)
	var font:=Label.new(); font.text="Options"; font.set_meta("native_font_resource","fnt_galahad14"); page.stage.add_child(font)
	var button:=Button.new(); page.stage.add_child(button)
	var style:=StyleBoxTexture.new(); var button_key:=Icons.model_key("ctl_options","up")
	painter.button_geometry[button.get_instance_id()]={"resource":"ctl_options","overrides":{},"styles":{"normal":[style,"up"]}}
	page.buttons={"optionsbutton":button}; page.captions={"optionsbutton":font}
	var confirm:=TextureRect.new(); page.confirmation.add_child(confirm); var confirm_key:=Icons.model_key("okpanel",""); confirm.set_meta("native_gui_art_key",confirm_key)
	var cold: Dictionary=page.cohort_snapshot()
	check(cold.scope=="options_pregame+okcancelpanel" and cold.models_expected==1 and cold.images_expected==3 and cold.fonts_expected==1,"Exact options and hidden confirmation cohort is enumerated")
	check(not page.art_ready() and cold.pending.has("image:"+confirm_key),"Hidden confirmation remains an options admission dependency")
	var pixels:=Image.create(4,4,false,Image.FORMAT_RGBA8); pixels.fill(Color.RED); var texture:=ImageTexture.create_from_image(pixels)
	picture.texture=texture; style.texture=texture; font.set_meta("native_font_applied","fnt_galahad14")
	check(not page.art_ready(),"Prepared visible controls cannot bypass hidden confirmation")
	confirm.texture=texture
	check(page.art_ready() and page.cohort_snapshot().ready,"Complete options cohort admits")
	page.dismiss(); page.show()
	check(page.art_ready(),"Reopen reuses ready options cohort")
	confirm.texture=null; art.failed[confirm_key]=true
	var failed: Dictionary=page.cohort_snapshot()
	check(not page.art_ready() and str(failed.failures[0]).contains(confirm_key),"Failed hidden image blocks options and names exact key")
	art.failed.erase(confirm_key); confirm.texture=texture; font.remove_meta("native_font_applied"); fonts.failed["fnt_galahad14"]="Broken font atlas"
	failed=page.cohort_snapshot()
	check(not page.art_ready() and str(failed.failures[0]).contains("Broken font atlas"),"Failed font blocks options and names cause")
	page.close(); page.free(); painter.close(); painter.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
