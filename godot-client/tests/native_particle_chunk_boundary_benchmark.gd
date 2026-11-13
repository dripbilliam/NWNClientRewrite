extends "res://tests/native_particle_resident_test.gd"
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
func model_services(stats: Dictionary) -> Dictionary:
	return {"createChunkModel":func(_name):stats.created+=1; return "chunk"+str(stats.created),
		"chunkScene":func(_child,attached):stats.attached+=int(attached); stats.detached+=int(not attached),
		"chunkScale":func(_child,_factor,_kind):stats.scaled+=1,
		"chunkPlay":func(_child,_clip,_speed,_flags,_time):stats.played+=1,
		"chunkPosition":func(_child,_position):stats.positions+=1,
		"chunkOrientation":func(_child,_q):stats.orientations+=1,
		"destroyChunkModel":func(_child,_flag):stats.destroyed+=1}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var host:=Node3D.new(); root.add_child(host)
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(0,4,8); camera.look_at(Vector3.ZERO); camera.current=true
	var groups: Array=[[],[]]; var model_stats: Array=[[],[]]; var timings: Array=[[],[]]
	for slot in 2:
		for n in 28:
			var stats:={"created":0,"attached":0,"detached":0,"scaled":0,"played":0,"positions":0,"orientations":0,"destroyed":0}
			var emitter:=Emitter.new(); emitter.force_reference=slot==0; emitter.source_path=NodePath(".."); emitter.source_model_flags=0; emitter.frustum_enabled=false
			emitter.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":32|64,"chunkname":"authored_chunk","texture":"NULL","birthrate":3.0,"lifeexp":0.75,"velocity":0.2,"randvel":0.3,"spread":0.8,"xsize":5.0,"ysize":3.0,"sizestart":0.1,"sizeend":0.2,"alphastart":1.0,"alphaend":0.2,"particlerot":2.9,"frameend":7.0}
			emitter.services=model_services(stats); host.add_child(emitter); emitter.set_process(false); emitter.rng.seed_value(321+n)
			check(emitter.failure.is_empty() and emitter.compiled_kernel,"Chunk boundary configures compiled emitter "+str(slot)+"/"+str(n))
			check((emitter.native_owner!=null)==bool(slot),"Measures old compiled versus resident boundary "+str(slot)+"/"+str(n))
			groups[slot].append(emitter); model_stats[slot].append(stats)
	var windows: Array=[]
	for frame in 600:
		host.position=Vector3(sin(frame*0.01),0.0,cos(frame*0.013))
		for turn in 2:
			var slot: int=(turn+frame)%2
			var start:=Time.get_ticks_usec()
			for emitter in groups[slot]: emitter.tick(1.0/60.0,true)
			var elapsed:=Time.get_ticks_usec()-start
			if frame>=120: timings[slot].append(elapsed)
		if frame%30==0 or frame==599:
			for n in 28:
				var a=groups[0][n]; var b=groups[1][n]
				check(a.failure.is_empty() and b.failure.is_empty(),"Chunk boundary frames remain valid "+str(frame)+"/"+str(n))
				var difference:=same(a.state,b.state)
				check(difference.is_empty(),"Exact chunk boundary state "+str(frame)+"/"+str(n)+" "+difference)
				check(a.rng.state==b.rng.state and a.rng.draws==b.rng.draws,"Exact chunk boundary RNG "+str(frame)+"/"+str(n))
				var model_difference:=same(model_stats[0][n],model_stats[1][n])
				check(model_difference.is_empty(),"Exact model service totals "+str(frame)+"/"+str(n)+" "+model_difference)
		if not failures.is_empty(): break
		if frame>=120 and (frame+1)%120==0:
			var means: Array=[]
			for slot in 2:
				var sum:=0.0
				for n in range(timings[slot].size()-120,timings[slot].size()): sum+=float(timings[slot][n])
				means.append(sum/120.0/1000.0)
			windows.append({"end_frame":frame,"compiled_ms":means[0],"resident_ms":means[1],"reduction":1.0-means[1]/means[0]})
	var summary: Array=[]
	for slot in 2:
		var values: Array=timings[slot]; values.sort(); var sum:=0.0
		for value in values: sum+=float(value)
		summary.append({"resident":bool(slot),"samples":values.size(),"mean_ms":sum/maxi(1,values.size())/1000.0,"p95_ms":float(values[int((values.size()-1)*0.95)])/1000.0 if not values.is_empty() else 0.0})
	for slot in 2:
		for emitter in groups[slot]: emitter.retire()
	for n in 28:
		check(model_stats[0][n].created==model_stats[0][n].destroyed and model_stats[1][n].created==model_stats[1][n].destroyed,"Both chunk boundaries destroy every private model "+str(n))
	host.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timings":summary,"windows":windows,"emitters_per_path":28,"network_connections":0,"scope":"Interleaved identical source/parameters/RNG: old compiled chunk emitter versus resident native chunk state. Model-service calls use captured lightweight providers; actual model/GPU/server performance requires separate graphical and live receipts."},"\t")); file.close()
	print("NATIVE_PARTICLE_CHUNK_BOUNDARY ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
