extends RefCounted
# Bounded ordered Valve KeyValues reader. Installed-item order and membership
# come from Steam's installed section, excluding pending/download details.
const MAX_BYTES:=4*1024*1024
var failure:=""
var tokens: Array=[]
var index:=0
func parse(text: String) -> Array:
	failure=""; tokens=[]; index=0
	if text.length()>MAX_BYTES: failure="Steam metadata exceeds bound"; return []
	var at:=0
	while at<text.length():
		var c:=text[at]
		if c in [" ","\t","\r","\n"]: at+=1; continue
		if text.substr(at,2)=="//":
			var end:=text.find("\n",at); at=text.length() if end<0 else end+1; continue
		if c in ["{","}"]: tokens.append({"brace":c}); at+=1
		elif c=='"':
			at+=1; var value:=""; var closed:=false
			while at<text.length():
				c=text[at]; at+=1
				if c=='"': closed=true; break
				if c=="\\" and at<text.length():
					var escaped:=text[at]; at+=1
					value+={"n":"\n","r":"\r","t":"\t"}.get(escaped,escaped)
				else: value+=c
			if not closed: failure="Unterminated Steam metadata string"; return []
			tokens.append({"text":value})
		else:
			var start:=at
			while at<text.length() and text[at] not in [" ","\t","\r","\n","{","}"]: at+=1
			tokens.append({"text":text.substr(start,at-start)})
		if tokens.size()>200000: failure="Steam metadata token count exceeds bound"; return []
	var result:=block(false,0)
	if index!=tokens.size() and failure.is_empty(): failure="Trailing Steam metadata tokens"
	return result if failure.is_empty() else []
func block(braced: bool,depth: int) -> Array:
	if depth>64: failure="Steam metadata nesting exceeds bound"; return []
	var rows: Array=[]
	while index<tokens.size():
		var key: Dictionary=tokens[index]; index+=1
		if key.get("brace")=="}" and braced: return rows
		if not key.has("text") or index>=tokens.size(): failure="Invalid Steam metadata key/value"; return []
		var value: Dictionary=tokens[index]; index+=1
		if value.get("brace")=="{": rows.append({"key":key.text,"value":block(true,depth+1)})
		elif value.has("text"): rows.append({"key":key.text,"value":value.text})
		else: failure="Invalid Steam metadata value"; return []
		if not failure.is_empty(): return []
	if braced: failure="Unclosed Steam metadata section"
	return rows
static func section(rows: Array,name: String) -> Array:
	for row in rows:
		if row.key==name and row.value is Array: return [row.value]
		if row.value is Array:
			var found:=section(row.value,name)
			if not found.is_empty(): return found
	return []
