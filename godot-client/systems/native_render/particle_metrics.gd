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
var native_counters: RefCounted
var native_scratch:=PackedInt64Array()
const FIELDS=["simulated","active","vertices","failed","fused_simulated","composed_simulated","native_parameter_simulated","gd_parameter_simulated","constant_channel_hits","sampled_channels","culling_checks","culled_frames","culled_emitters","currently_culled","culling_fallbacks"]
func _init(native_requested: Variant=null) -> void:
	sums.resize(FIELDS.size()); sums.fill(0); scratch.assign(sums)
	var requested: bool=bool(native_requested) if native_requested is bool else not OS.get_cmdline_user_args().has("--particle-metrics=gd") and (OS.get_cmdline_user_args().has("--particle-metrics=native") or OS.get_environment("NWN_PARTICLE_METRICS")!="gd")
	if requested:
		if not ClassDB.class_exists("NwnParticleCounters"):
			if native_requested==true or OS.get_cmdline_user_args().has("--particle-metrics=native") or OS.get_environment("NWN_PARTICLE_METRICS")=="native": push_error("Native particle counters are unavailable")
			return
		native_counters=ClassDB.instantiate("NwnParticleCounters"); native_scratch.resize(FIELDS.size())
func register(emitter: Node) -> void:
	if closed: return
	var id:=emitter.get_instance_id()
	if entries.has(id): return
	var values: Array[int]=[]; values.assign(sums); values.fill(0)
	entries[id]={"values":values,"failure":"","classification":str(emitter.source_model_flags)}
	if native_counters!=null and not native_counters.call("register_id",id): push_error("Native particle counter registration failed")
	var classification: String=entries[id].classification
	classifications[classification]=int(classifications.get(classification,0))+1
func update(emitter: Node) -> void:
	var id:=emitter.get_instance_id()
	if not entries.has(id): return
	var entry: Dictionary=entries[id]; var simulated:=int(emitter.frames>0)
	if native_counters!=null:
		native_scratch[0]=simulated; native_scratch[1]=emitter.active_count(); native_scratch[2]=emitter.surface.vertex_count if is_instance_valid(emitter.surface) else 0; native_scratch[3]=int(not emitter.failure.is_empty())
		native_scratch[4]=simulated if emitter.fused_dispatch else 0; native_scratch[5]=simulated if not emitter.fused_dispatch else 0; native_scratch[6]=simulated if emitter.native_parameter_transfer else 0; native_scratch[7]=simulated if not emitter.native_parameter_transfer else 0
		native_scratch[8]=emitter.channels.constant_hits; native_scratch[9]=emitter.channels.sampled_channels; native_scratch[10]=emitter.culling_checks; native_scratch[11]=emitter.culled_frames; native_scratch[12]=int(emitter.culled_frames>0); native_scratch[13]=int(emitter.last_culled); native_scratch[14]=emitter.culling_fallbacks
		if not native_counters.call("update",id,native_scratch): push_error("Native particle counter update failed")
	else:
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
	if native_counters!=null:
		if not native_counters.call("remove_id",id): push_error("Native particle counter removal failed")
	else:
		for index in FIELDS.size(): sums[index]-=int(entry.values[index])
	remove_reason(id,str(entry.failure)); var classification:=str(entry.classification)
	classifications[classification]=int(classifications.get(classification,0))-1
	if int(classifications[classification])<=0: classifications.erase(classification)
	entries.erase(id)
func snapshot() -> Dictionary:
	var out: Dictionary={}
	if native_counters!=null:
		var totals: PackedInt64Array=native_counters.call("snapshot")
		for index in FIELDS.size(): out[FIELDS[index]]=totals[index]
	else:
		for index in FIELDS.size(): out[FIELDS[index]]=sums[index]
	out.emitters=entries.size(); out.diagnostics=diagnostics.values(); out.reason_counts=reasons.duplicate(); out.classification_counts=classifications.duplicate()
	return out
func close() -> void:
	closed=true; entries.clear(); reasons.clear(); diagnostics.clear(); classifications.clear()
	if native_counters!=null: native_counters.call("close")
	sums.fill(0)
