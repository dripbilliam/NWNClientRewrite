extends Node
# Original player-list presentation. Requests carry received IDs; no local group rules run.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/players_layout.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
var desktop
var panel
var frame
var assets
var models: Dictionary={}
var layouts: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var definition: Dictionary={}
var layout_ready:=false
var closed:=false
var failure:=""
var stage: Control
var scroll: ScrollContainer
var tree: Control
var bar
var help_label: Label
var pvp_label: Label
var buttons: Dictionary={}
var cards: Dictionary={}
var images: Dictionary={}
var rendering:=false
var selected:=-1
var serial:=0
var pending: Dictionary={}
var captured: Dictionary={}
var popup
func configure(owner,catalog,cache_path: String) -> void:
	desktop=owner; panel=owner.players; panel.native_skin=self; frame=owner.owner_ui.inventory.frame_skin
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared); frame.art.loaded.connect(art_loaded); frame.fonts.loaded.connect(font_loaded)
	panel.visibility_changed.connect(func():
		if not panel.wanted:
			captured.clear()
			for id in pending.keys():
				if not pending[id].get("popup",false): pending.erase(id)
			if layout_ready: clear_cards())
	popup=preload("res://systems/native_party_invitation.gd").new(); add_child(popup); popup.configure(self)
	schedule_sources()
func schedule_sources() -> void:
	for name in Plan.RESOURCES+["scrollbar_simple","pb_scrl_up","pb_scrl_down","pnl_util_ok","ctl_btn_pre_118","ctl_btn_xch"]: request_model(name)
	for name in ["ingame_pvp","party_invitation"]:
		var id: int=assets.request(name,2047,"gff")
		if id<0: fail(name+": "+str(assets.failure)); return
		jobs[id]="@"+name
	frame.fonts.request("fnt_galahad14")
func scope() -> Array: return [desktop.generation,desktop.area_id,desktop.actor_id]
func flags() -> Dictionary: return desktop.actor().get("replicated",{}).get("party",{})
func reaction(object: Dictionary) -> int:
	# Native GetCreature returns no current-area creature for a retired proxy.
	if int(object.get("objectType",-1))!=5 or bool(object.get("replicationRemoved",false)) or int(object.get("areaId",-1))!=desktop.area_id: return 255
	return int(object.get("replicated",{}).get("reaction",255))
func invitation() -> int: return int(flags().get("field7D8",-1)) if bool(flags().get("field7DC",false)) else -1
func _process(_delta: float) -> void:
	if closed: return
	popup.observe()
	# NativeUiArt records decode failures without a loaded signal. Poll only
	# while waiting for first admission so a missing original is reported.
	if panel.wanted and not panel.visible: try_admit()
func request_model(name: String) -> void:
	if requested.has(name): return
	requested[name]=true
	var id: int=assets.request(name,2002,"actor-model")
	if id<0: fail(name+": "+str(assets.failure)); return
	jobs[id]=name
func collect_models(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty(): request_model(name)
	for child in node.get("Obj_ChildList",[]): collect_models(child)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): fail(name+": "+str(result.error)); return
	if name.begins_with("@"):
		var key:=name.substr(1); layouts[key]=result.value.root; collect_models(layouts[key])
	else: models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty() or layouts.size()<2: return
	definition=Plan.parse(layouts.ingame_pvp,models)
	if not str(definition.error).is_empty(): fail(str(definition.error)); return
	activate(); popup.activate(layouts.party_invitation,models); call_deferred("try_admit")
func fail(message: String) -> void:
	failure=message
	if is_instance_valid(desktop.target_prompt): desktop.target_prompt.text=message; desktop.target_prompt.show()
func picture(parent: Control,resource: String,rect: Rect2) -> TextureRect:
	var image:=TextureRect.new(); parent.add_child(image); image.position=rect.position; image.size=rect.size; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var key: String=frame.art.request_model(resource,""); images[image.get_instance_id()]={"target":weakref(image),"key":key}; image.visible=frame.art.textures.has(key)
	if image.visible: image.texture=frame.art.textures[key]
	return image
func art_loaded(key: String,image: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for entry in images.values():
		var target: Object=entry.target.get_ref()
		if entry.key==key and is_instance_valid(target) and not target.is_queued_for_deletion(): target.texture=image; target.show()
	call_deferred("try_admit")
func font_loaded(_name: String) -> void: call_deferred("try_admit")
func art_and_font_ready(node: Node) -> bool:
	if node is Control and node.has_meta("native_font_resource"):
		var font_name: String=str(node.get_meta("native_font_resource"))
		if frame.fonts.failed.has(font_name): fail("Original player font unavailable: "+font_name); return false
		if str(node.get_meta("native_font_applied",""))!=font_name: return false
	for child in node.get_children():
		if not art_and_font_ready(child): return false
	return true
func admission_ready() -> bool:
	if closed or rendering or not layout_ready or not popup.layout_ready or not failure.is_empty(): return false
	if is_instance_valid(bar) and not bar.art_ready:
		if not bar.failure.is_empty(): fail(bar.failure)
		return false
	for entry in images.values():
		var target: Object=entry.target.get_ref()
		if not is_instance_valid(target) or target.is_queued_for_deletion(): continue
		if frame.art.failed.has(entry.key): fail("Original player image unavailable: "+str(entry.key)); return false
		if not frame.art.textures.has(entry.key) or target.texture!=frame.art.textures[entry.key]: return false
	for data in frame.button_geometry.values():
		var control: Button=data.control
		if not is_instance_valid(control) or not (stage.is_ancestor_of(control) or popup.panel.is_ancestor_of(control)): continue
		for pair in data.styles.values():
			var key: String=frame.art.models.model_key(str(data.resource),str(pair[1]),data.overrides)
			if frame.art.failed.has(key): fail("Original player button art unavailable: "+key); return false
			if not frame.art.textures.has(key) or pair[0].texture!=frame.art.textures[key]: return false
	return art_and_font_ready(stage) and art_and_font_ready(popup.panel)
func try_admit() -> void:
	if closed or not panel.wanted or panel.visible: return
	if admission_ready():
		panel.show(); panel.move_to_front(); panel._clamp()
func make_label(parent: Control,entry: Dictionary,value: String) -> Label:
	var label: Label=frame.create_label(entry,parent); label.text=value; return label
func reskin(button: Button,icon: String) -> void:
	var data: Dictionary=frame.button_geometry[button.get_instance_id()]; var overrides: Dictionary={"gui_replace01":icon}
	if data.overrides==overrides: return
	data.overrides=overrides
	for pair in data.styles.values(): frame.art.bind(pair[0],data.resource,"texture",true,pair[1],false,overrides)
	frame.update_button(button.get_instance_id())
func button(control: Button,entry: Dictionary,parent: Control,checkbox: bool=false) -> void:
	frame.button(control,entry,parent,models,false,checkbox)
	if not checkbox: return
	var data: Dictionary=frame.button_geometry[control.get_instance_id()]; var clips: Array=models[str(entry.resource)].get("animations",[])
	for pair in [["hover","hilite"],["hover_checked","checkedhilite"]]:
		if not clips.any(func(clip):return str(clip.name).to_lower()==pair[1]): continue
		data.styles[pair[0]][1]=pair[1]; frame.art.bind(data.styles[pair[0]][0],str(entry.resource),"texture",true,pair[1],false,entry.get("overrides",{}))
func activate() -> void:
	panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.size; panel.size=definition.size
	stage=Control.new(); panel.add_child(stage); stage.size=definition.size; stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; picture(stage,definition.main.resource,definition.main.rect)
	for tag in ["tguilabel","tguilabel1","tguilabel2","tguilabel3","pvpsettinglabel"]:
		var entry: Dictionary=definition.entries[tag]; var label:=make_label(stage,entry,desktop.owner_ui.text.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}))
		if tag=="tguilabel3": label.mouse_filter=Control.MOUSE_FILTER_STOP; label.gui_input.connect(panel._title_input)
		if tag=="pvpsettinglabel": pvp_label=label; pvp_label.clip_text=false
	for tag in Plan.BUTTONS:
		var button:=Button.new(); stage.add_child(button); var entry: Dictionary=definition.entries[tag].duplicate(true); entry.overrides={"gui_replace01":entry.icon}; self.button(button,entry,stage,true); buttons[tag]=button
		button.tooltip_text=desktop.owner_ui.text.raw({"strRef":int(entry.tooltip)}); button.button_down.connect(func():captured[tag]=action_context()); button.pressed.connect(func():invoke(tag))
		# CNetLayer privilege0x40 is not disclosed by the current bridge. Do not
		# infer administrator permission from DM status or fabricate these actions.
		if tag in ["bootbutton","banbutton"]: button.hide()
	var close: Button=panel.close_button; frame.button(close,definition.entries.xbutton,stage,models,false)
	scroll=ScrollContainer.new(); stage.add_child(scroll); scroll.position=definition.view.position; scroll.size=definition.view.size; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tree=Control.new(); scroll.add_child(tree); tree.mouse_filter=Control.MOUSE_FILTER_IGNORE; tree.custom_minimum_size=Vector2(definition.view.size.x,0)
	bar=Bar.new(); stage.add_child(bar); bar.configure(frame,models,definition.scroll,scroll,definition.row_step.y)
	help_label=make_label(stage,{"rect":Rect2(0,definition.size.y+4,definition.size.x,24),"caption":{"AurString_Font":"fnt_galahad14"}},"")
	layout_ready=true; render(); panel._clamp()
func rows() -> Array:
	var result: Array=[]; var attitudes: Dictionary={}
	for pair in desktop.state.get("playerAttitudes",[]): attitudes[int(pair[0])]=pair[1]
	for pair in desktop.state.get("players",[]):
		var player: Dictionary=pair[1]; var target:=int(player.get("objectId",-1)); var character: Dictionary=player.get("character",{}); var pc:=int(character.get("id",-1))
		if target==desktop.actor_id or pc==desktop.actor_id or bool(player.get("isDM",player.get("dm",false))): continue
		var attitude: Dictionary=attitudes.get(int(pair[0]),{}); var object: Dictionary=desktop.objects.get(pc,{})
		result.append({"entryId":result.size(),"playerId":int(pair[0]),"objectId":target,"characterId":pc,"label":preload("res://systems/native_data/chat_reply.gd").character_name(player,desktop.owner_ui.text),"account":str(player.get("name","")),"dm":false,"self":false,"member":desktop.state.get("party",[]).any(func(row):return int(row.id)==pc),"ownLikes":int(attitude.get("ownLikes",1)),"incomingLikes":int(attitude.get("incomingLikes",1)),"reaction":reaction(object)})
	return result
func row_entry(source: Dictionary,origin: Vector2) -> Dictionary:
	var entry:=source.duplicate(true); entry.offset-=origin; entry.rect.position-=origin; return entry
func clear_cards() -> void:
	for card in cards.values(): card.button.get_parent().remove_child(card.button); card.button.queue_free()
	cards.clear()
func render() -> void:
	if not layout_ready: return
	rendering=true
	var present: Dictionary={}
	for row in panel.rows: present[int(row.playerId)]=row
	for id in cards.keys():
		if not present.has(id): cards[id].button.get_parent().remove_child(cards[id].button); cards[id].button.queue_free(); cards.erase(id)
	selected=mini(selected,panel.rows.size()-1) if not panel.rows.is_empty() else -1
	if selected<0 and not panel.rows.is_empty(): selected=panel.rows.size()-1
	for index in panel.rows.size():
		var row: Dictionary=panel.rows[index]; var id:=int(row.playerId); var origin: Vector2=definition.view.position-definition.row_step*index
		if not cards.has(id):
			var button:=Button.new(); tree.add_child(button); button.toggle_mode=true; self.button(button,row_entry(definition.row,origin),tree,true)
			var name_entry: Dictionary={"rect":Rect2(definition.name_rect.position-definition.row.rect.position,definition.name_rect.size),"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignV":0.5}}
			var name:=make_label(button,name_entry,""); var attitude:=Button.new(); button.add_child(attitude); attitude.toggle_mode=true; self.button(attitude,row_entry(definition.attitude,definition.row.rect.position),button,true)
			var caption:=make_label(attitude,{"rect":Rect2(6,0,55,25),"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignV":0.5}},"")
			var reaction:=make_label(button,{"rect":Rect2(245,0,80,29),"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignV":0.5,"AurString_AlignH":1}},"")
			var card: Dictionary={"button":button,"attitude":attitude,"name":name,"caption":caption,"reaction":reaction,"id":id}; cards[id]=card
			button.pressed.connect(func():if valid_card(card): select_player(id,true))
			attitude.pressed.connect(func():if valid_card(card): attitude_click(id))
		var card: Dictionary=cards[id]; var data: Dictionary=frame.button_geometry[card.button.get_instance_id()]; var entry:=row_entry(definition.row,origin); data.offset=entry.offset; data.rect=entry.rect; frame.update_button(card.button.get_instance_id())
		card.name.text=row.label; card.button.set_pressed_no_signal(index==selected); reskin(card.button,"gui_ig_happyface" if row.incomingLikes!=0 else "gui_ig_madface")
		card.attitude.set_pressed_no_signal(row.ownLikes==0); card.attitude.disabled=row.member or not pending.is_empty(); card.caption.text=desktop.owner_ui.text.raw({"strRef":0xf93b if row.member else 7999})
		var refs: Dictionary={0:0x1918,1:0x1919,2:0x1917}; var colors: Dictionary={0:Color(0.26,0.29,0.8),1:Color(0.16,0.59,0.06),2:Color(0.83,0.14,0.09)}; card.reaction.text=desktop.owner_ui.text.raw({"strRef":int(refs.get(row.reaction,0x1076b))}); card.reaction.add_theme_color_override("font_color",colors.get(row.reaction,Color(0.5,0.5,0.5)))
	tree.custom_minimum_size.y=maxf(0,definition.row.rect.position.y-definition.view.position.y+definition.row.rect.size.y+maxi(0,panel.rows.size()-1)*definition.row_step.y); update_actions()
	var pvp:=int(desktop.state.get("area",{}).get("pvp",-1)); var refs: Dictionary={0:0x1f53,1:0x1f52,2:0x1f54}; pvp_label.text=desktop.owner_ui.text.raw({"strRef":0x1f51})+": "+desktop.owner_ui.text.raw({"strRef":refs[pvp]}) if refs.has(pvp) else ""
	rendering=false; try_admit()
func valid_card(card: Dictionary) -> bool: return panel.wanted and cards.get(card.id)==card and is_instance_valid(card.button) and card.button.is_inside_tree()
func selected_row() -> Dictionary: return panel.rows[selected] if selected>=0 and selected<panel.rows.size() else {}
func select_player(id: int,notify: bool) -> void:
	for index in panel.rows.size():
		if int(panel.rows[index].playerId)!=id: continue
		selected=index; render()
		if notify: send("native-players",{"operation":"select","playerId":id,"targetId":int(panel.rows[index].characterId)})
		return
func action_context() -> Dictionary:
	var row:=selected_row(); return {"scope":scope(),"view":panel.view_id,"id":int(row.get("playerId",-1)),"target":int(row.get("objectId",-1)),"character":int(row.get("characterId",-1)),"inviter":invitation()}
func update_actions() -> void:
	var row:=selected_row(); var invited:=invitation()>=0; var member:=bool(row.get("member",false)); var leader:=bool(flags().get("leader",false))
	var states: Dictionary={"invitebutton":["ir_accept",0x1051d,invited],"leavebutton":["ir_reject",0x1051c,invited],"transferbutton":["ir_ignore",0x1051b,invited],"tellbutton":["ir_chat",0x104db,not row.is_empty()]}
	if not invited:
		states.invitebutton=["ir_kick" if member else "ir_invite",0x42c if member else 0x42b,not row.is_empty() and (not member or leader)]
		states.leavebutton=["ir_leave",0x42f,member]; states.transferbutton=["ir_transleader",0x18ef,member and leader]
	for tag in states:
		reskin(buttons[tag],states[tag][0]); buttons[tag].tooltip_text=desktop.owner_ui.text.raw({"strRef":int(states[tag][1])}); buttons[tag].disabled=not states[tag][2] or not pending.is_empty()
func invoke(tag: String) -> void:
	if not panel.wanted or not layout_ready or not buttons.has(tag) or buttons[tag].disabled: return
	var now:=action_context(); var began: Dictionary=captured.get(tag,now); captured.erase(tag)
	if began!=now: return
	var row:=selected_row(); var invited:=invitation()>=0
	if tag=="tellbutton":
		send("native-players",{"operation":"tell","playerId":int(row.playerId),"targetId":int(row.objectId)}); desktop.owner_ui.chat.prime_tell(row.label); return
	var operation: String={"invitebutton":"accept","leavebutton":"reject","transferbutton":"ignore"}.get(tag,"") if invited else {"invitebutton":"kick" if row.get("member",false) else "invite","leavebutton":"leave","transferbutton":"transfer"}.get(tag,"")
	if operation.is_empty(): return
	var message: Dictionary={"operation":operation}
	if invited: message.targetId=invitation()
	else: message.playerId=int(row.playerId); message.targetId=int(row.characterId)
	send("native-party",message)
func attitude_click(id: int) -> void:
	if not pending.is_empty(): render(); return
	select_player(id,true); var row:=selected_row()
	if row.get("member",false): return
	send("native-player-attitude",{"playerId":id,"likes":int(row.ownLikes)==0}); render()
func send(kind: String,value: Dictionary,from_popup: bool=false) -> void:
	serial+=1; var message:=value.duplicate(); message.kind=kind; message.requestId=serial; pending[serial]={"scope":scope(),"view":panel.view_id,"operation":value.get("operation",""),"popup":from_popup}; desktop.command(message)
	if layout_ready: update_actions()
func receive(message: Dictionary) -> void:
	var id:=int(message.get("requestId",-1))
	if not pending.has(id): return
	var current: Dictionary=pending[id]
	if current.scope!=scope() or current.scope!=[int(message.get("generation",-1)),int(message.get("areaId",-1)),int(message.get("actorId",-1))]: return
	pending.erase(id)
	if not message.get("accepted",false): help_label.text=str(message.get("text","Player action could not be sent."))
	render(); popup.receive(message)
func reset_view() -> void:
	pending.clear(); captured.clear(); selected=-1
	if layout_ready: clear_cards()
	if is_instance_valid(popup): popup.reset_view()
func snapshot() -> Dictionary: return {"ready":layout_ready,"admitted":panel.visible,"art_ready":admission_ready(),"failure":failure,"pending_assets":jobs.size(),"rows":cards.size(),"selected":selected,"pending_actions":pending.size(),"native_only":true,"full_players_parity":false,"popup":popup.snapshot()}
func close() -> void:
	if closed: return
	closed=true; reset_view(); images.clear(); jobs.clear(); assets.close(); popup.close()
	if is_instance_valid(bar): bar.close()
	if frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	if frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
func _exit_tree() -> void: close()
