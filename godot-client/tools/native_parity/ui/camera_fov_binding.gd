extends RefCounted
const FovProjection=preload("res://tools/native_parity/ui/camera_fov_projection.gd")
var settings: WeakRef
var camera: WeakRef
var camera_id:=0
var closed:=false
func configure(owner) -> void:
	if settings!=null:close()
	closed=false;settings=weakref(owner)
	if not owner.fov_changed.is_connected(value_changed):owner.fov_changed.connect(value_changed)
func bind(value: Camera3D) -> bool:
	if closed or not is_instance_valid(value):return false
	if camera_id==value.get_instance_id() and camera!=null and camera.get_ref()==value:return true
	var owner=settings.get_ref() if settings!=null else null
	if not is_instance_valid(owner) or not FovProjection.apply(value,owner.fov_degrees):return false
	camera=weakref(value);camera_id=value.get_instance_id()
	return true
func value_changed(value: float) -> void:
	if closed:return
	var current=camera.get_ref() if camera!=null else null
	if is_instance_valid(current) and current.get_instance_id()==camera_id:FovProjection.apply(current,value)
func unbind() -> void:
	# Session reset may retain the same Camera3D instance for the next login.
	# Drop only its presentation binding; saved settings/signals remain active.
	camera=null;camera_id=0
func close() -> void:
	if closed:return
	closed=true
	var owner=settings.get_ref() if settings!=null else null
	if is_instance_valid(owner) and owner.fov_changed.is_connected(value_changed):owner.fov_changed.disconnect(value_changed)
	settings=null;unbind()
