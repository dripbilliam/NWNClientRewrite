extends Node
# Original BNXI/BNES/BNDS server-info exchange, owned by Godot UDP.
signal completed(result: Dictionary,error: String)
const GffText=preload("res://systems/native_data/native_gff_text.gd")
const BrowserStore=preload("res://systems/native_data/godot_server_browser_store.gd")
var socket: PacketPeerUDP
var resolver_id:=-1
var address: String=""
var host_name: String=""
var server_port:=0
var deadline:=0
var info: Dictionary={}
var details: Dictionary={}
var server_name: String=""
var name_received:=false

func query(host: String,port: int,timeout_ms: int=3500)->bool:
	close()
	var endpoint:=BrowserStore.new().normalized_endpoint({"host":host,"port":port})
	if endpoint.is_empty():completed.emit({},"Invalid server endpoint");return false
	host_name=str(endpoint.host);server_port=int(endpoint.port);deadline=Time.get_ticks_msec()+clampi(timeout_ms,100,10000)
	socket=PacketPeerUDP.new()
	if socket.bind(0,"0.0.0.0")!=OK:finish("Server information socket could not open");return false
	if host_name.is_valid_ip_address():address=host_name;send_queries()
	else:
		resolver_id=IP.resolve_hostname_queue_item(host_name,IP.TYPE_IPV4)
		if resolver_id<0:finish("Server hostname lookup could not start");return false
	set_process(true)
	return true

func send_queries()->void:
	if socket==null:return
	if socket.set_dest_address(address,server_port)!=OK:finish("Server information endpoint is unavailable");return
	var local:=socket.get_local_port()
	for tag in ["BNXI","BNES","BNDS"]:
		var bytes: PackedByteArray=tag.to_ascii_buffer();bytes.append(local&255);bytes.append((local>>8)&255)
		if tag=="BNES":bytes.append(0)
		if socket.put_packet(bytes)!=OK:finish("Server information request failed");return

func _process(_delta: float)->void:
	if socket==null:return
	if resolver_id>=0:
		match IP.get_resolve_item_status(resolver_id):
			IP.RESOLVER_STATUS_DONE:
				address=IP.get_resolve_item_address(resolver_id)
				IP.erase_resolve_item(resolver_id);resolver_id=-1
				if address.is_empty():finish("Server hostname could not be resolved");return
				send_queries()
			IP.RESOLVER_STATUS_ERROR:finish("Server hostname could not be resolved");return
	if socket==null:return
	for _index in mini(socket.get_available_packet_count(),64):
		var packet: PackedByteArray=socket.get_packet()
		if socket.get_packet_ip()!=address or socket.get_packet_port()!=server_port:continue
		var parsed:=decode_packet(packet)
		if parsed.has("error"):continue
		match str(parsed.get("type","")):
			"info":info=parsed
			"details":details=parsed
			"discovery":
				if int(parsed.get("section",-1))==0:server_name=str(parsed.serverName);name_received=true
		if not info.is_empty() and name_received and not details.is_empty():finish("");return
	if Time.get_ticks_msec()>=deadline:finish("" if not info.is_empty() else "Server information request timed out")

func finish(reason: String)->void:
	var result: Dictionary={}
	if reason.is_empty() and not info.is_empty():
		result={"host":host_name,"address":address,"port":server_port,"serverName":server_name if name_received else host_name}
		result.merge(info,true);result.merge(details,true)
		result.erase("type");result.erase("section")
		result.description=str(details.get("moduleDescription",details.get("gameDetails","")))
		result.extendedReceived=not details.is_empty()
	close()
	completed.emit(result,reason)

func close()->void:
	set_process(false)
	if resolver_id>=0:IP.erase_resolve_item(resolver_id);resolver_id=-1
	if socket!=null:socket.close();socket=null
	address="";host_name="";server_port=0;deadline=0;info.clear();details.clear();server_name="";name_received=false

static func decode_packet(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4 or bytes.size()>65535:return {"error":"Invalid server query packet"}
	var tag:=bytes.slice(0,4).get_string_from_ascii()
	if tag=="BNER":
		if bytes.size()<9 or bytes[7]>5 or 9+int(bytes[8])>bytes.size():return {"error":"Invalid native discovery response"}
		return {"type":"discovery","section":int(bytes[7]),"serverName":decode_text(bytes,9,int(bytes[8]))}
	if tag=="BNXR":
		if bytes.size()<20 or bytes[6]!=0xfd or 20+int(bytes[19])>bytes.size():return {"error":"Invalid native server info"}
		var module:=decode_text(bytes,20,int(bytes[19]))
		var advertisement:=decode_advertisement(bytes.slice(20+int(bytes[19])))
		if advertisement.has("error"):return advertisement
		return {"type":"info","passwordRequired":bytes[7]!=0,"minimumLevel":int(bytes[8]),"maximumLevel":int(bytes[9]),"playerCount":int(bytes[10]),"maximumPlayers":int(bytes[11]),"allowLocalVaultCharacters":bytes[12]!=0,"pvpSetting":int(bytes[13]),"pauseAndPlay":bytes[14]!=0,"onePartyOnly":bytes[15]!=0,"enforceLegalCharacters":bytes[16]!=0,"itemLevelRestrictions":bytes[17]!=0,"moduleName":module,"advertisement":advertisement.get("advertisement"),"sync":advertisement.has("advertisement")}
	if tag=="BNDR":
		if bytes.size()<20:return {"error":"Invalid native server details"}
		var at:=6;var fields: Array[String]=[]
		for _index in 3:
			if at+4>bytes.size():return {"error":"Truncated native server details"}
			var length:=int(bytes.decode_u32(at));at+=4
			if length<0 or at+length>bytes.size():return {"error":"Truncated native server details"}
			fields.append(decode_text(bytes,at,length));at+=length
		if at+2>bytes.size():return {"error":"Truncated native server details"}
		return {"type":"details","gameDetails":fields[0],"moduleDescription":fields[1],"serverVersion":fields[2],"gameType":int(bytes.decode_s16(at))}
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
