extends "res://tests/native_level_up_recommended_test.gd"
const ReceivedContext=preload("res://systems/native_data/level_up_received_context.gd")
const AppRandom=preload("res://systems/native_data/native_client_random.gd")
const PublishedDesktop=preload("res://systems/native_game_desktop.gd")
var current_actor: Dictionary={}
var pending_inputs: Array=[]
func actor_for(snapshot: Dictionary) -> Dictionary:
	var level:=snapshot.duplicate(true)
	for key in ["actorId","classes","race","goodEvil","lawChaos","baseAbilities","feats","spellbooks"]:level.erase(key)
	var stats:={"classes":snapshot.classes.duplicate(true)}
	for pair in [["race","racialType"],["goodEvil","fieldDE4"],["lawChaos","fieldDE6"]]:
		if snapshot.has(pair[0]):stats[pair[1]]=snapshot[pair[0]]
	return {"id":snapshot.actorId,"objectType":5,"areaId":7,"nativeLifetime":9,"clientKnownLifetime":10,"replicationRemoved":false,"inventoryStats":{},"replicated":{"stats":stats},"playerState":{"combat":{"canLevelUp":true},"abilities":{"base":snapshot.baseAbilities.duplicate()},"feats":snapshot.feats.duplicate(),"spellbooks":snapshot.spellbooks.duplicate(true),"levelUp":level}}
func start_wait(begin: Dictionary,token: int,already: bool=false) -> bool:
	panel.reset();var value:=begin.duplicate(true);value.token=token;value.draftContext.baseFortitude=null
	# The inherited noncaster source-only fixture predates network snapshot
	# schema tests. A real networkLevelUpSnapshot always contains its received
	# spellbooks map, even when the authored character has no books.
	if not value.snapshot.has("spellbooks"):value.snapshot.spellbooks={}
	current_actor=actor_for(value.snapshot)
	desktop.actor_value=current_actor
	if already:current_actor.inventoryStats.field9c=0
	runtime.current_actor_reader=func():return current_actor
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	return await ready("class")
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	cancel_on_press=false;var stream=AppRandom.acquire();var draws: int=stream.draws;var commands: int=desktop.commands.size()
	if not gate(await start_wait(begin,101),"Missing independent Fortitude retains original native Class rather than switching editor"):return
	check(runtime.active and panel.source_active and not panel.visible and runtime.context_wait.armed and not private_owner.wanted,"Pending context owns an uneditable native transaction while generic editor stays hidden")
	var pane=front.panes["class"];var old_ticket: Array=front.ticket.duplicate();var old_scope: Array=front.scope.duplicate();var original_result: Dictionary=runtime.result.duplicate(true)
	check(pane.row_buttons.is_empty() and pane.buttons.okbutton.disabled and pane.buttons.recommendbutton.disabled and not pane.buttons.cancelbutton.disabled and pane.help_body.get_parsed_text().contains("Waiting for character data"),"Native pending controls show explicit help and usable Cancel with no selectable choices")
	pane.complete(true);front.accepted.emit("class",3,old_ticket);front.action_requested.emit("class","recommend",-1,old_ticket);await frames()
	check(runtime.context_wait.armed and not private_owner.wanted and desktop.commands.size()==commands+1 and stream.draws==draws,"Synthetic accepted/action signals cannot create a private class, packet or RNG draw during waiting")
	controller.input({"kind":"level-submit","viewId":controller.serial});controller.input({"kind":"level-page","viewId":controller.serial,"step":6});await frames()
	check(runtime.context_wait.armed and desktop.commands.size()==commands+1,"Hidden legacy callbacks cannot submit or navigate behind the source surface")
	var late_before:=current_actor.duplicate(true);current_actor.inventoryStats.field9c=0;var received_row:=current_actor.duplicate(true);var began:=Time.get_ticks_usec();controller.observe_received();pending_inputs.append({"kind":"late-received-resume","callback_usec":Time.get_ticks_usec()-began})
	check(await ready("class") and not runtime.context_wait.armed and private_owner.wanted and private_owner.context.baseFortitude==0 and front.scope!=old_scope,"Accepted signed-zero S9c resumes the same token in the actual source Class owner")
	check(runtime.result.token==101 and runtime.result.snapshot==original_result.snapshot and original_result.draftContext.baseFortitude==null and current_actor==received_row and late_before.inventoryStats.is_empty(),"Only detached draftContext changes; canonical actor and immutable transaction comparison remain exact")
	check(not pane.buttons.okbutton.disabled and not pane.help_body.get_parsed_text().contains("Waiting for character data") and desktop.commands.size()==commands+1 and stream.draws==draws,"Ready Class clears pending UI without another begin or die draw")
	await click(pane.buttons.okbutton)
	check(await ready("attributes") and private_owner.class_id==3,"Physical resumed Class OK enters actual level-up Attributes")
	await key_escape();check(not panel.wanted and desktop.commands[-1].operation=="cancel" and desktop.commands[-1].token==101,"Resumed source cancellation retains the original server token")
	if not gate(await start_wait(begin,102),"Second missing-context native entry is available for physical cancellation"):return
	commands=desktop.commands.size();await click(front.panes["class"].buttons.cancelbutton)
	current_actor.inventoryStats.field9c=2;controller.observe_received();await frames()
	check(not panel.wanted and not runtime.active and not runtime.context_wait.armed and desktop.commands.size()==commands+1 and desktop.commands[-1].operation=="cancel" and desktop.commands[-1].token==102,"Physical pending Cancel sends one scoped cancellation and late data cannot reopen it")
	if not gate(await start_wait(begin,103,true),"S9c arriving before the async begin reply is handled without a second request"):return
	check(private_owner.wanted and not runtime.context_wait.armed and private_owner.context.baseFortitude==0 and stream.draws==draws,"Already-received metadata race takes the same fenced native path")
	await key_escape()
	for kind in ["native-lifetime","disclosure-lifetime","removed","snapshot","levelable","catalog"]:
		if not gate(await start_wait(begin,110+pending_inputs.size()),"Fresh missing-context entry for "+kind):return
		var token: int=runtime.result.token;commands=desktop.commands.size();current_actor.inventoryStats.field9c=3
		match kind:
			"native-lifetime":current_actor.nativeLifetime+=1
			"disclosure-lifetime":current_actor.clientKnownLifetime+=1
			"removed":current_actor.replicationRemoved=true
			"snapshot":current_actor.playerState.levelUp.skills[0]+=1
			"levelable":current_actor.playerState.combat.canLevelUp=false
			"catalog":runtime.current_catalog_reader=func():return null
		controller.observe_received();await frames()
		var retired_actor: bool=kind in ["native-lifetime","disclosure-lifetime","removed"]
		var command_guard: bool=desktop.commands.size()==commands if retired_actor else desktop.commands.size()==commands+1 and desktop.commands[-1].operation=="cancel" and desktop.commands[-1].token==token
		check(not runtime.active and not panel.wanted and not private_owner.wanted and command_guard,"Publication boundary rejects stale "+kind+"; retired actor resets without sending to its replacement")
		pending_inputs.append({"kind":kind});runtime.current_catalog_reader=controller.source_catalog
	if not gate(await start_wait(begin,121),"Escapable pending entry reopens after prior stale scopes"):return
	await key_escape();check(not runtime.active and not panel.wanted and stream.draws==draws,"Physical Escape cancels pending context and leaves process random history unchanged")
	if not gate(await start_wait(begin,122),"Native waiting entry is available for the real Desktop publication boundary"):return
	var publication:=PublishedDesktop.new();publication.generation=desktop.generation;publication.area_id=7;publication.actor_id=42;publication.owner_ui={"text":active_text};publication.objects={42:current_actor};publication.level_owner=controller
	runtime.current_actor_reader=publication.actor;var next_actor:=current_actor.duplicate(true);next_actor.inventoryStats.field9c=-1;commands=desktop.commands.size();began=Time.get_ticks_usec()
	publication.set_world(desktop.generation,7,42,{42:next_actor},{"module":desktop.state.module})
	pending_inputs.append({"kind":"actual-desktop-publication","callback_usec":Time.get_ticks_usec()-began})
	check(await ready("class") and not runtime.context_wait.armed and private_owner.wanted and private_owner.context.baseFortitude==-1 and desktop.commands.size()==commands,"Actual Desktop.set_world publishes actor/header before automatically resuming the same source transaction")
	check(publication.actor()==next_actor and stream.draws==draws,"Real object-publication hook leaves received row exact and consumes no die")
	runtime.current_actor_reader=Callable();publication.level_owner=null;publication.closed=true;publication.free();await key_escape()
	check(received==before and desktop.commands.all(func(value):return value.operation!="submit"),"All waiting scenarios preserve received actor and emit no level-up proposal")
	runtime.current_actor_reader=Callable();active_text.tables=tables;observations.append({"kind":"received-context-wait","cases":pending_inputs})
