extends SceneTree
const Map = preload("res://systems/server_map.gd")
const Journal = preload("res://systems/server_journal.gd")
const Connection = preload("res://systems/local_connection.gd")
var failures: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	root.size = Vector2i(1440, 960)
	var map := Map.new(); map.setup(""); root.add_child(map)
	var journal := Journal.new(); journal.setup(""); root.add_child(journal)
	var sent: Array = []; map.request.connect(func(row): sent.append(row)); journal.request.connect(func(row): sent.append(row))
	map.open(); check(map.visible and sent.back().kind == "map-open", "Map opens through the native owner")
	map.receive({"kind": "map-view", "viewId": 2, "width": 2, "height": 2, "cells": [0, 0, 0, 0], "controls": {"pin": 1, "player": 2, "hilite": 1, "down": 1}})
	map.receive({"kind": "map-state", "viewId": 2, "explored": [true, false, true, false], "pins": [{"visible": true, "point": [0, 0, 0], "rich": {"text": "Authored pin"}}]})
	map.receive({"kind": "map-pose", "viewId": 2, "point": [0.01, 0.02, 0], "heading": 45})
	await process_frame
	check(map.board.explored == [true, false, true, false] and map.board.point[0] == 0.01, "Only supplied exploration and original projected player coordinates enter native drawing")
	var old: Array = map.board.point.duplicate(); map.receive({"kind": "map-pose", "viewId": 1, "point": [2, 3, 0], "heading": 0})
	check(map.board.point == old, "Old map poses cannot mutate reopened content")
	map.board.pin_selected.emit({"text": "Authored pin"}); check(map.note.get_parsed_text() == "Authored pin", "Map pin selection displays its supplied note")
	map.set_zoom(32); check(map.board.zoom == 32 and map.board.custom_minimum_size == Vector2(64, 64), "Native zoom scales installed art coordinates")
	map.position = Vector2(50, 60); map.close_map(); map.open(); check(map.position == Vector2(50, 60), "Map reopens in its last window position")
	journal.open(); check(journal.visible and map.visible and sent.back().kind == "journal-open", "Journal and map are independent simultaneous native windows")
	journal.receive({"kind": "journal-view", "viewId": 3, "page": 0, "loaded": true, "entries": [{"title": {"text": "Quest"}, "description": {"spans": [{"text": "Color", "color": "#00ff00"}]}}]})
	check(journal.body.get_child(0).get_parsed_text() == "Quest" and journal.body.get_child(1).get_parsed_text() == "Color", "Journal displays literal rich server title/description")
	journal.tabs[3].pressed.emit(); check(sent.back().kind == "journal-page" and sent.back().page == 3 and sent.back().viewId == 3, "Category navigation carries a scoped private handle")
	journal.receive({"kind": "journal-view", "viewId": 4, "page": 3, "loaded": true, "entries": []}); check(journal.body.get_child(0).get_parsed_text() == "No entries in this category.", "Loaded empty categories remain distinct from waiting")
	map.reset(); journal.reset(); check(map.board.art.is_empty() and not map.visible and not journal.visible and journal.view_id == -1, "World retirement clears native map art, entries and private views")
	map.free(); journal.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}, "\t")); file.close(); quit(0 if failures.is_empty() else 1)
