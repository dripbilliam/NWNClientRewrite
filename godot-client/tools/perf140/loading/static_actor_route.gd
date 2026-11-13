extends RefCounted
# Binary header/topology hint only. Actual parsing, mesh checks, ancestry and
# resources remain with their existing owners. No decoded data or cache tier.
static func enabled() -> bool: return OS.get_cmdline_user_args().has("--static-emitter-route=enabled")
static func binary_hint(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<108 or bytes.decode_u32(0)!=0: return {"known":false,"reason":"Not a complete binary MDL header"}
	var model_size:=int(bytes.decode_u32(4)); var raw_size:=int(bytes.decode_u32(8)); var declared:=int(bytes.decode_u32(88))
	if model_size>bytes.size()-12 or raw_size>bytes.size()-12-model_size or declared<1 or declared>100000: return {"known":false,"reason":"Invalid binary MDL section/count bounds"}
	var pending: Array=[{"offset":int(bytes.decode_u32(84)),"depth":0}]; var seen: Dictionary={}; var emitter:=false
	while not pending.is_empty():
		var item: Dictionary=pending.pop_back(); var offset:=int(item.offset); var depth:=int(item.depth)
		if depth>128 or seen.has(offset) or seen.size()>=declared or offset<0 or offset>model_size or 112>model_size-offset: return {"known":false,"reason":"Invalid binary MDL node topology"}
		seen[offset]=true; var at:=12+offset; var flags:=int(bytes.decode_u32(at+108))
		if flags & ~0x3f7: return {"known":false,"reason":"Unknown original node flags"}
		if flags & 4: emitter=true
		var children:=int(bytes.decode_u32(at+76)); var table:=int(bytes.decode_u32(at+72))
		if children>declared or table>model_size or children*4>model_size-table: return {"known":false,"reason":"Invalid binary MDL child table"}
		for index in children: pending.append({"offset":int(bytes.decode_u32(12+table+index*4)),"depth":depth+1})
	return {"known":true,"emitter":emitter,"nodes":seen.size()}
