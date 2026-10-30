extends Control
# Mode-zero CCharPageFeats: original model hooks, list/description and native
# BIC feat identities. This pregame owner never casts or changes server feats.
const Layout=preload("res://systems/native_data/character_sheet_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
var chooser
var frame
var models: Dictionary={}
var body: Control
var list: ScrollContainer
var description_scroll: ScrollContainer
var description: RichTextLabel
var rows: Array=[]
var entries: Array=[]
var bars: Array=[]
var signature:=""
var revision:=0
var selected:=-1
var held: Dictionary={}
var failure:=""
var closed:=false
var list_rect:=Rect2()
var page_kind:=2
var row_resource:="ctl_chr_btn_feat"
func configure(owner_ui,painter,source: Dictionary,extent: Vector2,kind: int=2) -> void:
	page_kind=kind; row_resource="ctl_chr_btn_skil" if kind==1 else "ctl_chr_btn_feat"
	chooser=owner_ui; frame=painter; models=source; size=extent; mouse_filter=Control.MOUSE_FILTER_IGNORE; clip_contents=true; hide()
	for pair in [["pnl_chrsht_skil2",["description","list"]],["ctl_chrsht_desc",["text0","text1","scrollmin","scrollmax"]],["ctl_chr_btnlstbx",["top","bottom","listitem","scrollmin","scrollmax"]],[row_resource,["icon","text","next"]+(["value"] if kind==1 else [])]]:
		for hook in pair[1]:
			if not models[pair[0]].hooks.has(hook): failure="Original pregame Feats hook missing: "+pair[0]+"/"+hook; return
	var picture:=TextureRect.new(); add_child(picture); picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; picture.position=Vector2.ZERO; picture.size=size; picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_SCALE
	frame.art.bind(picture,"pnl_chrsht_skil2","texture",true,"",false,{},Rect2(Vector2.ZERO,size))
	var layout: Dictionary=models.pnl_chrsht_skil2; var desc_model: Dictionary=models.ctl_chrsht_desc; var list_model: Dictionary=models.ctl_chr_btnlstbx
	description_scroll=scroll(Layout.box(desc_model,"text0","text1",layout.hooks.description))
	description=Text.label({},description_scroll.size.x); description_scroll.add_child(description); description.custom_minimum_size.x=description_scroll.size.x; description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; frame.font_style(description,Layout.CAPTION)
	add_bar(description_scroll,layout.hooks.description,desc_model,14,"fnt_galahad14")
	# Mode-zero HandleSetPage adds no in-game 0.11 inset. The list's bottom
	# meets its page bottom; SetHeightByAnchor puts scrollmax14 pixels above it.
	var sized: Dictionary=list_model.duplicate(true); sized.hooks.bottom.y=size.y-layout.hooks.list.y; sized.hooks.scrollmax.y=sized.hooks.bottom.y-14
	list_rect=Layout.box(sized,"top","bottom",layout.hooks.list); list=scroll(list_rect)
	add_bar(list,layout.hooks.list,sized,float(models[row_resource].hooks.next.y),"")
	body=Control.new(); list.add_child(body); body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func():if not is_visible_in_tree(): held.clear())
func scroll(rect: Rect2) -> ScrollContainer:
	var target:=ScrollContainer.new(); add_child(target); target.position=rect.position; target.size=rect.size; target.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; target.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS; return target
func add_bar(target: ScrollContainer,offset: Vector2,model: Dictionary,step: float,font: String) -> void:
	var bar:=Bar.new(); add_child(bar); bar.configure(frame,chooser.models,{"offset":offset,"model":model,"caption":{"AurString_Font":font}},target,step); bars.append(bar)
	if not bar.failure.is_empty(): failure=bar.failure
func scope() -> Array:
	return [chooser.owner_ui.connection,chooser.owner_ui.state.get("selected"),chooser.interaction_epoch,revision]
func present(value: Variant) -> void:
	if closed or not failure.is_empty(): return
	var next:=JSON.stringify([scope().slice(0,3),chooser.spell_projection if page_kind==3 else chooser.skill_projection if page_kind==1 else value.get("feats",[]) if value is Dictionary else [],value.get("bonusFeats",[]) if value is Dictionary else [],chooser.text_owner.revision])
	if next==signature: return
	signature=next; revision+=1; held.clear(); selected=-1; entries=[]; Text.set_text(description,{}); description_scroll.scroll_vertical=0; list.scroll_vertical=0
	for row in rows: row.free()
	rows.clear()
	if page_kind==3 and chooser.spell_projection.get("ready",false):
		entries=chooser.spell_projection.entries.duplicate(true)
		for entry in entries:
			if entry.summary: entry.name=chooser.text_owner.raw({"strRef":int(entry.nameRef)}); entry.description={}
			else:
				var data: Dictionary=chooser.rules.row("spells",int(entry.id)); entry.name=chooser.text_owner.raw({"strRef":chooser.rules.number(chooser.rules.cell(data,"Name"),4294967295)}); entry.icon=chooser.rules.icon("spells",int(entry.id)); entry.description=chooser.rules.description("spells",int(entry.id))
		entries=preload("res://systems/native_data/character_record_entries.gd").ordered(entries)
	elif page_kind==1 and chooser.skill_projection.get("ready",false):
		entries=chooser.skill_projection.entries.duplicate(true)
		for entry in entries:
			entry.name=chooser.rules.title("skills",int(entry.id)); entry.icon=chooser.rules.icon("skills",int(entry.id)); entry.description=chooser.rules.description("skills",int(entry.id))
		entries=preload("res://systems/native_data/character_record_entries.gd").ordered(entries)
	elif value is Dictionary and page_kind==2:
		entries=chooser.rules.record_entries({"inventoryStats":{"fields118":value.get("feats",[]),"fields128":value.get("bonusFeats",[])}},2)
	var model: Dictionary=models[row_resource]; var list_model: Dictionary=models.ctl_chr_btnlstbx; var offset: Vector2=list_model.hooks.listitem
	var group:=ButtonGroup.new()
	for index in entries.size():
		var entry: Dictionary=entries[index]; var button:=Button.new(); body.add_child(button); button.toggle_mode=true; button.button_group=group; frame.button(button,Layout.entry(models,row_resource,offset),body,chooser.models,false,true)
		button.button_down.connect(func():held[index]=scope()); button.pressed.connect(select.bind(index)); rows.append(button)
		var local: Vector2=-model.bounds.position; var icon:=TextureRect.new(); button.add_child(icon); icon.position=local+model.hooks.icon-Vector2(16,16); icon.size=Vector2(32,32); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; chooser.data_art.bind(icon,str(entry.icon))
		var name: Label=frame.create_label({"rect":Rect2(local+model.hooks.text-Vector2(0,17),Vector2(250 if page_kind==1 else 280,34)),"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignH":0.0,"AurString_AlignV":0.5}},button); name.text=str(entry.name)
		if page_kind==1:
			var value_label: Label=frame.create_label({"rect":Rect2(local+model.hooks.value-Vector2(16,17),Vector2(33,34)),"caption":Layout.CAPTION},button); value_label.text=str(int(entry.value))
			if entry.get("lostAbilities",false): value_label.add_theme_color_override("font_color",Color(1,0.1,0.1))
		offset+=model.hooks.next
	body.custom_minimum_size=Vector2(list.size.x,maxf(1,offset.y+model.bounds.position.y)); body.size=body.custom_minimum_size
func select(index: int) -> void:
	if closed or not is_visible_in_tree() or index<0 or index>=entries.size(): return
	var captured: Array=held.get(index,[]); held.erase(index)
	if captured!=scope() or not chooser.owner_ui.state.get("canSelect",false) or not chooser.owner_ui.native_selection.is_empty():
		for at in rows.size(): rows[at].set_pressed_no_signal(at==selected)
		return
	selected=index
	for at in rows.size(): rows[at].set_pressed_no_signal(at==selected)
	# The original summary has ID-1: GetSpell returns null, retaining prior help
	# and its scroll position while the radio selection itself still changes.
	if page_kind!=3 or not entries[index].get("summary",false): Text.set_text(description,entries[index].description); description_scroll.scroll_vertical=0
func close() -> void:
	if closed: return
	closed=true; held.clear()
	for bar in bars: if is_instance_valid(bar): bar.close()
	bars.clear(); rows.clear(); entries.clear(); chooser=null; frame=null
func _exit_tree() -> void: close()
