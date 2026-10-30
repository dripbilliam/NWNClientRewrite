extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Raw protocol UI messages in; native original TLK/2DA/texture readers and
# Godot controls out. No spans, PNG URLs or rendering-ready layouts from JS.
signal request(message: Dictionary)
signal options_requested
signal gui_sound_requested(resource: String)
const Desktop=preload("res://systems/native_game_desktop.gd")
var desktop
var mouse_cursor
var creator
var nui
const Assets=preload("res://systems/native_data/asset_service.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Chat=preload("res://systems/server_chat.gd")
const Conversation=preload("res://systems/server_conversation.gd")
const Examine=preload("res://systems/server_examine.gd")
const ItemPropertyText=preload("res://systems/native_data/item_property_text.gd")
const ExamineContent=preload("res://systems/native_data/examine_content.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const UiSkin=preload("res://systems/native_ui_skin.gd")
const InventoryOwner=preload("res://systems/native_inventory.gd")
var feedback=preload("res://systems/native_data/combat_feedback.gd").new()
var floating_rows: Array=[]
var world_camera: Camera3D
var world_registry
var text:=TextOwner.new()
var pool:=Pool.new()
var assets
var catalog
var layer: CanvasLayer
var controls: Control
var window_layers
var key_bindings
var chat
var conversation
var conversation_skin
var examine
var examine_skin
var skin_owner
var inventory
var barter
var generation:=-1
var area_id:=-1
var controlled_id:=-1
var closed:=false
var presentation_enabled:=true
var tables_ready:=false
var hud_ready:=false
var bindings_installed:=false
const HUD_TABLES=["stringtokens","portraits"]
const EARLY_TABLES=["stringtokens","portraits","keymap"]
var startup_at:=0
var startup_jobs: Dictionary={}
var startup_finished: Array=[]
var startup_marks: Dictionary={}
var table_jobs: Dictionary={}
var tlk_jobs: Dictionary={}
var portrait_jobs: Dictionary={}
var examine_jobs: Dictionary={}
var examine_pending: Dictionary={}
var examine_message: Dictionary={}
var queue: Array=[]
var revision:=0
var stats:={"messages":0,"speech":0,"dialogs":0,"examines":0,"portraits":0,"stale_messages":0,"errors":[],"native_only":true,"full_ui_migration":false}
func configure(source,install: String,cache_path: String,layout: String="user://native-menu-layout.cfg",custom_tlk: Dictionary={}) -> void:
	startup_at=Time.get_ticks_msec()
	catalog=source; feedback.text=text
	var recorded: bool=catalog.has_method("talk_path")
	if not text.base.open_file(catalog.talk_path("base") if recorded else install.path_join("lang/en/data/dialog.tlk")): stats.errors.append(text.base.failure)
	var female_path: String=catalog.talk_path("female") if recorded else install.path_join("lang/en/data/dialogf.tlk")
	if FileAccess.file_exists(female_path) and not text.female.open_file(female_path): stats.errors.append(text.female.failure)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	key_bindings=preload("res://systems/native_key_bindings.gd").new(); add_child(key_bindings); key_bindings.configure(layout)
	# Portrait/name projection and movement bindings do not depend on every
	# class/feat/spell table. Dispatch these before optional/custom text work.
	for name in EARLY_TABLES: request_startup_table(name)
	if not custom_tlk.is_empty():
		var name:=str(custom_tlk.get("name","")).get_file().trim_suffix(".tlk").to_lower()
		var path:=str(custom_tlk.get("path","")) if custom_tlk.get("path") is String else ""
		if recorded: path=catalog.talk_path("custom")
		if catalog.has_resource(name,2018): tlk_jobs[assets.request(name,2018,"bytes")]=false
		elif not path.is_empty() and not text.custom.open_file(path): stats.errors.append(text.custom.failure)
		if catalog.has_resource(name+"f",2018): tlk_jobs[assets.request(name+"f",2018,"bytes")]=true
		elif recorded and not catalog.talk_path("custom_female").is_empty(): text.custom_female.open_file(catalog.talk_path("custom_female"))
		elif not recorded and not path.is_empty() and FileAccess.file_exists(path.trim_suffix(".tlk")+"f.tlk"): text.custom_female.open_file(path.trim_suffix(".tlk")+"f.tlk")
	for name in ["racialtypes","classes","damagelevels","baseitems","armor","itempropdef","iprp_costtable","iprp_paramtable","damagetypes","damagetypegroups","effecticons","traps","encumbrance","capart","parts_robe","cloakmodel","iprp_spells","spells","feat","skills","exptable","domains","ranges","actions","ruleset","hen_familiar","hen_companion","spellschools","masterfeats"]: request_startup_table(name)
	layer=CanvasLayer.new(); layer.layer=10; add_child(layer); controls=Control.new(); controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); controls.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(controls)
	chat=Chat.new(); controls.add_child(chat); chat.setup(); chat.request.connect(request.emit)
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); chat.position=Vector2(10,maxf(0,get_viewport().get_visible_rect().size.y-280)); chat.size=Vector2(520,260)
	get_viewport().size_changed.connect(func(): chat.position.y=maxf(0,get_viewport().get_visible_rect().size.y-280))
	conversation=Conversation.new(); controls.add_child(conversation); conversation.setup(layout); conversation.request.connect(request.emit)
	examine=Examine.new(); controls.add_child(examine); examine.setup(layout)
	inventory=InventoryOwner.new(); add_child(inventory); inventory.configure(controls,catalog,cache_path,text,layout); inventory.request.connect(request.emit)
	inventory.gold.world_pick=func(point): return world_registry.pick(world_camera,point) if is_instance_valid(world_registry) and is_instance_valid(world_camera) else {}
	inventory.gold.world_blocked=blocks_pointer
	skin_owner=UiSkin.new(); add_child(skin_owner); skin_owner.fonts_ready.connect(func(): controls.theme=skin_owner.theme()); skin_owner.configure(catalog,cache_path)
	desktop=Desktop.new(); add_child(desktop); desktop.configure(self,catalog,cache_path,layout); desktop.request.connect(request.emit); desktop.options_requested.connect(options_requested.emit)
	mouse_cursor=preload("res://systems/native_mouse_cursor.gd").new(); add_child(mouse_cursor); mouse_cursor.configure(self,catalog,cache_path)
	conversation_skin=preload("res://systems/native_conversation_frame.gd").new(); add_child(conversation_skin); conversation_skin.configure(self,catalog,cache_path)
	barter=preload("res://systems/native_barter.gd").new(); add_child(barter); barter.configure(self,catalog,cache_path,layout)
	examine_skin=preload("res://systems/native_examine_frame.gd").new(); add_child(examine_skin); examine_skin.configure(self,catalog,cache_path)
	nui=preload("res://systems/native_nui.gd").new(); add_child(nui); nui.configure(self); nui.request.connect(request.emit)
	creator=preload("res://systems/native_creation.gd").new(); add_child(creator); creator.configure(self); creator.request.connect(request.emit)
	window_layers=preload("res://systems/native_window_layers.gd").new(); add_child(window_layers); window_layers.configure(controls)
func set_gameplay_visible(value: bool) -> void:
	if closed or value==presentation_enabled: return
	presentation_enabled=value
	# Catalog/font/art owners remain live for the independent pregame chooser,
	# creator and loading screen. Hide only the gameplay canvases; CanvasLayer
	# children (including NUI windows) do not inherit a Control's visibility.
	var canvases: Array=[layer,desktop.radial,inventory.item_context.wheel]
	if not value:
		var focus:=get_viewport().gui_get_focus_owner()
		for canvas in canvases:
			if is_instance_valid(focus) and canvas.is_ancestor_of(focus): focus.release_focus(); break
	for canvas in canvases:
		canvas.visible=value
		canvas.process_mode=Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	# These input owners are siblings of the hidden canvas. Their preparation
	# and received-state callbacks continue, but hidden menus cannot take keys.
	set_process_unhandled_key_input(value)
	desktop.set_process_unhandled_key_input(value)
	inventory.gold.set_process_input(value)
	mouse_cursor.set_process_input(value)
	if not value:
		mouse_cursor.select(preload("res://systems/native_data/mouse_cursor.gd").selection())
func request_startup_table(name: String) -> void:
	# UI rule projection only reads these graphs. Borrow the decoder's immutable
	# source instead of deep-copying aliased physical/keyed/ordered row views at
	# both cache levels. Mutable consumers retain Assets' existing copy default.
	var id: int=assets.request(name,2017,"2da",{"immutable_source":true})
	table_jobs[id]=name; startup_jobs[id]={"name":name,"queued_ms":Time.get_ticks_msec()-startup_at}
func mark_hud_started() -> void:
	if not startup_marks.has("hud_presented_ms"): startup_marks.hud_presented_ms=Time.get_ticks_msec()-startup_at
func panel_ready(id: String) -> bool:
	if tables_ready or id in ["options","rest"]: return true
	if id=="map": return hud_ready
	if id=="journal": return hud_ready and tlk_jobs.is_empty()
	if id=="pvp": return hud_ready and tlk_jobs.is_empty() and text.tables.has("classes")
	return false
func startup_snapshot() -> Dictionary:
	var slow:=startup_finished.duplicate(); slow.sort_custom(func(a,b):return float(a.worker_ms)>float(b.worker_ms)); slow=slow.slice(0,6)
	var result:=startup_marks.duplicate()
	result.merge({"gameplay_visible":presentation_enabled,"gameplay_canvas_visible":layer.visible if is_instance_valid(layer) else false,"chat_visible_in_tree":chat.is_visible_in_tree() if is_instance_valid(chat) else false})
	result.merge({"configured_ticks_ms":startup_at,"elapsed_ms":Time.get_ticks_msec()-startup_at,"hud_ready":hud_ready,"tables_ready":tables_ready,"pending_tables":table_jobs.values(),"pending_custom_text":tlk_jobs.size(),"completed_tables":startup_finished.size(),"slowest_tables":slow})
	if is_instance_valid(desktop): result.merge({"party_visible":desktop.party.visible,"quickbar_visible":desktop.quickbar.visible,"party_layout_ready":desktop.party_frame.layout_ready,"quickbar_layout_ready":desktop.quickbar_frame.layout_ready})
	return result
func set_world(epoch: int,area: int,controlled: int,objects: Array,raw_inventory: Dictionary={},header: Dictionary={}) -> void:
	var began:=Timing.begin()
	if generation!=epoch:
		conversation.reset(); examine.reset(); examine_message.clear(); clear_floating()
	Timing.finish("snapshot_ui_reset_ms",began); began=Timing.begin()
	generation=epoch; area_id=area; controlled_id=controlled; text.objects={}
	for object in objects: text.objects[int(object.id)]=object
	Timing.finish("snapshot_ui_object_map_ms",began); began=Timing.begin()
	inventory.set_world(epoch,area,controlled,objects,raw_inventory)
	Timing.finish("snapshot_ui_inventory_ms",began); began=Timing.begin()
	desktop.set_world(epoch,area,controlled,text.objects,{"area":header.get("area",{}),"module":header.get("module",{}),"scriptTargeting":header.get("ui",{}).get("scriptTargeting"),"scriptTargetingData":header.get("ui",{}).get("scriptTargetingData"),"playerAttitudes":header.get("ui",{}).get("playerAttitudes",[]),"partyInviteNotice":header.get("ui",{}).get("partyInviteNotice"),"partyListRevision":header.get("ui",{}).get("partyListRevision",0),"party":header.get("ui",{}).get("party",[]),"quickbar":header.get("ui",{}).get("quickbar",[]),"players":header.get("ui",{}).get("players",[]),"journal":header.get("ui",{}).get("journal",{}),"mapPins":header.get("ui",{}).get("mapPins",[])})
	Timing.finish("snapshot_ui_desktop_ms",began)
	barter.set_world(epoch,area,controlled,text.objects,header.get("ui",{}).get("barter",{}))
	examine_skin.sync()
func update_world(epoch: int,area: int,controlled: int,objects: Array,removed: Array,raw_inventory: Dictionary={},header: Dictionary={}) -> void:
	if epoch!=generation or area!=area_id: return
	controlled_id=controlled
	for id in removed: text.objects.erase(int(id))
	for object in objects: text.objects[int(object.id)]=object
	inventory.update_world(epoch,area,controlled,objects,removed,raw_inventory)
	desktop.set_world(epoch,area,controlled,text.objects,{"area":header.get("area",{}),"module":header.get("module",{}),"scriptTargeting":header.get("ui",{}).get("scriptTargeting"),"scriptTargetingData":header.get("ui",{}).get("scriptTargetingData"),"playerAttitudes":header.get("ui",{}).get("playerAttitudes",[]),"partyInviteNotice":header.get("ui",{}).get("partyInviteNotice"),"partyListRevision":header.get("ui",{}).get("partyListRevision",0),"party":header.get("ui",{}).get("party",[]),"quickbar":header.get("ui",{}).get("quickbar",[]),"players":header.get("ui",{}).get("players",[]),"journal":header.get("ui",{}).get("journal",{}),"mapPins":header.get("ui",{}).get("mapPins",[])})
	barter.set_world(epoch,area,controlled,text.objects,header.get("ui",{}).get("barter",{}))
	examine_skin.sync()
func receive(message: Dictionary,epoch: int) -> void:
	if closed: return
	if str(message.kind).begins_with("barter-"):
		if epoch==generation: barter.receive(message)
		if message.kind!="barter-reject": return
	if str(message.kind).begins_with("nui-"): nui.receive(message); return
	if message.kind=="native-action-result":
		if epoch==generation:
			barter.receive(message)
			desktop.receive(message); inventory.receive(message)
			examine_skin.receive(message)
		return
	if message.kind in ["inventory-result","inventory-ack","inventory-command-result","store-transaction","store-close"]:
		if epoch==generation: inventory.receive(message)
		if epoch==generation: examine_skin.receive(message)
		return
	if message.kind=="custom-token":
		if int(message.id)>=0: text.custom_tokens[int(message.id)]=str(message.text)
		text.mark_changed()
		return
	if message.kind=="tlk-overrides":
		for row in message.entries:
			if str(row.text).is_empty(): text.overrides.erase(int(row.strRef))
			else: text.overrides[int(row.strRef)]=str(row.text)
		text.mark_changed()
		return
	if queue.size()>=512: stats.errors.append("Native UI protocol queue exceeds bound"); return
	queue.append({"generation":epoch,"message":message.duplicate(true)})
func prepared(id: int,result: Dictionary) -> void:
	if closed: return
	if examine_jobs.has(id):
		var name:=str(examine_jobs[id]); examine_jobs.erase(id); examine_pending.erase(name)
		if not str(result.error).is_empty(): stats.errors.append({"resource":name,"reason":result.error}); text.publish_table(name,{})
		else: text.publish_table(name,result.value)
		refresh_examine_properties(); return
	if tlk_jobs.has(id):
		var female: bool=tlk_jobs[id]; tlk_jobs.erase(id)
		var target=text.custom_female if female else text.custom
		if not str(result.error).is_empty(): stats.errors.append(result.error)
		elif not target.open_bytes(result.bytes): stats.errors.append(target.failure)
		text.mark_changed()
		if is_instance_valid(desktop): desktop.signatures.erase("party"); desktop.dirty=true
		return
	if table_jobs.has(id):
		var name:=str(table_jobs[id]); table_jobs.erase(id)
		if startup_jobs.has(id):
			var row: Dictionary=startup_jobs[id]; startup_jobs.erase(id)
			row.merge({"completed_ms":Time.get_ticks_msec()-startup_at,"worker_ms":float(result.get("worker_ms",0)),"read_ms":float(result.get("read_ms",0)),"queue_ms":float(result.get("phases",{}).get("service_queue_ms",0)),"decode_ms":float(result.get("timings",{}).get("decode_ms",0)),"memory_decode_hit":bool(result.get("memory_decode_hit",false)),"bytes":result.get("bytes",PackedByteArray()).size(),"error":str(result.get("error",""))}); startup_finished.append(row)
		if not str(result.error).is_empty(): stats.errors.append({"resource":name,"reason":result.error}); text.publish_table(name,{})
		else: text.publish_table(name,result.value)
		if is_instance_valid(desktop): desktop.dirty=true
		return
	if not portrait_jobs.has(id): return
	var job: Dictionary=portrait_jobs[id]; portrait_jobs.erase(id)
	if int(job.generation)!=generation or not examine.visible or int(examine.state.get("revision",-1))!=int(job.revision): return
	if not str(result.error).is_empty(): stats.errors.append({"portrait":job.name,"reason":result.error}); return
	var texture=pool.texture(result)
	if texture==null: stats.errors.append(pool.failure); return
	if examine.set_native_portrait(preload("res://systems/native_ui_art.gd").portrait_texture(texture),int(job.target),int(job.revision)):
		examine.portrait.flip_v=true; stats.portraits+=1
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_ui",began)
func _profile_process(_delta: float) -> void:
	if closed: return
	update_floating()
	if not bindings_installed and not table_jobs.values().has("keymap"):
		key_bindings.install(text.tables.get("keymap",{}),text.base.language); bindings_installed=true; startup_marks.bindings_ready_ms=Time.get_ticks_msec()-startup_at
	if not hud_ready and not HUD_TABLES.any(func(name):return table_jobs.values().has(name)):
		text.import_tokens(); hud_ready=true; startup_marks.hud_rules_ready_ms=Time.get_ticks_msec()-startup_at
		if is_instance_valid(desktop): desktop.dirty=true
	if not table_jobs.is_empty() or not tlk_jobs.is_empty(): return
	if not tables_ready:
		tables_ready=true; startup_marks.all_rules_ready_ms=Time.get_ticks_msec()-startup_at; barter.refresh()
		if is_instance_valid(desktop): desktop.signatures.erase("party"); desktop.dirty=true
	if queue.is_empty() or int(queue[0].generation)>generation: return
	var next: Dictionary=queue.pop_front()
	if int(next.generation)!=generation: stats.stale_messages+=1; return
	present(next.message); stats.messages+=1
func speech(message: Dictionary) -> Dictionary:
	var channel:=int(message.channel)
	if channel==7: return {}
	var system:=channel in [5,15]; var object: Dictionary=text.objects.get(int(message.get("objectId",-1)),{})
	var remote:=channel>=0 and channel<31 and ((0x401e4054>>channel)&1)!=0
	if object.is_empty() and not system and channel not in [11,12] and not remote: return {}
	var context:=int(message.get("contextId",controlled_id)); var raw:=text.resolve(message.text,context)
	if raw.is_empty(): return {}
	var name:="" if system else text.name(message.get("speakerName"),int(message.get("objectId",-1)))
	if name.is_empty() and not system: name=text.raw({"strRef":5189})
	var prefixes:={2:10300,9:10300,18:10300,3:10301,10:10301,19:10301,4:10302,20:10302,5:10299,15:10299,6:10303,22:10303,14:66756,30:66756}
	var prefix:=text.resolve({"strRef":prefixes[channel]},context) if prefixes.has(channel) else ""
	if channel in [14,30] and not prefix.is_empty(): prefix="["+prefix+"] "
	return {"kind":"chat","channel":channel,"system":system,"objectId":message.get("objectId",-1),"name":Rich.parse(name),"rich":Rich.parse(prefix+raw),"text":Rich.parse(raw).text}
func clear_floating() -> void:
	for row in floating_rows:
		if is_instance_valid(row.label): row.label.queue_free()
	floating_rows.clear()
func add_floating(row: Dictionary) -> void:
	if floating_rows.size()>=64:
		var old: Dictionary=floating_rows.pop_front(); old.label.queue_free()
	var label:=preload("res://systems/server_text.gd").label({})
	label.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER); preload("res://systems/server_text.gd").append(label,row.rich); label.pop()
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.scroll_active=false; label.custom_minimum_size.x=500
	label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",4)
	controls.add_child(label); floating_rows.append({"id":int(row.objectId),"label":label,"at":Time.get_ticks_msec()})
func update_floating() -> void:
	var now:=Time.get_ticks_msec()
	for index in range(floating_rows.size()-1,-1,-1):
		var row: Dictionary=floating_rows[index]; var elapsed: float=(now-int(row.at))/1000.0
		var actor: Dictionary=text.objects.get(int(row.id),{}); var pose: Array=actor.get("replicated",{}).get("position",[])
		if elapsed>4.5 or actor.is_empty(): row.label.queue_free(); floating_rows.remove_at(index); continue
		if not is_instance_valid(world_camera) or pose.size()!=3: row.label.hide(); continue
		var point:=Vector3(pose[0],pose[2]+2.4,-pose[1])
		if is_instance_valid(world_registry) and world_registry.bounds.has(int(row.id)):
			var bounds: AABB=world_registry.bounds[int(row.id)]; point.y=maxf(point.y,bounds.end.y+0.3)
		row.label.visible=not world_camera.is_position_behind(point)
		var screen:=world_camera.unproject_position(point); row.label.position=screen-Vector2(250,elapsed*14+(floating_rows.size()-index-1)*20); row.label.modulate.a=minf(1.0,(4.5-elapsed)*2)
func present(message: Dictionary) -> void:
	match str(message.kind):
		"barter-reject":
			if int(message.operation)==1:
				var ref: int={1:0x1a8a,2:0x1a8b,3:0x1a8c,4:0x1a8d,5:0x2848,6:0x107cb}.get(int(message.reason),1)
				var rich:=Rich.parse(text.resolve({"strRef":ref},int(message.targetId),{"nativeB8":1}))
				chat.append_message({"category":"barter-reject","system":true,"color":"#ffff00","rich":rich,"text":rich.text,"targetId":int(message.targetId),"operation":int(message.operation),"reason":int(message.reason)})
		"combat-feedback","spell-feedback","attack-feedback","damage-feedback","initiative-feedback":
			feedback.controlled=controlled_id
			for row in feedback.format(message): chat.append_message(row)
			for row in feedback.floating: add_floating(row)
			for resource in feedback.sounds: gui_sound_requested.emit(str(resource))
		"server-speech":
			var row:=speech(message)
			if not row.is_empty(): chat.append_message(row); stats.speech+=1
		"dialog-close": conversation.reset()
		"dialog-entry","dialog-selected":
			var row:=message.duplicate(true); row.rich=text.rich(message.text,int(message.tokenObjectId)); conversation.present(row); stats.dialogs+=1
		"dialog-replies":
			var choices: Array=message.replies if not message.replies.is_empty() else [{"id":4294967295,"text":{"text":""}}]; var replies: Array=[]
			for index in choices.size():
				var row: Dictionary=choices[index]
				var label:=text.resolve(row.text,int(message.tokenObjectId))
				if label.is_empty(): label=text.raw({"strRef":0x6ce if bool(message.end) or message.replies.is_empty() else 0x6cd})
				replies.append({"id":row.id,"rich":Rich.parse(label),"available":message.replies.is_empty() or index<int(message.get("firstCount",message.replies.size()-int(message.get("secondCount",0))))})
			conversation.present({"kind":"dialog-replies","entryId":message.entryId,"end":message.end,"localEnd":message.replies.is_empty(),"replies":replies}); stats.dialogs+=1
		"examine": present_examine(message)
		"dialog-error": conversation.present(message)
func present_examine(message: Dictionary) -> void:
	revision+=1
	examine_message=message.duplicate(true)
	inventory.receive(message)
	var id:=int(message.targetId); var output:={"kind":"examine","type":message.type,"identified":bool(message.get("identified",true)),"targetId":id,"revision":revision,"name":Rich.parse(text.name(message.get("name"),id)),"warnings":[],"facts":[],"properties":[],"effects":[]}
	output.close=bool(message.get("close",false)) or (message.type=="trap" and not message.get("success",false))
	if message.has("description"): output.description=text.rich(message.description,id)
	if message.type=="item":
		var native_content:=ExamineContent.item(message,text,id); output.nativeBody=native_content.rich; output.propertyHeading=native_content.property_heading; output.propertyCount=message.get("properties",[]).size() if bool(message.get("identified",false)) else 0
		var item: Dictionary=text.objects.get(id,{}).get("item",{})
		if item.has("baseItem"): output.facts.append({"name":"Item type","rich":Rich.parse(text.label("baseitems",int(item.baseItem)))})
		if bool(message.get("identified",false)) and int(message.get("charges",0))>0: output.facts.append({"name":"Charges","rich":Rich.parse(Numbers.text(message.charges))})
		if message.has("weight"): output.facts.append({"name":"Weight","rich":Rich.parse(Numbers.tenths(message.weight))})
		if message.has("value"): output.facts.append({"name":"Value","rich":Rich.parse(Numbers.text(message.value))})
		if not bool(message.get("identified",false)): output.facts.append({"name":"Identification","rich":Rich.parse("Unidentified")})
		if message.has("canUse") and not message.canUse: output.facts.append({"name":"Use","rich":Rich.parse("Cannot use")})
		if message.has("minimumLevel"): output.facts.append({"name":"Required level","rich":Rich.parse(Numbers.text(message.minimumLevel))})
	if message.type=="creature" and message.get("hasDetails",false):
		output.condition=Rich.parse(text.label("damagelevels",int(message.damageLevel),"STRING_REF"))
		if int(message.reaction)<=2: output.reaction=text.rich({"strRef":[0x1918,0x1919,0x1917][int(message.reaction)]},id)
		if message.has("challengeRating"): output.facts.append({"name":"Challenge Rating","rich":Rich.parse(Numbers.text(message.challengeRating))})
		if message.has("playerLevel"): output.facts.append({"name":"Level","rich":Rich.parse(Numbers.text(message.playerLevel))})
	for effect in message.get("effects",[]):
		var label:=text.label("effecticons",int(effect),"StrRef")
		if not label.is_empty(): output.effects.append(Rich.parse(label))
	if message.type=="item" and bool(message.get("identified",false)):
		var details:=ItemPropertyText.project(message.get("properties",[]),text,int(message.get("actorId",controlled_id)))
		output.properties=details.properties; output.warnings=details.warnings
	examine.present(output); stats.examines+=1
	if not output.close: request_examine_tables()
	if output.close or not message.has("portraitId"): return
	var base:=str(message.get("portrait","")); var portrait_id:=int(message.portraitId)
	if portrait_id<=65533:
		var rows: Array=text.tables.get("portraits",{}).get("orderedRows",[])
		if portrait_id<rows.size(): base="po_"+str(rows[portrait_id].get("BaseResRef",""))
	if base.is_empty() or base.ends_with("****"): return
	for suffix in ["l","h","m","s","t"]:
		var name: String=base+str(suffix); var location: Dictionary=catalog.raster_location(name)
		if location.is_empty(): continue
		var job: int=assets.request(name,int(location.type),"raster")
		if job>=0: portrait_jobs[job]={"name":name,"target":id,"revision":revision,"generation":generation}
		break
func request_examine_tables() -> void:
	if examine_message.get("type","")!="item" or not examine_message.get("identified",false) or not examine.visible: return
	var requested:=0
	for name in ItemPropertyText.dependencies(examine_message.get("properties",[]),text.tables):
		if examine_pending.has(name): continue
		if requested>=8: break
		var job: int=assets.request(name,2017,"2da")
		if job<0: stats.errors.append({"resource":name,"reason":assets.failure}); continue
		examine_jobs[job]=name; examine_pending[name]=true; requested+=1
func refresh_examine_properties() -> void:
	if examine_message.get("type","")!="item" or not examine_message.get("identified",false) or not examine.visible: return
	var details:=ItemPropertyText.project(examine_message.get("properties",[]),text,int(examine_message.get("actorId",controlled_id)))
	if examine.refresh_properties(details.properties,details.warnings,int(examine_message.targetId),revision): request_examine_tables()
func blocks_pointer(point: Vector2) -> bool:
	if not presentation_enabled: return false
	if is_instance_valid(barter) and barter.blocks_pointer(point): return true
	if is_instance_valid(nui) and nui.blocks_pointer(point): return true
	if is_instance_valid(desktop) and desktop.blocks_pointer(point): return true
	if is_instance_valid(inventory) and inventory.blocks_pointer(point): return true
	for control in [chat,conversation,examine]:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(point): return true
	return false
func _unhandled_key_input(event: InputEvent) -> void:
	if not presentation_enabled: return
	if is_instance_valid(creator) and creator.phase!="closed": return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(key_bindings) and key_bindings.blocked(): return
	var focus:=get_viewport().gui_get_focus_owner()
	if (key_bindings.action_matches(63,event) if is_instance_valid(key_bindings) else event.keycode==KEY_I) and not focus is LineEdit and not focus is TextEdit:
		if inventory.ui.wanted: inventory.ui.close_inventory()
		else: inventory.ui.open()
		get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_ENTER and not get_viewport().gui_get_focus_owner() is LineEdit:
		chat.entry.grab_focus(); get_viewport().set_input_as_handled()
func snapshot() -> Dictionary:
	if is_instance_valid(mouse_cursor): stats.mouse_cursor=mouse_cursor.snapshot()
	var state:=stats.duplicate(true); state.merge({"startup":startup_snapshot(),"queued":queue.size(),"pending_tables":table_jobs.size(),"pending_portraits":portrait_jobs.size(),"tables_ready":tables_ready,"tlk_reads":text.base.reads+text.female.reads+text.custom.reads+text.custom_female.reads,"token_diagnostics":text.diagnostics.duplicate(),"feedback_diagnostics":feedback.diagnostics.duplicate(),"floating":floating_rows.size(),"nui":nui.snapshot(),"skin":skin_owner.snapshot() if is_instance_valid(skin_owner) else {},"inventory":inventory.snapshot() if is_instance_valid(inventory) else {},"barter":barter.snapshot() if is_instance_valid(barter) else {},"examine":examine_skin.snapshot() if is_instance_valid(examine_skin) else {},"desktop":desktop.snapshot() if is_instance_valid(desktop) else {},"creation":{"phase":creator.phase,"native_only":true},"scope":"Native gameplay desktop, character creation and original-data UI projection. Full binary visual parity and public-server transfers remain incomplete; native NUI is locally verified."}); state.window_layers=window_layers.snapshot() if is_instance_valid(window_layers) else {}; return state
func close() -> void:
	if closed: return
	closed=true; clear_floating()
	if is_instance_valid(mouse_cursor): mouse_cursor.close()
	if is_instance_valid(key_bindings): key_bindings.close()
	if is_instance_valid(window_layers): window_layers.close()
	if is_instance_valid(creator): creator.close()
	if is_instance_valid(nui): nui.close()
	if is_instance_valid(barter): barter.close()
	if is_instance_valid(examine_skin): examine_skin.close()
	if is_instance_valid(conversation_skin): conversation_skin.close()
	if is_instance_valid(desktop): desktop.close()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(skin_owner): skin_owner.close()
	if is_instance_valid(inventory): inventory.close()
	text.close(); table_jobs.clear(); portrait_jobs.clear(); examine_jobs.clear(); examine_pending.clear(); examine_message.clear(); queue.clear(); pool.clear(); catalog=null
func _exit_tree() -> void: close()
