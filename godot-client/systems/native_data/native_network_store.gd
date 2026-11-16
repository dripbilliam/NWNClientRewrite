extends RefCounted
# Original server 7/3,4,6 and client 7/1,2,4,5,6,7. Store identity is
# server-owned; OpenStoreInventory carries no merchant object ID.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const INVALID:=0x7f000000
const SERVER_MINORS=[3,4,6]

static func accepted(major: int,minor: int)->bool:return major==7 and minor in SERVER_MINORS

static func decode_packet(packet: PackedByteArray,format_mode: int=1)->Dictionary:
	if packet.size()<3 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):return {"error":"Invalid native store envelope"}
	var minor:=int(packet[2])
	if minor==6:return {"kind":"store-close","major":7,"minor":6} if packet.size()==3 else {"error":"Invalid native store close"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3),format_mode):return {"error":"Invalid native store streams: "+reader.error}
	var message: Dictionary={"major":7,"minor":minor}
	if minor==3:
		message.kind="store-transaction";message.itemId=reader.object_id();message.gold=reader.signed_dword()
	else:
		message.kind="store-open"
		message.panel=reader.byte();message.sellRate=reader.short();message.buyRate=reader.byte();message.blackMarketRate=reader.byte()
		message.identifyPrice=reader.signed_dword();message.maxBuyPrice=reader.signed_dword();message.gold=reader.signed_dword()
		message.blackMarket=int(reader.boolean());message.restricted=int(reader.boolean())
		var count: int=reader.signed_dword()
		if count<0 or count>(reader.byte_size-reader.byte_cursor)/4:return {"error":"Invalid native store restriction count"}
		var base_items: Array=[]
		for _index in count:base_items.append(reader.signed_dword())
		message.baseItems=base_items
	if not reader.finished():return {"error":"Invalid native store fields: "+reader.error}
	return message

static func valid_uint(value: Variant,maximum: int)->bool:return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=0 and value<=maximum

static func request(operation: String,item_id: int=-1,x: int=255,y: int=255,destination_id: int=INVALID,panel: int=-1,page: int=-1)->Dictionary:
	if operation=="close":return {"bytes":PackedByteArray([112,7,6])}
	var minor: int={"buy":1,"sell":2,"panel":4,"page":5,"identify":7}.get(operation,-1)
	if minor<0:return {"error":"Invalid native store operation"}
	var bytes:=PackedByteArray([112,7,minor,0,0,0,0])
	if operation in ["panel","page"]:
		var value:=panel if operation=="panel" else page
		if not valid_uint(value,255):return {"error":"Invalid native store panel or page"}
		bytes.append(value)
	else:
		if not valid_uint(item_id,0xffffffff):return {"error":"Invalid native store item"}
		var at:=bytes.size();bytes.resize(at+4);bytes.encode_u32(at,item_id)
		if operation=="buy":
			if not valid_uint(x,255) or not valid_uint(y,255) or not valid_uint(destination_id,0xffffffff):return {"error":"Invalid native store destination"}
			bytes.append(x);bytes.append(y);at=bytes.size();bytes.resize(at+4);bytes.encode_u32(at,destination_id)
	bytes.append(0x60);bytes.encode_u32(3,bytes.size()-1)
	return {"bytes":bytes}
