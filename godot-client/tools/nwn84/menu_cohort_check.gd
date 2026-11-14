extends SceneTree
const KeyPage=preload("res://systems/native_key_settings.gd")
const VideoPage=preload("res://systems/native_video_options.gd")
const OptionsPage=preload("res://systems/native_entry_menu_frame.gd")
class FakeArt extends RefCounted:
	var textures: Dictionary={}
	var failed: Dictionary={}
class FakeFonts extends RefCounted:
	var failed: Dictionary={}
class FakeFrame extends RefCounted:
	var art=FakeArt.new()
	var fonts=FakeFonts.new()
	var button_geometry: Dictionary={}
class FakeScroll extends Control:
	var art_ready:=true
	var failure:=""
	var thumb_image_key:="thumb"
	var thumb_key:="thumb"
class FakeSettings extends RefCounted:
	var query_ready:=false
	var error:=""
func _initialize() -> void: call_deferred("run")
func fail(reason: String) -> void: push_error(reason); quit(2)
func run() -> void:
	var key=KeyPage.new(); key.frame=FakeFrame.new(); key.scrollbar=FakeScroll.new(); key.layout_ready=true
	for index in 5:key.row_art_keys.append("pose"+str(index))
	if key.art_ready():fail("Key page admitted absent row poses");return
	for pose in key.row_art_keys:key.frame.art.textures[pose]=ImageTexture.new()
	var icon:=TextureRect.new(); key.add_child(icon); icon.set_meta("native_gui_art_key","key_icon")
	if key.art_ready():fail("Key page admitted absent original image");return
	icon.texture=ImageTexture.new()
	var label:=Label.new(); key.add_child(label); label.set_meta("native_font_resource","fnt_galahad14")
	if key.art_ready():fail("Key page admitted absent font");return
	label.set_meta("native_font_applied","fnt_galahad14")
	if not key.art_ready():fail("Key page did not admit complete cohort: "+JSON.stringify(key.cohort_snapshot()));return
	var video=VideoPage.new(); video.frame=FakeFrame.new(); video.scrollbar=FakeScroll.new(); video.settings=FakeSettings.new(); video.layout_ready=true
	if video.art_ready():fail("Video page admitted before display modes were ready");return
	video.settings.query_ready=true
	if not video.art_ready():fail("Video page did not admit prepared modes: "+JSON.stringify(video.cohort_snapshot()));return
	if OptionsPage==null:fail("Options page script failed to load");return
	print(JSON.stringify({"key_cohort":"pass","video_mode_gate":"pass","options_script":"loaded"}))
	quit()
