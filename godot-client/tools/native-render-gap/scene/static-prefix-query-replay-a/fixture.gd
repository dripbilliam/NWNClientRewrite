extends SceneTree
# SOURCE-ONLY mock contract/codec test. It does NOT exercise real world collision,
# a built native cursor, rendering, driver activation or movement authority.
const Replay=preload("res://tools/native-render-gap/scene/static-prefix-query-replay-a/query_replay.gd")
class FakeAssets extends RefCounted:
	var closed:=false
	var pending: Array=[]
	var running: Dictionary={}
class FakeMotion extends RefCounted:
	var objects: Dictionary={}
class FakeWorld extends Node3D:
	var generation:=2
	var area_id:=7
	var controlled_id:=9
	var motion:=FakeMotion.new()
	var desired: Dictionary={}
	var complete:=true
	func ready_for_control()->bool:return true
	func snapshot(_full: bool)->Dictionary:return {"object_visuals_complete":complete}
class FakeOwner extends Node:
	var world: FakeWorld
	var assets:=FakeAssets.new()
	var closed:=false
	var source_batch:=false
	var dirty_groups: Dictionary={}
	var requests: Dictionary={}
	var pending_models: Dictionary={}
	var model_queue: Array=[]
	var wanted_models: Dictionary={}
	var source_rows: Dictionary={}
	var spatial_ticket: Dictionary={}
	var publication_revision:=1
	var preview_revision:=1
	var model_versions: Dictionary={"fixture":1}
	var static_groups: Dictionary={}
	var arguments_seen: Array=[]
	var helper
	var retire_witness:=false
	func ready()->bool:return not closed
	func static_candidates(from: Vector3,to: Vector3,radius: float,exclude: int)->Dictionary:
		if helper!=null:helper.capture_query(self,from,to,radius,exclude)
		var bytes: PackedByteArray=Replay.encode_arguments(from,to,radius,exclude);arguments_seen.append(bytes)
		if retire_witness:source_rows[exclude].witness=[0x7fffffffffffffff,2]
		return {"ready":true,"rows":[{"packet":bytes.hex_encode(),"witness":[0x7fffffffffffffff,1]}]}
var checks: Array=[]
var output:=""
func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func make_fixture()->Dictionary:
	var world:=FakeWorld.new()
	world.motion.objects[9]={"lifetime":88,"position":Vector3(1,2,3),"render":Vector3(1,2,3),"orientation":Vector3(1,0,0),"targetOrientation":Vector3(1,0,0),"path":[],"active":false,"script":0,"driveHeld":false}
	world.desired[9]={"object":{"replicated":{"position":[1.0,2.0,3.0]}}}
	var owner:=FakeOwner.new();owner.world=world
	owner.source_rows[9]={"witness":[0x7fffffffffffffff,1]}
	owner.spatial_ticket={"ready":true,"epoch":1,"scope":[world.get_instance_id(),2,7]}
	var helper:=Replay.new();owner.helper=helper
	var context:={"offline_replay":true,"timeline_delivered":true,"movement_gates_passed":true,"connection":3,"keyboard_released":true,"all_scene_assets_idle":true,"camera_signature":"exact-native-camera-fixture".to_utf8_buffer()}
	check(helper.begin_capture(owner,3).accepted,"Fresh same-process owner capture begins")
	return {"world":world,"owner":owner,"helper":helper,"context":context}
func dispose(value: Dictionary)->void:value.owner.helper=null;value.owner.free();value.world.free();value.clear()
func capture_one(value: Dictionary)->void:value.helper.capture_query(value.owner,Vector3(1,2,3),Vector3(4,5,6),0.5,9)
func codec()->void:
	var bit:=PackedByteArray();bit.resize(8);bit.encode_u64(0,0x3ff0000000000001);var radius:=bit.decode_double(0)
	var zero:=PackedByteArray();zero.resize(4);zero.encode_u32(0,0x80000000);var negative_zero:=zero.decode_float(0)
	var bytes: PackedByteArray=Replay.encode_arguments(Vector3(negative_zero,1.0,-2.0),Vector3(3.0,-4.0,5.0),radius,0x7ffffffffffffffe)
	check(bytes.size()==40,"Fixed40B query record")
	check(bytes.decode_u32(0)==0x80000000,"Signed zero Vector3 coordinate exact bits")
	check(bytes.decode_u64(24)==0x3ff0000000000001,"F64 radius ULP survives without JSON parser")
	check(bytes.decode_s64(32)==0x7ffffffffffffffe,"I64 exclusion beyond JSON exact integer bound survives")
	var decoded: Dictionary=Replay.decode_arguments(bytes)
	check(Replay.encode_arguments(decoded.from,decoded.to,decoded.radius,decoded.exclude)==bytes,"Complete actual packed argument round trip")
	check(Replay.decode_arguments(PackedByteArray()).is_empty(),"Malformed record rejected")
func bounded_pass()->void:
	var value:=make_fixture()
	for index in 130:value.helper.capture_query(value.owner,Vector3(index,2,3),Vector3(index+1,2,3),0.5,9)
	var snapshot: Dictionary=value.helper.snapshot()
	check(snapshot.query_count==128 and snapshot.seen==130 and snapshot.capped==2,"Only first128 actual calls retained, cap explicit")
	var copy: Array=value.helper.corpus_copy();copy[0].arguments.encode_s64(32,88);copy.clear()
	check(value.helper.snapshot().arguments_hex[0]==snapshot.arguments_hex[0],"External packet copy cannot mutate private corpus")
	check(value.helper.seal_after_timeline(value.owner,value.context).accepted,"Actual complete+queues+idle scope seals")
	for phase in ["prewarm","measure"]:
		check(value.helper.begin_pass(value.owner,value.context,phase).accepted,"Fresh "+phase+" pass begins")
		for batch in 32:
			var result: Dictionary=value.helper.replay_batch(value.owner,value.context,4)
			check(result.accepted,"Bounded "+phase+" batch "+str(batch))
		var metric: Dictionary=value.helper.snapshot().passes[phase]
		check(metric.complete and metric.calls==128 and metric.batches==32,"Exact whole corpus "+phase+" completion")
	check(value.owner.arguments_seen.size()==256,"Direct prefix API called128+128 times")
	check(value.helper.snapshot().query_count==128,"Recursive capture suppressed during direct replay")
	check(value.helper.snapshot().passes.measure.result_sha256==value.helper.snapshot().passes.prewarm.result_sha256,"Same-corpus results exact across prewarm/measure")
	dispose(value)
func rejected_barriers()->void:
	for mode in ["timeline","visuals","queue","worker","actor-active","actor-script","drive-held","generation","witness","connection","keyboard"]:
		var value:=make_fixture();capture_one(value)
		if mode=="timeline":value.context.timeline_delivered=false
		elif mode=="visuals":value.world.complete=false
		elif mode=="queue":value.owner.pending_models.fixture=true
		elif mode=="worker":value.owner.assets.running[1]=1
		elif mode=="actor-active":value.world.motion.objects[9].active=true
		elif mode=="actor-script":value.world.motion.objects[9].script=1
		elif mode=="drive-held":value.world.motion.objects[9].driveHeld=true
		elif mode=="generation":value.world.generation=3
		elif mode=="witness":value.owner.source_rows[9].witness=[0x7fffffffffffffff,2]
		elif mode=="connection":value.context.connection=4
		elif mode=="keyboard":value.context.keyboard_released=false
		check(not value.helper.seal_after_timeline(value.owner,value.context).accepted,"Reject seal barrier: "+mode)
		check(value.owner.arguments_seen.is_empty(),"Rejected "+mode+" never executes queries")
		dispose(value)
	for mode in ["publication","camera","actor","witness-during-query"]:
		var value:=make_fixture();capture_one(value);check(value.helper.seal_after_timeline(value.owner,value.context).accepted,"Fresh sealed "+mode)
		if mode=="publication":value.owner.publication_revision+=1
		elif mode=="camera":value.context.camera_signature="changed-camera".to_utf8_buffer()
		elif mode=="actor":value.world.motion.objects[9].render.x+=1.0
		elif mode=="witness-during-query":
			check(value.helper.begin_pass(value.owner,value.context,"prewarm").accepted,"Begin dynamic retirement test")
			value.owner.retire_witness=true
			check(not value.helper.replay_batch(value.owner,value.context,1).accepted,"Post-batch captured lifetime retirement rejects")
			check(value.owner.arguments_seen.size()==1,"Retirement only reached one bounded direct query")
			check(value.helper.snapshot().replaying==false,"Rejected callback does not leave replay active")
			dispose(value);continue
		check(not value.helper.begin_pass(value.owner,value.context,"prewarm").accepted,"Reject post-seal drift: "+mode)
		check(value.owner.arguments_seen.is_empty(),"Drift rejected before query: "+mode)
		dispose(value)
func _initialize()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	call_deferred("run")
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	codec();bounded_pass();rejected_barriers()
	await process_frame;await process_frame
	var success:=checks.all(func(row):return row.ok)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":checks,"scope":"Actual future Godot MOCK helper codec/ownership/barriers only. Does not validate native G/collision route/world rendering or authority. Source preparation alone is not execution."}));file.close();quit(0 if success else 1)
