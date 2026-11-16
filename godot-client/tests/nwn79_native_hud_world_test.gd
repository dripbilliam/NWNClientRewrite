extends SceneTree
const World=preload("res://systems/native_data/native_network_world.gd")
const Hud=preload("res://systems/native_data/native_network_hud.gd")
const Visuals=preload("res://systems/native_data/native_network_area_visuals.gd")

func _initialize()->void:
	var world:=World.new();world.module={"minutesPerHour":5}
	var area_id:=0x80000010
	if not world.apply_area({"area":{"id":area_id,"mapPins":[],"sounds":[],"placeableLights":[],"staticPlaceables":[]},"position":[0,0,0],"facing":0,"loadingScreen":"","flag":0}):fail("Current area fixture failed");return
	var hud: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_hud_messages_fixture.json")))
	var visuals: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_area_visuals_fixture.json")))
	if not hud is Dictionary or not visuals is Dictionary:fail("Original-format HUD fixtures unavailable");return
	for name in ["journal-world-literal","journal-quest-entry","journal-notice","timing-on","attitude-own","map-pin-created-literal","map-pin-added"]:
		var row: Dictionary=case_named(hud.cases,name)
		if row.is_empty():fail("Missing HUD fixture "+name);return
		var decoded: Dictionary=Hud.decode_packet(str(row.packet).hex_decode())
		if decoded.has("error") or not world.apply_hud(decoded):fail("HUD state rejected "+name);return
	for name in ["weather-1-1","wind-1"]:
		var row: Dictionary=case_named(visuals.cases,name)
		if row.is_empty():fail("Missing area visual fixture "+name);return
		var decoded: Dictionary=Visuals.decode_packet(str(row.packet).hex_decode())
		if decoded.has("error") or not world.apply_area_visual(decoded):fail("Area state rejected "+name);return
	var snapshot: Dictionary=world.presentation(true)
	if snapshot.has("error") or snapshot.ui.journal.entries.size()!=1 or snapshot.ui.journal.worldEntries.size()!=1 or not snapshot.ui.journal.has("notification") or snapshot.ui.mapPins.size()!=1 or snapshot.ui.playerAttitudes.size()!=1 or snapshot.ui.timing.version!=1:fail("HUD presentation omitted decoded state");return
	if snapshot.area.weather!={"type":1,"enabled":1} or world.registry[area_id].state.weather!=snapshot.area.weather or int(snapshot.area.fields.e4)!=3 or world.registry[area_id].state.fields!=snapshot.area.fields or snapshot.area.playerMapPins.size()!=1:fail("Current-area weather, wind or map pin diverged");return
	if world.apply_area_visual({"kind":"area-weather","weather":{"type":256,"enabled":1}}):fail("Invalid area weather admitted");return
	world.registry[area_id].replicationRemoved=true
	if world.apply_area_visual({"kind":"area-weather","weather":{"type":1,"enabled":1}}):fail("Retired area accepted weather");return
	print("NWN79 Godot HUD world PASS: journal, timing, attitude, map pin, weather, wind, valid-area gate")
	quit(0)

func case_named(rows: Array,name: String)->Dictionary:
	for row in rows:
		if str(row.get("name",""))==name:return row
	return {}

func fail(reason: String)->void:
	printerr("NWN79 Godot HUD world failed: "+reason)
	quit(1)
