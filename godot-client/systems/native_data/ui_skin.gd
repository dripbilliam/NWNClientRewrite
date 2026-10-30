extends RefCounted
# Original installed NUI TOML subset: tables, scalar/JSON values and [[fonts]].
# It is data only; no executable source or JS layout is consumed.
var failure:=""
func reject(reason: String) -> Dictionary: failure=reason; return {}
func parse(source: String) -> Dictionary:
	failure=""
	if source.length()>4*1024*1024: return reject("Original NUI skin exceeds bound")
	var tables: Dictionary={"":{}}; var fonts: Array=[]; var target: Dictionary=tables[""]
	var section:=RegEx.new(); section.compile("^\\[([\\w.]+)\\]$")
	var property:=RegEx.new(); property.compile("^([\\w-]+)\\s*=\\s*(.+)$")
	var separators:=RegEx.new(); separators.compile("(?<=\\d)_(?=\\d)")
	for raw in source.trim_prefix(String.chr(65279)).split("\n"):
		var line:=""; var quote:=""; var escaped:=false
		for character in str(raw):
			if quote.is_empty() and character=="#": break
			line+=character
			if escaped: escaped=false; continue
			if character=="\\" and quote=="\"": escaped=true; continue
			if not quote.is_empty():
				if character==quote: quote=""
			elif character in ["\"","'"]: quote=character
		line=line.strip_edges()
		if line.is_empty(): continue
		if line=="[[fonts]]": target={}; fonts.append(target); continue
		var found:=section.search(line)
		if found!=null:
			var name:=found.get_string(1)
			if not tables.has(name): tables[name]={}
			target=tables[name]; continue
		found=property.search(line)
		if found==null: return reject("Unsupported original NUI skin syntax")
		var key:=found.get_string(1); var value:=found.get_string(2); var parsed: Variant
		if value.begins_with("'") and value.ends_with("'"): parsed=value.substr(1,value.length()-2)
		else:
			var json:=JSON.new()
			if json.parse(separators.sub(value,"",true))!=OK: return reject("Unsupported original NUI skin value: "+key)
			parsed=json.data
		target[key]=parsed
	return {"tables":tables,"fonts":fonts}
