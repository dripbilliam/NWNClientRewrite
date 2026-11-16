extends SceneTree
const CryptoOwner=preload("res://systems/native_data/native_network_crypto.gd")
func _initialize()->void:
	var binary:=ProjectSettings.globalize_path("res://../tooling/native/nwn-network-crypto.exe")
	var crypto=CryptoOwner.new()
	if not crypto.open(binary):printerr("NWN79 Godot crypto helper unavailable");quit(1);return
	var id: int=crypto.application_id()
	var first: Dictionary=crypto.start()
	var key:=PackedByteArray();key.resize(32);key.fill(7)
	var platform: Dictionary=crypto.platform_identity(4,key)
	key.fill(0)
	var invalid: Dictionary=crypto.finish(PackedByteArray())
	var ok: bool=id>=0 and first.has("bytes") and first.bytes.size()==32 and platform.has("identity") and platform.identity.length()==72 and invalid.has("error") and crypto.phase==1 and crypto.reset() and crypto.phase==0
	if first.has("bytes"):first.bytes.fill(0)
	crypto.close()
	if not ok:printerr("NWN79 Godot crypto protocol failed");quit(1);return
	print("NWN79 Godot crypto protocol PASS")
	quit(0)
