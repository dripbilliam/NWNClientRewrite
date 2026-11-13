extends SceneTree
const Anchor=preload("res://systems/native_data/script_floating_anchor.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Motion=preload("res://systems/network_motion.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var host:=Node3D.new();root.add_child(host);var camera:=Camera3D.new();host.add_child(camera);camera.position=Vector3(0,10,20);camera.look_at(Vector3(0,2,0))
	var row:={"id":42,"areaId":91,"objectType":5,"nativeLifetime":8,"clientKnownLifetime":13};var before:=row.duplicate(true)
	var context:=Scope.context(3,7,91);var witness:=[42,8,13];var scope:=[3,7,91];var point:=Vector3(3,5,-4)
	var shown:=Anchor.project(row,witness,scope,context,point,2.25,camera)
	check(shown.ready and shown.point==Vector3(3,7.25,-4),"Current client pose gains native world-up rise, with no model or interaction-registry dependency")
	check(shown.screen==camera.unproject_position(shown.point) and shown.viewportHeight==root.get_visible_rect().size.y,"Anchor returns raw projected downwards screen plus explicit logical viewport height")
	check(row==before,"Anchor does not change received identity/properties")
	check(not Anchor.project({},witness,scope,context,point,2.0,camera).ready,"Transient source loss remains unavailable instead of adopting origin or controlled character")
	var reused:=row.duplicate();reused.clientKnownLifetime=14
	var stale:=Anchor.project(reused,witness,scope,context,point,2.0,camera)
	check(not stale.ready and not stale.get("retired",false),"ID reuse cannot retarget an old active widget; owner can keep its last display until expiry")
	reused=row.duplicate();reused.nativeLifetime=9
	check(not Anchor.project(reused,witness,scope,context,point,2.0,camera).ready,"Native object replacement cannot retarget the widget")
	check(Anchor.project(row,witness,scope,Scope.context(4,7,91),point,2.0,camera).get("retired",false),"Reconnect retires the old widget scope")
	check(Anchor.project(row,witness,scope,Scope.context(3,8,91),point,2.0,camera).get("retired",false),"Area reentry generation retires old widget scope")
	var wrong:=row.duplicate();wrong.areaId=92
	check(not Anchor.project(wrong,witness,scope,context,point,2.0,camera).ready,"Other-area object cannot supply a pose")
	wrong=row.duplicate();wrong.objectType=9
	check(not Anchor.project(wrong,witness,scope,context,point,2.0,camera).ready,"Noncreature cannot be a native93/94 target")
	for absent in [null,[],Vector3(NAN,0,0)]:check(not Anchor.project(row,witness,scope,context,absent,2.0,camera).ready,"Absent/nonfinite pose remains explicitly unavailable")
	for invalid in [null,true,NAN,INF]:check(not Anchor.project(row,witness,scope,context,point,invalid,camera).ready,"Unknown/malformed height cannot become zero")
	check(not Anchor.project(row,witness,scope,context,point,2.0,null).ready,"Missing camera does not destroy or fabricate display state")
	var detached:=Camera3D.new();check(not Anchor.project(row,witness,scope,context,point,2.0,detached).ready,"Detached camera does not emit engine projection errors");detached.free()
	check(Anchor.project(row,witness,scope,context,camera.position+Vector3(0,0,10),2.0,camera).ready,"No invented behind-camera or viewport gate")
	var motion:=Motion.new();motion.update(0.0004);motion.update(0.0004);motion.update(0.0004)
	check(motion.last_delta_ms==1 and motion.last_delta_frame==Engine.get_process_frames(),"Read-only object-clock quantum preserves existing fractional millisecond accumulator")
	var remainder: float=motion.remainder_ms;motion.update(0.016)
	check(motion.last_delta_ms==16 and is_equal_approx(motion.remainder_ms,remainder),"Exposing current quantum leaves established movement-clock arithmetic unchanged")
	host.free()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"ScriptFloating exact received lifetime + client-pose/no-mesh anchor and nominal movement clock exposure; isolated headless CPU, no rendered pixels or special native timer-selector claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
