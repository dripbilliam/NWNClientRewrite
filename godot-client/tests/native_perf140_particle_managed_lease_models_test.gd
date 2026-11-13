extends "res://tests/native_particle_presentation_test.gd"
# Real installed MDL fields, hierarchy and controller storage; CPU state/geometry
# oracle only. Chunk scene services are deterministic boundary stand-ins, and
# this does not validate textures, child Gob visuals or a graphical game client.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Wind=preload("res://systems/native_render/scene_point_wind.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Leases=preload("res://systems/native_render/managed_particle_pose_leases.gd")
class Consumer:
	extends Node3D
	var native_owner: RefCounted
	var source: Node3D
var managed_hits:=0

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report):quit(2);return
	OS.set_environment("NWN_PARTICLE_POSE_LEASES","managed")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed native model catalog mounts read-only")
	var scene:=Node3D.new();root.add_child(scene)
	var rows: Array=[]
	for managed in [false,true]:
		var host:=Node3D.new();scene.add_child(host)
		var rng: RefCounted=ClassDB.instantiate("NwnVisualRandom");rng.seed_value(8221)
		host.set_meta("native_particle_random",rng)
		host.set_meta("native_particle_pose_lease_scope",Leases.create_scope(host))
		var wind:=Wind.new();host.add_child(wind);wind.set_process(false)
		check(wind.failure.is_empty() and wind.set_area({"e4":0}),"Installed-model fixture retains actual shared wind stream")
		rows.append({"host":host,"rng":rng,"wind":wind,"presentation":ClassDB.instantiate("NwnParticlePresentation"),"owners":[],"nodes":[],"providers":[],"events":[],"origins":[],"placements":[],"managed":managed})
	var observations: Array=[];var total_emitters:=0
	for name in ["it_torch_000","plc_cndl01","plc_x0_drt"]:
		var bytes:=catalog.get_resource(name,2002);check(not bytes.is_empty() and catalog.failure.is_empty(),"Actual installed MDL loads "+name)
		if bytes.is_empty():continue
		var parser:=ActorData.new();var model: Dictionary=parser.parse(bytes)
		check(parser.failure.is_empty() and not model.is_empty(),"Original model/controller data parses "+name)
		if model.is_empty():continue
		var rig: Dictionary=parser.rig_asset(model);var model_emitters:=0
		for row: Dictionary in rows:
			var placement:=Template.Placement.new();row.host.add_child(placement);row.placements.append(placement)
			var source:=Node3D.new();source.name=name;placement.add_child(source)
			var parts: Array=[];var rotation:=Quaternion(Vector3.RIGHT,-PI/2)
			for index in model.nodes.size():
				var original: Dictionary=model.nodes[index];var part:=Node3D.new()
				if int(original.parent)<0:source.add_child(part)
				else:parts[int(original.parent)].add_child(part)
				parts.append(part);part.position=Vector3(original.position[0],original.position[2],-original.position[1])
				var q:=Quaternion(original.orientation[0],original.orientation[1],original.orientation[2],original.orientation[3]);if q.length_squared()<1e-16:q=Quaternion.IDENTITY
				part.quaternion=rotation*q.normalized()*rotation.inverse();part.scale=Vector3.ONE*float(original.scale)
				if not original.has("emitter"):continue
				var parameters: Dictionary=original.emitter.duplicate(true);var kind:=str(parameters.get("update","")).to_lower()
				if kind not in ["fountain","explosion","single"] or (int(parameters.get("flags",0))&1)!=0:continue
				if row==rows[0]:model_emitters+=1
				var channels:=Channels.new();channels.configure(rig,index);check(channels.failure.is_empty(),"Original emitter channels compile "+name+"/"+str(index))
				var seed_owner:=make_owner(false,kind,int(parameters.get("flags",0)),false,false)
				seed_owner.state.merge({"chunkName":str(parameters.get("chunkname","")),"renderMode1a8":Emitter.MODES.get(str(parameters.get("render","Normal")),0),"blendMode68":0 if str(parameters.get("blend",""))=="Normal" else 2,"spawnType":int(parameters.get("spawntype",0)),"loop":int(parameters.get("loop",0)),"xGrid":int(parameters.get("xgrid",0)),"yGrid":int(parameters.get("ygrid",0))},true)
				var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
				check(not owner.call("dispatch",0,{"state":seed_owner.state,"parameters":parameters,"clips":channels.clips,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":part.get_instance_id(),"sourceId":source.get_instance_id()},{ }).has("error"),"Native actual-model owner configures "+name+"/"+str(index))
				seed_owner.providers.clear();row.owners.append(owner)
				var emitter:=Consumer.new();emitter.name="native_emitter";emitter.native_owner=owner;emitter.source=source;part.add_child(emitter);row.nodes.append(emitter)
				var providers: Dictionary=callbacks(row.rng,row.events,index);providers.random=row.rng.next
				if not str(parameters.get("chunkname","")).is_empty():providers.merge(chunks(row.events),true)
				row.providers.append(providers);row.origins.append(name)
				var clip:="pause" if channels.clips.has("pause") else "default" if channels.clips.has("default") else ""
				check(not row.presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"source_flags":int(model.get("classification_flags",0)),"clip":clip,"clip_length":float(channels.clips.get(clip,{}).get("length",0.0)),"wind_token":row.wind.token,"culling":true}).has("error"),"Actual-model emitter joins shared owner")
			placement.parts=parts
			if row.managed:placement.grant_particle_pose_lease(Leases.scope_for(row.host))
		observations.append({"name":name,"sha256":Cache.digest(bytes),"physical_nodes":model.nodes.size(),"supported_emitters":model_emitters})
		total_emitters+=model_emitters
	check(total_emitters>=4,"Multiple real model emitter/controller families are exercised")
	for frame in 36:
		var outputs: Array=[]
		for row: Dictionary in rows:
			row.events.clear();row.wind.tick(1.0/60.0)
			if frame%8==0:
				for node: Node3D in row.nodes:row.presentation.call("dispatch",4,{"id":node.get_instance_id(),"detonate":true})
			# Direct GD/fallback consumer shares the object before native emitters.
			if frame%3==0:row.rng.next()
			outputs.append(row.presentation.call("dispatch",1,{"delta":[1.0/60.0,1.0/40.0,0.0,0.5][frame%4],"view":view_packet(7100000+frame,frame%13==0),"profile":true}))
		check(not outputs[0].has("error") and not outputs[1].has("error"),"Actual-model native frames succeed "+str(frame)+" "+str(outputs))
		if outputs.any(func(value):return value.has("error")):break
		var a: Dictionary=rows[0].presentation.call("dispatch",2,{})
		var b: Dictionary=rows[1].presentation.call("dispatch",2,{})
		managed_hits+=int(b.frame_pose_reuse.managed_hits)
		check(a.frame_pose_reuse.managed_hits==0,"Unmanaged real model oracle stays live")
		check(a.buffer==b.buffer and outputs[0].active==outputs[1].active,"Exact actual-model geometry/admission "+str(frame))
		for index in total_emitters:
			var expected: Dictionary=rows[0].owners[index].call("dispatch",2,{},{})
			var actual: Dictionary=rows[1].owners[index].call("dispatch",2,{},{})
			check(same(without_ids(expected),without_ids(actual)).is_empty(),"Exact original-model state/clip/recycling "+str(frame)+"/"+str(index))
		check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws and rows[0].events==rows[1].events,"Exact original-model shared RNG and external-service order "+str(frame))
		if not failures.is_empty():break
	check(managed_hits>0,"Installed-model Placement endpoint poses really reuse")
	check(rows[1].rng.snapshot().direct_hits>0,"Actual installed models use guarded native draws")
	var draws: int=rows[1].rng.draws;var direct_hits: int=rows[1].rng.snapshot().direct_hits
	for row: Dictionary in rows:
		row.presentation.call("dispatch",5,{})
		for providers: Dictionary in row.providers:providers.clear()
		row.providers.clear();row.owners.clear();row.presentation=null;row.wind.close();row.rng=null
	rows.clear();scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"models":observations,"emitters":total_emitters,"shared_draws":draws,"native_direct_hits":direct_hits,"managed_hits":managed_hits,"network_connections":0,"gpu_execution":false,"scope":"Installed MDL fields/TRS/controller pools with exact ordinary-vs-managed Placement pose state, RNG and CPU geometry; deterministic chunk service boundary stand-ins, no texture/child-Gob/GPU visual claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
