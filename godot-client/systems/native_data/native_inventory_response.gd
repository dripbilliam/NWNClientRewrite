extends RefCounted
# Original client79f150 reads the server's queued item-action result. G/object
# updates remain the authority for item ownership and equipment state.
const OPERATIONS:={1:"equip",2:"equip",3:"drop",4:"drop",5:"pickup",6:"pickup",7:"unequip",8:"unequip",9:"move",10:"move"}

static func decode_packet(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<12 or bytes[0]!=80 or bytes[1]!=12:return {"error":"Invalid native inventory result envelope"}
	var minor:=int(bytes[2])
	if not OPERATIONS.has(minor) and minor!=14:return {"error":"Unsupported native inventory result"}
	var expected:=16 if minor in [1,2] else 12
	if bytes.size()!=expected or int(bytes.decode_u32(3))!=expected-1:return {"error":"Invalid native inventory result length"}
	var tail:=int(bytes[-1]) & 0xf0
	if tail not in [0x80,0x90]:return {"error":"Invalid native inventory result role"}
	var result:={"kind":"inventory-ack" if minor==14 else "inventory-result","itemId":int(bytes.decode_u32(7)),"alternate":tail==0x90,"operation":"learn" if minor==14 else str(OPERATIONS[minor])}
	if minor!=14:
		result.success=minor%2==1
		if minor in [1,2]:result.slot=int(bytes.decode_u32(11))
	return result
