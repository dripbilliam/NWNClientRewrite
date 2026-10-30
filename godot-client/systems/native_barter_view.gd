extends "res://systems/draggable_panel.gd"
const Slot=preload("res://systems/native_barter_slot.gd")
const Grid=preload("res://systems/native_barter_grid.gd")
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
var owner_barter
var wanted:=false
var view_id:=0
var examine_mode:=false
var gold_owner
var stage: Control
var grids: Dictionary={}
var buttons: Dictionary={}
var captions: Dictionary={}
var item_buttons: Dictionary={}
var portraits: Dictionary={}
var notice: Label
var frame
var definition: Dictionary={}
func setup(owner,storage: String) -> void:
	owner_barter=owner; gold_owner=owner.owner_ui.inventory.gold; frame=owner.owner_ui.inventory.frame_skin
	configure("Barter","barter",Vector2(470,100),storage); close_hides=false; close_requested.connect(func():owner_barter.command("close")); hide()
func build(plan: Dictionary,models: Dictionary) -> void:
	definition=plan; window_column.hide(); add_theme_stylebox_override("panel",StyleBoxEmpty.new()); custom_minimum_size=plan.size; size=plan.size
	stage=Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(stage); stage.size=plan.size
	frame.image(plan.resource,Rect2(Vector2.ZERO,plan.size),stage)
	frame.label(heading,plan.entries.titletext,stage); heading.mouse_filter=Control.MOUSE_FILTER_STOP
	frame.button(close_button,plan.entries.xbutton,stage,models,false)
	for tag in ["leftacceptbut","rightacceptbut","leftdeclinebut","rightdeclinebut","leftcancelbut","examinebutton","goldbutton"]:
		var checkbox: bool=tag in ["leftacceptbut","rightacceptbut","leftdeclinebut","rightdeclinebut"]
		var button: Button=frame.create_button(plan.entries[tag],stage,models,checkbox); buttons[tag]=button
		var caption: Dictionary=plan.entries[tag].get("caption",{})
		if caption.has("Obj_StrRef"): captions[tag]=frame.button_caption(button,owner_barter.owner_ui.text.raw({"strRef":int(caption.Obj_StrRef)}))
		if tag.begins_with("right"): button.mouse_filter=Control.MOUSE_FILTER_IGNORE
	buttons.leftacceptbut.toggled.connect(func(value):owner_barter.command("accept",{"value":value}))
	buttons.leftdeclinebut.toggled.connect(func(value):owner_barter.command("lock",{"value":value}))
	buttons.leftcancelbut.pressed.connect(func():owner_barter.command("close"))
	buttons.examinebutton.pressed.connect(func():examine_mode=not examine_mode)
	buttons.goldbutton.pressed.connect(func():gold_owner.open(true))
	for side in ["B","A"]:
		var data: Dictionary=plan.own if side=="B" else plan.other
		frame.image("inv_box_3x10",data.art,stage)
		var grid:=Grid.new(); stage.add_child(grid); grid.owner_view=self; grid.side=side; grid.position=data.rect.position; grid.size=data.rect.size; grid.clip_contents=true; grids[side]=grid
	for tag in ["playerportrait","barratorportrait"]:
		var image:=TextureRect.new(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_SCALE; stage.add_child(image); image.position=plan.entries[tag].rect.position; image.size=plan.entries[tag].rect.size; portraits[tag]=image
	notice=Label.new(); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; notice.position=Vector2(0,size.y+4); notice.custom_minimum_size=Vector2(size.x,30); notice.add_theme_color_override("font_shadow_color",Color.BLACK); stage.add_child(notice)
func render(state: Dictionary,rows: Array,pending: Dictionary) -> void:
	if definition.is_empty(): return
	wanted=bool(state.get("open",false)); visible=wanted
	if not wanted: return
	view_id+=1; size=definition.size; stage.size=size
	var closing: bool=pending.has("close"); var lock_pending: bool=pending.has("lock"); var accept_pending: bool=pending.has("accept"); var item_pending:=false
	for key in pending:
		if str(key).begins_with("item:"): item_pending=true
	buttons.leftdeclinebut.set_pressed_no_signal(bool(state.ownLocked)); buttons.rightdeclinebut.set_pressed_no_signal(bool(state.otherLocked)); buttons.leftacceptbut.set_pressed_no_signal(bool(state.ownAccepted)); buttons.rightacceptbut.set_pressed_no_signal(bool(state.otherAccepted))
	buttons.leftdeclinebut.disabled=closing or lock_pending or item_pending
	buttons.leftacceptbut.disabled=closing or lock_pending or item_pending or accept_pending or not bool(state.ownLocked) or not bool(state.otherLocked)
	buttons.leftcancelbut.disabled=closing; close_button.disabled=closing; buttons.goldbutton.disabled=closing or bool(state.ownLocked) or lock_pending or gold_owner.balance()<=0
	for tag in captions: captions[tag].modulate=Color(0.6,0.6,0.6) if tag.begins_with("right") or buttons[tag].disabled else Color.WHITE
	var keep: Dictionary={}
	for row in rows:
		var id:=int(row.itemId); keep[id]=true; var button
		if item_buttons.has(id):
			button=item_buttons[id]
			if button.get_parent()!=grids[row.channel]: button.reparent(grids[row.channel],false)
			button.row=row; button.channel=str(row.channel); button.bound_view=view_id
		else:
			button=Slot.new(); grids[row.channel].add_child(button); button.setup(self,row); item_buttons[id]=button
			for style in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		button.disabled=bool(row.pending) or closing or row.channel=="B" and bool(state.ownLocked)
		button.position=Vector2(int(row.x)*33,(10-int(row.y)-int(row.height))*33); button.size=Vector2(int(row.width)*33-1,int(row.height)*33-1)
		var center:=Layout.icon_center(int(row.x),int(row.y),int(row.width),int(row.height)); button.native_icon_center=Vector2(center.x,330-center.y)-button.position; button.refresh_icon()
		button.count.text=str(int(row.stack)) if int(row.stack)>1 else ""; button.tooltip_text=str(row.name)
	for id in item_buttons.keys():
		if not keep.has(id): item_buttons[id].get_parent().remove_child(item_buttons[id]); item_buttons[id].queue_free(); item_buttons.erase(id)
	_clamp()
func select_item(id: int) -> void:
	if examine_mode: examine_mode=false; owner_barter.examine(id)
func operation(id: int,_operation: String) -> void:
	if owner_barter.own_rows.has(id): owner_barter.remove_item(id)
func item_menu(id: int,point: Vector2) -> void: owner_barter.item_menu(id,point)
