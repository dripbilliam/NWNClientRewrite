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



func replace_member(row: Dictionary,index: int) -> void:
	var old: Node3D=row.nodes[index];var stale:=old.get_instance_id()
	check(not row.presentation.call("dispatch",3,{"id":stale}).has("error"),"Member retires at its canonical boundary")
	old.get_parent().free()
	var pose:=Node3D.new();row.source.add_child(pose);pose.position=Vector3(index*0.25,0.125,index*0.125)
	var emitter:=Consumer.new();emitter.source=row.source;pose.add_child(emitter)
	check(emitter.get_instance_id()!=stale,"New member full lifetime cannot match a retired ID")
	var seed:=make_owner(false,"single",0,false,false);seed.state.birthRate=1.0;seed.state.lifeExp=2.0;seed.state.velocity=0.125;seed.state.mass=0.01
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":row.source.get_instance_id()},{}).has("error"),"Replacement typed owner configures")
	seed.providers.clear();emitter.native_owner=owner;row.owners[index]=owner;row.nodes[index]=emitter
	check(not row.presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":row.providers[index],"source_flags":0,"culling":false}).has("error"),"Registration can reuse retired request slots")

func compare_frame(rows: Array,presentations: Array,frame: int,expected: int,refresh: bool=false) -> Array:
	var outcomes: Array=[];var readbacks: Array=[]
	for index in 2:
		var result: Dictionary=presentations[index].call("dispatch",1,{"scene_snapshot_mode":0 if index==0 else 1+frame%2,"delta":0.03125,"view":view_packet(9300000+frame,false)})
		check(not result.has("error"),"Frame executes through exact live/batch pair "+str(frame));outcomes.append(result)
		readbacks.append(presentations[index].call("dispatch",14,{}))
	var a: Dictionary=presentations[0].call("dispatch",2,{});var b: Dictionary=presentations[1].call("dispatch",2,{})
	check(a.buffer==b.buffer,"Slot/lifetime changes preserve exact CPU geometry")
	for field in ["prepared","active","culled","vertices","draws"]:check(outcomes[0][field]==outcomes[1][field],"Admission agrees after membership changes "+field)
	for index in 3:check(same(without_ids(rows[0].owners[index].call("dispatch",2,{},{})),without_ids(rows[1].owners[index].call("dispatch",2,{},{}))).is_empty(),"Member state is exact after slot reuse")
	check(rows[0].rng.state==rows[1].rng.state and rows[0].rng.draws==rows[1].rng.draws,"Slot changes preserve shared visual RNG order")
	var actual: Dictionary=readbacks[1]
	check(actual.available and actual.usable and not actual.invalidated,"Corrected builtin actually supplies this callback-free frame")
	check(actual.eligibility_uses==expected and actual.validated_rows==actual.rows,"Every immutable packet row validates once, including vacant slots")
	check(actual.slot_hits>0 and (actual.id_lookups>0)==refresh,"Retained scalar handle takes expected direct/refresh path: "+str(actual))
	return readbacks

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	if not ClassDB.class_exists("NwnParticleSceneSnapshot"):quit(2);return
	OS.set_environment("NWN_PARTICLE_POSE_LEASES","managed")
	var scene:=Node3D.new();root.add_child(scene);var rows:=[setup(scene,false),setup(scene,false)];var observed: Array=[]
	for frame in 4:observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],frame,3))
	for row: Dictionary in rows:replace_member(row,0)
	observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],4,3))
	for row: Dictionary in rows:
		check(not row.presentation.call("dispatch",6,{"ids":[row.nodes[2].get_instance_id(),row.nodes[1].get_instance_id(),row.nodes[0].get_instance_id()]}).has("error"),"Reordering members retains request slots")
	observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],5,3))
	# The same native owner may be a member of a different Plan. Owner endpoint
	# handles must refresh via plan identity, while Entry handles remain local.
	var other: Array=[]
	for row: Dictionary in rows:
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation");other.append(presentation)
		check(not presentation.call("dispatch",0,{"id":row.nodes[0].get_instance_id(),"owner":row.owners[0],"providers":row.providers[0],"source_flags":0,"culling":false}).has("error"),"Secondary Plan shares a native owner without owning its data")
	observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],6,3,true))
	observed.append_array(compare_frame(rows,other,7,1,true))
	observed.append_array(compare_frame(rows,other,8,1))
	for value in other:value.call("dispatch",5,{})
	other.clear()
	observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],9,3,true))
	observed.append_array(compare_frame(rows,[rows[0].presentation,rows[1].presentation],10,3))
	close_rows(rows);scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"modes":observed,"gpu":false,"server_connections":0,"scope":"Exact live/batch oracle for once-validated rows, direct handle counters, remove/new full-ID slot reuse, reorder, shared-owner multi-Plan refresh, and Plan retirement. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
