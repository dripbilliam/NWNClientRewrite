extends RefCounted
# Original9cda40 /7f3f00 /7f1230 text only. The caller must provide the
# private clone's exact resolved strings and the actual first caption line.
# This does not resolve live names, approximate a wrapped line, or paint text.
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func name(parts: Variant) -> Dictionary:
	if not parts is Dictionary:return pending("Private level-up name context is unavailable.")
	for key in ["first","last","override"]:
		if not parts.get(key) is String or String.chr(0) in parts[key]:return pending("Private level-up name strings are unavailable or outside the verified C-string domain.")
	var value: String=parts.override
	if value.is_empty():value=parts.first+(" " if not parts.first.is_empty() and not parts.last.is_empty() else "")+parts.last
	return {"ready":true,"text":value}
static func classes(values: Variant,tables: Dictionary,text) -> Dictionary:
	if not values is Array or values.is_empty() or values.size()>8 or not tables.has("classes") or text==null or not text.has_method("raw"):return pending("Private class title context is unavailable.")
	var output: Array=[];var count: int=tables.classes.get("orderedRows",[]).size()&255
	for value in values:
		if not value is Dictionary or not Class.integer(value.get("id"),0,254) or int(value.id)>=count or not Class.integer(value.get("level"),1,255):return pending("Private class title identity/level is malformed.")
		var ref:=Tables.integer(tables.classes,int(value.id),"Name")
		if not ref.ready or not ref.ok:return pending("Active class title name is unavailable.")
		#837f60 copies id/level, not class297's colored-level flag;7ea700
		# leaves that flag zero in every private class record.
		output.append(text.raw({"strRef":int(ref.value)&0xffffffff})+" ("+str(int(value.level))+")")
	return {"ready":true,"text":" ".join(output)}
static func compose(parts: Variant,private_classes: Variant,first_caption_line: Variant,tables: Dictionary,text) -> Dictionary:
	if not first_caption_line is String or "\n" in first_caption_line or "\r" in first_caption_line or String.chr(0) in first_caption_line:return pending("The actual original first caption line is unavailable.")
	var full_name:=name(parts)
	if not full_name.ready:return full_name
	var summary:=classes(private_classes,tables,text)
	if not summary.ready:return summary
	return {"ready":true,"text":(full_name.text+"   " if not full_name.text.is_empty() else "")+summary.text+"        "+first_caption_line,"name":full_name.text,"classes":summary.text,"runtimeIntegrated":false}
