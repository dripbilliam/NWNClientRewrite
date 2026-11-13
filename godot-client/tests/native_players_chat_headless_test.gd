extends "res://tests/native_players_ui_test.gd"
func players_settled(ui) -> bool:
	var skin=ui.desktop.players_frame
	return ui.chat_skin.layout_ready and skin.layout_ready and skin.popup.layout_ready and skin.jobs.is_empty() and skin.failure.is_empty()
func shot(_output: String,_suffix: String) -> void:
	# Source geometry and actual controls/input only; no pixel acceptance.
	await process_frame
