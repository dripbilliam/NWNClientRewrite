extends "res://tests/native_particle_presentation_test.gd"
const Template=preload("res://systems/native_render/model_template.gd")
const Eligibility=preload("res://systems/native_render/managed_particle_eligibility.gd")
const WorldSyntax=preload("res://systems/native_render/live_world.gd")
const ObjectSyntax=preload("res://systems/native_render/object_stream.gd")
const AreaSyntax=preload("res://systems/native_render/area_stream.gd")
const VisibilitySyntax=preload("res://systems/native_render/particle_visibility.gd")
class TestEmitter:
	extends "res://systems/native_render/particle_emitter.gd"
	# Test only skips resource construction. Preference/retire methods are the
	# actual production methods, including revoke-before-setter publication.
	func _ready() -> void:set_process(false)

var observations: Array=[]
func add_member(row: Dictionary,index: int) -> void:
	var part: Node3D=row.parts[index]
	var emitter:=TestEmitter.new();emitter.name="native_emitter";emitter.source=row.source
	var seed:=make_owner(false,"single",0,false,false)
	seed.state.birthRate=1.0;seed.state.lifeExp=2.0;seed.state.velocity=0.0;seed.state.randomVelocity=0.0;seed.state.mass=0.0;seed.state.xSize=0.0;seed.state.ySize=0.0;seed.state.spread=0.0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":part.get_instance_id(),"sourceId":row.source.get_instance_id()},{}).has("error"),"Eligibility member native state configures")
	seed.providers.clear();emitter.native_owner=owner;emitter.providers={"random":row.rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass}
	part.add_child(emitter);row.nodes[index]=emitter;row.owners[index]=owner
	check(not row.presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":emitter.providers,"culling":false,"source_flags":0,"managed_eligibility":row.managed}).has("error"),"Explicit per-entry ownership mode registers")

func setup(scene: Node3D,managed: bool) -> Dictionary:
	var host:=Node3D.new();scene.add_child(host)
	var scope:=Eligibility.create_scope(host);host.set_meta("native_particle_eligibility_scope",scope)
	check(scope!=null,"Independent eligibility scope is available without a pose grant")
	var placement:=Template.Placement.new();host.add_child(placement)
	var source:=Node3D.new();placement.add_child(source)
	var row:={"host":host,"scope":scope,"placement":placement,"source":source,"managed":managed,"presentation":ClassDB.instantiate("NwnParticlePresentation"),"rng":ClassDB.instantiate("NwnVisualRandom"),"owners":[null,null,null],"nodes":[null,null,null],"parts":[],"events":[]}
	row.rng.seed_value(71812)
	for index in 3:
		var part:=Node3D.new();source.add_child(part);part.position=Vector3(index*0.25,0.125,index*0.125);placement.parts.append(part);row.parts.append(part);add_member(row,index)
	refresh(row)
	if managed:
		var abi: Dictionary=placement.particle_eligibility_lease.snapshot()
		check(abi.enum_return_bytes==8 and abi.enum_abi_calls>0 and abi.enum_abi_failures==0,"Actual getter ptrcalls use eight-byte enum slots with intact neighboring canaries")
	return row

func revoke(row: Dictionary) -> void:
	if row.managed:row.placement.revoke_particle_eligibility()
func refresh(row: Dictionary) -> void:
	if row.managed:row.placement.grant_particle_eligibility(row.scope)

func pair_frame(rows: Array,serial: int,hits: int=-1,anchors: int=-1,error: bool=false) -> Array:
	var output: Array=[];var snapshots: Array=[];var diagnostics: Array=[]
	for row: Dictionary in rows:
		output.append(row.presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(18000000+serial,false)}))
		snapshots.append(row.presentation.call("dispatch",2,{}));diagnostics.append(row.presentation.call("dispatch",15,{}))
	check(output[0].has("error")==error and output[1].has("error")==error,"Original failure boundary agrees "+str(serial)+" "+str(output))
	for field in ["registered","prepared","active","culled","vertices","draws"]:check(snapshots[0][field]==snapshots[1][field],"Exact eligibility/admission "+field+" "+str(serial))
	check(snapshots[0].get("buffer")==snapshots[1].get("buffer"),"Exact active CPU geometry "+str(serial))
	for index in 3:check(same(without_ids(rows[0].owners[index].call("dispatch",2,{},{})),without_ids(rows[1].owners[index].call("dispatch",2,{},{}))).is_empty(),"Exact state/history/lifetime "+str(serial)+"/"+str(index))
	check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Exact shared RNG "+str(serial))
	check(diagnostics[0].attempts==0,"Ordinary path stays selected in the same DLL")
	if hits>=0:check(diagnostics[1].hits==hits and diagnostics[1].endpoint_validations>=hits,"Actual live-ID validated managed hit count "+str(serial)+" "+str(diagnostics[1]))
	if anchors>=0:check(diagnostics[1].anchor_reads==anchors,"Actual per-call anchor read count "+str(serial)+" "+str(diagnostics[1]))
	observations.append({"serial":serial,"owned":diagnostics[1]})
	return diagnostics

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var split:=arg.trim_prefix("--").split("=",true,1)
		if split.size()==2:args[split[0]]=split[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	OS.set_environment("NWN_PARTICLE_ELIGIBILITY","managed")
	var scene:=Node3D.new();root.add_child(scene);var rows:=[setup(scene,false),setup(scene,true)]
	for frame in 4:pair_frame(rows,frame,3,1)
	for row: Dictionary in rows:row.host.hide()
	pair_frame(rows,4,3,1)
	for row: Dictionary in rows:row.host.show()
	paused=true;pair_frame(rows,5,3,1)
	for row: Dictionary in rows:row.host.process_mode=Node.PROCESS_MODE_ALWAYS
	pair_frame(rows,6,3,1)
	for row: Dictionary in rows:row.host.process_mode=Node.PROCESS_MODE_DISABLED
	pair_frame(rows,7,3,1);paused=false
	for row: Dictionary in rows:row.host.process_mode=Node.PROCESS_MODE_INHERIT
	# Actual preference setters revoke before Node visible/process notifications,
	# then publish a new independently checked grant. Disabled-first works too.
	for row: Dictionary in rows:row.nodes[0].set_particles_enabled(false)
	pair_frame(rows,8,2,1)
	for row: Dictionary in rows:row.nodes[0].set_particles_enabled(true)
	pair_frame(rows,9,3,1)
	for row: Dictionary in rows:
		var visibility:=VisibilitySyntax.new();row.host.add_child(visibility)
		for emitter in row.nodes:visibility.register(emitter)
		visibility.set_enabled(true)
		check(visibility.snapshot().registered==3,"Actual visibility owner batches three preference writers")
	pair_frame(rows,10,3,1)
	# Canonical local writer revokes BEFORE an early visibility listener can
	# synchronously enter another presentation call.
	for row: Dictionary in rows:
		revoke(row)
		var listener:=func():
			var result: Dictionary=row.presentation.call("dispatch",1,{"delta":0.0,"view":view_packet(18000100,false)})
			row.events.append(result.get("prepared"));row.events.append(row.presentation.call("dispatch",15,{}).hits)
		row.parts[1].visibility_changed.connect(listener);row.parts[1].hide();row.parts[1].visibility_changed.disconnect(listener)
		refresh(row)
	check(rows[0].events==rows[1].events and rows[1].events==[2,0],"Early local visibility callback observes revoked grant and actual current chain")
	pair_frame(rows,11,2,1)
	for row: Dictionary in rows:revoke(row);row.parts[1].show();refresh(row)
	pair_frame(rows,12,3,1)
	# A local process override cannot be substituted by the anchor, particularly
	# when the surrounding world is paused.
	for row: Dictionary in rows:revoke(row);row.parts[1].process_mode=Node.PROCESS_MODE_ALWAYS;refresh(row)
	paused=true;pair_frame(rows,13,2,1);paused=false
	for row: Dictionary in rows:revoke(row);row.parts[1].process_mode=Node.PROCESS_MODE_INHERIT;refresh(row)
	pair_frame(rows,14,3,1)
	for row: Dictionary in rows:revoke(row);row.parts[1].reparent(row.host,false);refresh(row)
	pair_frame(rows,15,2,1)
	for row: Dictionary in rows:
		revoke(row);row.parts[1].reparent(row.source,false)
		# The actual emitter retires in _exit_tree during reparenting. Canonical
		# publication must install a fresh emitter/native owner, not revive it.
		row.presentation.call("dispatch",3,{"id":row.nodes[1].get_instance_id()});row.nodes[1].free();add_member(row,1);refresh(row)
	pair_frame(rows,16,3,1)
	# Every endpoint still validates a full live ID. Unexpected removal cannot
	# turn a stale reference into another member or retain a true group result.
	for row: Dictionary in rows:
		row.stale=int(row.nodes[2].get_instance_id())
		# Bypass the supported pre-retire publisher deliberately, so this case
		# actually exercises native per-endpoint full-ID validation itself.
		row.nodes[2].native_eligibility_token=null;row.nodes[2].free()
	var missing:=pair_frame(rows,17,1,1)
	check(missing[1].endpoint_validations==2,"Live-ID validation reaches the freed member and retires the group before its later member")
	check(not rows[1].placement.particle_eligibility_lease.snapshot().active,"Unexpected freed full ID retires the old capability")
	for row: Dictionary in rows:
		row.presentation.call("dispatch",3,{"id":row.stale});add_member(row,2);check(row.nodes[2].get_instance_id()!=row.stale,"Replacement has a new full object lifetime");refresh(row)
	pair_frame(rows,171,3,1)
	for row: Dictionary in rows:revoke(row);row.placement.reference_graph=RefCounted.new();refresh(row)
	pair_frame(rows,172,0,0)
	for row: Dictionary in rows:row.placement.reference_graph=null;refresh(row)
	pair_frame(rows,173,3,1)
	# An arbitrary opaque clock mutates an intermediate local node. Current-call
	# sharing must stop; the next call structurally rechecks the prior grant.
	for row: Dictionary in rows:
		row.presentation.call("dispatch",4,{"id":row.nodes[0].get_instance_id(),"clock":func():row.parts[1].hide();return {"clip":"","time":0.0}})
	var invalidated:=pair_frame(rows,18,1,1)
	check(invalidated[1].invalidated and invalidated[1].fallbacks>0,"Opaque mutation abandons shared eligibility for the rest of the call")
	for row: Dictionary in rows:row.presentation.call("dispatch",4,{"id":row.nodes[0].get_instance_id(),"clock":Callable()})
	pair_frame(rows,19)
	check(not rows[1].placement.particle_eligibility_lease.snapshot().active,"Callback-changed local state retires its old grant before another member reuses it")
	for row: Dictionary in rows:revoke(row);row.parts[1].show();refresh(row)
	pair_frame(rows,20,3,1)
	for row: Dictionary in rows:row.presentation.call("dispatch",4,{"id":row.nodes[0].get_instance_id(),"clock":func():return 17})
	var failure:=pair_frame(rows,21,1,1,true)
	check(failure[1].invalidated,"Failed final callback also invalidates the eligibility scope")
	for row: Dictionary in rows:row.presentation.call("dispatch",4,{"id":row.nodes[0].get_instance_id(),"clock":Callable()})
	pair_frame(rows,22,3,1)
	# Scope changes never revive old tokens, even with the same current Nodes.
	var old: RefCounted=rows[1].placement.particle_eligibility_lease
	for row: Dictionary in rows:Eligibility.revoke_scope(row.host)
	pair_frame(rows,23,0,0)
	for row: Dictionary in rows:
		row.scope=Eligibility.create_scope(row.host);row.host.set_meta("native_particle_eligibility_scope",row.scope);refresh(row)
	check(not old.snapshot().active,"Old connection/area capability remains stale after new scope grant")
	pair_frame(rows,24,3,1)
	# A Placement or intermediate sub-thread group is outside the declared
	# no-concurrent-writer capability. Ordinary eligibility remains available.
	for row: Dictionary in rows:revoke(row);row.placement.process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD;refresh(row)
	pair_frame(rows,25,0,0)
	for row: Dictionary in rows:row.placement.process_thread_group=Node.PROCESS_THREAD_GROUP_INHERIT;refresh(row)
	pair_frame(rows,26,3,1)
	for row: Dictionary in rows:revoke(row);row.parts[1].process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD;refresh(row)
	pair_frame(rows,27,2,1)
	for row: Dictionary in rows:revoke(row);row.parts[1].process_thread_group=Node.PROCESS_THREAD_GROUP_INHERIT;refresh(row)
	pair_frame(rows,28,3,1)
	var enum_abi: Dictionary=rows[1].placement.particle_eligibility_lease.snapshot()
	check(enum_abi.enum_return_bytes==8 and enum_abi.enum_abi_calls>100 and enum_abi.enum_abi_failures==0,"All initial/regrant/callback enum reads retain exact eight-byte return boundaries")
	var worker_token: RefCounted=ClassDB.instantiate("NwnParticleEligibilityLease")
	var worker:=Thread.new()
	check(worker.start(func():return ClassDB.class_call_static("NwnParticleEligibilityLease","bind",worker_token,rows[1].scope,rows[1].placement,rows[1].source))==OK,"Unsupported worker grant probe starts")
	check(worker.wait_to_finish()==false,"Worker grant is rejected before any live Node eligibility getter")
	worker_token=null
	for row: Dictionary in rows:
		row.presentation.call("dispatch",5,{});revoke(row);row.presentation=null;row.owners.clear();row.nodes.clear();row.parts.clear();row.rng=null
	rows.clear();old=null;scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"enum_abi":enum_abi,"gpu":false,"server_connections":0,"scope":"Explicit Placement-only eligibility ownership versus live getters: actual canonical preference writers, per-call ancestor state, local override/exclusion, early reentrancy, topology, lifetimes, opaque callback/exception invalidation and stale scope generations. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
