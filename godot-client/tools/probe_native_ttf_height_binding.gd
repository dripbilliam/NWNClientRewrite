extends SceneTree
const Builder=preload("res://tools/native_ttf_height_font.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,why: String) -> void:
	checks+=1
	if not value: failures.append(why)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var cases: Array=[]
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); check(FileAccess.get_sha256(resource.path)==resource.sha256,"Font identity")
		var began:=Time.get_ticks_usec(); var packet:=Builder.build(bytes,14,[0,1,2]); var elapsed:=(Time.get_ticks_usec()-began)/1000.0; check(packet.success,"Outline candidate builds"); var font: FontFile=packet.font
		var outline_geometry: Array=[]
		for outline in [0,1,2]:
			var size:=Vector2i(14,outline); var glyph:=font.get_glyph_index(14,65,0); var rectangle:=font.get_glyph_size(0,size,glyph); var texture:=font.get_glyph_texture_idx(0,size,glyph)
			check(texture>=0 and rectangle.x>0 and rectangle.y>0,"Real outline raster cache exists")
			outline_geometry.append({"outline":outline,"texture":texture,"offset":font.get_glyph_offset(0,size,glyph),"size":rectangle,"uv":font.get_glyph_uv_rect(0,size,glyph),"textures":font.get_texture_count(0,size)})
		var scales: Array=[]
		for scale_factor in [1.0,1.25,1.5,2.0]:
			var label:=Label.new(); label.text="Nibs"; label.scale=Vector2.ONE*scale_factor; label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",14); label.add_theme_constant_override("outline_size",1); label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",1); root.add_child(label); label.reset_size()
			check(label.get_minimum_size().y==14,"Physical scaling preserves logical line")
			check(label.get_global_rect().size==label.size*scale_factor,"Control transforms scale actual draw bounds and metrics together")
			scales.append({"scale":scale_factor,"logical":label.size,"physical":label.get_global_rect().size}); label.queue_free()
		var canvas:=RenderingServer.canvas_item_create(); var rid: RID=font.get_rids()[0]; var ts:=TextServerManager.get_primary_interface(); var glyph:=font.get_glyph_index(14,65,0)
		# Dummy headless RenderingServer accepts the real glyph/outline draw
		# calls, but there is no framebuffer/pixel or GPU acceptance here.
		ts.font_draw_glyph(rid,canvas,14,Vector2(10,20),glyph,Color.WHITE); ts.font_draw_glyph_outline(rid,canvas,14,1,Vector2(10,20),glyph,Color.BLACK); RenderingServer.free_rid(canvas)
		var rich:=RichTextLabel.new(); rich.bbcode_enabled=true; rich.fit_content=true; rich.scroll_active=false; rich.autowrap_mode=TextServer.AUTOWRAP_OFF; rich.size=Vector2(400,100); rich.text="[color=red]Nibs[/color]\nUninjured"; rich.add_theme_font_override("normal_font",font); rich.add_theme_font_size_override("normal_font_size",14); root.add_child(rich); await process_frame
		check(rich.get_line_count()==2,"Real RichTextLabel retains two authored lines"); check(rich.get_content_height()==28,"Real rich text uses native14 logical lines")
		cases.append({"font":resource.name,"outline_build_ms":elapsed,"texture_bytes":packet.texture_bytes,"outline_geometry":outline_geometry,"scales":scales,"rich_lines":rich.get_line_count(),"rich_content_height":rich.get_content_height(),"font_14_at_size_28":font.get_height(28),"dummy_draw_commands_accepted":true}); rich.queue_free()
		check(not Builder.build(bytes,14,[1]).success,"Outline request requires base cache"); check(not Builder.build(bytes,14,[0,5]).success,"Outline width bounded")
	await process_frame
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"headless":true,"gpu":false,"framebuffer":false,"productionChanged":false,"serverConnections":0,"sourceAssetsExported":false},"  ")+"\n"); output.close(); print("NATIVE_TTF_HEIGHT_BINDING ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
