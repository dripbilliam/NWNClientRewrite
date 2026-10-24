extends "res://systems/inventory_probe.gd"

var chest_id := -1

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	for id in client.owner_scene.registry.entities:
		var row: Dictionary = client.owner_scene.registry.entities[id]
		if int(row.get("type", 0)) == 9 and str(row.get("name", "")).contains("container chest"): chest_id = int(id); break
	check(chest_id >= 0, "Authored chest is an actual native replicated interactable")
	if chest_id < 0: finish(message, 0); return
	check(client.source_eligibility.get(chest_id, false) and client.targets.has(chest_id), "Real chest is eligible for native world interaction and highlighting")
	client.command({"kind": "chat", "channel": 1, "text": "-native-chest"})
	check(await wait_until(func(): return client.chat_ui.system_messages.get_parsed_text().contains("GODOT_CONTAINER_READY"), 10), "Real server script creates chest items from installed template references")
	client.command({"kind": "interact", "targetId": chest_id})
	var panel = client.inventory
	check(await wait_until(func(): return panel.visible and panel.wanted and int(panel.state.get("container", {}).get("ownerId", -1)) == chest_id and panel.items.values().any(func(row): return row.channel == "C"), 15), "Actual chest use/status automatically opens native container inventory")
	if not valid(): return
	var count := int(panel.state.get("container", {}).get("pageCount", 1))
	check(count > 1, "Actual server exposes multiple populated container pages")
	if count <= 1: finish(message, 0); return
	panel.container_controls.next.pressed.emit()
	check(await wait_until(func(): return int(panel.state.get("container", {}).get("page", -1)) == 1 and panel.items.values().any(func(row): return row.channel == "C" and int(row.y) >= 5 and int(row.y) < 10), 10), "Native Next requests and displays a real second chest page")
	panel.container_controls.previous.pressed.emit()
	check(await wait_until(func(): return int(panel.state.get("container", {}).get("page", -1)) == 0 and panel.items.values().any(func(row): return row.channel == "C" and int(row.y) < 5), 10), "Native Previous restores the first authoritative chest page")
	if not valid(): return
	var stored: Array = panel.items.values().filter(func(row): return row.channel == "C" and int(row.y) < 5)
	if stored.is_empty(): check(false, "Chest contains a transferable real item"); finish(message, 0); return
	var source: Dictionary = stored[0]
	var id := int(source.itemId)
	var original_cell := Vector2i(int(source.x), int(source.y))
	var old_view: int = panel.view_id
	panel.pages[5].pressed.emit()
	check(await wait_until(func(): return panel.view_id != old_view and int(panel.state.get("page", -1)) == 5, 10), "Player backpack paging remains independent of the open container")
	source = item(id, "C")
	if source.is_empty(): check(false, "Container item remains available across player page changes"); finish(message, id); return
	panel.operation(int(source.entryId), "move", {"destination": "backpack", "x": 0, "y": 30})
	check(await wait_until(func(): var row := item(id, "R"); return not row.is_empty() and int(row.y) == 30 and not row.pending, 15), "Real move acknowledgement and replicated ownership confirm chest-to-player transfer")
	if not valid(): return
	var carried := item(id, "R")
	if carried.is_empty(): check(false, "Transferred item is visible for returning"); finish(message, id); return
	var drag := {"kind": "native-inventory-item", "viewId": panel.view_id, "entryId": int(carried.entryId)}
	panel.container_repository.drop_global(drag, panel.container_repository.global_position + Vector2(original_cell.x * 40 + 10, original_cell.y * 40 + 10))
	check(await wait_until(func(): var row := item(id, "C"); return not row.is_empty() and int(row.x) == original_cell.x and int(row.y) == original_cell.y and not row.pending, 15), "Native drop returns the same real item to the chest with server-confirmed ownership")
	var stale_drag := {"kind": "native-inventory-item", "viewId": panel.view_id, "entryId": int(item(id, "C").get("entryId", -1))}
	var serial := int(panel.state.container.serial)
	panel.container_controls.close.pressed.emit()
	check(await wait_until(func(): return not panel.container_box.visible and int(panel.state.container.ownerId) == 2130706432, 10), "Closing the real container restores native equipment/backpack presentation")
	check(not panel.can_drop(stale_drag, 0), "A closed-container drag cannot act in the replacement equipment view")
	client.command({"kind": "interact", "targetId": chest_id})
	check(await wait_until(func(): return int(panel.state.container.ownerId) == chest_id and int(panel.state.container.serial) > serial and not item(id, "C").is_empty(), 15), "Reopening the same real chest creates a new native container context")
	check(not panel.can_drop(stale_drag, 0), "Reused chest/item IDs do not revive old drag identities")
	check(await wait_until(func(): return panel.items.values().filter(func(row): return row.channel == "C" and int(row.y) < 5).all(func(row): return panel.buttons.has(int(row.entryId)) and panel.buttons[int(row.entryId)].image.texture != null), 10), "All visible real chest clothing icons render through their original palette layers")
	panel.position = Vector2(25, 85)
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual native chest/backpack/original item-icon frame captured")
	finish(message, id)

func finish(message: Dictionary, id: int) -> void:
	if valid(): client.command({"kind": "container-tested", "result": {"completed": true, "checks": checks, "chestId": chest_id, "itemId": id, "pageCount": client.inventory.state.get("container", {}).get("pageCount", 0), "screenshot": message.screenshot}})
