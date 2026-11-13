extends "res://tests/native_particle_resident_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var cases:=0
	for row in original("native-emitter-bucket-v1",384):
		var scene:=Node3D.new(); root.add_child(scene)
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
		var sources: Dictionary={}; var id_to_index: Dictionary={}; var index_to_id: Dictionary={}; var nodes: Array[Node3D]=[]; var owners: Array[RefCounted]=[]
		var c: Dictionary=row.input
		for index_value in row.registration_order:
			var index:=int(index_value); var group: int=index%4 if c.shared_sources else index
			var position:=[M.f((float((group*17)%97)-48)/8),M.f((group%3-1)*0.5),0.0]
			var pose_node:=Node3D.new(); scene.add_child(pose_node); pose_node.position=Vector3(position[0],position[2],-position[1]); nodes.append(pose_node)
			var has_source:=index%5!=0; var source: Node3D=pose_node
			if has_source:
				if not sources.has(group):
					var value:=Node3D.new(); scene.add_child(value); value.position=pose_node.position; sources[group]=value
				source=sources[group]
			var initial:=make_owner(false,"fountain",0,false,false)
			var count:=index%3
			if row.updates.any(func(update):return int(update.id)==index): count=0 if index%4==0 else 2
			var particles: Array=[]
			for part in count: particles.append({"position10":position.duplicate(),"trail64":position.duplicate(),"quaternion34":[1.0,0.0,0.0,0.0],"direction4c":[0.0,0.0,1.0],"rotation1c":0.0,"age":0.0,"field48":0.0,"frame44":0,"stopped70":0,"inheritedSpeed20":0.0,"inheritedDirection24":[0.0,0.0,0.0],"velocity58":[0.0,0.0,0.0]})
			initial.state.birthRate=0.0; initial.state.lifeExp=1.0; initial.state.renderMode1a8=0; initial.state.active188={"records":particles,"capacity":count}
			if has_source and c.faded and group%3==1: initial.state.source50.instance={"fade":0.5,"height50":0.0,"opacity70":1.0}
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=owner.call("dispatch",0,{"state":initial.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose_node.get_instance_id(),"sourceId":source.get_instance_id()},{})
			check(not configured.has("error"),"Original bucket typed owner configures "+str(cases)+"/"+str(index))
			var added: Dictionary=presentation.call("dispatch",0,{"id":pose_node.get_instance_id(),"owner":owner,"providers":{},"source_flags":0,"source_key":group+1 if has_source else 0,"source_animating":group%2==1,"node_order":(index*13)%37-18,"culling":true,"original_admission":true,"admission_radius":0.25})
			check(not added.has("error"),"Original bucket native presentation registration "+str(cases)+"/"+str(index))
			id_to_index[pose_node.get_instance_id()]=index; index_to_id[index]=pose_node.get_instance_id(); owners.append(owner); initial.providers.clear()
		var planes:=PackedFloat32Array([1,0,0,5,-1,0,0,5,0,0,-1,5,0,0,1,5,0,1,0,5,0,-1,0,5])
		var view:={"stamp":10000000+cases,"position":c.camera,"camera":[1.0,0.0,0.0,0.0],"planes":planes.to_byte_array()}
		var result: Dictionary=presentation.call("dispatch",1,{"delta":0.0,"view":view,"initial_reject_plane":int(c.last_plane),"animating":bool(c.animating)})
		check(not result.has("error"),"Original admission/sort native frame "+str(cases)+" "+str(result.get("error","")))
		if result.has("error"): presentation.call("dispatch",5,{}); scene.free(); break
		var actual: Dictionary=presentation.call("dispatch",2,{})
		var admitted: Array=actual.emitters.filter(func(entry):return not entry.culled).map(func(entry):return id_to_index[int(entry.id)])
		var drawing: Array=actual.ranges.map(func(range_data):return id_to_index[int(range_data.id)])
		var updated: Array=actual.emitters.filter(func(entry):return entry.updated).map(func(entry):return id_to_index[int(entry.id)])
		check(same(admitted,row.admitted).is_empty(),"Exact original admitted list "+str(cases))
		check(same(updated,row.updates.map(func(update):return int(update.id))).is_empty(),"Exact original scene/source animation and fade update eligibility "+str(cases))
		check(same(drawing,row.render_handlers).is_empty(),"Exact original partial-comparator sort including equal-distance/null-source ties "+str(cases)+" "+str(drawing)+" vs "+str(row.render_handlers))
		for range_data: Dictionary in actual.ranges:
			var index: int=id_to_index[int(range_data.id)]
			check(M.f(range_data.distance)==M.f(row.distances[str(index)]),"Exact original cached squared distance "+str(cases)+"/"+str(index))
		presentation.call("dispatch",5,{}); presentation=null; owners.clear(); nodes.clear(); sources.clear(); scene.free(); cases+=1
		if not failures.is_empty(): break
	check(cases==384,"All original admission/sort cases reached the scene presentation candidate")
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"network_connections":0,"gpu_execution":false,"scope":"Native presentation admission and exact draw order compared with 384 original-instruction captures, using their post-update live counts. Includes original cached radius, source/null-source tie behavior, native squared distances, shuffled registration and empty lists. Concrete update eligibility has a separate original oracle; no GPU or FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
