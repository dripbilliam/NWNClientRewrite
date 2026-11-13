extends Node
# One presentation for replacement-only menu controls. Original replicated
# panels retain their authored MDL layouts; this borrows their exact button,
# checkbox and arrow artwork and Galahad font for flexible client settings.
signal changed(value: Theme)
const FONT:="fnt_galahad14"
const SPECS={"button":"ctl_btn_pre_176","check":"ctl_chk_pre","up":"pb_scrl_up","down":"pb_scrl_down","close":"ctl_btn_x"}
const WHITE:=Color("eee6d2")
const GOLD:=Color("ac824a")
const DIM:=Color("777268")
const PICKER_GOLD=Color("d8b676")
const PICKER_IVORY=Color("eee5d1")
var frame
var keys: Dictionary={}
var images: Dictionary={}
var presentation_ready:=false
var closed:=false
var current: Theme
var entry_publication_active:=false
var entry_publication_dirty:=false
var entry_publication_building:=false
var entry_publication_windows: Array=[]
var entry_publication_index:=0
var entry_publication_touched: Array=[]
var entry_publication_visible_count:=0
var entry_publication_deferred_count:=0
var entry_publication_restarts:=0
static var _refresh_base_template: Theme
static func refresh_base_theme() -> Theme:
	# Entry and artwork callbacks compose the same large base Theme repeatedly.
	# Keep one private, bounded blueprint and deep-copy its mutable StyleBoxes;
	# base_theme() remains the public fresh-construction API.
	if _refresh_base_template==null:_refresh_base_template=base_theme()
	return _refresh_base_template.duplicate(true)
func begin_entry_publication() -> void:
	_discard_pending_entry_themes()
	entry_publication_active=true;entry_publication_dirty=true
	entry_publication_windows.clear();entry_publication_index=0
	entry_publication_visible_count=0;entry_publication_deferred_count=0;entry_publication_restarts=0
func _discard_pending_entry_themes() -> void:
	for window in entry_publication_touched:
		if is_instance_valid(window) and window.has_method("discard_pending_native_theme"):window.discard_pending_native_theme(get_instance_id())
	entry_publication_touched.clear()
func entry_publication_receipt() -> Dictionary:
	return {"visible_applies":entry_publication_visible_count,"hidden_deferrals":entry_publication_deferred_count,"restarts":entry_publication_restarts,"pending_hidden":entry_publication_touched.filter(func(window):return is_instance_valid(window) and window.pending_native_theme_source==get_instance_id()).size()}
func entry_publication_step() -> Dictionary:
	if closed or not entry_publication_active or not is_inside_tree():return {"done":true,"accepted":false}
	if entry_publication_dirty:
		if current!=null:entry_publication_restarts+=1
		entry_publication_dirty=false;entry_publication_building=true
		refresh()
		entry_publication_building=false
		entry_publication_windows=get_tree().get_nodes_in_group("native_client_windows")
		entry_publication_index=0
		return {"done":false}
	if entry_publication_index<entry_publication_windows.size():
		var window=entry_publication_windows[entry_publication_index]
		entry_publication_index+=1
		if is_instance_valid(window) and not window.is_queued_for_deletion():
			if window.has_method("stage_native_theme"):
				if window.stage_native_theme(current,get_instance_id()):
					entry_publication_deferred_count+=1
					if not entry_publication_touched.has(window):entry_publication_touched.append(window)
				else:entry_publication_visible_count+=1
			else:window.apply_native_theme(current);entry_publication_visible_count+=1
		return {"done":false}
	# A window can join or leave during a yielded entry. Reapply the final
	# theme in tree order if that changes the publication set.
	var actual: Array=get_tree().get_nodes_in_group("native_client_windows")
	if actual.size()!=entry_publication_windows.size():
		entry_publication_windows=actual;entry_publication_index=0
		return {"done":false}
	for index in actual.size():
		if actual[index]!=entry_publication_windows[index]:
			entry_publication_windows=actual;entry_publication_index=0
			return {"done":false}
	get_tree().set_meta("native_client_menu_theme",current)
	entry_publication_active=false;entry_publication_windows.clear()
	changed.emit(current)
	return {"done":true,"accepted":true}
static func for_tree(tree: SceneTree) -> Theme:
	return tree.get_meta("native_client_menu_theme") if tree!=null and tree.has_meta("native_client_menu_theme") else base_theme()
static func flat(fill: Color,border: Color=Color.TRANSPARENT,padding: float=0) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=fill; style.border_color=border; style.set_border_width_all(1 if border.a>0 else 0); style.set_content_margin_all(padding); return style
static func base_theme() -> Theme:
	var result:=Theme.new(); result.default_font_size=14
	for kind in ["Button","OptionButton","CheckBox","CheckButton","Label","LineEdit","TextEdit","PopupMenu","Tree","TabBar","TabContainer","RichTextLabel","ProgressBar","TooltipLabel"]:
		for name in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_selected_color","default_color"]: result.set_color(name,kind,WHITE)
		result.set_color("font_disabled_color",kind,DIM); result.set_color("font_unselected_color",kind,Color("b9ac91"))
		result.set_color("font_shadow_color",kind,Color.BLACK); result.set_constant("shadow_offset_x",kind,1); result.set_constant("shadow_offset_y",kind,1)
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			result.set_stylebox(state,kind,flat(Color("100d09"),GOLD if state in ["hover","focus"] else Color("665030"),8))
	for kind in ["PanelContainer","PopupMenu","TooltipPanel"]: result.set_stylebox("panel",kind,flat(Color("090a08f5"),GOLD,16 if kind=="PanelContainer" else 8))
	for kind in ["LineEdit","TextEdit"]:
		for state in ["normal","focus","read_only"]: result.set_stylebox(state,kind,flat(Color("070906"),GOLD if state=="focus" else Color("645334"),8))
		result.set_color("caret_color",kind,WHITE); result.set_color("selection_color",kind,Color("61502d"))
	for state in ["panel","tab_selected","tab_unselected","tab_hovered","tab_disabled","tab_focus"]: result.set_stylebox(state,"TabContainer",flat(Color("11120e") if state=="tab_selected" else Color("080a07"),GOLD if state in ["tab_selected","tab_focus"] else Color("55462e"),10))
	result.set_stylebox("panel","Tree",flat(Color("070906"),Color("645334"),6)); result.set_stylebox("selected","Tree",flat(Color("3f3521"),GOLD,2)); result.set_stylebox("selected_focus","Tree",flat(Color("4e4027"),GOLD,2))
	result.set_stylebox("background","ProgressBar",flat(Color("080a07"),Color("645334"),2)); result.set_stylebox("fill","ProgressBar",flat(Color("98733d")))
	for kind in ["HScrollBar","VScrollBar"]:
		result.set_stylebox("scroll",kind,flat(Color("100d09"),Color("55462e"),2))
		for state in ["grabber","grabber_highlight","grabber_pressed"]: result.set_stylebox(state,kind,flat(Color("98733d"),GOLD,4))
	for kind in ["CheckBox","CheckButton"]:
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]: result.set_stylebox(state,kind,flat(Color.TRANSPARENT,Color.TRANSPARENT,4))
	result.set_constant("separation","VBoxContainer",12); result.set_constant("separation","HBoxContainer",12)
	result.set_stylebox("separator","HSeparator",flat(Color("655132")))
	return result
static func picker_box(color: Color,border: Color=Color.TRANSPARENT,radius: int=8) -> StyleBoxFlat:
	var style:=flat(color,border,16); style.set_corner_radius_all(radius); return style
static func picker_theme() -> Theme:
	# The user-approved immediate picker has its own named design variants;
	# controls still come from the common builder and styling lives here.
	var result:=Theme.new()
	for variant in ["PickerButton","PickerPrimary","PickerRow","PickerSelectedRow"]:
		result.set_type_variation(variant,"Button")
		var primary: bool=variant=="PickerPrimary"; var row: bool=variant in ["PickerRow","PickerSelectedRow"]; var selected: bool=variant=="PickerSelectedRow"
		result.set_stylebox("normal",variant,picker_box(Color("293f49") if selected else Color("14222d") if row else Color("a77b38") if primary else Color("182630"),PICKER_GOLD if selected else Color.TRANSPARENT if row else Color("d0aa69") if primary else Color("35444c"),5))
		result.set_stylebox("hover",variant,picker_box(Color("2b424f") if row else Color("c3944b") if primary else Color("243a46"),PICKER_GOLD,5))
		result.set_stylebox("pressed",variant,picker_box(Color("334a53") if row else Color("6f4b22") if primary else Color("10202a"),PICKER_GOLD,5))
		result.set_stylebox("disabled",variant,picker_box(Color("101b24") if row else Color("171e24"),Color.TRANSPARENT if row else Color("30373b"),5))
		if not row:
			result.set_color("font_color",variant,Color("19150f") if primary else PICKER_IVORY); result.set_color("font_disabled_color",variant,Color("727a7e")); result.set_font_size("font_size",variant,16)
	return result
func configure(painter) -> void:
	frame=painter; frame.art.loaded.connect(art_loaded); frame.fonts.loaded.connect(font_loaded)
	frame.fonts.request(FONT)
	for clip in ["up","hilite","down"]: keys[frame.art.request_model(SPECS.button,clip)]="button:"+clip
	for clip in ["up","hilite","down"]: keys[frame.art.request_model(SPECS.close,clip)]="close:"+clip
	for clip in ["uncheckedup","checkedup","disabled"]: keys[frame.art.request_model(SPECS.check,clip)]="check:"+clip
	for name in ["up","down"]: keys[frame.art.request_model(SPECS[name],"up")]=name
	for key in keys:
		if frame.art.textures.has(key): images[keys[key]]=frame.art.textures[key]
	refresh()
func art_loaded(key: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed or not keys.has(key): return
	images[keys[key]]=texture; refresh()
func font_loaded(name: String) -> void:
	if not closed and name==FONT: refresh()
func picture(name: String) -> Texture2D: return images.get(name)
func button_style(name: String) -> StyleBoxTexture:
	var result:=StyleBoxTexture.new(); result.texture=picture(name); result.set_texture_margin_all(4); result.set_content_margin_all(8); return result
func refresh() -> void:
	if entry_publication_active and not entry_publication_building:
		entry_publication_dirty=true
		return
	current=refresh_base_theme()
	if frame.fonts.fonts.has(FONT):
		current.default_font=frame.fonts.fonts[FONT]; current.default_font_size=roundi(float(frame.fonts.metrics[FONT].height))
		for kind in ["Label","Button","CheckBox","OptionButton","LineEdit","Tree","PopupMenu","TabContainer","TabBar","TextEdit","ProgressBar","TooltipLabel"]:
			current.set_font("font",kind,current.default_font); current.set_font_size("font_size",kind,current.default_font_size)
		for name in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]: current.set_font(name,"RichTextLabel",current.default_font)
	for kind in ["Button","OptionButton"]:
		for pair in [["normal","up"],["hover","hilite"],["pressed","down"],["disabled","down"],["focus","hilite"]]:
			if picture("button:"+str(pair[1]))!=null: current.set_stylebox(pair[0],kind,button_style("button:"+str(pair[1])))
	current.set_type_variation("ClientCloseButton","Button")
	for pair in [["normal","up"],["hover","hilite"],["pressed","down"],["disabled","down"],["focus","hilite"]]:
		if picture("close:"+str(pair[1]))!=null:
			var style:=StyleBoxTexture.new(); style.texture=picture("close:"+str(pair[1])); style.set_content_margin_all(0); current.set_stylebox(pair[0],"ClientCloseButton",style)
	if picture("close:up")!=null: current.set_icon("client_close","Button",picture("close:up"))
	for kind in ["CheckBox","CheckButton"]:
		for pair in [["unchecked","uncheckedup"],["checked","checkedup"],["unchecked_disabled","disabled"],["checked_disabled","checkedup"]]:
			if picture("check:"+str(pair[1]))!=null: current.set_icon(pair[0],kind,picture("check:"+str(pair[1])))
	if picture("down")!=null: current.set_icon("arrow","OptionButton",picture("down"))
	for kind in ["HScrollBar","VScrollBar"]:
		for pair in [["decrement","up"],["increment","down"]]:
			if picture(pair[1])!=null:
				for suffix in ["","_highlight","_pressed"]: current.set_icon(str(pair[0])+suffix,kind,picture(pair[1]))
	presentation_ready=images.size()==11 and frame.fonts.fonts.has(FONT)
	if is_inside_tree() and not entry_publication_active:
		get_tree().set_meta("native_client_menu_theme",current)
		get_tree().call_group("native_client_windows","apply_native_theme",current)
	if not entry_publication_active:changed.emit(current)
func close() -> void:
	if closed: return
	closed=true
	_discard_pending_entry_themes()
	entry_publication_active=false;entry_publication_windows.clear()
	if is_inside_tree() and current!=null and get_tree().has_meta("native_client_menu_theme") and get_tree().get_meta("native_client_menu_theme")==current: get_tree().remove_meta("native_client_menu_theme")
	if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
	frame=null; keys.clear(); images.clear()
func _exit_tree() -> void: close()
