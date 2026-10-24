extends RefCounted
# PLT pixels and palette TGAs both retain the original bottom-up file order.
# Color row zero is therefore TGA row zero, without a second texture flip.
const Raster=preload("res://systems/native_data/texture_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const NAMES=["pal_skin01","pal_hair01","pal_armor01","pal_armor02","pal_cloth01","pal_cloth01","pal_leath01","pal_leath01","pal_tattoo01","pal_tattoo01"]
var failure:=""
func reject(reason: String) -> Dictionary:
	failure=reason; return {}
func header(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()<24 or bytes.slice(0,8).get_string_from_ascii()!="PLT V1  ": return reject("Invalid original PLT header")
	var layers:=bytes.decode_u32(8); var width:=bytes.decode_u32(16); var height:=bytes.decode_u32(20)
	if layers<1 or layers>NAMES.size() or width<1 or height<1 or width>32767 or height>32767 or width*height>Raster.MAX_PIXELS: return reject("Invalid original PLT dimensions/layers")
	if bytes.size()<24+width*height*2: return reject("Original PLT pixels are truncated")
	var used: Array=[]
	for pixel in width*height:
		var layer:=mini(bytes[25+pixel*2],NAMES.size()-1)
		if not used.has(NAMES[layer]): used.append(NAMES[layer])
	return {"width":width,"height":height,"palettes":used}
func decode(bytes: PackedByteArray, palettes: Dictionary, color_rows: Array=[]) -> Dictionary:
	var info:=header(bytes)
	if info.is_empty(): return {}
	for name in info.palettes:
		var palette: Dictionary=palettes.get(name,{})
		if palette.get("format")!="rgba8" or int(palette.get("width",0))!=256 or int(palette.get("height",0))<1 or palette.get("mips",[]).is_empty(): return reject("Original PLT palette is invalid: "+name)
		if not palette.mips[0].get("data") is PackedByteArray or palette.mips[0].data.size()!=int(palette.height)*256*4: return reject("Original PLT palette pixels are invalid: "+name)
	var output:=PackedByteArray(); output.resize(int(info.width)*int(info.height)*4)
	for pixel in int(info.width)*int(info.height):
		var intensity:=int(bytes[24+pixel*2]); var layer:=mini(int(bytes[25+pixel*2]),NAMES.size()-1)
		var palette: Dictionary=palettes[NAMES[layer]]
		var row:=0
		if layer<color_rows.size():
			var number: Variant=color_rows[layer]
			if not (number is int or number is float) or not is_finite(float(number)): return reject("Invalid original PLT color row")
			row=clampi(int(number),0,int(palette.height)-1)
		var at: int=(row*256+intensity)*4; var source: PackedByteArray=palette.mips[0].data
		for component in 4: output[pixel*4+component]=source[at+component]
	return {"type":6,"width":info.width,"height":info.height,"format":"rgba8","uv_flip_y":false,"generate_mips":true,"mips":[{"width":info.width,"height":info.height,"data":output}]}
func prepare(catalog, name: String, color_rows: Array, cache_path: String="") -> Dictionary:
	var began:=Time.get_ticks_usec(); var bytes: PackedByteArray=catalog.get_resource(name,6)
	var info:=header(bytes) if catalog.failure.is_empty() else {}
	if info.is_empty(): return {"error":catalog.failure if not catalog.failure.is_empty() else failure}
	var palettes: Dictionary={}; var dependencies: Array=[]; var rows: Array=[]
	for layer in NAMES.size(): rows.append(color_rows[layer] if layer<color_rows.size() else 0)
	for palette_name in info.palettes:
		var raw: PackedByteArray=catalog.get_resource(palette_name,3)
		if not catalog.failure.is_empty(): return {"error":catalog.failure}
		var parser:=Raster.new(); var data:=parser.parse(raw,3)
		if not parser.failure.is_empty(): return {"error":palette_name+": "+parser.failure}
		palettes[palette_name]=data; dependencies.append([palette_name,Cache.digest(raw)])
	# A palette edit, per-part color change or PLT edit creates a new identity.
	# Pool texture keys and the persistent cache cannot alias two color sets.
	var source_sha:=Cache.digest(bytes); var identity:=Cache.digest(var_to_bytes(["plt-original-1",source_sha,dependencies,rows]))
	var cache:=Cache.new(); var cached:=not cache_path.is_empty() and cache.configure(cache_path)
	var decoder:="plt-original"; var key:=Cache.key(identity,decoder)
	if cached:
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return {"value":saved,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":true,"palette_dependencies":dependencies,"prepare_ms":(Time.get_ticks_usec()-began)/1000.0}
	var value:=decode(bytes,palettes,rows)
	if not failure.is_empty(): return {"error":failure}
	if cached: cache.save_data(key,identity,decoder,value)
	return {"value":value,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":false,"palette_dependencies":dependencies,"prepare_ms":(Time.get_ticks_usec()-began)/1000.0}
