extends SceneTree
# Actual pooled model instances and ordinary selection registry/controller.
# No server, asset workers, native rebuild, input injection or FPS claim.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Registry=preload("res://systems/native_render/door_entity_registry.gd")
const Source=preload("res://systems/native_render/selection_highlight_source.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func bundle() -> Dictionary:
	var rows: Array=[]
	for index in 2:
		rows.append({"name":"visible" if index==0 else "authored_zero","parent":-1,"position":[0,0,0],"orientation":[0,0,0,1],"scale":1.0,"features":[],"flags":33,"alpha":0.6 if index==0 else 0.0,"selfillum":[0,0,0],"mesh":{"vertices":PackedFloat32Array([0,0,0,1,0,0,0,0,1]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":true,"shadow":false,"diffuse":[0.2,0.4,0.6],"ambient":[0.2,0.4,0.6],"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{"min":[0,0,0],"max":[1,1,1]}}})
	return {"sha256":"native-selection-registry-fixture-v1","resource_name":"selection_fixture","value":{"name":"selection_fixture","nodes":rows}}
func state(owner) -> Variant:return owner.renderer_alpha.models[0]
func run() -> void:
	var pool:=Pool.new();var template=pool.model_template(bundle())
	check(template!=null and pool.failure.is_empty(),"Actual native pool/template prepares bounds-bearing model")
	if template==null:quit(1);return
	var one=template.create();var two=template.create();root.add_child(one);root.add_child(two)
	one.set_meta("native_selection_scope",[1,2,3,10,4]);two.set_meta("native_selection_scope",[1,2,3,20,4])
	var source:=Source.collect(one)
	check(source.available and source.parts.size()==2 and source.missing.is_empty(),"Native parsed metadata is collected from actual placement Parts, including authored alpha0")
	var shared=one.meshes[0].material_override
	check(shared==two.meshes[0].material_override,"Fixture genuinely shares pooled source material")
	var registry:=Registry.new();registry.native_highlight_enabled=true;root.add_child(registry)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(4,4,4);registry.configure_highlights(camera)
	var row:={"id":10,"type":9,"eligible":true,"color":"#00ff00"}
	check(registry.register_native(10,row,one),"Ordinary registry registers native instance through new controller")
	check(one.renderer_alpha==null,"Highlight registration does not prematurely enroll static materials")
	registry.mark([10],-1,true)
	check(one.renderer_alpha!=null and state(one).vector_active[2]==1,"Actual registry Tab publishes native channel2 onto base pass")
	check(one.meshes[0].material_overlay==null and one.meshes[1].material_overlay==null and registry.overlays.is_empty(),"Native entity has no coincident full-mesh overlay or duplicate skin pass")
	check(absf(one.meshes[0].material_override.albedo_color.a-0.6)<0.000001 and not one.meshes[1].visible,"Tab preserves raw Part alpha including authored-zero mesh")
	check(two.meshes[0].material_override==shared and shared.albedo_color.r>0.1,"Unselected clone and pooled material remain untouched")
	var writes: int=registry.native_highlight.stats.channel_writes
	for frame in 120:registry.mark([10],-1,true)
	check(registry.native_highlight.stats.channel_writes==writes,"Holding Tab publishes no repeated material changes")
	check(not registry.native_highlight.bounds.texture_ready,"Missing native texture remains explicit instead of drawing solid placeholder planes")
	# A one-pixel fixture texture exercises buffer lifetime only. Original art
	# is validated by the separate active-catalog texture/pixel fixtures.
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	registry.native_highlight.bounds.configure_texture(ImageTexture.create_from_image(image),{"filter":true,"mipmap":true,"clamp":0},false)
	registry.native_highlight.set_process(false);registry.native_highlight._process(0.016)
	var rebuilds: int=registry.native_highlight.bounds.stats.membership_rebuilds
	for frame in 12:registry.native_highlight._process(0.016)
	check(registry.native_highlight.bounds.stats.membership_rebuilds==rebuilds and registry.native_highlight.bounds.stats.parts==2,"Stable selection retains one bounds batch without geometry membership rebuild")
	var changed:=row.duplicate();changed.color="#ff0000";registry.register_native(10,changed,one)
	check(state(one).vectors[2]==Vector3(1,0,0) and one.meshes[0].material_override.albedo_color.g==0,"Same-owner reaction colour republishes held Tab channel")
	one.set_renderer_vector(3,Vector3(0.3,0.2,0.1))
	registry.mark([10],10,true)
	check(state(one).vector_active[1]==1 and state(one).vector_active[2]==1 and state(one).vector_active[3]==1,"Hover, Tab and server Type5 channels coexist")
	registry.mark([10],10,false)
	check(state(one).vector_active[1]==1 and state(one).vector_active[2]==0,"Tab release leaves current hover intact")
	registry.mark([],-1,false)
	check(state(one).selected_vector.is_equal_approx(Vector3(0.3,0.2,0.1)) and state(one).vector_active[3]==1,"Clearing hover/Tab restores existing Type5 channel")
	registry.mark([10],-1,true);registry.forget_entity(10)
	check(not registry.native_highlight.entries.has(10) and state(one).vector_active[2]==0 and state(one).vector_active[3]==1,"Ordinary registry removal clears only owned selection channels")
	check(registry.native_highlight.bounds.selected.is_empty() and registry.marked.is_empty(),"Removal retires bounds membership and public marked subset")
	var replacement=template.create();root.add_child(replacement);replacement.set_meta("native_selection_scope",[1,2,3,10,5])
	registry.register_native(10,row,replacement);registry.mark([10],-1,true)
	check(registry.native_highlight._owner(10)==replacement and state(one).vector_active[2]==0 and state(replacement).vector_active[2]==1,"Same-ID reuse resolves only replacement physical owner/lifetime")
	replacement.set_meta("native_selection_scope",[1,3,4,10,5])
	check(registry.native_highlight._owner(10)==null and registry.native_highlight.model_alpha(0,10)==null,"Changed generation/area invalidates retained reference immediately")
	registry.forget_entity(10)
	var legacy_overlay:=StandardMaterial3D.new();two.meshes[0].material_overlay=legacy_overlay
	var bad=template.create();root.add_child(bad);bad.parts[0].remove_meta("native_mesh_source");bad.parts[1].remove_meta("native_mesh_source")
	registry.register_native(30,{"id":30,"type":9,"eligible":true,"color":"#00ff00"},bad);registry.mark([30],-1,true)
	check(bad.meshes[0].material_overlay==null and two.meshes[0].material_overlay==legacy_overlay,"Unknown provenance never activates duplicate-overlay fallback or changes unrelated overlay")
	registry.native_highlight.close();registry.native_highlight.close()
	check(registry.native_highlight.closed and registry.native_highlight.entries.is_empty(),"Controller close is idempotent and clears retained channels/weak records")
	registry.free();camera.free();one.retire();two.retire();replacement.retire();bad.retire();pool.clear()
	await process_frame;await process_frame
	print("NATIVE_SELECTION_REGISTRY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
