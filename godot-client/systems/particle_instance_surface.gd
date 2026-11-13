extends Node3D
# Experimental RenderingDevice path. Each packet owns its bytes until the
# render-thread callback finishes. GPU resources are strongly retained there.
const MAX_VERTICES:=196608
var capacity:=0
var vertex_count:=0
var epoch:=-1
var sequence:=-1
var retired:=true
var source_texture: Texture2D
var additive:=false
var two_sided:=false
var engine_lighting:=false
var native_surface_output:=false
var draw_material: ShaderMaterial
var instances: MultiMesh
var node: MultiMeshInstance3D
var mesh: Mesh:
	get: return null # No six-vertex CPU surface; use debug_streams() explicitly.
var last_bytes:=PackedByteArray()
static var shaders: Dictionary={}
static var quad: ArrayMesh
class Lease extends RefCounted:
	var mutex:=Mutex.new()
	var alive:=true
	var sequence:=-1
	var uploads:=0
	var bytes:=0
	var error:=""
var lease: Lease
var native_upload: RefCounted
var batch_upload:=false
static var pending_batch: RefCounted
static func queue_batch(owner: RefCounted,bytes: PackedByteArray,next_sequence: int) -> bool:
	if pending_batch!=null and pending_batch.call("enqueue",owner,bytes,next_sequence): return true
	pending_batch=ClassDB.instantiate("NwnParticleUploadBatch")
	if not pending_batch.call("enqueue",owner,bytes,next_sequence): return false
	pending_batch.call_deferred("submit",pending_batch)
	return true
func configure(texture: Texture2D,owner_epoch: int,use_additive: bool=false,double_sided: bool=false,scene_lighting: bool=false,native_output: bool=false) -> void:
	retire(); retired=false; epoch=owner_epoch; sequence=-1
	source_texture=texture; additive=use_additive; two_sided=double_sided; engine_lighting=scene_lighting
	native_surface_output=native_output
	visible=false; transform=Transform3D.IDENTITY; top_level=true
static func quad_mesh() -> ArrayMesh:
	if quad!=null: return quad
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,1,0),Vector3(1,1,0),Vector3(-1,-1,0),Vector3(1,-1,0)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,2,1,3])
	quad=ArrayMesh.new(); quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return quad
func _material() -> ShaderMaterial:
	if native_surface_output: return preload("res://systems/native_render/native_particle_material.gd").make(source_texture,additive,two_sided,vertex_code())
	var enhanced:=engine_lighting and preload("res://systems/native_render/native_light_policy.gd").requested()
	if enhanced: preload("res://systems/native_render/native_light_palette.gd").ensure()
	var key:=str(additive)+str(two_sided)+str(engine_lighting)+str(enhanced)
	if not shaders.has(key):
		var shader:=Shader.new()
		shader.code="""shader_type spatial;
render_mode skip_vertex_transform,depth_draw_never,shadows_disabled,specular_disabled,%s,%s%s;
uniform sampler2D original_texture : source_color,filter_linear_mipmap;
void vertex(){
%s
}
void fragment(){vec4 value=texture(original_texture,UV)*COLOR;ALBEDO=value.rgb;ALPHA=value.a;SPECULAR=0.0;}
%s
""" % ["blend_add" if additive else "blend_mix","cull_disabled" if two_sided else "cull_front","" if engine_lighting else ",unshaded",vertex_code(),"void light(){DIFFUSE_LIGHT+=ATTENUATION*LIGHT_COLOR/PI;}" if engine_lighting else ""]
		if enhanced:
			shader.code=shader.code.replace("uniform sampler2D original_texture",preload("res://systems/native_render/native_light_palette.gd").shader_code()+"\nuniform sampler2D original_texture").replace("VERTEX=(VIEW_MATRIX*vec4(point,1.0)).xyz;","VERTEX=(VIEW_MATRIX*vec4(point,1.0)).xyz; nwn_world_vertex=point;").replace("DIFFUSE_LIGHT+=ATTENUATION*LIGHT_COLOR/PI;","vec2 native_lamp=nwn_local_light(ATTENUATION,SPECULAR_AMOUNT,LIGHT_IS_DIRECTIONAL); DIFFUSE_LIGHT+=native_lamp.x*LIGHT_COLOR/PI;")
		shaders[key]=shader
	var material:=ShaderMaterial.new(); material.shader=shaders[key]; material.set_shader_parameter("original_texture",source_texture); return material
static func vertex_code() -> String:
	return """
 uvec4 parts=uvec4(round(COLOR));
 uint red=parts.x&255u;
 uint green=((parts.x>>8u)|(parts.y<<2u))&255u;
 uint blue=((parts.y>>6u)|(parts.z<<4u))&255u;
 uint alpha=((parts.z>>4u)|(parts.w<<6u))&255u;
 if(VERTEX_ID>=2){alpha=(parts.w>>2u)&255u;}
 COLOR=vec4(float(red),float(green),float(blue),float(alpha))/255.0;
 UV=vec2((VERTEX_ID==0||VERTEX_ID==2)?INSTANCE_CUSTOM.y:INSTANCE_CUSTOM.x,VERTEX_ID<2?INSTANCE_CUSTOM.w:INSTANCE_CUSTOM.z);
 vec3 point=MODEL_MATRIX[VERTEX_ID].xyz;
 VERTEX=(VIEW_MATRIX*vec4(point,1.0)).xyz;
 // Existing particle arrays have the default world-space +Z normal. Keep
 // its view transform for directional sky irradiance; corner-packed model
 // matrices are data and must never participate in normal transformation.
 NORMAL=mat3(VIEW_MATRIX)*vec3(0.0,0.0,1.0);
"""
func _cancel() -> void:
	if native_upload!=null: native_upload.call("cancel")
	if lease!=null:
		lease.mutex.lock(); lease.alive=false; lease.mutex.unlock()
func _allocate(next_capacity: int) -> void:
	_cancel()
	if node==null:
		node=MultiMeshInstance3D.new(); add_child(node); node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_material==null: draw_material=_material()
	var next:=MultiMesh.new(); next.transform_format=MultiMesh.TRANSFORM_3D; next.use_colors=true; next.use_custom_data=true
	next.mesh=quad_mesh(); next.instance_count=next_capacity/6; next.visible_instance_count=0
	var initial:=PackedFloat32Array(); initial.resize(next.instance_count*20); next.buffer=initial
	node.multimesh=next; node.material_override=draw_material; instances=next; capacity=next_capacity
	var use_native:=ClassDB.class_exists("NwnParticleUpload") and not OS.get_cmdline_user_args().has("--particle-instance-upload=gd") and OS.get_environment("NWN_PARTICLE_INSTANCE_UPLOAD")!="gd"
	if use_native:
		native_upload=ClassDB.instantiate("NwnParticleUpload"); native_upload.call("configure",next,next_capacity); lease=null
		batch_upload=ClassDB.class_exists("NwnParticleUploadBatch") and (OS.get_cmdline_user_args().has("--particle-instance-upload=batch") or OS.get_environment("NWN_PARTICLE_INSTANCE_UPLOAD")=="batch")
	else: native_upload=null; lease=Lease.new()
func upload_error() -> String:
	if native_upload!=null:
		var code: int=native_upload.call("error"); return "" if code==0 else "Native particle upload failed: "+str(code)
	if lease==null: return ""
	lease.mutex.lock(); var value:=lease.error; lease.mutex.unlock(); return value
func upload_backend() -> String:
	return ("batch" if batch_upload else "native") if native_upload!=null else "gd" if lease!=null else "unallocated"
func apply_instances(owner_epoch: int,next_sequence: int,count: int,next_capacity: int,bytes: PackedByteArray,bounds: AABB) -> bool:
	if retired or owner_epoch!=epoch or next_sequence<=sequence: return false
	if count<0 or count%6 or next_capacity<count or next_capacity<capacity or next_capacity>MAX_VERTICES or next_capacity%6 or bytes.size()!=count/6*80: return false
	if count>0 and (not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<0 or bounds.size.y<0 or bounds.size.z<0): return false
	if not upload_error().is_empty(): return false
	if next_capacity>capacity: _allocate(next_capacity)
	if instances!=null:
		instances.custom_aabb=bounds.grow(0.001) if count>0 else AABB(); instances.visible_instance_count=count/6
	if count>0 and native_upload!=null:
		# The bound self reference keeps the native target/resource alive until
		# RenderingServer releases the call, even after this Node is retired.
		if batch_upload:
			if not queue_batch(native_upload,bytes,next_sequence): return false
		else: RenderingServer.call_on_render_thread(Callable(native_upload,"upload").bind(native_upload,bytes,next_sequence))
	elif count>0:
		var resource:=instances; var retained:=lease
		RenderingServer.call_on_render_thread(func():
			retained.mutex.lock()
			if retained.alive and next_sequence>retained.sequence:
				var rd:=RenderingServer.get_rendering_device(); var rid:=RenderingServer.multimesh_get_buffer_rd_rid(resource.get_rid())
				if rd==null or not rid.is_valid(): retained.error="Particle instance GPU buffer is absent"
				else:
					var error:=rd.buffer_update(rid,0,bytes.size(),bytes)
					if error!=OK: retained.error="Particle prefix update failed: "+str(error)
					else: retained.uploads+=1; retained.bytes+=bytes.size(); retained.sequence=next_sequence
			retained.mutex.unlock())
	last_bytes=bytes; sequence=next_sequence; vertex_count=count; visible=count>0; return true
func debug_streams() -> Dictionary:
	return preload("res://systems/native_render/particle_instance_codec.gd").to_streams(last_bytes,vertex_count,capacity)
func retire() -> void:
	_cancel(); retired=true; visible=false
	if node!=null: node.multimesh=null; node.material_override=null
	instances=null; draw_material=null; source_texture=null; capacity=0; vertex_count=0; last_bytes=PackedByteArray(); lease=null; native_upload=null
