extends Node
# Original BNXI/BNES/BNDS server-info exchange, owned by Godot UDP.
signal completed(result: Dictionary,error: String)
const GffText=preload("res://systems/native_data/native_gff_text.gd")

var socket: PacketPeerUDP
var resolver_id:=-1
var address: String=""
var host_name: String=""
var requested_host: String=""
var server_port:=0
var deadline:=0
var info: Dictionary={}
var details: Dictionary={}
var server_name: String=""
var name_received:=false
var extended_requested:=false
var timeout_duration:=3500

func query(host: String,port: int,timeout_ms: int=3500,extended: bool=false)->bool:
	close()
	if host.strip_edges().is_empty() or js_length(host)>255 or port<1 or port>65535:completed.emit({},"Invalid server endpoint");return false
	host_name=host.strip_edges();requested_host=host;server_port=port;timeout_duration=timeout_ms;extended_requested=extended
	if host_name.is_valid_ip_address() and not host_name.contains(":"):
		address=host_name
		return open_socket()
	resolver_id=IP.resolve_hostname_queue_item(host_name,IP.TYPE_IPV4)
	if resolver_id<0:finish("Server hostname lookup could not start");return false
	set_process(true)
	return true

func open_socket()->bool:
	socket=PacketPeerUDP.new()
	if socket.bind(0,"0.0.0.0")!=OK:finish("Server information socket could not open");return false
	deadline=Time.get_ticks_msec()+timeout_duration
	send_queries()
	if socket==null:return false
	set_process(true)
	return true
func send_queries()->void:
	if socket==null:return
	if socket.set_dest_address(address,server_port)!=OK:finish("Server information endpoint is unavailable");return
	var local:=socket.get_local_port()
	var tags: Array[String]=["BNXI","BNES"]
	if extended_requested:tags.append("BNDS")
	for tag in tags:
		var bytes: PackedByteArray=tag.to_ascii_buffer();bytes.append(local&255);bytes.append((local>>8)&255)
		if tag=="BNES":bytes.append(0)
		if socket.put_packet(bytes)!=OK:finish("Server information request failed");return

func _process(_delta: float)->void:
	if resolver_id>=0:
		match IP.get_resolve_item_status(resolver_id):
			IP.RESOLVER_STATUS_DONE:
				address=IP.get_resolve_item_address(resolver_id)
				IP.erase_resolve_item(resolver_id);resolver_id=-1
				if address.is_empty():finish("Server hostname could not be resolved");return
				if not open_socket():return
			IP.RESOLVER_STATUS_ERROR:finish("Server hostname could not be resolved");return
	if socket==null:return
	if not socket.is_bound():finish("Server information request failed");return
	for _index in mini(socket.get_available_packet_count(),64):
		var packet: PackedByteArray=socket.get_packet()
		if socket.get_packet_error()!=OK:finish("Server information request failed");return
		if socket.get_packet_ip()!=address or socket.get_packet_port()!=server_port:continue
		var parsed:=decode_packet(packet)
		if parsed.has("error"):continue
		match str(parsed.get("type","")):
			"info":info=parsed
			"details":details=parsed
			"discovery":
				if int(parsed.get("section",-1))==0:server_name=str(parsed.serverName);name_received=true
		if not info.is_empty() and name_received and (not extended_requested or not details.is_empty()):finish("");return
	if Time.get_ticks_msec()>=deadline:finish("" if not info.is_empty() else "Server information request timed out")
func finish(reason: String)->void:
	var result: Dictionary={}
	if reason.is_empty() and not info.is_empty():
		var advertisement_bytes: PackedByteArray=info.get("advertisement",PackedByteArray())
		var decoded: Dictionary=decode_advertisement(advertisement_bytes)
		if decoded.has("error"):reason="Invalid server information advertisement"
		else:
			var fields: Dictionary=info.duplicate(true)
			fields.erase("advertisement")
			result={"host":host_name,"address":address,"port":server_port,"serverName":server_name if name_received else requested_host}
			result.merge(fields,true);result.merge(details,true)
			if not details.is_empty():
				result.description=str(details.get("moduleDescription","")) if not str(details.get("moduleDescription","")).is_empty() else str(details.get("gameDetails",""))
			result.extendedReceived=not details.is_empty()
			result.advertisement=decoded.get("advertisement",null)
	close()
	completed.emit(result,reason)
func close()->void:
	set_process(false)
	if resolver_id>=0:IP.erase_resolve_item(resolver_id);resolver_id=-1
	if socket!=null:socket.close();socket=null
	address="";host_name="";requested_host="";server_port=0;deadline=0;info.clear();details.clear();server_name="";name_received=false;extended_requested=false;timeout_duration=3500

static func js_length(value: String)->int:
	var units:=0
	for byte in value.to_utf8_buffer():
		if (int(byte) & 192)==128:continue
		units+=2 if int(byte)>=240 else 1
	return units

static func decode_packet(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4 or bytes.size()>65535:return {"error":"Invalid server query packet"}
	var tag:=bytes.slice(0,4).get_string_from_ascii()
	if tag=="BNER":
		if bytes.size()<9 or bytes[7]>5 or 9+int(bytes[8])>bytes.size():return {"error":"Invalid native discovery response"}
		return {"type":"discovery","protocolMarker":int(bytes[4]),"port":int(bytes[5]) | (int(bytes[6])<<8),"section":int(bytes[7]),"serverName":decode_text(bytes,9,int(bytes[8]))}
	if tag=="BNXR":
		if bytes.size()<20 or bytes[6]!=0xfd or 20+int(bytes[19])>bytes.size():return {"error":"Invalid native server info"}
		var module:=decode_text(bytes,20,int(bytes[19]))
		return {"type":"info","port":int(bytes[4]) | (int(bytes[5])<<8),"passwordRequired":int(bytes[7]),"minimumLevel":int(bytes[8]),"maximumLevel":int(bytes[9]),"playerCount":int(bytes[10]),"maximumPlayers":int(bytes[11]),"allowLocalVaultCharacters":int(bytes[12]),"pvpSetting":int(bytes[13]),"pauseAndPlay":int(bytes[14]),"onePartyOnly":int(bytes[15]),"enforceLegalCharacters":int(bytes[16]),"itemLevelRestrictions":int(bytes[17]),"reserved":int(bytes[18]),"moduleName":module,"advertisement":bytes.slice(20+int(bytes[19]))}
	if tag=="BNDR":
		if bytes.size()<20:return {"error":"Invalid native server details"}
		var at:=6;var fields: Array[String]=[]
		for _index in 3:
			if at+4>bytes.size():return {"error":"Truncated native server details"}
			var length:=int(bytes.decode_u32(at));at+=4
			if length<0 or at+length>bytes.size():return {"error":"Truncated native server details"}
			fields.append(decode_text(bytes,at,length));at+=length
		if at+2>bytes.size():return {"error":"Truncated native server details"}
		return {"type":"details","port":int(bytes[4]) | (int(bytes[5])<<8),"gameDetails":fields[0],"moduleDescription":fields[1],"serverVersion":fields[2],"gameType":int(bytes.decode_s16(at))}
	return {"error":"Unsupported native server query packet"}
static func decode_text(bytes: PackedByteArray,at: int,length: int)->String:
	if length==0 or bytes[at]==0:return ""
	return GffText.decode(bytes.slice(at,at+length))

static func decode_advertisement(bytes: PackedByteArray)->Dictionary:
	if bytes.is_empty() or bytes[0]!=2 or bytes.size()>=2 and bytes[1]==0:return {}
	if bytes.size()<3:return {"error":"Truncated native server advertisement"}
	var at:=2
	var strings: Array[String]=[]
	for _index in 2:
		if at>=bytes.size():return {"error":"Truncated native server advertisement"}
		var length:=int(bytes[at]);at+=1
		if at+length>bytes.size():return {"error":"Truncated native server advertisement"}
		strings.append(GffText.decode(bytes.slice(at,at+length)));at+=length
	if RegEx.create_from_string("^[0-9a-f]{40}$").search(strings[1].to_lower())==null:return {"error":"Invalid native server manifest hash"}
	if at>=bytes.size():return {"error":"Truncated native server advertisement"}
	var count:=int(bytes[at]);at+=1
	var manifests: Array[Dictionary]=[]
	for _index in count:
		if at+3>bytes.size():return {"error":"Truncated native server advertisement"}
		var flags:=int(bytes[at]);var language:=int(bytes[at+1]);var length:=int(bytes[at+2]);at+=3
		if at+length>bytes.size():return {"error":"Truncated native server advertisement"}
		var hash:=GffText.decode(bytes.slice(at,at+length)).to_lower();at+=length
		if RegEx.create_from_string("^[0-9a-f]{40}$").search(hash)==null:return {"error":"Invalid native server manifest hash"}
		manifests.append({"flags":flags,"language":language,"hash":hash})
	return {"advertisement":{"url":strings[0],"hash":strings[1].to_lower(),"manifests":manifests}}
