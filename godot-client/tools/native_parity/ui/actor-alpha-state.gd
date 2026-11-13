extends Resource
# One model/Gob's renderer alpha. No server state or animation clock is owned.
var alpha:=1.0
var alpha_word:=PackedFloat32Array([1.0])
var gob_flag18:=false
var colour_shift_active:=true
var multiplications: int:
	get:return int(gob_flag18)+int(colour_shift_active)
var revision:=0
var closed:=false
var presentation_draw_enabled:=true
var vector_active:=PackedByteArray([0,0,0,0,0])
var vectors:=PackedVector3Array([Vector3.ONE,Vector3.ONE,Vector3.ONE,Vector3.ONE,Vector3.ONE])
var selected_vector:=Vector3.ONE
var selected_emission:=Vector3.ZERO
var plain:=true
var materials: Dictionary={}
func register_material(value: Material) -> void:
	if not closed:materials[value.get_instance_id()]=weakref(value)
func unregister_material(value: Material) -> void:
	materials.erase(value.get_instance_id())
func set_alpha(value: float,flag18: bool=false,colour_shift: bool=true) -> bool:
	if closed or not is_finite(value):return false
	var word:=PackedFloat32Array([value])
	if not is_finite(word[0]):return false
	if word.to_byte_array()==alpha_word.to_byte_array() and gob_flag18==flag18 and colour_shift_active==colour_shift:return true
	alpha_word=word;alpha=word[0];gob_flag18=flag18;colour_shift_active=colour_shift;revision+=1
	return publish()
static func vector_input(value: Variant) -> Variant:
	if value is Vector3:return value if value.is_finite() else null
	if not value is Array or value.size()!=3:return null
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):return null
	var result:=Vector3(value[0],value[1],value[2]);return result if result.is_finite() else null
func set_vector(channel: int,value: Variant) -> bool:
	if closed or channel<0 or channel>=5:return false
	if value==null:
		if vector_active[channel]==0:return true
		vector_active[channel]=0
	else:
		var decoded=vector_input(value)
		if decoded==null:return false
		var words:=PackedFloat32Array([decoded.x,decoded.y,decoded.z]);var prior: Vector3=vectors[channel]
		if vector_active[channel]!=0 and words.to_byte_array()==PackedFloat32Array([prior.x,prior.y,prior.z]).to_byte_array():return true
		vectors[channel]=decoded;vector_active[channel]=1
	selected_vector=Vector3.ONE;selected_emission=Vector3.ZERO
	for index in 5:
		if vector_active[index]!=0:selected_vector=vectors[index];selected_emission=vectors[index];break
	revision+=1;return publish()
func set_presentation_draw_enabled(value: bool) -> bool:
	if closed:return false
	if presentation_draw_enabled==value:return true
	presentation_draw_enabled=value;revision+=1;return publish()
func publish() -> bool:
	plain=alpha==1.0 and presentation_draw_enabled and not vector_active.has(1)
	# Changes are sparse and explicit; no per-frame scene/world scan. A strong
	# local retains each Resource through synchronous setter callbacks.
	for id in materials.keys():
		var material=materials.get(id).get_ref() if materials.has(id) else null
		if not is_instance_valid(material) or material.get_instance_id()!=id:materials.erase(id);continue
		material.refresh_actor_alpha()
		if closed:break
	return not closed
func snapshot() -> Dictionary:
	return {"alpha":alpha,"gob_flag18":gob_flag18,"colour_shift_active":colour_shift_active,"multiplications":multiplications,"revision":revision,"closed":closed,"registered_materials":materials.size(),"presentation_draw_enabled":presentation_draw_enabled,"vector_active":Array(vector_active),"vectors":Array(vectors),"selected_vector":selected_vector,"selected_emission":selected_emission}
func close() -> void:
	closed=true;plain=false;revision+=1;materials.clear()
