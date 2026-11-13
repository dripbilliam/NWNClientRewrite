extends SceneTree
# Actual installed source summary/sheet controls and existing font owner.
# The test subclass counts real publications without replacing the branch. Artwork
# is deliberately non-rendering; there is no framebuffer or server connection.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Summary=preload("res://systems/native_character_summary_view.gd")
const SummaryPlan=preload("res://systems/native_data/character_summary_layout.gd")
const Sheet=preload("res://systems/server_character_sheet.gd")
const SheetFrame=preload("res://systems/native_character_sheet_frame.gd")
const Text=preload("res://systems/server_text.gd")
const TtfHeight=preload("res://systems/native_data/ttf_pixel_height.gd")
class CandidateFonts extends "res://systems/native_bitmap_fonts.gd":
	var builds: Array=[]
	func publish(name: String) -> void:
		builds.append({"name":name,"ms":null}); super.publish(name)
class NonRenderingArt extends Node:
	signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
	const models=preload("res://systems/native_item_icons.gd")
	var textures: Dictionary={}
	var bounds: Dictionary={}
	var failed: Dictionary={}
	func bind(_target: Object,_resource: String,_property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false,_overrides: Dictionary={},_region: Rect2=Rect2()) -> void: pass
	func unbind(_target: Object,_property: String="texture") -> void: pass
	func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String: return models.model_key(name,clip,overrides,turn,layer,poses,region)
var checks:=0
var failures: Array=[]
var errors: Array=[]
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok: failures.append(why)
func wait_for(predicate: Callable,ms: int=15000) -> bool:
	var until:=Time.get_ticks_msec()+ms
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func inspect_text(control: RichTextLabel,owner,name: String) -> Dictionary:
	var font: Font=control.get_theme_font("normal_font"); var height:=control.get_theme_font_size("normal_font_size"); var line:=TextLine.new(); line.add_string(control.get_parsed_text().split("\n")[0],font,height)
	check(font==owner.fonts[name] and font.get_meta("native_ttf_pixel_height",false),"Actual source text draws the same candidate object used by measurement")
	check(height==14 and font.get_height(height)==14 and line.get_line_ascent()+line.get_line_descent()==14,"Source text retains native logical line/baseline")
	check(control.get_theme_constant("outline_size")==3,"Existing ServerText outline3 is retained")
	var glyph: int=font.get_glyph_index(height,65,0); var ts:=TextServerManager.get_primary_interface(); ts.font_render_glyph(font.get_rids()[0],Vector2i(height,3),glyph)
	check(ts.font_get_glyph_size(font.get_rids()[0],Vector2i(height,3),glyph).x>0,"Actual source text's requested outline3 has real cached glyph geometry")
	return {"font_resource":name,"font_id":font.get_instance_id(),"requested_height":height,"line_height":font.get_height(height),"outline":control.get_theme_constant("outline_size"),"line_separation":control.get_theme_constant("line_separation"),"parsed_text":control.get_parsed_text(),"first_line_width":line.get_line_width(),"content_height":control.get_content_height()}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","install","cache"]) or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Installed original resources mount read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original TLK captions mount read-only")
	var surface:=SubViewport.new(); surface.size=Vector2i(1400,900); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var painter:=Painter.new(); var art:=NonRenderingArt.new(); var fonts:=CandidateFonts.new(); painter.art=art; painter.fonts=fonts; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter); fonts.ttf_pixel_height_enabled=true; fonts.configure(catalog,args.cache); fonts.ttf_pixel_height_enabled=false
	check(fonts.snapshot().ttf_pixel_height.enabled,"Opt-in is latched at configuration, not changed by later flag assignment")
	var ordinary:=CandidateFonts.new(); surface.add_child(ordinary); ordinary.configure(catalog,str(args.cache).path_join("ordinary")); ordinary.ttf_pixel_height_enabled=true
	var ordinary_label:=Label.new(); surface.add_child(ordinary_label); ordinary.bind(ordinary_label,"ttf fnt_default 14")
	check(await wait_for(func():return ordinary.fonts.has("ttf fnt_default 14")),"Ordinary default owner publishes its existing font")
	check(not ordinary.snapshot().ttf_pixel_height.enabled and ordinary.snapshot().ttf_pixel_height.attempted==0 and not ordinary.fonts["ttf fnt_default 14"].has_meta("native_ttf_pixel_height"),"Late flag assignment does not activate adaptation on an ordinary owner")
	check(ordinary.fonts["ttf fnt_default 14"].data==catalog.get_resource("fnt_default",2074),"Default font bytes and method remain unchanged")
	ordinary.close(); ordinary_label.free(); ordinary.free()
	var assets:=Assets.new(); surface.add_child(assets); assets.configure(catalog); assets.cache_directory=args.cache; assets.maximum_workers=2
	var models: Dictionary={}; var jobs: Dictionary={}
	assets.completed.connect(func(id,result):
		if not jobs.has(id): return
		var name: String=jobs[id]; jobs.erase(id)
		if not str(result.get("error","")).is_empty(): errors.append(name+": "+str(result.error))
		else: models[name]=result.value)
	for name in SummaryPlan.RESOURCES: jobs[assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")]=name
	check(await wait_for(func():return jobs.is_empty() or not errors.is_empty()),"Actual original summary model preparation is bounded"); check(errors.is_empty(),"Original source model preparation succeeds")
	var summary:=Summary.new(); surface.add_child(summary)
	if errors.is_empty(): summary.configure(painter,text,models)
	check(summary.failure.is_empty() and is_instance_valid(summary.detail),"Actual source creation/pregame summary builds from original hooks")
	var sheet:=Sheet.new(); surface.add_child(sheet); sheet.setup(""); var frame:=SheetFrame.new(); surface.add_child(frame); frame.configure(sheet,catalog,args.cache,text,painter); sheet.open()
	check(await wait_for(func():return frame.layout_ready or not frame.failure.is_empty()),"Actual source in-game sheet prepares without a renderer wait"); check(frame.failure.is_empty() and frame.layout_ready,"Actual source sheet layout succeeds")
	var records: Array=[]
	if is_instance_valid(summary.detail) and frame.layout_ready:
		Text.set_text(summary.detail,{"text":"Nibs\nUninjured"})
		sheet.receive({"kind":"sheet-view","viewId":1,"page":0,"model":{"identity":1,"name":"Font gate","details":[{"label":"","parts":[{"text":"Nibs\nUninjured"}]}],"abilities":[],"classes":[]}})
		check(await wait_for(func():return fonts.fonts.has("ttf fnt_default 14") and fonts.fonts.has("fnt_galahad14")),"Actual font worker publishes source TTF and original bitmap font")
		await process_frame; await process_frame
		if fonts.fonts.has("ttf fnt_default 14"):
			records.append(inspect_text(summary.detail,fonts,"ttf fnt_default 14")); records.append(inspect_text(sheet.active_scrolls.details.get_child(0),fonts,"ttf fnt_default 14"))
			check(records[0].font_id==records[1].font_id and fonts.builds.filter(func(value):return value.name=="ttf fnt_default 14").size()==1,"Both real source views share exactly one owner font publication")
		check(summary.labels.title.get_meta("native_font_applied","")=="fnt_galahad14" and fonts.metrics.fnt_galahad14.mode=="bitmap","Unrelated original bitmap typography retains its original source path")
	var label:=Label.new(); surface.add_child(label); fonts.bind(label,"ttf fnt_default 28")
	check(await wait_for(func():return fonts.fonts.has("ttf fnt_default 28")),"Independent requested-height28 cache publishes")
	if fonts.fonts.has("ttf fnt_default 28"):
		check(label.get_theme_font("font")==fonts.fonts["ttf fnt_default 28"] and label.get_theme_font_size("font_size")==28 and fonts.fonts["ttf fnt_default 28"].get_height(28)==28,"Actual owner draws/measures requested28 rather than reusing a fixed14 font")
		check(fonts.fonts["ttf fnt_default 28"]!=fonts.fonts["ttf fnt_default 14"],"Requested-height keys do not alias mutable font resources")
	var old_advance: float=fonts.fonts["ttf fnt_default 14"].get_glyph_advance(0,14,36).x
	var weak: WeakRef=weakref(fonts.fonts.get("ttf fnt_default 14")); var builds: Array=fonts.builds.duplicate(true); fonts.close()
	check(fonts.fonts.is_empty() and fonts.jobs.is_empty() and fonts.bindings.is_empty() and fonts.assets.running.is_empty(),"Existing font owner close drains workers/jobs/bindings/cache")
	fonts.prepared(999,{"value":{"data":PackedByteArray()}}); check(fonts.fonts.is_empty(),"Late publication cannot revive the closed owner")
	check(weak.get_ref()!=null,"Live text controls intentionally retain their currently applied font after owner close")
	# Same requested name, new catalog/source: verify no static filename cache
	# survives retirement. Original font bytes remain in an owned private cache.
	var overlay:=str(args.cache).path_join("alternate-font-scope"); DirAccess.make_dir_recursive_absolute(overlay); var source:=FileAccess.open(overlay.path_join("fnt_default.ttf"),FileAccess.WRITE); source.store_buffer(catalog.get_resource("fnt_default_hr",2074)); source.close()
	var unusual: PackedByteArray=catalog.get_resource("fnt_default",2074).duplicate(); var sfnt:=preload("res://systems/native_data/font_data.gd").new(); var decoded:=sfnt.parse(unusual); TtfHeight.w16(unusual,int(decoded.tables.hhea.offset)+4,32767); TtfHeight.w16(unusual,int(decoded.tables.hhea.offset)+6,32768)
	var unusual_path:=overlay.path_join("fallback_ttf.ttf"); source=FileAccess.open(unusual_path,FileAccess.WRITE); source.store_buffer(unusual); source.close()
	var alternate=catalog.fork(); check(alternate.mount_directory(overlay,99999999),"A separate owned catalog mounts alternate original font bytes")
	var next_fonts:=CandidateFonts.new(); surface.add_child(next_fonts); next_fonts.ttf_pixel_height_enabled=true; next_fonts.configure(alternate,str(args.cache).path_join("next-owner")); var next_label:=Label.new(); surface.add_child(next_label); next_fonts.bind(next_label,"ttf fnt_default 14")
	check(await wait_for(func():return next_fonts.fonts.has("ttf fnt_default 14")),"New catalog owner resolves the same requested name independently")
	if next_fonts.fonts.has("ttf fnt_default 14"):
		check(next_fonts.fonts["ttf fnt_default 14"].get_glyph_advance(0,14,36).x!=old_advance,"Replaced source bytes change the effective font rather than reusing the retired name")
		fonts.prepared(999,{"value":{"data":PackedByteArray()}}); check(next_fonts.fonts.size()==1 and fonts.fonts.is_empty(),"A retired owner's late delivery cannot poison the replacement catalog owner")
	var fallback_label:=Label.new(); surface.add_child(fallback_label); next_fonts.bind(fallback_label,"ttf fallback_ttf 14")
	check(await wait_for(func():return next_fonts.fonts.has("ttf fallback_ttf 14") or next_fonts.failed.has("ttf fallback_ttf 14")),"Unsupported adaptation completes through the existing dynamic path")
	if next_fonts.fonts.has("ttf fallback_ttf 14"):
		var fallback: FontFile=next_fonts.fonts["ttf fallback_ttf 14"]; var diagnostics: Dictionary=next_fonts.snapshot().ttf_pixel_height
		check(not fallback.has_meta("native_ttf_pixel_height") and fallback.data==unusual and fallback.has_char(65),"Unsupported scale preserves source bytes and actual glyph availability without publishing an empty candidate")
		check(diagnostics.fallbacks==1 and diagnostics.last_fallback.resource=="ttf fallback_ttf 14" and diagnostics.last_fallback.height==14 and diagnostics.last_fallback.source_sha256==FileAccess.get_sha256(unusual_path) and str(diagnostics.last_fallback.reason).length()<=256,"Fallback diagnostics retain bounded source/request/reason provenance")
		diagnostics.last_fallback.reason="MUTATED"; check(next_fonts.snapshot().ttf_pixel_height.last_fallback.reason!="MUTATED","Diagnostic snapshots cannot mutate the live fallback record"); fallback=null
	var next_weak: WeakRef=weakref(next_fonts.fonts["ttf fnt_default 14"]); next_fonts.close(); fallback_label.free(); next_label.free(); next_fonts.free(); check(next_weak.get_ref()==null,"Replacement owner and text retirement release its independent font")
	summary.close(); summary.free(); frame.close(); frame.free(); sheet.free(); label.free(); assets.close(); assets.free(); painter.close(); painter.free(); text.close(); surface.queue_free(); await process_frame; await process_frame; await process_frame
	check(weak.get_ref()==null,"Retiring actual text controls releases the dynamic font and private adapted byte storage")
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"errors":errors,"source_text_controls":records,"builds":builds,"headless":true,"gpu":false,"sourceArtworkDouble":true,"integratedOptInPublication":true,"oracleRuntimeDependency":false,"runtimeWritesProduction":false,"ordinaryDefaultsChanged":false,"serverConnections":0,"sourceAssetsExported":false,"scope":"Actual installed source creation/pregame summary and in-game sheet text, real original font owner/asset service, per-height keys and retirement. Production TTF opt-in is explicitly enabled before configure in this test. No GUI pixels, complete gameplay, server or production integration acceptance."},"  ")+"\n"); output.close(); print("NATIVE_TTF_SOURCE_OWNER ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
