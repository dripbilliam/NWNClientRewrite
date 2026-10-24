extends SceneTree

const Main = preload("res://main.gd")
const Connection = preload("res://systems/local_connection.gd")
const Lobby = preload("res://systems/character_lobby.gd")
var checks: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})
	if not value:
		push_error(name)

func loading(ticket: int, area: int, generation: int) -> Dictionary:
	return {"kind": "loading", "connection": 1, "transferId": ticket, "areaId": area, "generation": generation, "text": "Authored transition"}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var host := Main.new()
	root.add_child(host)
	var bridge := Connection.new()
	host.add_child(bridge)
	bridge.set_process(false)
	bridge.owner_scene = host
	bridge._make_ui()
	bridge.lobby = Lobby.new()
	bridge.add_child(bridge.lobby)
	bridge.receive({"kind": "lobby", "connection": 1, "state": {"phase": "menu"}})
	var first := loading(1, 5, 1)
	bridge.receive(first)
	check(bridge.world_scope.matches(first) and not bridge.world_scope.admitted, "first loading establishes expected native scope")
	check(bridge.world_scope.admit(first), "matching initial package can be admitted")
	var refs: Array = []
	for field in ["world_input", "camera_controller", "native_hud", "registry", "room_owner", "environment_owner"]:
		var owned := Node3D.new()
		host.add_child(owned)
		host.set(field, owned)
		refs.append(weakref(owned))
	bridge.pivots[17] = Node3D.new()
	host.registry.add_child(bridge.pivots[17])
	bridge.targets[17] = Transform3D.IDENTITY
	bridge.model_rigs = Node.new()
	host.registry.add_child(bridge.model_rigs)
	bridge.following = true
	var second := loading(2, 6, 2)
	bridge.receive(second)
	check(not bridge.world_scope.admitted and bridge.world_scope.matches(second), "new area immediately revokes old admission")
	check(host.registry == null and bridge.pivots.is_empty() and bridge.targets.is_empty() and bridge.model_rigs == null and not bridge.following, "loading clears native world state and animation ownership")
	await process_frame
	await process_frame
	check(refs.all(func(reference): return reference.get_ref() == null), "all six old native owners are actually released")
	var installed := Node3D.new()
	host.add_child(installed)
	host.registry = installed
	bridge.receive(first)
	check(host.registry == installed and bridge.world_scope.matches(second), "late old loading cannot clear the new world")
	bridge.receive(second)
	check(host.registry == installed, "duplicate loading does not repeatedly clear the native room")
	var stale_area := first.duplicate()
	stale_area.kind = "area"
	stale_area.scene = "/absent/old-world.glb"
	bridge.receive(stale_area)
	check(host.registry == installed and bridge.world_scope.matches(second), "retired area payload is discarded before file access")
	var stale_pose := first.duplicate()
	stale_pose.kind = "poses"
	stale_pose.poses = [{"id": 17, "position": [1, 2, 3], "rotation": 0}]
	bridge.receive(stale_pose)
	check(bridge.targets.is_empty(), "old pose packets cannot restore retired objects")
	check(not bridge.world_scope.admit(first), "old package cannot re-admit after an area switch")
	var returned := loading(3, 5, 3)
	bridge.receive(returned)
	check(bridge.world_scope.matches(returned) and not bridge.world_scope.matches(first), "returning to the same area uses a distinct scope")
	bridge.receive({"kind": "loading", "connection": 1, "text": "Disconnected"})
	check(bridge.world_scope.expected.is_empty(), "disconnect invalidates pending admission")
	bridge.receive(stale_area)
	check(host.registry == null, "a late area cannot resurrect a disconnected world")
	bridge.receive({"kind": "lobby", "connection": 3, "state": {"phase": "menu"}})
	check(bridge.connection == 3 and bridge.world_scope.connection == 3, "new connection resets native scope ownership")
	bridge.receive(returned)
	check(bridge.world_scope.expected.is_empty(), "previous connection's loading is ignored")
	var rejoin := loading(4, 5, 1)
	rejoin.connection = 3
	bridge.receive(rejoin)
	check(bridge.world_scope.matches(rejoin), "same area and reset generation can be admitted after reconnect")
	bridge.motion.ensure(1, {"position": [1, 2, 0], "animation": 4})
	bridge.connected_once = true
	bridge._process(0.016)
	check(bridge.world_scope.expected.is_empty() and bridge.motion.objects.is_empty() and not bridge.connected_once, "transport loss clears prediction and native world admission")
	host.free()
	var failed := checks.filter(func(row): return not row.passed).size()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Authored native message admission and actual owner cleanup; not server transition or performance acceptance", "passed": checks.size() - failed, "failed": failed, "checks": checks}, "  "))
	file.close()
	print(JSON.stringify({"passed": checks.size() - failed, "failed": failed, "report": output}))
	quit(0 if failed == 0 else 1)
