extends SceneTree
const Before=preload("res://baseline_model_template.gd")
const Candidate=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):report=arg.substr(9)
 if report.is_empty() or not report.is_absolute_path() or FileAccess.file_exists(report):
  push_error("Fresh explicit absolute report path required");quit(2);return
 run.call_deferred()
func bundle() -> Dictionary:
 var mesh:={"vertices":PackedFloat32Array([0,0,0,1,0,0,0,0,1]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":true,"shadow":true,"diffuse":[0.4,0.5,0.6],"native_area":0.5}
 var nodes: Array=[]
 for index in 3:
  var row:={"name":"piece_"+str(index),"parent":-1 if index==0 else 0,"position":[0.0,float(index),0.0],"orientation":[0,0,0,1],"scale":1.0,"features":[],"flags":33,"mesh":mesh.duplicate(true),"alpha":1.0}
  if index==1:row.mesh={};row.flags=0
  if index==2:row.mesh.render=false
  nodes.append(row)
 return {"value":{"name":"tiny_static","nodes":nodes},"resource_name":"tiny_static","sha256":"a".repeat(64),"textures":{},"emitter_textures":{},"animation_sources":[],"error":""}
func view(value) -> Dictionary:
 var parts: Array=[]
 for part in value.parts:parts.append({"name":part.name,"pose":part.transform,"index":part.get_meta("native_part_index"),"source":part.get_meta("native_mesh_source",{}),"parent":part.get_meta("native_part_parent"),"area":part.get_meta("native_part_area",null)})
 var meshes: Array=[]
 for item in value.meshes:meshes.append({"mesh":item.mesh,"material":item.material_override,"pose":item.transform,"shadow":item.cast_shadow,"source":item.get_meta("native_mesh_source"),"pick":item.get_meta("native_pick_geometry")})
 var picks: Array=[]
 for item in value.pick_surfaces:picks.append(item.get_meta("native_pick_geometry"))
 return {"parts":parts,"meshes":meshes,"picks":picks,"bounds":value.get_meta("native_scene_bounds",null),"model":value.get_meta("native_model_name")}
func one_layout(compact: bool) -> void:
 var pool:=Pool.new();pool.compact_static_parts=compact;pool.use_prepared_geometry=false
 var source:=bundle();var before:=Before.new();var target:=Candidate.new()
 check(before.build(source,pool) and target.build(source,pool),"Actual current source installation builds both templates")
 check(before.scene.get_state().get_node_count()==target.scene.get_state().get_node_count(),"Packed node topology unchanged")
 var held: Node=target._first_root;var held_id:=held.get_instance_id()
 check(held.get_parent()==null and not held.is_inside_tree(),"Retained construction root was never admitted")
 var original=before.create();var first=target.create();var second=target.create()
 check(original!=null and first!=null and second!=null,"All placements are created")
 check(first.get_child(0).get_instance_id()==held_id and target._first_root==null,"First create transfers the exact retained tree once")
 check(target.first_instance_reuses==1 and target.packed_instance_creations==1,"Second create uses immutable PackedScene")
 check(view(first)==view(original) and view(second)==view(original),"Transforms, provenance, bounds, hit resources and shared render resources match")
 check(first.parts[0]!=second.parts[0] and first.meshes[0]!=second.meshes[0],"Physical Parts and geometry nodes stay private")
 check(first.meshes[0].mesh==second.meshes[0].mesh and first.meshes[0].material_override==second.meshes[0].material_override,"Immutable mesh and base material identities stay shared")
 first.parts[0].position=Vector3(9,8,7);var third=target.create()
 check(view(second)==view(original) and view(third)==view(original),"First placement mutation does not change packed rest state")
 check(first.renderer_alpha==null and second.renderer_alpha==null,"New renderer-alpha owner remains lazy")
 check(first.set_renderer_alpha(0.4) and original.set_renderer_alpha(0.4),"Actual current alpha path accepts both first placements")
 check(first.renderer_alpha.snapshot()==original.renderer_alpha.snapshot(),"New alpha state and endpoint count remain equivalent")
 check(first.meshes[0].material_override.albedo_color==original.meshes[0].material_override.albedo_color and first.meshes[0].material_override.transparency==original.meshes[0].material_override.transparency,"Private alpha material storage matches baseline")
 check(second.renderer_alpha==null and second.meshes[0].material_override!=first.meshes[0].material_override,"First placement alpha never changes another placement")
 check(first.set_presentation_draw_enabled(false) and original.set_presentation_draw_enabled(false) and not first.meshes[0].visible and second.meshes[0].visible,"Private draw gate remains isolated")
 pool.clear();check(is_instance_valid(first.get_child(0)) and first.get_child(0).get_instance_id()==held_id,"Explicit pool clear preserves transferred live tree")
 target=null;check(is_instance_valid(first.get_child(0)),"Template destruction cannot free transferred placement")
 observations.append({"compact":compact,"parts":first.parts.size(),"meshes":first.meshes.size(),"hidden":first.pick_surfaces.size()})
 for item in [original,first,second,third]:item.free()
 before=null;pool.clear()
func unused_root() -> WeakRef:
 var pool:=Pool.new();pool.use_prepared_geometry=false
 var item:=Candidate.new();check(item.build(bundle(),pool),"Unused current template builds")
 var observed:=weakref(item._first_root);item=null;pool.clear();return observed
func run() -> void:
 check(DisplayServer.get_name()=="headless","Tiny check does not create a physical display")
 for compact in [false,true]:one_layout(compact)
 var observed:=unused_root();check(observed.get_ref()==null,"Unused retained tree is released at template destruction")
 var failed:=Candidate.new();var pool:=Pool.new();var bad:=bundle();bad.error="authored failure"
 check(not failed.build(bad,pool) and failed.scene==null and failed._first_root==null,"Failed installation retains no first tree")
 failed=null;pool.clear()
 for frame in 2:await process_frame
 var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"gpuTests":0,"serverConnections":0,"nativeBuilds":0,"scope":"Tiny actual current ModelTemplate/ModelInstance/Pool headless contract: two authored three-Part models, no assets/world/native DLL. Real current alpha/provenance paths and root-transfer lifetime. Not the prior146-case suite or loading/performance acceptance."}
 var output:=FileAccess.open(report,FileAccess.WRITE)
 if output==null:push_error("Cannot create fresh explicit fixture report");quit(2);return
 output.store_string(JSON.stringify(result,"  "));output.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
