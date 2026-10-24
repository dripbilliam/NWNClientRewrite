extends RefCounted
# NUI-only JSON fragmentation. Ordinary bridge and particle limits stay intact.
const FRAME_BYTES := 60000
const PAYLOAD_BYTES := 16 * 1024 * 1024
const PART_CHARS := 48000
var pending: Dictionary = {}
var serial := 0
var failure := ""
func reset() -> void: pending.clear(); failure = ""
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func encode(value: Dictionary) -> Array:
	var bytes := JSON.stringify(value).to_utf8_buffer()
	if bytes.size() < FRAME_BYTES: return [value]
	if bytes.size() > PAYLOAD_BYTES or value.get("kind") != "nui-input" or value.get("operation") == "fragment":
		failure = "NUI input exceeds fragmented transport capacity"; return []
	serial += 1
	var data := Marshalls.raw_to_base64(bytes); var count := ceili(float(data.length()) / PART_CHARS)
	var base := {"kind":"nui-input","operation":"fragment","connection":value.connection,"windowId":value.windowId,"transferId":serial}
	var frames: Array = [base.merged({"phase":"begin","bytes":bytes.size(),"parts":count,"sha256":digest(bytes)})]
	for part in count: frames.append(base.merged({"phase":"part","part":part,"data":data.substr(part * PART_CHARS, PART_CHARS)}))
	frames.append(base.merged({"phase":"end"})); return frames
func reject(reason: String) -> Variant:
	pending.clear(); failure = reason; return null
func integer(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 9007199254740991.0 and float(value) == floor(float(value))
func receive(message: Dictionary) -> Variant:
	failure = ""
	if not integer(message.get("connection")) or not integer(message.get("transferId")): return reject("Invalid NUI JSON owner")
	match str(message.get("kind")):
		"nui-json-begin":
			if not pending.is_empty() or not integer(message.get("bytes")) or int(message.bytes) > PAYLOAD_BYTES or not integer(message.get("parts")) or int(message.parts) < 1 or int(message.parts) > ceili(float(PAYLOAD_BYTES) * 4 / 3 / PART_CHARS): return reject("Invalid NUI JSON size")
			if not message.get("sha256") is String or message.sha256.length() != 64 or not message.sha256.is_valid_hex_number(false): return reject("Invalid NUI JSON digest")
			pending = {"message":message.duplicate(true),"parts":[],"characters":0}; return null
		"nui-json-part", "nui-json-end":
			if pending.is_empty() or int(message.transferId) != int(pending.message.transferId) or int(message.connection) != int(pending.message.connection): return reject("Unknown NUI JSON transfer")
			if message.kind == "nui-json-part":
				if not integer(message.get("part")) or int(message.part) != pending.parts.size() or pending.parts.size() >= int(pending.message.parts) or not message.get("data") is String or message.data.length() > PART_CHARS or pending.characters + message.data.length() > ceili(float(pending.message.bytes) / 3) * 4: return reject("Invalid NUI JSON sequence")
				pending.parts.append(message.data); pending.characters += message.data.length(); return null
			var transfer := pending; pending = {}
			if transfer.parts.size() != int(transfer.message.parts): return reject("Truncated NUI JSON transfer")
			var bytes := Marshalls.base64_to_raw("".join(transfer.parts))
			if bytes.size() != int(transfer.message.bytes) or digest(bytes) != transfer.message.sha256: return reject("NUI JSON digest mismatch")
			var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if not value is Dictionary or value.get("kind") not in ["nui-frame","nui-nodes","nui-skin","nui-notice"] or int(value.get("connection", -1)) != int(transfer.message.connection): return reject("Invalid reconstructed NUI JSON owner")
			return value
	return reject("Unknown NUI JSON fragment")
