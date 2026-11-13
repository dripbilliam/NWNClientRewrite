extends SceneTree
# Actual popup font publication/fitting/controls with installed source data.
# No renderer, input injection, live World, server or clock owner is required.
const PopupFonts=preload("res://systems/native_popup_fonts.gd")
const MenuFonts=preload("res://systems/native_bitmap_fonts.gd")
const Plate=preload("res://systems/native_nameplate.gd")
const Bubble=preload("res://systems/native_overhead_bubble.gd")
const Resources=preload("res://systems/native_nameplate_resources.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Fit=preload("res://systems/native_data/nameplate_text.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionGraph=preload("res://native_session_world.gd")
const Hud=preload("res://systems/native_hud.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Text=preload("res://systems/server_text.gd")
const SMALL="ttf fnt_default 14"
const LARGE="ttf fnt_default_hr 16"
class Desktop extends Node:
	var art
	var state:={"players":[]}
	func close()->void:pass
class Inventory extends Node:
	var frame_skin
	func close()->void:pass
class Frame extends RefCounted:
	var fonts
class VisualRows extends RefCounted:
	var entities:={42:{"type":5,"eligible":true}}
var checks:=0
var failures: Array=[]
var measurements: Array=[]
var publications: Array=[]
var started:=0
func check(ok: bool,reason: String)->void:
	checks+=1
	if not ok:failures.append(reason);print("FAIL: ",reason)
func wait_for(predicate: Callable,milliseconds: int=20000)->bool:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func sha(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func plain(value: String)->Dictionary:return {"text":value}
func plate_data(value: Dictionary)->Dictionary:
	return {"available":true,"creature":true,"portrait":"po_hu_m_01t","name":value,"caption":value,"color":Color.WHITE,"caption_color":Color.WHITE}
func speech(value: Dictionary,font: String)->Dictionary:return {"ready":true,"eligible":true,"mode":2,"font":font,"rich":value,"text":Fit.plain(value)}
func text_checks(view,owner,font_name: String,height: int,baseline: int)->void:
	var label: RichTextLabel=view.caption;var font: Font=label.get_theme_font("normal_font");var size: int=label.get_theme_font_size("normal_font_size")
	var line:=TextLine.new();line.add_string("Nibs",font,size)
	check(font==owner.fonts[font_name] and font.get_meta("native_ttf_pixel_height",false),"Drawing uses actual popup-owner corrected resource "+font_name)
	check(size==height and font.get_height(size)==height and font.get_ascent(size)==baseline and font.get_descent(size)==3,"Original complete line/baseline/descent "+font_name)
	check(line.get_line_ascent()+line.get_line_descent()==height,"Actual TextLine uses the same logical line height "+font_name)
	check(label.get_theme_constant("outline_size")==0 and label.get_theme_constant("shadow_offset_x")==0 and label.get_theme_constant("shadow_offset_y")==0 and label.get_theme_color("font_shadow_color").a==0 and label.get_theme_color("font_outline_color").a==0,"Native popup has no generic outline/shadow "+font_name)
	var content:=Fit.plain(view.data.caption) if view is Plate else Fit.plain(view.model.rich)
	var fit: Dictionary=Fit.choose(content,Fit.font_metrics(font,size,content),font.get_height(size),2,23)
	check(view.size==Vector2(fit.bubble[0],fit.bubble[1]) and view.displayed_rich==Fit.display(view.data.caption if view is Plate else view.model.rich,fit.layout,fit.width,Fit.font_metrics(font,size,content)),"Actual draw resource also owns measured fitting/display "+font_name)
	check(label.get_parsed_text()==view.displayed_rich.text,"Actual label draws fitted literal spans "+font_name)
	measurements.append({"view":"plate" if view is Plate else "bubble","font":font_name,"height":font.get_height(size),"ascent":font.get_ascent(size),"descent":font.get_descent(size),"logical_box":[view.size.x,view.size.y],"caption_origin":[label.position.x,label.position.y],"caption_size":[label.size.x,label.size.y],"parsed":label.get_parsed_text(),"font_instance":font.get_instance_id()})
func _initialize()->void:run.call_deferred()
func run()->void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	check(SessionGraph!=null,"Actual SessionWorld/Gameplay static graph compiles")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original resource catalog mounts read-only")
	var source_hashes:={"fnt_default":sha(catalog.get_resource("fnt_default",2074)),"fnt_default_hr":sha(catalog.get_resource("fnt_default_hr",2074))}
	check(source_hashes.fnt_default=="6e1bd8f9e380f4e81bdbb687250c81dca01d9dfc81987fdb0d6e88357e146463" and source_hashes.fnt_default_hr=="3d4253142d03dcd700f3bd63cdeb7899f48df486051617a8c424573fe7694871","Both original dialog-font resource hashes match retained metric evidence")
	var stage:=Control.new();root.add_child(stage);stage.size=Vector2(1000,700)
	var fonts:=PopupFonts.new();root.add_child(fonts);started=Time.get_ticks_usec();fonts.loaded.connect(func(name):publications.append({"name":name,"elapsed_usec":Time.get_ticks_usec()-started}));fonts.configure(catalog,str(args.report).get_base_dir().path_join("popup-font-cache"))
	var menu:=MenuFonts.new();root.add_child(menu);menu.configure(catalog,str(args.report).get_base_dir().path_join("menu-font-cache"))
	var source:=Resources.new();root.add_child(source);source.configure(catalog,str(args.report).get_base_dir().path_join("popup-model-cache"))
	var plate:=Plate.new();stage.add_child(plate);plate.configure(null,fonts,source,SMALL);plate.set_popup_preferences(2,SMALL);plate.set_content(plate_data(plain("Nibs\nUninjured")))
	var small:=Bubble.new();stage.add_child(small);small.configure(null,fonts,source);small.set_content(speech(plain("Hi"),SMALL),"po_hu_m_01t",[42,8,13])
	var large:=Bubble.new();stage.add_child(large);large.configure(null,fonts,source);large.set_content(speech(plain("Hi"),LARGE),"po_hu_m_01t",[42,8,13])
	check(not plate.layout_ready and not small.layout_ready and not large.layout_ready,"Popup controls wait for actual asynchronous font publication without fabricated fallback layout")
	var menu_label:=Text.label(plain("Menu untouched"));stage.add_child(menu_label);menu.bind(menu_label,LARGE)
	check(await wait_for(func():return fonts.fonts.has(SMALL) and fonts.fonts.has(LARGE) and menu.fonts.has(LARGE) or not fonts.failed.is_empty() or not menu.failed.is_empty()),"Actual original font workers finish within the bounded gate")
	check(fonts.failed.is_empty() and menu.failed.is_empty() and fonts.fonts.has_all([SMALL,LARGE]) and menu.fonts.has(LARGE),"Font owners publish all required native resources")
	if not fonts.fonts.has_all([SMALL,LARGE]) or not menu.fonts.has(LARGE):
		fonts.close();menu.close();source.close();stage.queue_free();fonts.queue_free();menu.queue_free();source.queue_free();await process_frame;write_result(args.report,source_hashes,{});return
	check(await wait_for(func():return plate.layout_ready and small.layout_ready and large.layout_ready and source.plans.has("but_popup_prtrt") or not source.failures.is_empty()),"Real font/model loaded signals complete passive popup layout")
	check(source.failures.is_empty() and source.plans.has("but_popup_prtrt"),"Actual original popup portrait model prepares successfully")
	text_checks(plate,fonts,SMALL,14,11);text_checks(small,fonts,SMALL,14,11);text_checks(large,fonts,LARGE,16,13)
	check(plate.size.y==34 and small.size.y==34 and large.size.y==34,"Actual short plate and both speech fonts select original two-line logical34")
	var old_font: FontFile=menu.fonts[LARGE];var old_fit: Dictionary=Fit.choose("Hi",Fit.font_metrics(old_font,16,"Hi"),old_font.get_height(16),2,23)
	check(old_font.get_height(16)==20 and old_fit.bubble[1]==48,"Unchanged ordinary font owner reproduces prior48 choice")
	check(not menu.snapshot().ttf_pixel_height.enabled and menu.snapshot().ttf_pixel_height.attempted==0 and old_font.data==catalog.get_resource("fnt_default_hr",2074),"Menu owner retains original unadapted bytes and existing publication path")
	check(menu_label.get_theme_constant("outline_size")==3 and menu_label.get_theme_constant("shadow_offset_x")==1,"Popup style correction leaves generic menu text styling unchanged")
	if source.plans.has("but_popup_prtrt"):
		var portrait: Dictionary=source.plans.but_popup_prtrt;var photos: Array=portrait.parts.filter(func(row):return row.resource=="gui_replace01");var frames: Array=portrait.parts.filter(func(row):return row.resource=="gui_boxes")
		check(photos.size()==1 and frames.size()==1,"Original popup contains its photo and frame source meshes")
		if photos.size()==1 and frames.size()==1:
			check(photos[0].bounds.size.distance_to(Vector2(16,25))<0.001 and frames[0].bounds.size.distance_to(Vector2(18,27))<0.001,"Actual installed portrait16x25/frame18x27 remains unchanged")
			check(portrait.hooks.textindent.distance_to(Vector2(23,0))<0.001 and plate.caption.position.x==23 and large.caption.position.x==23 and plate.caption.size.x==plate.size.x-23,"Both actual popup controls retain original textindent23 hook")
	var colored:={"spans":[{"text":"A green traveler speaks across the old road and through the forest with ","color":"#00ff00"},{"text":"another carefully wrapped sentence about the town beyond the hill.","color":"#ff8040"}]}
	large.set_content(speech(colored,LARGE),"po_hu_m_01t",[42,8,13]);check(large.layout_ready and large.displayed_rich.text.contains("\n"),"Actual colored speech is wrapped by the original fitter")
	check(large.displayed_rich.spans.any(func(value):return value.get("color")=="#00ff00") and large.displayed_rich.spans.any(func(value):return value.get("color")=="#ff8040"),"Wrapping retains both explicit native color spans")
	text_checks(large,fonts,LARGE,16,13)
	var frozen: Dictionary=fonts.snapshot();var asset_serial: int=fonts.assets.serial;var source_serial: int=source.assets.serial;var layouts: Array=[plate.layouts,small.layouts,large.layouts]
	for index in 32:plate.place(Vector2(300+index,250),Rect2(0,0,1000,700),true);small.place(Vector2(300+index,300));large.place(Vector2(300+index,350))
	check(fonts.snapshot()==frozen and fonts.assets.serial==asset_serial and source.assets.serial==source_serial and [plate.layouts,small.layouts,large.layouts]==layouts,"Position updates reuse published fonts/fitted controls without per-frame adaptation or model requests")
	check(publications.size()==2 and frozen.ttf_pixel_height.attempted==2 and frozen.ttf_pixel_height.published==2 and frozen.ttf_pixel_height.fallbacks==0,"One corrected publication per requested font, shared by plate and speech")
	# Exercise the actual HUD font-borrowing branch with a deliberately different
	# ordinary menu owner. Only projection/received rows are authored seams.
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.set_process_unhandled_key_input(false);ui.catalog=catalog;ui.popup_fonts=fonts;ui.overhead_popup_source=source;ui.generation=7;ui.area_id=91;ui.controlled_id=42
	ui.native_connection_query=func():return 3
	ui.overhead_anchor_query=func(_id,_witness,_scope):return {"ready":true,"screen":Vector2(400,300)}
	check(ui.text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual UI TLK opens for source name/injury caption")
	ui.text.publish_table("damagelevels",Table.new().parse(catalog.get_resource("damagelevels",2017).get_string_from_ascii()));ui.text.objects={42:{"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Nibs"},"portraitRef":"po_hu_m_01","damageLevel":0,"reaction":1}}}
	var desktop:=Desktop.new();ui.add_child(desktop);ui.desktop=desktop;var inventory:=Inventory.new();ui.add_child(inventory);inventory.frame_skin=Frame.new();inventory.frame_skin.fonts=menu;ui.inventory=inventory
	var hud:=Hud.new();root.add_child(hud);hud.registry=VisualRows.new();hud.root=Control.new();hud.add_child(hud.root);hud.nameplate_root=Control.new();hud.root.add_child(hud.nameplate_root);hud.bind_gameplay(ui);hud.labels([42])
	check(hud.nameplates.has(42) and hud.nameplates[42].fonts==fonts and hud.nameplates[42].fonts!=menu,"Actual HUD chooses popup-only owner rather than inventory/menu font owner")
	check(hud.nameplates.has(42) and hud.nameplates[42].layout_ready and hud.nameplates[42].size.y==34,"Actual HUD source short caption uses corrected logical34")
	hud.clear_nameplates();hud.release_nameplate_source();hud.queue_free();ui.popup_fonts=null;ui.overhead_popup_source=null;ui.close();ui.queue_free()
	var overlay:=str(args.report).get_base_dir().path_join("alternate-catalog");DirAccess.make_dir_recursive_absolute(overlay);var output:=FileAccess.open(overlay.path_join("fnt_default.ttf"),FileAccess.WRITE);output.store_buffer(catalog.get_resource("fnt_default_hr",2074));output.close()
	var other_catalog=catalog.fork();check(other_catalog.mount_directory(overlay,99999999),"Independent catalog mounts alternate original font bytes privately")
	var other:=PopupFonts.new();root.add_child(other);other.configure(other_catalog,str(args.report).get_base_dir().path_join("other-font-cache"));var other_label:=Label.new();stage.add_child(other_label);other.bind(other_label,SMALL)
	check(await wait_for(func():return other.fonts.has(SMALL) or not other.failed.is_empty()),"Independent popup catalog owner publishes its own requested font")
	if other.fonts.has(SMALL):check(other.fonts[SMALL]!=fonts.fonts[SMALL] and other.fonts[SMALL].data!=fonts.fonts[SMALL].data,"Same font name in distinct catalogs never aliases derived font resources")
	other.close();other.prepared(999,{"value":{"data":PackedByteArray()}});check(other.fonts.is_empty() and other.jobs.is_empty() and other.bindings.is_empty(),"Closed catalog owner rejects late publication and clears jobs/bindings")
	check(fonts.fonts.size()==2 and not fonts.closed,"Closing another catalog does not retire shared active popup fonts")
	other_label.queue_free();other.queue_free();plate.close();small.close();large.close();check(fonts.bindings.is_empty(),"Actual popup close releases all borrowed font bindings")
	fonts.close();fonts.prepared(999,{"value":{"data":PackedByteArray()}});check(fonts.fonts.is_empty() and fonts.jobs.is_empty() and fonts.bindings.is_empty() and fonts.assets.running.is_empty(),"Popup font owner close drains workers and cannot be revived by late completion")
	menu.close();source.close();stage.queue_free();fonts.queue_free();menu.queue_free();source.queue_free();await process_frame;await process_frame;await process_frame
	check(sha(catalog.get_resource("fnt_default",2074))==source_hashes.fnt_default and sha(catalog.get_resource("fnt_default_hr",2074))==source_hashes.fnt_default_hr,"Installed catalog source font bytes remain unchanged")
	write_result(args.report,source_hashes,frozen)
func write_result(path: String,source_hashes: Dictionary,stats: Dictionary)->void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"font_publications":publications,"font_owner_before_close":stats,"source_font_sha256":source_hashes,"headless":true,"gpu":false,"original_pixels_accepted":false,"scope":"Actual installed catalog/font workers, popup-only owner, Nameplate/OverheadBubble draw+fitting metrics, original portrait plan, actual HUD borrowing with authored projection/rows and current SessionWorld graph. No framebuffer, GUI pixels, raster coverage equivalence, live world/server or FPS acceptance."}
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_POPUP_TYPOGRAPHY ",checks," checks; ",failures.size()," failures");quit(0 if result.success else 1)
