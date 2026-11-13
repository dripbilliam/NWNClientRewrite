extends SceneTree

const Rigs=preload("res://systems/model_rigs.gd")
const Original=preload("res://.cache/nwn65/baseline/model_rigs.gd")
const Skeletal=preload("res://systems/native_render/skeletal_rigs.gd")
var checks:=0
var failures: Array=[]
var options: Dictionary={}

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")

func metadata(id: int,animated: bool=false,attachment: bool=false) -> Dictionary:
	var rest:={"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}
	var asset:={"defaults":[rest],"clips":[],"unsupported":[]}
	if animated:
		asset.clips.append({"name":"walk","length":1.0,"transition":0.0,"events":[{"time":0.1,"name":"one"},{"time":0.5,"name":"two"}],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0.0,0.0,0.0]},{"time":1.0,"value":[1.0,0.0,0.0]}],"sourceInterpolation":"linear"}]})
	var source:={"id":id,"nodes":[{"name":"root","parent":-1,"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale}],"models":[{"asset":0,"parts":[0],"defaults":[rest],"follow":true}],"clipMap":{"4":"walk"},"attachments":[]}
	if attachment:
		source.nodes.append({"name":"held","parent":-1,"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale})
		source.attachments.append({"node":1,"anchor":0,"scale":[2.0,2.0,2.0]})
	return {"rigs":{"version":1,"assets":[asset],"entities":[source]},"meshes":[]}

func create(script,id: int,animated: bool=false,attachment: bool=false,offtree: bool=false) -> Dictionary:
	var pivot:=Node3D.new();root.add_child(pivot)
	var rigs=script.new()
	if not offtree:root.add_child(rigs)
	rigs.configure({"meshes_by_name":{}},{id:pivot},metadata(id,animated,attachment))
	return {"rigs":rigs,"pivot":pivot,"id":id}

func dispose(row: Dictionary) -> void:
	if is_instance_valid(row.rigs):row.rigs.free()
	if is_instance_valid(row.pivot):row.pivot.free()

func sample(row: Dictionary) -> Dictionary:
	var entry: Dictionary=row.rigs.entities[row.id]
	return {"transforms":entry.nodes.map(func(node):return node.transform),"playback":row.rigs.playback_state(row.id,0)}

func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	var empty:=Rigs.new();check(not empty.is_processing(),"Empty owner starts unscheduled");root.add_child(empty);check(not empty.is_processing(),"Empty owner stays unscheduled on ready");empty.free()
	var original:=create(Original,1);var optimized:=create(Rigs,2)
	check(original.rigs.is_processing() and not optimized.rigs.is_processing(),"Only fully idle rigid owner loses its empty callback")
	var start_original:=int(original.rigs.stats.pose_frames);var start_optimized:=int(optimized.rigs.stats.pose_frames)
	for frame in 8:await process_frame
	var idle_callbacks:={"reference":int(original.rigs.stats.pose_frames)-start_original,"optimized":int(optimized.rigs.stats.pose_frames)-start_optimized}
	check(int(original.rigs.stats.pose_frames)>start_original and int(optimized.rigs.stats.pose_frames)==start_optimized,"Actual SceneTree callbacks stop only for idle owner")
	optimized.pivot.position=Vector3(4,5,6);check(optimized.rigs.node_at(2,0).global_position==Vector3(4,5,6),"Idle parts still follow parent transforms")
	optimized.pivot.hide();optimized.pivot.show();check(not optimized.rigs.is_processing(),"Visibility changes do not invent idle rig work")
	check(optimized.rigs.set_manual_pose(2,optimized.rigs.node_at(2,0),Vector3(3,2,1),Quaternion.IDENTITY),"Manual pose admitted on idle owner")
	check(optimized.rigs.is_processing(),"Manual-pose ownership wakes callbacks")
	optimized.rigs.node_at(2,0).position=Vector3.ZERO
	await process_frame;await process_frame
	check(optimized.rigs.node_at(2,0).position==Vector3(3,2,1),"Scheduled callback reapplies manual pose")
	var manually_held: Node3D=optimized.rigs.node_at(2,0)
	manually_held.quaternion=Quaternion.from_euler(Vector3(0.2,-0.3,0.1));manually_held.scale=Vector3(2,3,4)
	optimized.rigs._update(0.0)
	check(manually_held.position==Vector3(3,2,1) and manually_held.quaternion==Quaternion.IDENTITY and manually_held.scale==Vector3.ONE,"External rotation and scale edits are corrected by saved manual pose")
	optimized.rigs.forget_entity(2);check(not optimized.rigs.is_processing(),"Final entity retirement suspends owner")
	dispose(original);dispose(optimized)
	var off_idle:=create(Rigs,3,false,false,true);var off_active:=create(Rigs,4,true,false,true)
	check(not off_idle.rigs.is_processing() and off_active.rigs.is_processing(),"Off-tree configure computes exact work state")
	root.add_child(off_idle.rigs);root.add_child(off_active.rigs)
	check(not off_idle.rigs.is_processing() and off_active.rigs.is_processing(),"Tree admission preserves off-tree scheduling")
	off_active.rigs.set_playback(4,4);off_active.pivot.hide()
	var hidden_clock: float=off_active.rigs.playback_state(4,0).time
	await process_frame;await process_frame;await process_frame
	check(float(off_active.rigs.playback_state(4,0).time)>hidden_clock,"Actual scheduled animation clock advances while owner is hidden")
	off_active.pivot.show();var resumed_clock: float=off_active.rigs.playback_state(4,0).time
	await process_frame;await process_frame
	check(float(off_active.rigs.playback_state(4,0).time)>resumed_clock,"Actual visible resume continues the same animation clock")
	dispose(off_idle);dispose(off_active)
	var attach:=create(Rigs,5,false,true);check(attach.rigs.is_processing(),"Unanimated attachment owner remains scheduled")
	attach.rigs.node_at(5,0).position=Vector3(2,3,4);await process_frame;await process_frame
	check(attach.rigs.node_at(5,1).global_position==Vector3(2,3,4) and attach.rigs.node_at(5,1).global_basis.get_scale()==Vector3(2,2,2),"Late anchor movement retains attachment transform/scale")
	attach.rigs.node_at(5,1).global_position=Vector3(99,98,97)
	attach.rigs._update(0.0)
	check(attach.rigs.node_at(5,1).global_position==Vector3(2,3,4) and attach.rigs.node_at(5,1).global_basis.get_scale()==Vector3(2,2,2),"External held-part edits are corrected even after an unchanged attachment frame")
	dispose(attach)
	var skinned:=create(Rigs,10)
	var skeleton:=Skeleton3D.new();skinned.pivot.add_child(skeleton);skeleton.add_bone("root")
	skinned.rigs.entities[10].skins.append({"part":0,"bones":[0],"skeleton":skeleton})
	skinned.rigs._refresh_processing()
	check(skinned.rigs.is_processing(),"Unanimated skinned owner keeps publication callback")
	var skin_forces: Array=[];skeleton.pose_updated.connect(func():skin_forces.append(true))
	skinned.rigs.node_at(10,0).position=Vector3(6,7,8);await process_frame;await process_frame
	check(not skin_forces.is_empty(),"Stationary skin retains original force-update notifications")
	dispose(skinned)
	var donor:=create(Rigs,6,true);var receiver:=Rigs.new();root.add_child(receiver)
	receiver.adopt_entities(donor.rigs,[6]);check(receiver.is_processing(),"Adopting animated content wakes idle receiver")
	donor.rigs.forget_entity(6);check(not donor.rigs.is_processing(),"Donor retirement removes its callback")
	receiver.forget_entity(6);check(not receiver.is_processing(),"Adopted owner retires normally");receiver.free();dispose(donor)
	var a:=create(Original,7,true,true);var b:=create(Rigs,7,true,true)
	a.rigs.set_process(false);b.rigs.set_process(false)
	var events_a: Array=[];var events_b: Array=[]
	a.rigs.model_event.connect(func(id,index,name,serial):events_a.append([id,index,name,serial]))
	b.rigs.model_event.connect(func(id,index,name,serial):events_b.append([id,index,name,serial]))
	a.rigs.set_playback(7,4);b.rigs.set_playback(7,4)
	var equal:=true
	for frame in 37:
		if frame==8:a.pivot.hide();b.pivot.hide()
		if frame==16:a.pivot.show();b.pivot.show()
		if frame==22:a.rigs.set_playback(7,4,-1.0,true,true);b.rigs.set_playback(7,4,-1.0,true,true)
		a.rigs._update(0.1);b.rigs._update(0.1);equal=equal and sample(a)==sample(b)
	check(equal,"Animated, hidden, resumed, reverse and held-part pose/clocks match original")
	check(events_a==events_b and events_b.size()>4,"Model event count/order/serials match original")
	check(not b.rigs.is_processing(),"Explicit caller process pause survives playback changes")
	a.rigs.forget_entity(7);b.rigs.forget_entity(7)
	check(b.rigs.entities.is_empty() and b.rigs.stats.players==0,"Appearance retirement closes player ownership")
	b.rigs.configure({"meshes_by_name":{}},{8:b.pivot},metadata(8,true));check(b.rigs.is_processing(),"Appearance replacement enables new animated owner")
	dispose(a);dispose(b)
	var skeletal:=create(Skeletal,9);check(not skeletal.rigs.is_processing(),"Experimental rigid skeletal owner retains correct idle policy");dispose(skeletal)
	await process_frame
	var report:={"issue":"NWN-65","success":failures.is_empty(),"checks":checks,"failures":failures,"idle_callbacks":idle_callbacks,"events":{"reference":events_a,"optimized":events_b},"scope":"Actual SceneTree idle-owner scheduling plus deterministic original/optimized animation, event, attachment, off-tree/adoption/replacement/retirement checks. No whole-client FPS claim."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NWN65_RIG_SCHEDULING ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
