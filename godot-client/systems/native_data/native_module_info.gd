extends RefCounted
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

static func at_least(build: Dictionary,revision: int)->bool:
	var number:=int(build.get("number",0))
	var current:=int(build.get("revision",0))
	return number>8193 or number==8193 and current>=revision

static func decode_packet(packet: PackedByteArray,build: Dictionary)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=3 or packet[2]!=1:return {"error":"Not a native module-information message"}
	if not build.has("number") or not build.has("revision") or not build.has("postfix"):return {"error":"Server build is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var resource_name:=reader.string()
	var name: Dictionary=Characters.localized(reader)
	var minutes_per_hour:=reader.byte()
	var entry_area:=reader.resref()
	var count:=reader.dword()
	if count>(reader.byte_size-reader.byte_cursor)/8:return {"error":"Invalid native module area count"}
	var areas: Array[Dictionary]=[]
	for _index in range(count):areas.append({"id":reader.dword(),"name":reader.string()})
	var official:=reader.byte()
	var flags: Dictionary={"field158":reader.boolean(),"field164":reader.boolean()}
	if at_least(build,34):flags.field168=reader.boolean()
	if at_least(build,35):flags.field16c=reader.boolean()
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Native module information is incomplete"}
	return {"resourceName":resource_name,"name":name,"minutesPerHour":minutes_per_hour,"entryArea":entry_area,"areas":areas,"officialCampaign":official,"serverFlags":flags}
