extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class ActorProbe extends Node3D:
	var rigs
	func setup() -> void:
		rigs=preload("res://systems/model_rigs.gd").new(); add_child(rigs)
		var defaults:=[{"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}]
		var idle:={"name":"pause1","length":1.0,"transition":0.0,"events":[],"tracks":[]}
		var run:={"name":"run","length":1.0,"transition":0.0,"events":[],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0,0,0]},{"time":1.0,"value":[0,1,0]}]}]}
		var source:={"id":1,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"bodyType":1,"nodes":[{"name":"root","parent":-1,"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}],"models":[{"asset":0,"parts":[0],"follow":true,"clip":"pause1","loop":true}],"clipMap":{"0":"pause1","4":"run"}}
		rigs.configure({"meshes_by_name":{}},{1:self},{"rigs":{"version":1,"assets":[{"name":"authored","defaults":defaults,"clips":[idle,run]}],"entities":[source]},"meshes":[]})
		set_meta("native_combat_actor",{"id":1,"lifetime":0,"objectType":5})
	func set_animation(code: int,speed: float) -> void: rigs.set_animation(1,code,speed)
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var owner:=World.new(); root.add_child(owner); owner.set_process(false); owner.area_id=42; owner.generation=7
	var source:={"id":1,"areaId":42,"objectType":5,"appearance":{"appearance":0},"replicated":{"position":[0.0,0.0,3.0],"orientation":{"vector":[1.0,0.0,0.0]},"animation":0,"walkRate":1000.0,"runRate":1000.0}}
	owner.receive([source],1)
	var actor:=ActorProbe.new(); owner.add_child(actor); actor.setup(); owner.instances[1]=actor; owner.installed[1]=owner.signature(source); owner.sync_combat(1)
	owner.motion.adopt([{"id":1,"state":{"modelType":1,"walkDistance":0.5,"runDistance":1.0}}])
	var changes:={"animation":4,"path":[[0.0,0.0],[2.0,0.0]],"field8F4":1,"field8EC":1.0}
	var packet:={"id":1,"revision":1,"created":false,"changes":changes,"initial":source.replicated}
	owner.observe_movement([packet]); check(owner.motion.objects[1].active,"Raw protocol path activates native simulation")
	var previous:=0.0; var maximum_step:=0.0
	for frame in 60:
		owner._process(1.0/60.0)
		var current:=actor.position.x; var step:=current-previous; maximum_step=maxf(maximum_step,step)
		check(step>0 and step<0.025,"Native per-frame progression %d"%frame)
		check(is_equal_approx(actor.position.y,3.0),"Retain original authoritative height %d"%frame)
		if frame%6==0:
			var before: Vector3=actor.position
			owner.receive([source.duplicate(true)],1)
			check(actor.position.is_equal_approx(before),"Repeated registry snapshots do not rewind motion %d"%frame)
		previous=current
	check(absf(actor.position.x-1.0)<0.002,"One second uses original script rate")
	check(actor.rigs.entities[1].animation==4 and absf(actor.rigs.entities[1].models[0].speed-1.0)<0.0001,"Native gait selects original animation and stride speed through actual combat and rig owners")
	owner.observe_movement([packet]); check(owner.stats.stale_movement_records==1,"Duplicate revision is discarded")
	check(absf(owner.motion.objects[1].position.x-1.0)<0.002,"Duplicate path does not restart simulation")
	for frame in 65: owner._process(1.0/60.0)
	check(absf(actor.position.x-2.0)<0.011 and not owner.motion.objects[1].active,"Original path reaches its endpoint and retires its active gait")
	check(actor.rigs.entities[1].animation==0,"Completed gait returns to its original resting animation")
	var before_lifetime:=int(owner.motion.objects[1].lifetime)
	owner.receive([],1)
	check(not owner.motion.objects.has(1) and not owner.motion_revisions.has(1) and owner.instances.is_empty(),"Removal retires pose, revision and instance ownership")
	owner.receive([source],1)
	check(int(owner.motion.objects[1].lifetime)>before_lifetime,"Reused object ID receives a new native motion lifetime")
	owner.observe_movement([{"id":1,"revision":2,"created":true,"changes":{"position":[5.0,0.0,3.0],"animation":0},"initial":{"position":[5.0,0.0,3.0],"animation":0}}])
	check(owner.motion.pose(1).position.is_equal_approx(Vector3(5,3,0)),"Created movement resets old object pose")
	owner.close(); owner.observe_movement([packet])
	check(owner.motion.objects.is_empty() and owner.motion_revisions.is_empty(),"Closed generation ignores late movement")
	owner.free()
	await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"maximum_step":maximum_step,"native_only":true,"live_server_verified":false,"scope":"Headless raw protocol/native live-world movement integration through initialized combat and actual private rig playback; original movement math has a separate retained-binary oracle. No walkmesh, live-server, GPU, WASD or smooth gameplay acceptance."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures,"report":output})); quit(0 if failures.is_empty() else 1)
