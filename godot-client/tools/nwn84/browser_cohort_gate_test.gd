extends SceneTree
const Cohort=preload("res://systems/native_data/constructed_ui_cohort.gd")
const Browser=preload("res://systems/native_server_browser.gd")
const Controller=preload("res://systems/server_browser.gd")
const Direct=preload("res://systems/native_direct_connect.gd")
const Profile=preload("res://systems/native_player_profile.gd")
const Filters=preload("res://systems/native_server_filters.gd")
const Details=preload("res://systems/native_server_details.gd")
const Password=preload("res://systems/native_server_password.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
const Entry=preload("res://systems/native_entry_menu_frame.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Icons=preload("res://systems/native_item_icons.gd")
class FakeBar:
	extends Control
	var rail: TextureRect
	var thumb: TextureRect
	var rail_key:="gui:rail:"
	var thumb_key:="gui:thumb:"
	var thumb_image_key:="gui:thumb:"
	var failure:=""
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
	var first:=Control.new(); root.add_child(first)
	var image:=TextureRect.new(); first.add_child(image); image.set_meta("native_gui_art_key","gui:first:")
	var label:=Label.new(); first.add_child(label); label.text="First"; label.set_meta("native_font_resource","first_font")
	var other:=Control.new(); root.add_child(other)
	var other_image:=TextureRect.new(); other.add_child(other_image); other_image.set_meta("native_gui_art_key","gui:other:")
	var unbound:=Label.new(); other.add_child(unbound); unbound.text="Generated fallback"
	var a: Dictionary=Cohort.capture("first",first,painter,{"first":{}})
	var b: Dictionary=Cohort.capture("other",other,painter,{"other":{}})
	check(a.images.size()==1 and a.fonts.size()==1 and b.untagged_fonts==1,"Static capture freezes exact per-screen image and bound-font targets")
	check(not Cohort.snapshot(a,painter).ready and Cohort.snapshot(a,painter).pending.size()==2,"Cold image and font block only their screen")
	var pixels:=Image.create(2,2,false,Image.FORMAT_RGBA8); pixels.fill(Color.WHITE); var texture:=ImageTexture.create_from_image(pixels)
	art.textures["gui:first:"]=texture; image.texture=texture; label.set_meta("native_font_applied","first_font")
	check(Cohort.snapshot(a,painter).ready and not Cohort.snapshot(b,painter).ready,"One ready screen does not admit its neighbor")
	var dynamic:=TextureRect.new(); first.add_child(dynamic)
	check(Cohort.snapshot(a,painter).ready,"Later dynamic row artwork does not enter the sealed static cohort")
	art.failed["gui:other:"]=true
	check(not Cohort.snapshot(b,painter).ready and str(Cohort.snapshot(b,painter).failures[0]).contains("gui:other:"),"Missing image reports its exact screen key")
	label.remove_meta("native_font_applied"); fonts.failed["first_font"]="Broken atlas"
	check(not Cohort.snapshot(a,painter).ready and str(Cohort.snapshot(a,painter).failures[0]).contains("first_font"),"Corrupt font reports its exact bound key")
	var bar:=FakeBar.new(); root.add_child(bar)
	bar.rail=TextureRect.new(); bar.add_child(bar.rail); bar.rail.set_meta("native_gui_art_key",bar.rail_key)
	bar.thumb=TextureRect.new(); bar.add_child(bar.thumb); bar.thumb.set_meta("native_gui_art_key",bar.thumb_key)
	var right:=ImageTexture.create_from_image(pixels)
	art.textures[bar.rail_key]=right; art.textures[bar.thumb_key]=right
	bar.rail.texture=right; bar.thumb.texture=texture
	var bar_manifest: Dictionary=Cohort.capture("bar",bar,painter,{},[bar])
	check(not Cohort.snapshot(bar_manifest,painter).ready,"A non-null image from the wrong key cannot admit the initial scrollbar cohort")
	bar.thumb.texture=right
	check(Cohort.snapshot(bar_manifest,painter).ready and bar_manifest.admitted,"Exact published rail/thumb keys admit the initial scrollbar cohort")
	bar.thumb.set_meta("native_gui_art_key","gui:dynamic-thumb:"); bar.thumb.texture=texture
	check(Cohort.snapshot(bar_manifest,painter).ready,"A later dynamic thumb replacement does not unseal the admitted static screen")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  "))
	file.close(); quit(0 if failures.is_empty() else 1)
