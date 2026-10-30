extends SceneTree
const Cue=preload("res://systems/native_data/movement_cue.gd")
const Motion=preload("res://systems/network_motion.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok and failures.size()<30: failures.append(reason); print("FAIL ",reason)
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-network-correction-observations.json"))
	check(source.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and source.cases.size()==208,"Pinned complete original correction/queue corpus")
	var index:=0; var queued:=0
	for row in source.cases:
		var c: Dictionary=row.case
		var state:={"position":Motion.vector(c.position),"render":Motion.vector(c.render),"orientation":Motion.vector(c.orientation),"animation":int(c.animation),"correction":int(c.timer)}
		var point:=Motion.correct(state,state.position,int(c.dt))
		check(point.distance_to(Motion.vector(row.render))<0.000002 and int(state.correction)==int(row.timer),"Original correction position/timer "+str(index))
		var request: Variant=state.get("correctionCue")
		check((request is Dictionary)==(row.requests.size()==1),"Original correction request presence "+str(index))
		if request is Dictionary:
			var expected_request: Dictionary=row.requests[0]
			check(int(request.animation)==int(expected_request.animation) and int(request.type)==int(expected_request.type) and int(request.duration)==int(expected_request.duration),"Original correction direction/type/WORD duration "+str(index))
			var actual:=Cue.build(request,float(c.clipMs)/1000.0); var expected: Dictionary=row.queues[0]
			check(not actual.has("error") and actual.animation==int(expected.animation) and actual.duration==int(expected.duration) and actual.delay==int(expected.delay) and actual.record==null and absf(float(actual.speed)-float(expected.speed))<0.000002,"Original type6 queued clip/duration/binary32 speed "+str(index)); queued+=1
		index+=1
	check(Cue.build({"animation":24,"type":6,"duration":65536},1.0).has("error"),"Zero low-WORD correction duration is rejected")
	check(Cue.build({"animation":24,"type":6,"duration":65537},1.0).duration==1,"Correction duration uses the original low WORD")
	var turn:=Cue.build({"animation":80},1.5,2.0)
	check(turn.duration==750 and turn.speed==2.0 and turn.record==null,"Null-record turn requests retain ordinary clip/speed timing")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_cases":index,"original_queued_cues":queued,"game_network_connections":0,"scope":"Pinned original correction and queued type6 timing observations plus explicit parameter edges; no gameplay or visual acceptance"},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
