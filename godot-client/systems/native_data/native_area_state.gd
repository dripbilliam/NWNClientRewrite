extends RefCounted
# Inverse of native PackAreaIntoMessage. Field keys retain original offsets;
# visual meaning is supplied by the existing Godot world renderer.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

static func at_least(build: Dictionary,revision: int,postfix: int=0)->bool:
	var number:=int(build.get("number",0))
	var current:=int(build.get("revision",0))
	var current_postfix:=int(build.get("postfix",0))
	return number>8193 or number==8193 and (current>revision or current==revision and current_postfix>=postfix)

static func vector(reader: Requirements.Reader)->Array[float]:
	return [reader.float32(),reader.float32(),reader.float32()]

static func fields(reader: Requirements.Reader,offsets: Array,method: String,target: Dictionary)->void:
	for offset in offsets:target["%x" % int(offset)]=reader.call(method)

static func bounded_count(reader: Requirements.Reader,count: int,minimum: int)->bool:
	return count>=0 and count<=int((reader.byte_size-reader.byte_cursor)/minimum)

static func sound_state(reader: Requirements.Reader)->Dictionary:
	var sound: Dictionary={"id":reader.dword(),"fields":{}}
	var value: Dictionary=sound.fields
	fields(reader,[0x308,0x30c,0x310],"boolean",value)
	fields(reader,[0x314,0x318,0x31c],"byte",value)
	fields(reader,[0x320],"float32",value)
	fields(reader,[0x324],"dword",value)
	fields(reader,[0x328],"byte",value)
	fields(reader,[0x348,0x34c],"dword",value)
	fields(reader,[0x350,0x354],"float32",value)
	fields(reader,[0x358,0x35c,0x32c],"boolean",value)
	fields(reader,[0x330,0x334],"float32",value)
	sound.position=vector(reader)
	var count:=reader.word()
	if not bounded_count(reader,count,16):return {"error":"Invalid native sound references"}
	var refs: Array[String]=[]
	for _index in range(count):refs.append(reader.resref())
	sound.refs=refs
	return sound

static func decode_packet(packet: PackedByteArray,build: Dictionary)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=4 or packet[2]!=1:return {"error":"Not a native client-area message"}
	if not build.has("number") or not build.has("revision") or not build.has("postfix"):return {"error":"Server build is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var loading_screen:=reader.signed_dword()
	var position:=vector(reader)
	var facing:=reader.float32()
	var flag:=reader.boolean()
	var area: Dictionary={"id":reader.dword(),"resRef":reader.resref()}
	area.name={"text":reader.string()} if reader.boolean() else Characters.localized(reader)
	area.moduleEntry=[reader.signed_dword(),reader.signed_dword(),reader.signed_dword()]
	var f: Dictionary={}
	area.fields=f
	fields(reader,[8,0x98,0x9c],"dword",f)
	if at_least(build,35):fields(reader,[0xac,0xb0,0xb4],"float32",f)
	fields(reader,[0xa0],"dword",f)
	fields(reader,[0xa4],"byte",f)
	fields(reader,[0xa8],"boolean",f)
	fields(reader,[0xb8,0xbc],"dword",f)
	if at_least(build,35):fields(reader,[0xcc,0xd0,0xd4],"float32",f)
	fields(reader,[0xc0],"dword",f)
	fields(reader,[0xc4],"byte",f)
	fields(reader,[0xc8,0xd8,0xdc],"boolean",f)
	area.pvp=reader.byte()
	fields(reader,[0x100],"boolean",f)
	fields(reader,[0x104],"byte",f)
	fields(reader,[0x108],"float32",f)
	fields(reader,[0x34c],"signed_dword",f)
	var ambient: Dictionary={}
	fields(reader,[8,0x18,0x20],"boolean",ambient)
	fields(reader,[0xc,0x10,0x14,0x1c,0x24,0x28],"signed_dword",ambient)
	fields(reader,[0x2c,0x2d],"byte",ambient)
	area.ambient=ambient
	area.time={"timeOfDay":reader.byte(),"transition":reader.dword(),"hour":reader.byte(),"day":reader.byte(),"month":reader.byte(),"year":reader.dword(),"dawn":reader.byte(),"dusk":reader.byte()}
	fields(reader,[0xe0,0xe3,0xe4],"byte",f)
	if at_least(build,14) and int(f.get("e4",0))==3:fields(reader,[0xe8,0xec,0xf0,0xf4,0xf8,0xfc],"float32",f)
	area.weather={"type":reader.byte(),"enabled":reader.boolean()}
	area.width=reader.signed_dword();area.height=reader.signed_dword();area.tileset=reader.resref()
	var grass: Array[Dictionary]=[]
	if at_least(build,36,3):
		fields(reader,[0x368],"boolean",f)
		var grass_count:=reader.signed_dword()
		if not bounded_count(reader,grass_count,37):return {"error":"Invalid native area grass count"}
		for _index in range(grass_count):
			var entry: Dictionary={"field10":reader.byte(),"name":reader.string(),"fields":{}}
			fields(reader,[0x28,0x2c,0x30,0x34,0x38,0x3c,0x40,0x44],"float32",entry.fields)
			grass.append(entry)
	area.grass=grass
	if at_least(build,36,5):fields(reader,[0x10c],"boolean",f)
	if int(area.width)<0 or int(area.height)<0 or int(area.width)>100000 or int(area.height)>100000:return {"error":"Invalid native area dimensions"}
	var tile_count:=int(area.width)*int(area.height)
	if not bounded_count(reader,tile_count,16):return {"error":"Invalid native area tile count"}
	var tiles: Array[Dictionary]=[]
	for _index in range(tile_count):
		var tile: Dictionary={"fields":{}}
		fields(reader,[0x14,0x24,0x18],"signed_dword",tile.fields)
		var mask:=reader.word();tile.lightMask=mask
		for bit in range(8):tile.fields["%x" % (0x28+bit)]=reader.byte() if mask & (1 << bit) else 0
		tiles.append(tile)
	area.tiles=tiles
	var map_count:=reader.signed_dword()
	if not bounded_count(reader,map_count,20):return {"error":"Invalid native map-pin count"}
	var map_pins: Array[Dictionary]=[]
	for _index in range(map_count):map_pins.append({"id":reader.dword(),"position":vector(reader),"enabled":reader.boolean(),"name":Characters.localized(reader)})
	area.mapPins=map_pins
	var player_count:=reader.signed_dword()
	if not bounded_count(reader,player_count,20):return {"error":"Invalid native player map-pin count"}
	var player_pins: Array[Dictionary]=[]
	for _index in range(player_count):player_pins.append({"index":reader.dword(),"text":reader.string(),"position":vector(reader)})
	area.playerMapPins=player_pins
	var sound_count:=reader.word()
	if not bounded_count(reader,sound_count,53):return {"error":"Invalid native sound count"}
	var sounds: Array[Dictionary]=[]
	for _index in range(sound_count):
		var sound:=sound_state(reader)
		if sound.has("error"):return sound
		sounds.append(sound)
	area.sounds=sounds
	var light_count:=reader.word()
	if not bounded_count(reader,light_count,18):return {"error":"Invalid native placeable-light count"}
	var lights: Array[Dictionary]=[]
	for _index in range(light_count):lights.append({"id":reader.dword(),"appearance":reader.word(),"position":vector(reader)})
	area.placeableLights=lights
	var placeable_count:=reader.word()
	if not bounded_count(reader,placeable_count,30):return {"error":"Invalid native static-placeable count"}
	var placeables: Array[Dictionary]=[]
	for _index in range(placeable_count):placeables.append({"id":reader.dword(),"appearance":reader.word(),"position":vector(reader),"orientation":vector(reader)})
	area.staticPlaceables=placeables
	var reserved: Array[int]=[reader.word(),reader.word()]
	if reserved[0]!=0 or reserved[1]!=0:return {"error":"Unsupported native area trailing records"}
	area.reservedCounts=reserved
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Native area message is incomplete"}
	return {"loadingScreen":loading_screen,"position":position,"facing":facing,"flag":flag,"area":area}
