extends SceneTree
const Preparation=preload("res://tests/nwn71_pipeline_preparation.gd")
var output:=""
var checks:=0
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	for mode in ["rid","exact_draw"]:
		var job:=Preparation.new()
		check(not job.handoff(),"unrequested case cannot hand off")
		check(job.open(root,mode,710003),"case opens with bounded explicit mode")
		check(not job.open(root,mode,710003),"open is one-shot")
		check(job.cover.visible and job.phase=="covered","same loading fence starts visible")
		check(job.snapshot().cover_full_size and job.snapshot().cover_opaque,"loading cover actually fills theviewport opaquely")
		check(job.request_material(),"actual geometry/material created andget_rid requested")
		var identity: Dictionary=job.identity()
		check(identity.surface_count==1 and not identity.geometry_sha256.is_empty(),"real geometry/layout fingerprint recorded")
		check(job.mesh.is_visible_in_tree() and job.mesh.get_viewport()==root,"actual mesh is renderable behindcover in the same viewport")
		check(not job.request_material(),"material/resources cannot be silently recreated")
		if mode=="exact_draw":
			check(not job.handoff(),"prepared mode fences readiness until actual draw boundary")
			check(job.draw_preparation(),"exactdraw plus sync completes the preparation fence")
			check(not job.preparation_draw_completed(),"preparation completion is one-shot")
		else:check(not job.preparation_draw_completed(),"get_rid mode never pretends to have prepared pipelines")
		check(job.handoff(),"handoff hides cover after its mode contract")
		check(not job.cover.visible and job.phase=="ready","ready fence releases exactly once")
		check(not job.handoff(),"handoff is one-shot")
		check(job.draw_visible(),"exact first visible draw plus sync accounted")
		check(job.identity()==identity,"exact resources/geometry/layout never swapped across handoff")
		check(job.prepared_draws==(1 if mode=="exact_draw" else 0) and job.visible_draws==1,"preparation andvisible draws counted independently")
		cases.append(job.snapshot());job.close();job.close();check(job.phase=="closed" and job.world==null and job.cover==null,"close is safe and leaves no fixture scene")
	var cancelled:=Preparation.new();check(cancelled.open(root,"exact_draw",1) and cancelled.request_material(),"cancellable preparation created");cancelled.close();check(not cancelled.handoff() and not cancelled.preparation_draw_completed(),"cancelled case cannot become ready")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Headless correctness only: real scene resources, exactviewport/layout identity, cover/ready lifecycle and cancellation. Dummy renderer does not verify graphics-pipeline preparation or performance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
