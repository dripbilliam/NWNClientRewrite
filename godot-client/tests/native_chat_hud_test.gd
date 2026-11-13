extends "res://tests/native_party_indicators_test.gd"
const Chat=preload("res://systems/server_chat.gd")
const ChatFrame=preload("res://systems/native_chat_hud.gd")
const ChatPlan=preload("res://systems/native_data/chat_hud_layout.gd")
const Prompt=preload("res://systems/native_data/chat_prompt.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Layers=preload("res://systems/native_window_layers.gd")
class ChatInventory extends RefCounted:
	var frame_skin
class Ui extends RefCounted:
	var chat
	var desktop
	var inventory:=ChatInventory.new()
	var text
	var presentation_enabled:=true
var requests: Array=[]
var ground_clicks:=0
func mouse(surface: SubViewport,point: Vector2,pressed: bool) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await frames()
func key(surface: SubViewport,code: Key,pressed: bool=true) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; surface.push_input(event,true); await frames()
func adjustments(_frame,_chat,_surface,_art,_args) -> void:
	pass
func reconnected(_previous,_current) -> void:
	pass
func policy() -> void:
	var players: Array=[[7,{"name":"Account","character":{"firstName":{"text":"Two"},"lastName":{"text":"Words"}}}],[8,{"name":"Other","character":{"firstName":{"text":"Ada"}}}]]
	for index in 5:
		var value:=Prompt.dispatch("Original text",index)
		check(value=={"kind":"chat","channel":[2,3,1,6,14][index],"text":"Original text"},"Original five-mode channel mapping "+str(index))
	for command in ["s","w","p","dm","tk","talk"]:
		var value:=Prompt.dispatch("/"+command.to_upper()+"  payload",2)
		check(value.channel=={"s":2,"w":3,"p":6,"dm":14,"tk":1,"talk":1}[command] and value.text==" payload","Original case-insensitive command prefix "+command)
	check(Prompt.dispatch('/t "Two Words" hello',2,players)=={"kind":"chat","channel":4,"playerId":7,"playerAccount":"Account","text":"hello"},"Quoted character Tell resolves the exact full name to PLAYER_ID")
	check(Prompt.dispatch("/T Ada text",0,players).playerId==8 and Prompt.dispatch("/tell Ada text",4,players).channel==4,"Tell aliases override the selected mode")
	check(Prompt.dispatch("abc\nnot sent\rmore",2).text=="abc" and Prompt.dispatch("abc\rnot sent",2).text=="abc","Original single-line submission truncates CR/LF before dispatch")
	check(Prompt.dispatch("  ",2).text=="  " and Prompt.dispatch("",2).is_empty(),"Native nonempty whitespace is preserved; empty draft sends no chat packet")
	check(Prompt.dispatch('/t "Incomplete',2).is_empty() and Prompt.dispatch("/t Ada",2).is_empty(),"Malformed Tell follows original silent cancellation without public speech")
	check(Prompt.dispatch("/s",2).text=="/s" and Prompt.dispatch("test",-1).has("error"),"Bare channel command preserves native substring behavior; invalid mode fails")
	check(Prompt.dispatch("##local command",2).has("error"),"Unimplemented local console commands cannot leak into public chat")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	policy()
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original catalog opens read-only")
	var models: Dictionary={}
	for name in ChatPlan.RESOURCES:
		var parser:=Actor.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Original chat resource "+name)
	var definition:=ChatPlan.parse(models); check(str(definition.error).is_empty(),"Source chat hooks and original geometry admitted")
	var default_pane:=ChatPlan.pane(definition,false,false,134)
	check(default_pane.width==360 and default_pane.model.hooks.text1==Vector2(313,64) and default_pane.model.hooks.scrollmax==Vector2(344,56),"Original default134px anchor reproduces physical edit/scroll endpoints")
	check(ChatPlan.pane(definition,false,true,134).width==720 and ChatPlan.pane(definition,true,false,134).resource=="edit_chat_right","Combined/split modes select authored720/360 models without stretching")
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var ui_root:=Control.new(); surface.add_child(ui_root); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ground:=Button.new(); ui_root.add_child(ground); ground.size=surface.size; ground.focus_mode=Control.FOCUS_NONE; ground.pressed.connect(func():ground_clicks+=1)
	var text:=Talk.new()
	for index in 5: text.overrides[int(Prompt.MODES[index].ref)]=["Shout","Whisper","Talk","Party","DM"][index]
	var art:=Art.new(); root.add_child(art); art.models=QueuedModels.new(); art.add_child(art.models); art.catalog=RasterCatalog.new(); art.assets=QueuedRasters.new(); art.add_child(art.assets)
	var fonts:=HeadlessFonts.new(); root.add_child(fonts); var painter:=Painter.new(); root.add_child(painter); painter.art=art; painter.fonts=fonts
	var chat:=Chat.new(); ui_root.add_child(chat); chat.setup(); var ui:=Ui.new(); ui.chat=chat; ui.text=text; ui.inventory.frame_skin=painter
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.set_process(false); desktop.actor_id=42; desktop.area_id=55; desktop.generation=3; desktop.objects={42:{}}; desktop.request.connect(func(value):requests.append(value))
	ui.desktop=desktop; desktop.owner_ui=ui
	desktop.state={"players":[[7,{"name":"Account","objectId":77,"character":{"id":77,"firstName":{"text":"Two"},"lastName":{"text":"Words"}}}]]}
	chat.request.connect(func(value):
		if value.kind=="native-panel": desktop.command(value)
		else: requests.append(value))
	var frame:=ChatFrame.new(); frame.requested=true; root.add_child(frame); frame.configure(ui,catalog,str(args.report)+".cache",str(args.report)+".layout.cfg")
	chat.append_message({"name":{"text":"Speaker"},"rich":{"text":"Attuned to Fire","spans":[{"text":"Attuned to Fire","color":"#87ceeb"}]}})
	chat.append_message({"system":true,"text":"Server feedback"})
	frame.models=models; frame.activate(); await frames(); frame.place()
	check(frame.layout_ready and frame.failure.is_empty() and chat.position==Vector2.ZERO and frame.panes[0].container.position==Vector2(0,566),"Connected source chat takes the original default screen anchor")
	check(frame.entry_clip.position==Vector2(78,648) and frame.entry_clip.size.y==16 and frame.mode_button.position.distance_to(Vector2(1,647))<0.001 and chat.entry.scale==Vector2.ONE,"Original prompt text clip and mode-button geometry preserve font pixels above36px quickbar")
	check(frame.mode_options.size()==5 and frame.mode_label.text=="Talk:" and chat.entry.max_length==0,"Original five localized modes and unlimited edit sentinel replace prototype six-mode controls")
	check(frame.panes[0].label.get_parsed_text()=="Speaker: Attuned to Fire\nServer feedback\n" and not frame.panes[1].container.visible,"Combined source window retains received rich speech and server feedback")
	frame.set_split(true); await frames()
	check(frame.panes[0].label.get_parsed_text()=="Speaker: Attuned to Fire\n" and frame.panes[1].label.get_parsed_text()=="Server feedback\n" and frame.panes[1].container.position.x==360,"Split source panes preserve separate histories at authored offsets")
	frame.set_split(false)
	var at:=frame.mode_button.get_global_rect().get_center(); await mouse(surface,at,true); await mouse(surface,at,false)
	check(frame.popup.visible,"Actual native mode button opens the authored source list")
	at=frame.mode_options[3].get_global_rect().get_center(); await mouse(surface,at,true); await mouse(surface,at,false)
	check(frame.mode==3 and frame.mode_label.text=="Party:" and not frame.popup.visible,"Actual source channel choice updates the caption without stealing edit focus")
	chat.entry.grab_focus(); await frames()
	check(requests.back()=={"kind":"native-panel","panel":"chat-focus","open":true,"mode":3,"actorId":42,"areaId":55,"generation":3},"Actual entry focus sends original GUI event metadata in controlled scope")
	var count:=chat.rows.size(); chat.entry.text="Party draft"; await key(surface,KEY_ENTER); await key(surface,KEY_ENTER,false)
	check(requests.back()=={"kind":"chat","channel":6,"text":"Party draft"} and chat.entry.text.is_empty() and not chat.entry.has_focus() and chat.rows.size()==count,"Actual Enter submits the selected channel without a local echo")
	check(requests[-2].panel=="chat-focus" and not requests[-2].open,"Native submit releases focus and sends GUI event2")
	chat.prime_tell("Two Words"); await frames(); check(frame.mode==3 and chat.entry.text=='/t "Two Words" ' and chat.entry.has_focus(),"Player Tell primes the original quoted text without changing the selected mode")
	chat.entry.text+='hello'; await key(surface,KEY_ENTER); await key(surface,KEY_ENTER,false)
	check(requests.back().channel==4 and requests.back().playerId==7 and requests.back().playerAccount=="Account" and requests.back().text=="hello","Quoted Tell resolves through the active player roster")
	chat.entry.grab_focus(); chat.entry.text="Cancel me"; await key(surface,KEY_ESCAPE); await key(surface,KEY_ESCAPE,false)
	check(not chat.entry.has_focus() and chat.entry.text.is_empty(),"Actual Escape clears and leaves the original prompt")
	var before:=requests.size(); frame.select_mode(0); ui.presentation_enabled=false; chat.submit("hidden"); check(requests.size()==before,"Hidden gameplay cannot dispatch a stale chat draft")
	ui.presentation_enabled=true; text.overrides[66751]="Localized shout"; text.mark_changed(); frame._process(0)
	check(frame.mode_label.text=="Localized shout:" and frame.mode_options[0].text=="Localized shout","Active server text revisions refresh source channel labels")
	check(not chat.blocks_pointer(Vector2(900,300)) and chat.blocks_pointer(chat.entry.get_global_rect().get_center()),"A full-screen layout owner does not claim the world outside real chat controls")
	var layers:=Layers.new(); var covered:=layers.regions(chat); layers.free()
	check(not covered.any(func(rect):return rect.has_point(Vector2(900,300))),"Native front-window coverage also excludes the chat layout's empty screen area")
	await mouse(surface,Vector2(900,300),true); await mouse(surface,Vector2(900,300),false); check(ground_clicks==1,"Actual outside click still reaches world controls")
	frame.set_split(true); var handle: Control=frame.panes[0].handle; at=handle.get_global_rect().get_center(); await mouse(surface,at,true)
	var motion:=InputEventMouseMotion.new(); motion.position=at-Vector2(0,80); motion.global_position=motion.position; motion.relative=Vector2(0,-80); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(motion,true); await frames(); await mouse(surface,at-Vector2(0,80),false)
	check(frame.heights[0]>=200 and frame.heights[1]==134,"Actual native chat drag changes only its own pane height")
	for index in 80: chat.append_message({"text":"Received chat line "+str(index)})
	await frames(4); var range_control: VScrollBar=frame.panes[0].scroll.get_v_scroll_bar()
	check(range_control.max_value>range_control.page and range_control.value>=range_control.max_value-range_control.page-1,"Received messages follow the bottom only while the last line was visible")
	range_control.value=(range_control.max_value-range_control.page)*0.5; var prior:=range_control.value
	chat.append_message({"text":"Do not disturb historical reading"}); await frames(4)
	check(absf(range_control.value-prior)<1,"Appending received chat preserves a deliberately scrolled history position")
	surface.size=Vector2i(1200,800); await frames(); frame.place()
	check(frame.entry_clip.position.y==748 and frame.panes[1].container.position.x==360,"Viewport resizing reanchors the prompt without stretching pane widths")
	await adjustments(frame,chat,surface,art,args)
	var saved:=frame.mode; frame.close(); frame.select_mode(4); chat.submit("retired")
	check(frame.closed and frame.mode==saved and not frame.stage.visible and frame.jobs.is_empty(),"Retired chat callbacks cannot reactivate controls or send drafts")
	check(not fonts.bindings.has(chat.entry.get_instance_id()),"Retirement unbinds borrowed original font owners")
	var next_chat:=Chat.new(); ui_root.add_child(next_chat); next_chat.setup(); var next_ui:=Ui.new(); next_ui.chat=next_chat; next_ui.text=text; next_ui.inventory.frame_skin=painter
	var loading:=ChatFrame.new(); root.add_child(loading); loading.configure(next_ui,catalog,str(args.report)+".worker-cache",frame.storage)
	var deadline:=Time.get_ticks_msec()+5000
	while not loading.layout_ready and loading.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(loading.layout_ready and loading.failure.is_empty() and loading.jobs.is_empty() and loading.panes.size()==2,"Production native chat worker requests prepare original models and animated scrollbar data without GPU work")
	await reconnected(frame,loading)
	loading.close(); loading.queue_free(); next_chat.queue_free()
	desktop.closed=true; desktop.free(); frame.queue_free(); chat.queue_free(); painter.queue_free(); art.close(); art.queue_free(); fonts.close(); fonts.queue_free(); ui_root.queue_free(); surface.queue_free(); text.close(); catalog=null; await frames(3)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"Original chat geometry/mode constants, selected prompt commands, real native mouse/keyboard/focus routing, split panes and retirement. Original pixels, full chat context/filter/history/portrait behaviors and actual server outcomes remain open."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
