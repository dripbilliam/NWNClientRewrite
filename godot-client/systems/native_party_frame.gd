extends Node
# Source model geometry over the existing received party/action owner.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/party_bar_layout.gd")
const Status=preload("res://systems/native_status_bar.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
const Locator=preload("res://systems/native_party_locator.gd")
const Bearing=preload("res://systems/native_data/party_locator.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var panel
var frame
var text_owner
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var stage: Control
var member_bar
var last_bar_height:=-1.0
var leader: TextureRect
var locator_context: Callable
func configure(target,catalog,cache_path: String,text,painter) -> void:
	panel=target; panel.native_skin=self; frame=painter; text_owner=text
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	frame.fonts.loaded.connect(font_loaded)
func _process(_delta: float) -> void:
	if layout_ready:
		if not closed and panel.visible:
			var began:=Timing.begin(); update_locators(); Timing.finish("hud_party_locators_ms",began)
		return
	if closed or requested or not panel.visible: return
	requested=true; set_process(false)
	for name in Plan.RESOURCES:
		var id: int=assets.request(name,2002,"actor-model" if name in ["scrollbar_simple","pb_mbr_pos"] else "mdl-original")
		if id<0: failure=str(assets.failure); return
		jobs[id]=name
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	activate()
func activate() -> void:
	layout_ready=true; stage=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	leader=image("ctl_party_leader",Vector2.ZERO,stage); leader.name="NativeLeader"; leader.hide()
	panel.column.add_theme_constant_override("separation",0)
	for row in panel.rows:
		var card: Control=panel.cards[int(row.entryId)]
		if row.self: card.reparent(stage,false)
		update_card(row)
	place()
func card_parent(row: Dictionary) -> Node: return stage if row.self else panel.column
func manual_box(previous: Control) -> Control:
	var parent: Node=previous.get_parent(); var name: String=previous.name; parent.remove_child(previous)
	var box:=Control.new(); box.name=name; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(box)
	for child in previous.get_children(): child.reparent(box,false)
	previous.queue_free(); return box
func image(resource: String,offset: Vector2,parent: Control,bind_image: bool=true) -> TextureRect:
	var result:=TextureRect.new(); parent.add_child(result); parent.move_child(result,0); result.mouse_filter=Control.MOUSE_FILTER_IGNORE; result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; result.stretch_mode=TextureRect.STRETCH_SCALE
	var rect: Rect2=definition.models[resource].bounds; result.position=offset+rect.position; result.size=rect.size
	if bind_image: frame.art.bind(result,resource,"texture",true,"")
	return result
func update_card(row: Dictionary) -> void:
	if not layout_ready or closed or not panel.cards.has(int(row.entryId)): return
	var card: PanelContainer=panel.cards[int(row.entryId)]; var box: Control=card.get_node("Box")
	if not card.has_meta("native_party_frame"):
		card.set_meta("native_party_frame",true); card.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		box=manual_box(box)
		var entry: Dictionary=definition.portrait if row.self else definition.member_portrait; var button: Button=box.get_node("Portrait")
		frame.relocate(button,box,entry.rect); button.add_theme_stylebox_override("normal",StyleBoxEmpty.new()); button.add_theme_stylebox_override("hover",StyleBoxEmpty.new()); button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new()); button.add_theme_stylebox_override("disabled",StyleBoxEmpty.new()); button.add_theme_font_size_override("font_size",1)
		card.custom_minimum_size=Vector2(80,definition.members.y) if row.self else Vector2(63,definition.row_height)
		card.size=card.custom_minimum_size
		image("pnl_party_bar" if row.self else "pb_pnl_member",Vector2.ZERO,box)
		var status:=Status.new(); status.name="NativeHealth"; box.add_child(status); status.configure(frame.art,"ctl_playr_health" if row.self else "ctl_party_health",definition.models.pnl_party_bar.hooks.health if row.self else definition.models.pb_pnl_member.hooks.health)
		var name: Label=box.get_node("Name"); name.visible=not row.self
		if not row.self:
			image("pb_nametag",definition.models.pb_pnl_member.hooks.text,box)
			frame.label(name,{"rect":Rect2(Vector2.ZERO,Vector2(62,14)),"caption":{"AurString_Font":Plan.FONT,"AurString_AlignH":0.0,"AurString_AlignV":1.0,"AurString_ColorR":0.8,"AurString_ColorG":0.8,"AurString_ColorB":0.8}},box)
			var indicator:=image("pb_mbr_state",definition.models.pb_pnl_member.hooks.properties,box,false); indicator.name="NativeState"; box.move_child(indicator,box.get_child_count()-1); indicator.hide()
			var locator:=Locator.new(); locator.name="NativeLocator"; box.add_child(locator); locator.configure(models.pb_mbr_pos,frame.art,definition.models.pb_pnl_member.hooks.pos)
		if row.self:
			var actions:=manual_box(box.get_node("Actions")); actions.size=Vector2(80,definition.members.y)
			for action in panel.actions:
				if not definition.actions.has(str(action.id)): continue
				var control: Button=actions.get_node("Action%s"%int(action.index)); var data: Dictionary=definition.actions[str(action.id)]; frame.button(control,data,actions,models,false); control.tooltip_text=text_owner.raw({"strRef":int(data.tooltip)})
			var level: Button=box.get_node("Level"); frame.button(level,definition.level,box,models,false); level.tooltip_text=text_owner.raw({"strRef":0x209a})
	box.get_node("Health").hide()
	var portrait: Button=box.get_node("Portrait"); portrait.tooltip_text=str(row.label)+( " %d/%d"%[row.health.current,row.health.maximum] if row.health is Dictionary else "")
	if is_instance_valid(frame.tooltips): frame.tooltips.register_control(portrait)
	box.get_node("NativeHealth").set_health(row.health)
	if row.self: box.get_node("Name").hide()
	else:
		set_process(true)
		layout_name(card)
		var indicator: TextureRect=box.get_node("NativeState"); var clip:=str(row.get("indicators",{}).get("state",""))
		indicator.visible=not clip.is_empty()
		if indicator.get_meta("native_state","")!=clip:
			indicator.set_meta("native_state",clip); frame.art.unbind(indicator); indicator.texture=null
			if not clip.is_empty(): frame.art.bind(indicator,"pb_mbr_state","texture",true,clip)
	update_leader()
func update_locators() -> void:
	var context: Dictionary=locator_context.call() if locator_context.is_valid() else {}
	for row in panel.rows:
		if row.self or not panel.cards.has(int(row.entryId)): continue
		var card: Control=panel.cards[int(row.entryId)]; var locator=card.get_node_or_null("Box/NativeLocator")
		if not is_instance_valid(locator): continue
		var rect:=card.get_global_rect()
		if context.is_empty() or not rect.intersects(panel.scroll.get_global_rect()): locator.hide(); continue
		var indicators: Dictionary=row.get("indicators",{})
		var value:=Bearing.decide(int(indicators.get("area",0x7f000000))==int(context.area),context.position.call(int(row.id)),context.actor,float(context.yaw),0.0,bool(locator.get_meta("native_unknown",false)))
		locator.set_meta("native_unknown",value.unknown)
		if value.unknown: locator.set_unknown()
		elif value.angle!=null: locator.set_angle(float(value.angle))
		else: locator.show()
func update_leader() -> void:
	if closed or not is_instance_valid(leader): return
	var target: Dictionary={}
	for row in panel.rows:
		if bool(row.get("indicators",{}).get("leader",false)): target=row; break
	if target.is_empty() or not panel.cards.has(int(target.entryId)):
		leader.hide(); return
	var box: Control=panel.cards[int(target.entryId)].get_node("Box")
	if leader.get_parent()!=box: leader.reparent(box,false)
	leader.position=(definition.portrait.offset if target.self else definition.member_portrait.offset)+definition.models.ctl_party_leader.bounds.position; leader.show()
func retire_card(card: Control) -> void:
	if not is_instance_valid(card) or not card.has_node("Box"): return
	var box: Control=card.get_node("Box")
	if is_instance_valid(leader) and leader.get_parent()==box:
		leader.reparent(stage,false); leader.hide()
	if box.has_node("NativeState"): frame.art.unbind(box.get_node("NativeState"))
	if box.has_node("NativeLocator"): box.get_node("NativeLocator").close()
	if box.has_node("NativeHealth"): box.get_node("NativeHealth").close()
	if box.has_node("Name"): frame.fonts.unbind(box.get_node("Name"))
func layout_name(card: Control) -> void:
	var label: Label=card.get_node("Box/Name"); var height:=label.get_minimum_size().y
	var point: Vector2=definition.models.pb_pnl_member.hooks.text+definition.models.pb_nametag.hooks.text
	label.position=point-Vector2(0,height); label.size=Vector2(62,height)
func font_loaded(name: String) -> void:
	if closed or not layout_ready or name!=Plan.FONT: return
	for card in panel.cards.values():
		if not card.get_meta("self",false) and card.has_meta("native_party_frame"): layout_name(card)
func place() -> void:
	if not layout_ready or closed: return
	var inverse: Transform2D=panel.get_parent().get_global_transform_with_canvas().affine_inverse(); var viewport: Rect2=panel.get_viewport_rect(); var lo: Vector2=inverse*viewport.position; var hi: Vector2=inverse*viewport.end
	panel.position=Vector2(hi.x-80,lo.y); panel.size=Vector2(80,hi.y-lo.y); stage.size=panel.size
	panel.scroll.position=definition.members; panel.scroll.size=Vector2(80,maxf(1,panel.size.y-definition.members.y-2))
	var count: int=panel.rows.filter(func(row):return not bool(row.self)).size(); var height:=minf(panel.scroll.size.y,float(count)*definition.row_height)
	if count==0:
		reset_view()
		return
	var model: Dictionary=definition.models.pnl_party_bar.duplicate(true); model.hooks.scrollmax=model.hooks.scrollmin+Vector2(0,maxf(3.01,height-26)); var entry:={"offset":Vector2.ZERO,"model":model,"caption":{}}
	if not is_instance_valid(member_bar):
		member_bar=Bar.new(); stage.add_child(member_bar); member_bar.configure(frame,models,entry,panel.scroll,definition.row_height)
	elif not is_equal_approx(height,last_bar_height): member_bar.relayout(entry)
	last_bar_height=height; member_bar.show()
func reset_view() -> void:
	if layout_ready: set_process(false)
	if is_instance_valid(leader):
		if leader.get_parent()!=stage: leader.reparent(stage,false)
		leader.hide()
	if is_instance_valid(member_bar): member_bar.close(); member_bar.queue_free(); member_bar=null
	last_bar_height=-1
func blocks_pointer(point: Vector2) -> bool:
	if not panel.visible: return false
	if is_instance_valid(member_bar) and member_bar.visible and member_bar.get_global_rect().has_point(point): return true
	for row in panel.rows:
		var card: Control=panel.cards.get(int(row.entryId))
		if not is_instance_valid(card): continue
		if row.self and card.get_global_rect().has_point(point): return true
		if not row.self and panel.scroll.get_global_rect().has_point(point) and card.get_global_rect().has_point(point): return true
	return false
func snapshot() -> Dictionary:
	var health: Array=[]
	for card in panel.cards.values():
		if card.has_node("Box/NativeHealth"): health.append(card.get_node("Box/NativeHealth").snapshot())
	var indicators: Array=[]
	for row in panel.rows: indicators.append({"id":row.id,"state":row.get("indicators",{}).get("state",""),"leader":row.get("indicators",{}).get("leader",false)})
	var locators: Array=[]
	for row in panel.rows:
		var control=panel.cards.get(int(row.entryId))
		if is_instance_valid(control) and control.has_node("Box/NativeLocator"):
			var locator=control.get_node("Box/NativeLocator")
			locators.append({"id":row.id,"area":row.get("indicators",{}).get("area",0x7f000000),"clip":locator.clip,"time":locator.time,"faces":locator.faces.size(),"poses":locator.poses,"raster":locator.resource,"texture_ready":locator.texture!=null,"failure":locator.failure})
	return {"ready":layout_ready,"failure":failure,"pending":jobs.size(),"health":health,"indicators":indicators,"locators":locators,"native_only":true,"full_party_parity":false}
func close() -> void:
	if closed: return
	closed=true; set_process(false); jobs.clear(); models.clear()
	if is_instance_valid(member_bar): member_bar.close()
	for card in panel.cards.values(): retire_card(card)
	if is_instance_valid(leader): frame.art.unbind(leader); leader.queue_free(); leader=null
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
func _exit_tree() -> void: close()
