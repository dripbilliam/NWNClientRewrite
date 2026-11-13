extends RefCounted
# Isolated source boundary, never installed in the live frame loop. All reads
# are synchronous. The caller owns the actual world collection phase guard.
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
const Tangents=preload("res://tools/native_parity/visibility/camera_tangent_words.gd")
var _camera: WeakRef
var _controller: WeakRef
var _follow: WeakRef
var _clock: WeakRef
var _services: WeakRef
var _viewport: WeakRef
var _tangents: Tangents
var _scope: Dictionary={}
var _guard:=Callable()
var _revision:=0
var _receipt: Dictionary={}
var _open:=false

func unavailable(field: String,reason: String) -> Dictionary:
	return {"available":false,"field":field,"reason":reason}

func bind(camera: Camera3D,controller,clock,scope: Dictionary,guard: Callable,tangents: Tangents) -> Dictionary:
	close()
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not is_instance_valid(controller) or not is_instance_valid(clock) or not is_instance_valid(tangents) or not guard.is_valid():return unavailable("owners","native-camera-owners-unavailable")
	for key in ["connection","generation","area_id","world_id"]:
		if not Math.uint(scope.get(key),9007199254740991):return unavailable("scope","native-camera-scope-unavailable")
	if controller.get_script()==null or controller.get_script().resource_path!="res://systems/camera_controller.gd" or clock.get_script()==null or clock.get_script().resource_path!="res://systems/native_client_clock_runtime.gd":return unavailable("owners","native-camera-owner-type-unavailable")
	if controller.camera!=camera or not is_instance_valid(controller.follow_state) or not is_instance_valid(clock.services):return unavailable("owners","native-camera-owner-binding-unavailable")
	_camera=weakref(camera);_controller=weakref(controller);_follow=weakref(controller.follow_state);_clock=weakref(clock);_services=weakref(clock.services);_viewport=weakref(camera.get_viewport())
	_scope=scope.duplicate(true);_guard=guard;_tangents=tangents;_open=true
	return {"available":true}

func _same_owners(revision: int) -> bool:
	if not _open or _revision!=revision:return false
	for ref in [_camera,_controller,_follow,_clock,_services,_viewport]:
		if ref==null or not is_instance_valid(ref.get_ref()):return false
	var camera=_camera.get_ref();var controller=_controller.get_ref();var clock=_clock.get_ref()
	var viewport=_viewport.get_ref()
	return camera.is_inside_tree() and not camera.is_queued_for_deletion() and controller.is_inside_tree() and not controller.is_queued_for_deletion() and not viewport.is_queued_for_deletion() and controller.get_viewport()==viewport and controller.camera==camera and controller.follow_state==_follow.get_ref() and clock.services==_services.get_ref() and camera.get_viewport()==viewport and clock.ready and clock.enabled and clock.connection==_scope.connection and clock.current_scope==[_scope.connection,_scope.generation,_scope.area_id]

func _admitted(revision: int,frame: int,collection: int) -> bool:
	if not _same_owners(revision) or not _guard.is_valid():return false
	var result: Variant=_guard.call(_scope.duplicate(true),frame,collection)
	return result is bool and result and _same_owners(revision)

func _read(frame: int) -> Dictionary:
	var camera: Camera3D=_camera.get_ref();var controller=_controller.get_ref();var clock=_clock.get_ref();var viewport: Viewport=_viewport.get_ref()
	if not camera.is_current() or viewport.get_camera_3d()!=camera:return unavailable("camera","native-camera-is-not-current-main-view")
	if camera.is_physics_interpolated_and_enabled() or camera.h_offset!=0.0 or camera.v_offset!=0.0:return unavailable("pose","native-camera-adjusted-pose-unavailable")
	var state: Dictionary=controller.follow_state.state
	if not Math.point(state.get("position")) or not Math.point(state.get("quaternion"),4):return unavailable("pose","native-camera-follow-pose-unavailable")
	var p:=Math.rounded(state.position);var q:=Math.rounded(state.quaternion)
	# Exactly the existing CameraController presentation conversion. Preserve
	# source WXYZ bits instead of extracting/renormalizing an engine quaternion.
	var presented:=Transform3D(Basis(Quaternion(Vector3.RIGHT,-PI/2)*Quaternion(q[1],q[2],q[3],q[0])),Vector3(p[0],p[2],-p[1]))
	# Camera3D constructs with scale disabled: Node3D normalizes its global
	# basis once, then Camera3D normalizes again before render submission.
	var global_presented:=presented.orthonormalized() if camera.is_scale_disabled() else presented
	if camera.global_transform!=global_presented or camera.get_camera_transform()!=global_presented.orthonormalized():return unavailable("pose","native-camera-final-pose-no-longer-matches-follow")
	if camera.projection!=Camera3D.PROJECTION_PERSPECTIVE or camera.keep_aspect!=Camera3D.KEEP_HEIGHT or camera.frustum_offset!=Vector2.ZERO:return unavailable("projection","native-camera-projection-mode-unavailable")
	# RendererSceneCull uses internal_size, while Camera3D diagnostic projection
	# uses visible_rect (which may be a 2D override). Accept only the proved
	# common size, scale1/no-temporal/no-XR case; never infer hidden raster size.
	if not (viewport is Window or viewport is SubViewport) or viewport.disable_3d or viewport.use_xr or viewport.use_taa or viewport.scaling_3d_scale!=1.0 or viewport.scaling_3d_mode not in [Viewport.SCALING_3D_MODE_BILINEAR,Viewport.SCALING_3D_MODE_NEAREST]:return unavailable("viewport","native-camera-effective-viewport-mode-unavailable")
	var size: Vector2i=viewport.size
	if size.x<=0 or size.y<=0 or size.x>16384 or size.y>16384 or viewport.get_visible_rect().size!=Vector2(size) or viewport.get_texture().get_size()!=Vector2(size) or viewport.get_stretch_transform()!=Transform2D.IDENTITY:return unavailable("viewport","native-camera-effective-viewport-size-unavailable")
	var angle:=Math.f(camera.fov);var near:=Math.f(camera.near);var far:=Math.f(camera.far)
	if not Math.number(angle) or angle<=0 or angle>=180 or not Math.number(near) or not Math.number(far) or near<=0 or far<=near:return unavailable("projection","native-camera-projection-operands-unavailable")
	var tangent:=_tangents.lookup(angle)
	if not tangent.available:return unavailable("half_tangent_word",tangent.reason)
	if clock.current_frame!=frame:return unavailable("primary_words","native-camera-clock-frame-stale")
	var timing: Dictionary=clock.reveal_timing()
	if timing.get("available")!=true or timing.get("ready")!=true or timing.get("source")!="native-primary-world-snapshot-v1" or timing.get("frame")!=frame or not timing.get("snapshot_words") is Dictionary:return unavailable("primary_words","native-camera-primary-snapshot-unavailable")
	var primary: Dictionary=timing.snapshot_words
	if not Math.uint(primary.get("hi")) or not Math.uint(primary.get("lo")):return unavailable("primary_words","native-camera-primary-snapshot-words-unavailable")
	var delta:=Math.renderer_delta_t(primary)
	return {"available":true,"camera":{"position":p,"quaternion_wxyz":q,"angle":angle,"aspect":Math.f(float(size.x)/float(size.y)),"near":near,"far":far,"half_tangent_angle_word":tangent.half_tangent_angle_word,"half_tangent_word":tangent.half_tangent_word},"primary_words":{"hi":int(primary.hi),"lo":int(primary.lo)},"delta_t_word":Math.word(delta.delta_t),"effective_viewport":[size.x,size.y],"camera_id":camera.get_instance_id(),"viewport_id":viewport.get_instance_id(),"follow_id":controller.follow_state.get_instance_id(),"clock_id":clock.get_instance_id(),"services_id":clock.services.get_instance_id(),"tangent_branch":tangent.branch,"tangent_corpus_sha256":tangent.corpus_sha256}

func capture(scope: Dictionary,frame: int,collection: int) -> Dictionary:
	_revision+=1;_receipt={};var revision:=_revision
	if frame<0 or collection<0 or scope!=_scope or not _admitted(revision,frame,collection):return unavailable("boundary","native-camera-collection-scope-stale")
	var first:=_read(frame)
	if not first.available:return first
	if not _admitted(revision,frame,collection):return unavailable("boundary","native-camera-collection-retired-during-capture")
	var second:=_read(frame)
	if not second.available or first!=second:return unavailable("boundary","native-camera-source-changed-during-capture")
	first.scope=_scope.duplicate(true);first.frame=frame;first.collection=collection;first.revision=revision
	_receipt=first.duplicate(true)
	return first

func current(receipt: Dictionary) -> bool:
	if _receipt.is_empty() or receipt!=_receipt:return false
	var revision:=_revision
	if not _admitted(revision,int(receipt.frame),int(receipt.collection)) or receipt!=_receipt:return false
	var source:=_read(int(receipt.frame))
	if not source.available:return false
	for key in source:
		if source[key]!=receipt.get(key):return false
	return _same_owners(revision) and receipt==_receipt

func collect(scope: Dictionary,frame: int,collection: int,collector: Callable) -> Dictionary:
	var receipt:=capture(scope,frame,collection)
	if not receipt.available:return receipt
	if not collector.is_valid() or not current(receipt):return unavailable("boundary","native-camera-collection-lease-stale")
	var result: Variant=collector.call(scope.duplicate(true),receipt.camera.duplicate(true),receipt.primary_words.duplicate(true))
	if not current(receipt):return unavailable("boundary","native-camera-collection-retired-during-callback")
	if not result is Dictionary:return unavailable("collector","native-camera-collector-result-unavailable")
	return result.duplicate(true)

func close() -> void:
	_open=false;_revision+=1;_receipt={};_scope={};_guard=Callable();_tangents=null
	_camera=null;_controller=null;_follow=null;_clock=null;_services=null;_viewport=null
