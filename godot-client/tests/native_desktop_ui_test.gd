extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func wait_until(predicate: Callable,seconds: float=60.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; root.push_input(event,true); await process_frame
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1920,1080)
	var catalog:=Catalog.new(); check(catalog.mount_install(str(args.install)),"Original installed resources mount read-only")
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,str(args.install),ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message): requests.append(message.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready and ui.skin_owner.announced),"Native original rule tables, TLK and fonts become ready")
	var desktop=ui.desktop; var spell:=-1
	for id in ui.text.tables.get("spells",{}).get("orderedRows",[]).size():
		# This scenario clicks the controlled creature, so select an original
		# cantrip which actually permits self targeting under the active table.
		if desktop.rules.spell_level(id,10)==0 and (desktop.rules.number(desktop.rules.cell(desktop.rules.row("spells",id),"TargetType"),0)&1)!=0: spell=id; break
	var portrait:=-1
	for id in ui.text.tables.get("portraits",{}).get("orderedRows",[]).size():
		var resource:=str(desktop.rules.cell(desktop.rules.row("portraits",id),"BaseResRef",""))
		if not resource.is_empty() and resource!="****" and not catalog.raster_location("po_"+resource+"l").is_empty(): portrait=id; break
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"position":[5.0,5.0,0.0],"orientation":{"yaw":90.0},"name":{"text":"Native UI test"},"portrait":portrait,"hitPoints":{"current":10,"maximum":15,"fieldE8":2},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"inventoryStats":{"field94":3000,"skills":[{"index":0,"flag":true,"value":4}]},"playerState":{"abilities":{"base":[10,12,10,16,11,8],"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0],"spellbooks":{"0":{"known":[spell],"memorized":{"0":[{"spell":spell,"ready":true,"metamagic":0}]}}},"mapExploration":{"55":[1]},"effectIcons":{"0":true}}}
	var header:={"area":{"id":55,"tileset":"tic01","width":1,"height":1,"tiles":[{"fields":{"14":0,"24":1},"height":0}],"mapPins":[{"id":7,"name":{"text":"A local pin"},"enabled":true,"position":[5.0,5.0,0.0]}]},"ui":{"party":[],"quickbar":[{"type":2,"intParam":spell,"classIndex":0}],"players":[],"journal":{"entries":[[1,{"tag":"quest","isQuest":true,"completed":false,"title":{"text":"The active quest"},"description":{"text":"Find the gate"}}],[2,{"tag":"note","isQuest":false,"title":{"text":"A note"},"description":{"text":"Read this note"}}]],"worldEntries":[[3,{"title":{"text":"A message"},"description":{"text":"Read this message"}}]],"loaded":true}}}
	ui.set_world(1,55,42,[actor],{},header); await process_frame; await process_frame
	check(desktop.party.visible and desktop.party.rows.size()==1 and desktop.party.rows[0].health.current==12,"Native party HUD presents the controlled creature and actual HP")
	check(desktop.quickbar.visible and desktop.quickbar.rows.size()==36 and desktop.quickbar.rows[0].enabled,"Native quickbar presents 36 server shortcut slots and spell uses")
	check(await wait_until(func():return desktop.quickbar_frame.layout_ready and desktop.art.waiting.is_empty() and desktop.art.models.pending.is_empty() and not desktop.art.models.active and ui.inventory.frame_skin.art.waiting.is_empty() and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active),"Original party/action and both quickbar artwork owners prepare in native Godot")
	check(desktop.art.models.stats.rendered>=8,"Party action buttons use original GUI models instead of text placeholders")
	desktop.quickbar.render(1); desktop.quickbar.render(0)
	check(desktop.quickbar.buttons[0].image.texture!=null and desktop.quickbar.buttons[0].get_theme_stylebox("normal").texture!=null,"Quickbar pages preserve native spell and slot artwork when rebuilt")
	await key(KEY_C); await process_frame
	check(desktop.sheet.visible and desktop.sheet.state.model.armorClass==12 and requests.any(func(m):return m.kind=="native-panel" and m.panel=="character" and m.open),"Character shortcut opens the native record and requests server details")
	check(await wait_until(func():return desktop.sheet.image_nodes.portrait.texture!=null and desktop.party.cards[0].get_node("Box/Portrait/Image").texture!=null),"Built-in party and character portraits use the original po_ prefix and native size fallbacks")
	check(desktop.sheet.image_nodes.portrait.flip_v and desktop.sheet.image_nodes.portrait.texture is AtlasTexture and desktop.party.cards[0].get_node("Box/Portrait/Image").flip_v,"Native portrait presentation flips original UV row order and crops the original padded image")
	await key(KEY_B); await process_frame
	check(desktop.book.visible and desktop.sheet.visible and desktop.book.rows.size()>0,"Spellbook and character record remain open simultaneously")
	desktop.book.select_entry(int(desktop.book.state.known[0].entryId)); desktop.book.operation("book-activate")
	check(not desktop.target.is_empty() or requests.any(func(m):return m.kind=="native-cast"),"Casting from the native spellbook enters targeting or emits a self-target request")
	if not desktop.target.is_empty():
		check(desktop.world_click({"id":42,"position":Vector3(5,0,-5)}),"A targeted world click is consumed by the spell rather than walking")
	check(requests.any(func(m):return m.kind=="native-cast" and m.spellId==spell),"Spell input carries the selected original spell ID")
	desktop.open_radial({"id":42,"position":Vector3(5,0,-5)},Vector2(1100,400)); await process_frame
	check(desktop.radial.active and desktop.radial.layer>ui.layer.layer and desktop.radial.entries.size()>0,"Right-click menu renders above every normal menu in its own high CanvasLayer")
	var old_request: int=desktop.radial.request_id; var old_menu: int=desktop.radial.menu_id
	desktop.radial_select({"requestId":old_request-1,"menuId":old_menu,"slot":0})
	check(desktop.radial.active,"Stale radial requests cannot activate current menu entries")
	desktop.radial.reset(); desktop.panel("journal"); desktop.panel("pvp"); await process_frame
	check(desktop.journal.visible and desktop.players.visible and desktop.sheet.visible and desktop.book.visible,"Journal and player list open alongside existing gameplay windows")
	check(not desktop.blocks_pointer(Vector2(2,2)) and desktop.blocks_pointer(desktop.sheet.get_global_rect().get_center()),"Menu input blocking covers actual windows and leaves outside world clicks available")
	check(desktop.buffs.buttons.size()==1,"Native effect-icon state populates the buff bar")
	check(desktop.journal.state.entries.size()==2 and desktop.journal.state.entries.any(func(row):return row.title.text=="The active quest"),"Journal resolves received active titles and includes ordinary non-quest entries")
	desktop.refresh_journal(2); check(desktop.journal.state.entries.is_empty(),"Personal Notes never substitutes received non-quest entries for editable local text")
	desktop.refresh_journal(3); check(desktop.journal.state.entries.size()==1 and desktop.journal.state.entries[0].title.text=="A message","Journal Messages presents received world entries")
	desktop.panel("map"); await process_frame
	check(await wait_until(func():return desktop.map_set_job<0 and desktop.map_queue.is_empty() and desktop.map_jobs.is_empty() and not desktop.art.models.active),"Native original SET and map models prepare without a JS map service")
	check(desktop.area_map.board.art.has(0) and desktop.area_map.board.art.has(4),"Area tiles and player marker use original GUI models and original tile raster overrides")
	check(desktop.area_map.board.explored==[1] and desktop.area_map.board.pins.size()==1 and desktop.area_map.board.pins[0].visible,"Map pins and exploration use received server state")
	desktop.sheet.position=Vector2(70,80); desktop.sheet._save(); desktop.sheet.close_sheet(); desktop.panel("character"); await process_frame
	check(desktop.sheet.position==Vector2(70,80) and desktop.book.visible,"Closing and reopening keeps a window's position without closing another")
	desktop.journal.close_journal(); desktop.players.close_players(); desktop.book.hide(); desktop.book.wanted=false
	var baseline:=actor.duplicate(true)
	desktop.begin_target({"type":3,"intParam":10}); check(desktop.target.is_empty() and requests[-1].kind=="native-mode" and requests[-1].modeId==2,"Parry switches native mode immediately without a target cursor")
	desktop.begin_target({"type":3,"intParam":22}); check(desktop.target.is_empty() and requests[-1].kind=="native-skill" and requests[-1].targetId==42 and requests[-1].packedSkill==22 and requests[-1].position==[0,0,0],"Craft Trap targets self with the native wrapper's zero vector")
	desktop.activate({"type":42,"intParam":22}); check(requests[-1].kind=="native-quickchat" and requests[-1].quickChat==22,"Party Follow command emits the original quick-chat identifier")
	desktop.begin_target({"type":3,"intParam":9}); var before:=requests.size(); desktop.world_click({"id":42,"position":Vector3.ONE})
	check(not desktop.target.is_empty() and requests.size()==before,"Open Lock rejects creatures without sending a request or moving")
	desktop.objects[43]={"id":43,"objectType":10}; desktop.world_click({"id":43,"position":Vector3.ONE})
	check(desktop.target.is_empty() and requests[-1].kind=="native-skill" and requests[-1].targetId==43 and requests[-1].position==[0,0,0],"Open Lock accepts a door and preserves packed skill routing")
	var self_power:=-1
	for index in ui.text.tables.iprp_spells.orderedRows.size():
		var power_spell: int=desktop.rules.number(desktop.rules.cell(desktop.rules.row("iprp_spells",index),"SpellIndex"),-1)
		if power_spell>=0 and (desktop.rules.number(desktop.rules.cell(desktop.rules.row("spells",power_spell),"TargetType"),0)&1)!=0: self_power=index; break
	check(self_power>=0,"The original item-property table supplies a self-compatible power for this self-click scenario")
	var potion:={"id":44,"objectType":6,"item":{"baseItem":49,"name":{"text":"Potion"},"properties":[{"type":15,"subtype":self_power,"costValue":1}]},"inventoryLocation":{"ownerId":42,"channel":"R","x":0,"y":0}}
	desktop.objects[44]=potion; desktop.use_inventory_item(44)
	if not desktop.target.is_empty(): desktop.world_click({"id":42,"position":Vector3.ZERO})
	check(requests[-1].kind=="native-item-ability" and requests[-1].propertyIndex==0 and requests[-1].variant==255 and requests[-1].itemId==44,"Native inventory item powers preserve property index, item identity and variant")
	check(actor==baseline,"UI targeting sends requests without changing authoritative character state")
	desktop.level_up.wanted=true; desktop.level_up.show()
	var availability: Array=[]; availability.resize(11); availability.fill(false); availability[10]=true
	var ranks: Array=[]; ranks.resize(ui.text.tables.skills.orderedRows.size()); ranks.fill(0)
	desktop.level_owner.begin({"token":7,"available":availability,"snapshot":{"classes":[{"id":10,"level":3,"domains":[],"school":0}],"race":6,"baseAbilities":[10,12,10,16,11,8],"skills":ranks,"feats":[],"spellbooks":{},"fieldDC6":0,"fieldE34":255,"fieldE48":"","fieldE30":255,"fieldE38":""}})
	check(await wait_until(func():return not desktop.level_up.state.is_empty() and not desktop.level_rules_waiting),"Native level-up reads original per-class progression tables")
	desktop.level_owner.draft.ability=3
	for level in range(1,10):
		var choices: Array=desktop.level_owner.spell_options(level)
		if choices.size()>=2: desktop.level_owner.draft.known[str(level)]=choices.slice(0,2); break
	check(desktop.level_owner.abilities()[3]==17 and desktop.level_owner.errors().is_empty(),"Native level-up ability and shared wizard spell choices satisfy original rules")
	desktop.level_owner.step=6; desktop.level_owner.render(); var bound: int=desktop.level_owner.serial
	desktop.level_owner.input({"kind":"level-submit","viewId":bound})
	check(requests[-1].kind=="native-level-up" and requests[-1].token==7 and requests[-1].proposal.ability==3 and desktop.level_owner.submitting,"Level-up emits a proposal and waits for server confirmation")
	desktop.receive({"kind":"native-action-result","action":"native-level-up","operation":"submit","accepted":true,"result":{"accepted":false}})
	check(desktop.level_up.visible and not desktop.level_up.waiting and not desktop.level_owner.submitting and desktop.level_up.status.text.contains("rejected"),"A rejected level-up remains editable and never fabricates an applied level")
	desktop.level_up.reset()
	var stock:=potion.duplicate(true); stock.id=45; stock.item.cost=100; stock.item.identified=true; stock.item.parts=[1]; stock.item.colors=[]; stock.inventoryLocation={"ownerId":99,"channel":"M","x":0,"y":0}
	ui.inventory.objects[45]=stock
	var stock_state:={"inventories":[["M",{"entries":[{"id":45,"x":0,"y":0}],"pageCount":1}]],"containers":[],"store":{"open":true,"generation":5,"panel":0,"page":0,"gold":1000,"sellRate":150,"buyRate":50,"blackMarketRate":20,"identifyPrice":100,"maxBuyPrice":-1}}
	ui.inventory.update_inventory(stock_state); ui.inventory.refresh(); await process_frame
	check(ui.inventory.ui.store_panel.visible and ui.inventory.ui.items[45].price==150,"Native store opens from replicated stock with the server purchase rate")
	ui.inventory.ui.store_panel.select_item(45); ui.inventory.ui.store_panel.transact()
	check(requests[-1].kind=="native-store" and requests[-1].operation=="buy" and requests[-1].itemId==45 and requests[-1].storeGeneration==5 and ui.inventory.inventories.M.entries.size()==1,"Store purchase sends the selected server item and preserves stock until replication")
	var store_bound: int=ui.inventory.view_serial; ui.inventory.ui.close_inventory(); var sent:=requests.size(); ui.inventory.update_inventory(stock_state)
	check(not ui.inventory.ui.wanted,"Closing a store cannot be undone by an unchanged incoming stock snapshot")
	ui.inventory.store_command({"kind":"inventory-store","viewId":store_bound-1,"entryId":45,"operation":"buy"})
	check(requests.size()==sent,"Retired store views cannot purchase current stock")


	desktop.area_map.position=Vector2(790,100)
	desktop.open_radial({"id":42,"position":Vector3(5,0,-5)},Vector2(1400,720)); await process_frame

	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(str(args.report)+".png")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"art":desktop.art.models.stats.duplicate(true),"missing_art":desktop.art.failed.keys(),"ui_errors":ui.stats.errors.duplicate(true),"requests":requests,"publicConnections":0,"scope":"Native UI controls with original installed artwork and authored raw server state; real server acceptance tested separately"}
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
