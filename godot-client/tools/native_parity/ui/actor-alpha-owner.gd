extends RefCounted
const Enhanced=preload("res://systems/native_render/native_model_material.gd")
const StandardAlpha=preload("res://tools/native_parity/ui/actor-alpha-standard.gd")
const EnhancedAlpha=preload("res://tools/native_parity/ui/actor-alpha-enhanced.gd")
const State=preload("res://tools/native_parity/ui/actor-alpha-state.gd")
const Endpoint=preload("res://tools/native_parity/ui/actor-alpha-endpoint.gd")
const Publication=preload("res://tools/native_parity/ui/actor-alpha-publication.gd")
var models: Dictionary={}
var endpoints: Array=[]
var closed:=false
var failure:=""
static func primary_model_indices(pieces: Array) -> Array[int]:
	var result: Array[int]=[]
	for index in pieces.size():
		var body_part: Variant=pieces[index].get("partIndex")
		var visual_scope: Variant=pieces[index].get("nativeVisualScope")
		var equipment_slot: Variant=pieces[index].get("equipmentSlot")
		var helmet: bool=equipment_slot is int and equipment_slot==0 and pieces[index].get("anchor")=="head_g" and pieces[index].get("attachment")=="pq"
		# Native Append puts0..17 in the primary Gob; robe18 is a separate
		# attached Gob whose constructor propagate1c is true. The same explicit
		# construction/attachment proof covers cloak, wings, tail, head and Wield.
		# Never infer membership from follow or arbitrary descendant traversal.
		if index==0 or body_part is int and body_part>=0 and body_part<=18 or visual_scope is int and visual_scope in [243,252,253,254] or equipment_slot is int and equipment_slot in [16,32] or helmet:result.append(index)
	return result
func begin_model(model_index: int) -> bool:
	if closed or model_index<0:return false
	if not models.has(model_index):models[model_index]=State.new()
	return true
func enroll(mesh: MeshInstance3D,model_index: int) -> bool:
	if closed or not is_instance_valid(mesh) or model_index<0:return false
	var source: Material=mesh.material_override
	if not source is StandardMaterial3D and not source is Enhanced:failure="Unsupported actor alpha material";return false
	var target=EnhancedAlpha.new() if source is Enhanced else StandardAlpha.new()
	Publication.copy_storage(source,target)
	begin_model(model_index)
	var endpoint:=Endpoint.new();endpoint.configure(mesh);endpoints.append(endpoint)
	target.actor_part_color=source.albedo_color;target.actor_part_emission=source.emission;target.actor_part_emission_enabled=source.emission_enabled;target.actor_part_blended=source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA
	target.actor_base_transparency=source.transparency
	if source is StandardMaterial3D:target.actor_base_depth_draw=source.depth_draw_mode
	target.actor_alpha_endpoint=endpoint;target.actor_alpha_context=models[model_index]
	mesh.material_override=target;target.refresh_actor_alpha();return true
func set_alpha(value: float,model_indices: Array=[0],gob_flag18: bool=false,colour_shift: bool=true) -> bool:
	if closed or not is_finite(value):return false
	# Attachment propagation is explicit until native child+1c is mapped by the
	# caller. Do not silently apply scope255 to every held/reference model.
	var selected: Array=[]
	for index in model_indices:
		if not index is int or not models.has(index):return false
		selected.append(models[index])
	for state in selected:
		if closed or not state.set_alpha(value,gob_flag18,colour_shift):return false
	return true
func snapshot() -> Dictionary:
	var states: Dictionary={}
	for index in models:states[index]=models[index].snapshot()
	return {"enabled":true,"closed":closed,"models":states,"endpoints":endpoints.size(),"failure":failure,"attachment_propagation":"explicit model list; native child flag mapping pending","generic_static_support":false}
func set_vector(channel: int,value: Variant,model_indices: Array=[0]) -> bool:
	if closed or channel<0 or channel>=5 or value!=null and State.vector_input(value)==null:return false
	var selected: Array=[]
	for index in model_indices:
		if not index is int or not models.has(index):return false
		selected.append(models[index])
	for state in selected:
		if closed or not state.set_vector(channel,value):return false
	return true
func set_presentation_draw_enabled(value: bool,model_indices: Array=[0]) -> bool:
	if closed:return false
	var selected: Array=[]
	for index in model_indices:
		if not index is int or not models.has(index):return false
		selected.append(models[index])
	for state in selected:
		if closed or not state.set_presentation_draw_enabled(value):return false
	return true
func close() -> void:
	if closed:return
	closed=true
	for endpoint in endpoints:endpoint.close()
	for state in models.values():state.close()
	endpoints.clear();models.clear()
