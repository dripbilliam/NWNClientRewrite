extends RefCounted
# Connection-owned raw NUI data. No projected controls or JS layout state.
const UNDEFINED: StringName=&"__native_nui_missing__"
var windows: Dictionary={}
var version:=0
var serial:=0
var failure:=""
static func _integer_token(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value!=0
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
	# JavaScript Number(array) first stringifies the array. The raw NUI JSON
	# permits arrays in numeric layout fields, including [] and [one value].
	if value is Array:
		if value.is_empty(): return 0.0
		if value.size()!=1: return fallback
		return 0.0 if value[0]==null else number(value[0],fallback)
	if value is String:
		var text: String=value.strip_edges()
		if text.is_empty(): return 0
		var prefix:=text.substr(0,2).to_lower()
		if prefix in ["0x","0b","0o"]:
			var base:=16 if prefix=="0x" else 2 if prefix=="0b" else 8
			if text.length()==2:return fallback
			var result:=0.0
			for index in range(2,text.length()):
				var digit: int="0123456789abcdef".find(text.substr(index,1).to_lower())
				if digit<0 or digit>=base:return fallback
				result=result*base+digit
				if not is_finite(result):return fallback
			return result
		if text.is_valid_float(): return float(text) if is_finite(float(text)) else fallback
	return fallback
static func _big_decimal(value: Variant) -> String:
	if not value is Object:return ""
	for property in value.get_property_list():
		if str(property.name)=="decimal" and value.get("decimal") is String:return str(value.get("decimal"))
	return ""
static func _decimal_hex(decimal: String) -> String:
	var negative:=decimal.begins_with("-")
	var digits:=decimal.substr(1) if negative else decimal
	if digits.is_empty():return "0"
	var hex:=""
	while digits!="0" and not digits.is_empty():
		var quotient:=""
		var carry:=0
		for index in digits.length():
			var number:=carry*10+digits.unicode_at(index)-48
			var next:=int(number/16)
			carry=number%16
			if next!=0 or not quotient.is_empty():quotient+=str(next)
		hex="0123456789abcdef"[carry]+hex
		digits=quotient if not quotient.is_empty() else "0"
	return ("-" if negative and hex!="0" else "")+(hex if not hex.is_empty() else "0")
static func text(value: Variant,format: Dictionary={}) -> String:
	if value==null or missing(value): return ""
	var result:=""
	var big:=_big_decimal(value)
	if not big.is_empty():result=_decimal_hex(big) if int(number(format.get("number_flags",0)))&1 else big
	elif value is float or value is int:
		if value is float and not is_finite(value):result="NaN" if is_nan(value) else "-Infinity" if value<0 else "Infinity"
		elif int(number(format.get("number_flags",0)))&1:result=_decimal_hex(str(int(value)))
		elif value is float and value!=floor(float(value)): result=("%."+str(clampi(int(number(format.get("number_precision",0))),0,64))+"f")%value
		else: result=str(int(value))
	elif value is String: result=value
	elif value is bool: result="true" if value else "false"
	elif value is Dictionary: result="[object Object]"
	elif value is Array:
		var items: Array[String]=[]
		for item in value:items.append(text(item))
		result=",".join(items)
	else: result=str(value)
	var flags:=int(number(format.get("text_flags",0)))
	if flags&1: result=result.to_lower()
	if flags&2: result=result.to_upper()
	return result
func receive(message: Dictionary) -> bool:
	failure=""
	match str(message.kind):
		"nui-create":
			var raw_token: Variant=message.get("token")
			if not _integer_token(raw_token) or not message.get("layout") is Dictionary: failure="Invalid raw NUI window identity/layout"; return false
			var token:=int(raw_token)
			version+=1; serial+=1
			windows[token]={"token":token,"id":message.get("id"),"serial":int(message.get("nativeSerial",serial)),"layout":message.layout.duplicate(true),"bindings":{},"layouts":{},"version":version,"ready":message.layout.has("root")}
		"nui-destroy":
			if windows.erase(int(message.token)): version+=1
		"nui-binds":
			var replacements: Dictionary={}
			for update in message.updates:
				var token:=int(update.token)
				var previous: Dictionary=replacements.get(token,windows.get(token,{}))
				if previous.is_empty():continue
				if not update.get("bind") is String: failure="Invalid raw NUI binding name"; return false
				var window:=previous.duplicate()
				window.bindings=previous.bindings.duplicate(true)
				window.bindings[str(update.bind)]=copy_value(update.value)
				window.version=version+1
				replacements[token]=window
			if not replacements.is_empty():
				version+=1
				for token in replacements:windows[token]=replacements[token]
		"nui-layout":
			var token:=int(message.token)
			if windows.has(token):
				var previous: Dictionary=windows[token]
				var window:=previous.duplicate()
				window.layouts=previous.layouts.duplicate(true)
				window.layouts[message.element]=copy_value(message.layout)
				version+=1;window.version=version;windows[token]=window
		_: return false
	return true
static func copy_value(value: Variant) -> Variant: return value.duplicate(true) if value is Array or value is Dictionary else value
func local_bind(token: int,key: String,content: Variant,index: int=-1) -> Dictionary:
	failure=""
	if not windows.has(token):failure="NUI window is no longer open";return {}
	var previous: Dictionary=windows[token]
	var window:=previous.duplicate()
	window.bindings=previous.bindings.duplicate(true)
	version+=1;window.version=version
	if index<0:window.bindings[key]=copy_value(content)
	else:
		var current: Variant=window.bindings.get(key)
		if not current is Array or index>=current.size():failure="NUI binding index is stale";return {}
		var next: Array=current.duplicate()
		next[index]=copy_value(content)
		window.bindings[key]=next
	windows[token]=window
	return window
func clear() -> void: windows.clear(); version+=1

static func equal(left: Variant,right: Variant) -> bool:
	var a:=typeof(left); var b:=typeof(right)
	if a in [TYPE_INT,TYPE_FLOAT] and b in [TYPE_INT,TYPE_FLOAT]: return float(left)==float(right)
	return left==right if a==b else false
