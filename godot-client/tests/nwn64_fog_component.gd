extends "res://tests/nwn64_fog_test.gd"
func statistics(values: Array) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in sorted:total+=value
	return {"count":sorted.size(),"median_us":sorted[int(ceil(sorted.size()*.5))-1],"p95_us":sorted[int(ceil(sorted.size()*.95))-1],"mean_us":total/sorted.size(),"max_us":sorted[-1]}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var count:=clampi(int(args.get("sources",1750)),1,2048);var warm:=clampi(int(args.get("warm",60)),1,300);var samples:=clampi(int(args.get("samples",160)),1,1000)
	owner=Node.new();root.add_child(owner);source=Node3D.new();root.add_child(source);camera=Camera3D.new();camera.environment=Environment.new();camera.environment.fog_enabled=true;camera.environment.fog_depth_begin=3;camera.environment.fog_depth_end=90;root.add_child(camera);camera.current=true
	var emitters: Array=[];var blockers: Array=[]
	for index in count:
		var item:=Emitter.new();root.add_child(item);item.source=source;item._state={"chunkName":""};item.compiled_kernel=Kernel.enabled();item.native_surface_output=true;item.native_surface_world=weakref(owner)
		var stop:=Blocker.new();item.add_child(stop);item.chunk_models=stop;emitters.append(item);blockers.append(stop)
	await process_frame
	var rows: Array=[]
	for scenario in ["authoritative_area","camera_fallback"]:
		SurfaceState.bind(owner)
		if scenario=="authoritative_area":SurfaceState.publish(owner,Vector3(.7,.2,.4),true,11,99,true)
		var times: Array=[]
		for frame in warm+samples:
			var began:=Time.get_ticks_usec()
			for item in emitters:item._process(.016)
			if frame>=warm:times.append(Time.get_ticks_usec()-began)
		rows.append({"scenario":scenario,"cpu":statistics(times)})
	check(Probe.samples==0,"Component uses uninstrumented original Fog.sample")
	check(not preload("res://systems/native_render/frame_profile.gd").enabled,"Normal detailed profiling remains false")
	var ready_calls:=0;var draws:=0;var frames:=0;var elapsed:=0.0
	for index in emitters.size():
		ready_calls+=blockers[index].calls;draws+=emitters[index].rng.draws;frames+=emitters[index].frames;elapsed+=emitters[index].elapsed
		emitters[index].free()
	check(ready_calls==count*(warm+samples)*2 and draws==0 and frames==0 and elapsed==0,"Identical actual prefix visits; no simulation/RNG/clock changes")
	SurfaceState.retire(owner);owner.free();source.free();camera.free()
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"sources":count,"warm_frames":warm,"sample_frames":samples,"profile":false,"probe_samples":Probe.samples,"chunk_ready_calls":ready_calls,"rows":rows,"scope":"Headless actual uninstrumented normal emitter _process/tick fog prefix;1750 independent emitter/weak-owner objects, blocked chunk readiness after fog. Component CPU only, not complete simulation, graphical frametime or FPS."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_FOG_COMPONENT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
