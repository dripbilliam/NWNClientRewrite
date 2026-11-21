extends RefCounted
# src/network_automap.js::applyNetworkAutomap. This consumes only server
# automap changes; it never infers visibility or explores adjacent tiles.
static func apply_network_automap(previous: Variant,change: Dictionary,width: Variant,height: Variant) -> Dictionary:
	var product:=float(width)*float(height)
	if product!=product or product<0.0 or product>65536.0 or product!=floorf(product):return {"error":"Invalid native automap dimensions"}
	var size:=int(product)
	var states: Array=[]
	states.resize(size)
	if (previous is Array or previous is PackedByteArray) and previous.size()==size:
		for index in size:states[index]=int(previous[index])&255
	else:
		states.fill(0)
	var mode: Array=change.get("mode",[])
	if mode.size()<2:return {"error":"Invalid native automap mode"}
	if bool(mode[1]):
		var bytes: Array=change.get("bytes",[])
		for index in mini(size,bytes.size()*8):states[index]=(int(bytes[index>>3])>>(index&7))&1
	else:
		var points: Array=change.get("points",[])
		if bool(mode[0]):states.fill(1 if points.is_empty() else 0)
		for point in points:
			var x:=int(point.get("x",0));var y:=int(point.get("y",0))
			if x<0 or y<0 or float(x)>=float(width) or float(y)>=float(height):return {"error":"Native automap point exceeds area"}
			states[y*int(width)+x]=1 if bool(mode[0]) else int(point.get("state",0))&255
	return {"value":states}
