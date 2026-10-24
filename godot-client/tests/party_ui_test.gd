extends SceneTree
const Party = preload("res://systems/server_party.gd")
const Players = preload("res://systems/server_players.gd")
const Buffs = preload("res://systems/server_buffs.gd")
const Lobby = preload("res://systems/character_lobby.gd")
const Client = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array = []
var selected: Array = []
var menus: Array = []
var panels: Array = []
var requests: Array = []
class World extends Node:
	var clicks := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: clicks += 1
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func click(point: Vector2, key: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = key; event.pressed = pressed; event.position = point; event.global_position = point; root.push_input(event, true); await process_frame
func row(index: int, own: bool = false, available: bool = true) -> Dictionary:
	return {"entryId":index,"id":9 + index,"self":own,"available":available,"health":{"current":23,"maximum":30} if own else null,"canLevelUp":own,"label":"Native player" if own else "Companion %s" % index,"portraitKey":str(index)}
func view(bar, id: int, rows: Array) -> void:
	var definitions: Array = []
	for index in 8: definitions.append({"index":index,"id":["map","inventory","journal","character","rest","spells","options","pvp"][index],"label":"Panel %s" % index,"key":null})
	bar.receive({"kind":"party-view","viewId":id,"actorId":9,"rows":rows,"actions":definitions})
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1000, 800)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var lobby := Lobby.new(); root.add_child(lobby); lobby.apply_state({"connection":1,"state":{"phase":"playing","connected":true}})
	var bar := Party.new(); layer.add_child(bar); bar.setup()
	var buffs := Buffs.new(); layer.add_child(buffs); buffs.setup(); buffs.receive({"kind":"buff-begin","viewId":1,"actorId":9,"count":2}); buffs.receive({"kind":"buff-rows","viewId":1,"rows":[{"id":1,"state":0},{"id":2,"state":1}]}); buffs.receive({"kind":"buff-commit","viewId":1})
	var world := World.new(); root.add_child(world)
	bar.portrait_selected.connect(func(index, _point): selected.append(index)); bar.portrait_menu.connect(func(index, _point): menus.append(index)); bar.panel_requested.connect(func(id): panels.append(id)); bar.request.connect(func(value): requests.append(value))
	view(bar, 1, [row(0, true), row(1), row(2, false, false)]); await process_frame; await process_frame; await process_frame
	check(bar.visible and bar.cards.size() == 3 and bar.action_buttons.size() == 8, "Native HUD contains controlled player, received companion and unavailable membership plus all eight panel controls")
	var portrait: Button = bar.cards[0].get_node("Box/Portrait"); var identity := portrait.get_instance_id()
	check(portrait.size.y >= 100 and bar.cards[1].get_node("Box/Portrait").size.y >= 64, "Player and companion portraits retain their original aspect areas")
	check(bar.cards[0].get_node("Box/Health/Text").text == "23/30" and bar.cards[1].get_node("Box/Health/Text").text == "—", "Native health shows received totals and preserves undisclosed companion HP")
	var pixels := Image.create(64, 100, false, Image.FORMAT_RGBA8); pixels.fill(Color.GREEN); var image := "data:image/png;base64," + Marshalls.raw_to_base64(pixels.save_png_to_buffer())
	bar.receive({"kind":"party-portrait","viewId":1,"entryId":0,"image":image}); check(portrait.get_node("Image").texture.get_size() == Vector2(64, 100), "Portrait pixels reach the native card without cropping its lower half")
	var at: Vector2 = portrait.get_global_rect().get_center(); await click(at); await click(at, MOUSE_BUTTON_RIGHT)
	check(selected == [0] and menus == [0] and world.clicks == 0, "Actual GUI left and right portrait clicks dispatch their distinct handlers without world clicks")
	await click(bar.cards[2].get_node("Box/Portrait").get_global_rect().get_center())
	check(selected == [0] and bar.cards[2].get_node("Box/Portrait").disabled, "Unavailable party portraits are not actionable")
	for index in 8: await click(bar.action_buttons[index].get_global_rect().get_center())
	check(panels == ["map","inventory","journal","character","spells","options","pvp"] and requests.size() == 1 and requests[0].kind == "party-rest", "All eight actual HUD controls route panel actions and typed Rest separately")
	bar.receive({"kind":"party-state","viewId":1,"rows":[{"entryId":0,"health":{"current":8,"maximum":30},"canLevelUp":false}]}); await process_frame
	check(portrait.get_instance_id() == identity and bar.cards[0].get_node("Box/Health/Text").text == "8/30" and not bar.cards[0].get_node("Box/Level").visible, "Live HP and level availability update without replacing a pressed portrait")
	bar.receive({"kind":"party-art","viewId":1,"index":0,"state":"up","skin":{"url":image}}); check(bar.action_buttons[0].text.is_empty() and bar.action_buttons[0].get_theme_stylebox("normal") is StyleBoxTexture, "Original HUD skins replace text fallbacks on the native buttons")
	check(not buffs.blocks_pointer(at) and not bar.blocks_pointer(buffs.buttons[1].get_global_rect().get_center()) and not lobby.blocks_pointer(at), "Party portraits, buff slots and connection menu occupy distinct input regions")
	var before: int = world.clicks; await click(Vector2(10, 600)); check(world.clicks > before and not bar.blocks_pointer(Vector2(10, 600)), "Clicks outside the party rail still reach the world")
	view(bar, 2, [row(0, true), row(1)]); bar.receive({"kind":"party-label","viewId":1,"entryId":0,"label":"Old callback"}); bar.receive({"kind":"party-portrait","viewId":1,"entryId":1,"image":image}); await process_frame
	check(bar.cards[0].get_node("Box/Name").text == "Native player" and bar.cards[1].get_node("Box/Portrait/Image").texture == null, "A retired view cannot replace labels or portraits")
	var many: Array = [row(0, true)]
	for index in range(1, 40): many.append(row(index))
	view(bar, 3, many); await process_frame; await process_frame; bar.scroll.scroll_vertical = 100000; await process_frame; await process_frame
	var last: Vector2 = bar.cards[39].get_node("Box/Portrait").get_global_rect().get_center(); await click(last)
	check(selected.back() == 39 and bar.blocks_pointer(last) and not bar.blocks_pointer(portrait.get_global_rect().get_center()), "Large server rosters scroll to the last member without offscreen input interception")
	root.size = Vector2i(320, 240); await process_frame; await process_frame
	check(bar.get_global_rect().end.x <= 320 and bar.get_global_rect().end.y <= 240, "Party rail remains inside a narrow resized viewport")
	var players := Players.new(); layer.add_child(players); players.setup(""); players.request.connect(func(value): requests.append(value)); players.open(); players.receive({"kind":"players-view","viewId":4,"rows":[{"entryId":0,"label":"Self","account":"Local","self":true,"dm":false},{"entryId":1,"label":"Friend","account":"Other","self":false,"dm":false}]}); await process_frame
	check(players.list.get_node("Player0").get_child_count() == 1 and players.list.get_node("Player1").get_child_count() == 2, "Player list exposes attitude controls only for other canonical players")
	var friendly: Button = players.list.get_node("Player1").get_child(1).get_child(0); friendly.pressed.emit(); check(requests.back() == {"kind":"players-attitude","viewId":4,"entryId":1,"likes":true}, "Native attitude button carries a typed Boolean and private row handle")
	var count := requests.size(); players.reset(); friendly.pressed.emit(); check(requests.size() == count, "Retired player buttons do not dispatch another request")
	portrait = null; bar.reset(); await process_frame; await process_frame; check(bar.cards.is_empty() and bar.art.is_empty() and bar.retired_alive() == 0, "Connection retirement releases all native party cards and artwork")
	players.free(); bar.free(); buffs.free(); world.free(); layer.free(); lobby.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
