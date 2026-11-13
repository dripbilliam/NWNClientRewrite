extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Pane=preload("res://systems/native_spells_chooser.gd")
const Builder=preload("res://systems/native_menu_builder.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> bool:
	checks+=1
	if not value:failures.append(message)
	return value
func white_ink(picture: Image,rect: Rect2) -> int:
	var clipped:=Rect2i(rect).intersection(Rect2i(Vector2i.ZERO,picture.get_size()));var count:=0
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x):
			var pixel:=picture.get_pixel(x,y)
			if minf(pixel.r,minf(pixel.g,pixel.b))>.8 and maxf(pixel.r,maxf(pixel.g,pixel.b))-minf(pixel.r,minf(pixel.g,pixel.b))<.08:count+=1
	return count
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.position=Vector2i(-32000,-32000)
	await process_frame
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.position.x< -10000 and root.position.y< -10000,"The isolated owned test window remains non-activating and offscreen")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original GUI catalog mounts read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(850,650);surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,"")
	var text=preload("res://systems/native_data/talk_text.gd").new();text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var pane:=Pane.new();surface.add_child(pane);pane.position=Vector2(35,35);pane.configure(painter,text,catalog,"")
	var model:={"ready":true,"available":[{"id":1,"name":"Native rendered spell","icon":"ir_cantrips"}],"known":[],"tabs":[true,true,false,false,false,false,false,false,false,false],"level":1,"remaining":3,"canAccept":true,"empty":false,"cannotLearn":false}
	pane.set_context(model,false,text,painter.art,[1,1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<deadline:
		await process_frame;RenderingServer.force_draw(false,0.0)
		if not pane.failure.is_empty() or pane.layout_ready and Builder.source_ready(pane,painter) and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.art.jobs.is_empty():break
	check(pane.layout_ready and pane.failure.is_empty(),"Actual source controls prepare: "+pane.failure)
	var labels: Array=[];var levels: Array=[];var background_last:=-1
	if pane.layout_ready:
		for child in pane.content.get_children():
			if child is TextureRect and child.get_meta("native_gui_static_image",false):background_last=maxi(background_last,child.get_index())
		for child in pane.content.get_children():
			if child is Label and not child.text.is_empty():
				labels.append({"text":child.text,"index":child.get_index(),"position":[child.position.x,child.position.y],"size":[child.size.x,child.size.y],"fontApplied":child.has_meta("native_font_applied")})
				if child.text in ["Available/Known","Selected/Prepared","3"]:check(child.get_index()>background_last,"Claimed header/counter is painted above the opaque list background: "+child.text)
		for level in 10:
			var button: Button=pane.buttons["spelllevel"+str(level)];var data: Dictionary=painter.button_geometry[button.get_instance_id()]
			levels.append({"level":level,"visible":button.visible,"disabled":button.disabled,"position":[button.position.x,button.position.y],"size":[button.size.x,button.size.y],"drawn":str(data.get("drawn",{})),"stylesReady":data.styles.values().all(func(pair):return pair[0].texture!=null),"wantedBounds":painter.rendered_rect(data.resource,"checkedup" if level==1 else "uncheckedup",data.offset,data.overrides)!=null})
		check(levels[0].stylesReady and levels[1].stylesReady and levels[0].wantedBounds and levels[1].wantedBounds,"Current enabled tabs have actual finished native art and bounds")
		check(not str(painter.button_geometry[pane.buttons.spelllevel1.get_instance_id()].get("drawn",{})).is_empty(),"The checked tab reached the real painter draw callback")
		check(pane.rows.available[0].icon.texture!=null,"The current visible row's real installed bitmap completes alongside native tab artwork")
		await process_frame;RenderingServer.force_draw(false,0.0)
		var picture:=surface.get_texture().get_image();picture.save_png(str(args.report).trim_suffix(".json")+".png")
		for child in pane.content.get_children():
			if child is Label and child.text in ["Available/Known","Selected/Prepared","3"]:
				var rect:=Rect2(pane.position+child.position+Vector2(1,2),child.size-Vector2(2,4))
				check(white_ink(picture,rect)>=8,"The final pixels contain readable original-font foreground text: "+child.text)
	var artist: Dictionary=painter.art.models.snapshot();var fonts: Dictionary=painter.fonts.snapshot();var owned_window:={"position":[root.position.x,root.position.y],"noFocus":root.get_flag(Window.FLAG_NO_FOCUS)}
	pane.close();pane.free();painter.close();painter.free();surface.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"labels":labels,"levels":levels,"artist":artist,"fonts":fonts,"ownedWindow":owned_window,"scope":"Actual full CG_SPELLS controls, original bitmap fonts and real native model/raster publication in one850x650 private UI viewport with an offscreen non-activating owned window. Authored detached spell context; no FPS benchmark, draft/server or original-client visual acceptance.","gpuRaster":true,"gpuBenchmark":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
