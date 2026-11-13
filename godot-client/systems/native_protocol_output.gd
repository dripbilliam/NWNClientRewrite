extends RefCounted
# Main-thread loopback writes must never wait for the protocol host to read.
# Preserve command order and partial frames; only adjacent unsent observations
# can replace each other. No action, login or finish packet is discarded.
var pending: Array=[]
var head:=0
var offset:=0
var queued_bytes:=0
var maximum_bytes:=64*1024*1024
var failure:=OK
var stats:={"enqueued":0,"sent":0,"bytes_sent":0,"partial_writes":0,"would_block":0,"coalesced":0,"dropped_observations":0,"peak_bytes":0}
func enqueue(bytes: PackedByteArray,key: String="") -> Error:
	if failure!=OK: return failure
	if bytes.is_empty(): return OK
	var last:=pending.size()-1
	var replaceable: bool=key=="observed" and last>=head and pending[last].key==key and (last!=head or offset==0)
	var replaced: int=pending[last].bytes.size() if replaceable else 0
	if queued_bytes-replaced+bytes.size()>maximum_bytes:
		if key=="observed": stats.dropped_observations+=1; return OK
		failure=ERR_OUT_OF_MEMORY; return failure
	if replaceable: pending[last]={"bytes":bytes,"key":key}; stats.coalesced+=1
	else: pending.append({"bytes":bytes,"key":key}); stats.enqueued+=1
	queued_bytes+=bytes.size()-replaced; stats.peak_bytes=maxi(int(stats.peak_bytes),queued_bytes)
	return OK
func flush(writer: Callable,byte_budget: int=262144,time_budget_usec: int=1000) -> Error:
	if failure!=OK: return failure
	var began:=Time.get_ticks_usec(); var written:=0
	while head<pending.size() and written<byte_budget and Time.get_ticks_usec()-began<time_budget_usec:
		var data: PackedByteArray=pending[head].bytes
		var amount:=mini(65536,mini(data.size()-offset,byte_budget-written))
		if amount<=0: break
		var result: Variant=writer.call(data.slice(offset,offset+amount))
		if not result is Array or result.size()!=2: failure=ERR_INVALID_DATA; return failure
		var code:=int(result[0]); var accepted:=int(result[1])
		if code==ERR_BUSY and accepted==0: stats.would_block+=1; break
		if code!=OK: failure=code; return failure
		if accepted<0 or accepted>amount: failure=ERR_INVALID_DATA; return failure
		if accepted==0: stats.would_block+=1; break
		if accepted<amount: stats.partial_writes+=1
		offset+=accepted; written+=accepted; queued_bytes-=accepted; stats.bytes_sent+=accepted
		if offset==data.size(): head+=1; offset=0; stats.sent+=1
	if head==pending.size(): pending.clear(); head=0
	elif head>=64 and head*2>=pending.size(): pending=pending.slice(head); head=0
	return OK
func snapshot() -> Dictionary:
	var result:=stats.duplicate(); result.queued_bytes=queued_bytes; result.queued_messages=pending.size()-head; result.failure=failure; result.nonblocking=true; return result
