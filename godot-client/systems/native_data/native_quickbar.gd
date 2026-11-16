extends RefCounted
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Items=preload("res://systems/native_data/native_object_updates.gd")
const NO_PARAMS=[0,6,7,19,20,21,22,23,24,25,35,36,38,40,41]
const INTS=[3,4,8,10,27,28,31,32,33,34,37,42,43,45,46,47,48]
const INVALID:=0x7f000000

static func decode_packet(packet: PackedByteArray,build: Dictionary,providers: Dictionary)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=30 or int(packet[2]) not in [1,2]:return {"error":"Not a native quickbar packet"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var full:=int(packet[2])==1
	var start:=0 if full else reader.byte()
	if start>=36:return {"error":"Native quickbar index exceeds 35"}
	var count:=36 if full else 1
	var entries: Array[Dictionary]=[]
	for offset in range(count):
		var kind:=reader.byte()
		var button: Dictionary={"type":kind}
		var items: Array[Dictionary]=[]
		if kind==1:
			button.itemId=INVALID;button.secondaryItemId=INVALID;button.intParam=0xff0000
			if reader.boolean():
				button.itemId=reader.object_id();button.intParam=reader.signed_dword()
				var item: Dictionary=Items.active_item(reader,build,providers)
				if item.has("error"):return item
				items.append({"id":button.itemId,"item":item})
			if reader.boolean():
				button.secondaryItemId=reader.object_id()
				var item: Dictionary=Items.active_item(reader,build,providers)
				if item.has("error"):return item
				items.append({"id":button.secondaryItemId,"item":item})
		elif kind==2:
			button.classIndex=reader.byte();button.intParam=reader.dword();button.metamagic=reader.byte();button.domainLevel=reader.byte()
		elif kind in INTS:button.intParam=reader.signed_dword()
		elif kind>=11 and kind<=17:button.resRef=reader.resref();button.toolTip=reader.string()
		elif kind==18:button.commandLabel=reader.string();button.commandLine=reader.string()
		elif kind in [29,30]:button.resRef=reader.resref()
		elif kind==39:button.intParam=reader.signed_dword();button.associateType=reader.word();button.associateId=reader.object_id()
		elif kind==44:button.intParam=reader.dword();button.domainLevel=reader.byte()
		elif kind not in NO_PARAMS:return {"error":"Unsupported native quickbar button type " + str(kind)}
		if not reader.error.is_empty():return {"error":reader.error}
		entries.append({"index":start+offset,"button":button,"items":items})
	if not reader.finished():return {"error":"Native quickbar packet has trailing fields"}
	return {"full":full,"entries":entries}
