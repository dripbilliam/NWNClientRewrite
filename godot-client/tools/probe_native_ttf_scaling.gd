extends SceneTree
# CPU/headless font-cache geometry and layout probe. No canvas/window/GPU test,
# font-file dump, source asset modification or production font installation.
const Prototype=preload("res://tools/native_ttf_scaling_prototype.gd")
var ts
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func shape(font: Font,height: int,value: String) -> Dictionary:
	var line:=TextLine.new(); line.add_string(value,font,height); var width:=line.get_line_width(); var glyphs: Array=[]; var sum:=0.0
	for glyph in ts.shaped_text_get_glyphs(line.get_rid()):
		glyphs.append({"glyph":glyph.index,"advance":glyph.advance,"repeat":glyph.repeat,"offset":[glyph.offset.x,glyph.offset.y]}); sum+=float(glyph.advance)*int(glyph.repeat)
	return {"text":value,"width":width,"advance_sum":sum,"height":line.get_line_ascent()+line.get_line_descent(),"glyphs":glyphs}
func contour_bounds(rid: RID,height: int,glyph: int) -> Variant:
	var data: Dictionary=ts.font_get_glyph_contours(rid,height,glyph); var points: PackedVector3Array=data.get("points",PackedVector3Array())
	if points.is_empty(): return null
	var bounds:=Rect2(Vector2(points[0].x,points[0].y),Vector2.ZERO)
	for point in points: bounds=bounds.expand(Vector2(point.x,point.y))
	return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","inputs","oracle"]) or FileAccess.file_exists(args.report): quit(2); return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.inputs)); var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var fonts: Array=[]
	ts=TextServerManager.get_primary_interface()
	for resource in inputs.resources:
		var native: Dictionary={}
		for entry in original.fonts: if entry.name==resource.name: native=entry
		if native.is_empty() or native.font_sha256!=resource.sha256 or FileAccess.get_sha256(resource.path)!=resource.sha256: failures.append("Original font identity mismatch: "+str(resource.name)); continue
		var bytes:=FileAccess.get_file_as_bytes(resource.path); var modes: Array=[]
		for mode in ["baseline","unhinted","variation","transform","transform_os4","cache_scale","transform_metrics","bitmap","bitmap_os4","bitmap_fractional","transform_fractional"]:
			for size in native.sizes:
				var began:=Time.get_ticks_usec(); var packet:=Prototype.make(bytes,resource.header,size,mode); var font: Font=packet.font; var height:=int(size.requested_height); var rid: RID=font.get_rids()[0]; var glyphs: Array=[]; var geometry: Array=[]; var maximum_error:=0.0
				for row in size.glyphs:
					var code:=int(row.codepoint); var glyph: int=ts.font_get_glyph_index(rid,height,code,0); var advance: float=ts.font_get_glyph_advance(rid,height,glyph).x; var error:=absf(advance-float(row.native_advance_pixels)); maximum_error=maxf(maximum_error,error)
					glyphs.append({"byte":row.byte,"glyph":glyph,"advance":advance,"native":row.native_advance_pixels,"error":error})
					if int(row.byte) in [32,65,87,103,105,106,124,233]:
						ts.font_render_glyph(rid,Vector2i(height,0),glyph); var offset: Vector2=ts.font_get_glyph_offset(rid,Vector2i(height,0),glyph); var extent: Vector2=ts.font_get_glyph_size(rid,Vector2i(height,0),glyph)
						geometry.append({"byte":row.byte,"glyph":glyph,"offset":[offset.x,offset.y],"size":[extent.x,extent.y],"contour_bounds":null if mode.begins_with("bitmap") else contour_bounds(rid,height,glyph),"copied_source":packet.get("source_geometry",{}).get(code)})
				var strings: Array=[]
				for value in ["A","Nibs","Uninjured","Skrul'nak the Barfly","AV fi ffi","WWWWiiii 1234"]: strings.append(shape(font,height,value))
				modes.append({"mode":mode,"height":height,"line_height":font.get_height(height),"ascent":font.get_ascent(height),"descent":font.get_descent(height),"maximum_advance_error":maximum_error,"glyphs":glyphs,"geometry":geometry,"strings":strings,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
		fonts.append({"name":resource.name,"sha256":resource.sha256,"header":resource.header,"modes":modes})
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"failures":failures,"fonts":fonts,"headless":true,"gpuBenchmark":false,"publicConnections":0,"productionChanged":false,"sourceAssetsExported":false},"  ")+"\n"); output.close(); quit(0 if failures.is_empty() else 1)
