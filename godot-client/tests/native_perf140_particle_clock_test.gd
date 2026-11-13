extends "res://tests/native_particle_presentation_test.gd"
# The native slot is an explicit publication; the producer remains authoritative.
class Producer:
	extends Node
	var payload: Variant={"clip":"constant","time":0.123456789123,"serial":1}
	func sample() -> Variant:return payload

func setup_clock(scene: Node3D,typed: bool) -> Dictionary:
	var producer:=Producer.new();scene.add_child(producer)
	var source:=Node3D.new();scene.add_child(source);var pose:=Node3D.new();source.add_child(pose)
	var node:=Node3D.new();pose.add_child(node)
	var seed:=make_owner(false,"fountain",32|128,false,false)
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"clips":channels.clips,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()},{ }).has("error"),"Typed clock simulation fixture configures")
	seed.providers.clear();var rng:=Random.new();rng.seed_value(717)
	var providers:={"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass}
	var slot: RefCounted=ClassDB.instantiate("NwnParticleClock")
	check(bool(ClassDB.class_call_static("NwnParticleClock","bind_source",slot,producer,producer.sample)),"Clock binds its explicit weak producer and original fallback")
	check(not bool(ClassDB.class_call_static("NwnParticleClock","bind_source",slot,producer,producer.sample)),"Clock source cannot silently rebind")
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":providers,"clock":slot.sample if typed else producer.sample,"clock_owner":slot if typed else null,"clip":"constant","clip_length":3.0,"culling":true,"source_flags":0}).has("error"),"Native shared clock consumer registers")
	return {"producer":producer,"source":source,"pose":pose,"node":node,"owner":owner,"rng":rng,"providers":providers,"slot":slot,"presentation":presentation}

func compare_clock(rows: Array,frame: int,expected_error: bool=false) -> void:
	var results: Array=[]
	for row: Dictionary in rows:results.append(row.presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(frame+8200000,false),"profile":true}))
	check(results[0].has("error")==expected_error and results[1].has("error")==expected_error,"Clock error/validity boundary matches "+str(frame)+" "+str(results))
	if expected_error:
		check(results[0].get("error")==results[1].get("error"),"Malformed fallback preserves the exact error")
		return
	var a: Dictionary=rows[0].presentation.call("dispatch",2,{})
	var b: Dictionary=rows[1].presentation.call("dispatch",2,{})
	check(a.buffer==b.buffer,"Clock handoff preserves exact CPU geometry "+str(frame))
	check(same(without_ids(rows[0].owner.call("dispatch",2,{},{})),without_ids(rows[1].owner.call("dispatch",2,{},{}))).is_empty(),"Clock handoff preserves sampled fields/private state "+str(frame))
	check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Clock handoff preserves RNG draw order "+str(frame))
	for field in ["prepared","active","vertices","culled"]:check(results[0].get(field)==results[1].get(field),"Exact clock admission "+field)
	check(int(results[0].phases.get("count_particle_native_clock_direct",0))==0,"Ordinary scripted callable is never whitelisted")
	if frame==1:check(int(results[1].phases.get("count_particle_native_clock_direct",0))==1,"Published native sample actually bypasses the callback")
	if frame>=7:check(int(results[1].phases.get("count_particle_native_clock_direct",0))==0,"Disabled/changed source retains opaque original behavior")

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	check(ClassDB.class_exists("NwnParticleClock"),"Private native clock class is registered")
	var scene:=Node3D.new();root.add_child(scene);var rows:=[setup_clock(scene,false),setup_clock(scene,true)]
	for row: Dictionary in rows:
		ClassDB.class_call_static("NwnParticleClock","publish_fields",row.slot,"",-0.0,0,true)
		var expected:=PackedByteArray();expected.resize(8);expected.encode_double(0,-0.0)
		var actual:=PackedByteArray();actual.resize(8);actual.encode_double(0,float(row.slot.sample().time))
		check(actual==expected,"Clock publication preserves the raw signed-zero double")
		ClassDB.class_call_static("NwnParticleClock","publish_fields",row.slot,"unused",99.0,77,false)
		check(row.slot.sample()=={},"Unavailable clock fields are explicitly absent")
	for frame in 10:
		for row: Dictionary in rows:
			row.source.position=Vector3(frame*0.03125,0,0)
			if frame<7:
				row.producer.payload={"clip":["constant","linear","bezier"][frame%3],"time":0.123456789123+frame*0.03125,"serial":frame+2}
				check(bool(ClassDB.class_call_static("NwnParticleClock","publish_fields",row.slot,row.producer.payload.clip,row.producer.payload.time,row.producer.payload.serial,true)),"Canonical clock publication succeeds")
				check(row.slot.sample()==row.producer.sample(),"Native slot retains exact double/clip/serial")
				var snapshot: Dictionary=row.slot.sample();snapshot.time=99
				check(row.slot.sample()==row.producer.sample(),"Detached clock sample cannot mutate producer state")
			if frame==7:
				# Disable before replacement/close callbacks, then original callback
				# continues to resolve current data instead of a stale slot value.
				ClassDB.class_call_static("NwnParticleClock","disable",row.slot)
				row.producer.payload={}
			if frame==8:row.producer.payload=17
			if frame==9:row.producer.free()
		compare_clock(rows,frame,frame==8)
		if not failures.is_empty():break
	# A scripted native consumer is always opaque, even if its method name is
	# still sample and its native data is perfectly current.
	var custom: Dictionary=setup_clock(scene,true)
	ClassDB.class_call_static("NwnParticleClock","publish_fields",custom.slot,"constant",0.125,1,true)
	var handler:=GDScript.new();handler.source_code="extends NwnParticleClock\n@warning_ignore(\"native_method_override\")\nfunc sample() -> Dictionary:\n\tset_meta(\"calls\",int(get_meta(\"calls\",0))+1)\n\treturn {\"clip\":\"constant\",\"time\":0.25,\"serial\":9}\n"
	check(handler.reload()==OK,"Actual script clock handler compiles")
	custom.slot.set_script(handler)
	var output: Dictionary=custom.presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(8201000,false),"profile":true})
	check(not output.has("error") and int(custom.slot.get_meta("calls",0))==1 and int(output.get("phases",{}).get("count_particle_native_clock_direct",0))==0,"Attached script sample executes exactly once through opaque callback")
	# Static producer publication is authoritative even with a consumer script.
	check(bool(ClassDB.class_call_static("NwnParticleClock","publish_fields",custom.slot,"linear",0.987654321123,5,true)),"Consumer script cannot intercept canonical field publication")
	custom.slot.set_script(null)
	check(custom.slot.sample()=={"clip":"linear","time":0.987654321123,"serial":5},"Removing handler reveals current exact published data")
	rows.append(custom)
	for row: Dictionary in rows:row.presentation.call("dispatch",5,{});row.providers.clear();row.owner=null;row.presentation=null;row.slot=null
	rows.clear();custom.clear();handler=null;scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"gpu_execution":false,"scope":"Exact native published clock vs original callback: double time, clips/serials, detached samples, sampled particle state/geometry/RNG, disabled replacement, unknown/malformed/freed producer and attached consumer script. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
