extends SceneTree
# Component process-callback timing only; never records frame intervals or FPS.
const Rigs=preload("res://systems/model_rigs.gd")
const Original=preload("res://.cache/nwn65/baseline/model_rigs.gd")
class Early extends Node:
	var began:=0
	func _process(_delta: float) -> void:began=Time.get_ticks_usec()
class Late extends Node:
	var early: Node
	var warm:=0
	var limit:=0
	var samples: Array=[]
	var collecting:=false
	func _process(_delta: float) -> void:
		if not collecting:return
		if warm>0:warm-=1;return
		samples.append(Time.get_ticks_usec()-early.began)
		if samples.size()>=limit:collecting=false
var options: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
func create(script,id: int) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var rig=script.new();host.add_child(rig)
	var rest:={"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}
	var data:={"rigs":{"version":1,"assets":[{"defaults":[],"clips":[]}],"entities":[{"id":id,"nodes":[{"name":"root","parent":-1,"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale}],"models":[{"asset":0,"parts":[0]}]}]},"meshes":[]}
	rig.configure({"meshes_by_name":{}},{id:host},data)
	return {"host":host,"rig":rig}
func summary(values: Array) -> Dictionary:
	values.sort();var sum:=0
	for value in values:sum+=int(value)
	return {"samples":values.size(),"median_us":values[int(ceil(values.size()*0.5))-1],"p95_us":values[int(ceil(values.size()*0.95))-1],"p99_us":values[int(ceil(values.size()*0.99))-1],"mean_us":float(sum)/values.size()}
func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	var early:=Early.new();early.process_priority=-1000000;root.add_child(early)
	var late:=Late.new();late.early=early;late.process_priority=1000000;root.add_child(late)
	var old: Array=[];var current: Array=[]
	for id in 80:old.append(create(Original,id));current.append(create(Rigs,id))
	check(old.all(func(row):return row.rig.is_processing()) and current.all(func(row):return not row.rig.is_processing()),"Exactly80 eligible static owners per side use their respective scheduling policy")
	var legs: Array=[]
	for mode in ["reference","optimized","optimized","reference"]:
		for row in old:row.rig.set_process(mode=="reference")
		var before:=0
		for row in old:before+=int(row.rig.stats.pose_frames)
		var current_before:=0
		for row in current:current_before+=int(row.rig.stats.pose_frames)
		late.samples=[];late.warm=8;late.limit=160;late.collecting=true
		while late.collecting:await process_frame
		var after:=0
		for row in old:after+=int(row.rig.stats.pose_frames)
		var current_after:=0
		for row in current:current_after+=int(row.rig.stats.pose_frames)
		check(after-before==80*168 if mode=="reference" else after==before,"Actual original callback count matches selected mode "+mode)
		check(current_after==current_before,"Optimized static owners perform zero process callbacks "+mode)
		legs.append({"mode":mode,"timing":summary(late.samples.duplicate()),"reference_callbacks":after-before,"optimized_callbacks":current_after-current_before})
	for row in old+current:row.host.free()
	early.free();late.free();await process_frame
	var report:={"issue":"NWN-65","success":failures.is_empty(),"checks":checks,"failures":failures,"order":"A-B-B-A","eligible_owners":80,"legs":legs,"scope":"Normal Core E real SceneTree process callback window for80 fully static rigid owners without animation/manual poses/attachments/skins. Fixture population only; no live-capture eligible-owner census, whole-frame intervals, loading or FPS measurement."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN65_RIG_IDLE_COST ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
