extends "res://systems/native_data/menu_definition.gd"
# Replacement-only Client Options: contents, not widget construction or actions.
static func definition() -> Array:
	return [control("tabs","tabs",{"custom_minimum_size":Vector2(550,480)},[
		control("column","graphics",{"name":"Graphics"},[
			check("particles_toggle","Enable particles"),
			label("Turns particle simulation and drawing on or off.\nApplies immediately, including effects loaded later.\nModels, lights and gameplay are unchanged."),
			check("particle_collision_toggle","Particle collision and bouncing"),
			label("When off, particles pass through scenery."),label("Blood effects"),
			choice("gore_select",["Low","Normal","Full"]),
			check("compact_scenery_toggle","Compact scenery (experimental)"),
			label("Uses fewer scene nodes.\nApplies when the next area loads.")]),
		control("column","diagnostics",{"name":"Performance"},[
			check("profile_toggle","Detailed frame profiling"),
			label("Profiling has overhead. Timings are saved to the session log.\nCPU spans and asynchronous GPU timings overlap."),
			button("entity_inspector_button","Entity inspector…"),
			control("rich","performance",{"custom_minimum_size":Vector2(520,360),"size_flags_vertical":Control.SIZE_EXPAND_FILL})]),
		control("column","interface",{"name":"Interface"},[check("creature_toggle","Show creature equipment slots"),button("login_profiles_button","Login profiles…")]),
		control("column","prework",{"name":"Prework"},[
			label("Prepare installed or downloaded content before joining.\nSave processed models and opened UI artwork for later sessions.\nMore workers use more CPU, memory and disk bandwidth."),
			choice("prework_content",["Finding local content…"],{"disabled":true}),
			choice("prework_scope",["Current session appearances","All available models + current appearances"]),
			control("row","",{},[label("Workers"),choice("prework_workers",[["Automatic (up to 4)",0],["1",1],["2",2],["4",4],["8",8]],{"size_flags_horizontal":Control.SIZE_EXPAND_FILL})]),
			button("prework_prepare","Prepare assets",true),button("prework_cancel","Cancel preparation",true),
			control("progress","prework_progress",{"show_percentage":false}),
			control("scroll","",{"custom_minimum_size":Vector2(0,132),"horizontal_scroll_mode":ScrollContainer.SCROLL_MODE_DISABLED},[
				control("label","prework_status",{"text":"Finding installed and downloaded content…","size_flags_horizontal":Control.SIZE_EXPAND_FILL,"autowrap_mode":TextServer.AUTOWRAP_WORD_SMART})]),
			control("row","",{},[button("prework_clear","Clear saved prework"),button("prework_folder","View saved files")]),
			label("Clears generated model bundles and saved UI images.\nGame files and server downloads are kept.\nAssets already loaded stay available until the session ends.")]),
		control("column","ui_preload",{"name":"UI preload"},[
			label("Prepare menu artwork and fonts before opening menus.\nIncludes unopened menus in the selected local content.\nSaved artwork is reused on later launches."),
			choice("ui_preload_content",["Finding local content…"],{"disabled":true}),
			button("ui_preload_prepare","Preload all menus",true),button("ui_preload_cancel","Cancel UI preload",true),
			control("progress","ui_preload_progress",{"custom_minimum_size":Vector2(0,22)}),
			control("scroll","",{"custom_minimum_size":Vector2(520,240),"horizontal_scroll_mode":ScrollContainer.SCROLL_MODE_DISABLED,"size_flags_vertical":Control.SIZE_EXPAND_FILL},[
				control("label","ui_preload_status",{"text":"Choose local content, then preload its menus.","size_flags_horizontal":Control.SIZE_EXPAND_FILL,"autowrap_mode":TextServer.AUTOWRAP_WORD_SMART})]),
			label("Separate from model/world preparation. No server connection needed.\nLive contents and variable-size layouts still update when opened.\nClear saved prework in the Prework tab to remove saved artwork.",true)])])]
