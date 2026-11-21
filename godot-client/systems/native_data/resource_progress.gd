extends RefCounted

const MAX_SAFE_INTEGER := 9007199254740991
const MAX_RESOURCES := 1000000

static func _counter(value: Variant) -> bool:
	if value is int:
		return value >= 0 and value <= MAX_SAFE_INTEGER
	return value is float and is_finite(value) and value >= 0 and value <= MAX_SAFE_INTEGER and value == floorf(value)

static func finite_resource_progress(value: Variant) -> Variant:
	if not value is Dictionary or value.get("phase") not in ["server-manifest", "server-content"]:
		return null
	for field in ["completed", "total", "downloadedBytes"]:
		if not _counter(value.get(field)):
			return null
	if value.completed > value.total or value.total > MAX_RESOURCES:
		return null
	return {
		"phase": value.phase,
		"completed": int(value.completed),
		"total": int(value.total),
		"downloadedBytes": int(value.downloadedBytes),
	}

static func can_cancel_resources(phase: String, character_submitted: bool, character_uploaded: bool) -> bool:
	# Direct sessions distinguish active content loading from pre-manifest admission.
	return phase in ["connecting", "resources", "loading-content", "resources-unavailable"] and not character_submitted and not character_uploaded
