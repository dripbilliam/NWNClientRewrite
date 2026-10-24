extends "res://systems/inventory_probe.gd"
func title_present(text: String) -> bool:
	return client.journal.state.get("entries", []).any(func(row): return str(row.title.text).contains(text))
func stage_present(text: String) -> bool:
	return client.journal.state.get("entries", []).any(func(row): return str(row.description.text).contains(text))
func pin_index() -> int:
	for index in client.area_map.board.pins.size():
		if str(client.area_map.board.pins[index].rich.text).contains("Native server map pin"): return index
	return -1
func explored_count() -> int: return client.area_map.board.explored.filter(func(value): return value).size()
func chat(text: String) -> void: client.command({"kind": "chat", "channel": 1, "text": text})
func category(index: int) -> bool:
	client.journal.choose(index)
	return await wait_until(func(): return client.journal.page == index, 12)
func run(owner, message: Dictionary) -> void:
	client = owner; scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	var map = client.area_map; var log = client.journal
	client.quickbar.map_requested.emit(); client.quickbar.journal_requested.emit()
	check(await wait_until(func(): return map.view_id >= 0 and log.view_id >= 0 and log.state.get("loaded", false), 20), "Native map and subscribed journal open independently against the actual server")
	if map.view_id < 0 or log.view_id < 0: finish(message); return
	chat("-native-records-setup")
	check(await wait_until(func(): return title_present("Native active quest") and stage_present("FIRST_QUEST_STAGE"), 12), "Native journal displays the actual server-authored quest and initial stage")
	check(log.state.entries.any(func(row): return str(row.description.text).contains("Spectorial")) and log.body.get_child(1).get_parsed_text().contains("FIRST_QUEST_STAGE"), "Journal preserves native byte colors and resolves the character-name token")
	check(await category(1) and title_present("Native completed quest") and stage_present("COMPLETED_QUEST_STAGE"), "Actual completed quest is placed in the Completed category")
	check(await category(2) and log.state.entries.is_empty(), "Native Notes category reads actual server state without fabricated entries")
	check(await category(3), "Native Messages category uses its independent server world-journal collection")
	check(await category(0), "Journal returns to active quests through private native view handles")
	check(await wait_until(func(): return explored_count() == map.board.cells.size() and pin_index() >= 0, 15), "Server exploration command reveals actual tiles and the authored waypoint map note")
	check(await wait_until(func(): return map.board.cells.all(func(index): return map.board.art.has(int(index))) and map.board.controls.values().all(func(index): return map.board.art.has(int(index))), 20), "All original installed tile artwork and normal/hover/down/player marker skins arrive")
	var pin := pin_index()
	check(pin >= 0 and map.board.pins[pin].visible, "Server-enabled map note appears only on the explored tile")
	if pin >= 0:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = map.board.center(map.board.pins[pin].point); map.board._gui_input(event)
		check(map.note.get_parsed_text() == "Native server map pin", "Actual native map pin hit testing displays its received note")
	map.set_zoom(32); check(map.board.zoom == 32, "Native map zoom redraws the same original art")
	map.position = Vector2(35, 100); log.position = Vector2(700, 110); map.move_to_front()
	check(map.get_index() > log.get_index(), "Native map and journal participate in independent window stacking")
	var before: Array = map.board.point.duplicate(); var keyboard = client.keyboard; var focus: bool = keyboard.require_focus; keyboard.require_focus = false
	keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.7).timeout; keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = focus
	check(await wait_until(func(): return map.board.point != before, 8), "Actual WASD with simultaneous map/journal windows updates the live player marker")
	# Overlap the menus to expose a world region, then use ordinary ray input.
	log.position = Vector2(35, 100)
	var world_input = client.owner_scene.world_input
	var camera: Camera3D = client.owner_scene.camera
	var begin: Vector3 = client.pivots[client.controlled_id].global_position
	var clicked := false
	for offset in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
		var screen := camera.unproject_position(begin + offset)
		if world_input.extra_pointer_block.call(screen) or client.owner_scene.native_hud.blocks_pointer(screen): continue
		var hit: Dictionary = client.owner_scene.registry.pick(camera, screen)
		if hit.is_empty() or hit.get("entity", {}).get("eligible", false): continue
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = screen
		world_input._unhandled_input(event); world_input._physics_process(0.1); clicked = true; break
	check(clicked and await wait_until(func(): return client.pivots[client.controlled_id].global_position.distance_to(begin) > 0.1, 8), "A real ray click outside both menus still requests actual server movement")
	var controller = client.owner_scene.camera_controller
	var yaw: float = controller.yaw
	var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; controller._input(middle)
	var motion := InputEventMouseMotion.new(); motion.relative = Vector2(3, 0); controller._input(motion); middle.pressed = false; controller._input(middle)
	check(controller.yaw != yaw and not controller.dragging, "Middle-button native camera rotation remains available with map and journal open")
	controller.orbit(Vector2(-3, 0)); log.position = Vector2(700, 110)
	chat("-native-records-update")
	check(await wait_until(func(): return not title_present("Native active quest") and pin_index() >= 0 and not map.board.pins[pin_index()].visible, 12), "Real server quest completion and map-pin disable are reflected live")
	check(await category(1) and title_present("Native active quest") and log.state.entries.size() == 2, "Completed category receives both actual completed server quests")
	chat("-native-records-remove")
	check(await wait_until(func(): return not title_present("Native active quest") and log.state.entries.size() == 1, 12), "Actual server quest removal deletes the native entry")
	chat("-native-records-hide")
	check(await wait_until(func(): return explored_count() < map.board.cells.size(), 12), "Native map hides tiles when actual server exploration is revoked")
	chat("-native-records-show")
	check(await wait_until(func(): return explored_count() == map.board.cells.size() and pin_index() >= 0 and map.board.pins[pin_index()].visible, 12), "Actual server reveal and map-pin reenable restore the native map")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual simultaneous map/journal frame captured for review")
	map.close_map(); log.close_journal(); check(await wait_until(func(): return map.view_id < 0 and log.view_id < 0, 10), "Native close retires map resources and sends the real journal close subscription")
	map.open(); log.open(); check(await wait_until(func(): return map.view_id >= 0 and log.view_id >= 0 and not map.board.art.is_empty(), 15), "Both windows can reopen with fresh private views and original art")
	check(map.position == Vector2(35, 100) and log.position == Vector2(700, 110), "Reopened native map and journal preserve their last positions")
	finish(message)
func finish(message: Dictionary, _item_id: int = 0) -> void:
	if valid(): client.command({"kind": "records-tested", "result": {"completed": true, "checks": checks, "explored": explored_count(), "cells": client.area_map.board.cells.size(), "pins": client.area_map.board.pins, "mapView": client.area_map.view_id, "journalView": client.journal.view_id, "journal": client.journal.state, "screenshot": message.screenshot}})
