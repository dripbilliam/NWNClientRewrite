extends SceneTree
const Text=preload("res://systems/native_data/native_gff_text.gd")
const Identity=preload("res://systems/native_data/native_login_identity.gd")
func _initialize()->void:
	var sample: String="A€"+char(0x81)+"ÿ"
	var encoded: Dictionary=Text.encode(sample)
	if not encoded.has("bytes") or encoded.bytes!=PackedByteArray([65,128,129,255]) or Text.decode(encoded.bytes)!=sample:fail("Western text");return
	if Identity.digest(["abc".to_ascii_buffer()])!="900150983cd24fb0d6963f7d28e17f72":fail("MD5");return
	if Identity.digest([PackedByteArray()])!="d41d8cd98f00b204e9800998ecf8427e":fail("empty MD5");return
	var owner=Identity.new()
	if not owner.configure("A".repeat(41),"password","community") or owner.public_key!="AAAAAAAA":fail("public key");return
	var result: Dictionary=owner.respond({"kind":"challenge","keyChallenge":"key","communityChallenge":"community","passwordChallenge":"password","passwordRequired":true})
	if result.has("error") or result.keyResponse.length()!=40 or result.communityResponse.length()!=32 or result.passwordResponse.length()!=32 or result.connectionError!=0:fail("challenge");return
	var blank=Identity.new();blank.configure("A".repeat(41))
	var blank_proof: Dictionary=blank.respond({"kind":"challenge","keyChallenge":"abc","communityChallenge":"abc","passwordRequired":false})
	if blank_proof.communityResponse!="1606f8325d4f4fd10bf8fc797134d59e":fail("empty community challenge");return
	blank.dispose()
	var fixture: String=ProjectSettings.globalize_path("res://../backups/animations/native-network-login-identity-observations.json")
	var file:=FileAccess.open(fixture,FileAccess.READ)
	if file==null:fail("native fixture unavailable");return
	var native: Dictionary=JSON.parse_string(file.get_as_text());file.close()
	if native.md5.size()!=21 or native.publicKeys.size()!=6 or native.community.size()!=5:fail("native fixture shape");return
	for row in native.md5:
		if Identity.digest([str(row.input).hex_decode()])!=row.digest:fail("native MD5 parity");return
	var skipped_nul_key:=0
	for row in native.publicKeys:
		if str(row.key).contains("�"):
			skipped_nul_key+=1
			continue
		if Identity.public_cd_key(str(row.key))!=row.public:fail("native public key parity");return
	if skipped_nul_key!=1:fail("NUL key fixture accounting");return
	var skipped_nul_password:=0
	for row in native.community:
		if str(row.password).contains("�"):
			skipped_nul_password+=1
			continue
		var candidate=Identity.new()
		if not candidate.configure("ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-ZABCD-EFGHI","",str(row.password)):fail("native community setup");return
		var proof: Dictionary=candidate.respond({"kind":"challenge","passwordRequired":false,"passwordChallenge":"","keyChallenge":"key-salt","communityChallenge":str(row.challenge)})
		candidate.dispose()
		if proof.get("communityResponse","")!=row.response:fail("native community parity");return
	if skipped_nul_password!=1:fail("NUL password fixture accounting");return
	owner.dispose()
	if not owner.key.is_empty() or not owner.password.is_empty() or not owner.respond({"kind":"challenge"}).has("error"):fail("disposal");return
	print("NWN79 Godot login identity PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot login identity failed: "+stage)
	quit(1)
