extends RefCounted
# Investigation only: private, checksummed SFNT metric adaptation. The original
# resource remains unchanged. This is not imported by the production font owner.
const SFNT=preload("res://systems/native_data/font_data.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
static func f32(value: float) -> float: return PackedFloat32Array([value])[0]
static func s16(value: int) -> int: return value-65536 if value>=32768 else value
static func w16(bytes: PackedByteArray,at: int,value: int) -> void:
	bytes[at]=(value>>8)&255; bytes[at+1]=value&255
static func w32(bytes: PackedByteArray,at: int,value: int) -> void:
	for index in 4: bytes[at+index]=(value>>(24-index*8))&255
static func sum32(bytes: PackedByteArray,start: int,length: int) -> int:
	var total:=0
	for index in range(0,length,4):
		var value:=0
		for offset in 4: value=(value<<8)|(int(bytes[start+index+offset]) if index+offset<length else 0)
		total=(total+value)&0xffffffff
	return total
static func derive(bytes: PackedByteArray) -> Dictionary:
	var parser:=SFNT.new(); var decoded:=parser.parse(bytes)
	if not parser.failure.is_empty(): return {"success":false,"error":parser.failure}
	var tables: Dictionary=decoded.tables
	if not tables.has_all(["head","hhea","hmtx","maxp","loca","glyf"]) or int(tables.head.length)<54 or int(tables.hhea.length)<36 or int(tables.maxp.length)<6: return {"success":false,"error":"Supported TrueType metrics unavailable"}
	var head:=int(tables.head.offset); var ascent:=s16(SFNT.u16(bytes,int(tables.hhea.offset)+4)); var descent:=s16(SFNT.u16(bytes,int(tables.hhea.offset)+6)); var units:=ascent-descent
	if units<16 or units>16384: return {"success":false,"error":"Derived em scale outside TrueType range"}
	var metric_count:=SFNT.u16(bytes,int(tables.hhea.offset)+34); var glyph_count:=SFNT.u16(bytes,int(tables.maxp.offset)+4)
	if metric_count<1 or metric_count>glyph_count or int(tables.hmtx.length)<metric_count*4+(glyph_count-metric_count)*2: return {"success":false,"error":"Invalid or truncated horizontal font metrics"}
	if head%4!=0: return {"success":false,"error":"Unaligned TrueType head table"}
	var derived:=bytes.duplicate(); w16(derived,head+18,units)
	var head_entry:=-1
	for index in SFNT.u16(bytes,4):
		var at:=12+index*16
		if bytes.slice(at,at+4).get_string_from_ascii()=="head": head_entry=at; break
	if head_entry<0: return {"success":false,"error":"Missing font head directory entry"}
	# The low halfword of head+16 changes by delta; the head-directory
	# checksum changes by the same delta. Adjustment therefore changes by
	# -2*delta. This preserves the source checksum, including noncanonical
	# source files, without scanning the whole TTF on the publication thread.
	var delta:=units-SFNT.u16(bytes,head+18)
	w32(derived,head_entry+4,(SFNT.u32(bytes,head_entry+4)+delta)&0xffffffff); w32(derived,head+8,(SFNT.u32(bytes,head+8)-2*delta)&0xffffffff)
	return {"success":true,"error":"","data":derived,"source_units":SFNT.u16(bytes,head+18),"derived_units":units,"ascent":ascent,"descent":descent,"hmtx_offset":int(tables.hmtx.offset),"metric_count":metric_count,"glyph_count":glyph_count,"checksum_preserved":true,"checksum_method":"bounded changed-word delta"}
static func make(bytes: PackedByteArray,height: int,oversampling: float=0.0) -> Dictionary:
	if height<1 or height>512: return {"success":false,"error":"Unsupported font pixel height"}
	if not is_finite(oversampling) or oversampling<0 or oversampling>8: return {"success":false,"error":"Unsupported font raster scale"}
	var packet:=derive(bytes)
	if not packet.success: return packet
	var font:=FontFile.new(); font.data=packet.data; font.allow_system_fallback=false; font.generate_mipmaps=false; font.multichannel_signed_distance_field=false; font.hinting=TextServer.HINTING_NONE; font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER; font.oversampling=oversampling
	var baseline:=roundi(float(height)*packet.ascent/float(packet.derived_units)); font.set_cache_ascent(0,height,baseline); font.set_cache_descent(0,height,height-baseline)
	var scale:=f32(float(height)/float(packet.derived_units)); var rows: Array=[]
	for byte in 256:
		var code: int=Binary.CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
		var glyph:=font.get_glyph_index(height,124 if code==0 else code,0)
		if glyph<0 or glyph>=int(packet.glyph_count): return {"success":false,"error":"Glyph index outside font metrics"}
		var advance:=f32(float(SFNT.u16(packet.data,int(packet.hmtx_offset)+mini(glyph,int(packet.metric_count)-1)*4))*scale)
		# Render before overriding: a manually created cache glyph otherwise
		# has advance but no draw rectangle and can prevent demand rasterizing.
		font.render_glyph(0,Vector2i(height,0),glyph); font.set_glyph_advance(0,height,glyph,Vector2(advance,0)); rows.append({"byte":byte,"codepoint":code,"glyph":glyph,"advance":advance})
	font.set_meta("native_ttf_pixel_height",true); font.set_meta("native_ttf_pixel_height_prepared",height)
	packet.font=font; packet.height=height; packet.baseline=baseline; packet.rows=rows; return packet
