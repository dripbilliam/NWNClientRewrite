extends SceneTree
const Rigs=preload("res://systems/model_rigs.gd")
class CustomPart:
	extends Node3D
var failures: Array[String]=[]
var checks: int=0
var coverage: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func make_mesh(parent: Node3D) -> MeshInstance3D:
	var mesh: MeshInstance3D=MeshInstance3D.new();parent.add_child(mesh)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP])
	var geometry: ArrayMesh=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.mesh=geometry
	return mesh
func skin_source() -> Dictionary:
	var slots: Array=[]
	for index: int in 64:slots.append(index if index<5 else 0 if index==7 else -1)
	return {"part":2,"slots":slots,"inverseQuaternions":[[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,0,0,0]],"inversePositions":[[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0]],"groups":[],"position":[0,0,0,1,0,0,0,1,0],"normal":[0,0,1,0,0,1,0,0,1],"uv":[0,0,1,0,0,1],"weights":[1,0,0,0,1,0,0,0,0,0,0,0],"bones":[0,0,0,0,1,0,0,0,0,0,0,0]}
func setup(native: bool,custom: bool=false,probe_reentry: bool=true) -> Dictionary:
	var host: Node3D=Node3D.new();root.add_child(host)
	var rigs: Node=Rigs.new();host.add_child(rigs);rigs.set_process(false);rigs.use_native_skin_publisher=native
	var nodes: Array[Node3D]=[];var parents: Array=[-1,0,1,0,3]
	for index: int in parents.size():
		var node: Node3D=CustomPart.new() if custom and index==4 else Node3D.new()
		(host if int(parents[index])<0 else nodes[int(parents[index])]).add_child(node)
		node.position=Vector3(index*0.11,index*0.07,index*-0.13);node.quaternion=Quaternion(Vector3.UP,index*0.13);node.scale=Vector3(1+index*0.03,1-index*0.02,1+index*0.01)
		nodes.append(node)
	var defaults: Array=[]
	for index: int in 5:defaults.append({"position":[0,0,0],"quaternion":[1,0,0,0],"scale":[1,1,1]})
	var source: Dictionary={"parts":[0,1,2,3,4],"defaults":defaults,"follow":true,"clip":"turn","loop":true,"speed":1.0,"time":0.0}
	var asset: Dictionary={"defaults":defaults,"unsupported":[],"clips":[{"name":"turn","length":0.5,"transition":0.0,"tracks":[{"part":2,"property":"position","sourceInterpolation":"linear","keys":[{"time":0.0,"value":[0,0,0]},{"time":0.5,"value":[1,2,3]}]}],"events":[{"time":0.125,"name":"event_a"},{"time":0.375,"name":"event_b"}]}]}
	var model: Dictionary=rigs._model(host,nodes,source,asset);model.event_source=true;model.asset_source=asset;model.part_source=source
	var skins: Array=[]
	for index: int in 2:skins.append(rigs._skin(make_mesh(nodes[2]),skin_source(),[0,1,2,3,4]))
	var entry: Dictionary={"nodes":nodes,"parents":parents,"models":[model],"animated_models":[0],"manual_poses":{},"attachments":[{"node":3,"anchor":2,"scale":[1.0,1.0,1.0],"flags":3}],"skins":skins,"counts":{}}
	rigs.entities[1]=entry
	# This fixture installs the private entry directly instead of configure().
	# Establish the same work-state before requesting deterministic manual time.
	rigs._refresh_processing();rigs.set_process(false)
	var events: Array=[];var forces: Array=[];var sequence: Dictionary={"first":0,"reentrant":[],"recursed":false}
	rigs.model_event.connect(func(id: int,index: int,name: String,serial: int) -> void:
		events.append([id,index,name,serial]);nodes[4].position.x+=0.021)
	for skin_index: int in skins.size():
		var skeleton: Skeleton3D=skins[skin_index].skeleton
		skeleton.pose_updated.connect(func() -> void:
			forces.append(skin_index)
			if skin_index==0:
				sequence.first+=1
				if int(sequence.first) in [2,5,9]:
					# The first force callback changes later skin inputs. The rigid
					# array was already computed and must NOT be recomputed here.
					skins[1].bones[1]=4 if int(sequence.first)!=5 else 1
					skins[1].part=1 if int(sequence.first)==5 else 2
					nodes[2].position.y+=0.17
				if int(sequence.first)==6 and not bool(sequence.recursed):
					sequence.recursed=true
					# The actual old ModelRigs permits this nested update. Native
					# wrapper must use a separate legacy rigid array, not reject it.
					rigs._update(0.03125)
				if native and not custom and probe_reentry and rigs.native_skin_publishers.has(1):
					sequence.reentrant.append(int(rigs.native_skin_publishers[1][1].call("publish"))))
	return {"host":host,"rigs":rigs,"entry":entry,"events":events,"forces":forces,"sequence":sequence}
func capture(row: Dictionary) -> Dictionary:
	var result: Dictionary={"nodes":[],"skins":[],"clock":row.entry.models[0].last_time,"events":row.events.duplicate(true),"forces":row.forces.duplicate()}
	for node: Node3D in row.entry.nodes:result.nodes.append([node.position,node.quaternion,node.scale,node.global_transform])
	for skin: Dictionary in row.entry.skins:
		var state: Array=[];var skeleton: Skeleton3D=skin.skeleton
		for slot: int in skeleton.get_bone_count():state.append([skeleton.get_bone_pose_position(slot),skeleton.get_bone_pose_rotation(slot),skeleton.get_bone_pose_scale(slot),skeleton.get_bone_global_pose(slot)])
		result.skins.append({"state":state,"binds":skin.mesh.skin.get_bind_count(),"mesh":skin.mesh.mesh.surface_get_arrays(0)})
	return result
func compare_case(custom: bool) -> void:
	var ordinary: Dictionary=setup(false,custom);var candidate: Dictionary=setup(true,custom)
	for frame: int in 24:
		for row: Dictionary in [ordinary,candidate]:
			if frame in [3,8,17]:
				row.rigs.set_manual_pose(1,row.entry.nodes[1],Vector3(frame*0.03,-0.7,0.2),Quaternion(Vector3.RIGHT,frame*0.017))
			if frame==10:row.entry.attachments[0].flags=0
			if frame==16:row.entry.attachments[0].flags=3
			if frame==7:row.entry.parents=[-1,0,0,2,3]
			if frame==14:
				var reordered: Array=row.entry.skins.duplicate();reordered.reverse();row.entry.skins=reordered
			if frame==18:
				var rebound: Array[Node3D]=[];rebound.assign(row.entry.nodes);var saved: Node3D=rebound[3];rebound[3]=rebound[4];rebound[4]=saved;row.entry.nodes=rebound
			if frame==12:row.rigs._play(row.entry.models[0],"turn",true,-0.5,0.4,true)
			row.rigs._update(0.125)
		check(var_to_bytes(capture(ordinary))==var_to_bytes(capture(candidate)),"Exact actual ModelRigs skin/mesh/clock/event/attachment output frame "+str(frame)+" custom="+str(custom))
	var route: Dictionary=candidate.rigs.native_skin_snapshot(1)
	check(int(route.completed)==0 if custom else int(route.completed)==24,"Actual selected route, including scripted-part fallback")
	check(int(route.fallbacks)==25 if custom else int(route.fallbacks)==0,"Every ordinary and nested custom fallback happens before native bone writes")
	if not custom:
		check(int(route.node_reads)==120 and int(route.bone_writes)==3072 and int(route.force_calls)==48,"Whole rig batch read/write/force counts")
		check(candidate.sequence.reentrant.size()==25 and candidate.sequence.reentrant.all(func(value: int) -> bool:return value==3),"Direct API reentry does not touch outer scratch or bone state")
		check(candidate.rigs.native_skin_reentrant_fallbacks==1,"Actual ModelRigs reentry executes the unchanged legacy branch")
	check(ordinary.sequence.recursed and candidate.sequence.recursed and ordinary.rigs.stats.pose_frames==25 and candidate.rigs.stats.pose_frames==25,"Both actual ModelRigs paths complete the nested update")
	var previous_publisher: WeakRef=weakref(candidate.rigs.native_skin_publishers[1][1])
	for row: Dictionary in [ordinary,candidate]:
		row.entry=row.entry.duplicate();row.rigs.entities[1]=row.entry
		row.rigs._update(0.0)
	check(var_to_bytes(capture(ordinary))==var_to_bytes(capture(candidate)),"Replacing the live entry Dictionary keeps exact next publication")
	check(previous_publisher.get_ref()==null,"A new entry Dictionary releases the previous publisher binding")
	for row: Dictionary in [ordinary,candidate]:
		check(row.rigs.stats.failures.is_empty(),"No actual rig failure")
		var weak: WeakRef=weakref(row.rigs.native_skin_publishers[1][1]) if row.rigs.native_skin_publishers.has(1) else null
		row.rigs.forget_entity(1)
		check(row.rigs.native_skin_publishers.is_empty() and (weak==null or weak.get_ref()==null),"Forget releases separate publisher table without reference cycle")
		row.host.free();row.clear()
	coverage.append("scripted-part preflight fallback" if custom else "actual ModelRigs AnimationPlayer/manual/events/flags0+3 attachments/two64slot sparse skins/reentrant force callbacks/current node-parent-skin arrays/replaced entry Dictionary")
func finish() -> void:
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"coverage":coverage,"scope":"Bit-exact CPU bone/mesh/clock/event/attachment oracle, no GPU/FPS acceptance"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file: FileAccess=FileAccess.open(arg.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func run() -> void:
	if not ClassDB.class_exists("NwnRigSkinPublisher"):check(false,"Private engine publisher exists");finish();return
	check(int(ClassDB.class_call_static("NwnRigSkinPublisher","abi_version"))==2,"Versioned actual publisher")
	compare_case(false);compare_case(true);finish()
