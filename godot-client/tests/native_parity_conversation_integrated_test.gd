extends SceneTree
# Actual conversation/frame/window-layer parenting, including a visible legacy
# layout before asynchronous native skin activation. No server, raster or GPU.
# Text is an authored reproduction, not a claim of captured server content.
const Conversation=preload("res://systems/server_conversation.gd")
const ConversationFrame=preload("res://systems/native_conversation_frame.gd")
const Layers=preload("res://systems/native_window_layers.gd")
const ServerText=preload("res://systems/server_text.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const NativePainter=preload("res://systems/native_gui_painter.gd")
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
const WindowSettings=preload("res://systems/native_window_settings.gd")
class Art extends RefCounted:
	signal loaded(key,texture,bounds)
	var textures: Dictionary={}
	func bind_portrait(_control,_resource: String) -> void:pass
	func request_model(_name: String,_clip: String,_options: Dictionary,_count: int,_extra: String,_poses: Array) -> String:return "fixture-background"
class Fonts extends RefCounted:
	signal loaded(name)
class Frame extends RefCounted:
	var art=Art.new()
	var fonts=Fonts.new()
	func font_style(control,_caption) -> void:
		if control is RichTextLabel:control.add_theme_font_size_override("normal_font_size",14)
		elif control is Label:control.add_theme_font_size_override("font_size",14)
class TextOwner extends RefCounted:
	var objects: Dictionary={}
	func name(_value,_id: int) -> String:return "Gondolier"
	func raw(_value) -> String:return "Gondolier"
	func rich(value: Dictionary,_id: int) -> Dictionary:return value
class Ui extends RefCounted:
	var text=TextOwner.new()
	var conversation
	var inventory: Dictionary={}
var checks:=0
var failures: Array=[]
var rows: Array=[]
var output:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func tick_frames(count: int=4) -> void:
	for at in count:await process_frame
func layout_state(skin,dialog,tag: String) -> Dictionary:
	return {"tag":tag,"body_width":dialog.body.size.x,"body_minimum":dialog.body.get_combined_minimum_size().x,"entry_width":skin.entry_scroll.size.x,"body_lines":dialog.body.get_line_count(),"body_height":dialog.body.get_content_height(),"body_global":str(dialog.body.get_global_rect()),"entry_global":str(skin.entry_scroll.get_global_rect()),"dialog_global":str(dialog.get_global_rect()),"body_text":dialog.body.get_parsed_text()}
func reference_label(body: RichTextLabel,rich: Dictionary,width: float,parent: Control) -> RichTextLabel:
	var reference:=RichTextLabel.new();parent.add_child(reference);reference.position=Vector2(-5000,-5000)
	ServerText.style(reference);reference.theme=body.theme
	for key in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]:reference.add_theme_font_override(key,body.get_theme_font(key))
	for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]:reference.add_theme_font_size_override(key,body.get_theme_font_size(key))
	reference.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;reference.fit_content=true;reference.scroll_active=false;reference.custom_minimum_size=Vector2(width,0);reference.size=Vector2(width,0)
	ServerText.set_text(reference,rich);return reference
func character_lines(label: RichTextLabel) -> Array:
	var result: Array=[]
	for at in label.get_total_character_count():result.append(label.get_character_line(at))
	return result
func run() -> void:
	var install:="";var cache_path:="";var override_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
		elif arg.begins_with("--override="):override_path=arg.substr(11)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(1280,800)
	var canvas:=CanvasLayer.new();canvas.layer=10;root.add_child(canvas)
	var controls:=Control.new();canvas.add_child(controls);controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controls.position=Vector2(17,9);controls.scale=Vector2.ONE*(337.0/360.0)
	var background_window:=PanelContainer.new();controls.add_child(background_window);background_window.position=Vector2(900,20);background_window.size=Vector2(100,100)
	var dialog:=Conversation.new();controls.add_child(dialog);dialog.setup("");dialog.position=Vector2(60,70)
	var layers:=Layers.new();root.add_child(layers);layers.configure(controls)
	var fixture_text:="Save you a walk? For 5 gold I can get you to the docks in no time."
	var rich:={"spans":[{"text":"Save you a walk? ","color":"#66B3FF"},{"text":"For 5 gold I can get you to the docks in no time.","color":"#FFFFFF"}]}
	dialog.present({"kind":"dialog-entry","speakerId":43,"rich":rich})
	dialog.present({"kind":"dialog-replies","entryId":51,"replies":[{"id":91,"available":true,"rich":{"text":"Yes, take me there."}},{"id":92,"available":true,"rich":{"text":"No, thank you."}}]})
	# The actual visible prototype has already been laid out while native asset
	# work is pending. Immediate same-frame activation misses this lifetime.
	await tick_frames()
	var inherited_width: float=dialog.body.size.x
	check(inherited_width>=540,"Visible legacy content really reaches its original540px minimum before native activation")
	var skin:=ConversationFrame.new();root.add_child(skin);skin.set_process(false)
	var actual_painter
	var catalog
	if not install.is_empty():
		catalog=Catalog.new();check(catalog.mount_install(install),"Actual installed catalog mounts read-only")
		if not override_path.is_empty():check(catalog.mount_directory(override_path,10000000),"Actual active-profile override layer mounts at native session priority")
		actual_painter=NativePainter.new();root.add_child(actual_painter);actual_painter.set_process(false);actual_painter.art=Art.new()
		actual_painter.fonts=NativeFonts.new();actual_painter.add_child(actual_painter.fonts);actual_painter.fonts.configure(catalog,cache_path)
		var owner:=Ui.new();owner.conversation=dialog;owner.inventory={"frame_skin":actual_painter};skin.configure(owner,catalog,cache_path)
		var deadline:=Time.get_ticks_msec()+10000
		while Time.get_ticks_msec()<deadline and (not skin.layout_ready or not actual_painter.fonts.fonts.has(skin.Plan.FONT) or not actual_painter.fonts.fonts.has("fnt_galahad14")) and skin.failure.is_empty():
			skin._process(0);await process_frame
		check(skin.layout_ready and skin.failure.is_empty() and actual_painter.fonts.fonts.has(skin.Plan.FONT),"Actual source models and original dialogue font finish native skin activation")
		if not skin.layout_ready:
			skin.close();skin.free();actual_painter.close();actual_painter.free();layers.close();layers.free();canvas.free();quit(1);return
		for at in 6:skin._process(0);await process_frame
	else:
		skin.ui=Ui.new();skin.frame=Frame.new();skin.view=dialog;dialog.native_skin=skin;dialog.rendered.connect(skin.changed)
		skin.activate();skin.stage.size=Vector2(360,258)
		skin.geometry={"entry":Rect2(85,25,261,100),"replies":Rect2(12,150,331,80)}
		skin.entry_scroll.position=Vector2(85,25);skin.entry_scroll.size=Vector2(261,100)
		skin.reply_scroll.position=Vector2(12,150);skin.reply_scroll.size=Vector2(331,80)
		skin.portrait.position=Vector2(12,25);skin.portrait.size=Vector2(64,100)
	skin.sync_text_widths();await tick_frames()
	rows.append(layout_state(skin,dialog,"cold-native-activation"))
	var reference:=reference_label(dialog.body,rich,skin.entry_scroll.size.x,controls);await tick_frames()
	if override_path.is_empty():check(absf(dialog.get_global_rect().size.x-337.0)<0.01,"Unmodified retail dialogue retains its337px scaled physical width")
	else:check(dialog.size.x>360 and skin.entry_scroll.size.x>400,"Active wider dialogue override expands its stage instead of clipping at the retail width")
	check(layers.roots.has(dialog.get_instance_id()) and dialog.material is ShaderMaterial and skin.stage.use_parent_material,"Actual NativeWindowLayers owns and propagates the same conversation subtree")
	check(dialog.body.get_parsed_text()==fixture_text,"Colored received-style spans retain all entry words")
	check(dialog.body.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"NPC entry uses word wrapping")
	check(Rect2(Vector2.ZERO,skin.stage.size).grow(0.01).encloses(skin.entry_scroll.get_rect()),"Clipped native stage encloses the entire authored NPC text viewport")
	check(Rect2(Vector2.ZERO,skin.stage.size).grow(0.01).encloses(skin.name_label.get_rect()),"Clipped native stage encloses the entire authored speaker-name viewport")
	check(dialog.body.size.x<=skin.entry_scroll.size.x+0.01,"Cold native entry wraps inside its actual viewport, rather than clipping inherited prototype width")
	check(dialog.body.get_combined_minimum_size().x<=skin.entry_scroll.size.x+0.01,"NPC text minimum cannot force horizontal scroll behind the hidden rail")
	check(character_lines(dialog.body)==character_lines(reference),"Every NPC glyph, including middle words, wraps on the same line as an independently constrained reference")
	check(dialog.body.get_content_height()<=skin.entry_scroll.size.y and dialog.body.get_line_count()==reference.get_line_count(),"All authored NPC entry lines fit the visible entry viewport")
	check((not override_path.is_empty() or skin.portrait.size==Vector2(64,100)) and skin.portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Original portrait retains64x100 while source overrides retain the aspect convention")
	if not override_path.is_empty():check(skin.portrait.size.is_equal_approx(Vector2(96,150)),"Actual override portrait uses its authored96x150 transformed mesh bounds")
	for width in [180.0,261.0,201.0,261.0]:
		skin.entry_scroll.size.x=width;skin.sync_text_widths();await tick_frames()
		reference.custom_minimum_size.x=skin.entry_scroll.size.x;reference.size.x=skin.entry_scroll.size.x;await tick_frames()
		rows.append(layout_state(skin,dialog,"resize-"+str(width)))
		check(absf(dialog.body.size.x-skin.entry_scroll.size.x)<0.01,"NPC entry follows resized visible width"+str(width))
		check(character_lines(dialog.body)==character_lines(reference),"Each NPC word retains its constrained glyph wrap after resize"+str(width))
	for scale_value in [1.0,1.25,2.0]:
		controls.scale=Vector2.ONE*scale_value;skin.sync_text_widths();await tick_frames()
		check(absf(dialog.body.get_global_rect().size.x-skin.entry_scroll.get_global_rect().size.x)<0.01,"Parent UI scale preserves body/viewport agreement"+str(scale_value))
	controls.scale=Vector2.ONE
	var window_settings:=WindowSettings.new();window_settings.window=root;window_settings.unconstrained=true
	for scale_value in [1.0,1.25,2.0]:
		check(window_settings.apply_scale(scale_value,false),"Actual Window canvas-items UI scaling accepts fixture value")
		skin.sync_text_widths();await tick_frames()
		check(absf(dialog.body.get_global_rect().size.x-skin.entry_scroll.get_global_rect().size.x)<0.01 and character_lines(dialog.body)==character_lines(reference),"Actual Window scaling retains glyph wrapping and viewport width"+str(scale_value))
	window_settings.close();window_settings.free()
	dialog.present({"kind":"dialog-entry","speakerId":43,"rich":{"text":"A replacement server entry retains every word and rewraps at the current narrow viewport."}})
	skin.sync_text_widths();await tick_frames()
	check(absf(dialog.body.size.x-skin.entry_scroll.size.x)<0.01,"Replacement entry does not reintroduce prototype width")
	check(dialog.replies.get_child_count()==0 and dialog.entry_id==-1,"Layout retains actual conversation replacement ownership")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"inherited_width":inherited_width,"states":rows,"portrait_size":[skin.portrait.size.x,skin.portrait.size.y],"portrait_rect":str(skin.portrait.get_rect()),"geometry_size":[dialog.size.x,dialog.size.y],"window_layers":layers.snapshot(),"actual_original_models_fonts":not install.is_empty(),"font":str(dialog.body.get_meta("native_font_applied","engine-default14")),"scope":"Actual conversation/native frame/desktop canvas + NativeWindowLayers, delayed skin activation, actual Window settings and parent transforms; optional installed source model/font metrics, no pixel/native-client comparison.","serverConnections":0,"gpuDraws":0,"fixtureTextAuthored":true}
	layers.close();layers.free()
	if install.is_empty():skin.closed=true
	else:skin.close()
	skin.free()
	if is_instance_valid(actual_painter):actual_painter.close();actual_painter.free()
	canvas.free();await process_frame
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE_PARITY_CONVERSATION_INTEGRATED ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
