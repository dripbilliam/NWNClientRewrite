extends RefCounted
# Connection-owned raw NUI data. No projected controls or JS layout state.
const UNDEFINED: StringName=&"__native_nui_missing__"
var windows: Dictionary={}
var version:=0
var serial:=0
var failure:=""
static func missing(value: Variant) -> bool: return typeof(value)==TYPE_STRING_NAME and value==UNDEFINED
static func is_bind(value: Variant) -> bool: return value is Dictionary and value.get("bind") is String
static func value(window: Dictionary,source: Variant,index: int=-1) -> Variant:
	if not is_bind(source): return source
	var found: Variant=window.bindings.get(source.bind,UNDEFINED)
	return found[index] if index>=0 and found is Array and index<found.size() else (UNDEFINED if index>=0 and found is Array else found)
static func at(window: Dictionary,element: Dictionary,key: String,index: int=-1) -> Variant: return value(window,element.get(key,UNDEFINED),index)
static func strict_false(value: Variant) -> bool: return value is bool and not value
static func truth(value: Variant) -> bool:
	if missing(value) or value==null: return false
	if value is bool: return value
	if value is int or value is float: return value!=0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true
static func number(value: Variant,fallback: float=0.0) -> float:
	if missing(value): return fallback
	if value==null: return 0.0
	if value is bool: return 1.0 if value else 0.0
	if value is float or value is int: return float(value) if is_finite(float(value)) else fallback
	if value is String:
		var text: String=value.strip_edges()
		if text.is_empty(): return 0
		if text.is_valid_float(): return float(text) if is_finite(float(text)) else fallback
	return fallback
static func text(value: Variant,format: Dictionary={}) -> String:
	if value==null or missing(value): return ""
	var result:=""
	if value is float or value is int:
		if int(number(format.get("number_flags",0)))&1: result=("-%x"%(-int(value))) if value<0 else "%x"%int(value)
		elif value is float and value!=floor(float(value)): result=("%."+str(clampi(int(number(format.get("number_precision",0))),0,64))+"f")%value
		else: result=str(int(value))
	elif value is String: result=value
	elif value is bool: result="true" if value else "false"
	elif value is Dictionary and value.has("native64"): result=str(value.native64)
	elif value is Dictionary: result="[object Object]"
	else: result=str(value)
	var flags:=int(number(format.get("text_flags",0)))
	if flags&1: result=result.to_lower()
	if flags&2: result=result.to_upper()
	return result
func receive(message: Dictionary) -> bool:
	failure=""
	match str(message.kind):
		"nui-create":
			var token:=int(message.get("token",0))
			if token==0 or not message.get("layout",{}) is Dictionary: failure="Invalid raw NUI window identity/layout"; return false
			version+=1; serial+=1
			windows[token]={"token":token,"serial":int(message.get("nativeSerial",serial)),"layout":message.get("layout",{}).duplicate(true),"bindings":{},"layouts":{},"version":version,"ready":message.get("layout",{}).has("root")}
		"nui-destroy":
			if windows.erase(int(message.token)): version+=1
		"nui-binds":
			var changed:=false
			for update in message.updates:
				if not windows.has(int(update.token)): continue
				if not update.get("bind") is String: failure="Invalid raw NUI binding name"; return false
				windows[int(update.token)].bindings[update.bind]=copy_value(update.value); windows[int(update.token)].version=version+1; changed=true
			if changed: version+=1
		"nui-layout":
			if windows.has(int(message.token)): version+=1; windows[int(message.token)].layouts[str(message.element)]=copy_value(message.layout); windows[int(message.token)].version=version
		_: return false
	return true
static func copy_value(value: Variant) -> Variant: return value.duplicate(true) if value is Array or value is Dictionary else value
func local_bind(token: int,key: String,content: Variant) -> void:
	if not windows.has(token): return
	version+=1; windows[token].bindings[key]=copy_value(content); windows[token].version=version
func clear() -> void: windows.clear(); version+=1

static func equal(left: Variant,right: Variant) -> bool:
	var a:=typeof(left); var b:=typeof(right)
	if a in [TYPE_INT,TYPE_FLOAT] and b in [TYPE_INT,TYPE_FLOAT]: return float(left)==float(right)
	return left==right if a==b else false
