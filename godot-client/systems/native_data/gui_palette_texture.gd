extends RefCounted
# Original GUI_CG_COLOR_TMP is a one-layer PLT. Its single WORD selector
# contains the distinct palette-file type in the high BYTE and row in the low
# BYTE; these are not the ten world-material palette row numbers.
const Palette=preload("res://systems/native_data/palette_texture.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const NAMES={0:"pal_skin01",1:"pal_hair01",6:"pal_tattoo01"}
static func reject(reason:String)->Dictionary:return {"ready":false,"error":reason,"reason":reason}
static func whole(value:Variant,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and int(value)==value and value>=0 and value<=maximum
static func sha(value:Variant)->bool:
	if not value is String or value.length()!=64:return false
	for character in value:
		if character not in "0123456789abcdef":return false
	return true
static func palette_data(value:Variant)->bool:
	return value is Dictionary and value.get("format")=="rgba8" and value.get("width")==256 and whole(value.get("height"),65535) and int(value.height)>0 and value.get("mips") is Array and not value.mips.is_empty() and value.mips[0] is Dictionary and value.mips[0].get("data") is PackedByteArray and value.mips[0].data.size()==256*int(value.height)*4
static func rows(metadata:Dictionary,source_hashes:Dictionary)->Dictionary:
	var output:Dictionary={};var sources:Dictionary={}
	for kind in NAMES:
		var name:String=NAMES[kind];var data:Variant=metadata.get(name)
		if not palette_data(data) or not sha(source_hashes.get(name)):return reject("The active GUI palette pixels/source are unavailable: "+name)
		for row in mini(256,int(data.height)):
			var selector:int=(int(kind)<<8)|row
			output[selector]=data.mips[0].data.slice(row*1024,(row+1)*1024);sources[selector]=source_hashes[name]
	return {"ready":true,"rows":output,"sources":sources}
static func selection(descriptor:Dictionary)->Dictionary:
	if str(descriptor.get("resource","")).to_lower()!="gui_cg_color_tmp":return reject("Unsupported original GUI palette template.")
	var colors:Variant=descriptor.get("palette")
	if not colors is Array or colors.size()!=1 or not whole(colors[0],65535):return reject("The original GUI palette requires one packed WORD selector.")
	var selector:=int(colors[0]);var kind:int=selector>>8
	if not NAMES.has(kind):return reject("The original GUI palette type is unavailable.")
	return {"ready":true,"resource":"gui_cg_color_tmp","selector":selector,"name":NAMES[kind],"row":selector&255}
static func prepare(reader,descriptor:Dictionary,cache_path:String="")->Dictionary:
	var selected:=selection(descriptor)
	if not selected.ready:return selected
	var bytes:PackedByteArray=reader.get_resource(selected.resource,6)
	if not reader.failure.is_empty():return reject(reader.failure)
	var decoder:=Palette.new();var header:=decoder.header(bytes)
	if header.is_empty():return reject(decoder.failure)
	if int(header.layer_mask)!=1:return reject("The original GUI swatch template must use only PLT layer zero.")
	var row:PackedByteArray;var source_hash:String=""
	if descriptor.has("palette_row"):
		if not descriptor.palette_row is PackedByteArray or descriptor.palette_row.size()!=1024 or not sha(descriptor.get("palette_source")):return reject("The active GUI palette row/source is unavailable.")
		row=descriptor.palette_row;source_hash=descriptor.palette_source
	else:
		var raw:PackedByteArray=reader.get_resource(selected.name,3)
		if not reader.failure.is_empty():return reject(reader.failure)
		var parser:=Raster.new();var data:=parser.parse(raw,3)
		if not parser.failure.is_empty():return reject(parser.failure)
		if not palette_data(data) or int(selected.row)>=int(data.height):return reject("The original GUI palette row is outside the available palette.")
		row=data.mips[0].data.slice(int(selected.row)*1024,(int(selected.row)+1)*1024);source_hash=Cache.digest(raw)
	var source_sha:=Cache.digest(bytes)
	var identity:=Cache.digest(var_to_bytes(["original-gui-packed-palette-v1",source_sha,int(selected.selector),source_hash,Cache.digest(row)]))
	var cache:=Cache.new();var cached:=not cache_path.is_empty() and cache.configure(cache_path)
	var decoder_name:="gui-packed-palette-v1";var key:=Cache.key(identity,decoder_name)
	if cached:
		var saved:=cache.load_data(key,identity,decoder_name)
		if not saved.is_empty():return {"ready":true,"value":saved,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":true,"palette_source":source_hash,"selector":selected.selector}
	# Map the chosen file/row onto the swatch PLT's literal layer0. Reuse the
	# existing native/GDScript PLT colorizer, including intensity and alpha.
	var palette:Dictionary={"format":"rgba8","width":256,"height":1,"mips":[{"width":256,"height":1,"data":row}]}
	var value:=decoder.decode(bytes,{"pal_skin01":palette},[0])
	if not decoder.failure.is_empty():return reject(decoder.failure)
	if cached:cache.save_data(key,identity,decoder_name,value)
	return {"ready":true,"value":value,"error":"","sha256":identity,"source_sha256":source_sha,"cache_hit":false,"palette_source":source_hash,"selector":selected.selector}
