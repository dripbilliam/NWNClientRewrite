extends "res://systems/native_data/menu_definition.gd"
# Replacement-only Client Options: contents, not widget construction or actions.
static func definition() -> Array:
	return [control("tabs","tabs",{"custom_minimum_size":Vector2(550,480)},[
		control("scroll","graphics",{"name":"Graphics","horizontal_scroll_mode":ScrollContainer.SCROLL_MODE_DISABLED},[control("column","",{"size_flags_horizontal":Control.SIZE_EXPAND_FILL},[
			control("row","fov_row",{},[label("Vertical field of view"),control("label","fov_value",{"custom_minimum_size":Vector2(45,0)}),button("fov_reset","Original")]),
			label("Creature shadows"),choice("creature_shadow_select",[["All creatures",2],["Controlled creature",1],["Off",0]]),
			label("Shadow-casting lights"),choice("shadow_lights_select",[["1",1],["2",2],["3",3]]),
			check("wireframe_toggle","Wireframe"),
			control("row","",{},[label("Gamma (1.2 is neutral)"),control("number","gamma_control",{"min_value":0.0,"max_value":1000.0,"step":0.05,"value":2.2,"size_flags_horizontal":Control.SIZE_EXPAND_FILL})]),
			label("Match this to the original client's Gamma setting."),
			check("tile_borders_toggle","Show scenery beyond area edges"),
			label("Applies when the next area loads."),
			check("particles_toggle","Enable particles"),
			label("Turns particle simulation and drawing on or off.\nApplies immediately, including effects loaded later.\nModels, lights and gameplay are unchanged."),
			check("particle_collision_toggle","Particle collision and bouncing"),
			label("When off, particles pass through scenery."),label("Blood effects"),
			choice("gore_select",["Low","Normal","Full"]),
			check("compact_scenery_toggle","Compact scenery (experimental)"),
			label("Uses fewer scene nodes.\nApplies when the next area loads.")])]),
		control("column","diagnostics",{"name":"Performance"},[
			check("profile_toggle","Detailed frame profiling"),
			label("Profiling has overhead. Timings are saved to the session log.\nCPU spans and asynchronous GPU timings overlap."),
			check("show_blockers_toggle","Show invisible blockers (diagnostic)"),
			button("entity_inspector_button","Entity inspector…"),
			control("rich","performance",{"custom_minimum_size":Vector2(520,360),"size_flags_vertical":Control.SIZE_EXPAND_FILL})]),
		control("scroll","interface",{"name":"Interface","horizontal_scroll_mode":ScrollContainer.SCROLL_MODE_DISABLED},[control("column","",{},[
			check("creature_toggle","Show creature equipment slots"),button("login_profiles_button","Login profiles…"),button("chat_settings_button","Chat settings…"),
			check("floating_feedback_toggle","Floating combat feedback"),check("damage_totals_toggle","Show total damage only"),
			control("row","",{},[label("Camera"),choice("camera_mode_select",[["Top-down",1],["Chase",0],["Stiff chase",2]])]),
			control("row","",{},[label("Tooltip delay (ms)"),control("number","tooltip_delay_control",{"min_value":1,"max_value":5000,"step":1,"value":100,"size_flags_horizontal":Control.SIZE_EXPAND_FILL})]),
			control("row","",{},[label("Highlight double-tap (ms)"),control("number","tooltip_doubletap_control",{"min_value":0,"max_value":1000,"step":1,"value":200,"size_flags_horizontal":Control.SIZE_EXPAND_FILL,"tooltip_text":"Double-tap the highlight key to keep highlighting on. Set 0 to disable double-tap."})]),
			check("radial_group_abilities","Always group class abilities"),check("radial_group_spells","Always group spellcasting classes"),
			label("Radial submenu previews"),choice("radial_submenu_mode",["Off","Hovered branch","All branches"]),
			label("Radial action text"),choice("radial_text_mode",["Off","Hovered action","All actions"]),
			check("radial_hide_icons","Hide radial icons"),check("radial_text_in_center","Radial text in center"),check("radial_center_align_text","Center-align radial text"),
			check("radial_screen_center","Open radial at screen center"),check("radial_left_mirror","Left button mirrors right in radial menus")])])])]
