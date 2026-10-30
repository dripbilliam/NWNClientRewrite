extends RefCounted
# Concise native menu definitions; no widgets, IO or action handlers.
static func control(kind: String,id: String,properties: Dictionary={},children: Array=[]) -> Dictionary:
	return {"kind":kind,"id":id,"properties":properties,"children":children}
static func label(text: String,wrap: bool=false) -> Dictionary:
	return control("label","",{"text":text,"autowrap_mode":TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF})
static func check(id: String,text: String) -> Dictionary: return control("check",id,{"text":text})
static func button(id: String,text: String,disabled: bool=false) -> Dictionary: return control("button",id,{"text":text,"disabled":disabled})
static func choice(id: String,items: Array,properties: Dictionary={}) -> Dictionary:
	var value:=control("choice",id,properties); value.items=items; return value
