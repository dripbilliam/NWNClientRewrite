extends SceneTree
const Boundary=preload("res://tools/native_parity/visibility/camera_boundary.gd")
const FrozenTangents=preload("res://tools/native_parity/visibility/camera_tangent_words.gd")
const Provider=preload("res://tools/native_parity/visibility/camera_tangent_candidate_provider.gd")
const Candidate=preload("res://tools/native_parity/visibility/camera_tangent_candidate.gd")
const Collector=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const Controller=preload("res://systems/camera_controller.gd")
const Runtime=preload("res://systems/native_client_clock_runtime.gd")
const Services=preload("res://systems/native_data/client_clock_services.gd")
const WorldClock=preload("res://systems/native_data/world_timer.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const FovBinding=preload("res://tools/native_parity/ui/camera_fov_binding.gd")
class Counter extends RefCounted:
	var reads:=0
	func read() -> Dictionary:
		var result:=WorldClock.words_from_int(reads*1000);reads+=1;return result
var checks:=0
var failures: Array=[]
var scope:={"connection":7,"generation":3,"area_id":20,"world_id":42}
var active:=true
var callback_change:=""
var boundary
var camera: Camera3D
var controller
var runtime
var service
var provider
var calls:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func guard(where: Dictionary,frame: int,occurrence: int) -> bool:return active and where==scope and frame==1 and occurrence>=0
func bind() -> void:check(boundary.bind(camera,controller,runtime,scope,guard,provider).available,"Candidate subtype accepted by frozen typed Boundary.bind")
func pose() -> void:
	controller.configure(camera,Vector3(1,3,-2));controller.enable_follow(1,Vector3(1,3,-2),1.0,{},controller.follow_state);controller.follow_frame(Vector3(1,3,-2),15,0,.016)
func capture() -> Dictionary:return boundary.capture(scope,1,1)
func collect(where: Dictionary,native_camera: Dictionary,primary: Dictionary) -> Dictionary:
	calls+=1
	check(where==scope and primary==service.reveal_timing(1).snapshot_words,"Frozen boundary passes exact scope and primary snapshot")
	var planes:=Collector.camera_planes(native_camera)
	check(planes.available and planes.planes.size()==6,"Fractional tangent feeds unchanged six-plane collector interface")
	if callback_change=="fov":camera.fov+=.125
	elif callback_change=="retire":active=false
	return {"available":planes.available,"planes":planes.get("planes",[]),"delta_t_word":Collector.word(Collector.renderer_delta_t(primary).delta_t)}
func run() -> void:
	var output:="";var original:="";var old_original:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--oracle="):original=arg.substr(9)
		elif arg.begins_with("--old-oracle="):old_original=arg.substr(13)
	if output.is_empty() or original.is_empty() or old_original.is_empty() or FileAccess.file_exists(output):quit(2);return
	provider=Provider.new()
	check(not provider.lookup(63.125).available,"Candidate provider needs explicit cold authority binding")
	check(not provider.load_original_sse(old_original).available,"Old two-angle corpus cannot certify scalar candidate")
	var loaded: Dictionary=provider.load_original_sse(original)
	check(loaded.available and loaded.executed_original_cases==5882 and loaded.implementation=="scalar-domain-port","Candidate source/corpus/original constant authority admitted")
	check(not loaded.native_live_branch_observed and not loaded.fma_parity_accepted and loaded.branch=="original-sse","Authority explicitly excludes native live dispatch and FMA parity")
	check(not provider.load_original_sse(original).available,"Candidate provider authority cannot be replaced after bind")
	var typed: FrozenTangents=provider
	var fractional:=typed.lookup(63.125)
	check(fractional.available and fractional.half_tangent_word==Candidate.evaluate(63.125,"original-sse").half_tangent_word,"Base-typed dispatch uses original SSE fractional scalar implementation")
	var proof: Dictionary=provider.authority();proof.branch="fma"
	check(provider.authority().branch=="original-sse","Authority receipts detached")
	var old:=FrozenTangents.new();check(old.load_original_sse(old_original).available,"Frozen original cache still binds its original corpus")
	check(old.lookup(45).available and old.lookup(90).available and not old.lookup(63.125).available and not old.lookup(80).available,"Frozen old cache policy unchanged45/90 only")
	var viewport:=SubViewport.new();viewport.size=Vector2i(800,600);viewport.own_world_3d=true;root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=.1;camera.far=200
	controller=Controller.new();viewport.add_child(controller);controller.set_process(false);pose()
	var settings:=Settings.new();root.add_child(settings);settings.setup("user://candidate-fov.cfg","")
	var binding:=FovBinding.new();binding.configure(settings);check(binding.bind(camera) and camera.fov==45,"Actual Settings owner and FOV Binding start at native default")
	var counter:=Counter.new();service=Services.new()
	check(service.construct_process(counter.read,{"processConstructionKnown":true}).ready and service.attach_connection(7).ready and service.set_scope([7,3,20]).ready and service.begin_frame(1).ready,"Actual primary clock service and prefix established")
	check(service.receive_clock({"kind":"native-clock-protocol","version":1,"connection":7,"serial":1,"history":{"complete":true},"scope":{"generation":3,"areaId":20},"event":{"type":"begin","lifecycleBound":true}}).ready,"Actual accepted begin clock history")
	runtime=Runtime.new();runtime.enabled=true;runtime.ready=true;runtime.connection=7;runtime.current_scope=[7,3,20];runtime.current_frame=1;runtime.services=service
	boundary=Boundary.new();bind()
	settings.fov_control.value=80
	check(settings.fov_degrees==80 and camera.fov==80 and capture().available,"Ordinary real slider80 now has native tangent at frozen boundary")
	var persisted:=ConfigFile.new();persisted.load("user://candidate-fov.cfg")
	check(persisted.get_value("rendering","fov_degrees")==80,"Actual setting persistence remains intact")
	# The shipped HSlider deliberately steps integer degrees. Drive its actual
	# typed owner signal for a fractional authored source without claiming the
	# integer slider emitted a fraction or changing its production step policy.
	settings.fov_degrees=63.125;settings.fov_changed.emit(settings.fov_degrees)
	var first:=capture()
	check(camera.fov==63.125 and first.available and first.camera.angle==63.125,"Actual Settings signal/Binding/Camera3D preserve fractional FOV")
	check(first.tangent_corpus_sha256==Provider.CANDIDATE_CORPUS_SHA256 and first.tangent_branch=="original-sse","Frozen receipt carries honest candidate corpus and SSE branch")
	check(first.camera.half_tangent_angle_word==Collector.word(camera.fov) and first.camera.half_tangent_word==fractional.half_tangent_word,"Exact current fractional native angle word linked to candidate tangent")
	check(boundary.collect(scope,1,1,collect).available,"Fractional FOV composes with actual frozen boundary and native-plane consumer")
	for angle in [20.125,33.333333,80.125,90.0625,119.875]:
		var before:=capture();settings.fov_degrees=angle;settings.fov_changed.emit(angle)
		check(not boundary.current(before),"Later fractional Settings signal invalidates old projection receipt")
		var after:=capture();check(after.available and after.camera.angle==Collector.f(angle),"Ordinary arbitrary fractional FOV admitted")
	camera.fov=1.125;check(capture().available,"Authored perspective below slider range uses ordinary native domain")
	camera.fov=178.875;check(capture().available,"Authored perspective above slider range uses ordinary native domain")
	check(binding.bind(camera) and camera.fov==178.875 and capture().available,"Same-camera binding preserves later authored fractional FOV")
	for size in [Vector2i(1600,900),Vector2i(900,1200)]:
		var before:=capture();viewport.size=size
		check(not boundary.current(before),"Resize retires previous fractional projection receipt")
		var after:=capture();check(after.available and after.camera.aspect==Collector.f(float(size.x)/size.y),"Candidate fraction retained at actual effective resized aspect")
	var old_camera:=camera;var old_receipt:=capture()
	camera=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=.1;camera.far=200
	check(not boundary.current(old_receipt),"Recreated physical camera cannot inherit prior lease")
	pose();check(binding.bind(camera) and camera.fov==Collector.f(settings.fov_degrees),"Actual binding applies latest fractional owner value to recreated camera")
	check(not capture().available,"Frozen boundary remains bound to old physical camera until explicit rebind")
	bind();check(capture().available,"Explicit source-owner rebind admits recreated camera")
	old_camera.free()
	callback_change="fov";check(not boundary.collect(scope,1,1,collect).available,"Reentrant fractional FOV change rejects stale collector output")
	callback_change="retire";check(not boundary.collect(scope,1,1,collect).available,"Reentrant world retirement rejects collected planes");active=true;callback_change=""
	runtime.connection=8;runtime.current_scope=[8,3,20];check(not capture().available,"Reconnect fences reused fractional camera source");runtime.connection=7;runtime.current_scope=[7,3,20]
	check(counter.reads==6,"Composition samples no new primary/GUI/OS clock")
	boundary.close();binding.close();settings.free();controller.free();camera.free();viewport.free();runtime.ready=false;runtime.services=null;service.cleanup_connection();service.destroy_process()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"authority":provider.authority(),"collector_calls":calls,"absolute_provider_reads":counter.reads,"candidate_differential_repeated":false,"extensions":0,"gpu_draws":0,"native_builds":0,"server_connections":0,"production_hooks":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NATIVE_CAMERA_TANGENT_BOUNDARY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
