extends RefCounted
# Original8d0c90 ->CExoString16c4f0(0,0,1), Left(...,32).
# The imported original profile uses Windows1252 bytes. These permitted
# characters each occupy one byte; unrelated Unicode behavior is unverified.
const EXTRA=".',ßéÉèÈÇçùÙñÑàÀÄäÜüÖö_- "
static func sanitized(text: String) -> String:
	var result:=""
	for character in text:
		var code:=character.unicode_at(0)
		var allowed: bool=code>=65 and code<=90 or code>=97 and code<=122 or code>=48 and code<=57 or EXTRA.contains(character)
		if not allowed or result.is_empty() and character in ["."," "]: continue
		result+=character
	return result
static func confirmed(text: String) -> Dictionary:
	if text.is_empty(): return {"name":"","notice":66256,"accepted":false}
	var clean:=sanitized(text)
	if clean!=text: return {"name":clean,"notice":66104,"accepted":false}
	if clean.length()>32: return {"name":clean.left(32),"notice":66104,"accepted":false}
	return {"name":clean,"notice":0,"accepted":true}
