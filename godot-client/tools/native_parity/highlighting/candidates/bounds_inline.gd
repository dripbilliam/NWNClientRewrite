extends Node3D
# Registry owns admission/lifetime. This owner retains only immutable authored
# bounds, weak full-ID physical anchors, selected membership and draw buffers.
const TexturedMaterial=preload("res://tools/native_parity/highlighting/native_highlight_material.gd")
const ORDER=[0,1,3,3,1,2]
const UVS=[Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]
# Actual CNWCArea loader constants supersede the image's initial globals.
const AREA_PULSE_DEFAULTS={"amplitude":0.5,"frequency":1.0,"size":2.5,"intensity":0.3}
var entries: Dictionary={}
var selected: Array[int]=[]
var members: Array=[]
var dirty:=true
var closed:=false
var revision:=0
var batch:=MeshInstance3D.new()
var surface: ArrayMesh
var texture_ready:=false
var textured_material:=TexturedMaterial.new()
var uvs:=PackedVector2Array()
var attributes:=PackedByteArray()
var positions:=PackedVector3Array()
var colors:=PackedColorArray()
var color_bytes:=PackedByteArray()
var stats:={"registered":0,"selected":0,"parts":0,"vertices":0,"membership_rebuilds":0,"updates":0,"unavailable":0,"retired":0}
func _init() -> void:
	set_process(false)
	batch.name="native_highlight_bounds";batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.top_level=true
	batch.material_override=textured_material
	add_child(batch)
func configure_texture(texture: Texture2D,sampler: Dictionary,native_surface_output: bool=true) -> bool:
	if closed:return false
	texture_ready=textured_material.configure(texture,sampler,native_surface_output)
	if not texture_ready:batch.visible=false
	revision+=1;return texture_ready
func clear_texture() -> void:
	texture_ready=false;revision+=1;batch.visible=false;textured_material.clear_texture()
static func f32(value: float) -> float:return Color(value,0,0,0).r
static func finite_color(value: Color) -> bool:return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
static func highlight_rgb(color: Color,gob_alpha: float) -> Vector3:
	var tint:=Vector3(color.r,color.g,color.b)
	if gob_alpha<0.4:tint*=f32(gob_alpha/f32(0.4))
	return tint
static func pulse_step(phase: float,delta: float,amplitude: float,frequency: float,base_size: float) -> Dictionary:
	for value in [phase,delta,amplitude,frequency,base_size]:
		if not is_finite(value):return {"available":false}
	var next:=f32(f32(f32(f32(f32(delta)*2.0)*f32(PI))*f32(frequency))+f32(phase))
	var two_pi:=f32(TAU);var count:=0
	while next>two_pi:
		next=f32(next-two_pi);count+=1
		if count>65536:return {"available":false,"reason":"Native pulse wrap outside bounded presentation clock domain"}
	var wave:=f32(sin(next))
	var size:=f32(f32(f32(f32(f32(wave*0.5)+0.5)*f32(f32(amplitude)*0.25))+1.0)*f32(base_size))
	return {"available":true,"phase":next,"size":size}
static func native_normalize(value: Vector3) -> Vector3:
	var square:=f32(f32(f32(value.x*value.x)+f32(value.y*value.y))+f32(value.z*value.z))
	if square==0.0:return Vector3.RIGHT
	if square>=f32(0.99999) and square<=f32(1.00001):return value
	var length:=f32(sqrt(square))
	return Vector3(f32(value.x/length),f32(value.y/length),f32(value.z/length))
static func source_point(point: Array) -> Vector3:return Vector3(point[0],point[2],-point[1])
static func source_vector(point: Vector3) -> Vector3:return Vector3(point.x,point.z,-point.y)
static func native_direction(point: Vector3) -> Vector3:return Vector3(point.x,-point.z,point.y)
static func valid_bounds(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key in ["min","max"]:
		if not value.get(key) is Array or value[key].size()!=3:return false
		for component in value[key]:
			if not (component is int or component is float) or not is_finite(float(component)):return false
	for axis in 3:
		if value.min[axis]>value.max[axis]:return false
	return true
static func alive(reference: WeakRef,id: int) -> Node3D:
	var node=reference.get_ref()
	return node if node is Node3D and node.get_instance_id()==id and not node.is_queued_for_deletion() and node.is_inside_tree() else null
func register_entity(id: int,owner: Node3D,lifetime: Array,descriptors: Array,color: Color,alpha_provider: Callable=Callable(),color_provider: Callable=Callable()) -> bool:
	if closed or not is_instance_valid(owner) or not finite_color(color):return false
	var rows: Array=[]
	for descriptor in descriptors:
		# Unknown type/subtree state stays unavailable; never infer either from
		# material alpha, mesh.visible, names or render flags.
		if not descriptor is Dictionary or not descriptor.get("is_skin") is bool or not descriptor.get("subtree_enabled") is bool:return false
		var part=descriptor.get("anchor")
		if not part is Node3D or not valid_bounds(descriptor.get("native_bounds")):return false
		if descriptor.is_skin:continue
		rows.append({"anchor":weakref(part),"id":part.get_instance_id(),"bounds":descriptor.native_bounds.duplicate(true),"enabled":descriptor.subtree_enabled,"model":int(descriptor.get("model_index",0))})
	entries[id]={"owner":weakref(owner),"id":owner.get_instance_id(),"lifetime":lifetime.duplicate(true),"parts":rows,"color":color,"alpha":alpha_provider,"color_source":color_provider,"color_provided":not color_provider.is_null()}
	revision+=1;dirty=true;batch.visible=false;stats.registered=entries.size();return true
func mark(ids: Array) -> void:
	if closed:return
	var desired: Array[int]=[]
	for id in ids:
		if id is int and entries.has(id) and not desired.has(id):desired.append(id)
	if selected==desired:return
	selected=desired;dirty=true;batch.visible=false;revision+=1;stats.selected=selected.size()
func forget(id: int) -> void:
	if not entries.erase(id):return
	selected.erase(id);revision+=1;dirty=true;batch.visible=false;stats.retired+=1;stats.registered=entries.size();stats.selected=selected.size()
func set_color(id: int,color: Color) -> bool:
	if closed or not entries.has(id) or not finite_color(color):return false
	if entries[id].color!=color:entries[id].color=color;revision+=1;batch.visible=false
	return true
func set_subtree_enabled(id: int,part_id: int,value: bool) -> bool:
	if closed or not entries.has(id):return false
	for row in entries[id].parts:
		if row.id==part_id:
			if row.enabled!=value:row.enabled=value;dirty=true;batch.visible=false;revision+=1
			return true
	return false
func _rebuild() -> void:
	members.clear()
	for id in selected:
		if not entries.has(id):continue
		var entry: Dictionary=entries[id]
		if alive(entry.owner,entry.id)==null:continue
		for row in entry.parts:
			if row.enabled and alive(row.anchor,row.id)!=null:members.append({"entity":id,"entry":entry,"row":row})
	positions.resize(members.size()*18);colors.resize(positions.size());color_bytes.resize(positions.size()*4)
	positions.fill(Vector3.ZERO);colors.fill(Color(0,0,0,0));color_bytes.fill(0)
	uvs.resize(positions.size());attributes.resize(positions.size()*12);attributes.fill(0)
	for at in positions.size():
		uvs[at]=UVS[at%6];attributes.encode_float(at*12+4,uvs[at].x);attributes.encode_float(at*12+8,uvs[at].y)
	surface=ArrayMesh.new()
	if not positions.is_empty():
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs
		surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	batch.mesh=surface;batch.visible=texture_ready and not members.is_empty();stats.parts=members.size();stats.vertices=positions.size();stats.membership_rebuilds+=1;dirty=false
static func project(bounds: Dictionary,pose: Transform3D,camera_position: Vector3,pulse_size: float,intensity: float,color: Color,gob_alpha: float) -> Dictionary:
	if not valid_bounds(bounds) or not pose.is_finite() or not camera_position.is_finite() or not is_finite(pulse_size) or pulse_size<=0 or not is_finite(intensity) or intensity<0 or not is_finite(gob_alpha) or not finite_color(color):return {"available":false}
	var scale:=pose.basis.x.length()
	if scale<0.0000001 or absf(pose.basis.y.length()-scale)>scale*0.00001 or absf(pose.basis.z.length()-scale)>scale*0.00001:return {"available":false,"reason":"Native uniform-scale Part pose unavailable"}
	if absf(pose.basis.x.dot(pose.basis.y))>scale*scale*0.00001 or absf(pose.basis.x.dot(pose.basis.z))>scale*scale*0.00001 or absf(pose.basis.y.dot(pose.basis.z))>scale*scale*0.00001:return {"available":false,"reason":"Native orthogonal Part pose unavailable"}
	if pose.basis.determinant()<0:scale=-scale
	var center:=Vector3.ZERO;var lo:=Vector3.ZERO;var hi:=Vector3.ZERO
	for axis in 3:
		center[axis]=f32(f32(float(bounds.max[axis])+float(bounds.min[axis]))*0.5)
		lo[axis]=f32(f32(f32(float(bounds.min[axis])-center[axis])*pulse_size)+center[axis])
		hi[axis]=f32(f32(f32(float(bounds.max[axis])-center[axis])*pulse_size)+center[axis])
	var direction: Vector3=native_normalize(native_direction(camera_position-pose.origin))
	# Native subtracts WORLD camera direction from local/scaled center without
	# inverse-rotating it. Only each plane's constant axis receives this bias.
	var biased:=center-direction*(0.001/scale)
	var planes: Array=[
		PackedVector3Array([Vector3(biased.x,lo.y,lo.z),Vector3(biased.x,hi.y,lo.z),Vector3(biased.x,hi.y,hi.z),Vector3(biased.x,lo.y,hi.z)]),
		PackedVector3Array([Vector3(lo.x,biased.y,lo.z),Vector3(hi.x,biased.y,lo.z),Vector3(hi.x,biased.y,hi.z),Vector3(lo.x,biased.y,hi.z)]),
		PackedVector3Array([Vector3(lo.x,lo.y,biased.z),Vector3(hi.x,lo.y,biased.z),Vector3(hi.x,hi.y,biased.z),Vector3(lo.x,hi.y,biased.z)])]
	var vertices:=PackedVector3Array();vertices.resize(18);var packed:=PackedByteArray();packed.resize(72)
	var tint:=highlight_rgb(color,gob_alpha)
	for plane_index in 3:
		var local:=PackedVector3Array()
		for point in planes[plane_index]:local.append(source_vector(point))
		var transformed: PackedVector3Array=pose*local
		var normal: Vector3=native_normalize((transformed[1]-transformed[0]).cross(transformed[2]-transformed[0]))
		var camera_direction:=source_vector(direction)
		var facing:=absf(f32(f32(f32(normal.y*camera_direction.y)+f32(normal.x*camera_direction.x))+f32(normal.z*camera_direction.z)))
		var alpha:=int(f32(f32(f32(facing*facing)*intensity)*255.0))
		var rgba:=((alpha<<24)|(int(f32(tint.z*255.0))<<16)|(int(f32(tint.y*255.0))<<8)|int(f32(tint.x*255.0)))&0xffffffff
		for corner in 6:
			var at: int=plane_index*6+corner;vertices[at]=transformed[ORDER[corner]]
			packed.encode_u32(at*4,rgba)
	return {"available":true,"vertices":vertices,"colors":packed}
func tick(camera: Camera3D,pulse_size: Variant,intensity: Variant) -> bool:
	# Scene/controller clock owns pulse. Missing inputs are explicit; this
	# renderer has no timer, _process clock, alpha lifetime or server authority.
	if closed or not is_instance_valid(camera) or not camera.is_inside_tree() or not (pulse_size is int or pulse_size is float) or not (intensity is int or intensity is float):return false
	if not texture_ready:batch.visible=false;return false
	if dirty:_rebuild()
	if members.is_empty():return true
	var epoch:=revision;var alpha_values: Dictionary={};var color_values: Dictionary={};var complete:=true;var has_bounds:=false;var draw_bounds:=AABB()
	for index in members.size():
		var member: Dictionary=members[index];var entry: Dictionary=member.entry;var row: Dictionary=member.row
		var owner:=alive(entry.owner,entry.id);var part:=alive(row.anchor,row.id)
		var output: Dictionary={"available":false}
		if owner!=null and part!=null and entries.has(member.entity) and is_same(entries[member.entity],entry):
			var key: String=str(member.entity)+":"+str(row.model)
			if not alpha_values.has(key):alpha_values[key]=entry.alpha.call(row.model) if entry.alpha.is_valid() else null
			if closed or revision!=epoch:return false
			if not color_values.has(key):
				var current: Variant=entry.color
				if entry.color_provided:current=entry.color_source.call(row.model) if entry.color_source.is_valid() else null
				color_values[key]=Color(current.x,current.y,current.z) if current is Vector3 and current.is_finite() else current if current is Color and finite_color(current) else null
			# Providers may synchronously forget/re-register/close the owner.
			if closed or revision!=epoch:return false
			# Free/reparent callbacks need full live endpoint validation too, even
			# when the registry's explicit revision was not changed by that writer.
			owner=alive(entry.owner,entry.id);part=alive(row.anchor,row.id)
			if owner!=null and part!=null and (alpha_values[key] is int or alpha_values[key] is float) and color_values[key] is Color:output=project(row.bounds,part.global_transform,camera.global_position,float(pulse_size),float(intensity),color_values[key],float(alpha_values[key]))
		if not output.available:complete=false;stats.unavailable+=1
		for vertex in 18:
			positions[index*18+vertex]=output.vertices[vertex] if output.available else Vector3.ZERO
			if output.available:
				draw_bounds=draw_bounds.expand(output.vertices[vertex]) if has_bounds else AABB(output.vertices[vertex],Vector3.ZERO);has_bounds=true
		for vertex in 18:color_bytes.encode_u32(index*72+vertex*4,output.colors.decode_u32(vertex*4) if output.available else 0)
	if closed or revision!=epoch:return false
	for at in positions.size():
		attributes.encode_u32(at*12,color_bytes.decode_u32(at*4))
	surface.surface_update_vertex_region(0,0,positions.to_byte_array());surface.surface_update_attribute_region(0,0,attributes)
	# Region uploads do not recompute ArrayMesh's original zero-filled AABB.
	# Retain engine frustum culling with truthful current CPU-emitted bounds.
	batch.custom_aabb=draw_bounds;batch.visible=has_bounds
	stats.updates+=1;return complete
func snapshot() -> Dictionary:
	var result:=stats.duplicate();result.closed=closed;result.revision=revision;result.texture=textured_material.snapshot();result.texture_ready=texture_ready;result.pulse_clock="external native presentation owner";result.geometry="18 authored-bounds vertices per eligible non-skin Part";return result
func close() -> void:
	if closed:return
	closed=true;revision+=1;entries.clear();members.clear();selected.clear();positions.clear();colors.clear();color_bytes.clear();batch.mesh=null;batch.visible=false;surface=null
	texture_ready=false;textured_material.clear_texture();uvs.clear();attributes.clear()
