extends RefCounted
# Investigation-only builder. The production font owner does not import this.
# One FontFile owns the resized real glyph cache and corresponding native
# metrics. There is no global cache or original-oracle dependency at runtime.
const SFNT=preload("res://systems/native_data/font_data.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
static func f32(value: float) -> float: return PackedFloat32Array([value])[0]
static func s16(value: int) -> int: return value-65536 if value>=32768 else value
static func fail(reason: String) -> Dictionary: return {"success":false,"error":reason,"font":null}
static func build(bytes: PackedByteArray,height: int,outline_widths: Array=[0]) -> Dictionary:
	if height<1 or height>256: return fail("Unsupported prototype pixel height")
	if outline_widths.is_empty() or outline_widths.size()>4 or not outline_widths.has(0): return fail("Unsupported prototype outline caches")
	for outline in outline_widths:
		if not outline is int or outline<0 or outline>4: return fail("Unsupported prototype outline width")
	var parser:=SFNT.new(); var decoded:=parser.parse(bytes)
	if not parser.failure.is_empty(): return fail(parser.failure)
	var tables: Dictionary=decoded.tables
	if not tables.has_all(["head","hhea","hmtx","maxp"]): return fail("Required font metrics unavailable")
	if int(tables.head.length)<54 or int(tables.hhea.length)<36 or int(tables.maxp.length)<6: return fail("Truncated font metrics")
	var units:=SFNT.u16(bytes,int(tables.head.offset)+18); var ascent:=s16(SFNT.u16(bytes,int(tables.hhea.offset)+4)); var descent:=s16(SFNT.u16(bytes,int(tables.hhea.offset)+6))
	var metric_count:=SFNT.u16(bytes,int(tables.hhea.offset)+34); var glyph_count:=SFNT.u16(bytes,int(tables.maxp.offset)+4)
	if units<=0 or ascent<=descent or metric_count<1 or metric_count>glyph_count or glyph_count<1: return fail("Invalid font metric counts or scale")
	if int(tables.hmtx.length)<metric_count*4+(glyph_count-metric_count)*2: return fail("Truncated horizontal metrics")
	var scale:=f32(float(height)/float(ascent-descent)); var baseline:=roundi(float(height)*float(ascent)/float(ascent-descent)); var ratio:=float(units)/float(ascent-descent)
	var source:=FontFile.new(); source.data=bytes; source.allow_system_fallback=false; source.generate_mipmaps=false; source.multichannel_signed_distance_field=false
	source.hinting=TextServer.HINTING_NONE; source.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED; source.oversampling=1.0
	source.set_transform(0,Transform2D(Vector2(ratio,0),Vector2(0,ratio),Vector2.ZERO))
	var rows: Array=[]; var cache_size:=Vector2i(height,0)
	for byte in 256:
		var code: int=Binary.CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
		var glyph:=source.get_glyph_index(height,124 if code==0 else code,0)
		if glyph<0 or glyph>=glyph_count: return fail("Glyph index outside font metrics")
		var advance:=f32(float(SFNT.u16(bytes,int(tables.hmtx.offset)+mini(glyph,metric_count-1)*4))*scale)
		for outline in outline_widths: source.render_glyph(0,Vector2i(height,outline),glyph)
		rows.append({"byte":byte,"codepoint":code,"glyph":glyph,"advance":advance})
	var font:=FontFile.new(); font.font_name="Native height TTF investigation"; font.fixed_size=height; font.fixed_size_scale_mode=TextServer.FIXED_SIZE_SCALE_DISABLE
	font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false; font.modulate_color_glyphs=true
	font.hinting=TextServer.HINTING_NONE; font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER; font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
	font.set_cache_ascent(0,height,baseline); font.set_cache_descent(0,height,height-baseline); font.set_cache_scale(0,height,1.0)
	var texture_bytes:=0
	for outline in outline_widths:
		var shape_size:=Vector2i(height,outline)
		for index in source.get_texture_count(0,shape_size):
			var image:=source.get_texture_image(0,shape_size,index); texture_bytes+=image.get_data().size(); font.set_texture_image(0,shape_size,index,image)
	for row in rows:
		var glyph:=int(row.glyph); var code:=int(row.codepoint)
		var offset:=source.get_glyph_offset(0,cache_size,glyph); var extent:=source.get_glyph_size(0,cache_size,glyph); var uv:=source.get_glyph_uv_rect(0,cache_size,glyph); var texture:=source.get_glyph_texture_idx(0,cache_size,glyph)
		font.set_glyph_advance(0,height,code,Vector2(float(row.advance),0)); font.set_glyph_offset(0,cache_size,code,offset); font.set_glyph_size(0,cache_size,code,extent); font.set_glyph_uv_rect(0,cache_size,code,uv); font.set_glyph_texture_idx(0,cache_size,code,texture)
		for outline in outline_widths:
			if outline==0: continue
			var shape_size:=Vector2i(height,outline)
			font.set_glyph_offset(0,shape_size,code,source.get_glyph_offset(0,shape_size,glyph)); font.set_glyph_size(0,shape_size,code,source.get_glyph_size(0,shape_size,glyph)); font.set_glyph_uv_rect(0,shape_size,code,source.get_glyph_uv_rect(0,shape_size,glyph)); font.set_glyph_texture_idx(0,shape_size,code,source.get_glyph_texture_idx(0,shape_size,glyph))
		row["offset"]=[offset.x,offset.y]; row["size"]=[extent.x,extent.y]; row["texture"]=texture; row["uv"]=[uv.position.x,uv.position.y,uv.size.x,uv.size.y]
	return {"success":true,"error":"","font":font,"height":height,"baseline":baseline,"scale":scale,"rows":rows,"texture_bytes":texture_bytes,"texture_count":source.get_texture_count(0,cache_size),"outline_widths":outline_widths.duplicate(),"units_per_em":units,"ascent":ascent,"descent":descent}
