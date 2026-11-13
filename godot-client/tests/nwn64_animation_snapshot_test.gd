extends "res://tests/native_particle_presentation_test.gd"
# Exact private oracle for the frame-local animation input snapshot.

func make_group(scene: Node3D, snapshot: bool, mutate_input: bool=false) -> Dictionary:
	var holder:=Node3D.new();scene.add_child(holder)
	var source:=Node3D.new();holder.add_child(source)
	var rng:=Random.new();rng.seed_value(1771)
	var events: Array=[]
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var owners: Array=[]
	var poses: Array=[]
	var input: Dictionary={}
	for index in 4:
		var pose:=Node3D.new();holder.add_child(pose);poses.append(pose)
		var emitter:=Node3D.new();pose.add_child(emitter)
		var kind: String="explosion" if index==0 else "fountain"
		var seed:=make_owner(false,kind,32|128,false,false)
		seed.state.birthRate=120.0 if index>0 else 0.0
		seed.state.lifeExp=1.0;seed.state.velocity=0.0;seed.state.randomVelocity=0.0;seed.state.spread=0.0
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()}, {})
		check(not configured.has("error"),"Configure "+str(index)+": "+str(configured.get("error","")))
		owners.append(owner)
		var providers:={"random":func():events.append(["random",index]);source.position.y+=0.001;return rng.next(),"cosineDouble":func(angle):return cos(angle)}
		var entry:={"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"source_flags":0,"culling":false,"clip":""}
		if index==0:
			entry.clock=func():
				events.append(["clock",index]);source.position.x+=0.125
				if mutate_input:input.animating=true
				return {"clip":"","time":0.25}
		var added: Dictionary=presentation.call("dispatch",0,entry)
		check(not added.has("error"),"Register "+str(index)+": "+str(added.get("error","")))
		seed.providers.clear()
	return {"holder":holder,"source":source,"rng":rng,"events":events,"presentation":presentation,"owners":owners,"poses":poses,"snapshot":snapshot,"input":input}

func frame(group: Dictionary, number: int, animating: bool) -> Dictionary:
	group.events.clear()
	group.source.position=Vector3(sin(number*0.02),0.25,cos(number*0.015))
	for index in group.poses.size():group.poses[index].position=Vector3(index*0.1,0.05,0)
	var input: Dictionary=group.input
	input.clear();input.delta=1.0/30.0;input.view=view_packet(number+8800000,false);input.animating=animating
	if group.snapshot:input.animation_snapshot=true
	return group.presentation.call("dispatch",1,input)

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var groups: Array=[make_group(scene,false),make_group(scene,true)]
	var reads:=0;var prepared:=0
	for number in 32:
		var outputs: Array=[];var packets: Array=[]
		for group: Dictionary in groups:
			var result:=frame(group,number,number%4!=0)
			check(not result.has("error"),"Frame "+str(number)+": "+str(result.get("error","")))
			outputs.append(result);packets.append(group.presentation.call("dispatch",2,{}))
		if outputs.any(func(value):return value.has("error")):break
		for field in ["prepared","active","vertices","culled","draws"]:
			check(outputs[0].get(field)==outputs[1].get(field),"Exact shared output "+field+"/"+str(number))
		check(packets[0].buffer==packets[1].buffer,"Exact packet bytes "+str(number))
		check(groups[0].events==groups[1].events,"Clock and RNG callback order "+str(number))
		check(groups[0].rng.state==groups[1].rng.state and groups[0].rng.draws==groups[1].rng.draws,"Exact RNG "+str(number))
		check(groups[0].source.global_transform==groups[1].source.global_transform,"Exact source mutation "+str(number))
		for index in 4:
			var a: Dictionary=without_ids(groups[0].owners[index].call("dispatch",2,{},{}))
			var b: Dictionary=without_ids(groups[1].owners[index].call("dispatch",2,{},{}))
			check(same(a,b).is_empty(),"Exact emitter state "+str(number)+"/"+str(index))
		reads+=int(outputs[1].get("animation_snapshot_reads",0));prepared+=int(outputs[1].get("animation_snapshot_prepared",0))
	check(reads==32 and prepared==128,"One animation input read per opted-in frame")
	var empty: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var empty_result: Dictionary=empty.call("dispatch",1,{"delta":1.0/30.0,"view":view_packet(9000000,false),"animating":true,"animation_snapshot":true})
	check(not empty_result.has("error") and int(empty_result.get("prepared",-1))==0,"Empty opted-in frame remains valid")
	check(int(empty_result.get("animation_snapshot_reads",-1))==0,"Empty opted-in frame skips the input read")
	empty.call("dispatch",5,{})
	var mutating: Dictionary=make_group(scene,false,true)
	var mutated: Dictionary=frame(mutating,100,false)
	check(not mutated.has("error"),"Mutable-input default frame")
	check(mutating.input.animating and int(mutated.get("active",0))>0,"Default route observes clock mutation before later sources")
	for group: Dictionary in groups+[mutating]:
		group.presentation.call("dispatch",5,{})
		group.holder.free()
	scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"frames":32,"snapshot_reads":reads,"snapshot_prepared":prepared,"mutable_default_active":int(mutated.get("active",-1)),"scope":"Private exact source/state/packet/RNG and callback-order oracle. Opt-in contract uses immutable frame-local input; default route observes a mid-frame input mutation. No renderer or FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"reads":reads,"prepared":prepared}));quit(0 if failures.is_empty() else 1)
