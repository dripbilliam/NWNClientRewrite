extends SceneTree
const Rigs=preload("res://systems/model_rigs.gd")
const Bones=preload("res://systems/native_render/skeletal_rigs.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var pivot:=Node3D.new(); root.add_child(pivot)
	var rests: Array=[{"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]},{"position":[0.3,0.7,-0.2],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.1,0.8,1.2]}]
	var tracks: Array=[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0.0,0.0,0.0]},{"time":1.0,"value":[1.0,2.0,3.0]}],"sourceInterpolation":"linear"},{"part":1,"property":"quaternion","keys":[{"time":0.0,"value":[0.0,0.0,0.0,1.0]},{"time":1.0,"value":[0.0,sin(0.5),0.0,cos(0.5)]}],"sourceInterpolation":"slerp"}]
	var curve:={"part":0,"property":"position","sourceInterpolation":"bezier","keys":[{"time":0.0,"value":[0.0,0.0,0.0],"in":[0.0,0.0,0.0],"out":[0.3,1.0,-0.1]},{"time":1.0,"value":[1.0,2.0,3.0],"in":[-0.4,-0.3,0.8],"out":[0.0,0.0,0.0]}]}
	var asset:={"defaults":rests,"clips":[{"name":"linear","length":1.0,"transition":0.0,"events":[{"time":0.3,"name":"step"}],"tracks":tracks},{"name":"curve","length":1.0,"transition":0.0,"events":[],"tracks":[curve]},{"name":"idle","length":1.0,"transition":0.0,"events":[],"tracks":[]}],"unsupported":[]}
	var source:={"id":42,"nodes":[],"models":[{"asset":0,"parts":[0,1],"defaults":rests,"follow":true,"clip":"idle","loop":true}],"clipMap":{"0":"idle","2":"linear","3":"curve"}}
	for index in 2: source.nodes.append({"name":"bone"+str(index),"parent":index-1,"position":rests[index].position,"quaternion":rests[index].quaternion,"scale":rests[index].scale})
	var metadata:={"rigs":{"version":1,"assets":[asset],"entities":[source]},"meshes":[]}
	var legacy:=Rigs.new(); pivot.add_child(legacy); legacy.configure({"meshes_by_name":{}},{42:pivot},metadata); legacy.set_process(false)
	var bones:=Bones.new(); pivot.add_child(bones); bones.configure({"meshes_by_name":{}},{42:pivot},metadata); bones.set_process(false)
	check(legacy.stats.failures.is_empty() and bones.stats.failures.is_empty(),"Both authored physical graphs install")
	var events_old: Array=[]; var events_bones: Array=[]
	legacy.model_event.connect(func(_id,index,name,_serial): events_old.append([index,name]))
	bones.model_event.connect(func(_id,index,name,_serial): events_bones.append([index,name]))
	var maximum_error:=0.0
	for code in [2,3,0,2]:
		legacy.set_playback(42,code); bones.set_playback(42,code)
		for frame in 25:
			legacy._update(0.05); bones._update(0.05)
			for index in 2:
				var before: Transform3D=legacy.entities[42].nodes[index].transform
				var after: Transform3D=bones.entities[42].skeleton.get_bone_pose(index)
				maximum_error=maxf(maximum_error,before.origin.distance_to(after.origin))
				check(before.is_equal_approx(after),"Bone pose retains linear/Bezier/slerp/rest-reset data %d/%d/%d"%[code,frame,index])
				var global_before: Transform3D=legacy.entities[42].root.global_transform.affine_inverse()*legacy.entities[42].nodes[index].global_transform
				check(global_before.is_equal_approx(bones.entities[42].skeleton.get_bone_global_pose(index)),"Native bone hierarchy retains original parent/scale composition")
	check(events_old==events_bones and not events_old.is_empty(),"Physical model events and loop intervals are unchanged")
	var attachment: Node3D=bones.node_at(42,1); check(attachment is BoneAttachment3D and bones.node_for(42,0,"bone1")==attachment,"References address the original physical bone through a native attachment")
	legacy.forget_entity(42); bones.forget_entity(42); pivot.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"maximum_position_error":maximum_error,"scope":"Authored linear/Bezier/slerp/scale/loop/event/rest and bone attachment comparison. Original models, actual GPU skinning, picking and performance remain separate."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures,"maximum_position_error":maximum_error})); quit(0 if failures.is_empty() else 1)
