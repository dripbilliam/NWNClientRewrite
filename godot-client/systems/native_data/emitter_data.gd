extends RefCounted
# Original serialized MDL emitter fields and semantic controller channels.
# The established offline parser/oracles retain the binary relocation evidence.
# This is resource data only, not a particle simulation or rendering adapter.
const FLAGS={"p2p":1,"p2p_sel":2,"affectedbywind":4,"tinted":8,"bounce":16,"random":32,"inherit":64,"inheritvel":128,"inherit_local":256,"splat":512,"inherit_part":1024}
const FIELDS={0xe8:"blurlength",0x108:"detonate",0xdc:"velocity",0xc0:"randvel",0x74:"birthrate",0x88:"colorstart",0x218:"colormid",0x7c:"colorend",0x224:"percentstart",0x225:"percentmid",0x226:"percentend",0x70:"alphastart",0x214:"alphamid",0x6c:"alphaend",0xc4:"sizestart",0x228:"sizemid",0xc8:"sizeend",0xcc:"sizestart_y",0x22c:"sizemid_y",0xd0:"sizeend_y",0xa4:"framestart",0xa0:"frameend",0xac:"lifeexp",0xb0:"mass",0xd4:"spread",0xbc:"particlerot",0xf4:"lightningscale",0x9c:"fps",0xe0:"xsize",0xe4:"ysize",0x78:"bounce_co",0xec:"lightningdelay",0xf0:"lightningradius",0xb4:"p2p_bezier2",0xb8:"p2p_bezier3",0x94:"combinetime",0x98:"drag",0xa8:"grav",0xd8:"threshold"}
const STRINGS=["update","render","blend","texture","chunkname"]
const SCALARS=["deadspace","blastradius","blastlength","xgrid","ygrid","spawntype","renderorder"]
var failure:=""
static func runtime_controller(value: int) -> int:
	for pair in [[436,84],[392,64],[356,56],[328,48],[276,44],[228,36],[76,28],[72,24],[8,8]]:
		if value>=int(pair[0]): return value+int(pair[1])
	return value
static func components(property: String) -> int:
	return (3 if property.begins_with("color") else 1) if FIELDS.values().has(property) else 0
static func channel(value: int) -> Dictionary:
	var name:=str(FIELDS.get(runtime_controller(value),""))
	return {} if name.is_empty() else {"property":name,"components":components(name)}
static func flag(value: Variant) -> bool:
	if value is bool: return value
	if value is String:
		if value=="true": return true
		if not value.is_valid_float(): return false
		return is_finite(value.to_float()) and value.to_float()!=0
	return (value is float or value is int) and is_finite(float(value)) and float(value)!=0
static func resolve_flags(properties: Dictionary) -> int:
	var value:=int(properties.get("flags",0))&0xffffffff
	for name in FLAGS:
		if properties.has(name):
			if flag(properties[name]): value|=int(FLAGS[name])
			else: value&=~int(FLAGS[name])
	return value
static func normalize_flags(properties: Dictionary) -> void:
	properties.flags=resolve_flags(properties)
	for name in FLAGS: properties[name]=int((int(properties.flags)&int(FLAGS[name]))!=0)
func ascii_properties(properties: Dictionary) -> Dictionary:
	failure=""; var result: Dictionary={}
	for name in STRINGS:
		if properties.has(name): result[name]=str(properties[name])
	var names: Array=SCALARS.duplicate()
	names.append_array(FIELDS.values())
	for name in names:
		if not properties.has(name): continue
		var source: Variant=properties[name]; var values: Array=[]
		if source is Array: values=source
		elif source is String:
			for token in source.split(" ",false):
				if token.to_lower().begins_with("0x") and token.is_valid_hex_number(true): values.append(float(token.hex_to_int()))
				elif token.is_valid_float(): values.append(token.to_float())
				else: failure="Invalid original emitter number: "+str(name); return {}
		elif source is float or source is int: values=[source]
		else: failure="Invalid original emitter property: "+str(name); return {}
		var count:=3 if str(name).begins_with("color") else 1
		if values.size()!=count or not values.all(func(value):return (value is float or value is int) and is_finite(float(value))): failure="Invalid original emitter value shape: "+str(name); return {}
		result[name]=values if count==3 else values[0]
	for name in FLAGS:
		if properties.has(name): result[name]=properties[name]
	if properties.has("flags"):
		var source_flags:=str(properties.flags)
		result.flags=source_flags.hex_to_int() if source_flags.to_lower().begins_with("0x") and source_flags.is_valid_hex_number(true) else int(source_flags)
	normalize_flags(result)
	for name in ["loop","twosidedtex"]:
		if properties.has(name): result[name]=int(flag(properties[name]))
	return result
func binary_header(reader, at: int) -> Dictionary:
	failure=""
	if not reader.contains(at,216,"Original emitter header"): failure=reader.failure; return {}
	var properties: Dictionary={}
	for index in 3:
		var value: float=reader.f32(at+index*4)
		if not is_finite(value): failure="Non-finite original emitter header"; return {}
		properties[["deadspace","blastradius","blastlength"][index]]=value
	for index in 3: properties[["xgrid","ygrid","spawntype"][index]]=reader.u32(at+12+index*4)
	for row in [[24,32,"update"],[56,32,"render"],[88,32,"blend"],[120,64,"texture"],[184,16,"chunkname"]]: properties[row[2]]=reader.text(at+int(row[0]),int(row[1]),true)
	properties.twosidedtex=reader.u32(at+200); properties.loop=reader.u32(at+204); properties.renderorder=reader.u16(at+208); properties.flags=reader.u32(at+212)
	normalize_flags(properties)
	return properties
