extends RefCounted
# PLT pixels and palette TGAs both retain the original bottom-up file order.
# Color row zero is therefore TGA row zero, without a second texture flip.
const Raster=preload("res://systems/native_data/texture_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Conversion=preload("res://systems/native_data/raster_conversion.gd")
const NAMES=["pal_skin01","pal_hair01","pal_armor01","pal_armor02","pal_cloth01","pal_cloth01","pal_leath01","pal_leath01","pal_tattoo01","pal_tattoo01"]
var failure:=""
var use_native:=Conversion.configured_enabled()
var stats:={"native_pixels":0,"gd_pixels":0,"palette_coalesced":0}
func reject(reason: String) -> Dictionary:
	failure=reason; return {}
func header(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()<24 or bytes.slice(0,8).get_string_from_ascii()!="PLT V1  ": return reject("Invalid original PLT header")
	var layers:=bytes.decode_u32(8); var width:=bytes.decode_u32(16); var height:=bytes.decode_u32(20)
	if layers<1 or layers>NAMES.size() or width<1 or height<1 or width>32767 or height>32767 or width*height>Raster.MAX_PIXELS: return reject("Invalid original PLT dimensions/layers")
	if bytes.size()<24+width*height*2: return reject("Original PLT pixels are truncated")
	var used: Array=[]; var mask:=0; var order:=Conversion.layer_order(bytes) if use_native and Conversion.available else 0
	if order!=0:
		# Ten nibbles preserve first encounter, including duplicate palette-name
		# channels. Existing dependency ordering/cache identities remain exact.
		while order!=0:
			var layer:=(order&15)-1; mask|=1<<layer; order>>=4
			if not used.has(NAMES[layer]): used.append(NAMES[layer])
	else:
		for pixel in width*height:
			var layer:=mini(bytes[25+pixel*2],NAMES.size()-1); mask|=1<<layer
			if not used.has(NAMES[layer]): used.append(NAMES[layer])
	return {"width":width,"height":height,"palettes":used,"layer_mask":mask}
func decode(bytes: PackedByteArray, palettes: Dictionary, color_rows: Array=[]) -> Dictionary:
	stats.native_pixels=0; stats.gd_pixels=0
	var info:=header(bytes)
	if info.is_empty(): return {}
	for name in info.palettes:
		var palette: Dictionary=palettes.get(name,{})
		if palette.get("format")!="rgba8" or int(palette.get("width",0))!=256 or int(palette.get("height",0))<1 or palette.get("mips",[]).is_empty(): return reject("Original PLT palette is invalid: "+name)
		if not palette.mips[0].get("data") is PackedByteArray or palette.mips[0].data.size()!=int(palette.height)*256*4: return reject("Original PLT palette pixels are invalid: "+name)
	if use_native and Conversion.available:
		var lookup:=PackedByteArray(); lookup.resize(NAMES.size()*256*4)
		for layer in NAMES.size():
			if (int(info.layer_mask)&(1<<layer))==0: continue
			var palette: Dictionary=palettes[NAMES[layer]]; var row:=0
			if layer<color_rows.size():
				var number: Variant=color_rows[layer]
				if not (number is int or number is float) or not is_finite(float(number)): return reject("Invalid original PLT color row")
				row=clampi(int(number),0,int(palette.height)-1)
			var source: PackedByteArray=palette.mips[0].data
			for component in 256*4: lookup[layer*256*4+component]=source[row*256*4+component]
		var converted:=Conversion.colorize(bytes,lookup)
		if converted.size()==int(info.width)*int(info.height)*4:
			stats.native_pixels+=int(info.width)*int(info.height)
			return {"type":6,"width":info.width,"height":info.height,"format":"rgba8","uv_flip_y":false,"generate_mips":true,"mips":[{"width":info.width,"height":info.height,"data":converted}]}
	var output:=PackedByteArray(); output.resize(int(info.width)*int(info.height)*4)
	stats.gd_pixels+=int(info.width)*int(info.height)
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
func parse_palette(raw: PackedByteArray) -> Dictionary:
	var parser:=Raster.new(); parser.use_native=use_native; var data:=parser.parse(raw,3)
	return {"value":data,"error":parser.failure,"conversion":parser.stats.duplicate()}
func palette_data(raw: PackedByteArray,store) -> Dictionary:
	var generation: int=store.generation() if store!=null else -1
	var request_key:="palette-tga-2:"+Cache.digest(raw)
	var lease: Dictionary=store.begin_data(request_key,generation,false) if store!=null else {"owner":true}
	if not lease.owner:
		return {"value":lease.value.value,"error":lease.value.error,"decoded":false,"coalesced":int(lease.wait_us)>0,"wait_ms":int(lease.wait_us)/1000.0}
	var parsed:=parse_palette(raw); var data: Dictionary=parsed.value
	var value:={"value":data,"error":parsed.error}
	# Palette source graphs are immutable to all consumers. Publish once without
	# duplicating the pixel graph; followers cannot race a second cold decode.
	if store!=null:
		if str(parsed.error).is_empty(): store.save_data(request_key,request_key,value,generation,data.mips[0].data.size()+2048,true)
		store.finish_data(request_key,generation,value)
	return {"value":data,"error":parsed.error,"decoded":true,"coalesced":false,"wait_ms":0.0,"conversion":parsed.conversion}
func prepare(catalog, name: String, color_rows: Array, cache_path: String="",icon_metal: bool=false) -> Dictionary:
	stats={"native_pixels":0,"gd_pixels":0,"palette_coalesced":0}
	var began:=Time.get_ticks_usec(); var bytes: PackedByteArray=catalog.get_resource(name,6)
	var info:=header(bytes) if catalog.failure.is_empty() else {}
	if info.is_empty(): return {"error":catalog.failure if not catalog.failure.is_empty() else failure}
	var palettes: Dictionary={}; var palette_sources: Dictionary={}; var dependencies: Array=[]; var rows: Array=[]
	for layer in NAMES.size(): rows.append(color_rows[layer] if layer<color_rows.size() else 0)
	for palette_name in info.palettes:
		# Original UpdateIcons uses palette type3 for both metal icon channels.
		var selected_name: String="pal_armor02" if icon_metal and palette_name=="pal_armor01" else palette_name
		var raw: PackedByteArray=catalog.get_resource(selected_name,3)
		if not catalog.failure.is_empty(): return {"error":catalog.failure}
		palette_sources[palette_name]=raw; dependencies.append([palette_name,Cache.digest(raw)])
	# A palette edit, per-part color change or PLT edit creates a new identity.
	# Pool texture keys and the persistent cache cannot alias two color sets.
	var source_sha:=Cache.digest(bytes); var identity:=Cache.digest(var_to_bytes(["plt-original-1",source_sha,dependencies,rows]))
	var cache:=Cache.new(); var cached:=not cache_path.is_empty() and cache.configure(cache_path)
	var decoder:="plt-original"; var key:=Cache.key(identity,decoder)
	if cached:
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return {"value":saved,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":true,"palette_dependencies":dependencies,"prepare_ms":(Time.get_ticks_usec()-began)/1000.0}
	# Dependency bytes must still be hashed before lookup, so edits invalidate
	# the persistent result. Their full pixel decoding is only needed on a miss.
	var palette_decodes:=0
	var palette_timings: Array=[]
	for palette_name in info.palettes:
		var raw: PackedByteArray=palette_sources[palette_name]
		var store=catalog.preparation_cache() if catalog.has_method("preparation_cache") else null
		var prepared:=palette_data(raw,store)
		palette_timings.append({"name":palette_name,"decoded":prepared.decoded,"coalesced":prepared.coalesced,"wait_ms":prepared.wait_ms,"conversion":prepared.get("conversion",{})})
		if not str(prepared.error).is_empty(): return {"error":palette_name+": "+str(prepared.error)}
		if prepared.decoded: palette_decodes+=1
		if prepared.coalesced: stats.palette_coalesced+=1
		palettes[palette_name]=prepared.value
	var value:=decode(bytes,palettes,rows)
	if not failure.is_empty(): return {"error":failure}
	if cached: cache.save_data(key,identity,decoder,value)
	return {"value":value,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":false,"palette_dependencies":dependencies,"palette_decodes":palette_decodes,"palette_timings":palette_timings,"conversion":stats.duplicate(),"prepare_ms":(Time.get_ticks_usec()-began)/1000.0}
