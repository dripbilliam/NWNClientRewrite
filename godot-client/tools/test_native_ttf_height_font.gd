extends SceneTree
const Builder=preload("res://tools/native_ttf_height_font.gd")
const SFNT=preload("res://systems/native_data/font_data.gd")
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
	if not args.has_all(["report","inputs","oracle","boxes"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var box_oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.boxes)); var reports: Array=[]
	for resource in inputs.resources:
		var bytes:=FileAccess.get_file_as_bytes(resource.path); check(FileAccess.get_sha256(resource.path)==resource.sha256,"Font source identity")
		var native: Dictionary={}; var native_boxes: Dictionary={}
		for entry in original.fonts: if entry.name==resource.name: native=entry
		for entry in box_oracle.fonts: if entry.name==resource.name: native_boxes=entry
		check(not native.is_empty() and native.font_sha256==resource.sha256 and native_boxes.sha256==resource.sha256,"Original oracle identity")
		for size in native.sizes:
			var height:=int(size.requested_height); var timings: Array=[]; var packet: Dictionary={}
			for repetition in 8:
				var began:=Time.get_ticks_usec(); packet=Builder.build(bytes,height); timings.append((Time.get_ticks_usec()-began)/1000.0); check(packet.success,"Candidate construction")
			var font: FontFile=packet.font; var glyphs: Array=[]; var geometry_differences: Array=[]; var expected_boxes: Array=[]
			for entry in native_boxes.sizes: if int(entry.height)==height: expected_boxes=entry.glyphs
			check(font.get_height(height)==height,"Native logical line height"); check(font.get_ascent(height)==packet.baseline and font.get_descent(height)==height-packet.baseline,"Native baseline and descent")
			check(font.data.is_empty() and not font.allow_system_fallback,"Detached private bitmap publication; no system fallback")
			for row in size.glyphs:
				var byte:=int(row.byte); var code:=int(row.codepoint); var built: Dictionary=packet.rows[byte]; var glyph:=font.get_glyph_index(height,code,0); var actual:=font.get_glyph_advance(0,height,glyph).x
				# The original SSE result is binary32. Normalize the JSON reader's
				# decimal-to-binary64 conversion before comparing its exact float bits.
				check(int(built.glyph)==int(row.glyph),"Native glyph mapping byte "+str(byte)); check(actual==Builder.f32(float(row.native_advance_pixels)),"Exact native binary32 raw advance byte "+str(byte))
				var box: Array=expected_boxes[byte].bitmap_box; var expected:=[int(box[0])-1,int(box[1])-1,int(box[2])-int(box[0])+2,int(box[3])-int(box[1])+2]; var rect: Array=[int(built.offset[0]),int(built.offset[1]),int(built.size[0]),int(built.size[1])]
				if bool(expected_boxes[byte].present) and rect!=expected: geometry_differences.append({"byte":byte,"native_box":box,"candidate":rect,"expected_padded":expected})
				if built.size[0]>0 and built.size[1]>0:
					check(int(built.texture)>=0 and int(built.texture)<packet.texture_count,"Real glyph cache texture available")
					var image:=font.get_texture_image(0,Vector2i(height,0),int(built.texture)); check(built.uv[0]>=0 and built.uv[1]>=0 and built.uv[0]+built.uv[2]<=image.get_width() and built.uv[1]+built.uv[3]<=image.get_height(),"Glyph texture UV in bounds")
				glyphs.append({"byte":byte,"glyph":glyph,"advance":actual,"offset":built.offset,"size":built.size})
			var label:=Label.new(); label.text="Nibs"; label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",height); root.add_child(label)
			check(label.get_minimum_size().y==height,"Actual Label font minimum height")
			var line:=TextLine.new(); line.add_string(label.text,font,height); var shaped: Array=TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()); var maximum_shaping_error:=0.0; var total_native:=0.0
			for glyph in shaped:
				var code:=int(glyph.index); var raw:=font.get_glyph_advance(0,height,code).x; maximum_shaping_error=maxf(maximum_shaping_error,absf(float(glyph.advance)-raw)); total_native+=raw
			check(maximum_shaping_error<1.0/64.0,"Godot shaping has less than 1/64px per-glyph quantization error")
			check(line.get_line_width()==ceilf(total_native),"Actual TextLine bounds ceil the whole native-width line")
			var before:=font.get_glyph_advance(0,height,65).x; var changed:=bytes.duplicate(); var detached:=Builder.build(changed,height); changed.fill(0); check(detached.font.get_glyph_advance(0,height,65).x==before,"Mutating the actual supplied input bytes does not mutate published metrics")
			var rebuilt:=Builder.build(bytes,height); check(rebuilt.font!=font,"Independent builder results do not expose a global mutable font cache")
			rebuilt.font.set_glyph_advance(0,height,65,Vector2(99,0)); check(font.get_glyph_advance(0,height,65).x==before,"Mutating one candidate cannot mutate another font")
			reports.append({"name":resource.name,"height":height,"ascent":font.get_ascent(height),"descent":font.get_descent(height),"timings_ms":timings,"texture_bytes":packet.texture_bytes,"texture_count":packet.texture_count,"native_box_comparison_differences":geometry_differences,"shaping_maximum_error":maximum_shaping_error,"label_minimum":[label.get_minimum_size().x,label.get_minimum_size().y],"glyphs":glyphs})
			label.queue_free(); await process_frame
		var parser:=SFNT.new(); var decoded:=parser.parse(bytes); var broken:=bytes.duplicate(); broken[int(decoded.tables.hhea.offset)+34]=0; broken[int(decoded.tables.hhea.offset)+35]=0
		check(not Builder.build(broken,14).success,"Reject zero horizontal metrics"); check(not Builder.build(bytes,0).success,"Reject zero height"); check(not Builder.build(bytes,257).success,"Reject unreasonable prototype height"); check(not Builder.build(bytes.slice(0,15),14).success,"Reject truncated SFNT")
	await process_frame
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"fonts":reports,"headless":true,"gpuBenchmark":false,"serverConnections":0,"productionChanged":false,"originalPixelsAccepted":false,"nativeAtlasEnhancementAccepted":false,"sourceAssetsExported":false},"  ")+"\n"); output.close(); print("NATIVE_TTF_HEIGHT_FONT ",checks," checks; ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
