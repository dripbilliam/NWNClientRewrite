extends RefCounted
# Read-only final-world probe for the existing sparse native presentation sampler.
# Run only after a client launched with --particle-coarse-timing has entered a
# representative busy area; this does not measure or claim FPS.

const Profile=preload("res://systems/native_render/frame_profile.gd")

static func assess(sampler: Dictionary, members: int, gd_profile: bool) -> Dictionary:
	var reasons: Array[String]=[]
	if not bool(sampler.get("enabled",false)):reasons.append("sampler-disabled")
	if not bool(sampler.get("coarse_phases",false)):reasons.append("coarse-phases-disabled")
	if int(sampler.get("stride",0))!=120:reasons.append("unexpected-stride")
	if int(sampler.get("min_members",-1))!=1800:reasons.append("unexpected-member-threshold")
	if members<1800:reasons.append("current-population-below-threshold")
	if gd_profile:reasons.append("gd-detailed-profile-enabled")
	if int(sampler.get("excluded_detailed_samples",0))!=0:reasons.append("native-detailed-samples-excluded")
	if int(sampler.get("errors",0))!=0:reasons.append("sampled-frame-error")
	if int(sampler.get("phase_success_samples",0))<2:reasons.append("too-few-complete-phase-samples")
	var records: Array=sampler.get("records",[])
	var complete:=0
	for row in records:
		if bool(row.get("success",false)) and bool(row.get("phase_complete",false)):
			complete+=1
			if float(row.get("entry_advance_ms",-1.0))<=0.0:reasons.append("missing-entry-advance-phase");break
	if complete<2:reasons.append("too-few-retained-complete-records")
	return {"ready":reasons.is_empty(),"reasons":reasons,"members":members,"complete_records":complete,"phase_success_samples":int(sampler.get("phase_success_samples",0)),"phase_success_means":sampler.get("phase_success_means",{}),"scope":"Sparse profile-OFF CPU wall phase evidence only. Caller must correlate selected generations with a representative Tracy busy window; no FPS, GPU or inner-advance attribution."}

static func collect(world: Node) -> Dictionary:
	if not is_instance_valid(world):return {"ready":false,"reasons":["world-unavailable"]}
	var group=world.get("particle_stream_group")
	if not is_instance_valid(group) or not is_instance_valid(group.native):return {"ready":false,"reasons":["native-group-unavailable"]}
	var sampler: Variant=group.native.call("dispatch",16,{})
	if not sampler is Dictionary or sampler.has("error"):return {"ready":false,"reasons":["sampler-read-failed"]}
	var result:=assess(sampler,int(group.fast_members),Profile.enabled)
	result.area_id=int(world.get("area_id"));result.generation=int(world.get("generation"))
	result.sampler=sampler
	return result
