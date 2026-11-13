extends RefCounted
const Tlk=preload("res://systems/native_data/talk_table.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const RulesetCache=preload("res://systems/native_data/ruleset_cache.gd")
const NativeParser=preload("res://systems/native_data/native_talk_parser.gd")
var base:=Tlk.new()
var female:=Tlk.new()
var custom:=Tlk.new()
var custom_female:=Tlk.new()
var tables: Dictionary={}
var objects: Dictionary={}
var custom_tokens: Dictionary={}
var overrides: Dictionary={}
var named: Array=[]
var named_ready:=false
var diagnostics: Array=[]
var revision:=0
var native_families: Dictionary={}
var ruleset_owner:=RulesetCache.Owner.new()
var ruleset_publication:=0
func mark_changed() -> void: revision+=1
func publish_table(name: String,value: Dictionary) -> void:
	if name=="stringtokens":named_ready=false
	if name=="ruleset":
		ruleset_publication+=1
		var entry=ruleset_owner.prepare(value,[get_instance_id(),ruleset_publication])
		tables[name]=entry.source_view(); tables[RulesetCache.SLOT]=entry
	else: tables[name]=value
	mark_changed()
func warn(reason: String) -> void:
	if not diagnostics.has(reason) and diagnostics.size()<100: diagnostics.append(reason)
func fetch_reference(ref: int,gender: int=0) -> Dictionary:
	if overrides.has(ref):return {"found":true,"text":str(overrides[ref])}
	if ref==4294967295 or ref<0:return {"found":false,"text":""}
	var table=(custom_female if gender!=0 and custom_female.count>0 else custom) if ref&0x01000000 else (female if gender!=0 and female.count>0 else base)
	return table.entry(ref&0x00ffffff if ref&0x01000000 else ref)
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
	named.clear();named_ready=false
	var table: Dictionary=tables.get("stringtokens",{}); var columns: Array=table.get("columns",[])
	if columns.size()<7: warn("Original StringTokens table is unavailable"); return
	for row in table.get("orderedRows",[]):
		var key:=str(row.get(columns[0],""))
		if not key.is_empty() and key!="****": named.append({"name":key,"hash":token_hash(key,16),"action":integer(row.get(columns[1],0)),"default":integer(row.get(columns[2],0)),"refs":[integer(row.get(columns[3],0)),integer(row.get(columns[4],0)),integer(row.get(columns[5],0)),integer(row.get(columns[6],0))]})
	named.sort_custom(func(a,b): return int(a.hash)<int(b.hash))
	named_ready=true
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
				elif not bool(options.get("localCustomTokensComplete",false)) and custom_tokens.has(number): replacement=str(custom_tokens[number])
		else:
			var token:=find_named(key)
			if not token.is_empty(): replacement=token_value(token,context,state)
		result+=replacement; at=close+1
	return result
static func native_integer(value: Variant,minimum: int,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value))==float(value) and value>=minimum and value<=maximum
func retire_native_family(custom_family: bool) -> void:
	# Native-only load receipt; leave the legacy resource objects untouched.
	native_families[int(custom_family)]={"ready":false,"reason":"Native TLK family is awaiting its current load publication."}
func publish_native_family(custom_family: bool,female_absent: bool) -> bool:
	retire_native_family(custom_family)
	var primary=custom if custom_family else base;var selected=custom_female if custom_family else female
	if not native_file_ready(primary):return false
	if female_absent:
		# The caller has certified actual absence after the resource/file
		# lookup, not an uncompleted async request or malformed opened header.
		if selected.file!=null or not selected.bytes.is_empty():return false
		selected=primary
	elif not native_file_ready(selected):return false
	# Original OpenFile1995b0 aliases the pointer, without copying the TLK or
	# resetting gender1. Both family kinds use this exact pair loader.
	native_families[int(custom_family)]={"ready":true,"primary":primary,"female":selected,"aliased":female_absent}
	return true
static func native_file_ready(table) -> bool:
	return table.length>=20 and table.failure.is_empty() and (table.file!=null or not table.bytes.is_empty())
func fetch_native_reference(ref: Variant,gender: Variant=0) -> Dictionary:
	return native_reference_lookup(ref,gender,null)
func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selection: Dictionary) -> Dictionary:
	# A received name/header has already selected its runtime override. Read
	# the same live TLK family without borrowing a later override or mutating
	# the shared table. lookupComplete distinguishes native false/empty from
	# an unavailable file or uncertified selection.
	return native_reference_lookup(ref,gender,selection)
func native_reference_lookup(ref: Variant,gender: Variant,selection: Variant) -> Dictionary:
	# Raw native FetchInternal selection. Parsing is owned by the caller's
	# certified stage; legacy fetch_reference/resolve retain their old contract.
	var result:={"found":false,"text":"","duration":0.0,"gender":null,"override":false}
	if selection!=null:result.lookupComplete=false
	if not native_integer(ref,-2147483648,4294967295) or not native_integer(gender,0,255):
		result.reason="Native TLK reference or gender is malformed.";return result
	var id:=int(ref)&4294967295;var selected_gender:=int(gender);result.gender=selected_gender
	# Native invalid guards precede the runtime override hash lookup and return
	# a successful empty STR_RES. They do not change the retained gender byte.
	if id==4294967295 or selected_gender>1:
		result.found=true
		if selection!=null:result.lookupComplete=true
		return result
	if selection!=null and (not selection is Dictionary or not selection.get("known") is bool or selection.known!=true or not selection.get("present") is bool or selection.present and not selection.get("text") is String):
		result.reason="Native receipt-time override selection is unavailable.";return result
	var overridden: bool=selection.present if selection!=null else overrides.has(id)
	var selected_table: Variant=null;var selected_index:=0
	if not overridden:
		var is_custom: bool=(id&0x01000000)!=0
		var pair: Dictionary=native_families.get(int(is_custom),{})
		if not pair.is_empty() and not pair.get("ready",false):result.reason=str(pair.reason);return result
		var table=(custom_female if selected_gender==1 else custom) if is_custom else (female if selected_gender==1 else base)
		if not pair.is_empty():
			var primary=custom if is_custom else base;var actual_female=custom_female if is_custom else female
			if pair.primary!=primary or pair.female!=(primary if pair.aliased else actual_female) or (pair.aliased and (actual_female.file!=null or not actual_female.bytes.is_empty())):
				result.reason="Native TLK family changed before its current load publication.";return result
			table=pair.female if selected_gender==1 else pair.primary
		# A missing selected file differs from an existing empty/short female
		# file. Native only retries male for the latter's row-bounds branch.
		if table.file==null and table.bytes.is_empty():
			if is_custom:result.found=true;result.text="BadStrRef(%d)"%id
			else:result.reason="Native selected TLK file is unavailable."
			if selection!=null:result.lookupComplete=result.found
			return result
		var index: int=(id&0x00ffffff) if is_custom else id
		if selected_gender==1 and index>=table.count:
			selected_gender=0;result.gender=0
			table=custom if is_custom else base
			if table.file==null and table.bytes.is_empty():
				if is_custom:result.found=true;result.text="BadStrRef(%d)"%id
				else:result.reason="Native fallback TLK file is unavailable."
				if selection!=null:result.lookupComplete=result.found
				return result
		selected_table=table;selected_index=index
	# Keep body lookup virtual so the active owner and traced readers retain
	# one lookup boundary. Never reinterpret an in-range failure as a row miss.
	var fetched: Dictionary
	if selection==null:fetched=fetch_reference(id,selected_gender)
	elif overridden:fetched={"found":true,"text":str(selection.text)}
	else:fetched=selected_table.entry(selected_index)
	if selection!=null:result.lookupComplete=true
	result.found=fetched.get("found",false)==true;result.text=str(fetched.get("text",""));result.override=overridden
	if not overridden and (int(fetched.get("flags",0))&4)!=0:result.duration=float(fetched.get("duration",0.0))
	if not result.found:result.reason="Native selected TLK record is unavailable."
	return result
func parse_native(input: String,call_state: Dictionary={}) -> Dictionary:
	var encoded:=NativeParser.encode(input)
	if not encoded.get("ready",false):return encoded
	# This is a private call frame, not the retained global context of other UI.
	var state:={"suppression":0}
	for key in ["gender","nativeB8","nativeBC"]:
		if call_state.has(key):
			if not native_integer(call_state[key],0 if key=="gender" else -2147483648,255 if key=="gender" else 4294967295):return {"ready":false,"reason":"Native talk call state is malformed: "+key}
			state[key]=int(call_state[key])
	if call_state.has("context"):
		if not call_state.context is Dictionary:return NativeParser.pending("Native talk context is not certified.")
		state.context=call_state.context.duplicate(true)
	var providers:={"custom":call_state.get("localCustomTokens"),"customReady":call_state.get("localCustomTokensComplete")==true,"named":named,"namedReady":named_ready,"resolve":func(token,frame):return native_token_value(token,frame,call_state,0)}
	var parsed:=NativeParser.parse(encoded.bytes,state,providers)
	if not parsed.get("ready",false):return parsed
	# Received native strings are terminated. Keep exact bytes for diagnostics;
	# avoid feeding embedded NUL to Godot's Unicode string conversion.
	var visible: PackedByteArray=parsed.bytes;var zero:=visible.find(0)
	if zero>=0:visible=visible.slice(0,zero)
	parsed.body=preload("res://systems/native_data/binary_data.gd").new(visible).text(0,visible.size())
	parsed.state={"suppression":int(state.suppression)}
	if state.has("gender"):parsed.state.gender=state.gender
	return parsed
func native_fetch(ref: Variant,state: Dictionary,call_state: Dictionary,depth: int) -> Dictionary:
	if not native_integer(ref,-2147483648,4294967295):return NativeParser.pending("Native named-token reference is unavailable.")
	var id:=int(ref)&4294967295
	if id==4294967295:return {"ready":true,"bytes":PackedByteArray()}
	if not state.has("gender"):return NativeParser.pending("Native named-token gender is unavailable.")
	if int(state.gender)>1:return {"ready":true,"bytes":PackedByteArray()}
	if depth>=32:return {"ready":false,"reason":"Native token reference nesting exceeds the owned parser bound."}
	var fetched: Dictionary
	if call_state.has("nativeOverrideSelections"):
		var selections: Variant=call_state.nativeOverrideSelections
		if not selections is Dictionary or not selections.has(id):return NativeParser.pending("Native retained nested-reference override selection is unavailable.")
		if not selections[id] is Dictionary:return NativeParser.pending("Native retained nested-reference selection is malformed.")
		fetched=fetch_native_reference_snapshot(id,int(state.gender),selections[id])
	else:fetched=fetch_native_reference(id,int(state.gender))
	state.gender=fetched.gender
	if not fetched.get("found",false):return NativeParser.pending("Native named-token TLK reference is unavailable.")
	var encoded:=NativeParser.encode(str(fetched.get("text","")))
	if not encoded.get("ready",false):return encoded
	if not fetched.override:return encoded
	# Native GetTokenValue fetches with parseFlag0, but runtime overrides still
	# execute their own ParseStr. Returned replacement is not re-parsed by caller.
	var providers:={"custom":call_state.get("localCustomTokens"),"customReady":call_state.get("localCustomTokensComplete")==true,"named":named,"namedReady":named_ready,"resolve":func(token,frame):return native_token_value(token,frame,call_state,depth+1)}
	return NativeParser.parse(encoded.bytes,state,providers)
func native_literal_name(value: Variant) -> Dictionary:
	if value is String:return NativeParser.value_bytes(value)
	if value is Dictionary and value.get("text") is String:return NativeParser.value_bytes(value.text)
	return NativeParser.pending("Native literal name provider is unavailable.")
func native_token_value(token: Dictionary,state: Dictionary,call_state: Dictionary,depth: int) -> Dictionary:
	if not native_integer(token.get("action"),-2147483648,2147483647):return NativeParser.pending("Native named-token action is unavailable.")
	var action:=int(token.action);var refs: Variant=token.get("refs")
	if action==0 or action==1:
		if not refs is Array or refs.size()!=4:return NativeParser.pending("Native named-token references are unavailable.")
		if action==1 and not state.has("gender"):return NativeParser.pending("Native named-token gender is unavailable.")
		var index: int=int(state.gender) if action==1 else 0
		if index>=4:return {"ready":false,"reason":"Native named-token gender indexes uncertified record storage."}
		return native_fetch(refs[index],state,call_state,depth)
	if action>=2 and action<=14 or action==24:
		if not state.has("context"):return NativeParser.pending("Native named-token context is unavailable.")
		var context: Dictionary=state.context
		if context.is_empty():return native_fetch(token.get("default"),state,call_state,depth)
		if not native_integer(context.get("objectType"),1,4294967295):return NativeParser.pending("Native named-token object type is unavailable.")
		if int(context.objectType)!=5:return native_fetch(token.get("default"),state,call_state,depth)
		var data: Variant=context.get("replicated",{})
		if not data is Dictionary:return NativeParser.pending("Native received creature provider is unavailable.")
		if action in [2,3,4]:
			var names: Variant=data.get("name")
			if names==null and context.get("appearance") is Dictionary:names=context.appearance.get("name")
			if not names is Dictionary:return NativeParser.pending("Native received name provider is unavailable.")
			var first:=native_literal_name(names.get("firstName"));var last:=native_literal_name(names.get("lastName"))
			if action==3 and first.get("ready",false) and not first.bytes.is_empty():return first
			if action==4 and last.get("ready",false) and not last.bytes.is_empty():return last
			if not first.get("ready",false):return first
			if not last.get("ready",false):return last
			if action==3:return last
			if action==4:return first
			# FullName uses the native getter; concatenating received parts would
			# infer its spacing/override semantics. Wait for that exact provider.
			return NativeParser.pending("Native full-name getter is not certified.")
		if action==10:
			var stats: Variant=data.get("stats");var classes: Variant=stats.get("classes") if stats is Dictionary else null
			if classes is Array and not classes.is_empty() and classes[0] is Dictionary and native_integer(classes[0].get("level"),0,255):return {"ready":true,"bytes":str(int(classes[0].level)&255).to_ascii_buffer()}
		return NativeParser.pending("Native named-token creature provider is unavailable: "+str(action))
	if action in [19,20]:
		if not state.has("nativeBC"):return NativeParser.pending("Native talk BC flag is unavailable.")
		state.suppression=int(state.nativeBC)
		if int(state.suppression)!=0:return {"ready":true,"bytes":PackedByteArray()}
		if not state.has("nativeB8"):return NativeParser.pending("Native talk B8 flag is unavailable.")
		return {"ready":true,"bytes":PackedByteArray() if int(state.nativeB8)!=0 else PackedByteArray([60,99,1 if action==19 else 254,254 if action==19 else 1,1,62])}
	if action==21:
		if not state.has("nativeB8"):return NativeParser.pending("Native talk B8 flag is unavailable.")
		return {"ready":true,"bytes":PackedByteArray() if int(state.nativeB8)!=0 else PackedByteArray([60,99,1,1,254,62])}
	if action==22:
		var suppressed: bool=int(state.suppression)!=0;state.suppression=0
		if suppressed:return {"ready":true,"bytes":PackedByteArray()}
		if not state.has("nativeB8"):return NativeParser.pending("Native talk B8 flag is unavailable.")
		return {"ready":true,"bytes":"</c>".to_ascii_buffer() if int(state.nativeB8)==0 else PackedByteArray()}
	if action<0 or action>24:warn("Native GetTokenValue unknown action at line0x175: "+str(action));return {"ready":true}
	return NativeParser.pending("Native named-token provider is unavailable: "+str(action))
func rich(value: Variant,id: int) -> Dictionary: return Rich.parse(resolve(value,id))
func close() -> void:
	named_ready=false
	native_families.clear()
	ruleset_owner.retire()
	base.close(); female.close(); custom.close(); custom_female.close(); objects.clear(); custom_tokens.clear(); overrides.clear(); named.clear(); tables.clear()
