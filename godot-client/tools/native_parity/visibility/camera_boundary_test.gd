extends SceneTree
const Boundary=preload("res://tools/native_parity/visibility/camera_boundary.gd")
const Tangents=preload("res://tools/native_parity/visibility/camera_tangent_words.gd")
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const Controller=preload("res://systems/camera_controller.gd")
const GameCamera=preload("res://systems/game_camera_state.gd")
const Runtime=preload("res://systems/native_client_clock_runtime.gd")
const Services=preload("res://systems/native_data/client_clock_services.gd")
const WorldClock=preload("res://systems/native_data/world_timer.gd")
const FovBinding=preload("res://tools/native_parity/ui/camera_fov_binding.gd")
class Counter extends RefCounted:
	var value:=0
	var reads:=0
	func read() -> Dictionary:
		var result:=WorldClock.words_from_int(value);value+=1000;reads+=1;return result
class Settings extends RefCounted:
	signal fov_changed(value: float)
	var fov_degrees:=45.0
var checks:=0
var failures: Array=[]
var scope:={"connection":7,"generation":3,"area_id":20,"world_id":42}
var allow:=true
var guard_mode:=""
var guard_calls:=0
var callback_mode:=""
var viewport: SubViewport
var camera: Camera3D
var controller
var runtime
var service
var counter
var cache
var boundary
var settings
var fov
var callback_count:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func guard(where: Dictionary,frame: int,collection: int) -> bool:
	guard_calls+=1
	if guard_mode=="resize" and guard_calls==2:viewport.size=Vector2i(801,600)
	if guard_mode=="close" and guard_calls==2:boundary.close()
	if guard_mode=="nested" and guard_calls==2:
		guard_mode="";boundary.capture(scope,1,2)
	return allow and where==scope and frame==1 and collection>=0
func bind() -> void:
	guard_calls=0;guard_mode="";allow=true
	check(boundary.bind(camera,controller,runtime,scope,guard,cache).available,"Bind exact physical source owners")
func pose() -> void:
	controller.configure(camera,Vector3(1,3,-2));controller.enable_follow(1,Vector3(1,3,-2),1.0,{},controller.follow_state)
	controller.follow_frame(Vector3(1,3,-2),15,0,0.016)
func packet() -> Dictionary:return boundary.capture(scope,1,1)
func collector(where: Dictionary,native_camera: Dictionary,primary: Dictionary) -> Dictionary:
	callback_count+=1
	check(where==scope and native_camera.position==controller.follow_state.state.position,"Collector receives detached native source position")
	check(primary==service.reveal_timing(1).snapshot_words,"Collector receives exact current primary snapshot words")
	if callback_mode=="mutate-input":native_camera.position[0]=999;primary.lo=99;where.area_id=99
	elif callback_mode=="move":camera.position.x+=1
	elif callback_mode=="fov":camera.fov=90
	elif callback_mode=="far":camera.far+=1
	elif callback_mode=="follow":
		var next:=GameCamera.new();next.state=controller.follow_state.state.duplicate(true);controller.follow_state=next
	elif callback_mode=="services":runtime.services=Services.new()
	elif callback_mode=="clock-frame":runtime.current_frame=2
	elif callback_mode=="retire":boundary.close()
	return {"available":true,"node_ids":PackedInt32Array([4,4]),"delta_t_word":Math.word(Math.renderer_delta_t(primary).delta_t)}
func run() -> void:
	var output:="";var input:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--oracle="):input=arg.substr(9)
	if output.is_empty() or input.is_empty() or FileAccess.file_exists(output):quit(2);return
	cache=Tangents.new()
	check(not cache.lookup(45).available,"Unbound tangent has no host math fallback")
	check(not cache.load_original_sse("res://missing.json").available,"Missing original corpus explicitly unavailable")
	var loaded: Dictionary=cache.load_original_sse(input)
	check(loaded.available and loaded.angles==2,"Pinned original instruction corpus supplies exactly45/90 SSE words")
	check(not cache.load_original_sse(input).available,"Cold authority cannot be silently rebound")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input));var original_cameras:=0
	for item in corpus.cases:
		for original in item.cameras:
			if original.camera.angle<=0:continue
			var t: Dictionary=cache.lookup(float(original.camera.angle))
			check(t.available and t.half_tangent_word==int(original.half_tangent_word) and t.half_tangent_angle_word==Math.word(float(original.camera.angle)),"Original SSE tangent exact word/angle linkage")
			var copy: Dictionary=original.camera.duplicate(true);copy.merge(t,true)
			var planes: Dictionary=Math.camera_planes(copy)
			check(planes.available,"Cached tangent accepted by unchanged collector interface")
			for i in 6:
				for axis in 4:
					check(absf(float(planes.planes[i][axis])-Math.scalar(int(original.plane_words[i][axis])))<=0.00005,"Camera planes retain original executed native projection")
			original_cameras+=1
	check(not cache.lookup(80).available,"Uncaptured saved FOV80 remains an explicit lower")
	viewport=SubViewport.new();viewport.size=Vector2i(800,600);viewport.own_world_3d=true;root.add_child(viewport)
	camera=Camera3D.new();camera.near=0.1;camera.far=200;viewport.add_child(camera);camera.current=true
	controller=Controller.new();viewport.add_child(controller);controller.set_process(false);pose()
	settings=Settings.new();fov=FovBinding.new();fov.configure(settings);check(fov.bind(camera),"Actual FOV binding establishes vertical projection")
	counter=Counter.new();service=Services.new()
	check(service.construct_process(counter.read,{"processConstructionKnown":true}).ready,"Actual process primary timer constructed with explicit test-only integer source")
	check(service.attach_connection(7).ready and service.set_scope([7,3,20]).ready,"Actual service receives explicit accepted scope")
	check(service.begin_frame(1).ready,"Actual primary snapshot prefix precedes receive")
	check(service.receive_clock({"kind":"native-clock-protocol","version":1,"connection":7,"serial":1,"history":{"complete":true},"scope":{"generation":3,"areaId":20},"event":{"type":"begin","lifecycleBound":true}}).ready,"Actual admitted begin completes transport history")
	runtime=Runtime.new();runtime.enabled=true;runtime.ready=true;runtime.connection=7;runtime.current_scope=[7,3,20];runtime.current_frame=1;runtime.services=service
	boundary=Boundary.new();bind()
	var reads: int=counter.reads;var first:=packet()
	if not first.available:print("FIRST_CAMERA_BOUNDARY_UNAVAILABLE ",JSON.stringify(first))
	check(first.available,"Current native follow/physical camera/primary snapshot boundary captured")
	if first.available:
		check(first.camera.position==controller.follow_state.state.position and first.camera.quaternion_wxyz==controller.follow_state.state.quaternion,"Native XYZ and source WXYZ bits preserved without engine extraction")
		check(first.camera.aspect==Math.f(4.0/3.0) and first.camera.angle==45,"Effective raster ratio and vertical FOV retained")
		check(first.primary_words=={"hi":0,"lo":3000} and first.delta_t_word==Math.word(Math.f(.003)),"Exact primary low32 renderer DeltaT distinct from calendar and GUI")
		check(boundary.current(first),"Unchanged source receipt remains current")
		var altered: Dictionary=first.duplicate(true);altered.camera.position[0]+=1
		check(not boundary.current(altered) and boundary.current(first),"Detached mutation cannot forge source lease")
		var following:=packet();check(not boundary.current(first) and boundary.current(following),"New collection invalidates old receipt within same frame")
	check(counter.reads==reads,"Capture/revalidation never sample absolute/GUI/new clock")
	allow=false;check(not packet().available,"Retired external main-world scope rejected");allow=true
	check(not boundary.capture({"connection":7,"generation":4,"area_id":20,"world_id":42},1,1).available,"Stale area generation rejected")
	check(not boundary.capture(scope,2,1).available,"External collection phase rejects wrong frame")
	camera.h_offset=1;check(not packet().available,"Unrepresented horizontal view offset rejected");camera.h_offset=0
	camera.v_offset=1;check(not packet().available,"Unrepresented vertical view offset rejected");camera.v_offset=0
	camera.position.x+=1;check(not packet().available,"Later camera writer invalidates native source pose");pose()
	camera.keep_aspect=Camera3D.KEEP_WIDTH;check(not packet().available,"Horizontal FOV convention not silently converted with host tan");camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;check(not packet().available,"Centered engine ortho not promoted to native0..scale branch");camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.projection=Camera3D.PROJECTION_FRUSTUM;check(not packet().available,"Off-axis frustum explicitly unavailable");camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	viewport.scaling_3d_scale=.5;check(not packet().available,"Unobserved internal scaled viewport rejected");viewport.scaling_3d_scale=1
	viewport.size_2d_override=Vector2i(640,480);check(not packet().available,"2D visible rectangle override cannot masquerade as raster size");viewport.size_2d_override=Vector2i.ZERO
	viewport.use_taa=true;check(not packet().available,"Temporal jitter projection unsupported");viewport.use_taa=false
	viewport.use_xr=true;check(not packet().available,"XR projection explicitly unavailable");viewport.use_xr=false
	settings.fov_changed.emit(80);check(not packet().available,"Real binding changes to unsupported80 invalidate tangent authority")
	settings.fov_changed.emit(90);check(packet().available,"Captured original90 tangent supports actual changed binding");settings.fov_changed.emit(45)
	for size in [Vector2i(1600,900),Vector2i(900,1200)]:
		var before:=packet();viewport.size=size
		check(not boundary.current(before),"Resize immediately invalidates previous source receipt")
		var after:=packet();check(after.available and after.camera.aspect==Math.f(float(size.x)/size.y),"New collection uses actual resized vertical projection")
	viewport.size=Vector2i(800,600)
	var old_far:=camera.far;var far_receipt:=packet();camera.far=100
	check(not boundary.current(far_receipt) and packet().camera.far==100,"Late AreaEnvironment far update invalidates and recaptures projection");camera.far=old_far
	for mode in ["resize","close","nested"]:
		bind();guard_mode=mode
		check(not packet().available,"Reentrant guard invalidates outer capture: "+mode)
		viewport.size=Vector2i(800,600)
	bind();callback_mode="mutate-input"
	check(boundary.collect(scope,1,1,collector).available and packet().camera.position[0]!=999,"Collector DTO mutations do not mutate camera/clock authority")
	for mode in ["move","fov","far","follow","services","clock-frame","retire"]:
		pose();camera.fov=45;camera.far=200;runtime.services=service;runtime.current_frame=1;bind();callback_mode=mode
		check(not boundary.collect(scope,1,1,collector).available,"Reentrant collector change rejects stale output: "+mode)
	pose();runtime.services=service;runtime.current_frame=1;camera.fov=45;camera.far=200;bind()
	var other:=Camera3D.new();viewport.add_child(other);other.current=true
	check(not packet().available,"Physical camera replacement cannot inherit lease");other.free();camera.current=true
	var previous_view:=packet();root.size=Vector2i(800,600);camera.reparent(root);controller.reparent(root);camera.current=true;pose()
	check(not boundary.current(previous_view),"Reparenting identical camera to a new physical viewport invalidates old boundary")
	bind();check(packet().available,"Actual main Window viewport accepts the same exact unscaled source contract")
	camera.reparent(viewport);controller.reparent(viewport);camera.current=true;pose();bind()
	runtime.connection=8;runtime.current_scope=[8,3,20];check(not packet().available,"Reconnect fences retained Camera3D owner");runtime.connection=7;runtime.current_scope=[7,3,20]
	runtime.ready=false;check(not packet().available,"Unavailable native clock owner cannot borrow engine delta");runtime.ready=true
	var world_clock=service._timers.world;var saved: Dictionary=world_clock.state_view();var changed: Dictionary=saved.duplicate(true)
	var prior_primary:=packet()
	changed.counter={"hi":0,"lo":0x80000000};changed.previousCounter={"hi":0,"lo":0};world_clock.restore_state(changed)
	check(not boundary.current(prior_primary),"Snapshot replacement in same frame invalidates previous receipt")
	var signed_low:=packet();check(signed_low.available and signed_low.delta_t_word==Math.word(Math.f(Math.f(-2147483648.0)/1000000.0)),"Primary low32 highbit uses signed CVTDQ2PS, not unsigned/divide-double")
	changed.counter={"hi":1,"lo":0x80000000};world_clock.restore_state(changed)
	check(not boundary.current(signed_low),"All primary words are fenced even when renderer delta low32 is unchanged")
	check(packet().delta_t_word==signed_low.delta_t_word,"Primary high word does not enter renderer DeltaT math")
	changed.counter={"hi":0x80000000,"lo":1};world_clock.restore_state(changed)
	check(not packet().available,"Existing signed63 fade carrier limit stays explicitly unavailable")
	world_clock.restore_state(saved)
	check(counter.reads==reads,"All boundary tests leave absolute provider sample count unchanged")
	var last_current:=packet();camera.queue_free()
	check(not boundary.current(last_current) and not packet().available,"Queued physical camera retirement rejects receipt before deletion flush")
	boundary.close();check(not packet().available,"Closed boundary has no retained authority")
	fov.close();controller.free();camera.free();viewport.free();runtime.ready=false;runtime.services=null;service.cleanup_connection();service.destroy_process()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"original_sse_cameras":original_cameras,"absolute_provider_reads":counter.reads,"collection_callbacks":callback_count,"production_hooks":0,"gpu_draws":0,"native_builds":0,"server_connections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NATIVE_CAMERA_BOUNDARY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
