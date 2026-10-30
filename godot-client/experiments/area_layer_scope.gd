extends RefCounted
# Isolated experiment, NEVER imported by the production renderer. An authored
# probe must validate this before any captured-world integration is attempted.
# Map the existing two known render layers into a private per-area two-bit lane.
# Unknown layers/types fail before mutation instead of losing their semantics.
var root: Node3D
var slot:=-1
var mask:=0
var original_process_mode:=Node.PROCESS_MODE_INHERIT
var bindings: Array=[]
var owned: Dictionary={}
var failure:=""
var retired:=false
func bind(value: Node3D,area_slot: int) -> bool:
	if is_instance_valid(root) or not is_instance_valid(value) or area_slot<0 or area_slot>9:
		failure="Invalid/occupied experimental area scope"; return false
	root=value; slot=area_slot; mask=3<<(slot*2); original_process_mode=root.process_mode
	if not admit(root): root=null; slot=-1; mask=0; return false
	return true
func remap(layers: int) -> int:
	return (layers&3)<<(slot*2)
func admit(branch: Node) -> bool:
	if retired or not is_instance_valid(root) or not is_instance_valid(branch): failure="Inactive experimental scope"; return false
	if branch!=root and not root.is_ancestor_of(branch): failure="Admission is outside the area owner"; return false
	var pending: Array=[branch]; var prepared: Array=[]
	while not pending.is_empty():
		var node: Node=pending.pop_back(); pending.append_array(node.get_children())
		if not node is VisualInstance3D or owned.has(node.get_instance_id()): continue
		if not (node is MeshInstance3D or node is MultiMeshInstance3D or node is Light3D): failure="Unsupported experimental visual type: "+node.get_class(); return false
		var visual:=node as VisualInstance3D
		if visual.layers&~3: failure="Original visual layers exceed the experiment's two-layer contract"; return false
		var row:={"node":weakref(visual),"id":visual.get_instance_id(),"layers":visual.layers}
		if visual is Light3D: row.light_mask=visual.light_cull_mask; row.shadow_mask=visual.shadow_caster_mask
		prepared.append(row)
	# Validation above is deliberately complete before the first property write.
	for row in prepared:
		var visual: VisualInstance3D=row.node.get_ref(); visual.layers=remap(int(row.layers))
		if visual is Light3D: visual.light_cull_mask=remap(int(row.light_mask)); visual.shadow_caster_mask=remap(int(row.shadow_mask))
		bindings.append(row); owned[int(row.id)]=true
	return true
func activate(camera: Camera3D,original_cull_mask: int) -> bool:
	if retired or not is_instance_valid(root) or not is_instance_valid(camera): failure="Invalid experimental activation"; return false
	# Never remap an already remapped camera mask on a later transition.
	# The caller must retain the original camera policy separately.
	camera.cull_mask=remap(original_cull_mask)
	return true
func retire() -> bool:
	if retired: return true
	if not is_instance_valid(root): failure="Experimental area owner is gone"; return false
	# Only the hide traversal is being investigated. Retain the existing
	# inherited processing/physics disable, not an unsafe deferred stop.
	retired=true; root.process_mode=Node.PROCESS_MODE_DISABLED
	return true
func restore() -> void:
	for row in bindings:
		var visual: VisualInstance3D=row.node.get_ref()
		if not is_instance_valid(visual): continue
		visual.layers=int(row.layers)
		if visual is Light3D: visual.light_cull_mask=int(row.light_mask); visual.shadow_caster_mask=int(row.shadow_mask)
	if is_instance_valid(root): root.process_mode=original_process_mode
	bindings.clear(); owned.clear(); root=null; retired=false; slot=-1; mask=0
