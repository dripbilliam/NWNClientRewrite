extends "res://systems/native_data/menu_definition.gd"
static func definition() -> Array:
	return [label("Save a player name and CD key together, then choose which login to use."),
		control("row","",{},[choice("profiles",[],{"size_flags_horizontal":Control.SIZE_EXPAND_FILL}),button("new_profile","New profile")]),
		label("Profile name"),control("edit","profile_label"),label("Player name"),control("edit","player_name"),label("CD key"),control("edit","cd_key"),
		label("Keys are saved with Windows protection for this Windows user.\nLeave the key blank when editing to keep the saved key."),
		control("row","",{},[button("save_profile","Save and use"),button("use_profile","Use selected"),button("delete_profile","Delete profile")]),
		control("label","notice",{"custom_minimum_size":Vector2(540,60),"autowrap_mode":TextServer.AUTOWRAP_WORD_SMART})]
