extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Attributes=preload("res://systems/native_level_up_attributes.gd")
const Builder=preload("res://systems/native_menu_builder.gd")
const Ink=preload("res://tests/native_font_ink_probe.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.set_flag(Window.FLAG_BORDERLESS,true);root.position=Vector2i(-32000,-32000);run.call_deferred()
func outside_screens()->bool:
	var rectangle:=Rect2i(root.position,root.size)
	for index in DisplayServer.get_screen_count():
		if rectangle.intersects(Rect2i(DisplayServer.screen_get_position(index),DisplayServer.screen_get_size(index))):return false
	return true
func black_band(image:Image)->Vector2i:
	var longest:=Vector2i();var start:=-1;var column:=int(image.get_width()*.5)
	for y in image.get_height()+1:
		var dark:=false
		if y<image.get_height():
			var color:=image.get_pixel(column,y);dark=color.a>.9 and maxf(color.r,maxf(color.g,color.b))<.025
		if dark and start<0:start=y
		elif not dark and start>=0:
			if y-start>longest.y:longest=Vector2i(start,y-start)
			start=-1
	return longest
func capture(surface:SubViewport)->Image:
	await process_frame;RenderingServer.force_draw(false,0.0);await process_frame;RenderingServer.force_draw(false,0.0)
	return surface.get_texture().get_image()
func run()->void:
	await process_frame
	# Initial-position policy can override _initialize's coordinates. Move the
	# owned window after that boundary, before preparing any private renderer.
	root.position=Vector2i(-32000,-32000);await process_frame
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var screens:Array=[]
	for index in DisplayServer.get_screen_count():screens.append(Rect2i(DisplayServer.screen_get_position(index),DisplayServer.screen_get_size(index)))
	var window_state:Dictionary={"visible":root.visible,"noFocus":root.get_flag(Window.FLAG_NO_FOCUS),"borderless":root.get_flag(Window.FLAG_BORDERLESS),"position":root.position,"size":root.size,"screens":screens}
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.get_flag(Window.FLAG_BORDERLESS) and outside_screens(),"Owned borderless GUI raster remains outside every actual screen and cannot activate")
	if not failures.is_empty():
		var rejection:=FileAccess.open(args.report,FileAccess.WRITE);rejection.store_string(JSON.stringify(Ink.packed({"success":false,"checks":checks,"failures":failures,"diagnostics":{"window":window_state},"gpuRaster":false,"gpuBenchmark":false}),"\t")+"\n");rejection.close();quit(1);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed GUI catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original source captions load")
	var surface:=SubViewport.new();surface.size=Vector2i(850,650);surface.transparent_bg=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,"")
	var pane:=Attributes.new();surface.add_child(pane);pane.position=Vector2(35,35);pane.configure(painter,text,catalog,"");pane.set_context({"ready":true,"scores":[11,16,12,18,10,8],"modifiers":[0,3,1,4,0,-1],"raw":[13,14,12,16,10,8],"racial":[-2,2,0,2,0,0],"gains":[0,0,0,0,0,0],"costs":[2,2,1,3,1,1],"points":1,"selectedAbility":-1},true,text,["levelup-attributes",1]);pane.open();pane.start()
	var end:=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<end:
		await process_frame;RenderingServer.force_draw(false,0.0)
		if not pane.failure.is_empty() or pane.layout_ready and Builder.source_ready(pane,painter) and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.art.jobs.is_empty():break
	check(pane.layout_ready and pane.failure.is_empty() and Builder.source_ready(pane,painter),"Source pane publishes actual installed artwork and FontFiles: "+pane.failure)
	var observations:Array=[];var labels:Array=[]
	if pane.layout_ready:
		var resource:String=pane.plan.entries.strlabel.resource
		for clip in ["","up","down","hilite"]:
			var key:String=painter.art.models.model_key(resource,clip,{})
			if painter.art.textures.has(key):painter.art.textures[key].get_image().save_png(str(args.report)+".row-"+("static" if clip.is_empty() else clip)+".png")
		for component in ["ctl_cg_lstbxat",pane.plan.resource]:
			var key:String=painter.art.models.model_key(component,"",{})
			if painter.art.textures.has(key):painter.art.textures[key].get_image().save_png(str(args.report)+"."+component+".png")
		for index in 6:
			var key:String=Attributes.LevelLayout.KEYS[index];var row:Button=pane.buttons[key+"label"];var label:Label=pane.values[index];var name:Label=row.get_child(0);labels.append_array([name,label])
			var entry:Dictionary=pane.plan.entries[key+"label"];var art_rect:Rect2;var artwork:Image;var clip:="up"
			if row.has_meta("native_attributes_static_row"):
				var image:TextureRect=row.get_meta("native_attributes_static_row");art_rect=image.get_rect();artwork=image.texture.get_image();clip=""
			else:
				var geometry:Dictionary=painter.button_geometry[row.get_instance_id()];art_rect=geometry.rect;artwork=geometry.styles.normal[0].texture.get_image()
			var band:=black_band(artwork);var black_rect:=Rect2(art_rect.position+Vector2(0,float(band.x)/artwork.get_height()*art_rect.size.y),Vector2(art_rect.size.x,float(band.y)/artwork.get_height()*art_rect.size.y))
			var number_ink:Dictionary=Ink.glyph_ink(label);var name_ink:Dictionary=Ink.glyph_ink(name)
			var actual_number:Rect2=number_ink.rect;var actual_name:Rect2=name_ink.rect;actual_name.position+=row.position
			observations.append({"key":key,"clip":clip,"blackBandPixels":band,"blackInteriorRect":black_rect,"sourceRowRect":entry.rect,"sourceOffset":entry.offset,"sourceTextHook":entry.model.hooks.text,"captionAnchor":entry.get("caption_anchor",null),"realArtRect":art_rect,"actualRowControl":row.get_rect(),"numberRect":label.get_rect(),"numberInk":actual_number,"nameRect":Rect2(row.position+name.position,name.size),"nameInk":actual_name,"artBounds":painter.art.bounds.get(painter.art.models.model_key(entry.resource,clip,{}),{}),"staticBounds":entry.model.bounds})
			check(label.get_index()>row.get_index() and label.get_parent()==row.get_parent(),"Mode1 numeric text paints above its opaque row: "+key)
			check(row.has_meta("native_attributes_static_row") and not painter.button_geometry.has(row.get_instance_id()),"Mode1 native label retains static artwork with no animated button draw callback: "+key)
			check(number_ink.present and name_ink.present,"Real installed glyph ink exists for both row fields: "+key)
			check(black_rect.encloses(actual_number) and absf(actual_number.get_center().y-black_rect.get_center().y)<=4.0,"Numeric ink centers inside actual native black row interior: "+key)
			check(black_rect.encloses(actual_name) and absf(actual_name.get_center().y-black_rect.get_center().y)<=4.0,"Ability name ink centers inside actual native black row interior: "+key)
		check(Rect2(Vector2.ZERO,pane.size).encloses(pane.title.get_rect()),"Mode1 claimed Title retains its original bounded alignment region")
		check(not pane.title.text.is_empty() and Ink.glyph_ink(pane.title).present,"Mode1 Title has actual installed text and FontFile ink")
		var image:=await capture(surface);image.save_png(str(args.report)+".normal.png")
		for label in labels:label.hide()
		var background:=await capture(surface);background.save_png(str(args.report)+".art-only.png")
		for label in labels:label.show()
		check(image.get_size()==Vector2i(850,650) and background.get_size()==image.get_size(),"Full actual-art raster and label-hidden baseline are captured at the same geometry")
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.get_flag(Window.FLAG_BORDERLESS) and outside_screens(),"Owned raster stays isolated through completion")
	var diagnostics:Dictionary={"window":window_state,"rows":observations,"rowModel":pane.models.get("ctl_cg_btn_att",{}),"fonts":painter.fonts.snapshot(),"artist":painter.art.models.snapshot(),"artFailure":painter.art.failed.keys(),"frameSize":pane.size,"panePosition":pane.position}
	pane.close();pane.free();painter.close();painter.free();text.close();surface.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(Ink.packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostics,"gpuRaster":true,"gpuBenchmark":false,"serverConnections":0,"scope":"Bounded hidden/non-activating actual installed level-up Attributes font/art raster and native row-origin alignment; no FPS benchmark, user process, rules mutation or original-client pixel claim."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
