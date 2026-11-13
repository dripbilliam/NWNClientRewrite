extends Control
# Shared source-only mode-zero sheet. Callers own data, availability, page
# selection and scoped input tickets; this view never saves or sends a packet.
signal page_down(index: int)
signal page_pressed(index: int)
const Plan=preload("res://systems/native_data/character_summary_layout.gd")
const Sheet=preload("res://systems/native_data/character_sheet_layout.gd")
var frame
var text_owner
var definition: Dictionary={}
var tabs: Array=[]
var pages: Array=[]
var statistics: Control
var labels: Dictionary={}
var ability_labels: Dictionary={}
var portrait: TextureRect
var detail: RichTextLabel
var detail_scroll: ScrollContainer
var detail_bar
var failure:=""
var closed:=false
func configure(painter,text,source: Dictionary,extent: Vector2=Vector2.ZERO) -> void:
	frame=painter; text_owner=text; definition=Plan.parse(source,extent)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	size=definition.size; clip_contents=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	var models: Dictionary=definition.models; var header: Dictionary=models.pnl_chrsht2; var body: Dictionary=models.pnl_chrsht_char2; var origin: Vector2=definition.page_origin
	frame.image("pnl_chrsht2",header.bounds,self)
	# Original CTL_CHRSHT_NOSIZ is fixed and IgnoreHitCheck, with no drag/close.
	frame.image("ctl_chrsht_nosiz",definition.footer.rect,self)
	var group:=ButtonGroup.new()
	for index in 4:
		var tab: Button=frame.create_button(definition.tabs[index],self,source,true); tab.button_group=group; tab.set_pressed_no_signal(index==0); tabs.append(tab)
		tab.button_down.connect(func():page_down.emit(index)); tab.pressed.connect(func():page_pressed.emit(index))
	statistics=control(self,Rect2(Vector2.ZERO,size)); pages.append(statistics)
	for index in range(1,4):
		var page:=control(self,Rect2(origin,definition.page_size)); page.clip_contents=true; page.hide(); pages.append(page)
	var background:=picture(statistics,Rect2(origin,definition.page_size)); frame.art.bind(background,"pnl_chrsht_char2","texture",true,"",false,{},Rect2(Vector2.ZERO,definition.page_size))
	portrait=picture(statistics,Rect2(origin+Vector2(1,0),Vector2(128,200)))
	labels.title=label(self,Sheet.box(header,"title0","title1"))
	labels.classes=label(statistics,Sheet.box(body,"racealignclass0","racealignclass1",origin)); labels.classes.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	for item in Plan.ABILITIES:
		ability_labels[item[0]]=label(statistics,Sheet.box(body,"l"+item[1]+"0","l"+item[1]+"1",origin))
		for suffix in ["stat","mod"]: labels[item[0]+suffix]=label(statistics,Sheet.box(body,item[0]+suffix+"0",item[0]+suffix+"1",origin))
		var icon:=picture(statistics,Rect2(origin+body.hooks[item[0]+"icon"]-Vector2(8,8),Vector2(16,16))); frame.art.bind(icon,"gui_chrsht_"+item[0])
	for tag in ["armorclass","hitpoints","experience","nextlevel","lac","lhp"]: labels[tag]=label(statistics,Sheet.box(body,tag+"0",tag+"1",origin))
	var detail_model: Dictionary=models.ctl_chrsht_lstbx.duplicate(true); var offset: Vector2=origin+body.hooks.list
	detail_model.hooks.text1.y=definition.page_size.y-body.hooks.list.y; detail_model.hooks.scrollmax.y=detail_model.hooks.text1.y-14
	var rect:=Sheet.box(detail_model,"text0","text1",offset)
	detail_scroll=ScrollContainer.new(); statistics.add_child(detail_scroll); detail_scroll.position=rect.position; detail_scroll.size=rect.size; detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	detail=preload("res://systems/server_text.gd").label({},rect.size.x); detail_scroll.add_child(detail); detail.custom_minimum_size.x=rect.size.x; frame.font_style(detail,{"AurString_Font":"ttf fnt_default 14"})
	detail_bar=preload("res://systems/native_scrollbar.gd").new(); statistics.add_child(detail_bar); detail_bar.configure(frame,source,{"offset":offset,"model":detail_model,"caption":{"AurString_Font":""}},detail_scroll,20)
	if not detail_bar.failure.is_empty(): failure=detail_bar.failure; return
	frame.fonts.loaded.connect(detail_font_loaded); detail_font_loaded("ttf fnt_default 14"); refresh_captions()
func control(parent: Control,rect: Rect2) -> Control:
	var target:=Control.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.position=rect.position; target.size=rect.size; return target
func picture(parent: Control,rect: Rect2) -> TextureRect:
	var target:=TextureRect.new(); parent.add_child(target); target.position=rect.position; target.size=rect.size; target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; target.mouse_filter=Control.MOUSE_FILTER_IGNORE; return target
func label(parent: Control,rect: Rect2) -> Label:
	return frame.create_label({"rect":rect,"caption":{"AurString_Font":"fnt_galahad14"}},parent)
func refresh_captions() -> void:
	if closed or not failure.is_empty(): return
	for index in tabs.size(): tabs[index].tooltip_text=text_owner.raw({"strRef":Plan.TAB_REFS[index]})
	for item in Plan.ABILITIES: ability_labels[item[0]].text=text_owner.raw({"strRef":item[2]})
func set_page(index: int) -> void:
	if closed or not failure.is_empty() or index<0 or index>=pages.size(): return
	for at in pages.size(): pages[at].visible=at==index; tabs[at].set_pressed_no_signal(at==index)
func present_values(values: Dictionary) -> void:
	if closed or not failure.is_empty(): return
	for key in labels:
		var value: Dictionary=values.get(key,{})
		labels[key].text=str(value.get("text",""))
		labels[key].add_theme_color_override("font_color",preload("res://systems/native_data/character_record_values.gd").tone(int(value.get("adjustment",0))))
func clear_values(prefix: String="") -> void:
	present_values({"title":{"text":prefix+", "}} if not prefix.is_empty() else {})
func detail_font_loaded(name: String) -> void:
	if closed or name!="ttf fnt_default 14" or not is_instance_valid(detail) or not frame.fonts.fonts.has(name): return
	# Original AddItem spacing is20px, independent of the dialog font's height.
	var font: Font=frame.fonts.fonts[name]; detail.add_theme_constant_override("line_separation",20-ceili(font.get_height(14)))
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(detail_bar): detail_bar.close()
	if is_instance_valid(frame):
		if is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(detail_font_loaded): frame.fonts.loaded.disconnect(detail_font_loaded)
		for tab in tabs:
			if is_instance_valid(tab):
				if is_instance_valid(frame.tooltips): frame.tooltips.unregister_control(tab)
				frame.button_geometry.erase(tab.get_instance_id())
	frame=null; text_owner=null
func _exit_tree() -> void: close()
