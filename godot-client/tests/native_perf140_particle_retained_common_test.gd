extends "res://tests/native_perf140_particle_common_input_test.gd"
func _init() -> void:
	experiment_mode="retain_common_animating"
	experiment_scope="Independent synchronous common truth-conversion reuse, invalidated by every opaque callback and new presentation call. Exact missing/bool/integer/float semantics, same-call mutable Dictionary, failures/retry, pending controls and closed lifecycle; no FPS claim."
func finish_experiment(groups: Array) -> void:
	# Paused native updates do not invoke particle services. The interleaved
	# fallback and actor clock still form real barriers; the two entries before
	# the first barrier must exercise reuse rather than merely select its flag.
	for group: Dictionary in groups:
		for index in 4:
			var node: Node3D=group.nodes[index+(1 if index>1 else 0)]
			check(not group.presentation.call("dispatch",4,{"id":node.get_instance_id(),"source_animating":false}).has("error"),"Common reuse fixture pauses every source")
		var output: Dictionary=group.presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(14090000,false),"animating":false,"profile":true})
		check(not output.has("error"),"Paused common reuse fixture runs")
		var phases: Dictionary=output.get("phases",{})
		check(int(phases.get("count_particle_native_common_reads",0))+int(phases.get("count_particle_native_common_hits",0))==4,"Common counters cover exactly the four native entries")
		if group.reuse:check(int(phases.get("count_particle_native_common_hits",0))>0 and int(phases.get("count_particle_native_common_reads",0))<4,"An unchanged epoch actually avoids engine Dictionary reads")
		else:check(int(phases.get("count_particle_native_common_hits",0))==0 and int(phases.get("count_particle_native_common_reads",0))==4,"Ordinary oracle keeps live per-entry reads")
	# Force a conversion failure AFTER an earlier emitter read a valid common
	# value. Reuse must not swallow the callback's new malformed Dictionary.
	oracle_context.frame=180
	var originals: Array=[]
	for group: Dictionary in groups:
		originals.append(group.services[0].random)
		group.services[0].random=func():group.common.animating={"invalid":true};return group.rng.next()
		check(not group.presentation.call("dispatch",4,{"id":group.nodes[0].get_instance_id(),"culling":false,"patch":{"birthRate":32.0}}).has("error"),"Retained common failure fixture prepares admitted births")
	compare_controls(groups,0.125,true)
	for index in groups.size():groups[index].services[0].random=originals[index]
	compare_controls(groups,0.01)
	for group: Dictionary in groups:
		var draws: int=group.rng.draws
		check(not group.presentation.call("dispatch",5,{}).has("error"),"Retained common group closes")
		var result: Dictionary=group.presentation.call("dispatch",1,{"delta":0.01,"animating":{"invalid":true}})
		check(result.get("error","")=="Native presentation is closed or already running","Closed frame rejects before reading cached/malformed common input")
		check(group.rng.draws==draws,"Closed common frame consumes no RNG")
	oracle_context.frame=179
