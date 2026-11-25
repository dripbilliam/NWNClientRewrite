extends Control

signal admission_changed

const FADE_IN := 0.6
const HOLD := 5.0
const FADE_OUT := 1.6

enum Phase { IDLE, PREPARING, SHOWING, FINISHED }

var phase := Phase.IDLE
var artwork: TextureRect
var painter
var elapsed := 0.0

static func enabled(profile: String) -> bool:
	if profile.is_empty(): return true
	var settings := FileAccess.open(profile.path_join("settings.tml"),FileAccess.READ)
	if settings == null: return true
	var splash_section := false
	while not settings.eof_reached():
		var line := settings.get_line().get_slice("#",0).strip_edges()
		if line.begins_with("["):
			splash_section = line == "[graphics.intro.splash]"
		elif splash_section and line.get_slice("=",0).strip_edges() == "enabled":
			return line.get_slice("=",1).strip_edges() != "false"
	return true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	set_process(false)

func prepare(shared_painter) -> void:
	if phase == Phase.FINISHED: return
	painter = shared_painter
	artwork = painter.image("load_legal",Rect2(Vector2.ZERO,size),self)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE

func open_once() -> void:
	if phase != Phase.IDLE: return
	phase = Phase.PREPARING
	set_process(true)

func covers_menu() -> bool:
	return phase == Phase.PREPARING or (phase == Phase.SHOWING and elapsed < FADE_IN + HOLD)

func _process(delta: float) -> void:
	if phase == Phase.PREPARING:
		if artwork == null: return
		if artwork.texture == null:
			var key := str(artwork.get_meta("native_gui_art_key",""))
			if key.is_empty() or painter.art.failed.has(key): finish()
			return
		phase = Phase.SHOWING
		artwork.modulate.a = 0.0
		show()
		move_to_front()
		return
	if phase != Phase.SHOWING: return
	var was_covering := covers_menu()
	elapsed += delta
	if elapsed >= FADE_IN + HOLD + FADE_OUT:
		finish()
		return
	artwork.modulate.a = minf(clampf(elapsed / FADE_IN,0.0,1.0),clampf((FADE_IN + HOLD + FADE_OUT - elapsed) / FADE_OUT,0.0,1.0))
	if was_covering and not covers_menu():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		admission_changed.emit()

func finish() -> void:
	if phase == Phase.FINISHED or phase == Phase.IDLE: return
	phase = Phase.FINISHED
	hide()
	set_process(false)
	admission_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		finish()
