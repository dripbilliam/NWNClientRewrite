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

func close_rows(rows: Array) -> void:
	for row: Dictionary in rows:
		row.presentation.call("dispatch",5,{})
		check(row.presentation.call("dispatch",2,{}).frame_pose_reuse.retained==0,"Close retires all retained pose rows")
		for providers: Dictionary in row.providers:providers.clear()
		row.providers.clear();row.owners.clear();row.presentation=null;row.rng=null
	rows.clear()


# Same helpers as the existing managed fixture; both modes run in this one class.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	OS.set_environment("NWN_PARTICLE_POSE_LEASES","managed")
	var builtin:=ClassDB.class_exists("NwnParticleSceneSnapshot")
	var scene:=Node3D.new();root.add_child(scene);var rows:=[setup(scene,false),setup(scene,true)]
	var modes: Array=[];var used:=0
	for frame in 12:
		var outputs: Array=[]
		for index in 2:
			var row: Dictionary=rows[index]
			if frame%4==0:revoke(row);row.placement.position.x+=0.03125;grant(row)
			var mode:=0 if index==0 else 1+frame%2
			outputs.append(row.presentation.call("dispatch",1,{"scene_snapshot_mode":mode,"delta":0.03125,"view":view_packet(9200000+frame,false),"profile":true}))
		check(not outputs[0].has("error") and not outputs[1].has("error"),"Snapshot off/eligibility/full frame runs "+str(frame)+" "+str(outputs))
		if outputs.any(func(value):return value.has("error")):break
		var a: Dictionary=rows[0].presentation.call("dispatch",2,{})
		var b: Dictionary=rows[1].presentation.call("dispatch",2,{})
		check(a.buffer==b.buffer,"Snapshot mode preserves exact CPU geometry")
		for field in ["prepared","active","culled","vertices","draws"]:check(outputs[0][field]==outputs[1][field],"Snapshot admission is exact "+field)
		for index in 3:check(same(without_ids(rows[0].owners[index].call("dispatch",2,{},{})),without_ids(rows[1].owners[index].call("dispatch",2,{},{}))).is_empty(),"Snapshot keeps exact pose/history/private state")
		check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Snapshot keeps exact shared RNG")
		var actual: Dictionary=rows[1].presentation.call("dispatch",14,{})
		check(actual.mode==1+frame%2 and actual.available==builtin,"Last-frame readback proves requested mode and actual builtin availability")
		if builtin:
			check(int(actual.eligibility_uses)>0 and int(actual.validation_uses)>0,"Builtin current rows are actually consumed")
			if frame>1:check(actual.usable and not actual.invalidated,"A callback-free completed frame keeps its current batch proof")
			check((actual.transforms>0)==(actual.mode==2),"Only full mode fetches TRS; eligibility mode retains managed-pose savings")
		else:check(not actual.usable and actual.rows==0 and actual.eligibility_uses==0,"Absent builtin transparently retains ordinary live checks")
		used+=int(actual.eligibility_uses);modes.append(actual)
	close_rows(rows);scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"engine_module_available":builtin,"builtin_rows_consumed":used,"modes":modes,"gpu":false,"server_connections":0,"scope":"Exact same-DLL off/eligibility/full versus original live path, including managed poses and explicit absent-engine fallback. Builtin execution only claimed when recorded available; no FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
