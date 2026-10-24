extends RefCounted
var client
var prefix := ""
var observations: Array = []
var captures: Dictionary = {}
var capturing: Dictionary = {}
var recovery
func start(owner, message: Dictionary) -> void:
	client = owner; prefix = str(message.screenshot)
	client.lobby.resource_progress.connect(progress)
	if message.get("mode","") in ["cancel","failure"]:
		recovery=preload("res://tests/sync_handoff_recovery.gd").new();recovery.run(client,self,message)
func progress(value: Dictionary) -> void:
	if observations.size() < 512: observations.append(value.duplicate(true))
	var c := int(value.connection)
	if value.phase == "server-content" and value.completed > 0 and value.completed < value.total and value.downloadedBytes > 0 and not captures.has(c) and not capturing.has(c):
		capturing[c] = true; capture(c)
func capture(c: int) -> void:
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	if client.connection == c and client.lobby.download_bar.visible:
		var file := prefix + "-c" + str(c) + "-download.png"
		var saved: bool = client.get_viewport().get_texture().get_image().save_png(file) == OK
		captures[c] = {"screenshot":file if saved else "","canCancel":client.lobby.cancel_button.visible and not client.lobby.cancel_button.disabled,"playDisabled":client.lobby.play_button.disabled}
	capturing.erase(c)
func snapshot(c: int) -> Dictionary:
	return {"progress":observations.filter(func(v): return int(v.connection) == c),"capture":captures.get(c,{})}
func stop() -> void:
	if recovery!=null:recovery.stop()
	if is_instance_valid(client) and client.lobby.resource_progress.is_connected(progress): client.lobby.resource_progress.disconnect(progress)
