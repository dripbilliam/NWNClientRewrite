extends RefCounted
const Text=preload("res://systems/native_data/native_gff_text.gd")
var key:=PackedByteArray()
var password:=PackedByteArray()
var community:=PackedByteArray()
var public_key: String=""
var disposed:=false

static func public_cd_key(value: String)->String:
	if value.length()!=41:return ""
	for offset in range(value.length()):
		if value.unicode_at(offset)==0:return ""
	var stage:=0;var material:=0;var public_part:="";var check:=0;var index:=0
	while index<41:
		var character:=value[index]
		if character=="-":index+=1;continue
		if stage==0:
			stage=1
			if material<=19:material+=1;index+=1;continue
		if stage==1:
			stage=2
			if material>12 and check<7:check+=1;index+=1;continue
		elif stage!=2:index+=1;continue
		stage=0
		if public_part.length()<8:public_part+=character;index+=1
		elif material>=20 and check>=7:index+=1
	return public_part

func configure(cd_key: String,server_password: String="",community_password: String="")->bool:
	if disposed or not key.is_empty():return false
	public_key=public_cd_key(cd_key.to_upper())
	if public_key.length()!=8:return false
	var encoded_key: Dictionary=Text.encode(cd_key.to_upper())
	var encoded_password: Dictionary=Text.encode(server_password)
	var encoded_community: Dictionary=Text.encode(community_password)
	if not encoded_key.has("bytes") or not encoded_password.has("bytes") or not encoded_community.has("bytes"):return false
	key=encoded_key.bytes;password=encoded_password.bytes;community=encoded_community.bytes
	return true

static func digest(parts: Array[PackedByteArray])->String:
	var context:=HashingContext.new()
	if context.start(HashingContext.HASH_MD5)!=OK:return ""
	for part in parts:
		if part.is_empty():continue
		if context.update(part)!=OK:return ""
	return context.finish().hex_encode()

func respond(challenge: Dictionary)->Dictionary:
	if disposed or key.is_empty() or challenge.get("kind","")!="challenge":return {"error":"Native login challenge is unavailable"}
	# The former encoded() provider rejected missing or non-string challenge
	# fields rather than hashing a coerced value into a valid-looking proof.
	for field in ["keyChallenge","communityChallenge"]:
		if not challenge.get(field) is String:return {"error":"Native login text is unavailable"}
	var key_challenge: Dictionary=Text.encode(challenge.keyChallenge)
	var community_challenge: Dictionary=Text.encode(challenge.communityChallenge)
	if not key_challenge.has("bytes") or not community_challenge.has("bytes"):return {"error":"NWN login text encoding is unsupported"}
	var password_challenge: Dictionary={}
	if challenge.get("passwordRequired",false) and not password.is_empty():
		if not challenge.get("passwordChallenge") is String:return {"error":"Native login text is unavailable"}
		password_challenge=Text.encode(challenge.passwordChallenge)
		if not password_challenge.has("bytes"):return {"error":"NWN login text encoding is unsupported"}
	var community_digest:=digest([community]).to_ascii_buffer()
	var proof={"keyResponse":public_key+digest([key,key_challenge.bytes]),"communityResponse":digest([community_digest,community_challenge.bytes]),"passwordResponse":"","connectionError":3 if challenge.get("passwordRequired",false) and password.is_empty() else 0}
	if challenge.get("passwordRequired",false) and not password.is_empty():proof.passwordResponse=digest([password,password_challenge.bytes])
	community_digest.fill(0)
	if proof.keyResponse.length()!=40 or proof.communityResponse.length()!=32 or challenge.get("passwordRequired",false) and not password.is_empty() and proof.passwordResponse.length()!=32:return {"error":"NWN login digest is unavailable"}
	return proof

func for_portal(server_password: String)->RefCounted:
	if disposed or key.is_empty():return null
	var encoded: Dictionary=Text.encode(server_password)
	if encoded.has("error"):return null
	var next: RefCounted=get_script().new()
	next.key=key.duplicate()
	next.password=encoded.bytes
	next.community=community.duplicate()
	next.public_key=public_key
	return next

func dispose()->void:
	if disposed:return
	key.fill(0);password.fill(0);community.fill(0)
	key=PackedByteArray();password=PackedByteArray();community=PackedByteArray();public_key="";disposed=true
