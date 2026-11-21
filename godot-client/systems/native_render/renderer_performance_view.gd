extends PanelContainer
# Direct replacement for the old renderer performance window's rolling display.
# The caller supplies the same frame timing and detail fields when available.
const ROWS := [
	["fps", "FPS"], ["frame", "Frame avg / p95"], ["peak", "Worst / hitches >50ms"],
	["work", "Frame process CPU"], ["render", "Render CPU"], ["network", "Network visuals"],
	["presentation", "Other presentation"], ["particles", "Particles"], ["camera", "Camera / lights"],
	["cameraAndAudio", "Camera / audio"], ["keyhole", "Keyhole"], ["overlay", "Labels / picking"],
	["matrices", "World matrices"], ["membership", "Scene membership"], ["selection", "Light selection"],
	["shadowBudget", "Shadow budgeting"], ["lightSlots", "Light shader slots"], ["metadata", "Debug metadata"],
	["draws", "Total / shadow draws"], ["triangles", "Total / shadow primitives"],
	["reuse", "Shadow maps reused"], ["particleWorkers", "Particle workers / pending frame"],
	["resolution", "Render resolution"], ["display", "Viewport / pixel ratio"],
	["lights", "Lights / shadows"], ["slots", "Point shader slots"], ["programs", "Cached shaders / new"],
	["loading", "Pending assets / shaders"], ["models", "Model preparations / failed"],
	["memory", "Geometries / textures"], ["heap", "Renderer JS heap"]
]
const PRIMARY := {"fps": true, "frame": true, "peak": true, "render": true, "loading": true, "programs": true}
const STAGES := ["cameraAndAudio", "keyhole", "overlay", "matrices", "membership", "selection", "shadowBudget", "lightSlots", "metadata"]

var samples: Array = []
var last_at: Variant = null
var last_publish := -INF
var last_programs: Variant = null
var peak := 0.0
var hitches := 0
var fields: Dictionary = {}
var state: Dictionary = {}
var more: ScrollContainer

func configure() -> void:
	name = "Renderer performance"
	position = Vector2(16, 52)
	custom_minimum_size = Vector2(355, 0)
	var body := VBoxContainer.new()
	add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := Label.new()
	title.text = "PERFORMANCE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var reset := Button.new()
	reset.text = "Reset peaks"
	reset.pressed.connect(func() -> void: peak = 0.0; hitches = 0)
	heading.add_child(reset)
	var primary := GridContainer.new()
	primary.columns = 2
	body.add_child(primary)
	for row in ROWS:
		if PRIMARY.has(row[0]): _add_row(primary, row)
	var expand := CheckButton.new()
	expand.text = "More performance details"
	expand.toggled.connect(func(value: bool) -> void: more.visible = value)
	body.add_child(expand)
	more = ScrollContainer.new()
	more.custom_minimum_size = Vector2(345, 360)
	more.visible = false
	body.add_child(more)
	var detail_grid := GridContainer.new()
	detail_grid.columns = 2
	more.add_child(detail_grid)
	for row in ROWS:
		if not PRIMARY.has(row[0]): _add_row(detail_grid, row)
	var note := Label.new()
	note.text = "FPS uses a 2-second window. Times measure CPU work and driver waits, not GPU time or server ping."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 345
	body.add_child(note)
	hide()

func _add_row(grid: GridContainer, row: Array) -> void:
	var label := Label.new()
	label.text = str(row[1])
	grid.add_child(label)
	var value := Label.new()
	value.text = "—"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)
	fields[row[0]] = value

static func _ms(value: Variant) -> String:
	return "%.1f ms" % float(value) if value != null and is_finite(float(value)) else "—"

static func _number(value: Variant) -> String:
	if value == null or not is_finite(float(value)): return "—"
	# The old overlay's toLocaleString groups whole-number counters. The local
	# Windows profile uses comma grouping; keep that formatting for real values.
	var raw:=str(roundi(float(value)))
	var sign:="-" if raw.begins_with("-") else ""
	if not sign.is_empty():raw=raw.substr(1)
	var grouped:=""
	for index in raw.length():
		if index>0 and (raw.length()-index)%3==0:grouped+=","
		grouped+=raw[index]
	return sign+grouped

static func _average(rows: Array, key: String) -> Variant:
	var total := 0.0
	for row in rows:
		if not row.timing.has(key): return null
		total += float(row.timing[key])
	return total / rows.size()

static func _stage(rows: Array, key: String) -> Variant:
	var total := 0.0
	for row in rows:
		var timing: Dictionary = row.timing.get("cameraStages", {})
		if not timing.has(key + "Ms"): return null
		total += float(timing[key + "Ms"])
	return total / rows.size()

func record(input: Dictionary) -> void:
	if not bool(input.get("visible", true)):
		samples.clear()
		last_at = null
		return
	var at := float(input.get("at", Time.get_ticks_msec()))
	var timing: Dictionary = input.get("timing", {})
	var rendered := bool(input.get("rendered", false))
	# The first sample needs an actual measured duration. Subsequent samples
	# use completion-to-completion gaps, including stalls outside callbacks.
	if last_at == null and not timing.has("totalMs"):
		last_at=at
		return
	var gap := float(timing.totalMs) if last_at == null else maxf(0.0, at - float(last_at))
	last_at = at
	var programs: Variant = timing.get("programsAfter")
	var added := maxi(0, int(programs) - int(last_programs)) if programs != null and last_programs != null else 0
	last_programs = programs
	peak = maxf(peak, gap)
	if gap > 50.0: hitches += 1
	samples.append({"at": at, "gap": gap, "rendered": rendered, "added": added, "timing": timing})
	while samples.size() > 1 and float(samples[0].at) < at - 2000.0: samples.pop_front()
	if at - last_publish < 500.0: return
	last_publish = at
	var count := samples.size()
	var elapsed := 0.0
	var intervals: Array = []
	var rendered_count := 0
	var new_programs := 0
	for row in samples:
		elapsed += float(row.gap)
		intervals.append(float(row.gap))
		rendered_count += int(row.rendered)
		new_programs += int(row.added)
	intervals.sort()
	var average_frame := elapsed / count
	var p95: float = intervals[clampi(int(ceil(count * 0.95)) - 1, 0, count - 1)]
	var fps := rendered_count * 1000.0 / elapsed if elapsed > 0.0 else 0.0
	var details: Dictionary = input.get("details", {})
	var draw: Dictionary = details.get("draw", {})
	var shadow: Dictionary = details.get("shadow", {})
	var viewport: Dictionary = details.get("viewport", {})
	var lighting: Dictionary = details.get("lighting", {})
	var models: Dictionary = details.get("models", {})
	var memory: Dictionary = details.get("memory", {})
	var workers: Dictionary = details.get("particleWorkers", {})
	var selection: Dictionary = lighting.get("selection", {})
	var budget: Dictionary = lighting.get("shadows", {})
	var point: Dictionary = lighting.get("slots", {}).get("point", {})
	var values: Dictionary = {
		"fps": "%.1f%s" % [fps, "" if rendered else " · preparing"],
		"frame": "%s / %s" % [_ms(average_frame), _ms(p95)],
		"peak": "%s / %s" % [_ms(peak), _number(hitches)],
		"work": _ms(_average(samples, "totalMs")),
		"render": _ms(_average(samples, "renderMs")),
		"network": _ms(_average(samples, "networkMs")),
		"presentation": _ms(_average(samples, "presentationMs")),
		"particles": _ms(_average(samples, "particlesMs")),
		"camera": _ms(_average(samples, "cameraAndShadowsMs")),
		"draws": "%s / %s" % [_number(draw.get("calls")) if rendered else "—", _number(shadow.get("drawCalls")) if rendered else "—"],
		"triangles": "%s / %s" % [_number(draw.get("triangles")) if rendered else "—", _number(shadow.get("triangles")) if rendered else "—"],
		"reuse": "%s reused · %s drawn" % [_number(shadow.get("reusedLights")), _number(shadow.get("renderedLights"))],
		"particleWorkers": "%s / %s" % [_number(workers.get("workers")), _number(int(bool(workers.pending))) if workers.has("pending") else "—"],
		"resolution": "%s × %s" % [_number(viewport.get("bufferWidth")), _number(viewport.get("bufferHeight"))],
		"display": "%s × %s · %s×" % [_number(viewport.get("width")), _number(viewport.get("height")), str(viewport.get("pixelRatio", "—"))],
		"lights": "%s active · %s/%s shadows" % [_number(selection.get("admitted")), _number(budget.get("admitted")), _number(budget.get("requested"))],
		"slots": "%s/%s lights · %s/%s shadows" % [_number(point.get("actual")), _number(point.get("capacity")), _number(point.get("shadowActual")), _number(point.get("shadowCapacity"))],
		"programs": "%s / +%s" % [_number(programs), _number(new_programs)] if programs != null else "—",
		"loading": "%s / %s" % [_number(details.get("pendingAssets")), _number(models.get("pending"))],
		"models": "%s / %s" % [_number(models.get("compilations")), _number(models.get("failed"))],
		"memory": "%s / %s" % [_number(memory.get("geometries")), _number(memory.get("textures"))],
		"heap": "%.1f MiB" % (float(details.heapBytes) / 1048576.0) if details.get("heapBytes") != null else "Unavailable"
	}
	for stage in STAGES: values[stage] = _ms(_stage(samples, str(stage)))
	for id in values:
		if fields.has(id) and fields[id].text != values[id]: fields[id].text = values[id]
	state = {"fps": fps, "averageFrameMs": average_frame, "p95FrameMs": p95, "worstFrameMs": peak, "hitches": hitches, "preparing": not rendered, "programs": programs, "pendingAssets": details.get("pendingAssets"), "pendingShaders": models.get("pending")}

func snapshot() -> Dictionary:
	return state.duplicate(true)
