extends Control
# CPlayModulePanel710720/715400/70dae0: native presentation of received data.
const Sheet=preload("res://systems/native_data/character_sheet_layout.gd")
const Plan=preload("res://systems/native_data/character_lobby_layout.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const INFO_FONT="ttf fnt_default 14" # CTlkTable default pointer14128f1d8.
const Values=preload("res://systems/native_data/character_record_values.gd")
var frame
var data_art
var text_owner
var rules:=Rules.new()
var models: Dictionary={}
var definition: Dictionary={}
var info: Control
var info_scroll: ScrollContainer
var info_text: RichTextLabel
var players: Control
var player_scroll: ScrollContainer
var player_content: Control
var player_bar
var rows: Array=[]
var player_geometry: Dictionary={}
var info_signature:=""
var player_signature:=""
var failure:=""
var closed:=false
func control(parent: Control,rect: Rect2) -> Control:
	var target:=Control.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.position=rect.position; target.size=rect.size; return target
func configure(painter,text,plan: Dictionary,source: Dictionary) -> void:
	frame=painter; data_art=painter.art; text_owner=text; rules.text=text; definition=plan; models=source; mouse_filter=Control.MOUSE_FILTER_IGNORE; size=definition.models.pmod_details800.bounds.size
	info=control(self,Rect2(Vector2.ZERO,size)); players=control(self,Rect2(Vector2.ZERO,size))
	frame.image("pmod_details800",definition.models.pmod_details800.bounds,info)
	var data: Dictionary=definition.models.pmod_details800
	if not data.hooks.has("text0") or not data.hooks.has("text1"): failure="Original lobby server information text hooks are missing"; return
	var rect:=Sheet.box(data,"text0","text1")
	info_scroll=ScrollContainer.new(); info.add_child(info_scroll); info_scroll.position=rect.position; info_scroll.size=rect.size; info_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; info_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	info_text=Text.label({},rect.size.x); info_scroll.add_child(info_text); frame.font_style(info_text,{"AurString_Font":INFO_FONT})
	data=definition.models.ctl_pre_plyrlist
	for hook in ["top","bottom","listitem","scrollmin","scrollmax"]:
		if not data.hooks.has(hook): failure="Original lobby player list hook missing: "+hook; return
	frame.image("ctl_pre_plyrlist",data.bounds,players)
	rect=Rect2(data.hooks.top,data.hooks.bottom-data.hooks.top).abs()
	player_scroll=ScrollContainer.new(); players.add_child(player_scroll); player_scroll.position=rect.position; player_scroll.size=rect.size; player_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; player_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	player_content=control(player_scroll,Rect2(Vector2.ZERO,Vector2(rect.size.x,1))); player_content.custom_minimum_size=player_content.size
	player_geometry={"first":data.hooks.listitem-rect.position,"model":definition.models.ctl_pre_btn_plyr,"portrait":Plan.texture_bounds(models.ctl_pre_btn_plyr,"gui_replace01")}
	if not player_geometry.portrait.drawn: failure="Original lobby player portrait mesh is missing"; return
	var bar_entry:=Sheet.entry(definition.models,"ctl_pre_plyrlist",Vector2.ZERO); bar_entry.caption={}
	player_bar=preload("res://systems/native_scrollbar.gd").new(); players.add_child(player_bar); player_bar.configure(frame,models,bar_entry,player_scroll,float(player_geometry.model.hooks.next.y))
	if not player_bar.failure.is_empty(): failure=player_bar.failure; return
	info.hide(); players.hide()
func present(index: int,state: Dictionary,connection: int) -> void:
	if closed or not failure.is_empty(): return
	info.visible=index==1; players.visible=index==2
	# Hidden pages have no display work. Text/table publication increments the
	# owner's revision; do not serialize entire class/portrait tables per click.
	if index not in [1,2]: return
	var signature:=JSON.stringify([connection,state.get("serverInfo",{}),state.get("endpoint",{}),text_owner.revision]) if index==1 else ""
	if index==1 and signature!=info_signature:
		var endpoint: Dictionary=state.endpoint if state.get("endpoint") is Dictionary else {}
		Text.set_text(info_text,Rich.parse(format_info(state.get("serverInfo",{}),endpoint))); info_scroll.scroll_vertical=0; info_signature=signature
	if index!=2: return
	signature=JSON.stringify([connection,state.get("players",[]),text_owner.revision])
	if signature!=player_signature: rebuild_players(state.get("players",[])); player_signature=signature
func format_info(data: Dictionary,endpoint: Dictionary) -> String:
	var lines: Array=[]
	if data.has("moduleName"):
		lines.append(text_owner.raw({"strRef":0x1fc7})+": "+str(data.moduleName))
		lines.append(text_owner.raw({"strRef":0x1fc8})+": "+Values.integer_text(data.get("playerCount"))+" / "+Values.integer_text(data.get("maximumPlayers")))
		lines.append(text_owner.raw({"strRef":0x1fc9})+": "+Values.integer_text(data.get("minimumLevel"))+" - "+Values.integer_text(data.get("maximumLevel")))
		lines.append(text_owner.raw({"strRef":0x1fcb})+": "+str(data.get("address",endpoint.get("host","")))+":"+Values.integer_text(endpoint.get("port")))
		var pvp:=int(data.get("pvpSetting",-1)); var value: String=text_owner.raw({"strRef":[0x1f54,0x1f52,0x1f53][pvp]}) if pvp>=0 and pvp<=2 else ""
		lines.append(text_owner.raw({"strRef":0x1f51})+": "+value)
		if not str(data.get("serverVersion","")).is_empty(): lines.append(text_owner.raw({"strRef":0x10494})+": "+str(data.serverVersion))
	var status:=int(data.get("serverStatus",-1)); var value: String=text_owner.raw({"strRef":[0xcf4a,0xcf4b,0xcf4c][status]}) if status>=0 and status<=2 else ""
	lines.append(text_owner.raw({"strRef":0xcf49})+": "+value)
	return "\n".join(lines)+"\n"
func row_label(button: Button,rect: Rect2,value: String) -> Label:
	var label: Label=frame.create_label({"rect":rect,"caption":Plan.CAPTION},button); label.text=value; label.modulate=Color(0.5,0.5,0.5); return label
func rebuild_players(values: Array) -> void:
	for row in rows: row.free()
	rows.clear()
	var model: Dictionary=player_geometry.model
	for data in values:
		var offset: Vector2=player_geometry.first+model.hooks.next*rows.size(); var entry:=Sheet.entry(definition.models,"ctl_pre_btn_plyr",offset)
		var button: Button=frame.create_button(entry,player_content,models,true); button.disabled=true
		var point: Vector2=offset-entry.rect.position; var name: String=text_owner.name({"firstName":data.get("firstName",{}),"lastName":data.get("lastName",{})},int(data.id))
		row_label(button,Sheet.box(model,"text0","text1",point),name)
		var classes:=""
		for item in data.get("classes",[]): classes+=rules.title("classes",int(item.id))+"("+Values.integer_text(item.get("level"))+") "
		row_label(button,Sheet.box(model,"label0","label1",point),classes)
		var portrait:=TextureRect.new(); button.add_child(portrait); portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_SCALE
		var rect: Rect2=player_geometry.portrait.bounds; portrait.position=point+rect.position; portrait.size=rect.size; data_art.bind_portrait(portrait,rules.portrait({"replicated":data},1))
		button.set_meta("player_id",int(data.id)); rows.append(button)
	player_content.custom_minimum_size=Vector2(player_scroll.size.x,maxf(1,float(model.hooks.next.y)*rows.size())); player_content.size=player_content.custom_minimum_size
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(player_bar): player_bar.close()
	frame=null; data_art=null; text_owner=null; models={}
func _exit_tree() -> void: close()
