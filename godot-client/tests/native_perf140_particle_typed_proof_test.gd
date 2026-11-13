extends "res://tests/native_perf140_particle_common_input_test.gd"
class IdentityScript extends Node3D:
	func witness() -> String:return "Same native Node3D after script assignment"
var proof_hits:=0
func _init() -> void:
	experiment_mode="reuse_typed_proof"
	experiment_scope="Independent native Node3D ancestry witness versus repeated casts, with a live full ObjectID lookup every use. Exact mutation/state/geometry/RNG, null/freed/wrong-native-type, original one-shot configuration rejection, failed initial configure/retry, script assignment and reparent cases. No graphical or FPS acceptance."
func owner_options(reuse: bool) -> Dictionary:return {"reuseTypedProof":reuse}
func inspect_pair(a: Dictionary,b: Dictionary) -> void:
	check(a.typed_proofs.hits==0,"Ordinary oracle never reuses native ancestry")
	proof_hits=maxi(proof_hits,int(b.typed_proofs.hits))
func typed_edges(reuse: bool) -> void:
	var detached:=Node3D.new()
	check(not detached.is_inside_tree() and detached.is_visible_in_tree(),"Pinned engine visibility query alone does not imply tree membership")
	detached.free()
	var scene:=Node3D.new();root.add_child(scene)
	var source:=Node3D.new();scene.add_child(source)
	var node:=Node3D.new();source.add_child(node)
	var wrong:=Node.new();scene.add_child(wrong)
	var seed_owner:=make_owner(false,"fountain",32|128|16,false,false)
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var config:={"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":source.get_instance_id(),"reuseTypedProof":reuse}
	check(not owner.call("dispatch",0,config,{}).has("error"),"Typed lifetime owner configures")
	seed_owner.providers.clear()
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(107)
	var services:={"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass}
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":services,"culling":false,"reuse_typed_proof":reuse}).has("error"),"Typed lifetime member registers")
	for serial in 2:check(not presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(15000000+serial,false)}).has("error"),"Typed witness exercises a repeated live instance")
	node.set_script(IdentityScript);node.reparent(scene,true)
	check(not presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(15000002,false)}).has("error"),"Script assignment/reparent retain native Node3D ancestry")
	check(owner.call("dispatch",0,config,{}).has("error"),"A configured owner still rejects reconfiguration before changing its identity")
	var wrong_owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	config.poseId=wrong.get_instance_id()
	check(wrong_owner.call("dispatch",0,config,{}).has("error"),"Initial configuration still rejects a non-Node3D before admitting it")
	config.poseId=node.get_instance_id()
	check(not wrong_owner.call("dispatch",0,config,{}).has("error"),"An unconfigured owner can retry after initial type failure")
	check(not presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(15000004,false)}).has("error"),"The valid owner retains its original source after rejected reconfiguration")
	var retired_id:=source.get_instance_id();source.free()
	var replacement:=Node.new();scene.add_child(replacement)
	check(replacement.get_instance_id()!=retired_id,"A replacement has a different full engine lifetime")
	var skipped: Dictionary=presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(15000005,false)})
	check(not skipped.has("error") and skipped.prepared==0,"Presentation still resolves live source identity and skips the freed lifetime")
	var direct: Dictionary=owner.call("dispatch",1,{"clip":"","time":0.0,"delta":0.01,"view":view_packet(15000006,false),"source_flags":0,"culling":false,"capacity":0},services)
	check(direct.has("error"),"The direct pose path still rejects a freed source before using its saved numeric address")
	presentation.call("dispatch",5,{});services.clear();presentation=null;owner=null;wrong_owner=null;scene.free()
func finish_experiment(_groups: Array) -> void:
	check(proof_hits>0,"Candidate actually avoids repeated native casts")
	typed_edges(false);typed_edges(true)
