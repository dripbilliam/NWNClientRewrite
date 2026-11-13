extends "res://tests/native_particle_typed_pose_test.gd"
func simple_owner(node: Node3D) -> RefCounted:
	var seed_owner:=make_owner(false,"single",0,false,false)
	seed_owner.state.birthRate=1.0; seed_owner.state.velocity=0.0; seed_owner.state.randomVelocity=0.0; seed_owner.state.mass=0.0; seed_owner.state.renderMode1a8=0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var result: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{})
	check(not result.has("error"),"Private native owner configures")
	seed_owner.providers.clear(); return owner
func controls_and_lifetime() -> void:
	var scene:=Node3D.new(); root.add_child(scene); var a:=Node3D.new(); var b:=Node3D.new(); scene.add_child(a); scene.add_child(b)
	var owner:=simple_owner(a); var retained: WeakRef=weakref(owner)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var context:={"rejects":0}
	var callbacks:={"random":func():
		if presentation.call("dispatch",5,{}).has("error"): context.rejects+=1
		return 1,"cosineDouble":func(value):return cos(value)}
	check(not presentation.call("dispatch",0,{"id":a.get_instance_id(),"owner":owner,"providers":callbacks,"culling":false}).has("error"),"Presentation retains its configured native owner")
	check(presentation.call("dispatch",0,{"id":b.get_instance_id(),"owner":owner,"providers":callbacks}).has("error"),"Two identities cannot share mutable particle owner state")
	check(presentation.call("dispatch",6,{"ids":[a.get_instance_id(),a.get_instance_id()]}).has("error"),"Incomplete or duplicate frame order is rejected")
	check(not presentation.call("dispatch",6,{"ids":[a.get_instance_id()]}).has("error"),"Valid explicit frame order remains available")
	owner=null; check(retained.get_ref()!=null,"Registry pointer remains alive through the retained engine reference")
	var patch:={"alphaStart":0.3}; presentation.call("dispatch",4,{"id":a.get_instance_id(),"patch":patch}); patch.alphaStart=0.9
	var result: Dictionary=presentation.call("dispatch",1,{"delta":1.0/60,"view":view_packet(999999,false)})
	check(not result.has("error") and result.vertices==6 and context.rejects>0,"Reentrant close is rejected while the complete scene update survives")
	var held: RefCounted=retained.get_ref(); check(M.f(held.call("dispatch",2,{},{}).alphaStart)==M.f(0.3),"Control publication owns an immutable deep-copied patch"); held=null
	var data: Dictionary=presentation.call("dispatch",2,{})
	var buffer: PackedByteArray=data.buffer; var original_bytes:=buffer.duplicate()
	var inspected_again: Dictionary=presentation.call("dispatch",2,{})
	inspected_again.buffer[0]=int(inspected_again.buffer[0])^255
	check(presentation.call("dispatch",2,{}).buffer==original_bytes,"Mutating an inspected packet cannot alter native retained frame data")
	presentation.call("dispatch",4,{"id":a.get_instance_id(),"patch":{"renderMode1a8":9}})
	check(presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(1000003,false)}).has("error"),"Unsupported geometry rejects the incomplete frame packet")
	check(presentation.call("dispatch",7,{}).vertices==0,"Geometry failure cannot publish a partially written shared frame")
	presentation.call("dispatch",4,{"id":a.get_instance_id(),"patch":{"renderMode1a8":0}})
	check(not presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(1000004,false)}).has("error"),"A new valid frame can recover after geometry failure")
	held=retained.get_ref()
	var normal: Dictionary=held.call("dispatch",6,{"factor":1.0,"camera":[1.0,0.0,0.0,0.0],"tint":[1.0,1.0,1.0],"capacity":0},{})
	check(not normal.has("error") and normal.has("positions"),"Failed direct geometry restores the original surface writer before the next diagnostic"); held=null
	var bad_view:=view_packet(1000000,false); bad_view.planes=PackedByteArray([1,2,3])
	check(presentation.call("dispatch",1,{"delta":0.1,"view":bad_view}).has("error"),"Malformed camera publication fails before particle processing")
	check(presentation.call("dispatch",7,{}).vertices==0,"An unsuccessful scene frame cannot replay stale geometry")
	check(not presentation.call("dispatch",1,{"delta":1.0/60,"view":view_packet(1000001,false)}).has("error"),"A valid frame can follow a rejected common input")
	var id:=a.get_instance_id(); a.free()
	result=presentation.call("dispatch",1,{"delta":1.0/60,"view":view_packet(1000002,false)})
	check(not result.has("error") and result.prepared==0 and result.vertices==0,"Freed emitter identity is skipped without dereferencing its stale native pose")
	presentation.call("dispatch",3,{"id":id}); check(retained.get_ref()==null,"Removal releases the last private native owner reference")
	presentation.call("dispatch",5,{}); check(presentation.call("dispatch",7,{}).registered==0,"Close clears all scene membership")
	check(presentation.call("dispatch",0,{"id":b.get_instance_id(),"owner":null,"providers":{}}).has("error"),"Closed presentation rejects late registration")
	check(buffer==original_bytes,"Scene cancellation/removal/close preserve previously published packet bytes")
	callbacks.clear(); presentation=null; scene.free()
func density_storage() -> Dictionary:
	var scene:=Node3D.new(); root.add_child(scene)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var callbacks:={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	var count:=1506
	for index in count:
		var node:=Node3D.new(); scene.add_child(node); node.position=Vector3((index%41-20)*0.8,0.1,(int(index/41)-18)*0.8)
		var owner:=simple_owner(node)
		var added: Dictionary=presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":callbacks,"culling":false})
		check(not added.has("error"),"Dense native typed owner registers "+str(index))
	var last: Dictionary={}; var retained: PackedByteArray; var original_bytes: PackedByteArray; var layout: Dictionary={}
	for frame in 6:
		last=presentation.call("dispatch",1,{"delta":1.0/60,"view":view_packet(frame+2000000,false)})
		check(not last.has("error") and int(last.active)==count and int(last.vertices)==count*6 and int(last.bytes)==count*6*24 and int(last.draws)==count,"All dense effects remain in the exact-size active-only frame "+str(frame))
		if last.has("error"): break
		var snapshot: Dictionary=presentation.call("dispatch",2,{})
		layout=snapshot.native_layout_bytes
		for entry: Dictionary in snapshot.emitters: check(entry.legacy_position_bytes==0 and entry.legacy_attribute_bytes==0,"No dense owner allocates legacy capacity buffers "+str(frame)+"/"+str(entry.id))
		if frame==0: retained=snapshot.buffer; original_bytes=retained.duplicate()
		else: check(retained==original_bytes,"Dense later frames preserve the first frame's immutable storage "+str(frame))
	presentation.call("dispatch",5,{}); presentation=null; callbacks.clear(); scene.free()
	return {"emitters":count,"last":last,"native_layout_bytes":layout,"active_packet_bytes":count*6*24,"previous_minimum_capacity_stream_bytes":count*96*24,"scope":"Byte storage/correctness only. Layouts are sizeof values, excluding dynamic allocations, Godot objects and GPU resources; no whole-frame FPS or process-memory improvement claim."}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	controls_and_lifetime(); var storage:=density_storage()
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"storage":storage,"network_connections":0,"gpu_execution":false,"scope":"Native presentation ownership, controls, reentrancy, invalid camera recovery, freed identities and immutable packet lifetime; 1506 actual native typed owners retained across six complete CPU-only frames. No graphical draw or performance acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
