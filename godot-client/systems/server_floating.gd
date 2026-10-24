extends Control

const Text = preload("res://systems/server_text.gd")
var entries: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset() -> void:
	for entry in entries:
		entry.label.hide()
		entry.label.queue_free()
	entries.clear()

func add_event(event: Dictionary) -> void:
	var label := Text.label({}, 600)
	var rgb: Array = event.get("rgb", [1.0, 1.0, 1.0])
	Text.append(label, event.get("rich", {"text": event.get("text", "")}), Color(float(rgb[0]), float(rgb[1]), float(rgb[2])))
	add_child(label)
	label.hide()
	entries.append({"label": label, "objectId": int(event.objectId), "remaining": 1.5})
	if entries.size() > 64:
		entries.pop_front().label.queue_free()

func advance(delta: float, camera: Camera3D, pivots: Dictionary) -> void:
	if not is_finite(delta) or delta < 0:
		return
	for entry in entries.duplicate():
		if delta >= entry.remaining or not pivots.has(entry.objectId) or not is_instance_valid(camera):
			entry.label.queue_free()
			entries.erase(entry)
			continue
		var label: RichTextLabel = entry.label
		var position: Vector3 = pivots[entry.objectId].global_position + Vector3.UP * (2.0 + (1.5 - entry.remaining) * 0.5)
		label.visible = not camera.is_position_behind(position)
		if label.visible:
			var point := camera.unproject_position(position)
			label.position = Vector2(int(point.x + 0.5), int(point.y + 0.5)) - Vector2(label.size.x / 2, label.size.y)
			label.modulate.a = 1.0 if entry.remaining >= 0.5 else entry.remaining * 2.0
		entry.remaining -= delta
