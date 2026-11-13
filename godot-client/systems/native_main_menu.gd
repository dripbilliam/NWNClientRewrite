extends CanvasLayer
signal multiplayer_requested
signal options_requested
signal exit_requested
signal disconnect_requested
signal export_requested
signal client_theme_changed(value: Theme)
const MenuAssets=preload("res://systems/native_data/asset_service.gd")
var panel: PanelContainer
var disconnect_button: Button
var client_style
var pending_label: Label
var connection_query: Callable
var playing_query: Callable
var escape_override: Callable
var fallback: VBoxContainer
var fallback_style: StyleBoxFlat
var native_frame
var video_owner
var window_settings
var key_bindings
var key_owner
var observed_bindings
var native_scope: Array=[]
var lobby_state: Dictionary={}
var native_playing:=false
var layout_path:="user://native-menu-layout.cfg"
var retained_position:=Vector2.INF
var dragging:=false
var drag_offset:=Vector2.ZERO
var child_return_scope: Array=[]
var pregame
var pregame_cleanup: Dictionary={}
var menu_audio_assets
var menu_click_player: AudioStreamPlayer
var menu_click_job:=-1
var menu_audio_profile:=""
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
var modal_order
var modal_surfaces
var native_configuration: Dictionary={}
var native_configuration_serial:=0
func set_modal_order(order,surfaces=null) -> void:
	modal_order=order;modal_surfaces=surfaces;modal_lease.configure(self,order,surfaces,self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	if is_instance_valid(native_frame):native_frame.set_modal_order(order,surfaces,self,modal_lease.admits)
	if is_instance_valid(video_owner):video_owner.set_modal_order(order,surfaces,self)
	if is_instance_valid(key_owner):key_owner.set_modal_order(order,surfaces,self)
	if native_playing and is_instance_valid(panel) and panel.visible:modal_lease.activate(native_scope)
func modal_admission_changed(admitted: bool) -> void:
	if not admitted:
		dragging=false
		if is_instance_valid(native_frame):
			native_frame.held.clear()
			for button in native_frame.buttons.values():native_frame.release_button(button)
func modal_input_admitted() -> bool:
	if is_instance_valid(native_frame) and is_instance_valid(native_frame.confirmation) and native_frame.confirmation.visible:return native_frame.confirmation_lease.admits()
	return modal_lease.admits()
func _ready() -> void:
	layer = 30
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(320, 280); root.add_child(panel)
	panel.theme=preload("res://systems/native_client_menu_style.gd").base_theme()
	var style := preload("res://systems/native_client_menu_style.gd").flat(Color("090a08f5"),Color("ac824a"),22); panel.add_theme_stylebox_override("panel", style); fallback_style=style
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); panel.add_child(box); fallback=box
	pending_label=Label.new(); pending_label.text="Preparing menu…"; pending_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(pending_label)
	disconnect_button=Button.new(); disconnect_button.text="Cancel connection"; disconnect_button.focus_mode=Control.FOCUS_NONE; box.add_child(disconnect_button); disconnect_button.pressed.connect(choose.bind("disconnect")); disconnect_button.hide()
	get_viewport().size_changed.connect(place); panel.hide(); call_deferred("place")
func choose(id: String) -> void:
	if not modal_lease.admits():return
	dismiss()
	if id == "multiplayer": multiplayer_requested.emit()
	elif id == "options": options_requested.emit()
	elif id == "exit": exit_requested.emit()
	elif id == "disconnect": disconnect_requested.emit()
	elif id == "export": export_requested.emit()
func open(playing: bool) -> void:
	native_playing=playing
	disconnect_button.visible=connection_query.call() if connection_query.is_valid() else playing
	if not playing and is_instance_valid(pregame):
		if is_instance_valid(native_frame): native_frame.dismiss()
		panel.hide(); pregame.open(); return
	if is_instance_valid(pregame): pregame.dismiss()
	if playing and is_instance_valid(native_frame): native_frame.start(); show_fallback(); update_native()
	else: show_fallback()
	panel.show(); place()
	if playing:modal_lease.activate(native_scope)
func configure_pregame(sources: Dictionary,cache_path: String) -> void:
	close_pregame()
	menu_audio_profile=str(sources.get("profileDirectory",""))
	pregame=preload("res://systems/native_pregame_menu.gd").new(); get_child(0).add_child(pregame); pregame.configure(sources,cache_path,layout_path,window_settings)
	pregame.set_button_audio_status(false)
	pregame.button_sound_requested.connect(play_menu_click)
	pregame.multiplayer_requested.connect(func():choose("multiplayer"))
	pregame.exit_requested.connect(func():choose("exit"))
	pregame.client_settings_requested.connect(func():options_requested.emit())
	pregame.source_ready.connect(func(painter,_text,catalog,cache):
		configure_client_style(painter)
		configure_menu_audio(catalog,cache))
func configure_menu_audio(catalog,cache_path: String) -> void:
	if is_instance_valid(menu_audio_assets):menu_audio_assets.close();menu_audio_assets.queue_free()
	menu_audio_assets=MenuAssets.new();add_child(menu_audio_assets);menu_audio_assets.configure(catalog);menu_audio_assets.cache_directory=cache_path
	menu_audio_assets.completed.connect(menu_audio_ready.bind(menu_audio_assets))
	if not is_instance_valid(menu_click_player):menu_click_player=AudioStreamPlayer.new();menu_click_player.max_polyphony=4;add_child(menu_click_player)
	menu_click_player.stop();menu_click_player.stream=null
	menu_click_job=menu_audio_assets.request("gui_button",4,"wave-native-v1")
	if menu_click_job<0 and is_instance_valid(pregame):pregame.set_button_audio_status(false,menu_audio_assets.failure)
func menu_audio_ready(id: int,result: Dictionary,owner) -> void:
	if owner!=menu_audio_assets or id!=menu_click_job or not is_instance_valid(menu_click_player):return
	menu_click_job=-1
	if not str(result.get("error","")).is_empty():
		if is_instance_valid(pregame):pregame.set_button_audio_status(false,str(result.error))
		return
	var data: Dictionary=result.get("value",{});var bytes: PackedByteArray=result.get("bytes",PackedByteArray())
	var stream: AudioStream
	if data.get("codec","")=="pcm16":
		var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.stereo=int(data.channels)==2;wave.mix_rate=int(data.sampleRate);wave.data=data.pcm;stream=wave
	elif data.get("codec","")=="wav":stream=AudioStreamWAV.load_from_buffer(bytes)
	if stream!=null and stream.get_length()>0:
		menu_click_player.stream=stream
		if is_instance_valid(pregame):pregame.set_button_audio_status(true)
	elif is_instance_valid(pregame):pregame.set_button_audio_status(false,"Original gui_button could not be decoded")
func menu_effect_volume() -> float:
	if menu_audio_profile.is_empty():return 1.0
	var path:=menu_audio_profile.path_join("settings.tml")
	if not FileAccess.file_exists(path):return 1.0
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return 1.0
	var effects:=false
	while not file.eof_reached():
		var line:=file.get_line().strip_edges()
		if line.begins_with("["):effects=line=="[sound.effects]";continue
		if effects and line.begins_with("volume"):
			var parts:=line.split("=",true,1)
			if parts.size()==2 and parts[1].strip_edges().is_valid_float():return clampf(float(parts[1].strip_edges()),0.0,1.0)
	return 1.0
func play_menu_click() -> void:
	if not is_instance_valid(menu_click_player) or menu_click_player.stream==null:return
	var gain:=menu_effect_volume()
	if gain<=0.0:return
	menu_click_player.volume_linear=gain;menu_click_player.play()
func configure_client_style(painter,entry_staged: bool=false) -> void:
	if is_instance_valid(client_style): client_style.close(); client_style.queue_free()
	client_style=preload("res://systems/native_client_menu_style.gd").new(); get_child(0).add_child(client_style)
	client_style.changed.connect(func(value):panel.theme=value; client_theme_changed.emit(value))
	if entry_staged:client_style.begin_entry_publication()
	client_style.configure(painter)
func close_pregame() -> void:
	if is_instance_valid(pregame): pregame.close(); pregame_cleanup=pregame.snapshot(); pregame.queue_free()
	pregame=null
func configure_native(shared_frame,text,catalog,cache_path: String,value: Array) -> void:
	cancel_native_configuration()
	if is_instance_valid(pregame): pregame.dismiss()
	detach_native()
	native_scope=value.duplicate(); native_frame=preload("res://systems/native_entry_menu_frame.gd").new(); panel.add_child(native_frame); native_frame.configure(shared_frame,text,catalog,cache_path)
	native_frame.set_modal_order(modal_order,modal_surfaces,self,modal_lease.admits)
	native_frame.prepared.connect(func():update_native(); place())
	native_frame.artwork_ready.connect(func():update_native(); place())
	native_frame.action_requested.connect(native_action)
	native_frame.title_input.connect(drag_title)
	native_frame.start(); configure_client_style(shared_frame)
	if is_instance_valid(window_settings):
		video_owner=preload("res://systems/native_video_options.gd").new(); get_child(0).add_child(video_owner); video_owner.configure(shared_frame,text,catalog,cache_path,window_settings,layout_path)
		video_owner.set_modal_order(modal_order,modal_surfaces,self)
		video_owner.prepared.connect(update_native); video_owner.artwork_ready.connect(update_native); video_owner.finished.connect(child_closed)
	if is_instance_valid(key_bindings):
		observed_bindings=key_bindings
		if not observed_bindings.changed.is_connected(update_native): observed_bindings.changed.connect(update_native)
		key_owner=preload("res://systems/native_key_settings.gd").new(); get_child(0).add_child(key_owner); key_owner.configure(shared_frame,text,catalog,cache_path,key_bindings,layout_path)
		key_owner.set_modal_order(modal_order,modal_surfaces,self)
		key_owner.prepared.connect(update_native); key_owner.finished.connect(child_closed)
	var saved:=ConfigFile.new()
	if not layout_path.is_empty() and saved.load(layout_path)==OK:
		var position: Variant=saved.get_value("positions","ingame_options",Vector2.INF)
		if position is Vector2 and position.is_finite(): retained_position=position
func begin_native_configuration(shared_frame,text,catalog,cache_path: String,value: Array) -> Dictionary:
	# Entry-only continuation. The public synchronous configure_native keeps its
	# original body and callback ordering for all existing callers.
	cancel_native_configuration();native_configuration_serial+=1
	native_configuration={"serial":native_configuration_serial,"phase":0,"frame":shared_frame,"text":text,"catalog":catalog,"cache":cache_path,"scope":value.duplicate(),"retiring":{},"entry_style":null,"cancelled":false}
	return native_configuration
func native_configuration_current(state: Dictionary) -> bool:
	return not state.is_empty() and is_same(native_configuration,state) and int(state.serial)==native_configuration_serial and not is_queued_for_deletion()
func native_configuration_phase(state: Dictionary) -> String:
	const PHASES=["pregame_dismiss","retire_modal","retire_keys","retire_video","retire_frame","clear_scope","pregame_style","fallback","frame_create","frame_bind","frame_start","client_style_begin","client_style_publish","video","key_binding","keys","layout","complete"]
	var phase:=clampi(int(state.get("phase",0)),0,PHASES.size()-1)
	if phase==13 and state.has("video_entry") and is_instance_valid(video_owner):return "video:"+video_owner.entry_configuration_phase(state.video_entry)
	if phase==15 and state.has("keys_entry") and is_instance_valid(key_owner):return "keys:"+key_owner.entry_configuration_phase(state.keys_entry)
	return PHASES[phase]
func entry_style_publication_receipt() -> Dictionary:
	return client_style.entry_publication_receipt() if is_instance_valid(client_style) and client_style.has_method("entry_publication_receipt") else {}
func native_configuration_retire_owner(state: Dictionary,property: String) -> bool:
	var owner=get(property)
	if not is_instance_valid(owner):return true
	var assets=preload("res://systems/native_data/modal_lease.gd").property(owner,"assets")
	if is_instance_valid(assets):
		var id: int=owner.get_instance_id()
		if not state.retiring.has(id):state.retiring[id]=true;assets.retire_scope()
		# Never turn a pending decoder into a blocking close/join inside entry.
		# The SESSION must yield until another engine frame when this is false.
		for task in assets.running.values():
			if not WorkerThreadPool.is_task_completed(int(task)):return false
	owner.close()
	if not native_configuration_current(state):return true
	if get(property)!=owner:
		cancel_native_configuration(state);return true
	owner.queue_free();set(property,null)
	return true
func native_configuration_step(state: Dictionary) -> Dictionary:
	if not native_configuration_current(state):return {"done":true,"accepted":false}
	var phase:=int(state.phase)
	match phase:
		0:
			if is_instance_valid(pregame):pregame.dismiss()
		1:
			modal_lease.retire();child_return_scope.clear()
			if not native_configuration_current(state):return {"done":true,"accepted":false}
			if is_instance_valid(observed_bindings) and observed_bindings.changed.is_connected(update_native):observed_bindings.changed.disconnect(update_native)
			observed_bindings=null
		2,3,4:
			if not native_configuration_retire_owner(state,["key_owner","video_owner","native_frame"][phase-2]):return {"done":false,"blocked":true}
		5:native_scope.clear();native_playing=false
		6:
			# Preserve the original detach→pregame-theme notification, even when
			# the shared gameplay theme is configured later in this continuation.
			if is_instance_valid(pregame) and is_instance_valid(pregame.painter):configure_client_style(pregame.painter)
		7:
			if is_instance_valid(fallback):show_fallback()
		8:
			native_scope=state.scope.duplicate();native_frame=preload("res://systems/native_entry_menu_frame.gd").new();panel.add_child(native_frame)
			if not native_configuration_current(state):return {"done":true,"accepted":false}
			native_frame.configure(state.frame,state.text,state.catalog,str(state.cache))
		9:
			native_frame.set_modal_order(modal_order,modal_surfaces,self,modal_lease.admits)
			if not native_configuration_current(state):return {"done":true,"accepted":false}
			native_frame.prepared.connect(func():update_native();place());native_frame.artwork_ready.connect(func():update_native();place())
			native_frame.action_requested.connect(native_action);native_frame.title_input.connect(drag_title)
		10:native_frame.start()
		11:
			configure_client_style(state.frame,true)
			state.entry_style=client_style
		12:
			if client_style!=state.entry_style or not is_instance_valid(client_style):
				cancel_native_configuration(state);return {"done":true,"accepted":false}
			var style_result: Dictionary=client_style.entry_publication_step()
			if not style_result.get("done",false):return {"done":false,"blocked":false}
			if not style_result.get("accepted",false):
				cancel_native_configuration(state);return {"done":true,"accepted":false}
		13:
			if not state.has("video_entry") and is_instance_valid(window_settings):
				video_owner=preload("res://systems/native_video_options.gd").new();get_child(0).add_child(video_owner)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				state.video_entry=video_owner.begin_entry_configuration(state.frame,state.text,state.catalog,str(state.cache),window_settings,layout_path)
			if state.has("video_entry"):
				if not is_instance_valid(video_owner):cancel_native_configuration(state);return {"done":true,"accepted":false}
				var video_result: Dictionary=video_owner.entry_configuration_step(state.video_entry)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				if not video_result.get("done",false):return {"done":false,"blocked":false}
				if not video_result.get("accepted",false):cancel_native_configuration(state);return {"done":true,"accepted":false}
				video_owner.set_modal_order(modal_order,modal_surfaces,self)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				video_owner.prepared.connect(update_native);video_owner.artwork_ready.connect(update_native);video_owner.finished.connect(child_closed)
				video_owner.finish_entry_configuration()
		14:
			if is_instance_valid(key_bindings):
				observed_bindings=key_bindings
				if not observed_bindings.changed.is_connected(update_native):observed_bindings.changed.connect(update_native)
		15:
			if not state.has("keys_entry") and is_instance_valid(key_bindings):
				key_owner=preload("res://systems/native_key_settings.gd").new();get_child(0).add_child(key_owner)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				state.keys_entry=key_owner.begin_entry_configuration(state.frame,state.text,state.catalog,str(state.cache),key_bindings,layout_path)
			if state.has("keys_entry"):
				if not is_instance_valid(key_owner):cancel_native_configuration(state);return {"done":true,"accepted":false}
				var keys_result: Dictionary=key_owner.entry_configuration_step(state.keys_entry)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				if not keys_result.get("done",false):return {"done":false,"blocked":false}
				if not keys_result.get("accepted",false):cancel_native_configuration(state);return {"done":true,"accepted":false}
				key_owner.set_modal_order(modal_order,modal_surfaces,self)
				if not native_configuration_current(state):return {"done":true,"accepted":false}
				key_owner.prepared.connect(update_native);key_owner.finished.connect(child_closed)
				key_owner.finish_entry_configuration()
		16:
			var saved:=ConfigFile.new()
			if not layout_path.is_empty() and saved.load(layout_path)==OK:
				var position: Variant=saved.get_value("positions","ingame_options",Vector2.INF)
				if position is Vector2 and position.is_finite():retained_position=position
		17:
			native_configuration={};return {"done":true,"accepted":true}
	if not native_configuration_current(state):return {"done":true,"accepted":false}
	state.phase=phase+1
	return {"done":false,"blocked":false}
func cancel_native_configuration(state: Dictionary={}) -> void:
	if native_configuration.is_empty() or not state.is_empty() and not is_same(native_configuration,state):return
	var previous: Dictionary=native_configuration;native_configuration={};native_configuration_serial+=1;previous.cancelled=true
	var unpublished_style=previous.get("entry_style")
	if is_instance_valid(unpublished_style) and unpublished_style==client_style and unpublished_style.entry_publication_active:
		unpublished_style.close();unpublished_style.queue_free();client_style=null
	# Leave owned nodes reachable for the existing detach/shutdown path. Retire
	# their request epochs now so a cancelled menu cannot deliver stale artwork.
	for owner in [native_frame,video_owner,key_owner]:
		if not is_instance_valid(owner):continue
		var assets=preload("res://systems/native_data/modal_lease.gd").property(owner,"assets")
		if is_instance_valid(assets):assets.retire_scope()
	dismiss()
func set_native_scope(value: Array) -> void:
	if value!=native_scope: dismiss()
	native_scope=value.duplicate(); update_native()
func observe_lobby(value: Dictionary) -> void:
	lobby_state=value.duplicate(true); update_native()
func update_native() -> void:
	if not is_instance_valid(native_frame): return
	var connected: bool=bool(lobby_state.get("connected",false)); var busy: bool=bool(lobby_state.get("busy",false))
	# Only implemented capabilities are exposed. Original host Save/Load,
	# Full ConfigWindow still requires its owner. The video
	# owner currently implements windowed scale, not display-mode switching.
	native_frame.set_context(native_scope,{"resumegamebutton":true,"xbutton":true,"gamebutton":true,"controlsbutton":is_instance_valid(key_owner) and key_owner.layout_ready and key_owner.failure.is_empty() and key_bindings.bindings_ready,"videooptionsbutton":is_instance_valid(video_owner) and video_owner.art_ready(),"exitbutton":connected and not busy,"savecharbutton":connected and not busy and str(lobby_state.get("phase","")) in ["playing","area-loading"]})
	if native_playing and native_frame.art_ready():
		fallback.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=native_frame.definition.size; panel.size=native_frame.definition.size; native_frame.show()
		modal_lease.bind_input(native_frame.stage)
func native_action(tag: String) -> void:
	if tag=="videooptionsbutton" and (not is_instance_valid(video_owner) or not video_owner.art_ready()): return
	if tag in ["resumegamebutton","xbutton","gamebutton","videooptionsbutton","controlsbutton","savecharbutton","exitbutton","exit-confirmed"]:play_menu_click()
	match tag:
		"resumegamebutton","xbutton": dismiss()
		"gamebutton":
			var previous:=native_scope.duplicate(); choose("options"); child_return_scope=previous
		"videooptionsbutton":
			var previous:=native_scope.duplicate(); dismiss(); child_return_scope=previous; video_owner.show_page(previous)
		"controlsbutton":
			var previous:=native_scope.duplicate(); dismiss(); child_return_scope=previous; key_owner.show_page(previous)
		"savecharbutton": choose("export")
		"exitbutton": native_frame.ask_exit()
		"exit-confirmed": choose("disconnect")
func show_fallback() -> void:
	if is_instance_valid(native_frame): native_frame.dismiss()
	fallback.show(); panel.add_theme_stylebox_override("panel",fallback_style); panel.custom_minimum_size=Vector2(320,280); panel.reset_size()
	modal_lease.bind_input(fallback)
func dismiss() -> void:
	modal_lease.retire()
	dragging=false; child_return_scope.clear()
	if is_instance_valid(pregame): pregame.dismiss()
	if is_instance_valid(key_owner): key_owner.retire_scope()
	if is_instance_valid(video_owner): video_owner.retire_scope()
	if is_instance_valid(native_frame): native_frame.dismiss()
	panel.hide()
func child_closed() -> void:
	if is_instance_valid(pregame) and pregame.child_closed(): return
	var restore: bool=not child_return_scope.is_empty() and child_return_scope==native_scope and native_playing and is_instance_valid(native_frame) and bool(lobby_state.get("connected",false))
	child_return_scope.clear()
	if restore: open(true)
func detach_native() -> void:
	cancel_native_configuration()
	modal_lease.retire()
	child_return_scope.clear()
	if is_instance_valid(observed_bindings) and observed_bindings.changed.is_connected(update_native): observed_bindings.changed.disconnect(update_native)
	observed_bindings=null
	if is_instance_valid(key_owner): key_owner.close(); key_owner.queue_free()
	key_owner=null
	if is_instance_valid(video_owner): video_owner.close(); video_owner.queue_free()
	video_owner=null
	if is_instance_valid(native_frame): native_frame.close(); native_frame.queue_free()
	native_frame=null; native_scope.clear(); native_playing=false
	if is_instance_valid(pregame) and is_instance_valid(pregame.painter): configure_client_style(pregame.painter)
	if is_instance_valid(fallback): show_fallback()
func place() -> void:
	var maximum: Vector2=(get_viewport().get_visible_rect().size-panel.size*panel.scale.abs()).max(Vector2.ZERO)
	panel.position=retained_position.clamp(Vector2.ZERO,maximum) if native_playing and retained_position.is_finite() else maximum*0.5
func drag_title(event: InputEvent) -> void:
	if not modal_lease.admits():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging: drag_offset=event.global_position-panel.global_position
func save_position() -> void:
	retained_position=panel.position
	if layout_path.is_empty(): return
	var saved:=ConfigFile.new(); saved.load(layout_path); saved.set_value("positions","ingame_options",retained_position); saved.save(layout_path)
func blocks_pointer(point: Vector2) -> bool:
	if is_instance_valid(pregame) and pregame.visible: return true
	if is_instance_valid(key_owner) and key_owner.visible: return key_owner.get_global_rect().has_point(point)
	if is_instance_valid(video_owner) and video_owner.visible: return video_owner.get_global_rect().has_point(point)
	if not panel.visible: return false
	if is_instance_valid(native_frame) and is_instance_valid(native_frame.confirmation) and native_frame.confirmation.visible: return native_frame.confirmation.get_global_rect().has_point(point)
	return panel.get_global_rect().has_point(point)
func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(key_owner) and key_owner.visible or is_instance_valid(video_owner) and video_owner.visible:return
	if panel.visible and not modal_input_admitted():return
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if escape_override.is_valid() and escape_override.call(): pass
	elif panel.visible: dismiss()
	else: open(playing_query.call() if playing_query.is_valid() else false)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if panel.visible and not modal_input_admitted():return
	if event is InputEventMouseMotion and dragging:
		var maximum: Vector2=(get_viewport().get_visible_rect().size-panel.size*panel.scale.abs()).max(Vector2.ZERO)
		panel.global_position=(event.position-drag_offset).clamp(Vector2.ZERO,maximum)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and dragging: dragging=false; save_position()
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
	if is_instance_valid(pregame) and pregame.escape(): get_viewport().set_input_as_handled(); return
	if is_instance_valid(key_owner) and key_owner.visible:
		if key_owner.modal_lease.admits():key_owner.finish_page(false); get_viewport().set_input_as_handled()
		return
	if is_instance_valid(video_owner) and video_owner.visible:
		if video_owner.modal_lease.admits():video_owner.finish_page(); get_viewport().set_input_as_handled()
		return
	if panel.visible:
		if not is_instance_valid(native_frame) or not native_frame.cancel_confirmation(): dismiss()
		get_viewport().set_input_as_handled()
	elif escape_override.is_valid() and escape_override.call(): get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: dragging=false
func _exit_tree() -> void:
	cancel_native_configuration()
	modal_lease.close()
	if is_instance_valid(menu_audio_assets):menu_audio_assets.close()
	if is_instance_valid(menu_click_player):menu_click_player.stop()
	if is_instance_valid(client_style): client_style.close()
	close_pregame()
