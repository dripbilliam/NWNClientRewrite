extends SceneTree
const Identity=preload("res://systems/native_data/native_login_identity.gd")

func _initialize()->void:
	var original:=Identity.new()
	if not original.configure("A".repeat(41),"old-destination","community"):fail("Original identity unavailable");return
	var clone: RefCounted=original.for_portal("new-destination")
	if clone==null or clone==original or clone.public_key!=original.public_key or clone.key!=original.key or clone.community!=original.community or clone.password==original.password:fail("Portal identity did not clone key/community and replace destination password");return
	var challenge: Dictionary={"kind":"challenge","keyChallenge":"key","communityChallenge":"community","passwordChallenge":"password","passwordRequired":true}
	var old_proof: Dictionary=original.respond(challenge)
	var new_proof: Dictionary=clone.respond(challenge)
	if old_proof.keyResponse!=new_proof.keyResponse or old_proof.communityResponse!=new_proof.communityResponse or old_proof.passwordResponse==new_proof.passwordResponse:fail("Portal challenge proof changed key/community or retained old password");return
	original.dispose()
	if clone.respond(challenge)!=new_proof:fail("Old connection disposal invalidated destination identity");return
	clone.dispose()
	if not clone.key.is_empty() or not clone.password.is_empty() or not clone.community.is_empty() or clone.for_portal("again")!=null:fail("Portal identity retained secrets after disposal");return
	print("NWN79 Godot portal identity PASS: independent key/community clone, destination password, old/new disposal")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot portal identity failed: "+reason)
	quit(1)
