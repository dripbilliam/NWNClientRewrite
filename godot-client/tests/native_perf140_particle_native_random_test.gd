extends "res://tests/native_particle_presentation_test.gd"
# Exact shared-stream oracle. Native-only known callables may bypass dispatch;
# every script/custom/replaced callable must keep its opaque callback behavior.
const Wind=preload("res://systems/native_render/scene_point_wind.gd")
var exercise:={"frame":0}

func actual_wind_contract(scene: Node3D) -> void:
	var hosts: Array=[];var winds: Array=[];var streams: Array=[]
	for native_rng in [false,true]:
		var stream: RefCounted=ClassDB.instantiate("NwnVisualRandom") if native_rng else Random.new();stream.seed_value(793)
		var host:=Node3D.new();host.set_meta("native_particle_random",stream);scene.add_child(host)
		var wind:=Wind.new();host.add_child(wind);wind.set_process(false)
		check(wind.failure.is_empty() and wind.rng==stream,"Actual wind binds selected shared visual object")
		check(wind.set_area({"e4":1}),"Actual ambient wind configures")
		hosts.append(host);winds.append(wind);streams.append(stream)
	for frame in 8:
		for slot in 2:
			# Ordinary GD/fallback draw occurs between native wind updates.
			streams[slot].next();winds[slot].tick(0.03125+frame*0.001)
		check(streams[0].state==streams[1].state and streams[0].draws==streams[1].draws,"Actual wind and GD draws preserve one stream "+str(frame))
		check(winds[0].failure.is_empty() and winds[1].failure.is_empty(),"Actual wind state handoff succeeds")
	for wind in winds:wind.close()
	for host in hosts:host.free()
	winds.clear();hosts.clear();streams.clear()

func stream_contract() -> void:
	for seed in [0,1,-1,4294967295,-9223372036854775807]:
		var gd:=Random.new();var native: RefCounted=ClassDB.instantiate("NwnVisualRandom")
		gd.seed_value(seed);native.seed_value(seed)
		for block in 12:
			# This is the existing wind owner's state/draw handoff contract.
			if block%3==0:
				gd.state=(gd.state+0x12345)&0xffffffff;native.state=(native.state+0x12345)&0xffffffff
				gd.draws+=19;native.draws+=19
			var expected: Array=[];var actual: Array=[]
			for draw in 31:expected.append(gd.next());actual.append(native.next())
			check(expected==actual and gd.state==native.state and gd.draws==native.draws,"Exact CRT block plus wind handoff "+str(seed)+"/"+str(block))
		gd.draws=9223372036854775807;native.draws=9223372036854775807
		check(gd.next()==native.next() and gd.draws==native.draws,"Draw counter wraps like Godot integers")
		var snapshot: Dictionary=native.snapshot();snapshot.state=123
		check(native.state==gd.state,"Detached native stream snapshot cannot mutate state")
	var before:=OS.get_environment("NWN_PARTICLE_RANDOM")
	OS.set_environment("NWN_PARTICLE_RANDOM","native")
	var first: RefCounted=Random.create();check(first.get_class()=="NwnVisualRandom","Explicit factory selects native world owner")
	first.next();first=null
	var second: RefCounted=Random.create();check(second.state==1 and second.draws==0,"New world/transition creates a fresh original visual stream")
	OS.set_environment("NWN_PARTICLE_RANDOM",before)

func group(scene: Node3D,native_rng: bool) -> Dictionary:
	var rng: RefCounted=ClassDB.instantiate("NwnVisualRandom") if native_rng else Random.new();rng.seed_value(987)
	var source:=Node3D.new();scene.add_child(source)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var row:={"rng":rng,"source":source,"presentation":presentation,"owners":[],"providers":[],"nodes":[],"custom":0,"fallback_draws":0}
	for index in 3:
		var pose:=Node3D.new();source.add_child(pose);pose.position=Vector3(index*0.3,0.1,0)
		var emitter:=Node3D.new();pose.add_child(emitter);row.nodes.append(emitter)
		var kind: String=["single","explosion","fountain"][index]
		var seed_owner:=make_owner(false,kind,32|128,false,false)
		seed_owner.state.birthRate=5.0;seed_owner.state.lifeExp=0.9;seed_owner.state.mass=0.05
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		check(not owner.call("dispatch",0,{"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()},{ }).has("error"),"Shared stream owner configures "+str(index))
		seed_owner.providers.clear();row.owners.append(owner)
		var providers:={"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass};row.providers.append(providers)
		check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"culling":true,"source_flags":0}).has("error"),"Shared stream native emitter registers")
		if index==0:
			var fallback:=Node3D.new();source.add_child(fallback)
			check(not presentation.call("dispatch",0,{"id":fallback.get_instance_id(),"fallback":func(_delta):
				# A GD fallback consumes the SAME world object between emitters.
				row.rng.next();row.fallback_draws+=1
				if exercise.frame%7==3:
					# Replace a later entry's provider DURING this native frame.
					row.providers[2].random=func():
						row.source.position+=Vector3(0.015625,0,0);row.custom+=1;return row.rng.next()
			}).has("error"),"GD fallback interleaves one shared stream")
	return row

func compare_groups(rows: Array,frame: int) -> void:
	var outputs: Array=[]
	for row: Dictionary in rows:
		row.source.position=Vector3(sin(frame*0.04),0.2,cos(frame*0.03))
		row.source.rotation=Vector3(0.02,frame*0.0125,0.03)
		for providers: Dictionary in row.providers:providers.random=row.rng.next
		if frame%9==0:
			for node: Node3D in row.nodes:row.presentation.call("dispatch",4,{"id":node.get_instance_id(),"detonate":true,"patch":{"birthRate":5.0+frame%3}})
		# Exact wind-like seed/draw publication shares the same RNG between calls.
		if frame%11==0:row.rng.state=(row.rng.state+99)&0xffffffff;row.rng.draws+=7
		outputs.append(row.presentation.call("dispatch",1,{"delta":[1.0/60.0,0.0,-0.002,0.7][frame%4],"view":view_packet(frame+6800000,frame%17==0),"profile":true}))
	check(not outputs[0].has("error") and not outputs[1].has("error"),"Paired native frame succeeds "+str(frame)+" "+str(outputs))
	if outputs.any(func(value):return value.has("error")):return
	for field in ["prepared","fallbacks","culled","active","vertices","draws"]:check(outputs[0].get(field)==outputs[1].get(field),"Exact shared-stream admission "+field)
	var a: Dictionary=rows[0].presentation.call("dispatch",2,{})
	var b: Dictionary=rows[1].presentation.call("dispatch",2,{})
	check(a.buffer==b.buffer,"Exact native/GD stream geometry bytes "+str(frame))
	for index in 3:
		var expected: Dictionary=rows[0].owners[index].call("dispatch",2,{},{})
		var actual: Dictionary=rows[1].owners[index].call("dispatch",2,{},{})
		check(same(without_ids(expected),without_ids(actual)).is_empty(),"Exact simulation/recycling/pose after RNG interleave "+str(frame)+"/"+str(index))
	check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Exact one-world state and draw count after frame "+str(frame))
	check(rows[0].custom==rows[1].custom and rows[0].fallback_draws==rows[1].fallback_draws,"Custom replacement and GD fallback execute exactly")
	check(int(outputs[0].phases.get("count_particle_native_random_direct",0))==0,"GDScript RNG is never called directly")
	if frame==47:
		check(int(rows[1].rng.snapshot().direct_hits)>0,"Known native next callable actually bypasses dispatch")
		check(rows[1].custom>0 and rows[1].fallback_draws>0,"Custom provider and fallback boundaries were exercised")

func scripted_replacement(scene: Node3D) -> void:
	var native: RefCounted=ClassDB.instantiate("NwnVisualRandom");native.seed_value(123)
	var code:=GDScript.new();code.source_code="extends NwnVisualRandom\n@warning_ignore(\"native_method_override\")\nfunc next() -> int:\n\tset_meta(\"override_calls\",int(get_meta(\"override_calls\",0))+1)\n\tstate=state+11\n\treturn 77\n"
	check(code.reload()==OK,"Actual script override compiles on native RNG class")
	native.set_script(code)
	var source:=Node3D.new();scene.add_child(source);var pose:=Node3D.new();source.add_child(pose)
	var seed_owner:=make_owner(false,"fountain",32,false,false);seed_owner.state.birthRate=8.0;seed_owner.state.lifeExp=1.0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()},{ }).has("error"),"Scripted RNG native owner configures")
	seed_owner.providers.clear();var services:={"random":native.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass}
	var before: Dictionary=native.snapshot()
	var output: Dictionary=owner.call("dispatch",1,{"clip":"","time":0.2,"delta":0.2,"capacity":0,"view":view_packet(6900000,false),"source_flags":0,"culling":false},services)
	check(not output.has("error"),"Native emitter executes attached-script RNG "+str(output.get("error","")))
	check(int(native.get_meta("override_calls",0))>0,"Attached script next is NOT bypassed")
	check(native.snapshot().direct_hits==before.direct_hits and native.draws==0,"Script override preserves state/draw authority")
	native.set_script(null);services.random=native.next
	output=owner.call("dispatch",1,{"clip":"","time":0.4,"delta":0.2,"capacity":0,"view":view_packet(6900001,false),"source_flags":0,"culling":false},services)
	check(not output.has("error") and native.snapshot().direct_hits>before.direct_hits and native.draws>0,"Removing script restores guarded native path")
	# A standard method on the same native object still must not be mistaken
	# for next(). A closure likewise keeps its side effects and mutation barrier.
	var custom:={"calls":0};services.random=func():custom.calls+=1;return native.next()
	before=native.snapshot();output=owner.call("dispatch",1,{"clip":"","time":0.6,"delta":0.2,"capacity":0,"view":view_packet(6900002,false),"source_flags":0,"culling":false},services)
	check(not output.has("error") and custom.calls>0 and native.snapshot().direct_hits==before.direct_hits,"Custom wrapper is never bypassed even when it delegates to native RNG")
	services.clear();owner=null;native=null;code=null

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	check(ClassDB.class_exists("NwnVisualRandom"),"Private native visual stream class is registered")
	if not failures.is_empty():quit(1);return
	stream_contract()
	var scene:=Node3D.new();root.add_child(scene)
	actual_wind_contract(scene)
	var rows:=[group(scene,false),group(scene,true)]
	for frame in 48:
		exercise.frame=frame;compare_groups(rows,frame)
		if not failures.is_empty():break
	for row: Dictionary in rows:
		row.presentation.call("dispatch",5,{})
		for providers: Dictionary in row.providers:providers.clear()
		row.providers.clear();row.owners.clear();row.presentation=null;row.rng=null
	rows.clear();scripted_replacement(scene);scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":exercise.frame+1,"network_connections":0,"gpu_execution":false,"scope":"Exact shared native/GD visual stream, fallback interleave, detonations, wind-style seed handoff, transition reset, attached-script and same-call custom replacement guards. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
