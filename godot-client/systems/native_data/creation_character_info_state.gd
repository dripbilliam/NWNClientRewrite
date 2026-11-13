extends RefCounted
# Private Character Information fields. Soundset admission comes from the
# active owner; this object never borrows actor defaults or base table IDs.
const Atoi=preload("res://systems/native_data/ruleset_cache.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
var fields:Dictionary={}
var voices:Array=[]
var by_id:Dictionary={}
var selected:Variant=null
var sample:=0
var ready:=false
var reason:=""
func reset(context:Dictionary)->void:
	ready=false;reason="";fields.clear();voices.clear();by_id.clear();selected=null;sample=0
	var value:Variant=context.get("value")
	if not value is Dictionary or not context.get("voices") is Array:reason="The current Character Information fields are unavailable.";return
	for field in ["firstName","lastName","ageText","description","deity"]:
		if not value.get(field) is String:reason="The current Character Information field is unavailable: "+field;return
	for row in context.voices:
		if not row is Dictionary or not row.get("id") is int or int(row.id)<0 or int(row.id)>65535 or not row.get("name") is String or not row.get("resRef") is String or str(row.resRef).is_empty() or by_id.has(row.id):reason="An active soundset choice is unavailable or ambiguous.";return
		by_id[row.id]=voices.size();voices.append(row.duplicate(true))
	fields=value.duplicate(true);ready=true
	if value.get("soundset") is int and by_id.has(value.soundset):selected=value.soundset
func edit(field:String,value:String)->bool:
	if not ready or field not in ["firstName","lastName","ageText","description","deity"]:return false
	fields[field]=value;return true
func voice(id:int)->Dictionary:
	if not ready or not by_id.has(id):return {"available":false}
	if selected!=id:selected=id;sample=0
	var code:=sample;sample=(sample+1)%49;fields.soundset=id
	return {"available":true,"id":id,"resRef":str(voices[by_id[id]].resRef),"sample":code}
static func native_prefix(text:String,limit:int)->Dictionary:
	# The existing native GFF writer/reader own the client byte character set.
	# CP1252 accented characters consume one original byte, not UTF8's two.
	if limit<0:return {"ready":false,"reason":"The native text limit is unavailable."}
	var encoder:=Writer.new();var encoded:=encoder.text(text)
	if not encoder.failure.is_empty():return {"ready":false,"reason":encoder.failure}
	encoded=encoded.slice(0,mini(limit,encoded.size()))
	return {"ready":true,"text":Binary.new(encoded).text(0,encoded.size()),"bytes":encoded.size()}
static func byte_prefix(text:String,limit:int)->String:
	var result:=native_prefix(text,limit)
	return str(result.text) if result.ready else ""
static func strip_colors(text:String)->String:
	# Original6e5270 searches lowercase <c first, then </c, and removes through
	# the next >. Other authored tags, case and whitespace are preserved.
	for prefix in ["<c","</c"]:
		var at:=text.find(prefix)
		while at>=0:
			var end:=text.find(">",at)
			if end<0:break
			text=text.left(at)+text.substr(end+1);at=text.find(prefix)
	return text
func snapshot()->Dictionary:return fields.duplicate(true)
func result()->Dictionary:
	if not ready:return {"available":false,"reason":reason}
	var value:=snapshot()
	for field in ["firstName","lastName","description"]:
		var encoded:=native_prefix(str(value[field]),8192 if field=="description" else 250)
		if not encoded.ready:return {"available":false,"reason":encoded.reason}
		value[field]=strip_colors(str(encoded.text))
	value.age=Atoi.atoi(str(value.ageText))
	return {"available":true,"value":value,"code":0x8007}
