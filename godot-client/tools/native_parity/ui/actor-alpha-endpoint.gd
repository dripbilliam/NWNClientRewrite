extends Resource
# Private draw endpoint: weak full-ID identity, no registry membership mutation.
var mesh: WeakRef
var mesh_id:=0
var closed:=false
var publications:=0
func configure(value: MeshInstance3D) -> void:
	mesh=weakref(value);mesh_id=value.get_instance_id()
func publish(material: Material,visible_value: bool) -> void:
	if closed:return
	var current=mesh.get_ref() if mesh!=null else null
	if not is_instance_valid(current) or current.get_instance_id()!=mesh_id or current.is_queued_for_deletion():return
	# NativePose can replace a material with duplicate(false). Retired material
	# callbacks must never control the new binding's visibility.
	if current.material_override!=material:return
	if current.visible!=visible_value:current.visible=visible_value
	publications+=1
func close() -> void:
	closed=true;mesh=null;mesh_id=0
