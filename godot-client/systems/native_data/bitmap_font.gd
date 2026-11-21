extends RefCounted
# Original CAurFontInfo TXI metrics. Data only; GPU/font objects publish later.
const F=preload("res://systems/native_render/particle_math.gd")
var failure:=""
func reject(reason: String) -> Dictionary: failure=reason; return {}
func parse(text: String) -> Dictionary:
	failure=""
	if text.length()>8*1024*1024: return reject("Original bitmap-font metadata exceeds bounds")
	var values: Dictionary={}; var coordinates: Dictionary={}; var lines:=text.replace("\r","").split("\n"); var cursor:=0
	var regex:=RegEx.new(); regex.compile("\\s+")
	while cursor<lines.size():
		var line:=str(lines[cursor]).strip_edges(); cursor+=1
		if line.is_empty() or line.begins_with("#") or line.begins_with("//"): continue
		var words: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(line,regex); var key:=str(words[0]).to_lower()
		if key in ["upperleftcoords","lowerrightcoords"]:
			if words.size()!=2 or not words[1].is_valid_int() or int(words[1])<1 or int(words[1])>65536: return reject("Invalid original bitmap-font coordinate count")
			if coordinates.has(key): return reject("Duplicate original bitmap-font coordinate table")
			var rows: Array=[]
			for index in int(words[1]):
				while cursor<lines.size() and (str(lines[cursor]).strip_edges().is_empty() or str(lines[cursor]).strip_edges().begins_with("#")): cursor+=1
				if cursor>=lines.size(): return reject("Truncated original bitmap-font coordinates")
				var row: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(str(lines[cursor]).strip_edges(),regex); cursor+=1
				if row.size()!=3: return reject("Invalid original bitmap-font coordinate shape")
				var point: Array=[]
				for component in row:
					if not component.is_valid_float() or not is_finite(float(component)): return reject("Non-finite original bitmap-font coordinate")
					point.append(F.f(float(component)))
				rows.append(point)
			coordinates[key]=rows
		elif key in ["numchars","fontheight","baselineheight","texturewidth","spacingr","spacingb","caretindent","isdoublebyte"]:
			if words.size()!=2 or not words[1].is_valid_float() or not is_finite(float(words[1])): return reject("Invalid original bitmap-font metric")
			values[key]=F.f(float(words[1]))
	var count:=int(values.get("numchars",0))
	if count<1 or count>65536 or count!=values.get("numchars") or coordinates.get("upperleftcoords",[]).size()!=count or coordinates.get("lowerrightcoords",[]).size()!=count: return reject("Original bitmap-font glyph metrics are incomplete")
	for key in ["fontheight","baselineheight","texturewidth"]:
		if not values.has(key) or absf(float(values[key]))>327.68: return reject("Original bitmap-font dimensions are unavailable")
	if float(values.fontheight)<=0 or float(values.texturewidth)<=0: return reject("Invalid original bitmap-font dimensions")
	if values.get("isdoublebyte",0)!=0: return reject("Original double-byte bitmap-font mapping requires its separate atlas consumer")
	return {"count":count,"height":F.f(float(values.fontheight)*100.0),"baseline":F.f(float(values.baselineheight)*100.0),"width":F.f(float(values.texturewidth)*100.0),"spacing_r":F.f(float(values.get("spacingr",0))*100.0),"spacing_b":F.f(float(values.get("spacingb",0))*100.0),"upper":coordinates.upperleftcoords,"lower":coordinates.lowerrightcoords}
func glyphs(metrics: Dictionary,width: int,height: int) -> Array:
	if width<1 or height<1 or width>32768 or height>32768: failure="Invalid original bitmap-font atlas dimensions"; return []
	var output: Array=[]
	for index in int(metrics.count):
		var upper: Array=metrics.upper[index]; var lower: Array=metrics.lower[index]
		var left:=float(upper[0])*width; var top:=(1.0-float(upper[1]))*height; var w:=(float(lower[0])-float(upper[0]))*width; var h:=(float(upper[1])-float(lower[1]))*height
		# Original TXIs round UVs to six decimals; accept only that subpixel
		# representation error at an atlas edge, never a real out-of-range glyph.
		if minf(left,top)<-0.01 or minf(w,h)<-0.01 or left+w>width+0.01 or top+h>height+0.01: failure="Original bitmap-font glyph exceeds its atlas"; return []
		var glyph_width:=F.f(F.f(float(lower[0])-float(upper[0]))*F.f(float(metrics.width)))
		output.append({"rect":Rect2(maxf(0,left),maxf(0,top),maxf(0,w),maxf(0,h)),"size":Vector2(glyph_width,float(metrics.height)),"advance":floorf(F.f(glyph_width+float(metrics.spacing_r))+0.5)})
	return output
