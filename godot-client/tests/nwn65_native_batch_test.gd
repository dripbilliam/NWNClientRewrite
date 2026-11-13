extends SceneTree
const Base=preload("res://systems/model_rigs.gd")
const Candidate=preload("res://tests/nwn65_native_batch_candidate.gd")
const Fixture=preload("res://tests/nwn65_active_event_test.gd")
const ScriptedPlayer=preload("res://tests/nwn65_native_batch_player.gd")
var output:=""
var checks:=0
var failures: Array=[]
var counters: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label);push_error(label)
func equal(before: Dictionary,after: Dictionary,label: String) -> void:
	check(var_to_bytes(Fixture.capture(before))==var_to_bytes(Fixture.capture(after)),label)
func finish() -> void:
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"counts":counters,"rig_sha256":FileAccess.get_sha256("res://systems/model_rigs.gd"),"candidate_sha256":FileAccess.get_sha256("res://tests/nwn65_native_batch_candidate.gd"),"scope":"Private main-thread AnimationPlayer batch; authored active clocks/scene callbacks plus original3-asset event library. No renderer/FPS/live default acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(ClassDB.class_exists("NwnRigAnimationBatch"),"private extension is loaded; do not certify script-only fallback")
	if not failures.is_empty():finish();return
	ProjectSettings.set_setting("nwn/rig_animation_batch",false)
	var off:=Fixture.fixture(self,Candidate,true)
	check(not off.rigs._nwb_enabled,"private feature setting defaults to explicit opt-in")
	off.rigs._update(0.125);check(off.rigs._nwb_contexts.is_empty(),"disabled mode calls unchanged base without native context")
	Fixture.dispose(off);ProjectSettings.set_setting("nwn/rig_animation_batch",true)
	for eventful in [false,true]:
		for reentrant in [false,true]:
			var before:=Fixture.fixture(self,Base,eventful,reentrant);var after:=Fixture.fixture(self,Candidate,eventful,reentrant)
			for frame in 48:
				for row in [before,after]:
					if frame==8:row.host.hide()
					if frame==14:row.host.show()
					if frame==16:row.rigs._play(row.entry.models[0],"motion",true,-1.0,0.4,true)
					if frame==22:row.rigs._play(row.entry.models[0],"motion",false,1.0,0.0,true)
					if frame==30:row.rigs._play(row.entry.models[0],"motion",true,1.0,0.1,true)
					if frame in [3,11,25]:row.entry.manual_poses[1]={"position":Vector3(frame,2,3),"quaternion":Quaternion.IDENTITY,"scale":Vector3.ONE}
					if frame==18:row.entry.attachments[0].flags=3
					if frame==28:row.entry.attachments[0].flags=0
					row.rigs._update(0.125)
				equal(before,after,"native/script mixed-owner clocks/events/manual/attachments %s/%s frame%s"%[eventful,reentrant,frame])
			var info: Dictionary=after.rigs.native_batch_snapshot();counters.append(info)
			check(info.totals.advances>0 and info.totals.fallbacks>0,"actual ordinary advances and same-index native-owner fallback both occurred")
			check(info.totals.failures==0,"mixed-owner case has no concealed native failure")
			Fixture.dispose(before);Fixture.dispose(after)
	# Mutations happen inside the synchronous signal emitted by advance(), well
	# before the original model's event clock fields and next index are read.
	for scenario in ["replace_indices","append_indices","erase_indices","replace_models","post_script","post_script_clear","post_metadata","nested_advance","revoke_entry"]:
		var before:=Fixture.fixture(self,Base,true);var after:=Fixture.fixture(self,Candidate,true)
		var callback_counts: Array=[]
		for row in [before,after]:
			row.entry.animated_models=[0,1]
			var model: Dictionary=row.entry.models[0];var state:={"fired":false,"calls":0}
			callback_counts.append(state)
			model.player.mixer_applied.connect(func():
				state.calls+=1
				if state.fired:return
				state.fired=true
				match scenario:
					"replace_indices":row.entry.animated_models=[2]
					"append_indices":row.entry.animated_models.append(2)
					"erase_indices":row.entry.animated_models.erase(0)
					"replace_models":row.entry.models=[model.duplicate(),row.entry.models[1].duplicate(),row.entry.models[2]];row.entry.models[1].events={"motion":[{"time":0.125,"name":"replacement"}]}
					"post_script":model.player.set_script(ScriptedPlayer)
					"post_script_clear":model.player.set_script(ScriptedPlayer);row.entry.animated_models.clear()
					"post_metadata":model.events={"motion":[{"time":0.125,"name":42}]}
					"nested_advance":row.rigs._update(0.03125)
					"revoke_entry":row.rigs.entities.erase(1)
			)
		for row in [before,after]:row.rigs._update(0.125)
		equal(before,after,"after-advance mutation completes original model/next live index: "+scenario)
		check(callback_counts[0].calls==callback_counts[1].calls,"no prefix/current model was re-advanced: "+scenario)
		var info: Dictionary=after.rigs.native_batch_snapshot();counters.append({"scenario":scenario,"counts":info})
		if scenario.begins_with("post_"):check(info.totals.post_fallbacks==1,"post-advance continuation actually selected: "+scenario)
		if scenario=="nested_advance":check(info.totals.reentrant==1,"nested call used independent original path without taking outer output")
		if scenario=="revoke_entry":check(info.contexts==0,"revoked entry binding releases its retained identity after original attachment phase")
		Fixture.dispose(before);Fixture.dispose(after)
	# A player already carrying a script must fall back BEFORE the same model,
	# preserving exact processing of later ordinary and native-owned models.
	var before:=Fixture.fixture(self,Base,true);var after:=Fixture.fixture(self,Candidate,true)
	for row in [before,after]:row.entry.models[0].player.set_script(ScriptedPlayer);row.rigs._update(0.125)
	equal(before,after,"preexisting scripted player uses original current-index path")
	check(after.rigs.native_batch_snapshot().totals.advances==0,"preexisting unsupported first model did not partially advance")
	Fixture.dispose(before);Fixture.dispose(after)
	original_event_oracle()
	finish()
func original_event_oracle() -> void:
	var native: RefCounted=ClassDB.instantiate("NwnRigAnimationBatch")
	var event_rows:=0;var clips:=0
	for resource in ["a_ba","c_goblina","fx_light_clr"]:
		var file: String="res://.cache/nwn65/original-census-a/"+resource+"-original-events.json"
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
		for clip in data.clips:
			clips+=1;event_rows+=clip.events.size()
			var length:=float(clip.length)
			for span in [[0.0,length,0],[length,0.0,1],[length*0.8,length*0.2,0],[length*0.2,length*0.8,1],[0.0,0.0,2],[0.0,0.0,3]]:
				var result: Dictionary=native.probe_events(clip.events,span[0],span[1],span[2])
				check(result.supported,"original clip metadata admitted: "+resource+"/"+str(clip.name))
				check(result.events==Base.model_events(clip.events,span[0],span[1],span[2]),"original f32 event intervals/wrap/order: "+resource+"/"+str(clip.name))
	var boundary: Array=[{"time":-0.0,"name":"negative_zero"},{"time":0.0,"name":&"zero"},{"time":0.1250000001,"name":"near"},{"time":0.125,"name":"equal"},{"time":NAN,"name":"nan"},{"time":INF,"name":"infinite"}]
	for span in [[0.0,0.125,0],[0.125,0.0,1],[0.2,0.1,0],[0.1,0.2,1],[NAN,0.2,0],[0.1,NAN,1],[-0.0,0.0,2],[0.0,-0.0,3]]:
		var result: Dictionary=native.probe_events(boundary,span[0],span[1],span[2])
		check(result.supported and result.events==Base.model_events(boundary,span[0],span[1],span[2]),"f32 rounding/signed-zero/NaN/StringName event parity")
	check(event_rows==915 and clips==534,"exact bounded original3-asset library has915events/534clips")
	counters.append({"original_clips":clips,"original_event_rows":event_rows,"native_probe_counts":native.inspect()})
