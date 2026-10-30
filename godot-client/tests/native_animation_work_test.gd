extends SceneTree
const Rigs=preload("res://systems/model_rigs.gd")
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
	var rest:={"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}
	var asset:={"defaults":[rest],"clips":[{"name":"walk","length":1.0,"transition":0.0,"events":[{"time":0.1,"name":"tick"}],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0.0,0.0,0.0]},{"time":1.0,"value":[1.0,0.0,0.0]}],"sourceInterpolation":"linear"}]}],"unsupported":[]}
	var models: Array=[]
	for index in 30: models.append({"asset":0,"parts":[0],"defaults":[rest],"follow":true})
	for index in 2: models.append({"asset":1,"parts":[index],"defaults":[rest],"follow":true,"clip":"walk","loop":true})
	var source:={"id":42,"nodes":[],"models":models,"clipMap":{"4":"walk"},"animationSource":30}
	for index in 2: source.nodes.append({"name":"bone"+str(index),"parent":-1,"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale})
	var rigs:=Rigs.new(); root.add_child(rigs); rigs.configure({"meshes_by_name":{}},{42:pivot},{"rigs":{"version":1,"assets":[{"defaults":[],"clips":[]},asset],"entities":[source]},"meshes":[]}); rigs.set_process(false)
	check(rigs.stats.failures.is_empty(),"Authored multipart rig installs")
	check(rigs.entities[42].models.size()==32 and rigs.entities[42].animated_models==[30,31],"All physical models retained; only two animated models enter the per-frame animation loop")
	var events: Array=[]; rigs.model_event.connect(func(_id,index,name,_serial): events.append([index,name]))
	rigs.set_playback(42,4); rigs._update(0.2)
	for index in 2: check(absf(rigs.entities[42].nodes[index].position.x-0.2)<0.00001,"Original model index %d advances its bound node"%(30+index))
	check(events==[[30,"tick"],[31,"tick"]],"Events retain physical model indices and original order")
	rigs.set_manual_pose(42,rigs.entities[42].nodes[0],Vector3(3,4,5),Quaternion.IDENTITY); rigs._update(0.1)
	check(rigs.entities[42].nodes[0].position==Vector3(3,4,5),"Manual pose still applies independently of the animated-model selection")
	rigs.forget_entity(42); check(rigs.entities.is_empty() and rigs.stats.players==0,"Selected-loop ownership retires normally")
	rigs.free(); pivot.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored multipart rig retains all models, exact bound poses and physical event indices while skipping models with no animation owner."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
