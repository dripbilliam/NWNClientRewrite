extends Node
# Replacement preferences and pending edits. Original action IDs/defaults and
# table policy come from Keymap; editable36-slot hotbars are a user extension.
signal changed
signal capture_changed(active: bool)
signal edited
signal cancel_requested
const Rules=preload("res://systems/native_data/keymap_rules.gd")
const SHIFT:=1
const CTRL:=2
const ALT:=4
const META:=8
const NATIVE_KEYS=[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_PAGEUP,KEY_PAGEDOWN,KEY_KP_SUBTRACT,KEY_KP_ADD,KEY_PRINT,KEY_INSERT,KEY_DELETE,KEY_HOME,KEY_END,KEY_KP_0,KEY_KP_1,KEY_KP_2,KEY_KP_3,KEY_KP_4,KEY_KP_5,KEY_KP_6,KEY_KP_7,KEY_KP_8,KEY_KP_9,KEY_KP_PERIOD,KEY_KP_MULTIPLY,KEY_KP_DIVIDE,KEY_KP_ENTER,KEY_APOSTROPHE,KEY_TAB,KEY_BACKSPACE,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_BACKSLASH,KEY_SEMICOLON,KEY_QUOTELEFT,KEY_COMMA,KEY_PERIOD,KEY_SLASH,KEY_SPACE,KEY_A,KEY_B,KEY_C,KEY_D,KEY_E,KEY_F,KEY_G,KEY_H,KEY_I,KEY_J,KEY_K,KEY_L,KEY_M,KEY_N,KEY_O,KEY_P,KEY_Q,KEY_R,KEY_S,KEY_T,KEY_U,KEY_V,KEY_W,KEY_X,KEY_Y,KEY_Z]
var path:=""
var table: Dictionary={}
var language:=0
var active: Dictionary={}
var pending: Dictionary={}
var bindings_ready:=false
var closed:=false
var capturing:=false
var capture_kind:=""
var capture_index:=-1
var revision:=0
var failure:=""
func configure(storage: String) -> void: path=storage
static func physical(event: InputEventKey) -> int: return int(event.physical_keycode) if event.physical_keycode!=0 else int(event.keycode)
static func chord(event: InputEventKey) -> Dictionary:
	return {"key":physical(event),"modifiers":(SHIFT if event.shift_pressed else 0)|(CTRL if event.ctrl_pressed else 0)|(ALT if event.alt_pressed else 0)|(META if event.meta_pressed else 0)}
static func native_key(code: int) -> int:
	if code>=40 and code<=104: return int(NATIVE_KEYS[code-40])
	if code>=12 and code<=23: return KEY_F1+code-12
	if code>=30 and code<=39: return KEY_0+code-30
	return KEY_ESCAPE if code==10 else KEY_ENTER if code==11 else 0
static func native_chord(binding: int) -> Dictionary:
	return {"key":native_key(binding&255),"modifiers":SHIFT if binding>>8==2 else CTRL if binding>>8==3 else 0}
static func hotbar_defaults() -> Array:
	var rows: Array=[]
	for index in 36: rows.append({"key":KEY_F1+index%12,"modifiers":CTRL if index>=24 else SHIFT if index>=12 else 0})
	return rows
static func valid_chord(value: Variant) -> bool:
	if not value is Dictionary or not value.get("key") is int or not value.get("modifiers") is int: return false
	var key:=int(value.key)
	return key>=0 and key<(1<<23) and key not in [KEY_ESCAPE,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META] and int(value.modifiers)>=0 and int(value.modifiers)<=15 and (key!=0 or int(value.modifiers)==0)
static func token(value: Dictionary) -> String: return str(int(value.key))+":"+str(int(value.modifiers))
func profile() -> Dictionary:
	var saved:=ConfigFile.new(); var normal: Dictionary={}; var hotbar: Array=hotbar_defaults()
	if not path.is_empty() and saved.load(path)==OK:
		for action in range(Rules.FIRST,Rules.LAST+1):
			var name:="Action"+str(action)
			if saved.has_section_key("Keymapping",name): normal[name]=str(saved.get_value("Keymapping",name))
		for index in 36:
			var value: Variant=saved.get_value("HotbarKeymapping","Slot"+str(index),hotbar[index])
			if valid_chord(value): hotbar[index]={"key":int(value.key),"modifiers":int(value.modifiers)}
	return {"normal":normal,"hotbar":hotbar}
func install(source: Dictionary,locale: int=0) -> void:
	retire(); table=source; language=locale; failure=""
	var saved:=profile(); var normal:=Rules.populate(table,language,saved.normal)
	bindings_ready=not table.get("rowLabels",[]).is_empty() and normal.errors.is_empty()
	if not bindings_ready: failure="Active Keymap.2DA is unavailable" if normal.errors.is_empty() else str(normal.errors); return
	active={"normal":normal,"hotbar":saved.hotbar}; changed.emit()
func begin() -> int:
	retire()
	if bindings_ready and not closed: pending=active.duplicate(true)
	return revision
func defaults(ticket: int) -> void:
	if not valid_transaction(ticket): return
	stop_capture(); pending={"normal":Rules.populate(table,language,{},true),"hotbar":hotbar_defaults()}; edited.emit()
func valid_transaction(ticket: int) -> bool: return bindings_ready and not closed and ticket==revision and not pending.is_empty()
func start_capture(kind: String,index: int,ticket: int) -> bool:
	if not valid_transaction(ticket) or kind not in ["normal","hotbar"]: return false
	if kind=="hotbar" and (index<0 or index>=36): return false
	if kind=="normal" and not pending.normal.rows.any(func(row):return int(row.action)==index): return false
	stop_capture(); capture_kind=kind; capture_index=index; capturing=true; capture_changed.emit(true); edited.emit(); return true
func stop_capture() -> void:
	var was:=capturing; capturing=false; capture_kind=""; capture_index=-1
	if was: capture_changed.emit(false)
func assign(kind: String,index: int,value: Dictionary,ticket: int) -> bool:
	if not valid_transaction(ticket) or not valid_chord(value) or int(value.key)==0: return false
	var native:=0
	if kind=="normal":
		var at:=NATIVE_KEYS.find(int(value.key))
		if at<0 or int(value.modifiers)!=0 or not pending.normal.rows.any(func(row):return int(row.action)==index): return false
		native=at+40
	elif kind!="hotbar" or index<0 or index>=36: return false
	# Clear actual chord conflicts across original rows and all36 extension
	# slots. An unbound action is local input state, never server shortcut data.
	for row in pending.normal.rows:
		if native_chord(int(row.binding))==value: row.binding=0; pending.normal.values[int(row.action)]=0
	for slot in 36:
		if pending.hotbar[slot]==value: pending.hotbar[slot]={"key":0,"modifiers":0}
	if kind=="normal":
		for row in pending.normal.rows:
			if int(row.action)==index: row.binding=native
		pending.normal.values[index]=native
	else: pending.hotbar[index]={"key":int(value.key),"modifiers":int(value.modifiers)}
	stop_capture(); edited.emit(); return true
func unbind(kind: String,index: int,ticket: int) -> bool:
	if not valid_transaction(ticket): return false
	if kind=="hotbar" and index>=0 and index<36: pending.hotbar[index]={"key":0,"modifiers":0}
	elif kind=="normal" and pending.normal.values.has(index):
		pending.normal.values[index]=0
		for row in pending.normal.rows:
			if int(row.action)==index: row.binding=0
	else: return false
	stop_capture(); edited.emit(); return true
func commit(ticket: int) -> bool:
	if not valid_transaction(ticket): return false
	stop_capture(); failure=""
	var saved:=ConfigFile.new()
	if not path.is_empty():
		var loaded:=saved.load(path)
		if loaded not in [OK,ERR_FILE_NOT_FOUND]: failure="Key preferences could not be read"; return false
		var writes:=Rules.writes(pending.normal)
		for name in writes: saved.set_value("Keymapping",name,writes[name])
		for index in 36: saved.set_value("HotbarKeymapping","Slot"+str(index),pending.hotbar[index])
		if saved.save(path)!=OK: failure="Key preferences could not be saved"; return false
	active=pending.duplicate(true); pending.clear(); revision+=1; changed.emit(); return true
func retire() -> void:
	stop_capture(); pending.clear(); revision+=1
func blocked() -> bool: return closed or not bindings_ready or capturing
func hotbar_index(event: InputEventKey,page: int=0) -> int:
	if blocked(): return -1
	var value:=chord(event); var defaults_list:=hotbar_defaults()
	# An explicit custom chord wins over the original active-page F-key alias.
	for index in 36:
		if active.hotbar[index]!=defaults_list[index] and int(active.hotbar[index].key)!=0 and active.hotbar[index]==value: return index
	var key:=int(value.key)
	if key>=KEY_F1 and key<=KEY_F12 and not event.alt_pressed and not event.meta_pressed:
		var index: int=(2 if event.ctrl_pressed else 1 if event.shift_pressed else clampi(page,0,2))*12+key-KEY_F1
		if active.hotbar[index]==defaults_list[index]: return index
		return -1
	for index in 36:
		if int(active.hotbar[index].key)!=0 and active.hotbar[index]==value: return index
	return -1
func action_matches(action: int,event: InputEventKey,movement: bool=false) -> bool:
	if blocked() or hotbar_index(event)>=0: return false
	var binding:=int(active.normal.values.get(action,0))
	if binding<=0: return false
	var wanted:=native_chord(binding); var value:=chord(event)
	if movement and int(wanted.modifiers)==0: value.modifiers=int(value.modifiers)&~SHIFT
	return wanted==value
func action(event: InputEventKey,allowed: Array,movement: bool=false) -> int:
	for id in allowed:
		if action_matches(int(id),event,movement): return int(id)
	return -1
func caption(value: Dictionary,resolve: Callable) -> String:
	if int(value.get("key",0))==0: return ""
	var key:=int(value.key); var at:=NATIVE_KEYS.find(key); var ref:=Rules.label_ref(at+40) if at>=0 else -1
	var text: String=str(resolve.call(ref)).strip_edges() if ref>=0 else OS.get_keycode_string(key)
	var modifiers:=int(value.modifiers); var parts: PackedStringArray=[]
	if modifiers&CTRL: parts.append(str(resolve.call(52917)))
	if modifiers&ALT: parts.append("Alt")
	if modifiers&SHIFT: parts.append(str(resolve.call(52919)))
	if modifiers&META: parts.append("Meta")
	parts.append(text); return " + ".join(parts)
func _input(event: InputEvent) -> void:
	if not capturing or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	if physical(event)==KEY_ESCAPE: cancel_requested.emit(); return
	var value:=chord(event)
	if capture_kind=="normal": value.modifiers=0
	assign(capture_kind,capture_index,value,revision)
func snapshot() -> Dictionary:
	return {"ready":bindings_ready,"capturing":capturing,"pending":not pending.is_empty(),"revision":revision,"failure":failure,"hotbar_slots":active.get("hotbar",[]).size(),"native_only":true,"full_key_settings_parity":false}
func close() -> void:
	if closed: return
	retire(); closed=true; bindings_ready=false; active.clear(); table={}
func _exit_tree() -> void: close()
