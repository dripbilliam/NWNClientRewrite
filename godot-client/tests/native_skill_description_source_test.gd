extends SceneTree
# Independent input/description regression over the real installed model layout.
# Controlled art/font doubles avoid any dummy-renderer raster publication wait.
const Sheet=preload("res://systems/server_character_sheet.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Frame=preload("res://systems/native_character_sheet_frame.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Plan=preload("res://systems/native_data/character_sheet_layout.gd")
class ControlledFonts extends Node:
	signal loaded(name: String)
	var metrics: Dictionary={}
	var fonts: Dictionary={}
	var requested: Array=[]
	var closed:=false
	func bind(target: Control,name: String) -> void:
		requested.append(name); target.set_meta("native_font_applied",name)
		if target is RichTextLabel: target.add_theme_font_override("normal_font",ThemeDB.fallback_font)
		else: target.add_theme_font_override("font",ThemeDB.fallback_font)
	func close() -> void: closed=true; fonts.clear(); metrics.clear()
class ControlledArt extends Node:
	signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
	const models=preload("res://systems/native_item_icons.gd")
	var textures: Dictionary={}
	var bounds: Dictionary={}
	var failed: Dictionary={}
	var bindings: Dictionary={}
	var closed:=false
	var calls:=0
	var raster: Texture2D
	func _init() -> void:
		var image:=Image.create(8,8,false,Image.FORMAT_RGBA8); image.fill(Color(0.4,0.3,0.6,1)); raster=ImageTexture.create_from_image(image)
	func bind(target: Object,resource: String,property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false,_overrides: Dictionary={},_region: Rect2=Rect2()) -> void:
		calls+=1; bindings[str(target.get_instance_id())+":"+property]=resource; target.set(property,raster)
		textures[models.model_key(resource,_clip,_overrides,0,"",[],_region) if _model else resource.to_lower()]=raster
	func unbind(target: Object,property: String="texture") -> void: bindings.erase(str(target.get_instance_id())+":"+property)
	func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String:
		var key: String=models.model_key(name,clip,overrides,turn,layer,poses,region); textures[key]=raster; return key
	func close() -> void: closed=true; bindings.clear(); textures.clear(); bounds.clear(); raster=null
var checks:=0
var failures: Array=[]
var requests: Array=[]
var surface: SubViewport
var ui: Node
var sheet: PanelContainer
var painter: Node
var art: ControlledArt
var fonts: ControlledFonts
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
	return value
func frames(count: int=3) -> void:
	for index in count: await process_frame
func click(control: Control) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; event.position=point; event.global_position=point; surface.push_input(event,true); await process_frame
func skill_requests() -> Array: return requests.filter(func(message):return message.get("kind")=="native-panel" and message.get("panel")=="skill")
func digest(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["report","install"]) or FileAccess.file_exists(options.report): quit(2); return
	var diagnostic:=await exercise(options)
	if is_instance_valid(ui): ui.close(); ui.free()
	if is_instance_valid(sheet): sheet.free()
	if is_instance_valid(painter): painter.close()
	check(is_instance_valid(art) and art.closed and is_instance_valid(fonts) and fonts.closed,"Controlled raster/font owners implement and complete real close lifecycle")
	if is_instance_valid(surface): surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"headless":true,"gpu":false,"publicConnections":0,"gameServerConnections":0,"nativeBuilds":0,"scope":"Actual installed source-model decode and native sheet/frame/painter/record-entry controls with real pointer input. Art is an authored8px raster and font is Godot fallback, without original glyph/raster/pixel acceptance. Authored raw actor and server-message fixtures; original-server GUI outcome is a separate test."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("NATIVE_SKILL_SOURCE_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
func exercise(options: Dictionary) -> Dictionary:
	var catalog:=Catalog.new()
	if not check(catalog.mount_install(options.install),"Installed original resource catalog mounts read-only"): return {}
	root.size=Vector2i(1440,960); surface=SubViewport.new(); surface.size=root.size; surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.handle_input_locally=true; surface.gui_disable_input=false; root.add_child(surface); surface.notify_mouse_entered()
	painter=Painter.new(); art=ControlledArt.new(); fonts=ControlledFonts.new(); painter.art=art; painter.fonts=fonts; painter.owns_art=true; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	ui=Gameplay.new(); root.add_child(ui); ui.set_process(false); ui.generation=1; ui.area_id=55; ui.controlled_id=42
	if not check(ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk")),"Actual installed talk table opens"): return {}
	for name in ["skills","feat","classes","racialtypes","exptable","ruleset"]: ui.text.publish_table(name,Table.new().parse(catalog.read_resource(name,2017).get_string_from_ascii()))
	var desktop:=Desktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.owner_ui=ui; desktop.rules.text=ui.text; ui.desktop=desktop
	sheet=Sheet.new(); sheet.setup(""); surface.add_child(sheet); desktop.sheet=sheet; sheet.request.connect(desktop.input_request); desktop.request.connect(func(message): requests.append(message.duplicate(true)))
	var skin:=Frame.new(); desktop.add_child(skin); desktop.sheet_frame=skin; skin.configure(sheet,catalog,str(options.report).get_base_dir().path_join("model-cache"),ui.text,painter)
	var skills: Array=ui.text.tables.skills.orderedRows; var perform:=-1
	for index in skills.size():
		if str(skills[index].get("Label","")).to_lower()=="perform": perform=index; break
	if not check(perform>=0,"Perform ID comes from installed skills.2da"): return {}
	var reference:=int(skills[perform].Description)
	var unchanged_skill:=0 if perform!=0 else 1
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Source geometry skill fixture"},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]},"hitPoints":{"current":10,"maximum":10}},"inventoryStats":{"skills":[{"index":perform,"flag":true,"value":-1},{"index":unchanged_skill,"flag":true,"value":4}]},"playerState":{"abilities":{"current":[10,10,10,10,10,10]},"feats":[0,1,2]}}
	desktop.objects={42:actor}; desktop.generation=1; desktop.area_id=55; desktop.actor_id=42; ui.text.objects=desktop.objects
	sheet.wanted=true; sheet.page=1; sheet.show(); desktop.refresh_sheet()
	var deadline:=Time.get_ticks_msec()+20000
	while not skin.layout_ready and skin.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if not check(skin.layout_ready and skin.failure.is_empty(),"Original native asset service decodes all installed sheet models: "+skin.failure): return {"skin":skin.snapshot()}
	await frames(5)
	check(not sheet.window_column.visible and sheet.size.x==360 and skin.models.size()==Plan.RESOURCES.size(),"Active source frame replaces generic layout using all17 original components")
	var model_hashes: Dictionary={}
	for name in Plan.RESOURCES: model_hashes[name]=digest(catalog.read_resource(name,2002))
	if not check(sheet.entry_nodes.size()==2,"Received customized and unchanged skills both create selectable original-style rows"): return {"models":model_hashes,"skin":skin.snapshot()}
	var id:=-1; var unchanged_id:=-1
	for key in sheet.entry_data:
		if int(sheet.entry_data[key].id)==perform: id=int(key)
		else: unchanged_id=int(key)
	var row: Button=sheet.entry_nodes[id]; var unchanged_row: Button=sheet.entry_nodes[unchanged_id]
	check(row.size.distance_to(Vector2(331,34))<0.01 and row.image.size==Vector2(32,32),"Original row hitbox331x34 and32px icon come from source geometry")
	check(painter.button_geometry[row.get_instance_id()].resource=="ctl_chr_btn_skil" and row.toggle_mode and row.button_group!=null,"Real native radio control uses the original skill model")
	check(sheet.description.get_meta("native_font_applied","")=="fnt_galahad14" and art.calls>0,"Controlled raster/font owners are bound through the actual source painter")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":reference,"text":"Ability: Charisma.\n<CUSTOM9001>\nOwned source description."}]},1); ui.receive({"kind":"custom-token","id":9001,"text":"First authored server-message text"},1)
	var saved_actor:=actor.duplicate(true); var view: int=sheet.view_id; var before:=skill_requests().size()
	await click(row)
	check(row.button_pressed and skill_requests().size()==before+1,"Actual original-sized pointer press selects and sends exactly once")
	check(skill_requests().back()=={"kind":"native-panel","panel":"skill","open":true,"skillId":perform,"targetId":42,"actorId":42,"areaId":55,"generation":1},"Native inspection request targets the displayed actor and exact live scope")
	check(sheet.description.get_parsed_text().contains("First authored server-message text"),"First physical selection resolves current token text through active native TLK owner")
	ui.receive({"kind":"custom-token","id":9001,"text":"Second server-message fixture text"},1); await frames()
	var binds:=art.calls; var geometry: int=painter.button_geometry.size()
	await click(row)
	check(skill_requests().size()==before+2 and sheet.description.get_parsed_text().contains("Second server-message fixture text"),"Repeated already-selected radio press fetches new text and sends another GUI3 intent")
	check(sheet.view_id==view and sheet.entry_nodes[id]==row and art.calls==binds and painter.button_geometry.size()==geometry,"Description refresh preserves row/view/geometry and schedules no artwork rebuild")
	await click(unchanged_row); var unchanged_text: String=sheet.description.get_parsed_text(); var unchanged_before:=skill_requests().size()
	ui.receive({"kind":"custom-token","id":9001,"text":"Third server-message fixture text"},1); await click(unchanged_row)
	check(not unchanged_text.is_empty() and sheet.description.get_parsed_text()==unchanged_text,"An unaffected disclosed skill keeps the same installed description across repeated clicks and another skill token update")
	check(skill_requests().size()==unchanged_before+1 and int(skill_requests().back().skillId)==unchanged_skill,"Unchanged help still emits each ordinary skill GUI3 intent instead of suppressing the callback")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":reference,"text":"Updated installed-row override\n[b]literal[/b]\n<CUSTOM9001>"}]},1); await click(row)
	check(sheet.description.get_parsed_text().contains("Updated installed-row override") and sheet.description.get_parsed_text().contains("[b]literal[/b]") and not sheet.description.bbcode_enabled,"Source-skinned repeated selection resolves latest TLK and renders untrusted markup literally")
	var samples: Array=[]
	for iteration in 200:
		var began:=Time.get_ticks_usec(); row.pressed.emit(); samples.append((Time.get_ticks_usec()-began)/1000.0)
	samples.sort()
	check(samples[189]<8.0 and sheet.entry_nodes[id]==row and art.calls==binds,"200 warm source-skinned selections stay below8ms p95 without rebuilding")
	check(actor==saved_actor,"Description inspection never computes disguise or edits received skill/character state")
	var retired:={"kind":"sheet-select","viewId":view,"page":1,"entryId":id}; var count:=skill_requests().size(); desktop.refresh_sheet(); await frames()
	check(skill_requests().size()==count,"Restoring the selected source row does not emit a physical inspection")
	desktop.input_request(retired); check(skill_requests().size()==count,"Retired view cannot issue a new inspection")
	var next_id: int=sheet.entry_nodes.keys()[0]; var description: Dictionary=sheet.entry_data[next_id].description.duplicate(true)
	sheet.receive({"kind":"sheet-description","viewId":view,"page":1,"entryId":next_id,"description":{"text":"obsolete"}})
	check(sheet.entry_data[next_id].description==description,"Late description cannot decorate replacement source controls")
	await click(sheet.tabs[2]); var skill_count:=skill_requests().size()
	if not sheet.entry_nodes.is_empty(): await click(sheet.entry_nodes.values()[0])
	check(sheet.page==2 and skill_requests().size()==skill_count,"Actual source Feats tab and row never emit skill GUI3")
	sheet.close_sheet(); desktop.input_request({"kind":"sheet-select","viewId":sheet.view_id,"page":1,"entryId":next_id})
	check(skill_requests().size()==skill_count,"Closed original-style sheet rejects further skill inspection")
	return {"models":model_hashes,"skill_id":perform,"description_strref":reference,"physical_input":true,"raster":"Authored8x8RGBA8","font":"Godot fallback; original named binding preserved","selection_ms":{"p50":samples[99],"p95":samples[189],"max":samples.back(),"count":samples.size()},"skin":skin.snapshot()}
