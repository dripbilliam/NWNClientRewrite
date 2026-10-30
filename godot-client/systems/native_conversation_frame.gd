extends Node
# Original programmatic in-game chat dialog, over received reply ownership.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/conversation_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
var ui
var view
var frame
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var stage: Control
var background: TextureRect
var portrait: TextureRect
var name_label: RichTextLabel
var entry_scroll: ScrollContainer
var reply_scroll: ScrollContainer
var entry_bar
var reply_bar
var entry_bar_host: Control
var reply_bar_host: Control
var background_key:=""
var metrics: Array=[]
var speaker_signature: Array=[]
var geometry: Dictionary={}
var flow_count:=0
func configure(owner,catalog,cache_path: String) -> void:
	ui=owner; view=ui.conversation; view.native_skin=self; frame=ui.inventory.frame_skin
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	view.rendered.connect(changed); frame.art.loaded.connect(art_loaded); frame.fonts.loaded.connect(font_loaded)
func _process(_delta: float) -> void:
	if closed: return
	if not requested and view.opened:
		requested=true
		for name in Plan.RESOURCES: jobs[assets.request(name,2002,"actor-model" if name in ["scrollbar_simple","pnl_dialog"] else "mdl-original")]=name
	if not layout_ready or not view.visible: return
	refresh_speaker()
	var measured: Array=[view.body.get_content_height(),view.replies.get_combined_minimum_size().y,maxf(0,view.get_viewport_rect().size.y-view.position.y-4)]
	if measured!=metrics: metrics=measured; reflow(float(measured[0]),float(measured[1]),float(measured[2]))
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	activate()
func control(parent: Control) -> Control:
	var value:=Control.new(); parent.add_child(value); value.mouse_filter=Control.MOUSE_FILTER_IGNORE; return value
func scroll(parent: Control) -> ScrollContainer:
	var value:=ScrollContainer.new(); parent.add_child(value); value.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; value.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; return value
func activate() -> void:
	layout_ready=true; view.window_column.hide(); view.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); view.custom_minimum_size=Vector2(360,258); view.size=view.custom_minimum_size
	stage=control(view); stage.clip_contents=true
	background=TextureRect.new(); stage.add_child(background); background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode=TextureRect.STRETCH_SCALE; background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=TextureRect.new(); stage.add_child(portrait); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	name_label=RichTextLabel.new(); stage.add_child(name_label); Text.style(name_label); name_label.mouse_filter=Control.MOUSE_FILTER_STOP; name_label.gui_input.connect(view._title_input); frame.font_style(name_label,{"AurString_Font":"fnt_galahad14","AurString_ColorR":0.4,"AurString_ColorG":0.7,"AurString_ColorB":1.0})
	entry_scroll=scroll(stage); view.body.reparent(entry_scroll,false); view.body.custom_minimum_size=Vector2(261,0); view.body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; view.body.fit_content=true; view.body.scroll_active=false; frame.font_style(view.body,{"AurString_Font":Plan.FONT})
	view.body.set_meta("native_text_color",Color.WHITE); Text.set_text(view.body,view.entry_rich)
	reply_scroll=scroll(stage); view.replies.reparent(reply_scroll,false); view.replies.custom_minimum_size=Vector2(331,0); view.replies.add_theme_constant_override("separation",0)
	entry_bar_host=control(stage); reply_bar_host=control(stage)
	changed("dialog-replies")
func changed(kind: String) -> void:
	if closed or not layout_ready: return
	if kind in ["dialog-entry","dialog-replies","dialog-selected"]:
		for index in view.replies.get_child_count(): style_reply(index)
	metrics.clear(); refresh_speaker()
func font_loaded(name: String) -> void:
	if name in [Plan.FONT,"fnt_galahad14"]: metrics.clear()
func style_reply(index: int) -> void:
	var button: Button=view.replies.get_child(index); var label: RichTextLabel=button.get_child(0)
	if button.has_meta("native_dialog_number"):
		paint_reply(index,view.serial,button.is_hovered(),button.get_meta("native_dialog_number")); return
	for connection in label.resized.get_connections(): label.resized.disconnect(connection.callable)
	button.custom_minimum_size=Vector2(331,0); button.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); label.position=Vector2(20,0); label.custom_minimum_size=Vector2(311,0); label.size=Vector2(311,0); label.size_flags_horizontal=0; label.fit_content=true; frame.font_style(label,{"AurString_Font":Plan.FONT,"AurString_ColorR":0.4,"AurString_ColorG":0.7,"AurString_ColorB":1.0})
	var number:=Label.new(); button.add_child(number); number.position=Vector2.ZERO; number.size=Vector2(16,20); number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; number.vertical_alignment=VERTICAL_ALIGNMENT_TOP; number.mouse_filter=Control.MOUSE_FILTER_IGNORE; number.text=str(index+1)+"."; frame.font_style(number,{"AurString_Font":Plan.FONT,"AurString_ColorR":0.4,"AurString_ColorG":0.7,"AurString_ColorB":1.0})
	button.set_meta("native_dialog_number",number)
	var bound: int=view.serial
	label.resized.connect(func():if not closed and view.serial==bound and is_instance_valid(button): button.custom_minimum_size.y=maxf(1,label.get_content_height()))
	button.mouse_entered.connect(func():paint_reply(index,bound,true,number))
	button.mouse_exited.connect(func():paint_reply(index,bound,false,number))
	paint_reply(index,bound,false,number)
func paint_reply(index: int,bound: int,hover: bool,number: Label) -> void:
	if closed or view.serial!=bound or index>=view.rows.size() or not is_instance_valid(number): return
	var button: Button=view.replies.get_child(index); var label: RichTextLabel=button.get_child(0); var row: Dictionary=view.rows[index]
	var color: Color=Color.WHITE if hover and not button.disabled or row.get("selected",false) else Plan.COLOR
	label.set_meta("native_text_color",color); number.add_theme_color_override("font_color",color); Text.set_text(label,row.get("rich",{})); button.custom_minimum_size.y=maxf(1,label.get_content_height()); label.modulate.a=1.0 if row.get("available",true) else 0.5
func refresh_speaker() -> void:
	if not layout_ready: return
	var object: Dictionary=ui.text.objects.get(view.speaker_id,{}); var name: String=ui.text.name(null,view.speaker_id); var resource: String=ui.desktop.rules.portrait(object,3) if not object.is_empty() else ""
	if name.is_empty(): name=ui.text.raw({"strRef":0x1445})
	if resource.is_empty(): resource="po_hu_m_99_m"
	var signature: Array=[view.speaker_id,name,resource]
	if speaker_signature==signature: return
	speaker_signature=signature; Text.set_text(name_label,ui.text.rich({"text":name},view.speaker_id)); frame.art.bind_portrait(portrait,resource)
func reflow(entry_height: float,reply_height: float,clearance: float) -> void:
	var result:=Plan.layout(models,definition,Plan.flow(entry_height,reply_height,clearance))
	if not str(result.get("error","")).is_empty(): failure=str(result.error); return
	geometry=result; flow_count+=1; view.custom_minimum_size=result.size; view.size=result.size; stage.size=result.size
	name_label.position=result.name.position; name_label.size=result.name.size; portrait.position=result.portrait.position; portrait.size=result.portrait.size
	entry_scroll.position=result.entry.position; entry_scroll.size=result.entry.size; reply_scroll.position=result.replies.position; reply_scroll.size=result.replies.size
	# The original attaches scrollbars only for overflowing content. In
	# particular, entry-before-replies must never resize a hidden reply rail
	# to the short empty-list span, which is smaller than the model supports.
	if result.flow.entry_scroll:
		if not is_instance_valid(entry_bar):
			entry_bar=Bar.new(); entry_bar_host.add_child(entry_bar); entry_bar.configure(frame,models,result.entry_bar,entry_scroll,14)
		else: entry_bar.relayout(result.entry_bar)
	if result.flow.reply_scroll:
		if not is_instance_valid(reply_bar):
			reply_bar=Bar.new(); reply_bar_host.add_child(reply_bar); reply_bar.configure(frame,models,result.reply_bar,reply_scroll,14)
		else: reply_bar.relayout(result.reply_bar)
	entry_bar_host.visible=bool(result.flow.entry_scroll); reply_bar_host.visible=bool(result.flow.reply_scroll)
	background_key=frame.art.request_model("pnl_dialog","",{},0,"",result.flow.poses); background.position=result.background.position; background.size=result.background.size
	background.visible=frame.art.textures.has(background_key)
	if background.visible: background.texture=frame.art.textures[background_key]
	view._clamp()
func art_loaded(key: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed or not layout_ready or key!=background_key: return
	background.texture=texture; background.show()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"pending":jobs.size(),"reflows":flow_count,"speaker":view.speaker_id,"native_only":true,"full_conversation_parity":false}
func close() -> void:
	if closed: return
	closed=true; jobs.clear(); models.clear()
	for bar in [entry_bar,reply_bar]:
		if is_instance_valid(bar): bar.close()
	if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(assets): assets.close()
func _exit_tree() -> void: close()
