extends SceneTree
const Page=preload("res://systems/native_entry_menu_frame.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Pregame=preload("res://systems/native_pregame_menu.gd")
class FailedPage:
	extends Control
	var layout_ready:=true
	var buttons: Dictionary={}
	func cohort_snapshot() -> Dictionary: return {"scope":"pre_main+okcancelpanel","failures":["Page image gui:missing:up: Corrupt image"]}
	func art_ready() -> bool: return false
	func set_context(_scope: Array,_enabled: Dictionary,_colors: Dictionary={}) -> void: pass
	func dismiss() -> void: hide()
	func close() -> void: pass
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
	var page:=Page.new(); root.add_child(page); page.frame=painter; page.kind="pre_main"
	var before: Dictionary=page.cohort_snapshot()
	check(not before.sealed and not before.ready and before.pending==["GFF/model layout"],"Cold page cannot seal before both GFFs and recursive models resolve")
	page.layout_ready=true; page.requested={"pnl_main":true}; page.models={"pnl_main":{}}
	page.stage=Control.new(); page.add_child(page.stage)
	page.confirmation=Control.new(); page.add_child(page.confirmation); page.confirmation.hide()
	var image_key:=Icons.model_key("pnl_main","")
	var picture:=TextureRect.new(); page.stage.add_child(picture); picture.set_meta("native_gui_art_key",image_key)
	var font:=Label.new(); font.text="Main menu"; font.set_meta("native_font_resource","fnt_galahad14"); page.stage.add_child(font)
	var button:=Button.new(); page.stage.add_child(button)
	var style:=StyleBoxTexture.new(); var button_key:=Icons.model_key("ctl_main","up")
	painter.button_geometry[button.get_instance_id()]={"resource":"ctl_main","overrides":{},"styles":{"normal":[style,"up"]}}
	page.buttons={"mainbutton":button}; page.captions={"mainbutton":font}
	var confirm:=TextureRect.new(); page.confirmation.add_child(confirm); var confirm_key:=Icons.model_key("okpanel",""); confirm.set_meta("native_gui_art_key",confirm_key)
	var cold: Dictionary=page.cohort_snapshot()
	check(cold.sealed and not cold.ready and cold.images_expected==3 and cold.fonts_expected==1,"Constructed main and hidden confirmation form one exact scoped cohort")
	check(cold.pending.has("image:"+confirm_key) and cold.pending.has("font:fnt_galahad14"),"Cold hidden confirmation and font remain pending")
	var pixels:=Image.create(4,4,false,Image.FORMAT_RGBA8); pixels.fill(Color.RED); var texture:=ImageTexture.create_from_image(pixels)
	picture.texture=texture; style.texture=texture; font.set_meta("native_font_applied","fnt_galahad14")
	check(not page.art_ready(),"Page remains blocked until the hidden confirmation image is ready")
	confirm.texture=texture
	var ready: Dictionary=page.cohort_snapshot()
	check(ready.ready and ready.images_ready==3 and ready.fonts_ready==1 and ready.scope=="pre_main+okcancelpanel","All enumerated main-page images, model and font admit only the named two-layout cohort")
	page.dismiss(); page.show()
	check(page.art_ready() and page.cohort_snapshot().pending.is_empty(),"Reopening the prepared page needs no new image or font request")
	confirm.texture=null; art.failed[confirm_key]=true
	var failed: Dictionary=page.cohort_snapshot()
	check(not failed.ready and str(failed.failures[0]).contains(confirm_key),"Missing hidden-confirmation asset names the exact failed key")
	art.failed.erase(confirm_key); confirm.texture=texture; font.remove_meta("native_font_applied"); fonts.failed["fnt_galahad14"]="Broken font atlas"
	failed=page.cohort_snapshot()
	check(not failed.ready and str(failed.failures[0]).contains("fnt_galahad14") and str(failed.failures[0]).contains("Broken font atlas"),"Corrupt font shows the exact key and source failure")
	var pregame:=Pregame.new(); root.add_child(pregame)
	pregame.status=Label.new(); pregame.add_child(pregame.status)
	pregame.main=FailedPage.new(); pregame.add_child(pregame.main); pregame.page="main"; pregame.wanted=true
	pregame.refresh()
	check(pregame.status.visible and pregame.status.text.contains("pre_main+okcancelpanel") and pregame.status.text.contains("gui:missing:up"),"Pregame presents exact scoped failure instead of endless preparation text")
	pregame.close(); pregame.free()
	page.close(); page.free(); painter.close(); painter.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Constructed pre_main+okcancelpanel cold/reopen cohort and explicit image/font failure; authored textures and controls, not installed-content or graphical acceptance."},"  "))
	file.close(); quit(0 if failures.is_empty() else 1)
