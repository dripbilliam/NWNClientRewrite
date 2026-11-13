extends "res://native_live_world.gd"
# Dedicated pinned graphical input/authority receiver. Area readiness and HUD/text
# ports are explicit; original WorldInput/Registry/hover/action/menu code is used.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Door=preload("res://systems/native_render/door_instance.gd")
const Names=preload("res://systems/native_data/object_animation.gd")
const TalkText=preload("res://systems/native_data/talk_text.gd")
const Conversation=preload("res://systems/server_conversation.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Wheel=preload("res://systems/server_radial.gd")
const Access=preload("res://systems/native_gui_panel_access.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Presentation=preload("res://systems/native_render/world_hover_presentation.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
class ReadyWorld extends "res://systems/native_render/live_world_support.gd":
	func ready_for_control() -> bool:return not closed and not retiring and desired.has(controlled_id)
class CancelPort extends RefCounted:
	func cancel() -> void:pass
class InventoryPort extends RefCounted:
	var item_context:=CancelPort.new()
class TextPort extends RefCounted:
	var tables: Dictionary={}
	var revision:=1
	var source
	func raw(value: Variant) -> String:return source.raw(value)
	func name(_value: Variant,_id: int=-1) -> String:return "Prelude doorway"
class UiPort extends Node:
	var desktop
	var gui_panel_access
	var generation:=-1
	var area_id:=-1
	var controlled_id:=-1
	var inventory:=InventoryPort.new()
	var text:=TextPort.new()
class HudPort extends Node:
	var current_id:=-1
	var blocked:=false
	func blocks_pointer(_point: Vector2) -> bool:return blocked
	func labels(_ids: Array,_hover: int) -> void:pass
var door_service
var door_pool=RenderPool.new()
var door_tables: Dictionary={}
var door_jobs: Dictionary={}
var door_source: Dictionary={}
var door_control: Dictionary={}
var door_object
var door_bundle: Dictionary={}
var door_version:=-1
var door_ack:=-1
var door_model_requested:=false
var door_finished:=false
var door_checks:=0
var door_failures: Array=[]
var door_observations: Array=[]
var door_requests: Array=[]
var door_resting_busy:=false
var door_window: Dictionary={}
var door_report:=""
var door_ticket: Dictionary={}
var door_hello:=false
var door_text:=TalkText.new()
var door_conversation
var door_talking:=-1
var door_dialog_choices:=0
var door_hover
var door_ui
var door_wheel
var door_art
var door_part: Node3D
var door_bounds: Dictionary={}
var door_input_point:=Vector2.ZERO
var door_extension: Resource
var door_hover_results: Array=[]
var door_pixel_observations: Array=[]
func door_part_alpha() -> Variant:
	if not is_instance_valid(door_part):return null
	for child in door_part.get_children():
		if child is MeshInstance3D and child.material_override!=null and child.material_override.has_method("publish_actor_part_pose"):return child.material_override.actor_part_color.a
	return null
func _initialize() -> void:door_start.call_deferred()
func door_check(value: bool,label: String) -> void:
	door_checks+=1
	if not value:door_failures.append(label);print("FAIL ",label)
func send(value: Dictionary) -> void:
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return
	if value.get("kind") in ["interact","native-panel","walk","pickup"]:
		door_requests.append(value.duplicate(true));peer.put_data((JSON.stringify({"kind":"fixture-action","request":value})+"\n").to_utf8_buffer())
	else:peer.put_data((JSON.stringify(value)+"\n").to_utf8_buffer())
func fail(reason: String) -> void:
	if door_finished:return
	door_check(false,reason);send({"kind":"failed","reason":reason});door_finish.call_deferred()
func door_start() -> void:
	var ticket_path:="";var install:="";var cache_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticket="):ticket_path=arg.substr(9)
		elif arg.begins_with("--report="):door_report=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
	if door_report.is_empty() or ticket_path.is_empty() or FileAccess.file_exists(door_report):quit(2);return
	door_ticket=JSON.parse_string(FileAccess.get_file_as_string(ticket_path))
	if door_ticket.get("host")!="127.0.0.1":quit(3);return
	var primary:=DisplayServer.get_primary_screen();var secondary:=-1
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:secondary=screen;break
	if secondary>=0 and root.current_screen!=secondary:root.current_screen=secondary
	await process_frame
	door_window={"screen":root.current_screen,"primary":primary,"first_nonprimary":secondary,"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse":Input.get_mouse_mode()}
	door_check(secondary>=0 and root.current_screen==secondary and not root.has_focus() and root.unfocusable and Input.get_mouse_mode()==Input.MOUSE_MODE_VISIBLE,"Local doorway fixture uses first nonprimary screen unfocused and pointer visible")
	door_extension=load("res://native/particle_kernel.gdextension")
	door_check(door_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Pinned existing native pose DLL loads without rebuilding")
	door_check(catalog.mount_install(install),"Original installed assets mount read-only")
	door_check(door_text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original TLK supplies actual offered tutorial choices")
	door_conversation=Conversation.new();root.add_child(door_conversation);door_conversation.setup(door_report.get_base_dir().path_join("dialog-layout.cfg"));door_conversation.hide()
	door_conversation.request.connect(func(message):send({"kind":"reply","entryId":message.entryId,"replyId":message.replyId,"abort":message.abort}))
	door_pool.native_lighting=true;door_pool.native_surface_output=true;door_pool.picking=true
	host=Node3D.new();root.add_child(host);host.add_child(Palette.new());Palette.ambient(Vector3.ONE)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.025,0.035,0.055);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.BLACK;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;host.add_child(env)
	world=ReadyWorld.new();world.pool=door_pool;world.owns_pool=false;world.set_meta("native_surface_output",true);host.add_child(world);world.set_process(false)
	camera=Camera3D.new();host.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.2;camera.near=0.05;camera.far=40;camera.current=true
	gamma_controller=Gamma.new();host.add_child(gamma_controller);gamma_controller.attach(camera);gamma_controller.effect.set_surface_output(true);gamma_controller.set_gamma(1.2)
	registry=Registry.new();host.add_child(registry);registry.native_highlight_enabled=true
	hud=HudPort.new();root.add_child(hud)
	door_hover=Presentation.new();world.add_child(door_hover);door_hover.configure(world,registry)
	world_input=InputOwner.new();root.add_child(world_input);world_input.configure(registry,camera,hud);world_input.set_physics_process(false);world_input.action=world_action;world_input.hover_presentation=door_select_hover
	door_service=Assets.new();root.add_child(door_service);door_service.maximum_workers=1;door_service.cache_directory=cache_path;door_service.configure(catalog);door_service.completed.connect(door_prepared)
	registry.configure_highlight_assets(door_service,catalog,door_pool)
	for name in ["genericdoors","doortypes"]:door_jobs[door_service.request(name,2017,"2da")]=name
	door_ui=UiPort.new();root.add_child(door_ui);door_ui.text.source=door_text;gameplay_ui=door_ui
	var desktop:=Desktop.new();root.add_child(desktop);desktop.set_process(false);door_ui.desktop=desktop;desktop.owner_ui=door_ui;desktop.rules.text=door_ui.text;desktop.feat_rules.rules=desktop.rules;desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules;desktop.request.connect(player_command)
	door_art=Art.new();root.add_child(door_art);door_art.configure(catalog,cache_path.path_join("ui"));desktop.art=door_art
	door_wheel=Wheel.new();root.add_child(door_wheel);door_wheel.configure_art(door_art);desktop.radial=door_wheel;door_wheel.request.connect(desktop.input_request)
	var access:=Access.new();root.add_child(access);door_ui.gui_panel_access=access;access.configure(door_ui)
	world_input.context_action=desktop.open_radial
	peer.connect_to_host("127.0.0.1",int(door_ticket.port))
func door_prepared(id: int,result: Dictionary) -> void:
	if door_finished or not door_jobs.has(id):return
	var kind: String=door_jobs[id];door_jobs.erase(id)
	if not str(result.get("error","missing")).is_empty():fail("Original door preparation failed: "+str(result.get("error")));return
	if kind in ["genericdoors","doortypes"]:door_tables[kind]=result.value;door_prepare();return
	door_bundle=result;door_object=Door.new();world.add_child(door_object)
	door_check(door_object.install_door(result,door_pool,int(door_source.id),door_source.replicated),"Production Door installs actual canonical server-selected original model")
	if door_object.rigs==null:fail(door_object.failure);return
	world.instances[int(door_source.id)]=door_object;world.installed[int(door_source.id)]=world.desired[int(door_source.id)].key;world.apply_pose(int(door_source.id))
	door_object.rigs.set_process(true);door_object.rigs._update(0.0)
	var entry: Dictionary=door_object.rigs.entities[int(door_source.id)]
	for at in result.value.nodes.size():
		var node: Dictionary=result.value.nodes[at]
		if str(node.name).to_lower()=="sam" and not node.mesh.is_empty():door_part=door_object.rigs.node_at(int(door_source.id),int(entry.model_parts[0][at]));door_bounds=node.mesh.native_bounds;break
	door_check(is_instance_valid(door_part),"Actual server door retains original alpha-independent sam doorway Part")
	if not is_instance_valid(door_part):fail("Original doorway Part unavailable");return
	registry.register_native(int(door_source.id),{"id":int(door_source.id),"type":10,"eligible":true,"label":"Prelude Door"},door_object)
	var low: Array=door_bounds.min;var high: Array=door_bounds.max;var center:=Vector3((low[0]+high[0])*0.5,(low[2]+high[2])*0.5,-(low[1]+high[1])*0.5)
	var target: Vector3=door_part.global_transform*center
	camera.position=door_part.global_transform*(center+Vector3(-5.5,0,0));camera.look_at(target);door_input_point=camera.unproject_position(target)
	send({"kind":"door-installed","id":int(door_source.id),"model":result.resource_name,"regions":door_object.native_door_pick_snapshot().regions})
func door_prepare() -> void:
	if door_model_requested or door_source.is_empty() or door_tables.size()!=2:return
	var state: Dictionary=door_source.replicated;var type:=int(state.get("doorType",0));var table: Dictionary=door_tables["genericdoors" if type==0 else "doortypes"];var index:=int(state.get("genericType",-1)) if type==0 else type
	if index<0 or index>=table.orderedRows.size():fail("Server door table row unavailable");return
	var row: Dictionary=table.orderedRows[index];var name:=str(row.get("ModelName",row.get("Model",""))).to_lower();door_model_requested=true;door_jobs[door_service.request(name,2002,"actor-model",{"relevant_tracks":true})]="model"
func receive(message: Dictionary) -> void:
	match str(message.get("kind","")):
		"finish":door_finish.call_deferred()
		"talk-target":door_talking=int(message.targetId)
		"ui":door_present_ui(message.message)
		"pick-action":door_pick_action.call_deferred(message)
		"door":
			if int(message.version)<=door_version:return
			door_source=message.object.duplicate(true);door_control=message.controlled.duplicate(true);door_version=int(message.version);epoch=int(message.scope.areaGeneration);world.area_id=int(message.scope.areaId);world.generation=epoch
			world.receive([door_control,door_source],int(door_control.id))
			door_ui.generation=epoch;door_ui.area_id=world.area_id;door_ui.controlled_id=int(door_control.id);door_ui.desktop.actor_id=int(door_control.id);door_ui.desktop.generation=epoch;door_ui.desktop.area_id=world.area_id;door_ui.desktop.objects={int(door_control.id):door_control,int(door_source.id):door_source};door_ui.gui_panel_access.observe_header(message.guiPanelAccess)
			if is_instance_valid(door_object):world.apply_pose(int(door_source.id))
			else:door_prepare()
func door_draw() -> void:
	Palette.flush()
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
func door_select_hover(hit: Dictionary,blocked: bool) -> Dictionary:
	var result: Dictionary=door_hover.select(hit,blocked)
	if door_hover_results.size()<32:
		var target:=int(door_source.get("id",-1));var control: Dictionary=world.desired.get(world.controlled_id,{}).get("object",{})
		door_hover_results.append({"hit_id":hit.get("id"),"blocked":blocked,"result":result,"control_id":world.controlled_id,"control_type":control.get("objectType"),"control_area":control.get("areaId"),"area":world.area_id,"installed":world.installed.get(target),"wanted":world.desired.get(target,{}).get("key"),"registered_owner":registry.native_owners.get(target)==world.instances.get(target),"snapshot":door_hover.snapshot()})
	return result
func door_present_ui(message: Dictionary) -> void:
	var kind:=str(message.get("kind",""))
	if kind=="dialog-close":
		door_conversation.reset()
		if door_talking>=0:send({"kind":"conversation-done","targetId":door_talking});door_talking=-1
	elif kind in ["dialog-entry","dialog-selected"]:
		var row:=message.duplicate(true);row.rich={"text":door_text.raw(message.get("text",{}))};door_conversation.present(row);door_conversation.hide()
	elif kind=="dialog-replies":
		var replies: Array=[];var offered: Array=message.replies
		for index in offered.size():replies.append({"id":offered[index].id,"rich":{"text":door_text.raw(offered[index].text)},"available":index<int(message.get("firstCount",offered.size()))})
		if offered.is_empty():replies.append({"id":4294967295,"rich":{"text":"End"},"available":true})
		door_conversation.present({"kind":"dialog-replies","entryId":message.entryId,"end":message.end,"localEnd":offered.is_empty(),"replies":replies});door_conversation.hide();door_choose_dialog.call_deferred()
func door_choose_dialog() -> void:
	if not is_instance_valid(door_conversation) or not door_conversation.opened or door_conversation.pending:return
	door_dialog_choices+=1
	if door_dialog_choices>24:fail("Original tutorial exceeded bounded offered reply choices");return
	var reply:=-1
	for phrase in ["not interested in a tutorial","not need tutorial","goodbye","time for me to go","not really interested in chatting"]:
		for index in door_conversation.rows.size():
			if door_conversation.reply_available[index] and str(door_conversation.rows[index].rich.text).to_lower().contains(phrase):reply=index;break
		if reply>=0:break
	if reply<0:
		for index in door_conversation.rows.size():
			if door_conversation.reply_available[index]:reply=index;break
	if reply<0:fail("Server supplied no available tutorial reply");return
	door_conversation.choose(door_conversation.reply_ids[reply])
	if not door_conversation.opened and door_talking>=0:send({"kind":"conversation-done","targetId":door_talking});door_talking=-1
func door_pick_action(message: Dictionary) -> void:
	if door_finished:return
	if not is_instance_valid(door_object) or int(message.id)!=int(door_source.id) or int(message.version)!=door_version:fail("Input request scope differs from canonical door");return
	var before:=door_requests.size();var wanted:=str(message.action);var button:=MOUSE_BUTTON_LEFT if wanted=="door.open" else MOUSE_BUTTON_RIGHT
	var event:=InputEventMouseButton.new();event.button_index=button;event.position=door_input_point;event.pressed=true
	world_input._unhandled_input(event);world_input._pointer_step(0.1)
	door_object.rigs._update(0.5)
	door_check(world_input.hovered==int(door_source.id) and int(world_input.last_hit.get("id",-1))==int(door_source.id),"Actual WorldInput/Registry picks original server target ID for "+wanted)
	if wanted=="door.close":
		var hover_state: Dictionary=door_hover.snapshot()
		door_check(hover_state.active and hover_state.presentation_started,"Actual qualifying WorldInput pointer starts original transition-door Trans presentation")
		door_check(door_part_alpha()==0.25 and registry.native_highlight.hovered==-1,"Actual original Trans quarter alpha renders while only ordinary hover is suppressed")
		door_check(door_wheel.active and door_ui.desktop.radial_target==int(door_source.id) and door_ui.desktop.radial_entries.get(2,{}).get("interaction")==wanted,"Actual doorway context publishes current canonical Close with exact server target")
		door_wheel.stage.hide();await door_draw();root.get_texture().get_image().save_png(door_report.trim_suffix(".json")+"-hover-v"+str(door_version)+".png");door_wheel.stage.show()
		await door_draw();root.get_texture().get_image().save_png(door_report.trim_suffix(".json")+"-menu-v"+str(door_version)+".png")
		door_pixel_observations.append({"version":door_version,"alpha":door_part_alpha(),"hover":hover_state,"ordinary_hover":registry.native_highlight.hovered,"selected_id":world_input.hovered,"native_region":world_input.last_hit.get("native_door_region"),"canonical_transition":door_source.replicated.get("hasTransition")})
		var point: Vector2=door_wheel.buttons[2].get_global_rect().get_center()
		for pressed in [true,false]:
			var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=point;click.global_position=point;click.pressed=pressed;click.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(click,true);await process_frame
	var sent: Array=door_requests.slice(before).filter(func(value):return value.get("kind")=="interact")
	door_check(sent.size()==1 and int(sent[0].targetId)==int(door_source.id) and sent[0].action==wanted,"Actual production input/action path emits exactly one requested action and original target ID")
	if sent.is_empty():fail("Physical menu selection emitted no server action");return
	send({"kind":"input-complete","id":int(door_source.id),"version":door_version,"action":wanted,"requests":sent})
func door_capture_rest() -> void:
	if door_finished or not is_instance_valid(door_object):door_resting_busy=false;return
	var selected_version:=door_version;var state:=Names.door_state(door_source.replicated);var expected:=Names.name(10,{0:22,1:50,2:51}[state]);hud.blocked=true;world_input._pointer_step(0.1);hud.blocked=false;door_wheel.reset();door_object.rigs._update(0.0)
	await physics_frame;await physics_frame
	var canonical:=var_to_bytes(door_source)
	var picked: Dictionary=registry.pick(camera,door_input_point)
	door_check(int(picked.get("id",-1))==int(door_source.id),"Actual Camera/Registry retains current server doorway target at rest")
	await door_draw();root.get_texture().get_image().save_png(door_report.trim_suffix(".json")+"-rest-v"+str(selected_version)+".png")
	var row:={"kind":"door-rest","id":int(door_source.id),"version":selected_version,"state":state,"clip":door_object.rigs.entities[int(door_source.id)].models[0].clip,"expected":expected,"pick_id":picked.get("id"),"native_region":picked.get("native_door_region"),"part_alpha":door_part_alpha(),"walkmesh_colliders":registry.stats.walkmesh_colliders,"body_masks":registry.native_bodies[int(door_source.id)].map(func(body):return [body.collision_layer,body.collision_mask]),"hover":door_hover.snapshot()}
	door_check(door_object.received_state==state and row.clip==expected,"Canonical server state reaches exact current native rest clip")
	door_check(registry.stats.walkmesh_colliders==0 and row.body_masks.all(func(pair):return pair==[Registry.TARGET_LAYER,0]),"Selection geometry creates no navigation collision layer or collision mask")
	door_check(var_to_bytes(door_source)==canonical,"Selection/pixels do not overwrite canonical received door state")
	door_observations.append(row.duplicate(true));door_ack=selected_version;door_resting_busy=false;send(row)
func _process(_delta: float) -> bool:
	if door_finished or door_ticket.is_empty():return false
	peer.poll()
	if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		if not door_hello:door_hello=true;send({"kind":"hello","token":door_ticket.token})
		if peer.get_available_bytes()>0:
			var packet:=peer.get_data(peer.get_available_bytes())
			if packet[0]!=OK:fail("Private loopback frame failed");return false
			for message in frames.feed(packet[1]):receive(message)
	if is_instance_valid(door_object) and door_version>door_ack and door_object.pending_rest<0 and not door_resting_busy:
		door_resting_busy=true;door_capture_rest.call_deferred()
	return false
func door_finish() -> void:
	if door_finished:return
	door_finished=true
	if is_instance_valid(world_input):world_input.free()
	if is_instance_valid(door_hover):door_hover.hover_owner.close()
	if is_instance_valid(registry):
		for id in registry.entities.keys():registry.forget_entity(id)
		registry.queue_free()
	if is_instance_valid(world):world.instances.erase(int(door_control.get("id",-1)));world.close()
	if is_instance_valid(door_service):door_service.close()
	if is_instance_valid(door_art):door_art.close()
	if is_instance_valid(door_wheel):door_wheel.reset()
	if is_instance_valid(door_conversation):door_conversation.free()
	await process_frame;await process_frame
	var result:={"success":door_failures.is_empty() and door_observations.size()>=3,"checks":door_checks,"failures":door_failures,"window":door_window,"observations":door_observations,"requests":door_requests,"hover_results":door_hover_results,"pixel_observations":door_pixel_observations,"dialog_choices":door_dialog_choices,"door_model":door_bundle.get("resource_name"),"door_sha256":door_bundle.get("sha256"),"source_scope":"actorSourceScope/nativeTransChildModel10 retained by immutable production capsule","public_connections":0,"native_builds":0,"performance_claim":false,"scope":"Actual canonical Prelude door and original asset through production WorldInput, Registry, hover owner, inherited native_live_world.world_action for closed Open and actual Desktop/ServerRadial context Close. Original server acknowledges requests; explicit area-readiness/HUD/text ports and isolated door scene, no full campaign/native screenshot/navigation travel claim."}
	FileAccess.open(door_report,FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n");send({"kind":"finished","success":result.success});peer.disconnect_from_host();quit(0 if result.success else 1)
