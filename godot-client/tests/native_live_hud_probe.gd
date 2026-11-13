extends RefCounted
# Actual native HUD controls over two original-server participants. No fake
# health/effects/roster updates and no rendered-pixel claim in headless runs.
var p
var partner:=-1
func member(id: int) -> Dictionary:
	for row in p.desktop.party.rows:
		if int(row.id)==id: return row
	return {}
func box(id: int):
	var row:=member(id)
	return p.desktop.party.cards.get(int(row.get("entryId",-1))).get_node("Box") if not row.is_empty() and p.desktop.party.cards.has(int(row.entryId)) else null
func hp(id: int) -> Dictionary:
	return p.desktop.objects.get(id,{}).get("replicated",{}).get("hitPoints",{})
func health_matches(id: int) -> bool:
	var received:=hp(id); var row:=member(id); var card=box(id)
	if card==null or not row.get("health") is Dictionary or not received.has("current") or not received.has("maximum"): return false
	var current:=int(received.current)+int(received.get("fieldE8",0)); var maximum:=int(received.maximum)
	var bar=card.get_node_or_null("NativeHealth")
	return is_instance_valid(bar) and row.health.current==current and row.health.maximum==maximum and absf(bar.desired-clampf(float(current)/maxf(1,maximum)*100,0,100))<0.01 and bar.desired_clip==row.health.clip
func leader(id: int) -> bool:
	return await p.wait_for(func():return is_instance_valid(p.desktop.party_frame.leader) and p.desktop.party_frame.leader.is_visible_in_tree() and p.desktop.party_frame.leader.get_parent()==box(id),"Native shared party crest follows the original-server leader "+str(id))
func separated() -> bool:
	return await p.wait_for(func():return p.desktop.party.rows.size()==1 and member(partner).is_empty() and not p.desktop.party_frame.leader.visible,"Actual server party removal retires the remote card and shared leader crest")
func command(value: String) -> void: await p.chat_enter("-native-hud-"+value)
func run(probe,partner_id: int) -> bool:
	p=probe; partner=partner_id
	if not await p.wait_for(func():return p.desktop.party_frame.layout_ready and p.desktop.party_frame.failure.is_empty() and p.desktop.party.rows.size()==2 and box(partner)!=null,"Real server membership publishes both native party cards using worker-loaded original models",30): return false
	if not await p.wait_for(func():return health_matches(p.desktop.actor_id) and health_matches(partner),"Both original-server HP disclosures reach native row values and source health-pose requests"): return false
	if not await leader(p.desktop.actor_id): return false
	var row:=member(partner); var raw: Dictionary=p.desktop.objects[partner].get("replicated",{})
	if not p.check(raw.has("field8D4") and raw.has("field8D6") and str(row.indicators.state)==preload("res://systems/native_data/party_indicators.gd").state_clip(int(raw.field8D4),int(raw.field8D6)),"Native party status uses this real member's received alive/mode fields",{"indicators":row.indicators,"flags":raw.get("field8D4"),"mode":raw.get("field8D6")}): return false
	if not await p.wait_for(func():var locator=box(partner).get_node_or_null("NativeLocator"); return is_instance_valid(locator) and locator.is_visible_in_tree() and locator.clip=="angle" and not locator.faces.is_empty() and locator.failure.is_empty(),"Worker-loaded original party locator samples its angle geometry for the actual same-area member"): return false
	var players_open: bool=p.desktop.players.wanted
	p.desktop.players.close_players(); p.desktop.sheet.close_sheet(); p.ui.inventory.ui.close_inventory()
	if not await nameplates(): return false
	if not await custom_captions(): return false
	if not await object_captions(): return false
	if not await item_captions(): return false
	if not await instant_tooltips(): return false
	if not await preload("res://tests/native_live_item_tooltip_probe.gd").new().run(p,partner): return false
	if not await effects(): return false
	if not await poison(): return false
	if not await action_queue(): return false
	if players_open:
		p.desktop.panel("pvp")
		if not await p.wait_for(func():return p.desktop.players.wanted and p.desktop.players_frame.stage.is_visible_in_tree(),"Restore the actual native player controls after HUD input checks"): return false
	return true
func nameplates() -> bool:
	if not await p.wait_for(func():return p.session.world.instances.has(partner) and p.session.registry.entities.get(partner,{}).get("eligible",false),"Actual remote player model is available to world highlighting",30): return false
	var focused: Control=p.get_viewport().gui_get_focus_owner()
	if focused!=null: focused.release_focus()
	await p.inject_key(KEY_TAB)
	var visible: bool=await p.wait_for(func():return p.session.world_input.tab and p.session.hud.nameplates.has(partner) and p.session.hud.nameplates[partner].is_visible_in_tree(),"Actual Tab input shows the received remote player's native world nameplate")
	if not visible:
		await p.inject_key(KEY_TAB,false); return false
	var plate=p.session.hud.nameplates[partner]; var name: String=p.ui.text.name(null,partner)
	if not await p.wait_for(func():return plate.source!=null and plate.source.failures.is_empty() and plate.portrait!=null and plate.portrait.texture!=null and not plate.backdrop.plan.is_empty() and not plate.placeholder.visible,"Real server nameplate uses worker-loaded original backdrop/portrait geometry and raw raster"): return false
	var owner: Node3D=p.session.registry.native_owners.get(partner)
	if not p.check(is_instance_valid(owner) and owner.has_meta("native_nameplate_height") and is_finite(float(owner.get_meta("native_nameplate_height"))),"Actual worker-prepared creature publishes a cached original headconjure/fallback nameplate height"): return false
	if not p.check(plate.data.name.text==name and not plate.data.portrait.is_empty() and plate.mouse_filter==Control.MOUSE_FILTER_IGNORE and plate.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Real server identity and portrait populate a pointer-transparent native nameplate",{"name":name,"portrait":plate.data.portrait,"condition":plate.data.condition.text}):
		await p.inject_key(KEY_TAB,false); return false
	# Focus while held must clear highlighting even if the text control consumes
	# the release. Retain the same actual control for its later chat checks.
	p.ui.chat.entry.grab_focus(); await p.get_tree().process_frame
	if not await p.wait_for(func():return not p.session.world_input.tab,"Actual chat focus clears held world highlighting without blocking text input"):
		await p.inject_key(KEY_TAB,false); return false
	await p.inject_key(KEY_TAB,false); p.ui.chat.entry.release_focus()
	return true
func custom_captions() -> bool:
	await p.inject_key(KEY_TAB)
	if not await p.wait_for(func():return p.session.hud.nameplates.has(partner) and p.session.hud.nameplates[partner].is_visible_in_tree(),"Actual Tab restores the remote caption before original server override commands"):
		await p.inject_key(KEY_TAB,false); return false
	var plate=p.session.hud.nameplates[partner]; var original: String=plate.data.caption.text; var identity: int=plate.caption.get_instance_id()
	for row in [["bubble-replace",1,"NATIVE_HUD_REPLACE"],["bubble-prefix",2,"NATIVE_HUD_PREFIX"],["bubble-suffix",3,"NATIVE_HUD_SUFFIX"],["bubble-clear",0,""]]:
		p.barter_peer_command("hud-command",row[0])
		# Empty clear text needs equality: String.contains("") is false in Godot.
		# Keep the received mode check and the subsequent full native-label check.
		if not await p.wait_for(func():var misc: Dictionary=p.desktop.objects.get(partner,{}).get("replicated",{}).get("light",{}); var raw: String=str(misc.get("field278","")); return int(misc.get("field270",-1))==int(row[1]) and (raw=="" if int(row[1])==0 else raw.contains(str(row[2]))),"Original server replicates actual text-bubble mode "+str(row[1])):
			await p.inject_key(KEY_TAB,false); return false
		var expected: String=str(row[2]) if int(row[1])==1 else str(row[2])+"\n"+original if int(row[1])==2 else original+"\n"+str(row[2]) if int(row[1])==3 else original
		if not await p.wait_for(func():return plate.caption.get_parsed_text()==expected and plate.data.override_mode==int(row[1]) and plate.is_visible_in_tree(),"Actual native caption displays original override order for mode "+str(row[1])):
			await p.inject_key(KEY_TAB,false); return false
	await p.inject_key(KEY_TAB,false)
	return p.check(plate.caption.get_instance_id()==identity and plate.data.caption.text==original,"Clearing the server override restores normal text in the same native caption control")
func object_captions() -> bool:
	var chest:=-1
	for id in p.desktop.objects:
		if int(p.desktop.objects[id].get("objectType",0))==9 and p.ui.text.name(null,int(id))=="Native container chest": chest=int(id); break
	if not p.check(chest>=0,"Original local server discloses the real placeable used for hover-caption testing"): return false
	var found: Dictionary={}; var registry=p.session.registry; var camera: Camera3D=p.session.camera
	var locate:=func():
		if not registry.entities.get(chest,{}).get("eligible",false) or not registry.bounds.has(chest): return false
		var box: AABB=registry.bounds[chest]
		for x in [0.25,0.5,0.75]:
			for y in [0.3,0.7]:
				for z in [0.25,0.5,0.75]:
					var point: Vector3=box.position+box.size*Vector3(x,y,z)
					if camera.is_position_behind(point): continue
					var screen: Vector2=camera.unproject_position(point)
					if not p.get_viewport().get_visible_rect().has_point(screen) or p.ui.blocks_pointer(screen) or p.session.hud.blocks_pointer(screen): continue
					if int(registry.pick(camera,screen).get("id",-1))==chest: found.point=screen; return true
		return false
	if not await p.wait_for(locate,"Actual prepared placeable geometry supplies an unobstructed native hover point",30): return false
	var motion:=InputEventMouseMotion.new(); motion.position=found.point; motion.global_position=found.point; Input.parse_input_event(motion)
	if not await p.wait_for(func():return p.session.world_input.hovered==chest and p.session.hud.nameplates.has(chest) and p.session.hud.nameplates[chest].is_visible_in_tree(),"Actual mouse motion over received placeable shows its native hover caption"):
		var point: Vector2=p.get_viewport().get_mouse_position()
		p.check(false,"Retain actual headless hover-input state",{"requested":str(found.point),"observed":str(point),"hovered":p.session.world_input.hovered,"locked":p.session.world_input.smoke_locked,"physics":p.session.world_input.is_physics_processing(),"blocked":p.ui.blocks_pointer(point) or p.session.hud.blocks_pointer(point),"hit":registry.pick(camera,point).get("id",-1)})
		return false
	var plate=p.session.hud.nameplates[chest]; var original: String=p.ui.text.name(null,chest); var identity: int=plate.caption.get_instance_id()
	if not p.check(plate.caption.get_parsed_text()==original and plate.data.color==Color("#8080ff") and not plate.portrait_frame.visible,"Actual placeable caption uses original blue text and no creature portrait"): return false
	for row in [["object-replace",1,"NATIVE_OBJECT_REPLACE"],["object-prefix",2,"NATIVE_OBJECT_PREFIX\n"],["object-suffix",3,"\nNATIVE_OBJECT_SUFFIX"],["object-hide",1,""],["object-clear",0,""]]:
		await command(row[0])
		if not await p.wait_for(func():var misc: Dictionary=p.desktop.objects.get(chest,{}).get("replicated",{}).get("light",{}); return int(misc.get("field270",-1))==int(row[1]) and str(misc.get("field278",""))==str(row[2]),"Original server replicates placeable caption command "+str(row[0])): return false
		var expected: String=str(row[2]) if int(row[1])==1 else str(row[2])+original if int(row[1])==2 else original+str(row[2]) if int(row[1])==3 else original
		if not await p.wait_for(func():return plate.caption.get_parsed_text()==expected and plate.data.override_mode==int(row[1]) and plate.is_visible_in_tree()==not expected.is_empty() and p.session.world_input.hovered==chest,"Actual native placeable caption displays or hides the complete server result for "+str(row[0])): return false
	return p.check(plate.caption.get_instance_id()==identity and plate.data.caption.text==original,"Clearing the placeable override restores normal text without rebuilding the hover owner")
func item_captions() -> bool:
	p.desktop.panel("inventory")
	var item_id:=-1
	if not await p.wait_for(func():return p.ui.inventory.ui.wanted and p.ui.inventory.frame_skin.layout_ready and p.ui.inventory.inventories.has("I"),"Actual native inventory opens for authoritative item-tooltip testing",30): return false
	for row in p.ui.inventory.inventories.I.entries:
		if int(row.get("slot",0))==2: item_id=int(row.id); break
	if not p.check(item_id>=0,"Original server provides the controlled actor's real equipped chest item"): return false
	var tooltip=p.ui.inventory.item_tooltips
	var original: String=p.ui.text.raw(p.item(item_id).get("name",{}),p.desktop.actor_id)
	var control_identity:=-1
	for row in [["item-replace",1,"<c"+String.chr(1)+String.chr(255)+String.chr(1)+">NATIVE_ITEM_REPLACE</c>"],["item-prefix",2,"NATIVE_ITEM_PREFIX\n"],["item-suffix",3,"\nNATIVE_ITEM_SUFFIX"],["item-hide",1,""],["item-clear",0,""]]:
		await command(row[0])
		if not await p.wait_for(func():var item: Dictionary=p.item(item_id); return int(item.get("field2b8",-1))==int(row[1]) and str(item.get("field2c0",""))==str(row[2]),"Original server's24/5 packet updates the existing equipped item for "+str(row[0])): return false
		var raw: String=str(row[2]) if int(row[1])==1 else str(row[2])+original if int(row[1])==2 else original+str(row[2]) if int(row[1])==3 else original
		var expected: Dictionary=preload("res://systems/native_data/rich_text.gd").parse(raw)
		if not await p.wait_for(func():return p.ui.inventory.ui.buttons.has(item_id) and p.ui.inventory.ui.buttons[item_id].row.get("tooltip",{})==expected,"Production inventory row receives the complete native tooltip for "+str(row[0])): return false
		var button=p.ui.inventory.ui.buttons[item_id]; var point: Vector2=button.get_global_rect().get_center()
		if control_identity<0: control_identity=button.get_instance_id()
		elif not p.check(button.get_instance_id()==control_identity,"Authoritative item-caption update retains the existing native hover control for "+str(row[0])): return false
		var bound: WeakRef=weakref(button)
		var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion)
		if not await p.wait_for(func():var current=bound.get_ref(); return is_instance_valid(current) and tooltip.target!=null and tooltip.target.get_ref()==current and tooltip.elapsed>=float(tooltip.wait_usec)/1000000.0 and (tooltip.plate.is_visible_in_tree() and tooltip.plate.caption.get_parsed_text()==expected.text if not str(expected.text).is_empty() else not tooltip.plate.visible),"Actual hover displays or hides the original-style item tooltip for "+str(row[0])):
			var current=bound.get_ref(); var hovered: Control=p.get_viewport().gui_get_hovered_control(); var target=tooltip.target.get_ref() if tooltip.target!=null else null
			p.check(false,"Retain actual item hover ownership and geometry on failure",{"requested":str(point),"observed":str(p.get_viewport().get_mouse_position()),"current":is_instance_valid(current) and current.current(),"rect":str(current.get_global_rect()) if is_instance_valid(current) else "freed","hovered":str(hovered.get_path()) if is_instance_valid(hovered) else "none","target":str(target.get_path()) if is_instance_valid(target) else "none","elapsed":tooltip.elapsed,"visible":tooltip.plate.is_visible_in_tree(),"text":tooltip.plate.caption.get_parsed_text(),"expected":expected.text,"identity":control_identity,"current_identity":p.ui.inventory.ui.buttons[item_id].get_instance_id() if p.ui.inventory.ui.buttons.has(item_id) else -1})
			return false
		if row[0]=="item-replace" and not p.check(tooltip.wait_usec==preload("res://systems/native_data/tooltip_preferences.gd").delay_usec and is_equal_approx(float(tooltip.wait_usec)/1000000.0,float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec"))),"Actual inventory tooltip uses the shared configured native delay",{"wait_usec":tooltip.wait_usec,"elapsed":tooltip.elapsed}): return false
	if not await p.wait_for(func():return tooltip.source.failures.is_empty() and not tooltip.plate.placeholder.visible,"Actual inventory tooltip loads original source bubble geometry and raw rasters",30): return false
	p.ui.inventory.ui.close_inventory()
	return await p.wait_for(func():return not tooltip.plate.visible and tooltip.target==null,"Closing inventory retires the native tooltip and its input owner")
func instant_tooltips() -> bool:
	var preferences=preload("res://systems/native_data/tooltip_preferences.gd")
	var saved_delay: int=preferences.delay_usec; var saved_doubletap: int=preferences.doubletap_ms
	p.ui.inventory.ui.open()
	if not await p.wait_for(func():return p.ui.inventory.ui.wanted and p.ui.inventory.frame_skin.layout_ready,"Original local actor's native inventory is ready for highlight-key/tooltips"): return false
	var button: Button=p.ui.inventory.ui.item_controls.examine; var owner=p.ui.inventory.item_tooltips
	preferences.apply(1000000); preferences.apply_doubletap(200)
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(1,1); motion.global_position=motion.position; Input.parse_input_event(motion); await p.get_tree().process_frame
	motion.position=Vector2(Vector2i(button.get_global_rect().get_center())); motion.global_position=motion.position; Input.parse_input_event(motion); await p.get_tree().process_frame
	await p.inject_key(KEY_TAB)
	var immediate: bool=p.check(p.ui.key_bindings.highlighted and p.session.world_input.tab and owner.plate.visible and owner.plate.caption.get_parsed_text()==button.tooltip_text and owner.elapsed<1.0,"Actual highlight key shows the native source-button hint before its one-second normal delay in the real local world",{"elapsed":owner.elapsed,"keys":p.ui.key_bindings.snapshot().highlight})
	await p.get_tree().create_timer(0.22).timeout; await p.inject_key(KEY_TAB,false)
	var released: bool=p.check(not p.ui.key_bindings.highlighted and not p.session.world_input.tab and owner.router.policy.delay==1000000,"Actual normal hold release clears world highlighting and restores the configured GUI delay")
	for down in [true,false,true,false]: await p.inject_key(KEY_TAB,down)
	var latched: bool=await p.wait_for(func():return p.ui.key_bindings.highlight_policy.phase==4 and p.ui.key_bindings.highlight_policy.held==1 and p.ui.key_bindings.highlight_key==0 and p.session.world_input.tab and p.session.hud.nameplates.has(partner) and p.session.hud.nameplates[partner].is_visible_in_tree(),"Actual double-tap retains the received remote player's nameplate after physical key release")
	await p.inject_key(KEY_TAB); await p.inject_key(KEY_TAB,false)
	var cleared: bool=await p.wait_for(func():return not p.session.world_input.tab and not p.ui.key_bindings.highlighted and p.ui.key_bindings.highlight_policy.held==0 and (not p.session.hud.nameplates.has(partner) or not p.session.hud.nameplates[partner].is_visible_in_tree()),"Next actual highlight-key tap hides the real remote nameplate and releases its latched state")
	preferences.apply(saved_delay); preferences.apply_doubletap(saved_doubletap); p.ui.inventory.ui.close_inventory()
	var retired: bool=await p.wait_for(func():return owner.target==null and not owner.plate.visible,"Inventory close retires the instant tooltip after restoring normal local preferences")
	return immediate and released and latched and cleared and retired
func effects() -> bool:
	var actor_id: int=p.desktop.actor_id; var before: int=int(hp(actor_id).current)
	await command("damage")
	if not await p.wait_for(func():return int(hp(actor_id).get("current",before))==before-1 and health_matches(actor_id),"Original server's one-point damage updates the actual controlled health request without a client-side HP edit"): return false
	await command("heal")
	if not await p.wait_for(func():return int(hp(actor_id).get("current",-1))==before and health_matches(actor_id),"Original-server healing restores the native controlled health presentation"): return false
	if not await p.wait_for(func():return p.desktop.buff_frame.layout_ready and p.desktop.buff_frame.failure.is_empty(),"Actual native effect bar loads original source quads and animation keys",30): return false
	await command("icon")
	if not await p.wait_for(func():return p.current().get("playerState",{}).get("effectIcons",{}).has("25") and p.desktop.buffs.buttons.has(25),"Original server adds the real effect icon and native effect button"): return false
	var button: Button=p.desktop.buffs.buttons[25]; var row: Dictionary=p.desktop.buffs.rows[25]
	var icon=button.get_node("Icon"); var resource: String=p.desktop.rules.cell(p.desktop.rules.row("effecticons",25),"Icon")
	if not p.check(str(row.resource).to_lower()==str(resource).to_lower() and icon.resource==row.resource and button.size==Vector2(40,40),"Actual effect button uses active effecticons metadata and original unstretched40px geometry",{"resource":row.resource,"state":row.state,"serial":row.serial}): return false
	if not p.check(button.get_meta("native_tooltip_managed",false) and button.get_tooltip(Vector2.ZERO).is_empty(),"Actual original-server effect uses the shared native hint without a duplicate engine popup"): return false
	var point:=button.get_global_rect().get_center(); var start: int=p.ui.chat.sequence
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; p.get_viewport().push_input(motion,true)
	var hint=p.ui.inventory.item_tooltips
	if not await p.wait_for(func():return hint.target!=null and hint.target.get_ref()==button and hint.plate.visible and hint.plate.caption.get_parsed_text()==str(row.label),"Actual effect hover shows its received active-table name in the original source bubble"): return false
	for down in [true,false]:
		var click:=InputEventMouseButton.new(); click.position=point; click.global_position=point; click.button_index=MOUSE_BUTTON_LEFT; click.pressed=down; click.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; p.get_viewport().push_input(click,true); await p.get_tree().process_frame
	if not await p.wait_for(func():return p.chat_since(start).any(func(item):return str(item.get("text","")).contains("NATIVE_PLAYERS_GUI_TYPE:5")) and p.chat_since(start).any(func(item):return str(item.get("text","")).contains("NATIVE_PLAYERS_GUI_INT:25")),"Actual effect mouse release reaches original-server GUI5 with effect ID25"): return false
	var retired: WeakRef=weakref(button)
	if not await p.wait_for(func():return not p.current().get("playerState",{}).get("effectIcons",{}).has("25") and not p.desktop.buffs.buttons.has(25),"Original-server effect expiry removes its native button",12): return false
	await p.get_tree().process_frame
	if not p.check(retired.get_ref()==null,"Expired effect releases its original native input owner"): return false
	if not p.check(not hint.plate.visible,"Original-server effect expiry also retires its displayed native hint"): return false
	await command("temporary")
	if not await p.wait_for(func():return int(hp(actor_id).get("fieldE8",0))==7 and health_matches(actor_id),"Original temporary HP reaches the actual health display without changing its disclosed maximum"): return false
	return await p.wait_for(func():return int(hp(actor_id).get("fieldE8",-1))==0 and health_matches(actor_id),"Original temporary-HP expiry restores the controlled health display",10)
func action_queue() -> bool:
	var queue=p.desktop.action_queue; var hint=p.ui.inventory.item_tooltips
	await command("queue-start")
	if not await p.wait_for(func():return queue.layout_ready and not queue.rows.is_empty() and not queue.buttons.is_empty() and not p.current().get("playerState",{}).get("actionQueue",[]).is_empty(),"Original server queues a real PC attack and publishes its native HUD widget"): return false
	var row: Dictionary=queue.rows[0]; var serial:=int(row.widgetSerial); var button: Button=queue.buttons[serial]; var identity: WeakRef=weakref(button)
	if not p.check(queue.painter.tooltips==hint and button.get_meta("native_tooltip_managed",false) and button.get_tooltip(Vector2.ZERO).is_empty(),"Real original-server action queue borrows the shared source tooltip owner"): return false
	var point:=button.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; p.get_viewport().push_input(motion,true)
	if not await p.wait_for(func():return hint.target!=null and hint.target.get_ref()==button and hint.plate.visible and hint.plate.caption.get_parsed_text()==str(row.label),"Actual queued-action hover displays its native source caption"): return false
	var down:=InputEventMouseButton.new(); down.position=point; down.global_position=point; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.button_mask=MOUSE_BUTTON_MASK_LEFT; p.get_viewport().push_input(down,true); await p.get_tree().process_frame
	down.pressed=false; down.button_mask=0; p.get_viewport().push_input(down,true)
	if not p.check(queue.pending.has(serial) and is_equal_approx(button.modulate.a,0.5),"Actual queued-action mouse release dims the same widget while awaiting authoritative cancellation"): return false
	if not await p.wait_for(func():return not queue.buttons.has(serial) and not queue.pending.has(serial) and not p.current().get("playerState",{}).get("actionQueue",[]).any(func(value):return int(value.widgetSerial)==serial),"Original-server queue deletion confirms the actual mouse cancellation and retires its native widget"): return false
	await p.get_tree().process_frame
	if not p.check(identity.get_ref()==null and not hint.plate.visible and not hint.closed,"Authoritative queue retirement releases the selected control/hint and preserves the shared HUD scope"): return false
	await command("queue-stop")
	return await p.wait_for(func():return p.current().get("playerState",{}).get("actionQueue",[]).is_empty(),"Owned original server clears remaining PC combat actions before later player checks")
func poison() -> bool:
	p.barter_peer_command("hud-command","poison")
	if not await p.wait_for(func():return bool(p.desktop.objects.get(partner,{}).get("replicated",{}).get("party",{}).get("field8B0",false)) and member(partner).get("health",{}).get("clip","")=="poison" and health_matches(partner),"Original server's remote poison flag selects the native party health poison animation"): return false
	if not await p.wait_for(func():return not bool(p.desktop.objects.get(partner,{}).get("replicated",{}).get("party",{}).get("field8B0",true)) and member(partner).get("health",{}).get("clip","")=="percentage" and health_matches(partner),"Original poison expiry restores the remote member's native health animation",10): return false
	p.barter_peer_command("hud-command","disease")
	if not await p.wait_for(func():return bool(p.desktop.objects.get(partner,{}).get("replicated",{}).get("party",{}).get("field8B4",false)) and member(partner).get("health",{}).get("clip","")=="disease" and health_matches(partner),"Original server's remote disease flag selects the distinct native party health animation"): return false
	return await p.wait_for(func():return not bool(p.desktop.objects.get(partner,{}).get("replicated",{}).get("party",{}).get("field8B4",true)) and member(partner).get("health",{}).get("clip","")=="percentage" and health_matches(partner),"Original disease expiry restores the actual party health animation",10)
