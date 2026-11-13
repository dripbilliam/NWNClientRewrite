extends "res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd"
# Same native highlight contract and retained mesh/material. Godot-side owners
# keep every weak/lifetime/provider guard; native code sees only borrowed POD.
static var kernel_extension: Resource
static func ensure_kernel() -> bool:
	if ClassDB.class_exists("NwnHighlightGeometry"):return true
	if kernel_extension==null and FileAccess.file_exists("res://native/highlight_geometry.gdextension"):
		kernel_extension=load("res://native/highlight_geometry.gdextension")
	return kernel_extension!=null and ClassDB.class_exists("NwnHighlightGeometry")
var kernel_shapes:=PackedFloat32Array()
var kernel_poses: Array=[]
var kernel_colors:=PackedColorArray()
var kernel_alphas:=PackedFloat32Array()
var kernel_enabled:=PackedByteArray()
var kernel_stats:={"calls":0,"failures":0,"gather_us":0,"build_us":0,"upload_us":0,"last_error":""}
func _init() -> void:
	super()
	ensure_kernel()
func _rebuild() -> void:
	super._rebuild()
	kernel_shapes.resize(members.size()*6);kernel_poses.resize(members.size());kernel_colors.resize(members.size());kernel_alphas.resize(members.size());kernel_enabled.resize(members.size())
	kernel_poses.fill(Transform3D.IDENTITY)
	for index in members.size():
		var member: Dictionary=members[index];var row: Dictionary=member.row
		for axis in 3:
			kernel_shapes[index*6+axis]=float(row.bounds.min[axis]);kernel_shapes[index*6+3+axis]=float(row.bounds.max[axis])
		member.kernel_key=str(member.entity)+":"+str(row.model)
func tick(camera: Camera3D,pulse_size: Variant,intensity: Variant) -> bool:
	if closed or not texture_ready or not is_instance_valid(camera) or not camera.is_inside_tree() or not (pulse_size is int or pulse_size is float) or not (intensity is int or intensity is float):return false
	if not ClassDB.class_exists("NwnHighlightGeometry"):
		batch.visible=false;kernel_stats.last_error="Standalone native highlight kernel unavailable";return false
	if dirty:_rebuild()
	if members.is_empty():return true
	var began:=Time.get_ticks_usec();var epoch:=revision;var values: Dictionary={};var complete:=true
	for index in members.size():
		kernel_enabled[index]=0
		var member: Dictionary=members[index];var entry: Dictionary=member.entry;var row: Dictionary=member.row
		var physical_owner:=alive(entry.owner,entry.id);var part:=alive(row.anchor,row.id)
		if physical_owner==null or part==null or not entries.has(member.entity) or not is_same(entries[member.entity],entry):complete=false;continue
		var key: String=member.kernel_key
		if not values.has(key):
			var alpha: Variant=entry.alpha.call(row.model) if entry.alpha.is_valid() else null
			if closed or revision!=epoch:return false
			var color: Variant=entry.color_source.call(row.model) if entry.color_source.is_valid() else entry.color
			if closed or revision!=epoch:return false
			var available: bool=(alpha is int or alpha is float) and is_finite(float(alpha)) and (color is Vector3 and color.is_finite() or color is Color and finite_color(color))
			values[key]={"available":available,"alpha":alpha,"color":color}
		var value: Dictionary=values[key]
		if not value.available:complete=false;continue
		kernel_poses[index]=part.global_transform;kernel_alphas[index]=float(value.alpha)
		kernel_colors[index]=Color(value.color.x,value.color.y,value.color.z) if value.color is Vector3 else value.color
		kernel_enabled[index]=1
	if closed or revision!=epoch:return false
	kernel_stats.gather_us+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec()
	var output: Dictionary=ClassDB.class_call_static("NwnHighlightGeometry","build",kernel_shapes,kernel_poses,kernel_colors,kernel_alphas,kernel_enabled,camera.global_position,float(pulse_size),float(intensity))
	kernel_stats.build_us+=Time.get_ticks_usec()-began;kernel_stats.calls+=1
	if closed or revision!=epoch:return false
	if output.has("error") or not output.get("positions") is PackedByteArray or not output.get("attributes") is PackedByteArray or output.positions.size()!=members.size()*18*12 or output.attributes.size()!=members.size()*18*12 or not output.get("bounds") is AABB:
		batch.visible=false;kernel_stats.failures+=1;kernel_stats.last_error=str(output.get("error","Native highlight output unavailable"));return false
	began=Time.get_ticks_usec()
	surface.surface_update_vertex_region(0,0,output.positions);surface.surface_update_attribute_region(0,0,output.attributes)
	batch.custom_aabb=output.bounds;batch.visible=bool(output.has_bounds)
	kernel_stats.upload_us+=Time.get_ticks_usec()-began;stats.updates+=1;stats.unavailable+=int(output.unavailable_parts)
	return complete and int(output.unavailable_parts)==0
func snapshot() -> Dictionary:
	var result:=super.snapshot();result.route="standalone-native-pod-batch";result.kernel=kernel_stats.duplicate();return result
func close() -> void:
	super.close();kernel_shapes.clear();kernel_poses.clear();kernel_colors.clear();kernel_alphas.clear();kernel_enabled.clear()
