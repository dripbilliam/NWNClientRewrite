extends RefCounted
# Plain-text StringGob/CAurFont fitting. Widths and spacing are GUI model units
# (100 screen pixels per unit). Glyph ownership stays with the active font.
const F=preload("res://systems/native_render/particle_math.gd")
const Bubbles=preload("res://systems/native_data/radial_text.gd")
const PIXEL:=0.01

static func align_pixel(value: float) -> float:
	return F.f(floorf(F.f(F.f(value/F.f(PIXEL))+0.5))*F.f(PIXEL))

static func measure(text: String,width: float,metrics: Dictionary,wrapping: bool,start: int=0) -> Dictionary:
	var limit:=F.f(1000000.0) if F.f(width)==0 else F.f(F.f(width)+F.f(0.000010000001))
	var running:=0.0;var extent:=0.0;var last_space:=0;var space_width:=0.0
	var glyphs: Dictionary=metrics.get("glyphs",{});var spacing:=F.f(float(metrics.get("spacing",0.0)))
	for offset in text.length()-start:
		var character:=text.substr(start+offset,1)
		if character==" ":last_space=offset;space_width=running
		running=F.f(running+F.f(float(glyphs.get(character,metrics.get("default",0.0)))))
		if limit<running or character=="\n":
			if wrapping and last_space!=0 and limit<running:
				return {"overflow":false,"visible":last_space,"width":space_width}
			return {"overflow":character!="\n" and last_space==0,"visible":offset,"width":extent}
		extent=running;running=align_pixel(F.f(running+spacing))
	return {"overflow":false,"visible":text.length()-start,"width":extent}

static func wrap_lines(text: String,width: float,metrics: Dictionary) -> Dictionary:
	var lines: Array=[];var ranges: Array=[];var start:=0;var result:=0
	while true:
		var measured:=measure(text,width,metrics,true,start)
		var consumed:=int(measured.visible)
		if text.substr(start+consumed,1)==" ":consumed+=1
		if text.substr(start+consumed,1)=="\n":consumed+=1
		if consumed==0 or consumed==text.length()-start:
			lines.append(text.substr(start));ranges.append({"start":start,"length":text.length()-start})
			result=-1 if consumed==0 and start<text.length() else 0
			break
		lines.append(text.substr(start,consumed));ranges.append({"start":start,"length":consumed});start+=consumed
	return {"lines":lines,"ranges":ranges,"wrap_result":result}

static func choose(text: String,metrics: Dictionary,line_height: float,minimum_lines: int=1,indent: float=0.0) -> Dictionary:
	var first_fit:=-1;var chosen:=-1;var prepared: Dictionary={}
	for index in 14:
		var bubble: Array=Bubbles.BUBBLES[index]
		var capacity:=int(F.f(float(bubble[1])/F.f(maxf(line_height,0.000001))))
		if minimum_lines>capacity:continue
		var width:=F.f(F.f(float(bubble[0])-indent)*F.f(0.01))
		if not prepared.has(width):
			prepared[width]=wrap_lines(text,width,metrics)
			prepared[width].overflow=measure(text,width,metrics,false).overflow
		if prepared[width].lines.size()>capacity:continue
		if first_fit<0:first_fit=index
		if not prepared[width].overflow:chosen=index;break
	if chosen<0:chosen=first_fit if first_fit>=0 else 14
	var bubble: Array=Bubbles.BUBBLES[chosen]
	var width:=F.f(F.f(float(bubble[0])-indent)*F.f(0.01))
	if not prepared.has(width):prepared[width]=wrap_lines(text,width,metrics)
	return {"bubble_index":chosen,"bubble":bubble.duplicate(),"layout":prepared[width],"width":width}

static func font_metrics(font: Font,size: int,text: String) -> Dictionary:
	# Raw advances are used only when the same opt-in font also draws at the
	# corrected prepared height. Other fonts/sizes/missing glyphs retain their
	# existing drawing-width fallback; this never shrinks old glyphs' bounds.
	var glyphs: Dictionary={}
	for index in text.length():
		var character:=text.substr(index,1)
		if glyphs.has(character):continue
		if character in ["\n","\r","\t"]: glyphs[character]=0.0
		elif font is FontFile and bool(font.get_meta("native_ttf_pixel_height",false)) and int(font.get_meta("native_ttf_pixel_height_prepared",-1))==size and font.has_char(character.unicode_at(0)):
			var glyph: int=font.get_glyph_index(size,character.unicode_at(0),0)
			glyphs[character]=F.f(font.get_glyph_advance(0,size,glyph).x*0.01)
		else: glyphs[character]=F.f(font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*0.01)
	return {"glyphs":glyphs,"default":0.0,"spacing":0.0}

static func plain(rich: Dictionary) -> String:
	if not rich.has("spans"):return str(rich.get("text",""))
	var text:=""
	for span in rich.spans:
		if span is Dictionary:text+=str(span.get("text",""))
	return text

static func display(rich: Dictionary,layout: Dictionary,width: float,metrics: Dictionary) -> Dictionary:
	var spans: Array=rich.get("spans",[{"text":rich.get("text","")}]);var output: Array=[];var text:=""
	var span_index:=0;var span_start:=0
	for index in layout.ranges.size():
		var range_value: Dictionary=layout.ranges[index];var begin:=int(range_value.start)
		var shown:=int(measure(str(layout.lines[index]),width,metrics,false).visible);var end:=begin+shown
		while span_index<spans.size() and span_start+str(spans[span_index].get("text","")).length()<=begin:
			span_start+=str(spans[span_index].get("text","")).length();span_index+=1
		var cursor:=span_index;var cursor_start:=span_start
		while cursor<spans.size() and cursor_start<end:
			var span: Dictionary=spans[cursor];var value:=str(span.get("text",""));var stop:=mini(end,cursor_start+value.length())
			if stop>maxi(begin,cursor_start):
				var part:=value.substr(maxi(0,begin-cursor_start),stop-maxi(begin,cursor_start));var row:={"text":part}
				if span.has("color"):row.color=span.color
				output.append(row);text+=part
			cursor_start+=value.length();cursor+=1
		if index+1<layout.ranges.size():output.append({"text":"\n"});text+="\n"
	return {"text":text,"spans":output}
