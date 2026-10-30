extends RefCounted
const Tlk=preload("res://systems/native_data/talk_table.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var base:=Tlk.new()
var female:=Tlk.new()
var custom:=Tlk.new()
var custom_female:=Tlk.new()
var tables: Dictionary={}
var objects: Dictionary={}
var custom_tokens: Dictionary={}
var overrides: Dictionary={}
var named: Array=[]
var diagnostics: Array=[]
var revision:=0
func mark_changed() -> void: revision+=1
func publish_table(name: String,value: Dictionary) -> void:
	tables[name]=value; mark_changed()
func warn(reason: String) -> void:
	if not diagnostics.has(reason) and diagnostics.size()<100: diagnostics.append(reason)
func raw(value: Variant,gender: int=0) -> String:
	if value is String: return value
	if not value is Dictionary: return ""
	if value.has("text"): return str(value.text)
	var ref:=int(value.get("strRef",4294967295)); gender=int(value.get("gender",gender))
	if overrides.has(ref): return str(overrides[ref])
	if ref==4294967295 or ref<0: return ""
	var table=(custom_female if gender!=0 and custom_female.count>0 else custom) if ref&0x01000000 else (female if gender!=0 and female.count>0 else base)
	var result: Dictionary=table.entry(ref&0x00ffffff if ref&0x01000000 else ref)
	if not result.found: warn("Original TLK reference unavailable: "+str(ref))
	return str(result.text)
func name(value: Variant,id: int) -> String:
	if value==null:
		var object: Dictionary=objects.get(id,{})
		value=object.get("replicated",{}).get("name",object.get("appearance",{}).get("name",object.get("item",{}).get("name",object.get("staticState",{}).get("name",{}))))
	if value is Dictionary and (value.has("firstName") or value.has("lastName")):
		return (raw(value.get("firstName",{}))+" "+raw(value.get("lastName",{}))).strip_edges()
	return raw(value)
func import_tokens() -> void:
	named.clear()
	var table: Dictionary=tables.get("stringtokens",{}); var columns: Array=table.get("columns",[])
	if columns.size()<7: warn("Original StringTokens table is unavailable"); return
	for row in table.get("orderedRows",[]):
		var key:=str(row.get(columns[0],""))
		if not key.is_empty() and key!="****": named.append({"name":key,"hash":token_hash(key,16),"action":integer(row.get(columns[1],0)),"default":integer(row.get(columns[2],0)),"refs":[integer(row.get(columns[3],0)),integer(row.get(columns[4],0)),integer(row.get(columns[5],0)),integer(row.get(columns[6],0))]})
	named.sort_custom(func(a,b): return int(a.hash)<int(b.hash))
static func token_hash(value: String,limit: int=2147483647) -> int:
	var result:=0
	for index in mini(value.length(),limit):
		var byte:=Rich.byte_value(value.unicode_at(index))
		if byte<=0: break
		var word: int=(result^byte)&255
		for bit in 8: word=(word>>1)^(0xedb88320 if word&1 else 0)
		result=(word^(result>>8))&0xffffffff
	return result
func find_named(key: String) -> Dictionary:
	var wanted:=token_hash(key); var low:=0; var high:=named.size()
	while low<high:
		var middle: int=(low+high)>>1; var record: Dictionary=named[middle]
		if int(record.hash)>wanted: high=middle
		elif int(record.hash)<wanted: low=middle+1
		else: return record if str(record.name)==key else {}
	return {}
static func integer(value: Variant) -> int:
	var text:=str(value); return int(float(text)) if text.is_valid_float() else 0
func label(table_name: String,index: int,column: String="Name") -> String:
	var rows: Array=tables.get(table_name,{}).get("orderedRows",[])
	if index<0 or index>=rows.size() or not rows[index].has(column): warn("Original UI rule row unavailable: %s/%d/%s"%[table_name,index,column]); return ""
	return raw({"strRef":integer(rows[index][column])})
func token_value(token: Dictionary,context: Dictionary,state: Dictionary) -> String:
	var action:=int(token.action); var gender:=int(state.gender)
	if action==0: return raw({"strRef":int(token.refs[0])&0xffffffff},gender)
	if action==1: return raw({"strRef":int(token.refs[gender])&0xffffffff},gender) if gender>=0 and gender<4 else "<UNRECOGNIZED TOKEN>"
	if action>=2 and action<=14 or action==24:
		if context.is_empty() or int(context.get("objectType",0))!=5: return raw({"strRef":int(token.default)&0xffffffff},gender)
		var data: Dictionary=context.get("replicated",{}); var names: Dictionary=data.get("name",context.get("appearance",{}).get("name",{})); var stats: Dictionary=data.get("stats",{})
		var first:=raw(names.get("firstName",{}),gender); var last:=raw(names.get("lastName",{}),gender)
		if action==2: return (first+" "+last).strip_edges()
		if action==3: return first if not first.is_empty() else last
		if action==4: return last if not last.is_empty() else first
		if action in [5,6] and stats.has("racialType"): return label("racialtypes",int(stats.racialType),"ConverNameLower" if action==6 else "ConverName")
		if action in [8,9,10] and not stats.get("classes",[]).is_empty():
			var selected: Dictionary=stats.classes[0]
			return str(int(selected.level)&255) if action==10 else label("classes",int(selected.id),"Lower" if action==9 else "Name")
		# Unavailable replicated providers are explicit, never local rules or
		# fabricated character stats. These actions need their native owners.
		warn("Replicated named token provider unavailable: "+str(action)); return "<UNIMPLEMENTED TOKEN>"
	if action in [19,20]:
		state.suppression=int(state.get("nativeBC",0))
		if state.suppression!=0 or int(state.get("nativeB8",0))!=0: return ""
		return "<c"+String.chr(1 if action==19 else 254)+String.chr(254 if action==19 else 1)+String.chr(1)+">"
	if action==21: return "" if int(state.get("nativeB8",0))!=0 else "<c"+String.chr(1)+String.chr(1)+String.chr(254)+">"
	if action==22:
		var show: bool=int(state.suppression)==0 and int(state.get("nativeB8",0))==0; state.suppression=0
		return "</c>" if show else ""
	warn("Named token action unavailable: "+str(action)); return "<UNIMPLEMENTED TOKEN>"
func resolve(value: Variant,id: int,options: Dictionary={}) -> String:
	var context: Dictionary=options.get("context",objects.get(id,{})); var state:={"gender":int(context.get("appearance",{}).get("gender",0)),"suppression":0,"nativeB8":options.get("nativeB8",0),"nativeBC":options.get("nativeBC",0)}
	var input:=raw(value,int(state.gender)); var result:=""; var at:=0
	while at<input.length():
		if input[at]!="<":
			if int(state.suppression)==0: result+=input[at]
			at+=1; continue
		if input.substr(at,2)=="<<":
			if int(state.suppression)==0: result+="<"
			at+=2; continue
		var width:=Rich.color_width(input,at)
		if width>0:
			if int(state.suppression)==0: result+=input.substr(at,width)
			at+=width; continue
		var close:=input.find(">",at+1)
		if close<0: warn("Unterminated native talk token"); return result
		var key:=input.substr(at+1,close-at-1); var replacement:="<UNRECOGNIZED TOKEN>"
		if key.begins_with("CUSTOM") and key.length()>6:
			var digits:=key.substr(6); var valid:=true; var number:=0
			for code in digits.to_ascii_buffer():
				if code<48 or code>57: valid=false; break
				number=(number*10+int(code)-48)&0xffffffff
			if valid and number!=4294967295:
				var local_tokens: Dictionary=options.get("localCustomTokens",{})
				if local_tokens.has(number): replacement=str(local_tokens[number])
				elif custom_tokens.has(number): replacement=str(custom_tokens[number])
		else:
			var token:=find_named(key)
			if not token.is_empty(): replacement=token_value(token,context,state)
		result+=replacement; at=close+1
	return result
func rich(value: Variant,id: int) -> Dictionary: return Rich.parse(resolve(value,id))
func close() -> void:
	base.close(); female.close(); custom.close(); custom_female.close(); objects.clear(); custom_tokens.clear(); overrides.clear(); named.clear(); tables.clear()
