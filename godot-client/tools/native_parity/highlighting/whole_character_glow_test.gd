extends SceneTree
const Glow=preload("res://tools/native_parity/highlighting/whole_character_glow.gd")
const PrimaryState=preload("res://tools/native_parity/ui/actor-alpha-state.gd")
class Layer extends RefCounted:
	var models: Dictionary={}
	var closed:=false
class Owner extends Node3D:
	var parts: Array=[]
	var retired:=false
	var actor_alpha:=Layer.new()
var checks:=0
var failures: Array=[]
var glow
var body
var camera
var alpha:=.5
var alpha_calls:=0
var color_calls:=0
var draw_calls:=0
var draw_unknown:=false
var query_models: Array=[]
var callback:=""
var world_alive:=true
var color:=Vector3(0,1,0)
var late_action:=""
var guard_action:=""
var guard_at:=5
var guard_calls:=0
var replacement_parent: Node3D
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func primary(model: int) -> Variant:
	alpha_calls+=1;query_models.append(model)
	if callback=="forget":glow.forget(7)
	elif callback=="replace":glow.register_entity(7,body,[2],[],Color.RED,primary,target)
	elif callback=="camera":camera.fov+=1
	elif callback=="retire":body.retired=true
	return alpha
func target(model: int) -> Variant:color_calls+=1;query_models.append(model);return color
func draw(model: int) -> Variant:
	draw_calls+=1;query_models.append(model)
	return null if draw_unknown else body.actor_alpha.models[0].presentation_draw_enabled
func mutate(action: String) -> void:
	if action=="retire":body.retired=true
	elif action=="move":body.parts[0].position.x+=.5
	elif action=="reparent":body.parts[0].reparent(replacement_parent)
	elif action=="bounds":body.parts[0].get_meta("native_mesh_source").native_bounds.max[0]+=.5
	elif action=="lifetime":body.set_meta("native_selection_scope",[99])
	elif action=="draw":body.actor_alpha.models[0].set_presentation_draw_enabled(false)
	elif action=="source":body.parts[0].set_meta("native_mesh_source",body.parts[0].get_meta("native_mesh_source").duplicate(true))
	elif action=="free":body.parts[0].free()
func late_primary(_model: int) -> float:mutate(late_action);return 1.0
func late_draw(_model: int) -> bool:return true
func guard(_scope: Dictionary) -> bool:
	guard_calls+=1
	if not guard_action.is_empty() and guard_calls==guard_at:mutate(guard_action)
	return world_alive
func part(parent: Node3D,offset: Vector3,skin: bool=false) -> Node3D:
	var node:=Node3D.new();parent.add_child(node);node.position=offset
	node.set_meta("native_mesh_source",{"node_flags":0x61 if skin else 0x21,"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{"min":[-.5,-.25,0.0],"max":[.5,.25,2.0]}})
	return node
func register(owner: Variant=null,lifetime: Array=[1]) -> bool:
	return glow.register_entity(7,body if owner==null else owner,lifetime,[],Color.GREEN,primary,target) and glow.bind_draw_provider(7,draw)
func tick(old_pulse: float=2.65625) -> bool:return glow.tick(camera,old_pulse,.3)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(800,600);root.add_child(viewport)
	camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,3,10);camera.look_at(Vector3(0,1,0));camera.current=true
	body=Owner.new();viewport.add_child(body);body.actor_alpha.models[0]=PrimaryState.new();body.set_meta("native_selection_scope",[1]);body.parts=[part(body,Vector3(-1,0,0)),part(body,Vector3(1,0,0),true)]
	replacement_parent=Node3D.new();viewport.add_child(replacement_parent)
	glow=Glow.new();viewport.add_child(glow)
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);var texture:=ImageTexture.create_from_image(image)
	check(glow.configure_texture(texture,{"filter":true,"mipmap":true,"clamp":3},true),"CPU control texture borrows actual textured material path")
	check(glow.textured_material.shader.code.contains("depth_draw_never") and not glow.textured_material.shader.code.contains("depth_test_disabled"),"Existing soft texture shader retains depth test and no depth writes")
	check(glow.bind_scope({"world":1},guard) and register(),"Physical owner scope and authored Part index register")
	check(glow.entries[7].parts.size()==2 and glow.entries[7].parts[1].skin,"Whole-body policy includes Skin and rigid source bounds")
	glow.mark([7,7]);check(tick(),"Selected entity updates one whole-character glow")
	check(glow.stats.quads==1 and glow.stats.vertices==6 and glow.stats.source_parts==2 and glow.stats.source_corners==16,"Exactly one quad/six vertices despite multiple Parts and duplicate membership")
	check(alpha_calls==1 and color_calls==1 and draw_calls==1 and query_models==[0,0,0],"Primary alpha/color/draw queried once for model0; no Part alpha multiply")
	var fit: Dictionary=glow.diagnostic(7);var original_positions: PackedVector3Array=glow.positions.duplicate();var surface_id: int=glow.surface.get_instance_id();var material_id: int=glow.textured_material.get_instance_id()
	check(fit.available and fit.scale==1.12,"Explicit modest new halo policy")
	check((fit.halo_screen_max-fit.halo_screen_min).is_equal_approx((fit.body_screen_max-fit.body_screen_min)*1.12),"Fit scales tight projected overall Part bounds by1.12")
	check(tick(200) and glow.positions==original_positions,"Old per-Part pulse2.65 or200 cannot inflate whole-body halo")
	check(glow.surface.get_instance_id()==surface_id and glow.textured_material.get_instance_id()==material_id,"Held selection reuses mesh/material/texture identities")
	for corner in fit.corners:
		var screen: Vector2=camera.unproject_position(corner)
		check(screen.x>=fit.halo_screen_min.x-.001 and screen.x<=fit.halo_screen_max.x+.001 and screen.y>=fit.halo_screen_min.y-.001 and screen.y<=fit.halo_screen_max.y+.001,"Billboard exactly reprojects into selected entity halo rectangle")
	body.parts[0].scale=Vector3(-2,1,.5);body.parts[0].rotation.y=.4
	check(tick() and glow.positions!=original_positions,"Current rotated negative/nonuniform Part transform changes overall extent")
	var before: PackedVector3Array=glow.positions.duplicate();body.parts[1].get_meta("native_mesh_source").native_bounds.max[2]=3.0
	check(tick() and glow.positions!=before,"Current authenticated metadata bounds changes are observed")
	body.parts[1].set_meta("native_highlight_subtree_enabled",false)
	check(tick() and glow.stats.source_parts==1,"Disabled subtree excluded without scanning world")
	body.parts[1].set_meta("native_highlight_subtree_enabled",true)
	color=Vector3(1,.2,0);check(tick() and glow.attributes[0]==255 and glow.attributes[1]==51,"Target color remains data-driven")
	alpha=.2;check(tick() and glow.attributes[0]==127,"Existing primary Gob attenuation below.4 retained")
	alpha=0;check(tick() and not glow.batch.visible,"Zero primary alpha leaves no visible halo")
	alpha=1;body.actor_alpha.models[0].set_presentation_draw_enabled(false)
	check(tick() and not glow.batch.visible and glow.diagnostic(7).reason=="primary-presentation-draw-disabled","Independent primary draw=false suppresses halo at alpha1")
	body.actor_alpha.models[0].set_presentation_draw_enabled(true)
	check(tick() and glow.batch.visible,"Primary draw restoration resumes halo without body state writes")
	draw_unknown=true;check(not tick() and not glow.batch.visible and glow.diagnostic(7).reason=="primary-presentation-draw-unavailable","Unknown primary draw state stays explicitly unavailable");draw_unknown=false
	alpha=.5
	glow.mark([]);check(not glow.batch.visible and tick() and glow.stats.vertices==0,"Release removes glow membership")
	glow.mark([7]);check(tick(),"Hover-only/selected reentry resumes same owner")
	world_alive=false;check(not tick() and not glow.batch.visible,"External world scope retirement fails closed");world_alive=true
	for action in ["camera","retire","forget","replace"]:
		body.retired=false;body.set_meta("native_selection_scope",[1]);register();glow.mark([7]);callback=action
		check(not tick() and not glow.batch.visible,"Synchronous provider mutation rejects stale geometry: "+action)
		callback=""
	body.retired=false;body.set_meta("native_selection_scope",[1]);register();glow.mark([7]);check(tick(),"Owner restored only through explicit registration")
	check(not glow.unregister_entity(7,[99]) and glow.entries.has(7),"Stale retirement token cannot erase successor")
	check(glow.unregister_entity(7,[1]) and not glow.entries.has(7),"Current lifetime retirement removes membership")
	register();glow.mark([7]);body.set_meta("native_selection_scope",[2]);check(not tick() and not glow.batch.visible,"Reused physical owner with changed scope cannot inherit old glow")
	body.set_meta("native_selection_scope",[1]);register();glow.mark([7]);body.position=camera.position
	check(not tick() and not glow.batch.visible,"Near-plane crossing explicitly unavailable rather than capped fan")
	body.position=Vector3.ZERO;register();glow.mark([7])
	var late:=Owner.new();viewport.add_child(late);late.actor_alpha.models[0]=PrimaryState.new();late.set_meta("native_selection_scope",[2]);late.parts=[part(late,Vector3(2,0,0))]
	check(glow.register_entity(8,late,[2],[],Color.RED,late_primary) and glow.bind_draw_provider(8,late_draw),"Second physical selected entity explicitly binds primary draw source")
	for action in ["move","retire","reparent","bounds","lifetime","draw","source"]:
		body.retired=false;body.set_meta("native_selection_scope",[1]);body.actor_alpha.models[0].set_presentation_draw_enabled(true)
		if body.parts[0].get_parent()!=body:body.parts[0].reparent(body)
		register();glow.mark([7,8]);late_action=action
		check(not tick() and not glow.batch.visible,"Later entity provider cannot publish stale earlier fit: "+action)
	late_action="";glow.forget(8);late.free()
	for action in ["move","retire","reparent","bounds","lifetime","draw","source"]:
		body.retired=false;body.set_meta("native_selection_scope",[1]);body.actor_alpha.models[0].set_presentation_draw_enabled(true)
		if body.parts[0].get_parent()!=body:body.parts[0].reparent(body)
		register();glow.mark([7]);guard_calls=0;guard_action=action
		check(not tick() and not glow.batch.visible and guard_calls==5,"Final scope guard cannot publish stale fitted source: "+action)
		guard_action=""
	body.retired=false;body.set_meta("native_selection_scope",[1]);body.actor_alpha.models[0].set_presentation_draw_enabled(true)
	if body.parts[0].get_parent()!=body:body.parts[0].reparent(body)
	register();glow.mark([7]);guard_calls=0;guard_action="free"
	check(not tick() and not glow.batch.visible and guard_calls==5,"Final scope guard freeing a fitted Part cannot publish stale geometry");guard_action=""
	body.parts[0]=part(body,Vector3(-1,0,0));register();glow.mark([7]);body.parts[0].queue_free();check(not tick() and not glow.batch.visible,"Queued Part retirement rejects incomplete body fit")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"snapshot":glow.snapshot(),"extensions":0,"gpu_draws":0,"server_connections":0,"native_builds":0,"scope":"Isolated authored Part bounds/transform/policy fixture, synthetic white texture CPU control; actualfxpa_dot02/c_goldem pixels separate"}
	glow.close();glow.free();body.free();replacement_parent.free();camera.free();viewport.free()
	await process_frame
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close();print("WHOLE_CHARACTER_GLOW ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
