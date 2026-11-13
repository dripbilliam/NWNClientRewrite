extends SceneTree
const Contract=preload("res://systems/native_render/native_material_contract.gd")
const MaterialOwner=preload("res://systems/native_render/native_model_material.gd")
const Batches=preload("res://systems/native_render/static_scenery_batches.gd")
const BaseMerge=preload("res://systems/native_render/base_static_draw_merge.gd")
const Template=preload("res://systems/native_render/model_template.gd")
class Tile:
	extends Node3D
	var meshes: Array=[]
	var limitations: Array=[]
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func material() -> MaterialOwner:
	var owner:=MaterialOwner.new();owner.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0]);return owner
func geometry() -> ArrayMesh:
	var value:=ArrayMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK]);arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2]);value.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);value.set_meta(BaseMerge.CPU_STREAMS,arrays);return value
func source(parent: Node,mesh: ArrayMesh,owner: MaterialOwner) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=owner;node.set_meta("native_mesh_source",{"part_index":0,"part_name":"surface","parsed_render":true,"original_alpha":1.0,"native_tilefade_available":true,"native_tilefade":0});parent.add_child(node);return node
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var normal:=material();var original_shader:=normal.shader;var original_code:=original_shader.code
	check(Contract.supports(original_shader,false),"Factory-generated ordinary native shader has explicit owned uniform contract")
	check(Contract.describe(original_shader).available and Contract.describe(original_shader).parameters.is_empty(),"Ordinary native family declares no instance uniforms")
	check(not Contract.supports(original_shader,true,true),"A known shader cannot be reclassified as another uniform family")
	var unknown:=Shader.new();unknown.code="shader_type spatial; render_mode unshaded; void fragment(){ALBEDO=vec3(1.0);}"
	check(not Contract.supports(unknown,false) and not Contract.describe(unknown).available,"Unregistered custom shader is explicit fallback even when it has no uniforms")
	var fog:=material();fog.native_surface_output=true;fog.native_tile_fog_enabled=true
	check(Contract.supports(fog.shader,true,true) and not Contract.supports(fog.shader,true),"Known native tile-fog parameter needs an owner that explicitly supports its context")
	var view:=Contract.describe(fog.shader);view.parameters.append("mutated-consumer-view")
	check(Contract.describe(fog.shader).parameters==[Contract.TILE_FOG],"Contract views cannot mutate the internal known uniform list")
	var scope:=Node3D.new();root.add_child(scope);var batch:=Batches.new();scope.add_child(batch);var mesh:=geometry()
	var a:=Tile.new();scope.add_child(a);a.set_meta("native_tile_index",0);a.meshes=[source(a,mesh,normal)]
	var b:=Tile.new();scope.add_child(b);b.set_meta("native_tile_index",1);b.position.x=2;b.meshes=[source(b,mesh,normal)]
	check(batch.eligibility(a,a.meshes[0])=="","Known immutable native tile is admitted without live mesh property enumeration")
	batch.consider_tile(0,a);batch.consider_tile(1,b);batch.flush(100,8)
	check(batch.members.size()==2 and a.meshes[0].get_meta("native_static_batch_draw",false),"Actual native instancing uses the owned contract")
	var base:=BaseMerge.new();scope.add_child(base);var placement:=Template.Placement.new();scope.add_child(placement);placement.static_draw_proof={"revision":"base-static-draw-proof-v1","available":true,"own_animation_count":0,"parts":{0:{"name":"surface"}}};placement.meshes=[source(placement,mesh,normal)]
	check(base._candidate_reason(placement,placement.meshes[0])=="","BASE draw admission shares the same reflection-free known shader contract")
	normal.shader=unknown
	check(batch.members.is_empty() and not a.meshes[0].get_meta("native_static_batch_draw",false) and not b.meshes[0].get_meta("native_static_batch_draw",false),"Replacing a material shader synchronously withdraws all prior source draws")
	check(batch.eligibility(a,a.meshes[0])=="unowned-or-mutated-shader-contract" and base._candidate_reason(placement,placement.meshes[0])=="unowned-or-mutated-shader-contract","Terrain and BASE reject custom replacement shaders")
	normal.shader=original_shader
	check(Contract.supports(original_shader,false),"Replacing the binding did not invalidate an unchanged original program")
	batch.consider_tile(0,a);batch.consider_tile(1,b);batch.flush(100,8)
	check(batch.members.size()==2,"An unchanged original shader can re-enter through normal eligibility")
	original_shader.code=original_code+"\n// runtime mutation\n"
	check(not Contract.supports(original_shader,false) and Contract.describe(original_shader).reason=="program-mutated","Any mutation invalidates that exact known program before reuse")
	check(batch.members.is_empty() and not a.meshes[0].get_meta("native_static_batch_draw",false) and a.meshes[0].visible and a.meshes[0].layers==1,"Runtime Shader.changed withdraws sources even though ShaderMaterial only relays it in editor mode")
	check(base._candidate_reason(placement,placement.meshes[0])=="unowned-or-mutated-shader-contract","BASE refuses the mutated canonical program")
	original_shader.code=original_code
	check(not Contract.supports(original_shader,false),"Restoring text cannot resurrect a retired program contract")
	var transient:=Shader.new();transient.code="shader_type spatial;";var weak:=weakref(transient)
	check(Contract.register_program(transient,"shader_type spatial;",false),"Small explicitly owned program can register at its construction boundary")
	transient=null;Contract._retire_dead()
	check(weak.get_ref()==null and Contract.snapshot().retired>=1,"Registry holds weak identities and retires released programs")
	check(not Contract.register_program(unknown,"shader_type spatial; instance uniform float guessed=0.0;",false),"Unknown instance declarations cannot be marked as an owned zero-uniform family")
	check(Contract.snapshot().entries<=Contract.MAX_PROGRAMS,"Contract registry has an explicit bounded entry policy")
	var state:=Contract.snapshot();base.close();batch.close();scope.free();await process_frame
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state":state,"scope":"Owned Shader program contracts, native terrain/BASE eligibility and runtime replacement/mutation withdrawal. Native headless correctness only; no GPU or timing claim."},"\t")+"\n");output.close();print("NATIVE_MATERIAL_CONTRACT ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
