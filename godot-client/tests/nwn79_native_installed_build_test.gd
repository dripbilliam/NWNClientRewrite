extends SceneTree
const Build=preload("res://systems/native_data/native_installed_network_build.gd")
const CryptoOwner=preload("res://systems/native_data/native_network_crypto.gd")
func _initialize()->void:
	var crypto=CryptoOwner.new()
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/nwn-network-crypto.exe")
	if not crypto.open(helper):fail("crypto helper");return
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var value: Dictionary=Build.read(install,crypto)
	crypto.close()
	if value.has("error") or value.platformId!=2 or value.platformIdentifier.length()!=72 or value.build.number<=0 or value.build.commit.length()!=8:fail(str(value.get("error","build fields")));return
	print("NWN79 Godot installed build identity PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot installed build identity failed: "+stage)
	quit(1)
