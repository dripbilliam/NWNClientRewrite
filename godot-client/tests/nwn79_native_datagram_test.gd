extends SceneTree
const Datagram=preload("res://systems/native_data/native_network_datagram.gd")
func _initialize()->void:
	var server:=PacketPeerUDP.new()
	if server.bind(0,"127.0.0.1")!=OK:fail("fixture bind");return
	var peer=Datagram.new()
	if not peer.connect_to_server("127.0.0.1",server.get_local_port()) or peer.local_port<=0:fail("connect");return
	var request:=PackedByteArray([66,78,75,48,1,2,3])
	if not peer.send(request):fail("send");return
	var received:=PackedByteArray()
	var deadline:=Time.get_ticks_msec()+500
	while Time.get_ticks_msec()<deadline and received.is_empty():
		if server.get_available_packet_count()>0:received=server.get_packet()
		else:OS.delay_usec(1000)
	if received!=request:fail("wire bytes");return
	server.set_dest_address("127.0.0.1",peer.local_port)
	if server.put_packet(request)!=OK:fail("reply send");return
	var reply: Dictionary={"packets":[]}
	while Time.get_ticks_msec()<deadline and reply.packets.is_empty():
		reply=peer.receive()
		if reply.has("error"):break
		if reply.packets.is_empty():OS.delay_usec(1000)
	if reply.has("error") or reply.packets.size()!=1 or reply.packets[0]!=request:fail("reply receive");return
	peer.close();server.close()
	print("NWN79 Godot UDP datagram PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot UDP datagram failed: "+stage)
	quit(1)
