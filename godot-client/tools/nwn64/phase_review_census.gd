extends RefCounted
# PRIVATE final report only. Existing accepted485 dispatch16 exports sparse
# profile-OFF phase records; no simulation, clocks or scene state is changed.
const Profile=preload("res://systems/native_render/frame_profile.gd")
static func collect(world)->Dictionary:
	var result:={"version":1,"diagnostic":"accepted-particle-owner-phase-v1","success":false,"mutates_scene":false,"gd_profile_enabled":Profile.enabled}
	if not is_instance_valid(world):result.reason="world-unavailable";return result
	result.area_id=int(world.area_id);result.generation=int(world.generation)
	var group=world.get("particle_stream_group")
	if not is_instance_valid(group):result.reason="shared-group-unavailable";return result
	result.members=group.members.size();result.fast_members=int(group.fast_members)
	result.native_surface_output=bool(group.native_surface_output)
	var native=group.native
	if not is_instance_valid(native):result.reason="native-presentation-unavailable";return result
	var sampler: Variant=native.call("dispatch",16,{})
	if not sampler is Dictionary or sampler.has("error"):result.reason="sampler-report-unavailable";return result
	result.sampler=sampler
	result.success=bool(sampler.get("enabled",false)) and bool(sampler.get("coarse_phases",false)) and int(sampler.get("min_members",-1))==0 and int(sampler.get("stride",0))==120 and int(sampler.get("phase_success_samples",0))>0 and int(sampler.get("errors",-1))==0 and int(sampler.get("excluded_detailed_samples",-1))==0 and not Profile.enabled
	result.scope="Calling-thread Owner.frame wall phases, profile-OFF native route; dispatch-copy/GD envelope/renderer submission and GPU elapsed are excluded. Records may include area loading; correlate generation with existing observations before naming a steady window."
	return result
