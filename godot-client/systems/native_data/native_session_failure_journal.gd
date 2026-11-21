extends RefCounted

const TERMINAL_CODES := [
	"network.object-import-failed", "network.game-session-failed", "network.peer-failed",
	"network.message-decompression-failed", "network.server-disconnected",
	"network.connect-failed", "network.session-connect-failed",
]
const CONNECT_CODES := ["network.connect-failed", "network.session-connect-failed"]
const SAFE_INTEGER := 9007199254740991
const TEXT_LIMIT := 384

var _report: Dictionary
var _path: String
var _limit := 0
var _recent: Dictionary = {}
var _pending: Array[String] = []
var _scheduled := false
var _key_pattern := RegEx.create_from_string("(?<![A-Za-z0-9_])[A-Za-z0-9]{5}(?:-[A-Za-z0-9]{5}){6}(?![A-Za-z0-9_])")
var _controls := RegEx.create_from_string("[\\x00-\\x1f\\x7f]")

func _init(report: Dictionary, report_path: String, limit: int = 64) -> void:
	if report_path.is_empty() or limit < 1 or limit > 256:
		return
	_report = report
	_path = report_path.trim_suffix(".json") + ".connection.jsonl"
	_limit = limit

func _text(value: Variant) -> String:
	if not value is String:
		return ""
	var clean := _controls.sub(_key_pattern.sub(value, "[protected key]", true), " ", true)
	var units := 0
	for index in clean.length():
		units += 2 if clean.unicode_at(index) > 0xffff else 1
		if units > TEXT_LIMIT:
			return clean.left(index)
	return clean

func _failure(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["stage", "name", "code", "reason"]:
		if value.get(key) is String:
			result[key] = _text(value[key])
	return result

func _client_failure(value: Dictionary) -> Dictionary:
	var cause: Variant = value.get("cause")
	var fields: Dictionary = cause if cause is Dictionary else {}
	return {
		"code": _text(value.get("code")),
		"reason": _text(value.get("reason")),
		"cause": {"code": _text(fields.get("code")), "reason": _text(fields.get("reason"))},
	}

static func _safe_integer(value: Variant) -> bool:
	return (value is int or value is float and is_finite(value) and value == floorf(value)) and value >= -SAFE_INTEGER and value <= SAFE_INTEGER

func record(diagnostic: Dictionary, connection: int) -> bool:
	var code: Variant = diagnostic.get("code")
	if _limit == 0 or code not in TERMINAL_CODES:
		return false
	var row := {
		"at": floori(Time.get_unix_time_from_system() * 1000.0),
		"connection": connection,
		"code": code,
		"reason": _text(diagnostic.get("reason")),
	}
	var failure: Variant = diagnostic.get("failure")
	if failure is Dictionary or failure is Array:
		row.failure = _failure(failure if failure is Dictionary else {})
	if diagnostic.get("clientFailure") is Dictionary:
		row.clientFailure = _client_failure(diagnostic.clientFailure)
	if code == "network.server-disconnected":
		if _safe_integer(diagnostic.get("strRef")):
			row.strRef = int(diagnostic.strRef)
		if diagnostic.get("text") is String:
			row.text = _text(diagnostic.text)
	var key := JSON.stringify([connection, code, row.reason, row.get("failure"), row.get("clientFailure"), row.get("strRef"), row.get("text")])
	if _recent.has(key):
		return false
	_recent[key] = true
	if _recent.size() > _limit:
		_recent.erase(_recent.keys()[0])
	if not _report.get("sessionFailures") is Array:
		_report.sessionFailures = []
	if _report.sessionFailures.size() >= _limit:
		_report.sessionFailures.pop_front()
	_report.sessionFailures.append(row)
	if code in CONNECT_CODES:
		if not _report.get("connectionFailures") is Array:
			_report.connectionFailures = []
		if _report.connectionFailures.size() < 32:
			_report.connectionFailures.append(row)
	_pending.append(JSON.stringify(row, "", false) + "\n")
	if not _scheduled:
		_scheduled = true
		call_deferred("settled")
	return true

func _append(line: String) -> bool:
	var file := FileAccess.open(_path, FileAccess.READ_WRITE if FileAccess.file_exists(_path) else FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_string(line)
	file.flush()
	var written := file.get_error() == OK
	file.close()
	return written

func settled() -> void:
	# A single session-world owner appends on its main thread in receipt order.
	_scheduled = false
	var lines := _pending
	_pending = []
	for line in lines:
		if not _append(line):
			_report.sessionFailureJournalErrors = mini(65535, int(_report.get("sessionFailureJournalErrors", 0)) + 1)
