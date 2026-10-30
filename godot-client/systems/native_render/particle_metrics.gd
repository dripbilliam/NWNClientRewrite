extends RefCounted
# World-owned incremental counters. Entries retain values/IDs, never Nodes or
# particle records. Updates happen at the emitter's normal publication boundary.
var entries: Dictionary={}
var sums: Array[int]=[]
var scratch: Array[int]=[]
var reasons: Dictionary={}
var diagnostics: Dictionary={}
var classifications: Dictionary={}
var closed:=false
const FIELDS=["simulated","active","vertices","failed","fused_simulated","composed_simulated","native_parameter_simulated","gd_parameter_simulated","constant_channel_hits","sampled_channels","culling_checks","culled_frames","culled_emitters","currently_culled","culling_fallbacks"]
func _init() -> void:
	sums.resize(FIELDS.size()); sums.fill(0); scratch.assign(sums)
func register(emitter: Node) -> void:
	if closed: return
	var id:=emitter.get_instance_id()
	if entries.has(id): return
	var values: Array[int]=[]; values.assign(sums); values.fill(0)
	entries[id]={"values":values,"failure":"","classification":str(emitter.source_model_flags)}
	var classification: String=entries[id].classification
	classifications[classification]=int(classifications.get(classification,0))+1
func update(emitter: Node) -> void:
	var id:=emitter.get_instance_id()
	if not entries.has(id): return
	var entry: Dictionary=entries[id]; var simulated:=int(emitter.frames>0)
	scratch[0]=simulated; scratch[1]=emitter.active_count(); scratch[2]=emitter.surface.vertex_count if is_instance_valid(emitter.surface) else 0; scratch[3]=int(not emitter.failure.is_empty())
	scratch[4]=simulated if emitter.fused_dispatch else 0; scratch[5]=simulated if not emitter.fused_dispatch else 0; scratch[6]=simulated if emitter.native_parameter_transfer else 0; scratch[7]=simulated if not emitter.native_parameter_transfer else 0
	scratch[8]=emitter.channels.constant_hits; scratch[9]=emitter.channels.sampled_channels; scratch[10]=emitter.culling_checks; scratch[11]=emitter.culled_frames; scratch[12]=int(emitter.culled_frames>0); scratch[13]=int(emitter.last_culled); scratch[14]=emitter.culling_fallbacks
	var previous: Array=entry.values
	for index in FIELDS.size(): sums[index]+=scratch[index]-int(previous[index]); previous[index]=scratch[index]
	if str(entry.failure)!=str(emitter.failure):
		remove_reason(id,str(entry.failure)); entry.failure=str(emitter.failure)
		if not str(entry.failure).is_empty():
			reasons[entry.failure]=int(reasons.get(entry.failure,0))+1
			if diagnostics.size()<128: diagnostics[id]={"node":str(emitter.get_path()),"reason":entry.failure}
func remove_reason(id: int,reason: String) -> void:
	if not reason.is_empty():
		reasons[reason]=int(reasons.get(reason,0))-1
		if int(reasons[reason])<=0: reasons.erase(reason)
	diagnostics.erase(id)
func unregister(emitter: Node) -> void:
	var id:=emitter.get_instance_id()
	if not entries.has(id): return
	var entry: Dictionary=entries[id]
	for index in FIELDS.size(): sums[index]-=int(entry.values[index])
	remove_reason(id,str(entry.failure)); var classification:=str(entry.classification)
	classifications[classification]=int(classifications.get(classification,0))-1
	if int(classifications[classification])<=0: classifications.erase(classification)
	entries.erase(id)
func snapshot() -> Dictionary:
	var out: Dictionary={}
	for index in FIELDS.size(): out[FIELDS[index]]=sums[index]
	out.emitters=entries.size(); out.diagnostics=diagnostics.values(); out.reason_counts=reasons.duplicate(); out.classification_counts=classifications.duplicate()
	return out
func close() -> void:
	closed=true; entries.clear(); reasons.clear(); diagnostics.clear(); classifications.clear()
	sums.fill(0)
