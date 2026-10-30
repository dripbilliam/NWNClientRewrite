extends RefCounted
const Binary=preload("res://systems/native_data/binary_data.gd")
static func byte_value(code: int) -> int:
	if code>=0 and code<=255: return code
	var index:=Binary.CP1252_HIGH.find(code)
	return index+128 if index>=0 else -1
static func color_width(text: String,at: int) -> int:
	if text.substr(at,4)=="</c>": return 4
	if text.substr(at,2)!="<c" or at+5>=text.length() or text[at+5]!=">": return 0
	for index in range(at+2,at+5):
		if byte_value(text.unicode_at(index))<0: return 0
	return 6
static func parse(raw: String) -> Dictionary:
	var spans: Array=[]; var colors: Array=[]; var text:=""; var at:=0
	while at<raw.length():
		var width:=color_width(raw,at)
		if width>0:
			if not text.is_empty(): spans.append({"text":text,"color":colors.back() if not colors.is_empty() else null}); text=""
			if width==4:
				if not colors.is_empty(): colors.pop_back()
			else:
				var rgb:="#"
				for index in range(at+2,at+5): rgb+="%02x"%byte_value(raw.unicode_at(index))
				colors.append(rgb)
			at+=width
		else: text+=raw[at]; at+=1
	if not text.is_empty(): spans.append({"text":text,"color":colors.back() if not colors.is_empty() else null})
	var plain:=""
	for span in spans: plain+=str(span.text)
	return {"spans":spans,"text":plain}
