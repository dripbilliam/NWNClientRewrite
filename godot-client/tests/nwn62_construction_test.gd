extends "res://tests/native_staged_model_publication_test.gd"
const Actor=preload("res://systems/native_render/actor_instance.gd")
const ActorBefore=preload("res://.cache/nwn62/before/systems/native_render/actor_instance.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Rigs=preload("res://systems/model_rigs.gd")
const RigsBefore=preload("res://.cache/nwn62/before/systems/model_rigs.gd")
const Bones=preload("res://systems/native_render/skeletal_rigs.gd")
const BonesBefore=preload("res://.cache/nwn62/before/systems/native_render/skeletal_rigs.gd")
func rig_metadata(ids: Array)->Dictionary:
	var rest:={"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}
	var asset:={"defaults":[rest],"clips":[{"name":"walk","length":1.0,"transition":0.0,"events":[{"time":0.0,"name":"zero"},{"time":0.25,"name":"quarter"}],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0.0,0.0,0.0]},{"time":1.0,"value":[1.0,0.0,0.0]}],"sourceInterpolation":"linear"}]}],"unsupported":[]}
	var entities: Array=[]
	for id in ids:entities.append({"id":id,"nodes":[{"name":"root","parent":-1,"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale}],"models":[{"asset":0,"parts":[0],"defaults":[rest],"clip":"walk","follow":true}],"clipMap":{"4":"walk"},"attachments":[]})
	return {"rigs":{"version":1,"assets":[asset],"entities":entities},"meshes":[]}
func rig_sample(rigs,ids: Array)->Array:
	var result: Array=[]
	for id in ids:
		var entry: Dictionary=rigs.entities[id]
		result.append({"part":rigs.node_at(id,0).transform,"clock":rigs.playback_state(id,0),"counts":entry.counts})
	return result
func rig_checks()->void:
	for bones in [false,true]:
		var first= BonesBefore.new() if bones else RigsBefore.new();var next= Bones.new() if bones else Rigs.new()
		root.add_child(first);root.add_child(next)
		var a:=Node3D.new();var b:=Node3D.new();root.add_child(a);root.add_child(b)
		var metadata:=rig_metadata([1,2]);var registry:={"meshes_by_name":{}}
		var old_events: Array=[];var new_events: Array=[];var visible_records: Array=[]
		first.model_event.connect(func(id,index,name,serial):old_events.append([id,index,name,serial]))
		next.model_event.connect(func(id,index,name,serial):new_events.append([id,index,name,serial]);visible_records.append(next.entities.size()))
		first.configure(registry,{1:a,2:a},metadata);first.set_process(false)
		check(next.begin_configure(registry,{1:b,2:b},metadata),"Rig staged configure begins "+str(bones))
		var result: Dictionary={};var turns:=0
		while turns<128:
			result=next.configure_step(1,1);turns+=1
			check(int(result.units)<=1,"Rig step respects one-unit cap")
			if result.status!="pending":break
			check(next.entities.is_empty() and new_events.is_empty(),"No partial entity registry or initial event escapes a yield")
		next.set_process(false)
		check(result.status=="ready" and rig_sample(first,[1,2])==rig_sample(next,[1,2]),"Frozen original rig initial transforms/clocks/counters match "+str(bones))
		check(old_events==new_events and visible_records.all(func(count):return count==2),"Initial events retain complete multi-entity observation boundary")
		for frame in 12:first._update(0.125);next._update(0.125);check(rig_sample(first,[1,2])==rig_sample(next,[1,2]),"Original sampled animation/event clocks remain equal")
		check(old_events==new_events,"Original model event order and serials match")
		check(next.begin_configure(registry,{3:b},rig_metadata([3])),"Additional staged entity can start beside existing paused actors")
		next.configure_step(2,1);var pending: Node=next._configuration.entry.root;var weak:=weakref(pending);next.cancel_configure()
		check(weak.get_ref()==null and next.entities.size()==2 and rig_sample(first,[1,2])==rig_sample(next,[1,2]),"Cancel releases only pending rig and reverses only its construction counters")
		first.free();next.free();a.free();b.free()
func actor_input()->Dictionary:
	var input:=bundle("b");input.value.rig_asset=ActorData.new().rig_asset(input.value);return input
func actor_sample(actor)->Dictionary:
	var parts: Array=[]
	for row in actor.impact_parts:
		var node: Node3D=actor.rigs.node_at(actor.object_id,int(row.index));parts.append([row,node.transform,node.get_meta("native_mesh_source",{})])
	var mesh_rows: Array=[]
	for mesh in actor.meshes:mesh_rows.append([str(actor.get_path_to(mesh)),mesh.transform,mesh.mesh,mesh.material_override,mesh.cast_shadow,mesh.get_meta("native_mesh_source",{})])
	return {"parts":parts,"meshes":mesh_rows,"models":actor.model_names,"impact":actor.impact_lookup,"references":actor.reference_graphs.map(func(graph):return graph.rows.size() if graph!=null else 0),"snapshot":actor.snapshot()}
func actor_checks()->void:
	var input:=actor_input();var pieces: Array=[{"bundle":input,"initial_clip":"","follow":true}]
	for bones in [false,true]:
		var pool:=Pool.new();var first:=ActorBefore.new();first.use_skeleton=bones
		var next:=Actor.new();next.use_skeleton=bones
		check(first.install(pieces,pool,7,{}),"Frozen actor installs "+str(bones))
		check(next.begin_install(pieces,pool,7,{}),"Actor cooperative install begins "+str(bones))
		var result: Dictionary={};var turns:=0
		while turns<512:
			result=next.install_step(1,1);turns+=1
			check(int(result.units)<=1,"Actor step keeps requested unit cap")
			if result.status!="pending":break
			check(not next.installation_complete,"Partial actor is not marked ready")
		check(result.status=="ready" and actor_sample(first)==actor_sample(next),"Actor parts, rigs, metadata, resources and helpers match exact synchronous source "+str(bones))
		first.free();next.free();pool.clear()
	for stop in [0,1,3,7,12,18]:
		var pool:=Pool.new();var actor:=Actor.new();actor.begin_install(pieces,pool,7,{})
		for turn in stop:
			if actor.installation_complete:break
			actor.install_step(1,1)
		actor.cancel_install();check(actor._actor_install.is_empty() and actor.rigs==null and actor.meshes.is_empty() and actor.get_child_count()==0,"Cancellation releases partial actor ownership at step "+str(stop))
		actor.free();pool.clear()
func off_tree_rig_release_checks()->void:
	for bones in [false,true]:
		var owner=Bones.new() if bones else Rigs.new();var parent:=Node3D.new();var mesh:=MeshInstance3D.new();mesh.name="borrowed";mesh.mesh=BoxMesh.new();parent.add_child(mesh)
		var metadata:=rig_metadata([9]);var rest: Dictionary=metadata.rigs.entities[0].nodes[0]
		metadata.meshes=[{"name":"borrowed","objectId":9,"rigNode":0,"rigLocal":{"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale}}]
		owner.begin_configure({"meshes_by_name":{"borrowed":mesh}},{9:parent},metadata)
		var steps:=0
		while mesh.get_parent()==parent and steps<32:owner.configure_step(1,0);steps+=1
		var pending_root=weakref(owner._configuration.entry.root)
		check(mesh.get_parent()!=parent and not owner.is_inside_tree(),"Off-tree pending rig borrows real external mesh before owner disposal")
		owner.free()
		check(pending_root.get_ref()==null and is_instance_valid(mesh) and mesh.get_parent()==parent and mesh.transform==Transform3D.IDENTITY,"Off-tree rig predelete restores borrowed external mesh and frees only pending graph "+str(bones))
		parent.free()
func large_placement_checks()->void:
	var input:=bundle("c")
	for index in 128:
		var row: Dictionary=input.value.nodes[0].duplicate(true);row.name="extra_"+str(index);row.parent=0;row.position=[index*0.001,0.0,0.0];input.value.nodes.append(row)
	var pool:=Pool.new();pool.cooperative_templates=true
	var old:=BeforeTemplate.new();var next:=Template.new()
	check(old.build(input,pool) and next.build(input,pool),"Large original PackedScene and known-node templates build")
	var original=old.create();var pending: Dictionary={};var first: Dictionary={};var turns:=0
	while turns<2048:
		first=next.create_step(pending,1,1);turns+=1
		check(int(first.get("units",0))<=1,"Large placement finalization respects unit cap")
		if first.status!="pending":break
		if pending.has("placement_job"):check(not pending.placement_job.placement.is_inside_tree(),"Partial placement stays detached through discovery/reference graph")
	check(first.status=="ready" and node_rows(first.instance.get_child(0))==node_rows(original.get_child(0)),"Large staged first placement matches exact PackedScene graph/resources/metadata")
	check(first.status=="ready" and first.instance.parts.size()==input.value.nodes.size() and first.instance.reference_graph.rows.size()==input.value.nodes.size(),"Complete large placement keeps every original physical/reference row")
	var second: Dictionary={};turns=0
	while turns<2048:
		second=next.create_step(pending,1,1);turns+=1
		check(int(second.get("units",0))<=1,"Large clone and placement share one unit allowance")
		if second.status!="pending":break
	check(second.status=="ready" and node_rows(second.instance.get_child(0))==node_rows(original.get_child(0)),"Later staged clone matches exact first PackedScene graph")
	if first.status=="ready":first.instance.free()
	if second.status=="ready":second.instance.free()
	for release in ["cancel","unref"]:
		turns=0
		while not pending.has("placement_job") and turns<2048:next.create_step(pending,1,0);turns+=1
		check(pending.has("placement_job"),"Large placement release reaches privately owned discovery job")
		var owned=weakref(pending.placement_job.placement)
		if release=="cancel":Template.cancel_creation(pending)
		else:pending.clear()
		check(owned.get_ref()==null,"Large partial PlacementJob releases its owned graph on "+release)
	original.free();Template.cancel_creation(pending);pool.clear()
func run()->void:
	rig_checks();actor_checks();off_tree_rig_release_checks();large_placement_checks();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Frozen pre-NWN62 synchronous rig/actor source versus one-unit construction, complete multi-entity initial-event boundary, exact transforms/clocks/resources/helpers and cancellation. Headless correctness only."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
