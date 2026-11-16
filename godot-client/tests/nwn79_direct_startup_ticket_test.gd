extends SceneTree
const StartupPaths=preload("res://systems/native_data/native_startup_paths.gd")
const Prework=preload("res://systems/native_data/prework_sources.gd")
const Catalog=preload("res://systems/native_data/session_catalog.gd")

func _initialize()->void:
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var ticket: Dictionary=StartupPaths.direct_ticket(install)
	if ticket.has("error"):fail(str(ticket.error));return
	var sources: Dictionary=ticket.get("preworkSources",{})
	if sources.get("install")!=install or not str(sources.get("profileDirectory","")).is_absolute_path() or not str(sources.get("cacheDirectory","")).is_absolute_path() or not str(sources.get("helper","")).is_absolute_path():fail("Godot direct startup source paths are incomplete");return
	if not ticket.get("localCharacterRoots",[]) is Array or ticket.localCharacterRoots.size()!=3:fail("Godot character roots are incomplete");return
	var discovered: Dictionary=Prework.discover(sources)
	if discovered.get("choices",[]).is_empty() or str(discovered.choices[0].label)!="Installed game + local content":fail("Godot prework cannot discover installed content");return
	var mounted: Dictionary=Catalog.prepare(discovered.choices[0].sources)
	if not str(mounted.get("error","")).is_empty():fail("Godot menu catalog failed: "+str(mounted.error));return
	if mounted.catalog.get_resource("pre_main",2047).is_empty():fail("Godot menu catalog cannot read the original main menu layout");return
	print("NWN79 Godot startup source PASS: choices=",discovered.choices.size()," layers=",mounted.catalog.layers.size()," character_roots=",ticket.localCharacterRoots.size())
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot startup source failed: "+reason)
	quit(1)
