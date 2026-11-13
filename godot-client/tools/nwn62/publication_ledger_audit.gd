extends RefCounted
# PRIVATE diagnostic overlay only. Aggregate every touched Engine frame without
# retaining scene owners or per-frame samples. Phase CPU includes nested scopes;
# only charged_us follows the shared outer ledger and is additive across frames.
var frames:=0
var charged_us:=0
var maximum_charged_us:=0
var exhausted_frames:=0
var quota_frames:=0
var construction_units:=0
var publication_units:=0
var completion_units:=0
var phases: Dictionary={}
var denials: Dictionary={}
var last_finished:=-1
func finish_frame(pool)->void:
	if int(pool.publication_frame)<0 or int(pool.publication_frame)==last_finished:return
	last_finished=int(pool.publication_frame);frames+=1
	var used:=int(pool.publication_us);charged_us+=used;maximum_charged_us=maxi(maximum_charged_us,used)
	construction_units+=int(pool.construction_steps);publication_units+=int(pool.publications);completion_units+=int(pool.completion_units)
	if used>=int(pool.publication_budget_limit_us()):exhausted_frames+=1
	if int(pool.publications)>=int(pool.maximum_publications_per_frame):quota_frames+=1
func record(phase: String,elapsed: int,kind: String)->void:
	var key:=kind+":"+phase
	if not phases.has(key):phases[key]={"units":0,"cpu_us":0,"maximum_us":0}
	var entry: Dictionary=phases[key];entry.units+=1;entry.cpu_us+=elapsed;entry.maximum_us=maxi(entry.maximum_us,elapsed)
func deny(phase: String,elapsed: int,limit: int,quota: bool,kind: String)->void:
	var key:=kind+":"+phase
	if not denials.has(key):denials[key]={"attempts":0,"time":0,"quota":0,"time_and_quota":0}
	var entry: Dictionary=denials[key];entry.attempts+=1
	if elapsed>=limit:entry.time+=1
	if quota:entry.quota+=1
	if elapsed>=limit and quota:entry.time_and_quota+=1
func snapshot(pool)->Dictionary:
	# Include a provisional current frame without consuming it: runtime snapshots
	# must not alter a later frame's aggregation or double-count its work.
	var current:=int(pool.publication_frame)>=0 and int(pool.publication_frame)!=last_finished
	var count:=frames+int(current);var total:=charged_us+(int(pool.publication_us) if current else 0)
	return {"version":1,"frames":count,"charged_us":total,"mean_charged_us":float(total)/maxi(1,count),"maximum_charged_us":maxi(maximum_charged_us,int(pool.publication_us) if current else 0),"exhausted_frames":exhausted_frames+int(current and int(pool.publication_us)>=int(pool.publication_budget_limit_us())),"quota_frames":quota_frames+int(current and int(pool.publications)>=int(pool.maximum_publications_per_frame)),"construction_units":construction_units+(int(pool.construction_steps) if current else 0),"publication_units":publication_units+(int(pool.publications) if current else 0),"completion_units":completion_units+(int(pool.completion_units) if current else 0),"phases":phases.duplicate(true),"denials":denials.duplicate(true),"scope":"PRIVATE bounded numeric aggregates; charged_us is shared outer-ledger CPU; phase CPU may overlap completion scopes and must not be summed as exclusive CPU; no budget/quota/scheduling change"}
