extends "res://tests/native_portrait_chooser_test.gd"
# Only frame model art/fonts are controlled. Every portrait bitmap is read,
# decoded and published by the production Catalog/AssetService/NativeUIArt.
const RealArt=preload("res://systems/native_ui_art.gd")
const Choices=preload("res://systems/native_data/portrait_choices.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Resources=preload("res://systems/native_data/portrait_resources.gd")
var bitmap_art
var image_sources: Dictionary={}
class FrameArt extends HeadlessArt:
	func close() -> void:pass
func wait_bitmaps(pane,limit_ms: int=6000) -> bool:
	var deadline:=Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if pane.cells.all(func(cell):return not cell.button.visible or str(cell.base).is_empty() or cell.bitmap.texture!=null) and pane.preview.texture!=null:return true
		await process_frame
	return false
func current_images(pane) -> bool:
	for cell in pane.cells:
		if not cell.button.visible or str(cell.base).is_empty():continue
		var resource: String=Resources.sized(str(cell.base),3,bitmap_art.catalog.has_resource)
		if cell.bitmap.texture==null or cell.bitmap.texture!=bitmap_art.textures.get(resource):return false
	return true
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed portrait catalog mounts read-only")
	var parser:=Table.new();var table: Dictionary=parser.parse(catalog.get_resource("portraits",2017).get_string_from_utf8())
	var values:=Choices.ordered(table.get("orderedRows",[]),0,6,catalog.has_resource)
	check(parser.failure.is_empty() and values.size()>=96,"Actual installed table supplies at least 96 admitted portrait bases")
	if values.size()<96:finish(args.report,{});return
	surface=SubViewport.new();surface.size=Vector2i(1100,800);surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var frame_art:=FrameArt.new();var fonts:=HeadlessFonts.new();painter.art=frame_art;painter.fonts=fonts;painter.add_child(frame_art);painter.add_child(fonts);frame_art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	bitmap_art=RealArt.new();surface.add_child(bitmap_art);bitmap_art.configure(catalog,"")
	# Deterministically exercise the SAME real admission branch as a fast drag
	# exceeding the production 128-job cap, without relying on machine speed.
	bitmap_art.assets.maximum_workers=1;bitmap_art.assets.maximum_pending=2
	bitmap_art.assets.completed.connect(func(_id,result):
		if str(result.get("error","")).is_empty():image_sources[str(result.resource_name)]={"sha256":str(result.sha256),"width":int(result.value.width),"height":int(result.value.height)})
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Installed TLK captions")
	var pane:=Chooser.new();surface.add_child(pane);pane.configure(painter,text,catalog,"");pane.set_context(values,str(values[0]),["queue",1],bitmap_art,catalog);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+12000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Actual native Portrait layout builds: "+pane.failure)
	if pane.layout_ready:
		await frames(4);var identities:=pane.cells.map(func(cell):return cell.bitmap.get_instance_id())
		# Physical scrollbar value changes reuse the production 24 bitmap cells.
		for offset in [107,642,214,963,321,0,856,428]:pane.scroll.get_v_scroll_bar().value=offset
		var admitted_jobs: int=bitmap_art.assets.pending.size()+bitmap_art.assets.running.size()
		check(admitted_jobs<=2,"Real asset queue retains its original hard bound")
		var loaded_after_jump: bool=await wait_bitmaps(pane)
		check(loaded_after_jump,"A settled rapid jump eventually loads every current portrait despite earlier queue saturation")
		check(current_images(pane),"Late native bitmap results decorate only their current pooled base")
		check(bitmap_art.failed.is_empty(),"Queue pressure is not remembered as a permanent missing portrait")
		if not loaded_after_jump:
			var rejected:={"decoded":image_sources.duplicate(true),"failedKeys":bitmap_art.failed.keys(),"queueBound":2,"maximumWorkers":1,"pane":pane.snapshot(),"failFast":"first settled jump remains blank"}
			pane.close();pane.queue_free();bitmap_art.close();bitmap_art.queue_free();painter.close();painter.queue_free();await frames(3);surface.queue_free();await frames(2);text.close();finish(args.report,rejected);return
		for offset in [0,642,0]:
			pane.scroll.get_v_scroll_bar().value=offset
			check(await wait_bitmaps(pane),"A previously skipped/revisited section loads "+str(offset))
			check(current_images(pane),"Revisited section has exact current real native textures "+str(offset))
		check(identities==pane.cells.map(func(cell):return cell.bitmap.get_instance_id()),"Rapid jumps retain the same 24 actual bitmap controls")
		check(image_sources.size()>=24 and image_sources.values().all(func(row):return str(row.sha256).length()==64 and int(row.width)>0 and int(row.height)>0),"Bitmap evidence identifies actual decoded installed bytes and dimensions")
		# Leave one queued section immediately: obsolete pending listeners must
		# not retain each visited section, nor replace the subsequent context.
		for offset in [963,107,856,214,749,321]:pane.scroll.get_v_scroll_bar().value=offset
		pane.set_context(values.slice(0,12),str(values[1]),["queue",2],bitmap_art,catalog);await frames(4)
		check(await wait_bitmaps(pane) and current_images(pane),"New scope consumes only its current native bitmap bindings")
		check(bitmap_art.waiting.values().all(func(rows):return rows.size()<=25),"Obsolete pooled listeners do not accumulate across rapid rebinding")
		pane.close();check(bitmap_art.bindings.is_empty(),"Close synchronously retires all portrait bindings")
		if bitmap_art.get("deferred") is Dictionary:check(bitmap_art.deferred.is_empty(),"Close drops deferred reads when their final target is retired")
	var snapshot:={"decoded":image_sources,"failedKeys":bitmap_art.failed.keys(),"queueBound":2,"maximumWorkers":1,"pane":pane.snapshot()}
	pane.queue_free();bitmap_art.close();bitmap_art.queue_free();painter.close();painter.queue_free();await frames(3);surface.queue_free();await frames(2);text.close()
	finish(args.report,snapshot)
func finish(path: String,snapshot: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"actualBitmapEvidence":snapshot,"graphical":false,"publicConnections":0,"nativeBuilds":0,"scope":"Actual installed Portrait source Controls with production Catalog, AssetService raster decode and NativeUIArt publication under deterministic bounded queue pressure; rapid jump/revisit/current binding/context retirement. Frame model art/fonts controlled; no screenshot/pixel or full live creator acceptance."},"  "));file.close();quit(0 if failures.is_empty() else 1)
