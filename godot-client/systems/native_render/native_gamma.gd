extends Node
const Effect=preload("res://systems/native_render/native_gamma_effect.gd")
const Stack=preload("res://systems/native_render/camera_effects.gd")
const Post=preload("res://systems/native_render/native_postprocess.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var effect=Effect.new()
var camera: Camera3D
var settings_source: WeakRef
var post_world: WeakRef
var post_area: WeakRef
var post_error:=""
var post_frames:=0
var post_peak_ms:=0.0
var post_total_ms:=0.0
func _init() -> void:process_priority=120;set_process(false)
func attach(next: Camera3D) -> void:
	if camera==next: return
	clear_postprocess()
	if is_instance_valid(camera): Stack.remove(camera,effect)
	camera=next
	if is_instance_valid(camera): Stack.install(camera,effect)
func set_gamma(value: float) -> void: effect.set_gamma(value)
func bind_settings(source: Node,preserve_override: bool=false) -> bool:
	if not is_instance_valid(source) or not source.has_signal("gamma_changed") or not Effect.valid_value(source.get("gamma_value")): return false
	unbind_settings(); settings_source=weakref(source)
	if not preserve_override: set_gamma(float(source.get("gamma_value")))
	source.connect("gamma_changed",set_gamma)
	return true
func unbind_settings() -> void:
	var source=settings_source.get_ref() if settings_source!=null else null
	if is_instance_valid(source) and source.is_connected("gamma_changed",set_gamma): source.disconnect("gamma_changed",set_gamma)
	settings_source=null
func clear_postprocess() -> void:
	effect.set_postprocess({});post_world=null;post_area=null;post_error="";set_process(false)
func configure_postprocess(world: Node3D,area: Node,options: Dictionary) -> bool:
	if options.is_empty():clear_postprocess();return true
	if not is_instance_valid(world) or not is_instance_valid(area) or not is_instance_valid(camera) or not world.get_meta("native_surface_output",false) or not area.native_surface_output or not effect.postprocess_state().retail:
		post_error="Native postprocess requires its explicit world surface carrier";return false
	var source=world.get("catalog");var profile_error:=Post.profile(source)
	if not profile_error.is_empty():post_error=profile_error;return false
	# Validate actual generation/admission before replacing a working binding.
	var input: Dictionary=Post.capture(world,area,camera)
	if input.has("error"):post_error=str(input.error);return false
	if not effect.set_postprocess(options):post_error="Invalid or unsupported native postprocess options";return false
	var selected: Dictionary=effect.postprocess_state()
	if not effect.publish_postprocess_frame(input.value,int(selected.revision)):clear_postprocess();post_error="Native postprocess input publication failed";return false
	post_world=weakref(world);post_area=weakref(area);post_error="";set_process(true);return true
func _process(_delta: float) -> void:
	var world=post_world.get_ref() if post_world!=null else null;var area=post_area.get_ref() if post_area!=null else null
	if not is_instance_valid(world) or not is_instance_valid(area) or world.closed or world.retiring or not Post.SurfaceState.owns(world):
		clear_postprocess();return
	var selected: Dictionary=effect.postprocess_state()
	if selected.options.is_empty():set_process(false);return
	if (int(selected.options.mask)&4)==0:return
	var began:=Time.get_ticks_usec();var input: Dictionary=Post.capture(world,area,camera)
	if input.has("error"):post_error=str(input.error);return
	if effect.publish_postprocess_frame(input.value,int(selected.revision)):post_frames+=1;post_error=""
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0;post_peak_ms=maxf(post_peak_ms,elapsed);post_total_ms+=elapsed;Timing.record("callback_postprocess_state",elapsed)
func snapshot() -> Dictionary:
	var result: Dictionary=effect.snapshot();result.scene_inputs={"frames":post_frames,"total_ms":post_total_ms,"peak_ms":post_peak_ms,"error":post_error,"bound":post_world!=null};result.settings_bound=settings_source!=null and is_instance_valid(settings_source.get_ref());return result
func _exit_tree() -> void:
	unbind_settings(); attach(null); effect.close()
