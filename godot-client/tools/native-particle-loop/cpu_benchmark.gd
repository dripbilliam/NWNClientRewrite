extends "res://tests/native_particle_presentation_lifetime_test.gd"

func measure() -> Dictionary:
	var scene:=Node3D.new();root.add_child(scene)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var providers:={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	const COUNT:=2064
	for index in COUNT:
		var node:=Node3D.new();scene.add_child(node);node.position=Vector3((index%64)*0.01,0,(index/64)*0.01)
		var owner:=simple_owner(node)
		check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":providers,"culling":false}).has("error"),"Dense benchmark owner registration")
	var common:={"delta":1.0/6000,"view":view_packet(7100000,false),"animating":true}
	var samples: Array[int]=[];var result: Dictionary={}
	for frame in 480:
		# Steady dispatch alone is timed; creation, view construction, sorting
		# samples, diagnostics and file writes are outside this CPU interval.
		common.view=view_packet(7100000+frame,false)
		var began:=Time.get_ticks_usec()
		result=presentation.call("dispatch",1,common)
		var duration:=Time.get_ticks_usec()-began
		if frame>=120:samples.append(duration)
		if result.has("error"):check(false,"Benchmark frame "+str(result));break
	check(result.get("active")==COUNT and result.get("vertices")==COUNT*6,"All dense benchmark effects remain active and rendered")
	var packet: Dictionary=presentation.call("dispatch",2,{})
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(packet.buffer)
	var packet_hash:=digest.finish().hex_encode()
	presentation.call("dispatch",5,{});presentation=null;providers.clear();scene.free()
	var total:=0
	for sample in samples:total+=sample
	var sorted:=samples.duplicate();sorted.sort()
	return {"emitters":COUNT,"warmup":120,"samples_us":samples,"mean_us":float(total)/maxi(samples.size(),1),"median_us":sorted[sorted.size()/2] if not sorted.is_empty() else 0,"p99_us":sorted[int(sorted.size()*0.99)] if not sorted.is_empty() else 0,"packet_sha256":packet_hash,"vertices":result.get("vertices"),"active":result.get("active"),"profile":false}

func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var measurements:=measure()
	await process_frame;await process_frame
	var value:={"success":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"scope":"Private 2064-emitter steady native CPU dispatch only; profile off. No GPU, world-camera, FPS or loading claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  "));file.close();quit(0 if failures.is_empty() else 1)
