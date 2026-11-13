extends RefCounted
# Investigation helper only. Never installed by the production font owner.
# Source bytes/images remain private in-memory resources, not exported assets.
static func base(bytes: PackedByteArray,unhinted: bool=false,oversampling: float=1.0) -> FontFile:
	var font:=FontFile.new(); font.data=bytes; font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false
	if unhinted: font.hinting=TextServer.HINTING_NONE; font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling=oversampling; return font
static func transform(ratio: float) -> Transform2D:
	return Transform2D(Vector2(ratio,0),Vector2(0,ratio),Vector2.ZERO)
static func make(bytes: PackedByteArray,header: Dictionary,size: Dictionary,mode: String) -> Dictionary:
	var height:=int(size.requested_height); var ratio:=float(header.units_per_em)/float(int(header.ascent)-int(header.descent))
	var source:=base(bytes,mode!="baseline",4.0 if mode in ["transform_os4","bitmap_os4"] else 1.0)
	if mode=="baseline": return {"font":source,"source":source,"mode":mode}
	if mode=="unhinted": return {"font":source,"source":source,"mode":mode}
	if mode=="variation":
		var font:=FontVariation.new(); font.base_font=source; font.variation_transform=transform(ratio); return {"font":font,"source":source,"mode":mode}
	if mode=="cache_scale": source.set_cache_scale(0,height,ratio); return {"font":source,"source":source,"mode":mode}
	source.set_transform(0,transform(ratio))
	if mode in ["transform","transform_os4"]: return {"font":source,"source":source,"mode":mode}
	var baseline:=roundi(float(height)*float(header.ascent)/float(int(header.ascent)-int(header.descent)))
	if mode in ["transform_metrics","transform_fractional"]:
		if mode=="transform_fractional": source.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
		for row in size.glyphs: source.render_glyph(0,Vector2i(height,0),int(row.glyph))
		for row in size.glyphs: source.set_glyph_advance(0,height,int(row.glyph),Vector2(float(row.native_advance_pixels),0))
		source.set_cache_ascent(0,height,baseline); source.set_cache_descent(0,height,height-baseline)
		return {"font":source,"source":source,"mode":mode}
	# Publish transformed source raster geometry and exact native advances into
	# one bitmap FontFile, so the same object owns both draw and layout data.
	var cache_size:=Vector2i(height,0)
	for row in size.glyphs: source.render_glyph(0,cache_size,int(row.glyph))
	var font:=FontFile.new(); font.font_name="Private native TTF prototype"; font.fixed_size=height; font.fixed_size_scale_mode=TextServer.FIXED_SIZE_SCALE_DISABLE
	font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false; font.modulate_color_glyphs=true
	font.hinting=TextServer.HINTING_NONE; font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED; font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
	if mode=="bitmap_fractional": font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	font.set_cache_ascent(0,height,baseline); font.set_cache_descent(0,height,height-baseline); font.set_cache_scale(0,height,1.0)
	for index in source.get_texture_count(0,cache_size): font.set_texture_image(0,cache_size,index,source.get_texture_image(0,cache_size,index))
	var geometry: Dictionary={}
	for row in size.glyphs:
		var glyph:=int(row.glyph); var code:=int(row.codepoint)
		var offset:=source.get_glyph_offset(0,cache_size,glyph); var extent:=source.get_glyph_size(0,cache_size,glyph); var uv:=source.get_glyph_uv_rect(0,cache_size,glyph); var texture:=source.get_glyph_texture_idx(0,cache_size,glyph)
		font.set_glyph_advance(0,height,code,Vector2(float(row.native_advance_pixels),0)); font.set_glyph_offset(0,cache_size,code,offset); font.set_glyph_size(0,cache_size,code,extent); font.set_glyph_uv_rect(0,cache_size,code,uv); font.set_glyph_texture_idx(0,cache_size,code,texture)
		geometry[code]={"offset":[offset.x,offset.y],"size":[extent.x,extent.y],"uv":[uv.position.x,uv.position.y,uv.size.x,uv.size.y],"texture":texture}
	return {"font":font,"source":source,"mode":mode,"source_geometry":geometry}
