extends RefCounted

var connection := 0
var ticket := -1
var expected: Dictionary = {}
var admitted := false

func reset(next_connection: int) -> void:
	connection = next_connection
	ticket = -1
	invalidate()

func invalidate() -> void:
	expected.clear()
	admitted = false

func begin(message: Dictionary) -> bool:
	if int(message.get("connection", -1)) != connection or int(message.get("transferId", -1)) <= ticket:
		return false
	if int(message.get("areaId", -1)) < 0 or int(message.get("generation", -1)) < 0:
		return false
	ticket = int(message.transferId)
	expected = {"connection": connection, "transferId": ticket, "areaId": int(message.areaId), "generation": int(message.generation)}
	admitted = false
	return true

func matches(message: Dictionary) -> bool:
	if expected.is_empty():
		return false
	for key in expected:
		if int(message.get(key, -1)) != expected[key]:
			return false
	return true

func admit(message: Dictionary) -> bool:
	if not matches(message):
		return false
	admitted = true
	return true
