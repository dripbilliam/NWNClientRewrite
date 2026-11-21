extends RefCounted
# Original CAurFontInfo TXI metrics. Data only; GPU/font objects publish later.
const ScriptBytes=preload("res://systems/native_data/native_script_string.gd")
var failure:=""
func reject(reason: String) -> Dictionary: failure=reason; return {}
func parse(text: String) -> Dictionary:
	failure=""
	var values: Dictionary={}; var coordinates: Dictionary={}; var lines: Array=[]; var cursor:=0
	for source in text.replace("\r\n","\n").split("\n"):
		var line:=str(source).strip_edges()
		if not line.is_empty():lines.append(line)
	var regex:=RegEx.new(); regex.compile("\\s+")
	while cursor<lines.size():
		var line:=str(lines[cursor]).strip_edges(); cursor+=1
		if line.is_empty(): continue
		var words: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(line,regex); var key:=str(words[0]).to_lower()
		if key in ["upperleftcoords","lowerrightcoords"]:
			if words.size()<2 or not words[1].is_valid_int() or int(words[1])<1 or int(words[1])>65536: return reject("Invalid native font coordinate count")
			var rows: Array=[]
			for index in int(words[1]):
				if cursor>=lines.size(): return reject("Invalid native font coordinate")
				var row: PackedStringArray=preload("res://systems/native_data/binary_data.gd").ascii_tokens(str(lines[cursor]).strip_edges(),regex); cursor+=1
				if row.size()!=3: return reject("Invalid native font coordinate")
				var point: Array=[]
				for component in row:
					if not component.is_valid_float() or not is_finite(float(component)): return reject("Invalid native font coordinate")
					point.append(float(component))
				rows.append(point)
			coordinates[key]=rows
		else:
			values[key]=float(words[1]) if words.size()>1 and words[1].is_valid_float() else NAN
	var count_value:=float(values.get("numchars",NAN))
	if not is_finite(count_value) or count_value!=floorf(count_value) or count_value<1 or count_value>65536:return reject("Native font glyph metrics are incomplete")
	var count:=int(count_value)
	if coordinates.get("upperleftcoords",[]).size()!=count or coordinates.get("lowerrightcoords",[]).size()!=count: return reject("Native font glyph metrics are incomplete")
	for key in ["fontheight","baselineheight","texturewidth"]:
		if not values.has(key) or not is_finite(float(values[key])): return reject("Native font dimensions are unavailable")
	if float(values.fontheight)<=0 or float(values.texturewidth)<=0: return reject("Native font dimensions are unavailable")
	var spacing_r:=float(values.get("spacingr",0))*100.0; var spacing_b:=float(values.get("spacingb",0))*100.0
	return {"count":count,"height":float(values.fontheight)*100.0,"baseline":float(values.baselineheight)*100.0,"width":float(values.texturewidth)*100.0,"spacingR":spacing_r,"spacingB":spacing_b,"spacing_r":spacing_r,"spacing_b":spacing_b,"upper":coordinates.upperleftcoords,"lower":coordinates.lowerrightcoords}
func glyph(metrics: Dictionary,index: int,width: int,height: int) -> Dictionary:
	var missing:=index>=int(metrics.count)
	if missing:index=0
	if index<0 or width<1 or height<1:return reject("Native font glyph is outside its atlas")
	var upper: Array=metrics.upper[index];var lower: Array=metrics.lower[index]
	var scale:=float(metrics.width)/float(width)
	var sx:=int(floorf(float(upper[0])*width+0.5));var sy:=int(floorf((1.0-float(upper[1]))*height+0.5))
	var sw:=int(floorf((float(lower[0])-float(upper[0]))*width+0.5));var sh:=int(floorf((float(upper[1])-float(lower[1]))*height+0.5))
	if sw<0 or sh<0 or sx<0 or sy<0 or sx+sw>width or sy+sh>height:return reject("Native font glyph is outside its atlas")
	return {"sx":sx,"sy":sy,"sw":sw,"sh":sh,"width":sw*scale,"height":sh*scale,"advance":sw*scale+float(metrics.get("spacingR",metrics.get("spacing_r",0.0))),"missing":missing}
func glyphs(metrics: Dictionary,width: int,height: int) -> Array:
	failure=""
	var output: Array=[]
	for index in int(metrics.count):
		var item:=glyph(metrics,index,width,height)
		if not failure.is_empty():return []
		output.append({"rect":Rect2(item.sx,item.sy,item.sw,item.sh),"size":Vector2(item.width,item.height),"advance":float(item.advance)})
	return output
func render(metrics: Dictionary,width: int,height: int,spans: Array,default_color: String="#ffffff") -> Dictionary:
	failure=""
	var entries: Array=[];var x:=0.0;var y:=0.0;var line_width:=0.0;var missing:=0
	for span in spans:
		var encoded: Dictionary=ScriptBytes.bytes(str(span.get("text","")))
		if encoded.has("error"):return reject(str(encoded.error))
		for byte in encoded.value:
			if int(byte)==10:
				line_width=maxf(line_width,x);x=0.0;y+=float(metrics.height)+float(metrics.spacingB);continue
			var item:=glyph(metrics,int(byte),width,height)
			if not failure.is_empty():return {}
			if item.missing:missing+=1
			item.x=x;item.y=y;item.color=default_color if span.get("color")==null else str(span.color)
			entries.append(item);x+=float(item.advance)
	line_width=maxf(line_width,x)
	return {"glyphs":entries,"width":maxi(1,ceili(line_width)),"height":maxi(1,ceili(y+float(metrics.height))),"baseline":float(metrics.baseline),"missing":missing}
