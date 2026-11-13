extends "res://tests/nwn64_typed_pose_test.gd"
# Private-only shared CPU presentation parity for the callback-epoch cache.
# A single common Dictionary is deliberately mutated from every callback
# family that can precede a later emitter in the same synchronous frame.

func mutate(lane: Dictionary, kind: String) -> void:
	lane.events.append(kind)
	if lane.allow_mutation and not lane.mutated:
		lane.common.animating = false
		lane.mutated = true

func random_for(lane: Dictionary, mutator: bool) -> int:
	if mutator and lane.mode == "random": mutate(lane, "random")
	return lane.rng.next()

func collide_for(_start, _end, _point, _hit, lane: Dictionary, mutator: bool) -> bool:
	if mutator and lane.mode == "collision": mutate(lane, "collision")
	return false

func clock_for(lane: Dictionary) -> Dictionary:
	mutate(lane, "clock")
	return {"clip": "", "time": 0.0}

func ready_for(lane: Dictionary) -> bool:
	mutate(lane, "readiness")
	return true

func fallback_for(_delta: float, lane: Dictionary) -> void:
	mutate(lane, "fallback")

func add_native(lane: Dictionary, node: Node3D, role: String) -> void:
	var mutator: bool = role == "mutator"
	var kind: String = "fountain" if role == "tail" or mutator and lane.mode in ["ready", "random", "collision"] else "single"
	var flags: int = 16 if mutator and lane.mode == "collision" else 0
	var seed = make_owner(false, kind, flags, false, false)
	seed.state.birthRate = 120.0 if kind == "fountain" else 0.0
	seed.state.lifeExp = 1.0
	seed.state.velocity = 0.0
	seed.state.randomVelocity = 0.0
	seed.state.mass = 0.0
	seed.state.spread = 0.25 if mutator and lane.mode == "random" else 0.0
	seed.state.xSize = 0.0
	seed.state.ySize = 0.0
	seed.state.renderMode1a8 = 0
	var owner: RefCounted = ClassDB.instantiate("NwnParticleOwner")
	var configured: Dictionary = owner.call("dispatch", 0, {"state": seed.state, "update": kind, "compactRecords": true, "typedEmitter": true, "poseId": node.get_instance_id(), "sourceId": node.get_instance_id()}, {})
	check(not configured.has("error"), "Native owner configures " + lane.mode + "/" + role)
	var providers: Dictionary = {"random": random_for.bind(lane, mutator), "cosineDouble": func(angle): return cos(angle), "collide": collide_for.bind(lane, mutator)}
	var registration: Dictionary = {"id": node.get_instance_id(), "owner": owner, "providers": providers, "source_flags": 0, "clip": "", "culling": false}
	if mutator and lane.mode == "ready": registration.ready = ready_for.bind(lane)
	if mutator and lane.mode == "clock": registration.clock = clock_for.bind(lane)
	var added: Dictionary = lane.presentation.call("dispatch", 0, registration)
	check(not added.has("error"), "Native source registers " + lane.mode + "/" + role + " " + str(added.get("error", "")))
	lane.owners.append(owner)
	lane.providers.append(providers)
	seed.providers.clear()

func add_lane(scene: Node3D, nodes: Array, mode: String, enabled: bool) -> Dictionary:
	var presentation: RefCounted = ClassDB.instantiate("NwnParticlePresentation")
	var configured: Dictionary = presentation.call("dispatch", 15, {"enabled": false, "setup_boundary": true, "animating_epoch_cache": enabled, "reset": true})
	check(not configured.has("error") and bool(configured.get("animating_epoch_cache", not enabled)) == enabled, "Private cache toggle is explicit")
	var rng = Random.new(); rng.seed_value(321)
	var lane: Dictionary = {"mode": mode, "presentation": presentation, "owners": [], "providers": [], "rng": rng, "events": [], "common": {}, "mutated": false, "allow_mutation": true}
	for index in nodes.size():
		if index == 4 and mode == "fallback":
			var result: Dictionary = presentation.call("dispatch", 0, {"id": nodes[index].get_instance_id(), "fallback": fallback_for.bind(lane)})
			check(not result.has("error"), "Fallback source registers")
		else:
			add_native(lane, nodes[index], "mutator" if index == 4 else "tail" if index == 5 else "quiet")
	return lane

func state_for(lane: Dictionary) -> Dictionary:
	var snapshots: Array = []
	for owner in lane.owners: snapshots.append(owner.call("dispatch", 2, {}, {}))
	var packet: Dictionary = lane.presentation.call("dispatch", 2, {})
	return {"owners": snapshots, "buffer": packet.get("buffer", PackedByteArray()), "ranges": packet.get("ranges", []), "rng_state": lane.rng.state, "rng_draws": lane.rng.draws, "events": lane.events.duplicate()}

func run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair = arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if not args.has("report") or FileAccess.file_exists(str(args.report)): quit(2); return
	check(Kernel.available(), "Private native particle kernel loads")
	var cases: Array = []
	for mode in ["quiet", "fallback", "ready", "clock", "random", "collision"]:
		var scene := Node3D.new(); root.add_child(scene)
		var nodes: Array = []
		for index in 6:
			var node := Node3D.new(); scene.add_child(node); nodes.append(node)
		var off: Dictionary = add_lane(scene, nodes, mode, false)
		var on: Dictionary = add_lane(scene, nodes, mode, true)
		for frame in 3:
			for lane in [off, on]:
				lane.common = {"delta": 1.0 / 60.0, "view": view_packet(frame + 20000000 + cases.size() * 100, false), "profile": false, "native_surface_output": true, "animating": true}
				lane.mutated = false
				lane.allow_mutation = mode != "collision" or frame >= 1
				var result: Dictionary = lane.presentation.call("dispatch", 1, lane.common)
				check(not result.has("error"), "Frame completes " + mode + "/" + str(frame) + " " + str(result.get("error", "")))
			check(same(state_for(off), state_for(on)).is_empty(), "Exact state/packet/RNG/callback parity " + mode + "/" + str(frame))
		var info: Dictionary = on.presentation.call("dispatch", 16, {})
		check(int(info.get("animating_cache_hits", 0)) > 0, "Callback-free adjacent emitters reuse the common value " + mode)
		if mode != "quiet": check(off.events == on.events and not on.events.is_empty(), "Mutation callback actually ran " + mode)
		cases.append({"mode": mode, "hits": info.get("animating_cache_hits", 0), "misses": info.get("animating_cache_misses", 0), "callbacks": on.events.size(), "rng_draws": on.rng.draws})
		for lane in [off, on]:
			lane.presentation.call("dispatch", 4, {"id": nodes[5].get_instance_id(), "enabled": false})
			lane.common = {"delta": 1.0 / 60.0, "view": view_packet(21000000 + cases.size(), false), "profile": false, "native_surface_output": true, "animating": true}
			lane.presentation.call("dispatch", 1, lane.common)
		check(same(state_for(off), state_for(on)).is_empty(), "Particle-off state parity " + mode)
		for lane in [off, on]: lane.presentation.call("dispatch", 5, {}); lane.providers.clear(); lane.owners.clear()
		scene.free()
	var report: Dictionary = {"issue": "NWN-64", "success": failures.is_empty(), "checks": checks, "failures": failures, "cases": cases, "scope": "Private shared CPU presentation; callback-free reuse and fallback/readiness/clock/random/collision mutations, exact output/RNG/state, particle-off and close. No renderer, whole-frame or FPS claim."}
	var file := FileAccess.open(str(args.report), FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print("NWN64_ANIMATING_EPOCH ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
