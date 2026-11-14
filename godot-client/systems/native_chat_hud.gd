extends Node
signal context_prepared
# CGuiInGameChatWindow/Prompt source geometry over the received native chat owner.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/chat_hud_layout.gd")
const Prompt=preload("res://systems/native_data/chat_prompt.gd")
const Text=preload("res://systems/server_text.gd")
const Scrollbar=preload("res://systems/native_scrollbar.gd")
const Preferences=preload("res://systems/native_data/chat_preferences.gd")
const Options=preload("res://systems/native_chat_options.gd")
const Backdrop=preload("res://systems/native_chat_backdrop.gd")
const Categories=preload("res://systems/native_data/chat_categories.gd")
const Reply=preload("res://systems/native_data/chat_reply.gd")
const ReplyLayout=preload("res://systems/native_data/chat_reply_layout.gd")
const ReplyButton=preload("res://systems/native_chat_reply_button.gd")
var owner_ui
var panel
var frame
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var stage: Control
var panes: Array=[]
var mode_button: Button
var mode_label: Label
var popup: Control
var popup_background: TextureRect
var mode_options: Array=[]
var prompt_background: TextureRect
var entry_clip: Control
var notice: Label
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var mode:=2
var split:=false
var heights: Array=[134.0,134.0]
var expanded: Array=[134.0,134.0]
var drag: Dictionary={}
var storage:=""
var revision:=-1
var epoch:=0
var scroll_restore: Array=[]
var preferences: Dictionary=Preferences.DEFAULTS.duplicate()
var options_window
var context
var context_pane:=-1
var context_epoch:=-1
var admitted: Array=[{},{}]
var reply_plan: Dictionary={}
var rendering_history:=false
var chat_activation_probe:=OS.get_cmdline_user_args().has("--nwn62-chat-activation-phases")
var activation_probe_active:=false
var activation_history_us:=0
var activation_history_calls:=0
var static_art_keys: Array[String]=[]
var art_pending:=true
var art_error:=""
var art_notice: Label
func configure(ui,catalog,cache_path: String,layout: String) -> void:
	owner_ui=ui; panel=ui.chat; panel.native_skin=self; frame=ui.inventory.frame_skin; storage=layout
	preferences=Preferences.load_settings(storage); split=bool(preferences.split); panel.history_limit=int(preferences.history)
	options_window=Options.acquire(panel.get_viewport(),storage); options_window.settings_changed.connect(apply_preferences); options_window.latest_requested.connect(jump_latest)
	options_window.original_requested.connect(original_preset)
	frame.fonts.loaded.connect(font_loaded)
	var saved:=ConfigFile.new()
	if not storage.is_empty() and saved.load(storage)==OK:
		split=bool(saved.get_value("chat-hud","split",false))
		for index in 2: heights[index]=float(saved.get_value("chat-hud","height%d"%index,134.0)); expanded[index]=heights[index]
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	art_notice=Label.new(); panel.add_child(art_notice); art_notice.position=Vector2(80,24); art_notice.size=Vector2(600,48); art_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; art_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; art_notice.hide()
	request_models()
	request_static_art()
	panel.get_viewport().size_changed.connect(place)
	panel.entry.focus_entered.connect(focused.bind(true)); panel.entry.focus_exited.connect(focused.bind(false)); panel.entry.gui_input.connect(entry_input)
	panel.get_child(0).hide()
func _process(_delta: float) -> void:
	if closed: return
	if art_pending:admit_art()
	if layout_ready and revision!=int(owner_ui.text.revision): refresh_modes()
func request_models() -> void:
	if requested or closed:return
	requested=true
	for name in Plan.RESOURCES:
		var id: int=assets.request(name,2002,"actor-model" if name in ["scrollbar_simple","but_chat_reply"] else "mdl-original")
		if id<0:failure=str(assets.failure);return
		jobs[id]=name
func request_static_art() -> void:
	if closed or not is_instance_valid(frame) or not is_instance_valid(frame.art):return
	for name in ["ctl_lst_chatmode","but_chat_bar360","but_chat_bar720"]:static_art_keys.append(frame.art.request_model(name,""))
	for clip in ["up","hilite","down"]:static_art_keys.append(frame.art.request_model("ctl_btn_chatmode",clip))
	for name in ["pb_scrl_up","pb_scrl_down"]:
		for clip in ["up","hilite","down"]:static_art_keys.append(frame.art.request_model(name,clip))
	static_art_keys.append(frame.art.request_model("pnl_chat_prompt","",{},0,"",[],Rect2(0,-20,2040,23)))
	for name in ["edit_chat_left","edit_chat_right","edit_chat_main"]:
		static_art_keys.append(frame.art.request_model(name,"",{},0,"",[],Rect2(0,-10,720.0 if name=="edit_chat_main" else 360.0,2048)))
	frame.fonts.request(Plan.FONT)
	frame.fonts.request("ttf fnt_default %d"%int(preferences.font_size))
func art_snapshot() -> Dictionary:
	var result:={"ready":false,"models_expected":Plan.RESOURCES.size(),"models_ready":models.size(),"images_expected":0,"images_ready":0,"fonts_expected":0,"fonts_ready":0,"pending":[],"failures":[]}
	if not failure.is_empty():result.failures.append(failure)
	if not is_instance_valid(frame) or not is_instance_valid(frame.art):result.failures.append("Original chat artwork owner is unavailable");return result
	for key in static_art_keys:
		result.images_expected+=1
		if key.is_empty():result.failures.append("Original chat artwork could not be requested")
		elif frame.art.textures.has(key):result.images_ready+=1
		elif frame.art.failed.has(key):result.failures.append("Chat artwork "+key+": "+str(frame.art.failed[key]))
		else:result.pending.append("image:"+key)
	if not layout_ready:
		if result.failures.is_empty():result.pending.append("Original chat layout")
		return result
	if models.size()!=Plan.RESOURCES.size():result.failures.append("Original chat model cohort is incomplete")
	for control in [panel.entry,mode_label,notice]+mode_options:
		result.fonts_expected+=1
		if str(control.get_meta("native_font_applied",""))==Plan.FONT:result.fonts_ready+=1
		elif frame.fonts.failed.has(Plan.FONT):result.failures.append("Chat font: "+str(frame.fonts.failed[Plan.FONT]))
		else:result.pending.append("font:"+Plan.FONT)
	var message_font: String="ttf fnt_default %d"%int(preferences.font_size)
	for pane in panes:
		result.fonts_expected+=1
		if str(pane.label.get_meta("native_font_applied",""))==message_font:result.fonts_ready+=1
		elif frame.fonts.failed.has(message_font):result.failures.append("Chat message font: "+str(frame.fonts.failed[message_font]))
		else:result.pending.append("font:"+message_font)
	for background in [prompt_background]+panes.map(func(pane):return pane.background):
		result.images_expected+=1
		if background.source_texture!=null and background.texture!=null:result.images_ready+=1
		else:result.pending.append("chat-background")
	result.images_expected+=1
	if popup_background.texture!=null:result.images_ready+=1
	else:result.pending.append("chat-mode-popup")
	var button_data: Dictionary=frame.button_geometry.get(mode_button.get_instance_id(),{})
	if button_data.is_empty():result.failures.append("Original chat mode button is unavailable")
	for pair in button_data.get("styles",{}).values():
		result.images_expected+=1
		if pair[0].texture!=null:result.images_ready+=1
		else:result.pending.append("chat-mode-button")
	for pane in panes:
		result.images_expected+=1
		if pane.handle_image.texture!=null:result.images_ready+=1
		else:result.pending.append("chat-handle")
		if pane.container.visible:
			if not str(pane.bar.failure).is_empty():result.failures.append("Chat scrollbar: "+str(pane.bar.failure))
			elif not pane.bar.art_ready:result.pending.append("chat-scrollbar")
			for arrow in [pane.bar.up,pane.bar.down]:
				var arrow_data: Dictionary=frame.button_geometry.get(arrow.get_instance_id(),{}) if is_instance_valid(arrow) else {}
				if arrow_data.is_empty():result.failures.append("Original chat scrollbar button is unavailable");continue
				for pair in arrow_data.styles.values():
					result.images_expected+=1
					if pair[0].texture!=null:result.images_ready+=1
					else:result.pending.append("chat-scrollbar-button")
	result.ready=result.failures.is_empty() and result.pending.is_empty() and result.models_ready==result.models_expected
	return result
func admit_art() -> void:
	var snapshot: Dictionary=art_snapshot()
	if snapshot.ready:
		art_pending=false;art_error="";art_notice.hide();stage.show()
	elif not snapshot.failures.is_empty():
		art_pending=false;art_error=str(snapshot.failures[0]);art_notice.text="Chat art unavailable: "+art_error;art_notice.show()
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if jobs.is_empty() and failure.is_empty(): activate()
func image(resource: String,parent: Control) -> TextureRect:
	var target:=TextureRect.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_SCALE; return target
func activate() -> void:
	var activation_started:=Time.get_ticks_usec() if chat_activation_probe else 0
	var phase_started:=activation_started
	var phases: Dictionary={}
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	reply_plan=ReplyLayout.parse(models.but_chat_reply)
	if not str(reply_plan.error).is_empty(): failure=str(reply_plan.error); return
	if chat_activation_probe:
		phases.parse_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
		activation_probe_active=true;activation_history_us=0;activation_history_calls=0
	var bind_started:=0
	var direct_bind_us:=0
	layout_ready=true; panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.custom_minimum_size=Vector2.ZERO
	if chat_activation_probe:phases.layout_setup_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	context=preload("res://systems/server_radial.gd").new()
	if chat_activation_probe:phases.context_new_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	panel.add_child(context)
	if chat_activation_probe:
		phases.context_add_us=Time.get_ticks_usec()-phase_started
		phases.context_create_us=phases.context_new_us+phases.context_add_us;phase_started=Time.get_ticks_usec()
	context.configure_art(frame.art); context.configure_text(frame.fonts); context.request.connect(context_request)
	if chat_activation_probe:phases.context_bind_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	stage=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.hide()
	if chat_activation_probe:
		phases.stage_create_us=Time.get_ticks_usec()-phase_started
		phases.context_stage_us=phases.layout_setup_us+phases.context_create_us+phases.context_bind_us+phases.stage_create_us
		phase_started=Time.get_ticks_usec();phases.pane_us=[]
	for index in 2:
		var container:=Control.new(); stage.add_child(container); container.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var background:=Backdrop.new(); container.add_child(background); var handle:=Control.new(); container.add_child(handle); handle.mouse_filter=Control.MOUSE_FILTER_STOP; handle.mouse_default_cursor_shape=Control.CURSOR_VSIZE; handle.gui_input.connect(handle_input.bind(index))
		var handle_image:=NinePatchRect.new(); handle.add_child(handle_image); handle_image.mouse_filter=Control.MOUSE_FILTER_IGNORE; handle_image.patch_margin_left=12; handle_image.patch_margin_right=12
		var scroll:=ScrollContainer.new(); container.add_child(scroll); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.mouse_filter=Control.MOUSE_FILTER_STOP; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
		var body:=Control.new(); scroll.add_child(body); body.mouse_filter=Control.MOUSE_FILTER_PASS; body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var label: RichTextLabel=panel.messages if index==0 else panel.system_messages
		label.reparent(body,false); label.fit_content=true; label.scroll_active=false; label.custom_minimum_size=Vector2.ZERO; label.mouse_filter=Control.MOUSE_FILTER_PASS; label.selection_enabled=true; label.context_menu_enabled=false; label.add_theme_constant_override("outline_size",0)
		if chat_activation_probe:bind_started=Time.get_ticks_usec()
		frame.fonts.bind(label,Plan.FONT)
		if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
		label.gui_input.connect(pane_input.bind(index)); scroll.gui_input.connect(pane_input.bind(index))
		label.minimum_size_changed.connect(sync_content.bind(index))
		var bar:=Scrollbar.new(); container.add_child(bar)
		var grip:=Control.new(); container.add_child(grip); grip.size=Vector2(12,12); grip.mouse_default_cursor_shape=Control.CURSOR_HSIZE; grip.gui_input.connect(width_input.bind(index))
		panes.append({"container":container,"background":background,"handle":handle,"handle_image":handle_image,"scroll":scroll,"body":body,"label":label,"replies":{},"wanted_replies":{},"bar":bar,"grip":grip,"resource":"","background_resource":"","handle_resource":""})
		if chat_activation_probe:phases.pane_us.append(Time.get_ticks_usec()-phase_started);phase_started=Time.get_ticks_usec()
	prompt_background=Backdrop.new(); stage.add_child(prompt_background)
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	prompt_background.configure(frame.art,"pnl_chat_prompt",Rect2(0,-20,2040,23))
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	entry_clip=Control.new(); stage.add_child(entry_clip); entry_clip.clip_contents=true; entry_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.entry.reparent(entry_clip,false); panel.entry.placeholder_text=""; panel.entry.max_length=0; panel.entry.custom_minimum_size=Vector2.ZERO; panel.entry.add_theme_font_size_override("font_size",14)
	for state in ["normal","focus","read_only"]: panel.entry.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	frame.fonts.bind(panel.entry,Plan.FONT)
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	panel.entry.minimum_size_changed.connect(place_entry)
	if chat_activation_probe:phases.prompt_entry_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	mode_button=Button.new(); stage.add_child(mode_button); var rect: Rect2=definition.models.ctl_btn_chatmode.bounds
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	frame.button(mode_button,{"resource":"ctl_btn_chatmode","rect":rect,"offset":Vector2.ZERO},stage,models,false)
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	mode_button.pressed.connect(toggle_modes)
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	mode_label=frame.button_caption(mode_button,"",14)
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	frame.fonts.bind(mode_label,Plan.FONT)
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	mode_label.modulate.a=0.65
	popup=Control.new(); stage.add_child(popup); popup.mouse_filter=Control.MOUSE_FILTER_IGNORE; popup.hide()
	popup_background=image("",popup); var popup_rect: Rect2=definition.models.ctl_lst_chatmode.bounds; popup_background.position=popup_rect.position; popup_background.size=popup_rect.size
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	frame.art.bind(popup_background,"ctl_lst_chatmode","texture",true,"")
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	var lo: Vector2=definition.models.ctl_lst_chatmode.hooks.text0; var hi: Vector2=definition.models.ctl_lst_chatmode.hooks.text1
	for index in Prompt.MODES.size():
		var option:=Button.new(); popup.add_child(option); option.focus_mode=Control.FOCUS_NONE; option.position=Vector2(lo.x,lo.y+index*17); option.size=Vector2(hi.x-lo.x,17)
		for state in ["normal","hover","pressed","disabled","focus"]: option.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		if chat_activation_probe:bind_started=Time.get_ticks_usec()
		frame.fonts.bind(option,Plan.FONT)
		if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
		option.alignment=HORIZONTAL_ALIGNMENT_LEFT; option.pressed.connect(select_mode.bind(index)); mode_options.append(option)
	notice=Label.new(); stage.add_child(notice); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if chat_activation_probe:bind_started=Time.get_ticks_usec()
	frame.fonts.bind(notice,Plan.FONT)
	if chat_activation_probe:direct_bind_us+=Time.get_ticks_usec()-bind_started
	notice.add_theme_color_override("font_color",Color(1,0.8,0.3)); notice.hide()
	panel.set_meta("native_window_omit_body",true)
	var regions: Array=[weakref(prompt_background),weakref(entry_clip),weakref(mode_button),weakref(popup_background)]
	for pane in panes:
		for control in [pane.background,pane.handle,pane.scroll,pane.grip]: regions.append(weakref(control))
	panel.set_meta("native_window_extras",regions)
	if chat_activation_probe:
		phases.mode_popup_meta_us=Time.get_ticks_usec()-phase_started
		phases.construct_bind_us=phases.context_stage_us+phases.pane_us[0]+phases.pane_us[1]+phases.prompt_entry_us+phases.mode_popup_meta_us
		phases.direct_bind_us=direct_bind_us;phase_started=Time.get_ticks_usec()
	refresh_modes()
	if chat_activation_probe:phases.refresh_modes_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	apply_message_font()
	if chat_activation_probe:phases.font_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	place()
	if chat_activation_probe:phases.place_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	rebuild_admission()
	if chat_activation_probe:phases.admission_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	render_history()
	if chat_activation_probe:phases.final_history_call_us=Time.get_ticks_usec()-phase_started;phase_started=Time.get_ticks_usec()
	context_prepared.emit()
	if chat_activation_probe:
		phases.notify_us=Time.get_ticks_usec()-phase_started
		phases.history_all_us=activation_history_us;phases.history_calls=activation_history_calls
		phases.total_us=Time.get_ticks_usec()-activation_started
		phases.rows=panel.rows.size();phases.panes=panes.size();phases.models=models.size()
		activation_probe_active=false
		print("NWN62_CHAT_ACTIVATION_PHASES ",JSON.stringify(phases))
func refresh_modes() -> void:
	if not layout_ready or closed: return
	revision=int(owner_ui.text.revision)
	for index in mode_options.size(): mode_options[index].text=owner_ui.text.raw({"strRef":int(Prompt.MODES[index].ref)})
	mode_label.text=owner_ui.text.raw({"strRef":int(Prompt.MODES[mode].ref)})+":"
	if is_instance_valid(context) and context.active and not context.pending: fill_context()
func set_split(value: bool) -> void:
	if closed or split==value: return
	split=value
	preferences.split=value
	preferences.mask_combined=Categories.ALL; preferences.mask_left=Categories.LEFT; preferences.mask_right=Categories.RIGHT
	if is_instance_valid(context): context.reset()
	for pane in panes: pane.resource="" # Reconfigure original edit/rail hooks.
	rebuild_admission(); place(); render_history(); save(); options_window.reflect(preferences)
func place() -> void:
	if not layout_ready or closed or not panel.get_parent() is Control: return
	var inverse: Transform2D=panel.get_parent().get_global_transform_with_canvas().affine_inverse(); var viewport: Rect2=panel.get_viewport_rect(); var lo: Vector2=inverse*viewport.position; var hi: Vector2=inverse*viewport.end; var extent:=hi-lo
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); panel.position=lo; panel.size=extent; stage.size=extent
	var offset_x:=clampf(float(preferences.x),0,maxf(0,extent.x-minf(float(preferences.width),extent.x))); var offset_bottom:=clampf(float(preferences.bottom),0,maxf(0,extent.y-67))
	var prompt:=Vector2(offset_x,extent.y-36-offset_bottom)
	var prompt_width:=minf(float(preferences.width),extent.x-offset_x) if preferences.compact_prompt else extent.x-offset_x
	prompt_background.position=prompt+Vector2(0,-20); prompt_background.resize_background(Vector2(prompt_width,23))
	var entry: Rect2=Rect2(definition.models.edit_chat_prompt.hooks.text0,definition.models.edit_chat_prompt.hooks.text1-definition.models.edit_chat_prompt.hooks.text0); entry.position+=prompt; entry.size.x=minf(entry.size.x,maxf(1,prompt_width-definition.models.edit_chat_prompt.hooks.text0.x)); entry_clip.position=entry.position; entry_clip.size=entry.size; place_entry()
	var mode_rect: Rect2=definition.models.ctl_btn_chatmode.bounds; mode_rect.position+=prompt; mode_button.position=mode_rect.position; mode_button.size=mode_rect.size
	frame.button_geometry[mode_button.get_instance_id()].offset=prompt; frame.button_geometry[mode_button.get_instance_id()].rect=mode_rect
	popup.position=prompt; notice.position=Vector2(80,maxf(0,prompt.y-38))
	var total_width:=minf(float(preferences.width),extent.x)
	var reflow:=false
	for index in 2:
		var pane: Dictionary=panes[index]; pane.container.visible=index==0 or split
		heights[index]=clampf(float(heights[index]),67,maxf(67,extent.y-offset_bottom)); var plan:=Plan.pane(definition,index==1,not split,float(heights[index])); var pane_width:=total_width*0.5 if split else total_width
		var shift:=pane_width-float(plan.width); plan.model.hooks.scrollmin.x+=shift; plan.model.hooks.scrollmax.x+=shift; plan.model.hooks.text1.x+=shift; plan.rect.size.x+=shift; plan.width=pane_width; plan.handle.size.x+=shift
		pane.container.position=Vector2(offset_x+(pane_width if index==1 else 0),extent.y-heights[index]-offset_bottom); pane.grip.position=Vector2(pane_width-12,0); pane.grip.visible=not bool(preferences.locked); pane.handle.mouse_default_cursor_shape=Control.CURSOR_ARROW if preferences.locked else Control.CURSOR_VSIZE
		pane.handle.position=plan.handle.position; pane.handle.size=plan.handle.size; pane.handle_image.position=Vector2.ZERO; pane.handle_image.size=plan.handle.size
		if pane.handle_resource!=plan.bar: pane.handle_resource=plan.bar; frame.art.bind(pane.handle_image,plan.bar,"texture",true,"")
		pane.background.position=Vector2(0,2); pane.background.visible=heights[index]>67; pane.background.modulate.a=float(preferences.opacity)
		if pane.background_resource!=plan.resource:
			pane.background.close(); pane.background_resource=plan.resource; var source_width:=720.0 if plan.resource=="edit_chat_main" else 360.0; pane.background.configure(frame.art,plan.resource,Rect2(0,-10,source_width,2048))
		pane.background.resize_background(Vector2(pane_width,maxf(1,float(heights[index])-58)))
		var rect: Rect2=plan.rect; rect.size.y=maxf(1,rect.size.y); pane.scroll.position=Vector2(0,rect.position.y); pane.scroll.size=Vector2(rect.end.x,rect.size.y); pane.scroll.visible=heights[index]>67
		reflow=reflow or not is_equal_approx(pane.label.size.x,maxf(1,rect.size.x)); pane.body.custom_minimum_size.x=rect.end.x; pane.label.position=Vector2(rect.position.x,0); pane.label.custom_minimum_size.x=maxf(1,rect.size.x); pane.label.size.x=maxf(1,rect.size.x)
		if pane.resource!=plan.resource:
			pane.bar.close(); pane.bar.queue_free(); pane.bar=Scrollbar.new(); pane.container.add_child(pane.bar); pane.bar.configure(frame,models,plan,pane.scroll,14); pane.resource=plan.resource
		else: pane.bar.relayout(plan)
		pane.bar.visible=heights[index]>67
	prompt_background.modulate.a=float(preferences.opacity)
	if reflow: render_history()
func render_history() -> void:
	if not layout_ready or closed or rendering_history: return
	var activation_history_started:=Time.get_ticks_usec() if chat_activation_probe and activation_probe_active else 0
	rendering_history=true
	var following: Array=[]; var positions: Array=[]
	for pane in panes:
		var range_control: VScrollBar=pane.scroll.get_v_scroll_bar(); following.append(range_control.value>=range_control.max_value-range_control.page-1)
		positions.append(range_control.value)
		pane.label.clear()
		pane.wanted_replies={}
	var retained: Dictionary={}
	for row in panel.rows: retained[int(row.chat_sequence)]=true
	for accepted in admitted:
		for serial in accepted.keys():
			if not retained.has(serial): accepted.erase(serial)
	for row in panel.rows:
		if not Preferences.visible(row,preferences): continue
		for index in (2 if split else 1):
			if not admitted[index].has(int(row.chat_sequence)): continue
			var label: RichTextLabel=panes[index].label; var name: Dictionary=row.get("name",{})
			var first_character:=label.get_total_character_count(); var first_line:=maxi(0,label.get_line_count()-1)
			if preferences.timestamps and not str(row.get("received_at","")).is_empty(): Text.append(label,{"text":"["+(str(row.received_at) if preferences.seconds else str(row.received_at).left(5))+"] "},Color(0.55,0.55,0.55))
			if not str(name.get("text","")).is_empty() or row.get("nativeNameResolved")==true and not row.get("system",false): Text.append(label,name,Color(0.65,0.65,1)); Text.append(label,{"text":": "})
			var color:=str(row.get("color","")); var fallback:=Color.html(color) if color.length()==7 and color.begins_with("#") and color.substr(1).is_valid_hex_number(false) else Color(0.9,0.88,0.78)
			Text.append(label,row.get("rich",{"text":row.get("text","")}),fallback); Text.append(label,{"text":"\n"})
			if row.get("reply") is Dictionary:
				# Original879080 reserves two text lines for an attached portrait.
				if label.get_line_count()-1-first_line<2: Text.append(label,{"text":"\n"})
				# Smaller user-selected text must still leave the unscaled source
				# portrait above the next row; extra whole lines avoid overlap.
				var required: float=label.get_theme_font("normal_font").get_ascent(int(preferences.font_size))+reply_plan.bounds.end.y
				for padding in 8:
					if label.get_line_offset(label.get_line_count()-1)-label.get_line_offset(first_line)>=required: break
					Text.append(label,{"text":"\n"})
				var serial:=int(row.chat_sequence); var pane: Dictionary=panes[index]; pane.wanted_replies[serial]=true
				if not pane.replies.has(serial):
					var button:=ReplyButton.new(); pane.body.add_child(button); button.configure(reply_plan,frame.art,str(row.reply.get("portrait",""))); button.button_down.connect(capture_reply.bind(index,serial)); button.pressed.connect(reply_clicked.bind(index,serial,epoch)); pane.replies[serial]={"button":button,"row":row,"character":first_character}
					button.tooltip_provider=reply_tooltip.bind(index,serial,epoch)
				pane.replies[serial].character=first_character
	rendering_history=false
	for index in 2:
		var pane: Dictionary=panes[index]
		for serial in pane.replies.keys():
			if not pane.wanted_replies.has(serial): pane.replies[serial].button.close(); pane.replies[serial].button.queue_free(); pane.replies.erase(serial)
		sync_content(index)
	# Coalesce same-frame bursts around the first reader anchor, then restore
	# after the container has recalculated the new received text height.
	if scroll_restore.is_empty(): scroll_restore=[following.map(func(value):return bool(value) and bool(preferences.autoscroll)),positions]
	if not get_tree().process_frame.is_connected(restore_scroll): get_tree().process_frame.connect(restore_scroll,CONNECT_ONE_SHOT)
	if chat_activation_probe and activation_probe_active:activation_history_us+=Time.get_ticks_usec()-activation_history_started;activation_history_calls+=1
func sync_content(index: int) -> void:
	if closed or rendering_history or index>=panes.size(): return
	var pane: Dictionary=panes[index]; var label: RichTextLabel=pane.label
	pane.body.custom_minimum_size.y=label.get_combined_minimum_size().y
	var baseline:=label.get_theme_font("normal_font").get_ascent(int(preferences.font_size))
	for record in pane.replies.values():
		var line:=label.get_character_line(int(record.character))
		if line<0: record.button.hide(); continue
		record.button.show(); record.button.position=Vector2(label.position.x+reply_plan.bounds.position.x,label.get_line_offset(line)+baseline+reply_plan.bounds.position.y)
func player_roster() -> Array:
	return owner_ui.desktop.state.get("players",[]) if is_instance_valid(owner_ui.desktop) else []
func interaction_scope() -> Array:
	return [owner_ui.desktop.generation,owner_ui.desktop.area_id,owner_ui.desktop.actor_id] if is_instance_valid(owner_ui.desktop) else []
func reply_tooltip(index: int,serial: int,owned_epoch: int) -> String:
	if closed or owned_epoch!=epoch or not owner_ui.presentation_enabled or not panel.is_visible_in_tree() or index>=panes.size() or not panes[index].replies.has(serial) or not is_instance_valid(owner_ui.desktop): return ""
	var row: Dictionary=panes[index].replies[serial].row; var player:=Reply.player(player_roster(),int(row.reply.get("player_id",Reply.NO_PLAYER)))
	if player.is_empty(): return ""
	var target:=int(player.get("objectId",Reply.INVALID))
	return owner_ui.desktop.party_details.tooltip(target,owner_ui.desktop.state.get("module",{}))
func capture_reply(index: int,serial: int) -> void:
	if closed or not owner_ui.presentation_enabled or not panel.is_visible_in_tree() or index>=panes.size() or not panes[index].replies.has(serial): return
	panes[index].replies[serial].held_scope=interaction_scope()
func reply_clicked(index: int,serial: int,owned_epoch: int) -> void:
	if closed or owned_epoch!=epoch or not owner_ui.presentation_enabled or not panel.is_visible_in_tree() or index>=panes.size() or not panes[index].replies.has(serial): return
	var record: Dictionary=panes[index].replies[serial]; var held: Array=record.get("held_scope",[]); record.erase("held_scope")
	if held.is_empty() or held!=interaction_scope(): return
	var id:=int(record.row.reply.get("player_id",Reply.NO_PLAYER)); var player:=Reply.player(player_roster(),id)
	if player.is_empty(): return
	panel.request.emit({"kind":"native-panel","panel":"chat-reply","open":true,"playerId":id,"targetId":int(player.get("objectId",Reply.INVALID))})
	prime_player(str(player.get("name","")))
func admit(row: Dictionary) -> void:
	for index in 2:
		if Categories.bits(row)&Categories.mask(preferences,index): admitted[index][int(row.chat_sequence)]=true
func rebuild_admission() -> void:
	admitted=[{},{}]
	for row in panel.rows: admit(row)
func receive_row(row: Dictionary) -> void:
	if closed or not layout_ready: return
	admit(row); render_history()
func pane_input(event: InputEvent,index: int) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		open_context(index,event.global_position); panes[index].scroll.accept_event()
func open_context(index: int,point: Vector2) -> void:
	if closed or not layout_ready or not owner_ui.presentation_enabled or not panel.is_visible_in_tree() or index not in [0,1] or index==1 and not split: return
	context_pane=index; context_epoch=epoch; context.open_at(point,2130706432,Vector3.ZERO,false); fill_context()
func fill_context() -> void:
	if closed or not is_instance_valid(context) or not context.active: return
	var entries:=Categories.menu(owner_ui.text,preferences,context_pane)
	context.receive({"kind":"action-menu","requestId":context.request_id,"menuId":context.request_id,"depth":0,"title":owner_ui.text.raw({"strRef":66754}),"entries":entries}); context.set_center("ir_chat")
	for row in entries: frame.art.bind(context.icons[int(row.slot)],str(row.icon))
func context_request(message: Dictionary) -> void:
	if closed or not is_instance_valid(context) or not context.active or not owner_ui.presentation_enabled or not panel.is_visible_in_tree() or context_epoch!=epoch or int(message.get("requestId",-1))!=context.request_id: return
	if message.kind=="radial-cancel": context.reset(); return
	if message.kind!="radial-select" or int(message.get("menuId",-1))!=context.menu_id: return
	var slot:=int(message.get("slot",-1)); var entries:=Categories.menu(owner_ui.text,preferences,context_pane)
	for row in entries:
		if int(row.slot)!=slot: continue
		context.reset()
		if slot==0: set_split(not split)
		else:
			var key: String="mask_right" if context_pane==1 else "mask_left" if split else "mask_combined"
			preferences[key]=int(preferences[key])^int(row.bit); save(); options_window.reflect(preferences)
		return
func place_entry() -> void:
	if closed or not is_instance_valid(entry_clip): return
	# Preserve font pixels when the engine edit's intrinsic height exceeds the
	# original16px text region; clip and center, never scale the glyphs.
	panel.entry.size=Vector2(entry_clip.size.x,maxf(entry_clip.size.y,panel.entry.get_combined_minimum_size().y))
	panel.entry.position=Vector2(0,(entry_clip.size.y-panel.entry.size.y)*0.5)
func restore_scroll() -> void:
	var restore: Array=scroll_restore; scroll_restore=[]
	if closed or restore.is_empty(): return
	for index in 2:
		var range_control: VScrollBar=panes[index].scroll.get_v_scroll_bar(); range_control.value=range_control.max_value if bool(restore[0][index]) else float(restore[1][index])
func select_mode(index: int) -> void:
	if closed or index<0 or index>=Prompt.MODES.size(): return
	mode=index; popup.hide(); refresh_modes()
func toggle_modes() -> void:
	if closed: return
	popup.visible=not popup.visible
func focused(active: bool) -> void:
	if closed or not owner_ui.presentation_enabled: return
	panel.request.emit({"kind":"native-panel","panel":"chat-focus","open":active,"mode":mode})
func submit(value: String) -> void:
	if closed or not owner_ui.presentation_enabled: return
	var message:=Prompt.dispatch(value,mode,player_roster(),owner_ui.text)
	# Original87b0d0 clears/releases before dispatch for every submitted line.
	panel.entry.clear(); panel.entry.release_focus()
	if message.has("error") or message.has("error_ref"):
		if message.has("error_ref"):
			# Original87b0d0 clears/releases the prompt before dispatch; missing
			# account lookup queues local combat feedback106/TLK61899.
			var rich:=preload("res://systems/native_data/rich_text.gd").parse(owner_ui.text.raw({"strRef":int(message.error_ref)}))
			panel.append_message({"system":true,"category":"combat-feedback","color":"#ffff01","rich":rich,"text":rich.text})
			if is_instance_valid(notice): notice.hide()
			return
		if is_instance_valid(notice): notice.text=str(message.error); notice.show()
		return
	if is_instance_valid(notice): notice.hide()
	if not message.is_empty(): panel.request.emit(message)
func prime_tell(name: String) -> void:
	if closed or not owner_ui.presentation_enabled: return
	var was_focused: bool=panel.entry.has_focus(); panel.entry.text='/t "'+name+'" '; panel.entry.grab_focus(); panel.entry.caret_column=panel.entry.text.length()
	if was_focused: focused(true)
func prime_player(account: String) -> void:
	if closed or not owner_ui.presentation_enabled: return
	var was_focused: bool=panel.entry.has_focus(); panel.entry.text='/tp "'+account+'" '; panel.entry.grab_focus(); panel.entry.caret_column=panel.entry.text.length()
	if was_focused: focused(true)
func entry_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		panel.entry.clear(); panel.entry.release_focus()
		if is_instance_valid(popup): popup.hide()
		panel.entry.accept_event()
func handle_input(event: InputEvent,index: int) -> void:
	if closed: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if event.shift_pressed: open_settings()
		else: open_context(index,event.global_position)
		panes[index].handle.accept_event(); return
	if preferences.locked: return
	var control: Control=panes[index].handle
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.alt_pressed: drag={"kind":"move","index":index,"x":event.global_position.x,"y":event.global_position.y,"left":preferences.x,"bottom":preferences.bottom,"moved":true}
			else: drag={"kind":"height","index":index,"y":event.global_position.y,"height":heights[index],"moved":false}
		elif not drag.is_empty() and int(drag.index)==index:
			if not drag.moved: heights[index]=float(expanded[index]) if heights[index]<=67.1 else 67.0; place()
			drag.clear(); save(); options_window.reflect(preferences)
		control.accept_event()
	elif event is InputEventMouseMotion and not drag.is_empty() and int(drag.index)==index:
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT: drag.clear(); return
		var scale_y: float=control.get_global_transform_with_canvas().get_scale().y
		if drag.get("kind","")=="move":
			var scale_x: float=control.get_global_transform_with_canvas().get_scale().x
			preferences.x=clampi(int(float(drag.left)+(event.global_position.x-float(drag.x))/maxf(0.001,scale_x)),0,maxi(0,int(panel.size.x)-mini(int(preferences.width),int(panel.size.x))))
			preferences.bottom=clampi(int(float(drag.bottom)+(float(drag.y)-event.global_position.y)/maxf(0.001,scale_y)),0,maxi(0,int(panel.size.y)-67))
			place(); control.accept_event(); return
		var delta: float=(float(drag.y)-event.global_position.y)/maxf(0.001,scale_y)
		if absf(delta)>2: drag.moved=true
		heights[index]=clampf(float(drag.height)+delta,67,maxf(67,panel.size.y))
		if heights[index]>67.1: expanded[index]=heights[index]
		place(); control.accept_event()
func width_input(event: InputEvent,index: int) -> void:
	if closed: return
	var control: Control=panes[index].grip
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: open_settings(); control.accept_event(); return
	if preferences.locked: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: drag={"kind":"width","index":index,"x":event.global_position.x,"width":preferences.width}
		else: drag.clear(); save(); options_window.reflect(preferences)
		control.accept_event()
	elif event is InputEventMouseMotion and drag.get("kind","")=="width":
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT: drag.clear(); return
		var factor:=2.0 if split and int(drag.index)==0 else 1.0
		var scale_x: float=control.get_global_transform_with_canvas().get_scale().x
		preferences.width=clampi(int(float(drag.width)+(event.global_position.x-float(drag.x))*factor/maxf(0.001,scale_x)),320,2040)
		place(); control.accept_event()
func open_settings() -> void:
	if not closed: options_window.open_settings()
func apply_preferences(value: Dictionary) -> void:
	if closed: return
	var prior_split:=split
	preferences=Preferences.clean(value); split=bool(preferences.split); panel.history_limit=int(preferences.history); panel.trim_history(); scroll_restore.clear()
	if split!=prior_split:
		preferences.mask_combined=Categories.ALL; preferences.mask_left=Categories.LEFT; preferences.mask_right=Categories.RIGHT; save(); options_window.reflect(preferences)
	drag.clear()
	if is_instance_valid(context): context.reset()
	if layout_ready: rebuild_admission(); apply_message_font(); place(); render_history()
func apply_message_font() -> void:
	if not layout_ready or closed: return
	var name: String="ttf fnt_default %d"%int(preferences.font_size)
	for pane in panes:
		frame.fonts.bind(pane.label,name)
		for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: pane.label.add_theme_font_size_override(key,int(preferences.font_size))
func font_loaded(name: String) -> void:
	if closed or not layout_ready or not name.begins_with("ttf fnt_default "): return
	for pane in panes:
		for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: pane.label.add_theme_font_size_override(key,int(preferences.font_size))
	render_history()
func jump_latest() -> void:
	if closed or not layout_ready: return
	scroll_restore=[[true,true],[0.0,0.0]]
	if not get_tree().process_frame.is_connected(restore_scroll): get_tree().process_frame.connect(restore_scroll,CONNECT_ONE_SHOT)
func original_preset() -> void:
	if closed: return
	heights=[134.0,134.0]; expanded=heights.duplicate(); preferences=Preferences.DEFAULTS.duplicate(); split=false; panel.history_limit=200; panel.trim_history()
	if layout_ready: rebuild_admission(); apply_message_font(); place(); render_history()
	save()
func _input(event: InputEvent) -> void:
	if closed or not layout_ready: return
	if not panel.is_visible_in_tree(): popup.hide(); drag.clear(); context.reset(); return
	if event is InputEventMouseButton and event.pressed and popup.visible and not mode_options.any(func(button):return button.get_global_rect().has_point(event.position)) and not mode_button.get_global_rect().has_point(event.position): popup.hide()
func blocks_pointer(point: Vector2) -> bool:
	if is_instance_valid(options_window) and options_window.is_visible_in_tree() and options_window.get_global_rect().has_point(point): return true
	if not layout_ready or closed or not panel.is_visible_in_tree(): return false
	if context.blocks_pointer(point): return true
	if entry_clip.get_global_rect().has_point(point) or mode_button.get_global_rect().has_point(point): return true
	if popup.visible:
		for button in mode_options:
			if button.get_global_rect().has_point(point): return true
	for pane in panes:
		if not pane.container.visible: continue
		for control in [pane.handle,pane.scroll,pane.bar,pane.grip]:
			if control.visible and control.get_global_rect().has_point(point): return true
	return false
func reset() -> void:
	epoch+=1; drag.clear(); scroll_restore.clear(); mode=2
	admitted=[{},{}]
	if layout_ready: context.reset(); popup.hide(); notice.hide(); refresh_modes(); render_history()
func save() -> void:
	if storage.is_empty(): return
	Preferences.save_settings(storage,preferences)
	var config:=ConfigFile.new(); config.load(storage); config.set_value("chat-hud","split",split)
	for index in 2: config.set_value("chat-hud","height%d"%index,expanded[index])
	config.save(storage)
func close() -> void:
	if closed: return
	closed=true; epoch+=1; drag.clear()
	art_pending=false
	if is_instance_valid(art_notice):art_notice.hide()
	if get_tree()!=null and get_tree().process_frame.is_connected(restore_scroll): get_tree().process_frame.disconnect(restore_scroll)
	scroll_restore.clear()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(panel) and panel.get_viewport()!=null and panel.get_viewport().size_changed.is_connected(place): panel.get_viewport().size_changed.disconnect(place)
	if layout_ready:
		context.reset(); context.visible=false; admitted=[{},{}]
		for label in [context.hint]+context.captions.values(): frame.fonts.unbind(label)
		context.queue_free()
		for pane in panes:
			for record in pane.replies.values(): record.button.close(); record.button.queue_free()
			pane.replies.clear()
			pane.bar.close(); pane.background.close(); frame.art.unbind(pane.handle_image); frame.fonts.unbind(pane.label)
		for control in [panel.entry,mode_label,notice]+mode_options: frame.fonts.unbind(control)
		prompt_background.close(); frame.art.unbind(popup_background)
		for pair in frame.button_geometry.get(mode_button.get_instance_id(),{}).get("styles",{}).values(): frame.art.unbind(pair[0])
		if is_instance_valid(stage): stage.hide()
	jobs.clear(); models={}; definition={}
	if is_instance_valid(options_window):
		if options_window.settings_changed.is_connected(apply_preferences): options_window.settings_changed.disconnect(apply_preferences)
		if options_window.latest_requested.is_connected(jump_latest): options_window.latest_requested.disconnect(jump_latest)
		if options_window.original_requested.is_connected(original_preset): options_window.original_requested.disconnect(original_preset)
	if is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
func _exit_tree() -> void: close()
