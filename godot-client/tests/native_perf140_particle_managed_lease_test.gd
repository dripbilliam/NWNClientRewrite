extends "res://tests/native_particle_presentation_test.gd"
# Actual canonical Placement + native presentation pair; no GPU or server.
const Template=preload("res://systems/native_render/model_template.gd")
const Leases=preload("res://systems/native_render/managed_particle_pose_leases.gd")
const WorldSyntax=preload("res://systems/native_render/live_world.gd")
const ObjectSyntax=preload("res://systems/native_render/object_stream.gd")
const AreaSyntax=preload("res://systems/native_render/area_stream.gd")
class Consumer:
	extends Node3D
	var native_owner: RefCounted
	var source: Node3D
class Tick:
	extends Node
	var invoke: Callable
	func _process(_delta: float) -> void:invoke.call()

var lease_hits:=0
var lease_refreshes:=0
func setup(scene: Node3D,managed: bool) -> Dictionary:
	var host:=Node3D.new();scene.add_child(host)
	var scope:=Leases.create_scope(host);host.set_meta("native_particle_pose_lease_scope",scope)
	check(scope!=null,"Explicit canonical world scope binds")
	var placement:=Template.Placement.new();host.add_child(placement)
	var source:=Node3D.new();placement.add_child(source)
	placement.position=Vector3(0.25,0.125,-0.5);placement.rotation.y=0.25;placement.set_meta("native_tile_index",0)
	var row:={"host":host,"scope":scope,"placement":placement,"source":source,"managed":managed,"owners":[],"nodes":[],"providers":[],"presentation":ClassDB.instantiate("NwnParticlePresentation"),"rng":ClassDB.instantiate("NwnVisualRandom")}
	row.rng.seed_value(31811)
	for index in 3:
		var pose:=Node3D.new();source.add_child(pose);pose.position=Vector3(index*0.25,0.125,index*0.125);placement.parts.append(pose)
		var emitter:=Consumer.new();emitter.name="native_emitter";emitter.source=source;pose.add_child(emitter)
		var seed:=make_owner(false,"explosion" if index==1 else "single",0,false,false)
		seed.state.birthRate=1.0;seed.state.lifeExp=2.0;seed.state.velocity=0.125;seed.state.mass=0.01
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		check(not owner.call("dispatch",0,{"state":seed.state,"update":"explosion" if index==1 else "single","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()},{ }).has("error"),"Canonical static endpoint owner configures")
		seed.providers.clear();emitter.native_owner=owner;row.owners.append(owner);row.nodes.append(emitter)
		var providers:={"random":row.rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass};row.providers.append(providers)
		check(not row.presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"source_flags":0,"culling":false}).has("error"),"Canonical static endpoint registers")
	if managed:
		placement.grant_particle_pose_lease(scope)
		check(placement.particle_pose_lease!=null and placement.particle_pose_lease.snapshot().endpoints==4,"Real Placement grants only its three physical endpoints and source")
	return row

func revoke(row: Dictionary) -> void:
	row.placement.revoke_particle_pose_lease()
func grant(row: Dictionary) -> void:
	if row.managed:row.placement.grant_particle_pose_lease(row.scope)
func compare(rows: Array,frame: int,error_expected: bool=false) -> void:
	var outputs: Array=[]
	for row: Dictionary in rows:outputs.append(row.presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(9100000+frame,false),"profile":true}))
	check(outputs[0].has("error")==error_expected and outputs[1].has("error")==error_expected,"Managed pose error/validity matches "+str(frame)+" "+str(outputs))
	if error_expected:
		check(outputs[0].error==outputs[1].error,"Managed callback failure retains exact ordinary error");return
	if outputs.any(func(value):return value.has("error")):return
	var a: Dictionary=rows[0].presentation.call("dispatch",2,{})
	var b: Dictionary=rows[1].presentation.call("dispatch",2,{})
	check(a.buffer==b.buffer,"Managed static retention preserves exact geometry "+str(frame))
	for field in ["prepared","active","culled","vertices","draws"]:check(outputs[0][field]==outputs[1][field],"Managed admission matches "+field+"/"+str(frame))
	for index in 3:
		var difference:=same(without_ids(rows[0].owners[index].call("dispatch",2,{},{})),without_ids(rows[1].owners[index].call("dispatch",2,{},{})))
		check(difference.is_empty(),"Managed pose/history/private state is exact "+str(frame)+"/"+str(index)+" "+difference)
	check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Managed pose keeps exact shared RNG "+str(frame))
	check(a.frame_pose_reuse.managed_hits==0,"Unmanaged oracle never retains a managed pose")
	lease_hits+=int(b.frame_pose_reuse.managed_hits);lease_refreshes+=int(b.frame_pose_reuse.managed_refreshes)
	if frame==2:check(int(b.frame_pose_reuse.managed_refreshes)==0 and int(b.frame_pose_reuse.managed_hits)==6,"Warm managed endpoints reuse across a fresh presentation call without transform reads")

func close_rows(rows: Array) -> void:
	for row: Dictionary in rows:
		row.presentation.call("dispatch",5,{})
		check(row.presentation.call("dispatch",2,{}).frame_pose_reuse.retained==0,"Close retires all retained pose rows")
		for providers: Dictionary in row.providers:providers.clear()
		row.providers.clear();row.owners.clear();row.presentation=null;row.rng=null
	rows.clear()

func lifecycle_edges(scene: Node3D) -> void:
	var rows:=[setup(scene,false),setup(scene,true)]
	compare(rows,100);compare(rows,101)
	for row: Dictionary in rows:
		var foreign:=Node3D.new();foreign.position=Vector3(0.125,0,-0.25);row.host.add_child(foreign)
		row.providers[1].random=func():
			if row.source.get_parent()!=foreign:row.source.reparent(foreign,false)
			return row.rng.next()
		row.presentation.call("dispatch",4,{"id":row.nodes[1].get_instance_id(),"detonate":true})
	compare(rows,102)
	check(not rows[1].placement.particle_pose_lease.snapshot().active,"Opaque reparent revokes a topology proof before the next endpoint use")
	for row: Dictionary in rows:
		row.providers[1].random=row.rng.next
		revoke(row);row.source.reparent(row.placement,false);grant(row)
	compare(rows,103)
	# The original full source/pose IDs cannot resolve through replacement nodes.
	for row: Dictionary in rows:
		row.presentation.call("dispatch",4,{"id":row.nodes[0].get_instance_id(),"clock":func():
			if is_instance_valid(row.source):row.source.free()
			return {}
		})
	compare(rows,104,true)
	for row: Dictionary in rows:
		var replacement:=Node3D.new();row.placement.add_child(replacement)
		var next: Dictionary=row.presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(9100105,false)})
		check(not next.has("error") and next.prepared==0,"Freed endpoint lifetime never resolves to a new source")
	close_rows(rows)

func scheduled_edges(scene: Node3D) -> void:
	var rows:=[setup(scene,false),setup(scene,true)]
	var context:={"frame":0,"completed":0}
	var early:=Tick.new();early.process_priority=-100;early.invoke=func():
		context.frame+=1
		for row: Dictionary in rows:revoke(row);row.placement.parts[0].position.x+=0.015625;grant(row)
	root.add_child(early)
	var middle:=Tick.new();middle.process_priority=100;middle.invoke=func():compare(rows,500+context.frame*2)
	root.add_child(middle)
	var late:=Tick.new();late.process_priority=200;late.invoke=func():
		for row: Dictionary in rows:revoke(row);row.source.rotation.y+=0.015625;grant(row)
		compare(rows,501+context.frame*2);context.completed+=1
	root.add_child(late)
	while context.completed<6 and failures.is_empty():await process_frame
	early.free();middle.free();late.free();check(context.completed==6,"Early/late SceneTree writers and two calls in the same engine frame are exercised")
	close_rows(rows)

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	OS.set_environment("NWN_PARTICLE_POSE_LEASES","managed")
	check(ClassDB.class_exists("NwnParticlePoseLease"),"Native managed pose class is registered")
	var scene:=Node3D.new();root.add_child(scene);var rows:=[setup(scene,false),setup(scene,true)]
	for frame in 24:
		for row: Dictionary in rows:
			if frame in [3,5,7]:
				revoke(row)
				if frame==3:row.placement.parts[1].position+=Vector3(0.125,0.25,-0.0625)
				elif frame==5:row.placement.rotation.y+=0.03125;row.placement.scale=Vector3(-1.0,0.75,1.25)
				else:row.source.position+=Vector3(0.25,0.125,-0.5)
				grant(row)
			if frame==9:
				# This is a real opaque service mutating a source mid-presentation,
				# without the canonical writer API. The barrier must force refresh.
				row.providers[1].random=func():row.source.position+=Vector3(0.015625,0,0);return row.rng.next()
				row.presentation.call("dispatch",4,{"id":row.nodes[1].get_instance_id(),"detonate":true})
			if frame==10:row.providers[1].random=row.rng.next
			if frame==11:row.placement.hide()
			if frame==12:row.placement.show();row.placement.parts[2].process_mode=Node.PROCESS_MODE_DISABLED
			if frame==13:row.placement.parts[2].process_mode=Node.PROCESS_MODE_INHERIT
			if frame==14:
				row.providers[1].random=func():row.source.position+=Vector3(0,0.03125,0);return "invalid random result"
				row.presentation.call("dispatch",4,{"id":row.nodes[1].get_instance_id(),"detonate":true})
			if frame==15:
				row.providers[1].random=row.rng.next
				row.presentation.call("dispatch",4,{"id":row.nodes[1].get_instance_id(),"detonate":false})
			if frame==17:
				# Scope revocation precedes changing an ancestor. Reconnect/regrant
				# uses a new lifetime, even with the same numeric tile index.
				Leases.revoke(row.scope);revoke(row);row.host.position+=Vector3(0.125,0.0625,-0.25)
				row.scope=Leases.create_scope(row.host);row.host.set_meta("native_particle_pose_lease_scope",row.scope);grant(row)
		compare(rows,frame,frame==14)
		if not failures.is_empty():break
	check(lease_hits>20 and lease_refreshes>0,"Managed poses actually reuse across calls and refresh at mutation boundaries")
	# Existing references never survive explicit retirement or a scope lifetime.
	var old: RefCounted=rows[1].placement.particle_pose_lease
	rows[1].placement.revoke_particle_pose_lease();check(not old.snapshot().active,"Old token stays revoked after canonical regrant")
	rows[1].placement.grant_particle_pose_lease(rows[1].scope);check(rows[1].placement.particle_pose_lease!=old,"Regrant creates a distinct token lifetime")
	rows[1].placement.retire();check(not rows[1].placement.particle_pose_lease and not old.snapshot().active,"Placement retirement revokes before freeing its physical Parts")
	close_rows(rows);old=null
	if failures.is_empty():lifecycle_edges(scene)
	if failures.is_empty():await scheduled_edges(scene)
	scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"managed_hits":lease_hits,"managed_refreshes":lease_refreshes,"network_connections":0,"gpu_execution":false,"scope":"Actual canonical Placement, explicit static pose/scope lifetime revocation, reflection/nonuniform transforms, opaque same-call source mutation and failure retry, live visibility/process checks; exact ordinary state/geometry/RNG oracle. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
