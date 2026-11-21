extends RefCounted
# Worker-side source proof only. No visual owner, world store or model-name
# inference. The original own-animation exclusion is intentionally retained.
const REVISION:="base-static-draw-proof-v1"
const FORBIDDEN_FEATURES:=["skin","animated-mesh","dangly","reference","aabb"]
static func unavailable(reason: String) -> Dictionary:return {"revision":REVISION,"available":false,"reason":reason,"parts":{}}
static func capture(bytes: PackedByteArray,model: Dictionary,source_sha: String) -> Dictionary:
	if source_sha.length()!=64 or not source_sha.is_valid_hex_number() or not model.get("nodes") is Array or model.nodes.is_empty():return unavailable("source-or-physical-graph-unavailable")
	var own_animations: Variant=null;var supermodel: Variant=null
	if bytes.size()>=4 and bytes.decode_u32(0)==0:
		if bytes.size()<244 or bytes.decode_u32(4)<232 or int(bytes.decode_u32(4))+12>bytes.size():return unavailable("binary-model-header-unavailable")
		own_animations=bytes.decode_u32(136)
		var name_bytes:=bytes.slice(180,244);var terminator:=name_bytes.find(0)
		supermodel=name_bytes.slice(0,terminator if terminator>=0 else name_bytes.size()).get_string_from_ascii().to_lower()
	else:
		own_animations=0
		for line in bytes.get_string_from_utf8().replace("\r","").split("\n"):
			var text:=str(line).strip_edges()
			if text.is_empty() or text.begins_with("#"):continue
			var words:=text.replace("\t"," ").split(" ",false)
			if words[0].to_lower()=="newanim":own_animations+=1
			if words[0].to_lower()=="setsupermodel" and words.size()>=3:supermodel=words[2].to_lower()
	if own_animations!=0:return unavailable("original-own-animation-count-positive")
	if supermodel==null:return unavailable("original-supermodel-unavailable")
	if supermodel not in ["","null"]:return unavailable("inherited-animation-proof-unavailable")
	var parts:={}
	for index in model.nodes.size():
		var row: Variant=model.nodes[index]
		if not row is Dictionary or not row.get("mesh") is Dictionary or not row.get("features") is Array or not row.get("parent") is int:return unavailable("physical-part-graph-unavailable")
		if row.mesh.is_empty() or row.mesh.get("render")!=true:continue
		var current: int=index;var supported:=true;var ancestors: Array=[]
		while current>=0:
			if current>=model.nodes.size() or ancestors.has(current):return unavailable("physical-part-cycle-or-range")
			var parent: Variant=model.nodes[current]
			if not parent is Dictionary or not parent.get("features") is Array or not parent.get("parent") is int:return unavailable("physical-part-ancestry-unavailable")
			ancestors.append(current)
			for feature in parent.features:
				if feature in FORBIDDEN_FEATURES or feature not in ["light","emitter"]:supported=false
			if parent.has("reference") or parent.has("skin") or parent.has("animated_mesh"):supported=false
			current=int(parent.parent)
		if supported and not row.features.has("emitter") and not row.features.has("light"):
			parts[index]={"index":index,"name":str(row.get("name","")),"ancestors":ancestors,"original_alpha":row.get("alpha"),"render":true}
	return {"revision":REVISION,"available":true,"source_sha":source_sha.to_lower(),"own_animation_count":0,"supermodel":supermodel,"parts":parts,"source":"Original CreatePartBuckets owning Model own-animation exclusion; ordinary supported physical mesh ancestry"}
