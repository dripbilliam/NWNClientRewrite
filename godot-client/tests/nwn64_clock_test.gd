extends "res://tests/nwn64_typed_pose_test.gd"
class ModelEntry:
	extends RefCounted
	var models: Array=[]
# Same-process parity against an unrecognized wrapper of the original getter.
# The isolated materializer supplies a minimal canonical-path clock script.
func reference_clock(clock: Node,id: int,index: int) -> Dictionary:
	return clock.call("playback_state",id,index)
func packet_bytes(presentation: RefCounted) -> PackedByteArray:
	return presentation.call("dispatch",2,{}).get("buffer",PackedByteArray())
func models_at(time: Variant,clip: Variant="linear",serial: Variant=1) -> Array:
	var out: Array=[]
	for index in 7:out.append({"clip":clip,"last_time":time,"play_serial":serial})
	return out
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	check(Kernel.available(),"Private native kernel loads")
	var canonical: GDScript=load("res://systems/model_rigs.gd")
	var original_source: String=canonical.source_code
	var scene:=Node3D.new();root.add_child(scene)
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	var clocks: Array=[];var presentations: Array=[];var owners: Array=[[],[]];var callbacks: Array=[[],[]];var nodes: Array=[];var rngs: Array=[]
	var mutation: Array=[{"pending":false,"calls":0},{"pending":false,"calls":0}]
	for index in 7:
		var node:=Node3D.new();scene.add_child(node);nodes.append(node)
	for lane in 2:
		var clock: Node=canonical.new();scene.add_child(clock);clock.set("entities",{7:{"models":models_at(0.0)}});clocks.append(clock)
		var rng:=Random.new();rng.seed_value(321);rngs.append(rng)
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation");presentations.append(presentation)
		presentation.call("dispatch",15,{"enabled":false,"setup_boundary":OS.get_cmdline_user_args().has("--particle-setup-boundary=bound")})
		for index in 7:
			var kind: String=["single","fountain","explosion"][index%3]
			var seed_owner:=make_owner(false,kind,32,false,false);seed_owner.state.renderMode1a8=index
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var config:={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":nodes[index].get_instance_id(),"sourceId":nodes[index].get_instance_id(),"clips":channels.clips}
			check(not owner.call("dispatch",0,config,{}).has("error"),"Clock comparison owner configures "+str(lane)+"/"+str(index));owners[lane].append(owner)
			var services:={"random":func():
				if mutation[lane].pending:
					mutation[lane].pending=false;mutation[lane].calls+=1
					# A service from the previous source replaces the complete table.
					clock.set("entities",{7:{"models":models_at(0.9)}})
				return rng.next(),"cosineDouble":func(angle):return cos(angle)}
			callbacks[lane].append(services)
			var callable: Callable=Callable(self,"reference_clock").bind(clock,7,index) if lane==0 else Callable(clock,"playback_state").bind(7,index)
			check(not presentation.call("dispatch",0,{"id":nodes[index].get_instance_id(),"owner":owner,"providers":services,"clock":callable,"source_flags":0,"culling":true}).has("error"),"Clock source registers "+str(lane)+"/"+str(index));seed_owner.providers.clear()
	var expect_native: bool=args.get("expect-native","")=="on"
	var initial: Dictionary=presentations[1].call("dispatch",16,{})
	check(int(initial.get("native_clock_bindings",0))==(7 if expect_native else 0),"Canonical-path direct getter recognition is explicit")
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	var cases: Array=[];var invalidated:=0;var unsupported:=0
	for frame in 90:
		var time: Variant=fmod(frame/30.0,1.0);var clip: Variant=["linear","constant","bezier","empty","missing"][int(frame/3)%5];var serial: Variant=frame
		if frame==5:time=1
		if frame==6:clip=StringName("linear")
		if frame==7:time="0.5";unsupported+=1
		if frame==8:clip=17;unsupported+=1
		if frame==9:serial="12";unsupported+=1
		for lane in 2:clocks[lane].set("entities",{7:{"models":models_at(time,clip,serial)}})
		if frame==10:
			for clock in clocks:clock.set("entities",{})
		if frame==11:
			for clock in clocks:clock.set("entities",{7:{"models":[]}})
		if frame==12:
			for clock in clocks:clock.set("entities",{7:{"models":[{},{},{},{},{},{},{}]}})
		if frame==13:
			for lane in 2:
				mutation[lane].pending=true;clocks[lane].set("entities",{7:{"models":models_at(0.1)}})
				presentations[lane].call("dispatch",4,{"id":nodes[1].get_instance_id(),"patch":{"birthRate":120.0}})
		if frame==14:
			for clock in clocks:
				var object_entry:=ModelEntry.new();object_entry.models=models_at(0.8);clock.set("entities",{7:object_entry})
			unsupported+=1
		if frame==20:
			# Source changes before recompilation must decline the bound proof too.
			canonical.source_code=original_source+"\n# changed source at a frame boundary\n";invalidated+=1
		if frame==21:
			check(canonical.reload(true)==OK,"Same-resource source reload succeeds");invalidated+=1
		if frame==22:
			canonical.source_code=original_source;check(canonical.reload(true)==OK,"Canonical source restores without stale model values")
		if frame==30:
			# Replacing owner scripts preserves Callable dispatch but invalidates identity.
			var replacement:=GDScript.new();replacement.source_code=original_source.replace('"time":float(model.get("last_time",0.0))','"time":float(model.get("last_time",0.0))+0.125')
			check(replacement.reload()==OK,"Replacement playback script compiles")
			for clock in clocks:clock.set_script(replacement);clock.set("entities",{7:{"models":models_at(0.25)}})
			invalidated+=1
		if frame==32:
			for clock in clocks:clock.set_script(canonical);clock.set("entities",{7:{"models":models_at(0.5)}})
		if frame==40:
			var derived:=GDScript.new();derived.source_code='extends "res://systems/model_rigs.gd"\n';check(derived.reload()==OK,"Derived clock compiles")
			for lane in 2:
				clocks[lane].set_script(derived);clocks[lane].set("entities",{7:{"models":models_at(0.75)}})
				for index in 7:
					var callable: Callable=Callable(self,"reference_clock").bind(clocks[lane],7,index) if lane==0 else Callable(clocks[lane],"playback_state").bind(7,index)
					presentations[lane].call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":callable})
			check(int(presentations[1].call("dispatch",16,{}).get("native_clock_bindings",0))==0,"Derived scripts retain original getter path")
		if frame==42:
			for lane in 2:
				clocks[lane].set_script(canonical);clocks[lane].set("entities",{7:{"models":models_at(0.5)}})
				for index in 7:
					var callable: Callable=Callable(self,"reference_clock").bind(clocks[lane],7,index) if lane==0 else Callable(clocks[lane],"playback_state").bind(7,index)
					presentations[lane].call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":callable})
		if frame==50:
			for lane in 2:
				for index in 7:
					var callable: Callable=Callable(self,"reference_clock").bind(clocks[lane],7,-1) if lane==0 else Callable(clocks[lane],"playback_state").bind(7,-1)
					presentations[lane].call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":callable})
		if frame==51:
			for lane in 2:
				for index in 7:
					var callable: Callable=Callable(self,"reference_clock").bind(clocks[lane],7,index) if lane==0 else Callable(clocks[lane],"playback_state").bind(7,index)
					presentations[lane].call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":callable})
		if frame==60:
			# Freed clock nodes must not be retained by a native recognition proof.
			for lane in 2:
				for index in 7:presentations[lane].call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":Callable(clocks[lane],"playback_state").bind(7,index)})
				clocks[lane].free()
			check(not is_instance_valid(clocks[0]) and not is_instance_valid(clocks[1]),"Clock proof never retains a Node owner")
		for lane in 2:
			var result: Dictionary=presentations[lane].call("dispatch",1,{"delta":1.0/60.0,"view":view_packet(frame+17000000,frame%20==19),"profile":false,"native_surface_output":true,"detonate":frame%7==0})
			check(not result.has("error"),"Clock parity shared frame "+str(lane)+"/"+str(frame)+" "+str(result.get("error","")))
			check(not result.has("phases"),"Normal correctness input leaves phase instrumentation off")
		if frame==60:break
		var difference:=same(without_ids(owners[0][0].call("dispatch",2,{},{})),without_ids(owners[1][0].call("dispatch",2,{},{})))
		check(difference.is_empty(),"Clock result preserves sampled controller/state "+str(frame)+" "+difference)
		for index in range(1,7):check(same(without_ids(owners[0][index].call("dispatch",2,{},{})),without_ids(owners[1][index].call("dispatch",2,{},{}))).is_empty(),"All modes retain state "+str(frame)+"/"+str(index))
		var bytes:=packet_bytes(presentations[0]);check(bytes==packet_bytes(presentations[1]),"Shared geometry bytes match original Callable "+str(frame))
		if not bytes.is_empty():digest.update(bytes)
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"RNG order matches original Callable "+str(frame))
		cases.append(frame)
		if not failures.is_empty():break
	var final: Dictionary=presentations[1].call("dispatch",16,{})
	check(not expect_native or int(final.get("native_clock_reads",0))>200,"Native clock path demonstrably executes")
	check(not expect_native or int(final.get("native_clock_fallbacks",0))>=unsupported+invalidated,"Unsupported shapes, replacement and reload execute unchanged fallback")
	check(mutation[0].calls==1 and mutation[1].calls==1,"Previous-source RNG service replaced live clock table at original observation boundary")
	for presentation in presentations:presentation.call("dispatch",5,{})
	for lane in callbacks:
		for value in lane:value.clear()
	owners.clear();presentations.clear();callbacks.clear();clocks.clear();scene.free();canonical.source_code=original_source;canonical.reload(true);await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"frames":cases.size(),"digest":digest.finish().hex_encode(),"initial_clock_diagnostics":initial,"final_clock_diagnostics":final,"rng_draws":rngs[0].draws,"source_order_mutations":mutation,"scope":"Isolated canonical-path getter with original Callable wrapper parity for shared packet bytes, cold state, seven modes/three families, missing/default/conversion fields, source changes and reload, script replacement/inheritance, per-source RNG-service mutation and retired Node lifetime. No renderer/FPS measurement."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_CLOCK ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
