extends RefCounted
# An ordered, native-only barrier while private snapshot metadata is prepared.
# Wire sizes are supplied beside parsed messages by BridgeFrames, never from
# message fields. No message is dropped or coalesced to meet a frame budget.
const MAX_MESSAGES:=1024
const MAX_BYTES:=16*1024*1024
const COMPACT_HEAD:=512
var entries: Array=[]
var head:=0
var bytes:=0
var peak_messages:=0
var peak_bytes:=0
func size() -> int:return entries.size()-head
func push(message: Dictionary,wire_bytes: int) -> bool:
	if wire_bytes<=0 or size()>=MAX_MESSAGES or wire_bytes>MAX_BYTES-bytes:return false
	entries.append({"message":message,"bytes":wire_bytes});bytes+=wire_bytes
	peak_messages=maxi(peak_messages,size());peak_bytes=maxi(peak_bytes,bytes)
	return true
func pop() -> Dictionary:
	if head>=entries.size():return {}
	var entry: Dictionary=entries[head];entries[head]=null;head+=1;bytes-=int(entry.bytes)
	if head==entries.size():entries=[];head=0
	elif head>=COMPACT_HEAD:entries=entries.slice(head);head=0
	return entry
func detach() -> Array:
	# Transfer last decoded-data references for deferred worker release on reset.
	var value: Array=entries
	entries=[];head=0;bytes=0
	return value
func snapshot() -> Dictionary:
	return {"messages":size(),"bytes":bytes,"storage_entries":entries.size(),"peak_messages":peak_messages,"peak_bytes":peak_bytes,"maximum_messages":MAX_MESSAGES,"maximum_bytes":MAX_BYTES}
