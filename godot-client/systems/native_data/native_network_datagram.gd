extends RefCounted
signal crypto_turn
const Cipher=preload("res://systems/native_data/native_network_packet_cipher.gd")
var socket:=PacketPeerUDP.new()
var address: String=""
var port:=0
var local_port:=0
var cipher: RefCounted
var closed:=true
var failure_stage: String="validate-options"
var next_crypto_ticket:=0
var serving_crypto_ticket:=0

func acquire_crypto()->int:
	var ticket:=next_crypto_ticket
	next_crypto_ticket+=1
	while ticket!=serving_crypto_ticket and not closed:await crypto_turn
	return -1 if closed else ticket

func release_crypto()->void:
	serving_crypto_ticket+=1
	crypto_turn.emit()

func connect_to_server(host: String,remote_port: int)->bool:
	failure_stage="validate-options"
	if not closed or host.is_empty() or host.length()>255 or remote_port<1 or remote_port>65535:return false
	failure_stage="resolve-address"
	var resolved:=IP.resolve_hostname(host,IP.TYPE_IPV4)
	if resolved.is_empty():return false
	failure_stage="bind-socket"
	if socket.bind(0,"0.0.0.0")!=OK:return false
	if socket.connect_to_host(resolved,remote_port)!=OK:socket.close();return false
	address=resolved;port=remote_port;local_port=socket.get_local_port();closed=false
	return local_port>0

func set_session_crypto(owner: RefCounted,identity: int)->bool:
	if closed or cipher!=null or owner==null or identity<0 or identity>0xffffffff:return false
	cipher=Cipher.new(owner,identity)
	return true

func send(plain: PackedByteArray)->bool:
	if closed or plain.is_empty() or plain.size()>65466:return false
	var result: Dictionary={"bytes":plain}
	if cipher!=null:
		if await acquire_crypto()<0:return false
		result=await cipher.encode(plain)
		release_crypto()
	if closed:return false
	if not result.has("bytes") or result.bytes.size()>65507:return false
	return socket.put_packet(result.bytes)==OK

func receive(max_packets: int=128)->Dictionary:
	if closed:return {"error":"Native datagram is closed"}
	var packets: Array[PackedByteArray]=[]
	for _index in range(clampi(max_packets,1,128)):
		if socket.get_available_packet_count()==0:break
		var wire:=socket.get_packet()
		if socket.get_packet_error()!=OK:return {"error":"Native network socket failed"}
		if socket.get_packet_ip()!=address or socket.get_packet_port()!=port:continue
		if wire.is_empty():continue
		if cipher!=null and wire[0]!=73 and Cipher.requires_encryption(wire):return {"error":"Unencrypted native session packet"}
		var result: Dictionary={"bytes":wire}
		if cipher!=null and wire[0]==73:
			if await acquire_crypto()<0:return {"error":"Native datagram is closed"}
			result=await cipher.decode(wire)
			release_crypto()
		if closed:return {"error":"Native datagram is closed"}
		if not result.has("bytes"):return {"error":result.get("error","Native datagram decryption failed")}
		packets.append(result.bytes)
	return {"packets":packets}

func close()->void:
	if closed:return
	closed=true;crypto_turn.emit();socket.close();cipher=null;address="";port=0;local_port=0
