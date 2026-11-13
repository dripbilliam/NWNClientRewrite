extends SceneTree
# Actual pooled static models + actual EffectWorld.reserve/alpha_commands.
# No resource service, protocol, server, clocks or renderer benchmark is started.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
const Alpha=preload("res://tools/native_parity/visibility/alpha_program.gd")
var checks:=0
var failures: Array=[]
var retained_extension: Resource
var observations: Array=[]
class World:
	extends Node3D
	var desired: Dictionary={}
	var installed: Dictionary={}
	var instances: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func near(a: float,b: float) -> bool:return absf(a-b)<0.000001
func row(name: String,alpha: float,rendered: bool=true) -> Dictionary:
	return {"name":name,"parent":-1,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"features":[],"flags":33,"alpha":alpha,"selfillum":[0.0,0.0,0.0],"mesh":{"vertices":PackedFloat32Array([0,0,0,1,0,0,0,0,1]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":rendered,"shadow":false,"diffuse":[0.2,0.4,0.6],"ambient":[0.2,0.4,0.6]}}
func bundle() -> Dictionary:
	return {"sha256":"static-alpha-dedicated-fixture-v1","resource_name":"alpha_fixture","value":{"name":"alpha_fixture","nodes":[row("visible",1.0),row("authored_zero",0.0),row("hit_only",1.0,false)]}}
func reserve(fx,actor: int,lifetime: int=3) -> int:
	fx.reserve(actor,lifetime,{"visualId":6},false)
	return fx.next_effect
func set_alpha(value: float) -> Dictionary:return {"kind":"set_alpha","alpha_word":Alpha.word(value)}
func bind(world,id: int,instance,key: String="model-a") -> void:
	world.desired[id]={"key":key,"object":{"id":id,"objectType":9,"nativeLifetime":3,"disclosureLifetime":7}}
	world.installed[id]=key;world.instances[id]=instance
func dispatch(fx,id: int,actor: int,commands: Array,token: int=0) -> Dictionary:
	return fx.alpha_commands(id,actor,token,commands)
func static_case(enhanced: bool) -> void:
	var pool:=Pool.new();pool.native_lighting=enhanced
	var template=pool.model_template(bundle())
	check(template!=null and pool.failure.is_empty(),"Actual immutable pooled template builds (enhanced=%s)"%enhanced)
	if template==null:return
	check(pool.model_template(bundle())==template,"Same bundle reuses the actual pooled template")
	var one=template.create();var two=template.create();root.add_child(one);root.add_child(two)
	check(one.renderer_alpha==null and two.renderer_alpha==null,"Static alpha enrollment is lazy on both clones")
	check(one.meshes.size()==2 and one.pick_surfaces.size()==1 and one.parts.size()==3,"Rendered, authored-zero and hidden hit-only physical parts survive cloning")
	var first=one.meshes[0];var second=two.meshes[0];var pooled=first.material_override
	var hidden_geometry=one.pick_surfaces[0].get_meta("native_pick_geometry")
	check(first.mesh==second.mesh and pooled==second.material_override,"Static clones share immutable mesh and original material before enrollment")
	check(one.set_renderer_alpha(0.5) and near(first.material_override.albedo_color.a,0.5),"Lazy static renderer-alpha command composes current Part alpha")
	check(first.material_override!=pooled and second.material_override==pooled and pooled.albedo_color.a==1.0,"First clone publication never mutates second clone or pooled material")
	check(not one.meshes[1].visible and one.meshes[1].material_override.albedo_color.a==0.0,"Authored zero-alpha static Part stays hidden")
	check(one.set_renderer_vector(3,[0.5,0.25,0.75]) and near(first.material_override.albedo_color.r,0.1) and near(first.material_override.albedo_color.g,0.1),"Static channel3 multiplies raw Part diffuse")
	check(first.material_override.emission_enabled and second.material_override.albedo_color.r==pooled.albedo_color.r and not pooled.emission_enabled,"Static additive illumination stays private to the selected clone")
	check(one.set_renderer_vector(3,null) and near(first.material_override.albedo_color.r,0.2) and not first.material_override.emission_enabled,"Static clear restores authored diffuse/emission")
	check(one.set_presentation_draw_enabled(false) and not first.visible and one.visible and second.visible,"Static draw gate hides meshes without hiding target root or other clone")
	check(one.pick_surfaces[0].get_meta("native_pick_geometry")==hidden_geometry and one.parts.size()==3 and hidden_geometry.get_shape()!=null,"Alpha/draw publication retains original hidden hit geometry and physical parts")
	check(one.set_presentation_draw_enabled(true) and first.visible and not one.meshes[1].visible,"Draw gate restores only drawable nonzero Part products")
	check(one.renderer_alpha_model_indices()==[0],"Static target explicitly publishes model0 only")
	var retained_owner=one.renderer_alpha;one.retire()
	check(retained_owner.closed and one.renderer_alpha==null and one.renderer_alpha_model_indices().is_empty(),"Static retirement closes material contexts before releasing physical nodes")
	check(not one.set_renderer_alpha(1.0) and not one.set_renderer_vector(3,[1,1,1]) and not one.set_presentation_draw_enabled(true),"Retired static target rejects every later command")
	check(two.set_renderer_alpha(0.25) and near(second.material_override.albedo_color.a,0.25) and pooled.albedo_color.a==1.0,"Surviving clone enrolls independently after first clone retirement")
	observations.append({"case":"pooled-static","enhanced":enhanced,"parts":two.parts.size(),"meshes":two.meshes.size(),"hidden":two.pick_surfaces.size()})
	two.retire();pool.clear()
func dispatch_cases() -> void:
	var pool:=Pool.new();var template=pool.model_template(bundle())
	var a=template.create();var b=template.create();var replacement=template.create();root.add_child(a);root.add_child(b);root.add_child(replacement)
	var world:=World.new();root.add_child(world);bind(world,10,a);bind(world,20,b)
	var fx:=Effects.new();fx.set_process(false);root.add_child(fx);fx.world=world;fx.client=fx
	var id:=reserve(fx,10)
	check(fx.entries.has(id) and fx.records.has(id) and fx.records[id].presentation_lifetime==[["nativeLifetime",true,3],["disclosureLifetime",true,7]],"Actual reserve captures both detached presentation lifetime tokens")
	var result:=dispatch(fx,id,10,[set_alpha(0.5),{"kind":"set_vector_channel","channel":3,"vector_words":[Alpha.word(0.5),Alpha.word(0.25),Alpha.word(0.75)]}])
	check(result.available and near(a.meshes[0].material_override.albedo_color.a,0.5) and near(a.meshes[0].material_override.albedo_color.r,0.1),"Actual EffectWorld decodes native scalar/vector words onto actual static target")
	check(not result.scene_detach_parity,"Dispatcher explicitly reports unsupported SceneDetach parity")
	result=dispatch(fx,id,10,[{"kind":"clear_vector_channel","channel":3},{"kind":"set_blocked","value":true},{"kind":"set_visible","value":false}])
	check(result.available and a.get_meta("native_fade_blocked")==true and not a.meshes[0].visible and a.visible,"Actual clear/blocked/draw commands preserve root admission")
	check(world.instances[10]==a and world.desired[10].object.nativeLifetime==3 and world.desired[10].object.disclosureLifetime==7,"Presentation commands never mutate received identity/lifetime ownership")
	dispatch(fx,id,10,[{"kind":"set_visible","value":true}])
	var before: float=b.meshes[0].material_override.albedo_color.a
	result=dispatch(fx,id,20,[set_alpha(0.125)])
	check(not result.available and b.meshes[0].material_override.albedo_color.a==before and b.renderer_alpha==null,"Effect bound to actor10 cannot publish onto actor20")
	check(not dispatch(fx,id,10,[set_alpha(0.25)],55).available,"Private token cannot redirect an ordinary effect")
	world.installed[10]="old-model";check(not dispatch(fx,id,10,[set_alpha(0.25)]).available,"Unadmitted current model rejects publication")
	world.installed[10]="model-a";world.desired[10].object.disclosureLifetime=8
	check(not dispatch(fx,id,10,[set_alpha(0.25)]).available and fx.records[id].presentation_lifetime[1][2]==7,"Changed disclosure rejects old effect; captured token remains detached")
	id=reserve(fx,10);check(dispatch(fx,id,10,[set_alpha(0.75)]).available,"Fresh actual reserve binds current disclosure lifetime")
	world.desired[10].object.nativeLifetime=4;check(not dispatch(fx,id,10,[set_alpha(0.25)]).available,"Reused object ID with changed native lifetime rejects prior effect")
	world.desired[10].object.nativeLifetime=3;id=reserve(fx,10)
	# Real material publication emits changed/visibility callbacks synchronously.
	# First command may complete; subsequent commands must never touch old/new models.
	var original=a.meshes[0].material_override
	var old_color: Color=original.albedo_color
	a.meshes[0].visibility_changed.connect(func():world.instances[10]=replacement,CONNECT_ONE_SHOT)
	result=dispatch(fx,id,10,[{"kind":"set_visible","value":false},set_alpha(0.125)])
	check(not result.available and near(original.albedo_color.a,old_color.a) and replacement.renderer_alpha==null,"Replacement during visibility callback stops later commands without touching replacement")
	world.instances[10]=a;a.set_presentation_draw_enabled(true);id=reserve(fx,10)
	a.meshes[0].visibility_changed.connect(func():world.installed[10]="replaced-key",CONNECT_ONE_SHOT)
	result=dispatch(fx,id,10,[{"kind":"set_visible","value":false},set_alpha(0.125)])
	check(not result.available and near(original.albedo_color.a,old_color.a),"Model admission change during callback stops later commands on same instance")
	world.installed[10]="model-a";a.set_presentation_draw_enabled(true);id=reserve(fx,10)
	a.meshes[0].visibility_changed.connect(func():world.desired[10].object.disclosureLifetime+=1,CONNECT_ONE_SHOT)
	result=dispatch(fx,id,10,[{"kind":"set_visible","value":false},set_alpha(0.125)])
	check(not result.available and near(original.albedo_color.a,old_color.a),"Disclosure change during callback stops later commands")
	a.set_presentation_draw_enabled(true);id=reserve(fx,10)
	a.meshes[0].visibility_changed.connect(func():fx.receive({"kind":"visual-cancel","effectId":id}),CONNECT_ONE_SHOT)
	result=dispatch(fx,id,10,[{"kind":"set_visible","value":false},set_alpha(0.125)])
	check(not result.available and not fx.entries.has(id) and not fx.records.has(id),"Effect cancellation during callback stops later commands and retires both stores")
	a.set_presentation_draw_enabled(true);id=reserve(fx,10)
	result=dispatch(fx,id,10,[set_alpha(0.6),{"kind":"unknown"},set_alpha(0.125)])
	check(not result.available and near(original.albedo_color.a,0.6),"Unsupported command reports failure without replaying or rolling back already-published commands")
	a.meshes[0].visibility_changed.connect(func():fx.close(),CONNECT_ONE_SHOT)
	result=dispatch(fx,id,10,[{"kind":"set_visible","value":false},set_alpha(0.125)])
	check(not result.available and fx.closed and fx.entries.is_empty() and fx.records.is_empty(),"Owner close during callback retires effects before later publication")
	check(not dispatch(fx,id,10,[set_alpha(1.0)]).available,"Closed owner cannot resurrect retired effect")
	fx.free();world.free();a.retire();b.retire();replacement.retire();pool.clear()
func run() -> void:
	if OS.get_cmdline_user_args().has("--existing-kernel"):
		retained_extension=load("res://native/particle_kernel.gdextension")
		check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Approved frozen native library loads without rebuilding")
	static_case(false);static_case(true);dispatch_cases()
	await process_frame;await process_frame
	var folder:=OS.get_environment("NWN_PARITY_UI_TEST_DIR")
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("static-alpha-dispatch.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"server_connections":0,"native_builds":0,"performance_claim":false},"  "));file.close()
	print("NATIVE_PARITY_STATIC_ALPHA_DISPATCH ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
