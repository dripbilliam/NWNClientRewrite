extends RefCounted
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
static func literal(value: Variant,text)->Dictionary:
	if value is String:return {"ready":true,"text":value}
	if not value is Dictionary:return {"ready":false}
	if value.get("text") is String:return {"ready":true,"text":value.text}
	if value.has("firstName") or value.has("lastName"):
		var first:=literal(value.get("firstName",{"text":""}),text);var last:=literal(value.get("lastName",{"text":""}),text)
		if first.get("ready",false) and last.get("ready",false):return {"ready":true,"text":(str(first.text)+" "+str(last.text)).strip_edges()}
		return {"ready":false}
	if not is_instance_valid(text) or not value.has("strRef"):return {"ready":false}
	var fetched: Dictionary=text.fetch_native_reference(value.strRef,value.get("gender",0))
	return {"ready":true,"text":str(fetched.text)} if fetched.get("found",false) else {"ready":false}
static func capture(row: Dictionary,text)->Dictionary:
	var names: Variant=row.get("replicated",{}).get("name",row.get("appearance",{}).get("name",row.get("item",{}).get("name",row.get("staticState",{}).get("name"))))
	var result:=literal(names,text)
	if not result.get("ready",false):return result
	var encoded:=CaptionState.encoded(str(result.text))
	if not encoded.get("ready",false):return encoded
	return {"ready":true,"rawBytes":encoded.bytes,"rich":Rich.parse(CaptionState.decoded(encoded.bytes)),"ownerId":int(row.id) if int(row.get("objectType",0))==5 else 0x7f000000}
