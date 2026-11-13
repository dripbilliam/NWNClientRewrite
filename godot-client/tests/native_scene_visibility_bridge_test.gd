extends SceneTree
# Actual World-shaped scope + EffectWorld/VisualRuntime and Actor alpha owners.
# Native scene virtuals/fog/creature-state/clock delivery are explicit lower
# ports in this fixture, not claims that those unresolved game hooks exist.
const Bridge=preload("res://systems/native_render/native_scene_visibility_bridge.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
const Runtime=preload("res://systems/visual_runtime.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const ActorAlpha=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Pose=preload("res://systems/model_native_pose.gd")
const Alpha=preload("res://tools/native_parity/visibility/alpha_program.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const NativeTimer=preload("res://systems/native_data/world_timer.gd")
class World extends Node:
	var desired: Dictionary={}
	var installed: Dictionary={}
	var instances: Dictionary={}
	var effects
	var closed:=false
	var retiring:=false
	var generation:=3
	var area_id:=7
	var controlled_id:=99
var checks:=0
var failures: Array=[]
var output:=""
var extension: Resource
var native_queries:=0
var runtimes: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func source(id: int,kind: int=5,life: int=1) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":7,"nativeLifetime":life,"disclosureLifetime":1,"replicated":{"position":[5.0,5.0,0.0]}}
func admit(world: World,row: Dictionary) -> void:world.desired[row.id]={"object":row,"key":"fixture/"+str(row.id)+"/"+str(row.nativeLifetime)}
func effect(world: World,id: int,scope: int,value: float,kind: int=5,attached: int=1,finished: int=0) -> Dictionary:
	var runtime:=Runtime.new();world.effects.add_child(runtime);runtime.set_process(false);runtimes.append(runtime)
	runtime.state={"programType10d":kind,"attached114":attached,"finishedF4":finished,"scope10c":scope,"field100":value}
	var entry:={"id":id,"actor":11,"privateToken":0,"areaVisual":false,"runtime":runtime,"removed":false}
	world.effects.entries[id]=entry
	world.effects.records[id]={"lifetime":1,"presentation_lifetime":Lifetime.token(world.desired[11].object)}
	if not world.effects.actor_effects.has(11):world.effects.actor_effects[11]={0:[]}
	world.effects.actor_effects[11][0].append(entry)
	return entry
func clear_effects(world: World) -> void:
	world.effects.entries.clear();world.effects.records.clear();world.effects.actor_effects.clear()
	for runtime in runtimes:runtime.free()
	runtimes.clear()
func row(snapshot: Dictionary,id: int) -> Dictionary:
	for member in snapshot.owner.get("members",[]):
		if member.id==id:return member
	return {}
func actor(world: World,id: int) -> Dictionary:
	var instance:=Actor.new();world.add_child(instance);instance.set_process(false);instance.actor_alpha_enabled=true;instance.actor_alpha=ActorAlpha.new();instance.renderer_alpha_primary_models.assign([0,1]);instance.object_id=id
	var meshes: Array=[]
	for index in 3:
		var mesh:=MeshInstance3D.new();instance.add_child(mesh);mesh.mesh=BoxMesh.new()
		var material:=StandardMaterial3D.new();material.albedo_color=Color(0.2,0.4,0.6,0.8);mesh.material_override=material
		mesh.set_meta("native_source_model_index",index);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if index==1 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON;instance.meshes.append(mesh)
		check(instance.actor_alpha.enroll(mesh,index),"Actual private material/alpha context enrolls physical mesh "+str(index));meshes.append(mesh)
	world.instances[id]=instance;world.installed[id]=world.desired[id].key
	return {"actor":instance,"meshes":meshes}
func pose_case(mesh: MeshInstance3D,native: bool) -> void:
	var part:=Node3D.new();root.add_child(part);mesh.reparent(part,false)
	var node:={"id34":0,"flags98":0,"controllers78":[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":168}],"controllerCount80":1,"values88":PackedFloat32Array([0.0,0.8]),"children68":[],"childCount70":0}
	var pose:=Pose.new();pose.compiled_controls=false;pose.bulk_evaluation=false;pose.native_storage=false;pose.direct_flush=true
	pose.configure({"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":node,"properties":{},"children":[],"transparencyHint":false}]},{"parts":[0]},[part])
	if native:
		var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
		var configured: Dictionary=context.call("dispatch",0,{"parts":pose.parts,"binding":[0],"root":0,"emitter_fields":{}})
		check(not configured.has("error"),"Actual approved native pose storage binds the reveal alpha wrapper");pose.native_context=context;native_queries+=1
	pose.write(pose.parts[0],168,[0.6]);pose.flush()
	check(is_equal_approx(mesh.material_override.albedo_color.a,0.3),"Existing Part alpha publication composes with current bridge actor alpha once")
	mesh.reparent(root,false);pose.close();part.free()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var native:=OS.get_cmdline_user_args().has("--existing-kernel")
	if native:
		extension=load("res://native/particle_kernel.gdextension")
		check(extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Matched approved native library is actually loaded")
	var world:=World.new();root.add_child(world)
	admit(world,source(99,5,2));admit(world,source(11));admit(world,source(12,9))
	world.effects=Effects.new();world.add_child(world.effects);world.effects.world=world;world.effects.client=world.effects;world.effects.set_process(false)
	var scope:={"connection_epoch":4,"area_generation":3,"area_id":7,"controlled_id":99,"controlled_lifetime":Lifetime.token(world.desired[99].object)}
	var facts:={"current":true,"player":{"available":true,"present":false},"fields":{"available":false},"field_calls":0,"scene":[],"fog":[],"ticks":1000000}
	var timer:=NativeTimer.new();check(timer.initialize(func():return int(facts.ticks)).ready,"Existing WorldTimer arithmetic owner constructs from explicit fixture provider")
	facts.ticks+=200000;check(timer.snapshot().ready,"Existing WorldTimer captures fixture snapshot boundary")
	var timing:=func() -> Dictionary:
		var sampled: Dictionary=timer.snapshot_difference()
		if not sampled.get("ready",false) or int(sampled.microseconds.hi)>=2147483648:return {"available":false}
		return {"available":true,"snapshot_us":(int(sampled.microseconds.hi)<<32)|int(sampled.microseconds.lo)}
	var ports:={"scope_current":func(_scope):return facts.current,"tile_center":func(_i,x,y):return [float(x*10+5),float(y*10+5)],"player_info":func():return facts.player,"creature_fields":func(_id,_life):facts.field_calls+=1;return facts.fields,"scene_hook":func(id,life,command):facts.scene.append({"id":id,"life":life,"command":command});return true,"tile_fog":func(event):facts.fog.append(event);return true,"fade_timing":timing}
	var canonical: Array=[1,0,0,0];var bridge:=Bridge.new()
	check(bridge.configure(world,scope,{"width":2,"height":2,"flags":1,"states":canonical},ports).available,"Bridge binds exact current scope and caller-owned canonical tiles")
	var life:=Lifetime.token(world.desired[11].object)
	check(bridge.effect_override(11,life).alpha_word==Alpha.word(-1.0),"Empty actual native effect list returns original -1 sentinel")
	check(bridge.target_alpha(11,life,0).alpha_word==Alpha.ONE_WORD,"Certified absent PlayerInfo retains native revealed-byte bypass")
	effect(world,1,7,0.8);effect(world,2,3,0.7);effect(world,3,3,0.6);effect(world,4,255,0.1);effect(world,5,1,0.2,5,0);effect(world,6,1,0.3,5,1,1);effect(world,7,1,0.4,4)
	check(bridge.effect_override(11,life).alpha_word==Alpha.word(0.6),"Actual reverse list strict lowest scope chooses reverse-first equal priority")
	world.effects.indexed_membership=false
	check(bridge.effect_override(11,life).alpha_word==Alpha.word(0.6),"Actual ordinary full-list fallback preserves the same native tie result")
	world.effects.indexed_membership=true
	check(bridge.target_alpha(11,life,1).alpha_word==Alpha.word(0.6),"Real target provider reads selected actual VisualRuntime field100")
	var zero=effect(world,8,0,0.25)
	check(bridge.effect_override(11,life).alpha_word==Alpha.word(0.25),"Attached scope0 participates in original alpha getter")
	zero.runtime.state.attached114=0
	facts.player={"available":true,"present":true,"visibility":{"11":[true,false,false]}}
	check(bridge.target_alpha(11,life,0).alpha_word==Alpha.word(0.5) and facts.field_calls==0,"Actual received detected perception resolves before reading missing creature fields")
	facts.player={"available":true,"present":true,"visibility":{}}
	check(not bridge.target_alpha(11,life,1).available,"Missing native110/114 never become zero")
	facts.fields={"available":true,"creature110":1,"creature114":0}
	check(bridge.target_alpha(11,life,0).alpha_word==Alpha.word(0.5),"Explicit native creature-state branch precedes unrevealed-byte test")
	facts.fields={"available":true,"creature110":0,"creature114":0}
	check(bridge.target_alpha(11,life,0).alpha_word==0,"Certified normal creature unrevealed target is native zero")
	check(bridge.target_alpha(11,life,1).alpha_word==Alpha.word(0.6),"Certified normal creature target uses actual selected effect")
	facts.player={"available":false}
	check(not bridge.target_alpha(11,life,1).available,"Unknown PlayerInfo presence is distinct from proven absence")
	facts.player={"available":true,"present":false}
	var pending=effect(world,9,1,0.1);pending.runtime=null
	check(not bridge.effect_override(11,life).available,"Unprepared effect cannot be mistaken for a missing Type5 override")
	clear_effects(world)
	# Actual actor publication uses proven primary indices only, with independent
	# held-model context and original authored Part alpha retained.
	var physical:=actor(world,11);var received: Dictionary=world.desired[11].object.duplicate(true)
	check(bridge.capture_shadow_model(11,life).available,"Cold model adoption captures exact authored physical Part caster settings")
	check(bridge.publish(11,life,{"kind":"native_shadow","enabled":false}) and physical.meshes[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and physical.meshes[2].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Native Gob shadow-off affects only proven primary/attached models, not held unrelated model")
	check(bridge.publish(11,life,{"kind":"native_shadow","enabled":true}) and physical.meshes[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and physical.meshes[1].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Native Gob shadow-on restores original per-Part caster flags rather than enabling every mesh")
	var concrete:=Bridge.new();var native_ports:=ports.duplicate();var shadow_mode:={"value":0};native_ports.erase("scene_hook");native_ports.native_shadow_detail=func():return shadow_mode.value
	check(concrete.configure(world,scope,{"width":2,"height":2,"flags":1,"states":canonical},native_ports).available and concrete.capture_shadow_model(11,life).available,"Concrete native shadow-detail bridge binds real physical authored baseline")
	var scene_command:={"kind":"native_reveal_hooks","setter":"immediate765c80","revealed":true,"render_owner_present":true,"native_field108":0}
	var partial: Dictionary=concrete.apply_native_scene_hooks(11,life,scene_command)
	check(not partial.available and partial.primary_available and not partial.secondary_available and physical.meshes[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Actual detail0 disables primary shadows while unresolved D0 blob remains explicitly partial")
	shadow_mode.value=2;partial=concrete.apply_native_scene_hooks(11,life,scene_command)
	check(partial.primary_available and physical.meshes[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and physical.meshes[1].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Actual detail2 restores authored caster flags without touching authored noncasters")
	check(concrete.publish(11,life,{"kind":"set_alpha","scope":255,"alpha_word":Alpha.word(0.5)}) and is_equal_approx(physical.meshes[0].material_override.albedo_color.a,0.4),"Incomplete secondary scene hooks never block actual independent Actor alpha publication")
	check(bridge.publish(11,life,{"kind":"set_alpha","scope":255,"alpha_word":Alpha.word(0.5)}),"Real ActorInstance alpha endpoint accepts exact live primary models")
	check(is_equal_approx(physical.meshes[0].material_override.albedo_color.a,0.4) and is_equal_approx(physical.meshes[1].material_override.albedo_color.a,0.4) and is_equal_approx(physical.meshes[2].material_override.albedo_color.a,0.8),"Primary/attached models compose once while unselected held model stays unchanged")
	pose_case(physical.meshes[0],native)
	check(bridge.publish(11,life,{"kind":"set_alpha","scope":255,"alpha_word":0}) and not physical.meshes[0].visible and physical.meshes[0].mesh!=null,"Zero actor alpha suppresses actual draw without deleting geometry/entity")
	check(world.desired[11].object==received,"Alpha publication leaves canonical received object unchanged")
	check(not bridge.publish(11,life,{"kind":"set_alpha","scope":0,"alpha_word":0}),"Unknown wrapper scope is rejected")
	check(bridge.observe(world.desired[11].object,[15,5,0],"create").available and facts.scene.size()==2,"Actual boundary owner sends explicit immediate/target scene operations through lower port")
	check(bridge.receive_wire({"kind":"raw-tile-visibility","connection":4,"generation":3,"areaId":7,"actorId":99,"lifetime":scope.controlled_lifetime,"serial":1,"change":{"mode":[0,0],"points":[{"state":1,"x":1,"y":0}]}}).accepted and canonical[1]==1 and facts.fog.size()==1,"Fresh raw operation updates canonical tile through actual reveal owner and explicit fog port")
	check(bridge.advance().available,"Existing exact WorldTimer snapshot words feed the fade boundary")
	# Negative integration evidence: unresolved lowers must never be accepted as
	# successful scene detach, FogOfWar or frame clock operations.
	var incomplete:=Bridge.new();check(incomplete.configure(world,scope,{"width":2,"height":2,"flags":1,"states":canonical},{"scope_current":ports.scope_current,"tile_center":ports.tile_center}).available,"Bridge can retain explicit unresolved lower capability state")
	check(not incomplete.publish(11,life,{"kind":"native_reveal_hooks","setter":"immediate765c80","revealed":false}),"Missing native scene hook never becomes Node.hide or no-op success")
	check(not incomplete.publish(11,life,{"kind":"render_owner_virtual8","argument":0}),"Missing native detach owner stays explicit")
	check(not incomplete._tile_fog({"tile_index":0}),"Missing native tile fog operation stays explicit")
	check(not incomplete.advance().available,"Missing native WorldTimer never becomes OS frame delta")
	var cold:=bridge.snapshot();cold.scope.area_id=999;cold.stats.targets=999
	check(bridge.snapshot().scope.area_id==7 and bridge.snapshot().stats.targets!=999,"Diagnostic views cannot mutate live bridge ownership")
	world.installed[11]="other-model"
	check(not bridge.publish(11,life,{"kind":"set_alpha","scope":255,"alpha_word":Alpha.ONE_WORD}),"Pending/replaced model publication cannot target old installed visual")
	world.installed[11]=world.desired[11].key
	admit(world,source(11,5,2))
	check(not bridge.target_alpha(11,life,1).available and not bridge.publish(11,life,{"kind":"set_alpha","scope":255,"alpha_word":Alpha.ONE_WORD}),"Reused full ID fences old target and alpha calls")
	check(not bridge.remove(11,Lifetime.token(world.desired[11].object)).accepted,"New lifetime cannot remove the prior native presentation record")
	world.controlled_id=98
	check(not bridge.receive_wire({}).available and not bridge.advance().available,"Changed controlled identity fences existing scope")
	world.controlled_id=99;world.retiring=true
	check(not bridge.target_alpha(11,Lifetime.token(world.desired[11].object),1).available,"Retiring world cannot resolve new targets")
	world.retiring=false;facts.current=false
	check(not bridge.target_alpha(12,Lifetime.token(world.desired[12].object),0).available,"Connection ownership retirement fences even zero-target branch")
	bridge.close();incomplete.close();concrete.close()
	check(canonical==[1,1,0,0] and bridge.snapshot().closed,"Close retires presentation only and preserves canonical tiles")
	physical.meshes[0].reparent(physical.actor,false);physical.actor.retire();world.effects.closed=true;world.effects.entries.clear();world.effects.records.clear();world.effects.actor_effects.clear();world.free();await process_frame;await process_frame
	if native:check(native_queries==1,"Actual native pose-storage route was exercised exactly once")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"actual_native_pose_cases":native_queries,"stats":bridge.snapshot().stats,"serverConnections":0,"gpuDraws":0,"nativeBuilds":0,"scope":"Actual EffectWorld reverse effect list and VisualRuntime states; actual ActorInstance private material primary-model alpha and optional approved NwnModelPoseStorage. Native scene/fog/creature-state/time delivery remain explicit fixture lower ports; no gameplay visibility/fog/detach or live-client acceptance claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_SCENE_VISIBILITY_BRIDGE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
