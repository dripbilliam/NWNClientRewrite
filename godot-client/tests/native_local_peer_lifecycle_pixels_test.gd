extends "res://native_session_world.gd"
# Actual received original-server rows pass through the unchanged session,
# admission, registry, visibility, model/rig and read-only entity API owners.
const PeerAPI=preload("res://systems/client_api/access.gd")
const PeerLife=preload("res://systems/native_data/entity_presentation_lifetime.gd")
var peer_checks:=0
var peer_failures: Array=[]
var peer_phase: Dictionary={}
var peer_busy:=false
var peer_seen: Array=[]
var peer_old_reference: Variant=null
var peer_old_actor: WeakRef
var peer_old_id:=-1
var peer_capture:=false
var peer_queued: Array=[]
var peer_started:=0

func run() -> void:
	super.run()
	peer_started=Time.get_ticks_msec()
	process_frame.connect(peer_tick)
	report.peer_lifecycle={"checks":0,"failures":[],"observations":[],"pixels":[],"scope":"Actual unchanged Prelude two-account join/leave/rejoin through production V6 NativeSessionWorld, source payloads, World/CreatureStream, native visibility and entity API. Hidden-peer images are explicit reversible GPU controls; no original-client screenshot, same-ID reuse, room FPS or public gameplay claim."}

func peer_check(value: bool,label: String) -> void:
	peer_checks+=1
	if not value:peer_failures.append(label)
	report.peer_lifecycle.checks=peer_checks;report.peer_lifecycle.failures=peer_failures.duplicate()

func tick() -> void:
	# Three diagnostic readbacks must retain the same ordinary camera. The
	# regular inherited tick would re-follow A between present/hidden images.
	# The brief pause defers (rather than drops) protocol/model/camera work.
	if peer_capture:return
	super.tick()

func receive(message: Dictionary) -> void:
	if message.get("kind")=="peer-lifecycle-phase":
		peer_phase=message.duplicate(true);return
	if message.get("kind")=="peer-lifecycle-finish":
		peer_check(peer_seen==["baseline","join","leave","rejoin"],"All four authoritative lifecycle boundaries completed in order")
		peer_check(not root.has_focus() and root.unfocusable and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Functional fixture remains unfocused with pointer uncaptured")
		report.peer_lifecycle.screen={"current":root.current_screen,"primary":DisplayServer.get_primary_screen(),"count":DisplayServer.get_screen_count()}
		peer_check(root.current_screen!=DisplayServer.get_primary_screen(),"Fixture remains on the current nonprimary display")
		report.success=peer_failures.is_empty();shutdown();return
	if peer_capture and message.get("kind")!="finish-ack":peer_queued.append(message);return
	super.receive(message)

func peer_tick() -> void:
	if closing or peer_busy or peer_phase.is_empty():return
	if Time.get_ticks_msec()-peer_started>150000:fail("Actual peer lifecycle deadline exceeded");return
	if not is_instance_valid(world) or not initialized or accepted_raw_serial<int(peer_phase.get("afterSerial",1)):return
	var phase:=str(peer_phase.phase)
	if phase in peer_seen:return
	var id:=int(peer_phase.get("id",-1))
	var provider: RefCounted=PeerAPI.entities
	if phase=="baseline":
		if not world.ready_for_control() or loading_screen.blocks_input() or not gameplay_presentation_allowed():return
		peer_busy=true
		peer_check(world.ready_for_admission() and world.ready_for_control(),"Original area and controlled character complete actual loading admission")
		peer_check(not loading_screen.blocks_input() and not loading_screen.dismissed,"Actual loading veil completed without forced dismissal")
		await RenderingServer.frame_post_draw
		peer_check(root.get_texture().get_image().save_png(str(args.report).get_base_dir().path_join("peer-baseline.png"))==OK,"Actual initial Prelude framebuffer saved")
	elif phase in ["join","rejoin"]:
		var source: Dictionary=gameplay_ui.text.objects.get(id,{})
		if source.is_empty() or source.get("replicationRemoved",false) or not world.instances.has(id):return
		var actor: Node3D=world.instances[id]
		if not is_instance_valid(actor) or not world.installed.has(id) or not registry.native_owners.has(id) or actor.meshes.is_empty():return
		if not actor.is_visible_in_tree() or not actor.meshes.any(func(mesh):return mesh.is_visible_in_tree()):return
		# The actual native fade is allowed to finish on its own clocks.
		if not peer_phase.has("first_ready_ms"):peer_phase.first_ready_ms=Time.get_ticks_msec();return
		if Time.get_ticks_msec()-int(peer_phase.first_ready_ms)<1200:return
		peer_busy=true
		var reference: Variant=provider.get_reference(id)
		peer_check(source.objectType==5 and source.areaId==world.area_id and not source.get("replicationRemoved",false),phase+": received current-area original-server peer source")
		peer_check(PeerLife.token(source)[0][1] and PeerLife.token(source)[1][1],phase+": actual native and disclosure identities retained")
		peer_check(world.desired.has(id) and world.installed.has(id) and not world.hidden.has(id) and not world.failed_objects.has(id),phase+": complete actual World/CreatureStream admission without hidden or failure marks")
		peer_check(registry.native_owners.get(id)==actor and registry.entities.has(id),phase+": actual picking Registry owns the same admitted actor")
		peer_check(reference!=null and provider.resolve(reference)!=null,phase+": real entity API resolves authoritative peer reference")
		peer_check(actor.actor_alpha!=null and not actor.actor_alpha.closed,phase+": actual actor alpha owner remains open")
		peer_check(native_clock_runtime.enabled and native_clock_runtime.ready,phase+": actual approved native primary clock source is enabled and ready")
		var visibility: Dictionary=native_visibility_runtime.snapshot()
		peer_check(int(visibility.stats.accepted_worlds)>0 and int(visibility.stats.area_bindings)>0 and int(visibility.stats.model_publications)>0,phase+": actual native reveal runtime accepted original server world and model admission")
		peer_check(visibility.scope.get("controlled_id")==world.controlled_id and int(visibility.references)>0,phase+": native reveal runtime retains current controlled scope and observed references")
		var peer_members: Array=visibility.get("bridge",{}).get("owner",{}).get("members",[]).filter(func(member):return int(member.id)==id and member.lifetime==PeerLife.token(source))
		var native_peer: Dictionary=peer_members[0] if peer_members.size()==1 else {}
		peer_check(not native_peer.is_empty() and native_peer.get("opacity_pending") == null and native_peer.get("instance_present")==true and int(native_peer.get("fade",{}).get("opacity_word",-1))==1065353216 and int(native_peer.get("fade",{}).get("status",-1))==1 and int(native_peer.get("fade",{}).get("desired",-1))==1,phase+": current received peer native reveal completed alpha 1 without pending opacity")
		peer_check(actor.actor_alpha.snapshot().models.values().all(func(model):return model.alpha==1.0 and model.presentation_draw_enabled),phase+": actual peer model alpha endpoints remain fully visible")
		peer_check(not loading_screen.blocks_input() and world.ready_for_control() and gameplay_presentation_allowed(),phase+": peer admission preserves completed local loading and control")
		var diagnostic:={"phase":phase,"id":id,"source":source.duplicate(true),"reference":reference,"actorInstance":str(actor.get_instance_id()),"modelNames":actor.model_names.duplicate(),"meshCount":actor.meshes.size(),"actorAlpha":actor.actor_alpha.snapshot(),"loading":loading_screen.snapshot(),"nativeVisibility":native_visibility_runtime.snapshot()}
		report.peer_lifecycle.observations.append(diagnostic)
		if phase=="rejoin":
			peer_check(peer_old_reference!=null and provider.resolve(peer_old_reference)==null,"Rejoining peer cannot revive the previous read-only API reference")
			peer_check(peer_old_actor==null or not is_instance_valid(peer_old_actor.get_ref()),"Rejoining peer cannot revive the previous physical model/rig")
			peer_check(reference!=peer_old_reference,"Rejoin exposes a fresh received identity/reference")
		else:
			peer_old_reference=reference.duplicate(true);peer_old_actor=weakref(actor);peer_old_id=id
		await peer_pixels(actor,phase)
	elif phase=="leave":
		var source: Dictionary=gameplay_ui.text.objects.get(peer_old_id,{})
		if not source.is_empty() and not source.get("replicationRemoved",false):return
		if world.desired.has(peer_old_id) or world.instances.has(peer_old_id) or registry.entities.has(peer_old_id) or registry.native_owners.has(peer_old_id):return
		if peer_old_actor!=null and is_instance_valid(peer_old_actor.get_ref()):return
		peer_busy=true
		peer_check(provider.resolve(peer_old_reference)==null and provider.get_reference(peer_old_id)==null,"Actual server departure retires the old entity API reference")
		peer_check(not world.desired.has(peer_old_id) and not world.instances.has(peer_old_id) and not world.installed.has(peer_old_id),"Actual departure retires World desired/install/physical owners")
		peer_check(not registry.entities.has(peer_old_id) and not registry.native_owners.has(peer_old_id),"Actual departure retires picking/hover Registry ownership")
		peer_check(peer_old_actor!=null and not is_instance_valid(peer_old_actor.get_ref()),"Previous actor and rig have actually been freed")
		peer_check(not loading_screen.blocks_input() and world.ready_for_control(),"Peer departure preserves local loading/control admission")
		await RenderingServer.frame_post_draw
		peer_check(root.get_texture().get_image().save_png(str(args.report).get_base_dir().path_join("peer-left.png"))==OK,"Actual departed-peer framebuffer saved")
	else:return
	peer_seen.append(phase);send({"kind":"peer-lifecycle-observed","phase":phase,"id":id,"serial":accepted_raw_serial,"checks":peer_checks,"failures":peer_failures.duplicate()});peer_busy=false

func peer_pixels(actor: Node3D,phase: String) -> void:
	# Preserve the ordinary native camera. No source/motion/alpha, position,
	# camera, world visibility policy or server fields are changed.
	peer_capture=true
	var previous_mode:=host.process_mode;host.process_mode=Node.PROCESS_MODE_DISABLED
	await process_frame;await RenderingServer.frame_post_draw
	var present:=root.get_texture().get_image();var was_visible:=actor.visible
	actor.visible=false
	await process_frame;await RenderingServer.frame_post_draw
	var absent:=root.get_texture().get_image()
	actor.visible=was_visible
	await process_frame;await RenderingServer.frame_post_draw
	var restored:=root.get_texture().get_image()
	var changed:=0;var energy:=0.0
	for y in present.get_height():
		for x in present.get_width():
			var a:=present.get_pixel(x,y);var b:=absent.get_pixel(x,y);var delta:=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			if delta>0.04:changed+=1;energy+=delta
	var folder:=str(args.report).get_base_dir()
	for pair in [[present,"-present.png"],[absent,"-hidden-control.png"],[restored,"-restored.png"]]:peer_check(pair[0].save_png(folder.path_join("peer-"+phase+pair[1]))==OK,phase+": saved GPU "+pair[1])
	peer_check(changed>=32 and energy>2.0,phase+": actual admitted peer contributes visible framebuffer pixels against reversible hidden control")
	peer_check(actor.visible==was_visible and actor.is_visible_in_tree(),phase+": diagnostic restores exact prior actor visibility")
	report.peer_lifecycle.pixels.append({"phase":phase,"changedPixels":changed,"rgbEnergy":energy,"size":[present.get_width(),present.get_height()],"control":"Ordinary native camera retained; only peer Node3D visibility temporarily changed; host process and inherited tick paused during three GPU readbacks; exact previous visibility restored"})
	host.process_mode=previous_mode;peer_capture=false
	var queued:=peer_queued;peer_queued=[]
	for message in queued:super.receive(message)
