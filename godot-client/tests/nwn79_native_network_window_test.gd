extends SceneTree
const Frames=preload("res://systems/native_data/native_network_frames.gd")
const NativeWindow=preload("res://systems/native_data/native_network_window.gd")
func _initialize()->void:
	var sender=NativeWindow.new(0);var receiver=NativeWindow.new(0)
	var payload:=PackedByteArray();payload.resize(13);payload[7]=10;payload[12]=42
	var first: Dictionary=sender.enqueue(payload,10)
	var second: Dictionary=sender.enqueue(payload,11)
	if first.has("error") or second.has("error") or first.send.size()!=1 or second.send.size()!=1:fail("enqueue");return
	var corrupt: PackedByteArray=first.send[0].duplicate();corrupt[12]=43
	if receiver.receive(corrupt,12).accepted:fail("checksum");return
	var delayed: Dictionary=receiver.receive(second.send[0],13)
	if not delayed.accepted or not delayed.delivered.is_empty() or delayed.send.size()!=1 or Frames.read(delayed.send[0]).kind!=2:fail("out of order NAK");return
	var recovered: Dictionary=receiver.receive(first.send[0],14)
	if recovered.delivered.size()!=2 or receiver.expected!=2:fail("ordered delivery");return
	var ack: Array[PackedByteArray]=receiver.poll(2020)
	if ack.size()!=1 or Frames.read(ack[0]).kind!=1:fail("ACK timer");return
	var accepted: Dictionary=sender.receive(ack[0],2021)
	if accepted.acknowledged!=[0,1] or not sender.outgoing.is_empty():fail("acknowledgement");return
	print("NWN79 Godot reliable UDP window PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 reliable UDP window failed: "+stage)
	quit(1)
