extends "res://tests/native_particle_presentation_test.gd"
# Actual ModelRigs publication boundaries with installed original model clips.
# No rendering, network or separate animation-time authority is introduced.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Rigs=preload("res://systems/model_rigs.gd")
const ActorSyntax=preload("res://systems/native_render/actor_instance.gd")
const GroupSyntax=preload("res://systems/native_render/particle_stream_group.gd")
var observations: Array=[]

func metadata_for(model: Dictionary,asset: Dictionary,id: int,clip: String) -> Dictionary:
	var nodes: Array=[]
	for index in model.nodes.size():
		var original: Dictionary=model.nodes[index];var defaults: Dictionary=asset.defaults[index]
		nodes.append({"name":original.name,"parent":original.parent,"position":defaults.position,"quaternion":defaults.quaternion,"scale":defaults.scale})
	var parts: Array=[]
	for index in model.nodes.size():parts.append(index)
	return {"rigs":{"version":1,"assets":[asset],"entities":[{"id":id,"nodes":nodes,"models":[{"asset":0,"parts":parts,"defaults":asset.defaults,"clip":clip,"time":0.0,"speed":1.0,"loop":true,"follow":true}],"attachments":[],"clipMap":{"0":clip}}]},"meshes":[]}

func matches(rigs: Node,id: int,slot: RefCounted,label: String) -> void:
	check(slot.sample()==rigs.playback_state(id,0),"Exact canonical model clock "+label+" "+str(slot.sample())+" "+str(rigs.playback_state(id,0)))

func model_contract(scene: Node3D,model: Dictionary,asset: Dictionary,name: String,id: int) -> void:
	var host:=Node3D.new();scene.add_child(host)
	var rigs:=Rigs.new();host.add_child(rigs);rigs.set_process(false)
	var first:=str(asset.clips[0].name);var second:=str(asset.clips[asset.clips.size()-1].name)
	var metadata:=metadata_for(model,asset,id,first)
	rigs.configure({"meshes_by_name":{}},{id:host},metadata)
	check(rigs.stats.failures.is_empty(),"Actual model rig configures "+name)
	var binding: Dictionary=rigs.particle_clock_binding(id,0);var slot: RefCounted=binding.owner
	check(slot!=null and binding.provider==rigs.playback_state.bind(id,0),"Owned model requests native slot and keeps original callback")
	if slot==null:host.free();return
	matches(rigs,id,slot,name+" initial")
	var model_row: Dictionary=rigs.entities[id].models[0];var events:={"started":0,"model":0}
	model_row.player.animation_started.connect(func(_clip):
		events.started+=1;matches(rigs,id,slot,name+" reentrant AnimationPlayer start"))
	# _play stores a double last_time even when model pose channels use f32.
	for frame in 6:
		rigs._play(model_row,second if frame%2==0 else first,true,0.75,0.000123456789123+frame*0.001,true)
		matches(rigs,id,slot,name+" play/restart "+str(frame))
		check(slot.sample().time==0.000123456789123+frame*0.001,"Typed slot never narrows authoritative double to pose float")
		rigs._update(0.03125);matches(rigs,id,slot,name+" AnimationPlayer advance "+str(frame))
	check(events.started>0,"Reentrant animation-start clock boundary was exercised")
	# Reconfiguration disables the old slot BEFORE replacing the entity/model
	# binding. Its original callback then follows the actual new canonical data.
	rigs.configure({"meshes_by_name":{}},{id:host},metadata)
	matches(rigs,id,slot,name+" replaced model old reference")
	check(bool(slot.snapshot().disabled),"Old model slot is conservatively disabled on replacement")
	var next_binding: Dictionary=rigs.particle_clock_binding(id,0);var current: RefCounted=next_binding.owner
	check(current!=null and current!=slot,"Replacement model has a distinct typed lifetime")
	rigs.model_event.connect(func(_id,_index,_event,_serial):
		events.model+=1;matches(rigs,id,current,name+" reentrant native model event"))
	var native_plays:=0
	for frame in 12:
		if frame%3==0:
			var accepted: bool=rigs.play_native(id,0,first if frame%2==0 else second,0.75 if frame%4<2 else -0.5,0,0.03125+frame*0.001)
			if accepted:native_plays+=1
			matches(rigs,id,current,name+" native play "+str(frame))
		rigs._update([0.03125,0.0,-0.002,0.125][frame%4]);matches(rigs,id,current,name+" native run advance "+str(frame))
	var unknown: Dictionary=rigs.particle_clock_binding(id,99)
	check(unknown.owner==null and unknown.provider.call()=={},"Unavailable model binding retains the original empty response")
	rigs.forget_entity(id);matches(rigs,id,current,name+" forgotten model")
	check(bool(current.snapshot().disabled),"Forget routes old slot through canonical unavailable binding")
	# Shared/adopted dictionaries are deliberately outside initial typed coverage.
	rigs.configure({"meshes_by_name":{}},{id:host},metadata)
	var adopted_slot: RefCounted=rigs.particle_clock_binding(id,0).owner
	var target:=Rigs.new();host.add_child(target);target.set_process(false);target.adopt_entities(rigs,[id])
	check(bool(adopted_slot.snapshot().disabled) and target.particle_clock_binding(id,0).owner==null,"Adoption retains opaque callback instead of inventing shared ownership")
	rigs._update(0.0625);matches(rigs,id,adopted_slot,name+" adopted source")
	check(target.playback_state(id,0)==rigs.playback_state(id,0),"Borrowed model remains canonical shared data")
	target.forget_entity(id);rigs.forget_entity(id)
	observations.append({"name":name,"clips":asset.clips.size(),"native_declared":asset.get("nativeAnimation") is Dictionary,"native_plays":native_plays,"animation_start_callbacks":events.started,"model_event_callbacks":events.model})
	unknown.clear();binding.clear();next_binding.clear();model_row={};slot=null;current=null;adopted_slot=null;host.free()

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report):quit(2);return
	var before:=OS.get_environment("NWN_PARTICLE_CLOCKS");OS.set_environment("NWN_PARTICLE_CLOCKS","native")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed model catalog mounts without a server")
	var scene:=Node3D.new();root.add_child(scene)
	for index in 2:
		var name: String=["it_torch_000","plc_cndl01"][index]
		var bytes:=catalog.get_resource(name,2002);var parser:=ActorData.new();var model: Dictionary=parser.parse(bytes)
		check(catalog.failure.is_empty() and parser.failure.is_empty() and not model.is_empty(),"Original model clock fixture parses "+name)
		if model.is_empty():continue
		var asset: Dictionary=parser.rig_asset(model);check(not asset.clips.is_empty(),"Original model contains authored clocks "+name)
		if not asset.clips.is_empty():model_contract(scene,model,asset,name,100+index)
	check(observations.any(func(row):return int(row.native_plays)>0 and int(row.model_event_callbacks)>0),"At least one real model exercises native runs and reentrant model events")
	check(observations.all(func(row):return int(row.animation_start_callbacks)>0),"Actual AnimationPlayer clocks/start callbacks are exercised for each original model")
	OS.set_environment("NWN_PARTICLE_CLOCKS",before)
	scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"models":observations,"network_connections":0,"gpu_execution":false,"scope":"Actual installed model clocks through ModelRigs AnimationPlayer/native run boundaries, double precision, reentrant start/event callbacks, model replacement/forget/unknown/adoption ownership; no visual or FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
