extends RefCounted
# Compile text/colour commands once. Replay only commands per rendered frame,
# without re-shaping. Native CAurFont.ProcessTextMarkup uses a16-slot global
# ring, not a balanced stack; this app-lifetime lane covers ScriptFloating.
# Other legacy UI text owners' unbalanced render history is not reconstructed.
const Rich=preload("res://systems/native_data/rich_text.gd")
const F=preload("res://systems/native_render/particle_math.gd")
class Ring:
	extends RefCounted
	var index:=0
	var slots: Array[Color]=[]
	func _init() -> void:
		for at in 16:slots.append(Color.WHITE)
	func push(value: Color) -> void:slots[index]=value;index=(index+1)&15
	func pop() -> Color:index=(index+15)&15;return slots[index]
static var application_ring: Ring
static func shared_ring() -> Ring:
	if application_ring==null:application_ring=Ring.new()
	return application_ring
static func requires_named_tokens(raw: String) -> bool:
	var at:=0
	while at<raw.length():
		if raw[at]!="<":at+=1;continue
		if raw.substr(at,2)=="<<":at+=2;continue
		var width:=Rich.color_width(raw,at)
		if width>0:at+=width;continue
		var stop:=raw.find(">",at+1)
		if stop<0:return false
		var key:=raw.substr(at+1,stop-at-1)
		if not key.is_empty() and not (key.begins_with("CUSTOM") and key.length()>6):return true
		at=stop+1
	return false
static func compile(raw: String) -> Dictionary:
	var byte_count:=0;var end:=raw.length()
	for at in raw.length():
		var byte:=Rich.byte_value(raw.unicode_at(at))
		if byte<0:return {"ready":false,"reason":"Native floaty byte encoding is unavailable."}
		if byte==0 and end==raw.length():end=at
		byte_count+=1
	var visible:=raw.left(end);var commands: Array=[];var pieces: Array[String]=[];var start:=0;var at:=0
	while at<visible.length():
		# ProcessTextMarkup4c470 consumes four bytes after matching only </c.
		# The fourth byte is not tested, even at the C-string terminator.
		var closing: bool=visible.substr(at,3)=="</c";var opening:=false
		if visible.substr(at,2)=="<c" and at+5<visible.length() and visible[at+5]==">":
			opening=true
			for offset in range(2,5):
				if Rich.byte_value(visible.unicode_at(at+offset))<=0:opening=false
		if closing or opening:
			if at>start:
				var text:=visible.substr(start,at-start);commands.append({"op":"text","text":text});pieces.append(text)
			if closing:commands.append({"op":"close"});at+=4
			else:
				commands.append({"op":"open","rgb":Color(F.f(float(Rich.byte_value(visible.unicode_at(at+2)))/255.0),F.f(float(Rich.byte_value(visible.unicode_at(at+3)))/255.0),F.f(float(Rich.byte_value(visible.unicode_at(at+4)))/255.0),1.0)});at+=6
			start=at
		else:at+=1
	if at>start:
		var text:=visible.substr(start,at-start);commands.append({"op":"text","text":text});pieces.append(text)
	return {"ready":true,"commands":commands,"plain":"".join(pieces),"rendered":visible,"nativeBytes":byte_count,"renderedBytes":end}
static func compile_native(bytes: PackedByteArray,language: int) -> Dictionary:
	# Parse font commands in original byte order before decoding text spans.
	# RGB bytes are not DBCS characters, and byte counts are not glyph counts.
	var codec=preload("res://systems/native_data/native_text_encoding.gd")
	var end:=bytes.find(0)
	if end<0:end=bytes.size()
	var visible:=bytes.slice(0,end);var commands: Array=[];var pieces: Array[String]=[];var start:=0;var at:=0
	while at<end:
		var closing: bool=at+2<end and bytes[at]==60 and bytes[at+1]==47 and bytes[at+2]==99
		var opening: bool=at+5<end and bytes[at]==60 and bytes[at+1]==99 and bytes[at+5]==62 and bytes[at+2]!=0 and bytes[at+3]!=0 and bytes[at+4]!=0
		if closing or opening:
			if at>start:
				var decoded:=codec.decode(visible.slice(start,at),language)
				if not decoded.get("ready",false):return decoded
				commands.append({"op":"text","text":decoded.text});pieces.append(str(decoded.text))
			if closing:commands.append({"op":"close"});at+=4
			else:
				commands.append({"op":"open","rgb":Color(F.f(float(bytes[at+2])/255.0),F.f(float(bytes[at+3])/255.0),F.f(float(bytes[at+4])/255.0),1.0)});at+=6
			start=at
		else:at+=1
	if at>start:
		var decoded:=codec.decode(visible.slice(start,at),language)
		if not decoded.get("ready",false):return decoded
		commands.append({"op":"text","text":decoded.text});pieces.append(str(decoded.text))
	var rendered:=codec.decode(visible,language,true)
	if not rendered.get("ready",false):return rendered
	return {"ready":true,"commands":commands,"plain":"".join(pieces),"rendered":str(rendered.text),"nativeBytes":bytes.size(),"renderedBytes":end}
static func colors(program: Dictionary,ring: Ring,base: Color) -> Dictionary:
	var output: Dictionary={};var current:=base
	for index in program.get("commands",[]).size():
		var command: Dictionary=program.commands[index]
		match command.op:
			"open":ring.push(current);current=command.rgb
			"close":current=ring.pop()
			"text":output[index]=current
	return output
