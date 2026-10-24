extends RefCounted
# CPU data only: preserve compressed blocks/mips for native GPU publication.
const Binary = preload("res://systems/native_data/binary_data.gd")
const MAX_PIXELS := 16777216
var failure := ""
var reader
func reject(message: String) -> Dictionary:
	if failure.is_empty(): failure = message
	return {}
func dimensions(width: int, height: int) -> bool:
	return width > 0 and height > 0 and width < 32768 and height < 32768 and width * height <= MAX_PIXELS
func block_bytes(format: String, width: int, height: int) -> int:
	return ((width + 3) / 4) * ((height + 3) / 4) * (8 if format in ["dxt1_rgb", "dxt1_rgba", "etc1"] else 16)
func parse(bytes: PackedByteArray, type: int) -> Dictionary:
	failure = ""; reader = Binary.new(bytes)
	var result := {}
	match type:
		3: result = tga()
		2033: result = dds() if bytes.size() >= 4 and reader.text(0, 4) == "DDS " else bioware_dds()
		2073: result = ktx()
		_: return reject("Unsupported original raster type: " + str(type))
	if not reader.failure.is_empty(): return reject(reader.failure)
	if not failure.is_empty(): return {}
	result.type = type
	result.uv_flip_y = false # Stored row zero corresponds to original model v=0.
	return result
func packed_mips(at: int, width: int, height: int, format: String, count: int, allow_partial: bool = false) -> Array:
	var result: Array = []
	for level in count:
		var size := block_bytes(format, width, height)
		if at > reader.data.size() - size:
			if allow_partial and not result.is_empty(): break
			reject("Compressed raster mip is truncated"); return []
		result.append({"width": width, "height": height, "data": reader.bytes(at, size)})
		at += size
		if width == 1 and height == 1: break
		width = maxi(1, width >> 1); height = maxi(1, height >> 1)
	return result
func bioware_dds() -> Dictionary:
	if not reader.contains(0, 20): return reject("Truncated BioWare DDS header")
	var width: int = reader.u32(0); var height: int = reader.u32(4); var marker: int = reader.u32(8)
	if not dimensions(width, height) or marker not in [3, 4]: return reject("Invalid BioWare DDS dimensions/format")
	var format := "dxt1_rgb" if marker == 3 else "dxt5"
	if reader.u32(12) != block_bytes(format, width, height): return reject("Invalid BioWare DDS top mip size")
	var mips := packed_mips(20, width, height, format, 16, true)
	return {"width": width, "height": height, "format": format, "mips": mips, "generate_mips": false}
func dds() -> Dictionary:
	if not reader.contains(0, 128) or reader.u32(4) != 124: return reject("Invalid standard DDS header")
	var width: int = reader.u32(16); var height: int = reader.u32(12)
	if not dimensions(width, height) or reader.u32(112) & 0x200 or reader.u32(24) > 1: return reject("Only bounded 2D DDS rasters are admitted")
	var count := maxi(1, reader.u32(28)) if reader.u32(8) & 0x20000 else 1
	if count > 16: return reject("DDS mip count exceeds dimensions")
	var fourcc: String = reader.text(84, 4); var at := 128
	var format: String = {"DXT1":"dxt1_rgb", "DXT3":"dxt3", "DXT5":"dxt5", "ETC1":"etc1"}.get(fourcc, "")
	if fourcc == "DX10":
		if not reader.contains(128, 20) or reader.u32(132) != 3 or reader.u32(136) & 4 or reader.u32(140) != 1: return reject("Unsupported DDS DX10 texture kind")
		format = {95:"bc6h_unsigned",96:"bc6h_signed"}.get(reader.u32(128), ""); at = 148
	if not format.is_empty():
		return {"width":width, "height":height, "format":format, "mips":packed_mips(at,width,height,format,count), "generate_mips":false}
	var bits: int = reader.u32(88)
	if bits not in [24,32] or reader.u32(92) != 0xff0000 or reader.u32(96) != 0xff00 or reader.u32(100) != 0xff or (bits == 32 and reader.u32(104) != 0xff000000): return reject("Unsupported DDS pixel format")
	var mips: Array = []; var w := width; var h := height
	for level in count:
		var stride := bits / 8; var size := w * h * stride
		if not reader.contains(at, size): return reject("Truncated DDS raster")
		var pixels := PackedByteArray(); pixels.resize(w * h * 4)
		for index in w * h:
			pixels[index*4] = reader.u8(at+index*stride+2); pixels[index*4+1] = reader.u8(at+index*stride+1); pixels[index*4+2] = reader.u8(at+index*stride); pixels[index*4+3] = reader.u8(at+index*stride+3) if bits == 32 else 255
		mips.append({"width":w,"height":h,"data":pixels}); at += size
		w = maxi(1,w >> 1); h = maxi(1,h >> 1)
	return {"width":width,"height":height,"format":"rgba8","mips":mips,"generate_mips":false}
func ktx_u32(at: int, little: bool) -> int:
	var value: int = reader.u32(at)
	return value if little else ((value & 255) << 24) | ((value & 65280) << 8) | ((value >> 8) & 65280) | ((value >> 24) & 255)
func ktx() -> Dictionary:
	if not reader.contains(0,64) or reader.bytes(0,12) != PackedByteArray([171,75,84,88,32,49,49,187,13,10,26,10]): return reject("Invalid KTX1 header")
	var endian: int = reader.u32(12)
	if endian not in [0x04030201,0x01020304]: return reject("Invalid KTX byte order")
	var little := endian == 0x04030201
	var width := ktx_u32(36,little); var height := ktx_u32(40,little); var count := maxi(1,ktx_u32(56,little))
	if not dimensions(width,height) or count > 16 or ktx_u32(16,little) != 0 or ktx_u32(20,little) != 1 or ktx_u32(24,little) != 0 or ktx_u32(44,little) != 0 or ktx_u32(48,little) != 0 or ktx_u32(52,little) != 1: return reject("Unsupported KTX raster layout")
	var format: String = {33776:"dxt1_rgb",33777:"dxt1_rgba",33778:"dxt3",33779:"dxt5",36196:"etc1"}.get(ktx_u32(28,little), "")
	if format.is_empty(): return reject("Unsupported KTX compression")
	var at := 64 + ktx_u32(60,little); var w := width; var h := height; var mips: Array = []
	for level in count:
		if not reader.contains(at,4): return reject("Truncated KTX mip size")
		var size := ktx_u32(at,little); at += 4
		if size != block_bytes(format,w,h) or not reader.contains(at,size): return reject("Invalid KTX mip size")
		mips.append({"width":w,"height":h,"data":reader.bytes(at,size)}); at += size + ((4 - size % 4) % 4)
		w = maxi(1,w >> 1); h = maxi(1,h >> 1)
	return {"width":width,"height":height,"format":format,"mips":mips,"generate_mips":false}
func tga() -> Dictionary:
	if not reader.contains(0,18): return reject("Truncated TGA header")
	var kind: int = reader.u8(2); var width: int = reader.u16(12); var height: int = reader.u16(14); var bits: int = reader.u8(16)
	var paletted := kind in [1,9]; var grey := kind in [3,11]; var rle := kind in [9,10,11]
	if kind not in [1,2,3,9,10,11] or not dimensions(width,height) or bits not in [8,16,24,32]: return reject("Unsupported TGA raster")
	if paletted and (reader.u8(1) != 1 or bits != 8 or reader.u8(7) != 24 or reader.u16(5) > 256): return reject("Unsupported TGA palette")
	if not paletted and reader.u8(1) != 0: return reject("Unexpected TGA palette")
	if grey and bits not in [8,16] or not paletted and not grey and bits == 8: return reject("Invalid TGA pixel width")
	var stride := bits / 8; var cursor: int = 18 + reader.u8(0); var palette := PackedByteArray()
	if paletted:
		palette = reader.bytes(cursor,reader.u16(5)*3); cursor += palette.size()
	var count := width * height; var pixels := PackedByteArray(); pixels.resize(count*4); var done := 0
	while done < count:
		var run := 1; var repeat := false
		if rle:
			if not reader.contains(cursor,1): return reject("Truncated TGA RLE packet")
			var packet: int = reader.u8(cursor); cursor += 1; run = (packet & 127) + 1; repeat = (packet & 128) != 0
		if run > count - done or not reader.contains(cursor,stride * (1 if repeat else run)): return reject("TGA packet exceeds pixel data")
		for item in run:
			var source := cursor + (0 if repeat else item*stride); var dest := (done+item)*4
			if paletted:
				var index: int = reader.u8(source)
				if index*3+2 >= palette.size(): return reject("TGA palette index exceeds table")
				pixels[dest] = palette[index*3+2]; pixels[dest+1] = palette[index*3+1]; pixels[dest+2] = palette[index*3]; pixels[dest+3] = 255
			elif grey:
				pixels[dest] = reader.u8(source); pixels[dest+1] = pixels[dest]; pixels[dest+2] = pixels[dest]; pixels[dest+3] = reader.u8(source+1) if bits == 16 else 255
			elif bits == 16:
				var value: int = reader.u16(source)
				pixels[dest] = (value & 0x7c00) >> 7; pixels[dest+1] = (value & 0x3e0) >> 2; pixels[dest+2] = (value & 31) << 3; pixels[dest+3] = 0 if value & 0x8000 else 255
			else:
				pixels[dest] = reader.u8(source+2); pixels[dest+1] = reader.u8(source+1); pixels[dest+2] = reader.u8(source); pixels[dest+3] = reader.u8(source+3) if bits == 32 else 255
		cursor += stride * (1 if repeat else run); done += run
	# Ignore descriptor origin bits, as the original CResTGA reader does.
	return {"width":width,"height":height,"format":"rgba8","mips":[{"width":width,"height":height,"data":pixels}],"generate_mips":true}
