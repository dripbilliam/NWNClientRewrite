extends CanvasLayer
# Presentation only. Area-ready acknowledgements and server control gates never
# depend on the overlay or on the optional early-dismiss shortcut.
signal back_requested
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var veil: Control
var image: TextureRect
var heading: Label
var status: Label
var progress: ProgressBar
var details: Label
var art_notice: Label
var back: Button
var ui
var table: Dictionary={}
var table_job:=-1
var epoch:=-1
var active:=false
var dismissed:=false
var error:=""
var screen_id:=-1
var chosen_row:=-1
var art_resource:=""
var art_key:=""
var art_error:=""
var table_error:=""
var started:=0
var milestones: Dictionary={}
var history: Array=[]
var stats:={"shown":0,"completed":0,"early_dismissals":0,"errors":0,"art_loaded":0}
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
func _ready() -> void:
	layer=25; veil=Control.new(); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(veil)
	var background:=ColorRect.new(); background.color=Color("060a0b"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.add_child(background)
	image=TextureRect.new(); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; veil.add_child(image)
	var center:=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); center.mouse_filter=Control.MOUSE_FILTER_IGNORE; veil.add_child(center)
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(580,0); center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("081010ee"); style.border_color=Color("b7a06a"); style.set_border_width_all(1); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14); panel.add_child(column)
	heading=Label.new(); heading.text="Loading area"; heading.add_theme_font_size_override("font_size",26); column.add_child(heading)
	status=Label.new(); column.add_child(status)
	progress=ProgressBar.new(); progress.show_percentage=false; progress.custom_minimum_size=Vector2(520,12); progress.max_value=1; column.add_child(progress)
	details=Label.new(); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.custom_minimum_size.x=520; column.add_child(details)
	art_notice=Label.new(); art_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; art_notice.custom_minimum_size.x=520; art_notice.add_theme_color_override("font_color",Color("e5b66d")); art_notice.hide(); column.add_child(art_notice)
	var hint:=Label.new(); hint.text="Ctrl+Shift+L · Show the world early"; column.add_child(hint)
	back=Button.new(); back.text="Back to server selection"; back.focus_mode=Control.FOCUS_NONE; back.pressed.connect(func():back_requested.emit()); column.add_child(back)
	veil.hide()
func configure(owner) -> void:
	ui=owner; table={}; table_error=""; table_job=ui.assets.request("loadscreens",2017,"2da"); ui.assets.completed.connect(prepared)
	if table_job<0: table_error="Original loadscreens table could not be prepared: "+str(ui.assets.failure)
	modal_lease.configure(self,modal_lease.property(owner,"modal_order"),modal_lease.property(owner,"modal_surfaces"),self);modal_lease.bind_input(veil)
	if active and not dismissed:modal_lease.activate([epoch])
	ui.desktop.art.loaded.connect(art_ready)
	# The fallback panel is installed content. Area replacement names are only
	# known after the received area record and loadscreens table resolve.
	ui.desktop.art.request_model("pnl_loadscreen","up",{"gui_replace01":"ls_load"},0,"gui_replace01")
	veil.theme=ui.skin_owner.theme()
func prepared(id: int,result: Dictionary) -> void:
	if id!=table_job: return
	table_job=-1
	if str(result.error).is_empty(): table=result.value
	else: table_error="Original loadscreens table could not be prepared: "+str(result.error)
	if active:
		art_error=table_error; update_art_notice(); select_art()
func art_ready(name: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if name==art_key and active: image.texture=texture; stats.art_loaded+=1
func update_art_notice() -> void:
	if not is_instance_valid(art_notice): return
	art_notice.text=art_error; art_notice.visible=active and not art_error.is_empty()
func _process(_delta: float) -> void:
	if not active or not art_error.is_empty() or art_key.is_empty() or image.texture!=null or not is_instance_valid(ui): return
	if ui.desktop.art.failed.has(art_key):
		var shared=ui.desktop.art.ui_assets
		var reason: String=shared.failure("model",art_key) if shared!=null else "Original model or replacement bitmap could not be prepared"
		art_error="Original loading art unavailable: "+art_resource+" ("+reason+")"; update_art_notice()
func select_art() -> void:
	if not is_instance_valid(ui) or not active or table_job>=0: return
	var rows: Array=table.get("orderedRows",[]); var name:="ls_load"
	if chosen_row<0 and not rows.is_empty():
		# Native receiver treats 0 as random rows 2+, and 1 as custom text.
		# Randomness here is presentation-only, never canonical gameplay state.
		chosen_row=randi_range(2,rows.size()-1) if screen_id==0 and rows.size()>2 else screen_id
	if chosen_row>=2 and chosen_row<rows.size(): name=str(Game.cell(rows[chosen_row],"BMPResRef","ls_load"))
	elif screen_id>=2 and table_error.is_empty(): art_error="Original loading screen row unavailable: "+str(screen_id)
	if name in ["","****"]:
		if chosen_row>=2 and table_error.is_empty(): art_error="Original loading screen bitmap name is missing at row "+str(chosen_row)
		name="ls_load"
	if art_error.is_empty() and ui.desktop.art.catalog.raster_location(name).is_empty(): art_error="Original loading screen bitmap is missing: "+name
	update_art_notice()
	if name==art_resource: return
	art_resource=name; replace_image()
	# LOAD_SCREEN.GUI selects pnl_loadscreen. The original handler replaces
	# its gui_replace01 bitmap with the selected loading artwork.
	# Its UVs select the artwork from the packed bitmap; displaying the raw
	# atlas repeats/misplaces parts of the loading screen.
	art_key=ui.desktop.art.request_model("pnl_loadscreen","up",{"gui_replace01":name.to_lower()},0,"gui_replace01")
	if art_key.is_empty(): art_error="Original loading panel could not be requested: "+name; update_art_notice(); return
	if ui.desktop.art.textures.has(art_key): art_ready(art_key,ui.desktop.art.textures[art_key],{})
func replace_image() -> void:
	if is_instance_valid(image): veil.remove_child(image); image.queue_free()
	image=TextureRect.new(); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; veil.add_child(image); veil.move_child(image,1)
func begin(generation: int,area: String,entry: Dictionary={}) -> void:
	modal_lease.retire()
	epoch=generation; active=true; dismissed=false; error=""; milestones={}; started=Time.get_ticks_msec(); stats.shown+=1
	# A new target makes delayed archive-image callbacks harmless on transition.
	replace_image(); art_resource=""; art_key=""; art_error=table_error; chosen_row=-1; update_art_notice()
	screen_id=int(entry.get("loadingScreen",-1)); heading.text="Loading "+area; status.text="Preparing terrain…"; details.text=""; progress.value=0; veil.show(); select_art()
	modal_lease.activate([epoch])
func advance(generation: int,values: Dictionary) -> void:
	if generation!=epoch or not active: return
	if milestones==values: return
	milestones=values.duplicate(true)
	var errors: Array=values.get("errors",[])
	if not errors.is_empty():
		if error.is_empty(): stats.errors+=1
		error="\n".join(errors); status.text="Unable to finish loading this area"; details.text=error; veil.visible=not dismissed; return
	var terrain:=bool(values.get("terrain",false)); var player:=bool(values.get("player",false)); var camera:=bool(values.get("camera",false))
	var tiles:=int(values.get("tiles",0)); var total:=int(values.get("total_tiles",0))
	progress.value=0.6*(float(tiles)/maxi(1,total))+0.25*int(player)+0.15*int(camera)
	status.text="Preparing terrain…" if not terrain else "Loading your character…" if not player else "Positioning camera…"
	details.text="Terrain %d / %d · Character %s · Camera %s"%[tiles,total,"ready" if player else "loading","ready" if camera else "waiting"]
	if terrain and player and camera:
		stats.completed+=1
		if history.size()<32: history.append({"generation":epoch,"elapsed_ms":Time.get_ticks_msec()-started,"dismissed_early":dismissed,"milestones":milestones.duplicate(true)})
		modal_lease.retire();active=false; veil.hide()
func dismiss_early() -> void:
	if active and not dismissed: modal_lease.retire();dismissed=true; stats.early_dismissals+=1; veil.hide()
func blocks_input() -> bool: return active and not dismissed
func reset() -> void:
	modal_lease.retire()
	epoch=-1; active=false; dismissed=false; error=""; art_error=""; table_error=""; art_key=""; art_resource=""; veil.hide(); image.texture=null; art_notice.hide(); table_job=-1; ui=null; table={}
func snapshot() -> Dictionary:
	var result:=stats.duplicate(true); result.merge({"active":active,"generation":epoch,"dismissed":dismissed,"error":error,"art_error":art_error,"art_resource":art_resource,"art_key":art_key,"milestones":milestones.duplicate(true),"history":history.duplicate(true),"shortcut":"Ctrl+Shift+L"}); return result
func _input(event: InputEvent) -> void:
	if active and modal_lease.admits() and event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.shift_pressed and event.keycode==KEY_L:
		dismiss_early(); get_viewport().set_input_as_handled()
func _exit_tree() -> void:modal_lease.close()
