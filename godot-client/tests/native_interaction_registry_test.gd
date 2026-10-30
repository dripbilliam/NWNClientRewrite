extends "res://tests/native_template_cache_test.gd"
const Registry=preload("res://systems/entity_registry.gd")
const Policy=preload("res://systems/native_interaction_policy.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Hud=preload("res://systems/native_hud.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
var world
var registry
var hud
func object_row(id: int,kind: int,usable: bool,x: float) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":42,"replicated":{"appearance":0,"position":[x,0.0,0.0],"orientation":[0.0,1.0],"field264":int(usable)}}
func sync(id: int,object: Dictionary,instance) -> void:
	if registry.register_native(id,{"id":id,"type":int(object.objectType),"name":str(object.get("name","Object")),"eligible":Policy.eligible(object,42)},instance): hud.queue_refresh_entities()
func test_policy() -> void:
	var cases: Array=[]
	for kind in [5,10]: cases.append([object_row(kind,kind,false,0),true])
	var item:=object_row(6,6,false,0); cases.append([item.duplicate(true),true]); item.inventoryLocation={"channel":"I"}; cases.append([item.duplicate(true),false]); item.inventoryLocation={"channel":"U"}; cases.append([item.duplicate(true),false]); item.inventoryLocation={}; item.equipped=true; cases.append([item,false])
	var dropped:=object_row(6,6,false,0); dropped.inventoryLocation=null; cases.append([dropped,true])
	for value in [false,true]: cases.append([object_row(9,9,value,0),value])
	var scenery:=object_row(9,9,true,0); scenery.staticState={}; cases.append([scenery,false])
	for field in ["replicationRemoved","destroyed"]:
		var invalid:=object_row(5,5,true,0); invalid[field]=true; cases.append([invalid,false])
	var away:=object_row(5,5,true,0); away.areaId=99; cases.append([away,false])
	var unknown:=object_row(9,9,true,0); unknown.replicated.erase("field264"); cases.append([unknown,false])
	var fallback:=object_row(9,9,true,0); fallback.replicated.field264=null; fallback.usable=true; cases.append([fallback,true])
	var transition:=object_row(7,7,false,0); transition.replicated.hasTransition=true; cases.append([transition.duplicate(true),true]); transition.replicated.isTrap=true; cases.append([transition,false])
	for index in cases.size(): check(Policy.eligible(cases[index][0],42)==bool(cases[index][1]),"Received interaction eligibility case "+str(index))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	test_policy()
	world=World.new(); root.add_child(world); world.set_process(false); world.area_id=42
	registry=Registry.new(); world.add_child(registry)
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true; camera.position=Vector3(0.2,2,3); camera.look_at(Vector3(0.2,0.2,0))
	hud=Hud.new(); world.add_child(hud); hud.configure(registry,camera,"user://interaction-registry-test.cfg")
	world.instance_ready.connect(sync); world.instance_state_changed.connect(func(id,object):sync(id,object,world.instances[id])); world.instance_removed.connect(func(id):
		if registry.forget_entity(id): hud.queue_refresh_entities())
	var rows: Array=[]; var shared:=Pool.new(); var template=shared.model_template(bundle("auth_selection"))
	check(template!=null and not shared.picking,"Native rendering prepares without eager picking shapes")
	for id in range(1,601): rows.append(object_row(id,9,false,0.0 if id==1 else float(id)*2+10))
	world.receive(rows,-1)
	for row in rows:
		var instance=template.create(); world.add_child(instance); instance.position=World.object_pose(row).position; world.instances[int(row.id)]=instance; world.installed[int(row.id)]=world.signature(row); world.instance_ready.emit(int(row.id),row,instance)
	var source_geometry: Resource=world.instances[1].meshes[0].get_meta("native_pick_geometry")
	check(world.desired.size()==600 and world.instances.size()==600 and registry.entities.is_empty(),"600 scenery objects remain authoritative/rendered and absent from selection registry")
	check(registry.parts.is_empty() and registry.native_bodies.is_empty() and registry.stats.colliders==0 and source_geometry.builds==0,"Scenery creates zero picking bodies, highlight mesh bindings or triangle shapes")
	var aura:=Emitter.new(); aura.source_path=NodePath(".."); aura.source_model_flags=0; aura.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","birthrate":8,"lifeexp":1,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1}
	world.instances[1].add_child(aura); aura.set_process(false); var light:=OmniLight3D.new(); world.instances[1].add_child(light); aura.tick(0.2)
	check(aura.failure.is_empty() and aura.frames==1 and aura.active_count()>0 and light.is_visible_in_tree() and source_geometry.builds==0,"Noninteractive scenery retains active native particles and lights without picking shapes")
	var usable:=object_row(601,9,true,0); rows.append(usable); world.receive_delta([usable],[],-1)
	var active=template.create(); world.add_child(active); world.instances[601]=active; world.installed[601]=world.signature(usable); world.instance_ready.emit(601,usable,active)
	var floor_surface:={"definition":{"tiles":[{"model":"test","orientation":0,"position":Vector3(0,-1,0)}]},"table":{"orderedRows":[{"Walk":"1"}]},"meshes":{"test":{"vertices":[[0.0,0.0,0.0],[10.0,0.0,0.0],[10.0,10.0,0.0],[0.0,10.0,0.0]],"faces":[[0,1,2],[0,2,3]],"materials":[0,0]}}}
	registry.register_walkmesh(floor_surface); await physics_frame; await physics_frame
	var screen:=camera.unproject_position(Vector3(0.2,0.2,0))
	check(registry.pick(camera,screen).get("id",-1)==601 and source_geometry.builds==1,"Usable shared model builds one exact source shape and receives a real physics pick")
	check(registry.stats.entities==1 and registry.stats.colliders==2 and registry.stats.bound_meshes==1,"Only one object picking body plus independent walkmesh remains")
	registry.mark([601]); hud.labels([601]); hud.inspect_entity(601)
	var retained_mesh=active.meshes[0].mesh; var retained_body=registry.native_bodies[601][0]
	usable=usable.duplicate(true); usable.name="Renamed"; world.receive_delta([usable],[],-1)
	check(registry.entities[601].name=="Renamed" and registry.native_bodies[601][0]==retained_body,"Metadata delta updates target without rebuilding colliders")
	usable=usable.duplicate(true); usable.replicated.field264=0; world.receive_delta([usable],[],-1); await physics_frame; await physics_frame; await process_frame
	check(not registry.entities.has(601) and not registry.bounds.has(601) and registry.native_bodies.is_empty() and registry.marked.is_empty(),"Same-appearance usability delta removes all selection bookkeeping")
	check(active.meshes[0].mesh==retained_mesh and active.is_visible_in_tree() and active.meshes[0].material_overlay==null and world.desired.size()==601,"Removing selection retains server object, GPU geometry and visibility and clears highlight")
	check(not hud.nameplates.has(601) and not hud.panels.details.visible,"Lost eligibility retires labels and selected details")
	var floor_hit: Dictionary=registry.pick(camera,screen)
	check(floor_hit.get("id",0)==-1 and absf(floor_hit.get("position",Vector3.ZERO).y+1)<0.001 and registry.stats.colliders==1,"Click through scenery still selects unchanged walkmesh ground")
	usable=usable.duplicate(true); usable.replicated.field264=1; world.receive_delta([usable],[],-1); await physics_frame; await physics_frame
	check(registry.pick(camera,screen).get("id",-1)==601 and source_geometry.builds==1,"Re-enabling usability reuses immutable geometry without model reload")
	world.receive_delta([], [601],-1); await process_frame; await physics_frame
	check(not world.instances.has(601) and registry.entities.is_empty() and registry.stats.bound_meshes==0 and registry.stats.colliders==1,"Server removal retires target bodies and keeps walkmesh")
	var hidden_text:=source("auth_hidden").replace("parent NULL\n","parent NULL\nrender 0\n")
	var parser:=ActorData.new(); var hidden_bundle:={"value":parser.parse(hidden_text.to_utf8_buffer()),"sha256":Cache.digest(hidden_text.to_utf8_buffer()),"textures":{},"error":"","animation_sources":[]}
	var hidden_template=shared.model_template(hidden_bundle); var portal=hidden_template.create(); world.add_child(portal); portal.position=Vector3(-2,0,0)
	var hidden_source: Resource=portal.pick_surfaces[0].get_meta("native_pick_geometry")
	check(portal.meshes.is_empty() and hidden_source.builds==0,"Hidden original hit triangles require no rendered GPU mesh or eager shape")
	registry.register_native(604,{"id":604,"eligible":true},portal); camera.position=Vector3(-1.8,2,3); camera.look_at(Vector3(-1.8,0.2,0)); await physics_frame; await physics_frame
	check(registry.pick(camera,camera.unproject_position(Vector3(-1.8,0.2,0))).get("id",-1)==604 and hidden_source.builds==1,"Invisible portal hit mesh remains selectable using original triangles")
	registry.forget_entity(604); portal.retire()
	if args.has("install"): await original_portal(shared,str(args.install),camera)
	var metrics: Dictionary=registry.stats.duplicate(); world.close(); world.queue_free(); await process_frame; await process_frame; shared.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scenery_objects":600,"metrics":metrics,"publicConnections":0,"scope":"Actual native shared models, lazy shape creation, physics picking, world delta eligibility/metadata/removal, highlight/HUD retirement, independent WOK ground and hidden portal source triangles; original portal check when install supplied"},"\t")); file.close(); print("NATIVE_INTERACTION_REGISTRY ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
func original_portal(pool,install: String,camera: Camera3D) -> void:
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original portal assets mount read-only")
	var assets:=Assets.new(); world.add_child(assets); assets.configure(catalog); var delivered: Dictionary={}; assets.completed.connect(func(id,result):delivered[id]=result)
	var job: int=assets.request("plc_portal2",2002,"static-model"); var deadline:=Time.get_ticks_msec()+20000
	while not delivered.has(job) and Time.get_ticks_msec()<deadline: await process_frame
	var prepared: Dictionary=delivered.get(job,{})
	check(prepared.has("value") and str(prepared.get("error","unfinished")).is_empty(),"Original portal model and textures prepare")
	if prepared.has("value"):
		var template=pool.model_template(prepared); var portal=template.create(); world.add_child(portal); portal.position=Vector3(-5,0,0)
		check(not portal.pick_surfaces.is_empty(),"Original plc_portal2 retains hidden physical hit mesh")
		if not portal.pick_surfaces.is_empty():
			registry.register_native(999,{"id":999,"eligible":true},portal)
			var surface: Node3D=portal.pick_surfaces[0]; var geometry: Resource=surface.get_meta("native_pick_geometry")
			var a: Vector3=surface.global_transform*geometry.vertices[geometry.indices[0]]; var b: Vector3=surface.global_transform*geometry.vertices[geometry.indices[1]]; var c: Vector3=surface.global_transform*geometry.vertices[geometry.indices[2]]
			var center:=(a+b+c)/3.0; var normal:=(b-a).cross(c-a).normalized(); camera.position=center+normal*5; camera.look_at(center,Vector3.FORWARD if absf(normal.dot(Vector3.UP))>0.99 else Vector3.UP)
			await physics_frame; await physics_frame
			check(registry.pick(camera,camera.unproject_position(center)).get("id",-1)==999,"Original invisible portal hit geometry receives real selection ray")
			registry.forget_entity(999)
		portal.retire()
	assets.close(); assets.queue_free(); await process_frame
