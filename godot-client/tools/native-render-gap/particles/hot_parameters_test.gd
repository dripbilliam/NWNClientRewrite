extends "res://tests/native_render_gap_scene_boundary_callbacks_test.gd"

func channel(property: String,value: float) -> Dictionary:
	return {"property":property,"components":1,"controller":{"rows4":1,"timeIndex6":0,"valueIndex8":1,"columnsA":1},"storage":{"values88":PackedFloat32Array([0.0,value])}}

func make_bound_owner(pose: Node3D,parameters: Dictionary,bound: bool) -> RefCounted:
	var seed: Dictionary=make_owner(false,"fountain",0,false,false)
	var clips: Dictionary={"create_mid":{"channels":[channel("sizemid",4.0)]},"change_mid":{"channels":[channel("sizemid",8.0)]},"create_y":{"channels":[channel("sizemid_y",6.0)]},"rehash":{"channels":[]}}
	for index: int in 256:clips.rehash.channels.append(channel("binding_oracle_"+str(index),float(index)))
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,0x3f800001)
	clips.create_detonate={"channels":[channel("detonate",bytes.decode_float(0))]}
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"parameters":parameters,"clips":clips,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":pose.get_instance_id(),"bindHotParameters":bound},{})
	check(not configured.has("error"),"Actual hot-field owner configures "+str(bound)+" "+str(configured.get("error","")))
	check(bool(owner.call("dispatch",9,{},{}).enabled)==bound,"Per-owner binding selection is observed")
	seed.providers.clear();return owner

func radius(owner: RefCounted) -> Dictionary:
	return owner.call("dispatch",5,{"source_flags":0,"wind":[0.0,0.0,0.0]},{})

func compare(owners: Array[RefCounted],message: String) -> void:
	check(var_to_bytes(radius(owners[0]))==var_to_bytes(radius(owners[1])),"Radius/error bytes match "+message)
	check(var_to_bytes(owners[0].call("dispatch",3,{},{}))==var_to_bytes(owners[1].call("dispatch",3,{},{})),"Parameter keys and values match "+message)

func actual_owners() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var parameters: Dictionary={}
	var owners: Array[RefCounted]=[make_bound_owner(scene,parameters,false),make_bound_owner(scene,parameters,true)]
	compare(owners,"initial missing fields")
	for owner: RefCounted in owners:
		var keys: Dictionary=owner.call("dispatch",3,{},{})
		check(not keys.has("sizemid") and not keys.has("sizemid_y") and not keys.has("detonate"),"Reading missing fields preserves exposed key set")
	for clip: String in ["create_mid","change_mid","create_y","rehash"]:
		for owner: RefCounted in owners:
			check(not owner.call("dispatch",4,{"clip":clip,"time":0.0},{}).has("error"),"Original channel mutator samples "+clip)
		compare(owners,clip)
	parameters.sizemid=9000.0
	compare(owners,"external source Dictionary mutation remains private-import isolated")
	for owner: RefCounted in owners:
		var before: Dictionary=radius(owner)
		check(str(owner.call("dispatch",0,{},{}).get("error","")).contains("already configured"),"Reconfiguration rejects before mutating current bindings")
		check(var_to_bytes(before)==var_to_bytes(radius(owner)),"Rejected reconfiguration leaves live parameter values unchanged")
	var presenters: Array[RefCounted]=[]
	for owner: RefCounted in owners:
		check(not owner.call("dispatch",4,{"clip":"create_detonate","time":0.0},{}).has("error"),"Original channel inserts detonate after a prior miss")
		var current: Dictionary=owner.call("dispatch",3,{},{})
		check(current.has("detonate") and int(current.detonate)==1,"Controller publishes a nonzero inserted detonate")
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation");presenters.append(presentation)
		check(not presentation.call("dispatch",0,{"id":scene.get_instance_id(),"owner":owner,"providers":{},"culling":false}).has("error"),"Actual shared fast path registers")
		var frame: Dictionary=presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(21000000,false)})
		check(not frame.has("error") and frame.prepared==1,"Shared Step consumes the inserted detonate")
		check(int(owner.call("dispatch",3,{},{}).detonate)==0,"Consumed parameter resets at the original boundary")
	compare(owners,"shared detonate consumption")
	var stats: Dictionary=owners[1].call("dispatch",9,{},{})
	check(stats.fields.size()==3,"Only the three intended fields are bound")
	var hits:=0;var rebinds:=0
	for row: Dictionary in stats.fields:hits+=int(row.hits);rebinds+=int(row.rebinds)
	check(hits>0 and rebinds>=5,"Actual cache reuse and late-insert/rehash refreshes are witnessed")
	var foreign: RefCounted=make_bound_owner(scene,{"sizemid":2.0,"sizemid_y":9.0},true)
	check(var_to_bytes(radius(foreign))!=var_to_bytes(radius(owners[1])),"Separate actual owner has its own field locations")
	foreign=null
	for presentation: RefCounted in presenters:presentation.call("dispatch",5,{})
	presenters.clear();owners.clear()
	# NIL is present, and must still reach the old numeric error rather than
	# becoming the missing-field default. Include all three hot fields.
	for key: String in ["sizemid","sizemid_y","detonate"]:
		var nil_parameters: Dictionary={};nil_parameters[key]=null
		var pair: Array[RefCounted]=[make_bound_owner(scene,nil_parameters,false),make_bound_owner(scene,nil_parameters,true)]
		if key=="detonate":
			var errors: Array=[]
			for owner: RefCounted in pair:
				var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
				presentation.call("dispatch",0,{"id":scene.get_instance_id(),"owner":owner,"providers":{},"culling":false})
				errors.append(presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(21000010,false)}));presentation.call("dispatch",5,{})
			check(errors[0].has("error") and var_to_bytes(errors[0])==var_to_bytes(errors[1]),"Present NIL detonate keeps the same numeric failure")
		else:
			check(radius(pair[0]).has("error"),"Present NIL midpoint reaches numeric validation "+key);compare(pair,"present NIL "+key)
		pair.clear()
	scene.free()

func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var native: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var component: Dictionary=native.call("dispatch",19,{})
	check(component.success and component.checks>=15,"Native component adversarial cases pass")
	for row: Dictionary in component.cases:check(bool(row.success),"Native binding: "+str(row.message))
	native=null;actual_owners()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"component":component,"scope":"Actual private weak-container field bindings, channel insertion/overwrite/rehash, key presence, NIL errors, foreign owner, reconfiguration failure, generation retirement and engine-object lifetime"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
