extends "res://native_live_world.gd"
const OriginalCatalog=preload("res://systems/native_data/resource_catalog.gd")

func _initialize()->void:
	call_deferred("check_handoff")

func check_handoff()->void:
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var prepared:=OriginalCatalog.new()
	if not prepared.mount_install(install) or not prepared.mount_erf(install.path_join("data/nwm/Prelude.nwm"),100000000):fail_check("Original installed catalog unavailable");return
	host=Node3D.new();root.add_child(host)
	loading_screen=preload("res://systems/native_loading_screen.gd").new();host.add_child(loading_screen)
	var sources: Dictionary={"install":install,"archives":[{"path":install.path_join("data/nwm/Prelude.nwm"),"priority":100000000}]}
	if not install_mounted_catalog(prepared,install,sources):fail_check("Godot catalog handoff was rejected");return
	if not initialized or not is_instance_valid(gameplay_ui) or not is_same(catalog,prepared) or not is_same(gameplay_ui.catalog,prepared) or gameplay_ui.get_parent()!=host or loading_screen.ui!=gameplay_ui:
		fail_check("Renderer and UI did not share the admitted catalog");return
	if install_mounted_catalog(prepared,install,sources):fail_check("Duplicate direct catalog handoff was accepted");return
	print("NWN79 direct catalog handoff PASS: layers=",prepared.layers.size()," node_host=false")
	gameplay_ui.close();prepared.release_ui_assets();host.queue_free()
	quit(0)

func fail_check(reason: String)->void:
	printerr("NWN79 direct catalog handoff failed: "+reason)
	if is_instance_valid(gameplay_ui):gameplay_ui.close()
	if is_instance_valid(host):host.queue_free()
	quit(1)
