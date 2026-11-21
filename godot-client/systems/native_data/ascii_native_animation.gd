extends RefCounted
# Bounded data adapter into the existing NativeRuns/NativePose schema.
# It retains absent animation controllers as absent: no invented rest keys.
const Emitter=preload("res://systems/native_data/emitter_data.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Orientation=preload("res://systems/native_data/model_orientation.gd")
const LIMIT_NODES=256
const LIMIT_ROWS=65535
var failure:=""

func reject(reason: String) -> Dictionary:
	if failure.is_empty():failure=reason
	return {"available":false,"reason":failure}

static func _f(value: float) -> float:return Color(value,0,0,0).r
static func _js_number(token: String) -> float:
	var value:=token.strip_edges()
	if value.is_empty():return 0.0
	if value.length()>2 and value[0]=="0" and value[1].to_lower() in ["x","b","o"]:
		var radix: int={"x":16,"b":2,"o":8}[value[1].to_lower()]
		var number:=0.0
		for at in range(2,value.length()):
			var code:=value.unicode_at(at);var digit:=-1
			if code>=48 and code<=57:digit=code-48
			elif code>=65 and code<=70:digit=code-65+10
			elif code>=97 and code<=102:digit=code-97+10
			if digit<0 or digit>=radix:return NAN
			number=number*radix+digit
		return number
	return float(value) if value.is_valid_float() else NAN
static func _values(value: Variant,count: int) -> bool:
	return value is Array and value.size()==count and value.all(func(item):return (item is float or item is int) and is_finite(float(item)) and is_finite(_f(float(item))))
static func _empty(id: int,flags: int) -> Dictionary:
	return {"id34":id,"flags98":flags,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"valueCount90":0,"children68":[],"childCount70":0}

func _append(node: Dictionary,offset: int,components: int,frames: Array,bezier: bool=false) -> bool:
	if frames.is_empty():return true # Native AddGenericController omits zero rows.
	var pool: PackedFloat32Array=node.values88
	var stride:=components*(3 if bezier else 1)
	if frames.size()>LIMIT_ROWS or pool.size()+frames.size()*(1+stride)>LIMIT_ROWS:reject("ASCII native controller pool exceeds WORD bounds");return false
	var times:=pool.size();var previous:=-1.0
	for frame in frames:
		if not frame is Array or frame.size()!=stride+1:
			reject("ASCII native controller shape is unavailable");return false
		for value in frame:
			if not (value is float or value is int) or not is_finite(float(value)):reject("ASCII native controller value is non-finite");return false
		var time:=_f(float(frame[0]))
		if not is_finite(time) or time<0 or time<previous:reject("ASCII native controller times are unordered, negative or exceed f32");return false
		previous=time;pool.append(time)
	var values:=pool.size()
	for frame in frames:
		for at in stride:
			var value:=_f(float(frame[at+1]))
			if not is_finite(value):reject("ASCII native controller value exceeds f32");return false
			pool.append(value)
	node.controllers78.append({"displacement0":offset,"rows4":frames.size(),"timeIndex6":times,"valueIndex8":values,"columnsA":components|(16 if bezier else 0),"paddingB":0})
	node.controllerCount80=node.controllers78.size();node.values88=pool;node.valueCount90=pool.size()
	return true

func _single(node: Dictionary,offset: int,values: Array) -> bool:
	var frame: Array=[0.0];frame.append_array(values);return _append(node,offset,values.size(),[frame])

static func _channel(kind: String,property: String) -> Dictionary:
	if property=="position":return {"offset":16,"components":3}
	if property=="orientation":return {"offset":28,"components":4}
	if property=="scale":return {"offset":44,"components":1}
	if kind=="trimesh":
		if property=="alpha":return {"offset":168,"components":1}
		if property=="selfillumcolor":return {"offset":128,"components":3}
	if kind=="light":
		return {"color":{"offset":104,"components":3},"radius":{"offset":116,"components":1},"shadowradius":{"offset":124,"components":1},"verticaldisplacement":{"offset":128,"components":1},"multiplier":{"offset":168,"components":1}}.get(property,{})
	if kind=="emitter":
		# Byte percentage setters have a distinct original lower; do not encode
		# them as float writes into overlapping packed Part fields.
		if property.begins_with("percent"):return {}
		for offset in Emitter.FIELDS:
			if Emitter.FIELDS[offset]==property:return {"offset":int(offset),"components":Emitter.components(property)}
	return {}

func prepare(text: String,model: Dictionary,sources: Array) -> Dictionary:
	failure=""
	if text.length()>8*1024*1024:return reject("ASCII native source exceeds explicit text bound")
	if model.get("format")!="ASCII MDL":return reject("Not an original ASCII model")
	if not str(model.get("supermodel","")).to_lower() in ["","null"]:return reject("ASCII inherited native controller reconstruction unavailable")
	var physical: Variant=model.get("nodes")
	if not physical is Array or physical.is_empty() or physical.size()>LIMIT_NODES or sources.size()!=physical.size():return reject("ASCII physical/source-node mapping unavailable")
	var names: Dictionary={};var parts: Array=[];var root:=-1
	for at in physical.size():
		var row: Variant=physical[at]
		if not row is Dictionary or row.get("source_index")!=at or not sources[at] is Dictionary:return reject("ASCII split/reordered physical node unsupported")
		var source: Dictionary=sources[at];var name:=str(row.get("name","")).to_lower();var kind:=str(source.get("kind",""))
		if not _values(row.get("position"),3) or not _values(row.get("orientation"),4) or not _values([row.get("scale")],1) or not _values([row.get("alpha")],1) or not _values(row.get("selfillum"),3):return reject("ASCII static native fields unavailable/non-finite")
		if name.is_empty() or names.has(name) or name!=str(source.get("name","")).to_lower():return reject("ASCII physical names are empty or ambiguous")
		if not kind in ["dummy","reference","emitter","trimesh","light"]:return reject("ASCII native Part subtype unavailable: "+kind)
		if row.has("skin") or row.has("vertex_animation"):return reject("ASCII skin/animated vertex native reconstruction unavailable")
		var flags: int={"dummy":1,"reference":17,"emitter":5,"trimesh":33,"light":3}[kind]
		var node:=_empty(at,flags)
		if not _single(node,16,row.position) or not _single(node,28,row.orientation) or not _single(node,44,[row.scale]):return reject(failure)
		if kind=="trimesh":
			if not _single(node,168,[row.alpha]) or not _single(node,128,row.selfillum):return reject(failure)
		if kind=="light":
			var light: Dictionary=row.get("light",{})
			var color: Variant=light.get("color",[1.0,1.0,1.0])
			if not _values(color,3):return reject("ASCII static light color unavailable/non-finite")
			if not _single(node,104,color) or not _single(node,116,[light.get("radius",0.0)]) or not _single(node,124,[light.get("shadowradius",0.0)]) or not _single(node,128,[light.get("verticaldisplacement",0.0)]) or not _single(node,168,[light.get("multiplier",1.0)]):return reject(failure)
		# Other emitter inputs keep their existing canonical particle owner.
		# Authored animation emitter channels below still use native controllers.
		var type: String="trimesh" if kind=="trimesh" else "emitter" if kind=="emitter" else "light" if kind=="light" else "dummy"
		parts.append({"type":type,"properties":row.get("light",{}) if kind=="light" else row.get("emitter",{}),"transparencyHint":float(row.get("alpha",1.0))<1.0,"node":node,"children":[]})
		names[name]=at
	for at in physical.size():
		var parent: Variant=physical[at].get("parent")
		if not parent is int or parent< -1 or parent>=at:return reject("ASCII physical parent order unavailable")
		if parent<0:
			if root>=0:return reject("ASCII physical roots are ambiguous")
			root=at
		else:parts[parent].children.append(at)
	if root<0:return reject("ASCII physical root unavailable")
	var lines:=text.replace("\r","").split("\n");var regex:=RegEx.new();regex.compile("\\s+")
	var clips: Dictionary={};var clip: Dictionary={};var active: Dictionary={};var index:=0;var channels:=0
	while index<lines.size():
		var line:=str(lines[index]).strip_edges();index+=1
		if line.is_empty() or line.begins_with("#"):continue
		var tokens:=Binary.ascii_tokens(line,regex)
		if tokens.is_empty():continue
		var command:=tokens[0].to_lower()
		if command=="newanim":
			if not clip.is_empty() or tokens.size()!=3:return reject("ASCII native clip declaration malformed")
			var name:=str(tokens[1]).to_lower()
			if clips.has(name) or clips.size()>=256:return reject("ASCII native clip names/count unavailable")
			clip={"name":name,"nodes":[],"animroot":str(tokens[2]).to_lower()};active={};continue
		if clip.is_empty():continue
		if command=="doneanim":
			if not active.is_empty():return reject("ASCII native clip node unterminated")
			var built:=_clip_tree(clip,physical,names,root)
			if not failure.is_empty():return reject(failure)
			clips[clip.name]={"root":built};clip={};continue
		if command=="animroot":
			if tokens.size()!=2:return reject("ASCII native animroot malformed")
			clip.animroot=str(tokens[1]).to_lower();continue
		if command=="node":
			if tokens.size()!=3 or not active.is_empty() or clip.nodes.size()>=LIMIT_NODES:return reject("ASCII native clip node declaration malformed")
			var name:=str(tokens[2]).to_lower()
			var at: int=names.get(name,-1);var kind:=str(tokens[1]).to_lower()
			if not kind in ["dummy","reference","emitter","trimesh","light"]:return reject("ASCII native clip subtype unavailable")
			if at>=0 and kind!=str(sources[at].kind):return reject("ASCII native clip/physical subtype mismatch")
			var flags: int={"dummy":1,"reference":17,"emitter":5,"trimesh":33,"light":3}[kind]
			# SynchronizeNodes assigns -1 to unmatched direct children. Such a
			# branch is unreachable from the physical hierarchy; never invent it.
			active={"name":name,"parent":"","kind":kind,"matched":at>=0,"storage":_empty(at,flags)};clip.nodes.append(active);continue
		if command=="endnode":active={};continue
		if active.is_empty():continue
		if command=="parent":
			if tokens.size()!=2:return reject("ASCII native clip parent malformed")
			active.parent=str(tokens[1]).to_lower();continue
		var bezier:=command.ends_with("bezierkey");var keyed:=command.ends_with("key")
		var property:=command.trim_suffix("bezierkey") if bezier else command.trim_suffix("key")
		var channel:=_channel(active.kind,property)
		if channel.is_empty():
			if keyed:return reject("ASCII native controller unavailable: "+command)
			continue # Non-controller field/default is not an animation key.
		if bezier and property=="orientation":return reject("ASCII Bezier quaternion unavailable")
		var components: int=channel.components;var frames: Array=[]
		var count:=1;var uncounted:=false
		if keyed:
			if tokens.size()==1:uncounted=true;count=100000
			elif tokens.size()==2:
				var parsed_count:=_js_number(tokens[1])
				if not is_finite(parsed_count) or parsed_count<0 or parsed_count>100000 or parsed_count!=floorf(parsed_count):return reject("ASCII native controller count malformed")
				count=int(parsed_count)
			else:return reject("ASCII native controller count malformed")
		if not uncounted and count>LIMIT_ROWS:return reject("ASCII native controller count exceeds WORD bounds")
		var ended:=false
		for key in count:
			var values: PackedStringArray=tokens.slice(1)
			if keyed:
				while index<lines.size() and (str(lines[index]).strip_edges().is_empty() or str(lines[index]).strip_edges().begins_with("#")):index+=1
				if index>=lines.size():return reject("ASCII native controller list truncated")
				var next:=str(lines[index]).strip_edges();index+=1
				if uncounted and next.to_lower()=="endlist":ended=true;break
				values=Binary.ascii_tokens(next,regex)
			else:values.insert(0,"0")
			if values.size()!=1+components*(3 if bezier else 1):return reject("ASCII native controller component count malformed")
			var frame: Array=[]
			for value in values:
				var number:=_js_number(value)
				if not is_finite(number):return reject("ASCII native controller number invalid")
				frame.append(number if property=="orientation" else _f(number))
			if property=="orientation":
				var quaternion: Array=Orientation.decode(frame.slice(1,5),"axis-angle")
				frame=[_f(float(frame[0]))]
				for component in quaternion:frame.append(_f(float(component)))
			frames.append(frame)
		if uncounted and not ended:return reject("ASCII native controller missing endlist")
		if not _append(active.storage,int(channel.offset),components,frames,bezier):return reject(failure)
		channels+=1
	if not clip.is_empty():return reject("ASCII native clip unterminated")
	if clips.is_empty():return reject("ASCII model has no native animation clips")
	return {"available":true,"value":{"version":1,"root":root,"parts":parts,"clips":clips,"emitterFields":Emitter.FIELDS,"source":"original-ascii-linear-native-v1","authored_channels":channels}}

func _clip_tree(clip: Dictionary,physical: Array,names: Dictionary,root: int) -> Dictionary:
	if clip.animroot!=str(physical[root].name).to_lower():reject("ASCII native non-root animroot unsupported");return {}
	var by_name: Dictionary={};var output: Dictionary={}
	for node in clip.nodes:
		if not node.matched:continue
		if by_name.has(node.name):reject("ASCII native clip names ambiguous");return {}
		by_name[node.name]=node
	for node in clip.nodes:
		if not node.matched:continue
		var expected: int=physical[int(names[node.name])].parent
		if expected<0:
			if node.parent!="null" or not output.is_empty():reject("ASCII native clip root malformed");return {}
			output=node.storage
		elif not by_name.has(node.parent) or node.parent!=str(physical[expected].name).to_lower():reject("ASCII native clip parent differs from physical hierarchy");return {}
		else:
			var parent: Dictionary=by_name[node.parent].storage
			parent.children68.append(node.storage);parent.childCount70=parent.children68.size()
	if output.is_empty():reject("ASCII native clip root unavailable")
	return output
