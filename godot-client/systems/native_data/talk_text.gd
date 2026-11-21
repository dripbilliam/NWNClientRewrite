extends RefCounted
const Tlk=preload("res://systems/native_data/talk_table.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const ScriptString=preload("res://systems/native_data/native_script_string.gd")
const RulesetCache=preload("res://systems/native_data/ruleset_cache.gd")
const NativeParser=preload("res://systems/native_data/native_talk_parser.gd")
const ServerTokens=preload("res://systems/native_data/native_custom_token_table.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")
var base:=Tlk.new()
var female:=Tlk.new()
var custom:=Tlk.new()
var custom_female:=Tlk.new()
var tables: Dictionary={}
var objects: Dictionary={}
var players: Dictionary={}
var custom_tokens: Dictionary={}
var network_raw_cache: Dictionary={}
var network_table_request: Callable
var network_diagnostic: Callable
var network_table_pending: Dictionary={}
var network_table_errors: Dictionary={}
var network_last_error: String=""
var server_tokens=ServerTokens.new()
var overrides: Dictionary={}
var native_override_bytes: Dictionary={}
var named: Array=[]
var named_ready:=false
var network_token_error: String=""
var diagnostics: Array=[]
var revision:=0
var native_families: Dictionary={}
var ruleset_owner:=RulesetCache.Owner.new()
var ruleset_publication:=0
func mark_changed() -> void: revision+=1;network_raw_cache.clear()
func apply_server_token(id: int,bytes: PackedByteArray) -> Dictionary:
	if not server_tokens.apply(id,bytes):return {"applied":false,"reason":"Native custom-token ID is ignored."}
	var projected: Dictionary=server_tokens.project_ui(id,base.language)
	# Existing speech/tooltip consumers capture this dictionary by value. Only
	# safely decoded UI text enters it; the exact native bytes remain in table.
	if projected.get("ready",false):custom_tokens[id]=projected.text
	else:
		custom_tokens.erase(id)
		warn(str(projected.get("reason","Native custom-token text is unavailable.")))
	mark_changed()
	return {"applied":true,"projected":projected.get("ready",false),"revision":server_tokens.revision}
func network_token(id: int,value: Variant) -> Dictionary:
	var encoded:Dictionary=ScriptString.bytes(value)
	if encoded.has("error"):return {"applied":false,"error":encoded.error}
	return apply_server_token(id,encoded.value)
func reset_server_tokens() -> void:
	server_tokens.reset();custom_tokens.clear();mark_changed()
func server_token_snapshot() -> Array[Dictionary]:return server_tokens.snapshot()
func publish_table(name: String,value: Dictionary) -> void:
	network_table_pending.erase(name);network_table_errors.erase(name)
	if name=="stringtokens":named_ready=false
	if name=="ruleset":
		ruleset_publication+=1
		var entry=ruleset_owner.prepare(value,[get_instance_id(),ruleset_publication])
		if not entry.failure.is_empty():
			publish_table_error(name,entry.failure)
			return
		tables[name]=entry.source_view(); tables[RulesetCache.SLOT]=entry
		for label in entry.duplicates():
			if diagnostics.size()>=100:break
			diagnostics.append({"code":"rules.duplicate-ruleset-entry","reason":"Duplicate ruleset.2da entry: "+label,"resource":"ruleset","label":label})
	else: tables[name]=value
	mark_changed()
func publish_table_error(name: String,reason: String) -> void:
	network_table_pending.erase(name);network_table_errors[name]=reason
	if name=="stringtokens":named_ready=false;network_token_error=reason
	tables[name]={};mark_changed()
func network_table(name: String) -> Dictionary:
	if network_table_errors.has(name):return {"ready":false,"error":str(network_table_errors[name])}
	if tables.has(name):
		var source: Variant=tables[name]
		return {"ready":true,"value":source} if source is Dictionary and source.get("orderedRows") is Array else {"ready":false,"error":"Native network table is unavailable: "+name}
	if not network_table_pending.has(name):
		if not network_table_request.is_valid():return {"ready":false,"error":"Native network table request owner is unavailable: "+name}
		network_table_pending[name]=true;network_table_request.call(name)
	return {"ready":false,"pending":true,"reason":"Native network table is pending: "+name}
func warn(reason: String) -> void:
	if not diagnostics.has(reason) and diagnostics.size()<100: diagnostics.append(reason)
func token_diagnostic(reason: String,context: Dictionary) -> void:
	if diagnostics.size()>=100:return
	var event: Dictionary={"code":"network.text-token-unhandled","reason":reason}
	event.merge(context)
	diagnostics.append(event)
func fetch_reference(ref: int,gender: int=0) -> Dictionary:
	if overrides.has(ref):return {"found":true,"text":str(overrides[ref])}
	if ref==4294967295 or ref<0:return {"found":false,"text":""}
	var table=(custom_female if gender!=0 and custom_female.count>0 else custom) if ref&0x01000000 else (female if gender!=0 and female.count>0 else base)
	return table.entry(ref&0x00ffffff if ref&0x01000000 else ref)
func raw(value: Variant,gender: int=0) -> String:
	if value is String: return value
	if not value is Dictionary: return ""
	if value.has("text"): return str(value.text)
	gender=int(value.get("gender",gender))
	var entries: Variant=value.get("entries")
	if entries is Array:
		for wanted in [base.language*2+int(gender!=0),base.language*2]:
			for entry in entries:
				if entry is Dictionary and entry.get("languageId") is int and int(entry.languageId)==wanted:return str(entry.get("text",""))
	var alternate: String=""
	if value.get("AurString_Text") is String:alternate=str(value.AurString_Text)
	elif entries is Array and not entries.is_empty() and entries[0] is Dictionary:alternate=str(entries[0].get("text",""))
	var reference: Variant=value.get("strRef",value.get("Obj_StrRef",4294967295))
	if not native_integer(reference,-2147483648,4294967295):return alternate
	var ref:=int(reference)
	if ref==4294967295 or ref<0: return alternate
	if overrides.has(ref): return str(overrides[ref])
	var key:String=str(ref)+":"+str(gender)
	if network_raw_cache.has(key):
		var cached: Dictionary=network_raw_cache[key]
		return str(cached.text) if cached.found else alternate
	var table=(custom_female if gender!=0 and custom_female.count>0 else custom) if ref&0x01000000 else (female if gender!=0 and female.count>0 else base)
	var result: Dictionary=table.entry(ref&0x00ffffff if ref&0x01000000 else ref)
	if not result.found: warn("Original TLK reference unavailable: "+str(ref))
	network_raw_cache[key]={"found":bool(result.found),"text":str(result.text)}
	return str(result.text) if result.found else alternate
func network_raw(value: Variant,gender: int=0) -> String:
	# Old NetworkText.raw receives literal or reference-only wire values. Its
	# talkString bridge decodes native bytes as CP1252, even for other TLK IDs.
	if not value is Dictionary:return ""
	if value.has("text"):return str(value.text)
	var reference: Variant=value.get("strRef")
	if not reference is int or int(reference)==0xffffffff:return ""
	var selected: Variant=value.get("gender",gender)
	if selected==null:selected=gender
	var fetched:=talk_string(int(reference),selected)
	if fetched.has("error"):warn(str(fetched.error))
	return str(fetched.text)
func name(value: Variant,id: int) -> String:
	if value==null:
		var object: Dictionary=objects.get(id,{})
		value=object.get("replicated",{}).get("name",object.get("appearance",{}).get("name",object.get("item",{}).get("name",object.get("staticState",{}).get("name",{}))))
	if value is Dictionary and (value.has("firstName") or value.has("lastName")):
		return (raw(value.get("firstName",{}))+" "+raw(value.get("lastName",{}))).strip_edges()
	return raw(value)
func import_tokens() -> void:
	named.clear();named_ready=false;network_token_error=""
	var table: Dictionary=tables.get("stringtokens",{}); var source_columns: Variant=table.get("columns")
	if not table.get("orderedRows") is Array or not source_columns is Array:
		network_token_error="Native StringTokens table is unavailable";warn(network_token_error);return
	var columns: Array=source_columns
	var row_index:=0
	for row in table.get("orderedRows",[]):
		var key:=str(row.get(columns[0],"")) if row is Dictionary and not columns.is_empty() else ""
		if key=="****":key=""
		var name_bytes:Dictionary=ScriptString.bytes(key)
		if name_bytes.has("error"):network_token_error=str(name_bytes.error);warn(network_token_error);return
		var numbers: Array=[]
		for column_index in range(1,7):
			var field: Dictionary=network_rule_ref("stringtokens",row_index,str(columns[column_index])) if column_index<columns.size() else {"found":false}
			if not field.get("found",false):
				network_token_error="Native StringTokens numeric field import is unavailable at row%d/column%d"%[row_index,column_index];warn(network_token_error);return
			numbers.append(int(field.ref))
		named.append({"name":key,"hash":NativeParser.hash_bytes(name_bytes.value,16),"action":numbers[0],"default":numbers[1],"refs":numbers.slice(2,6),"sourceRow":row_index})
		row_index+=1
	# Array.sort in the old loader is stable for equal hashes.
	named.sort_custom(func(a,b): return int(a.hash)<int(b.hash) if int(a.hash)!=int(b.hash) else int(a.sourceRow)<int(b.sourceRow))
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
static func network_rule_number(value: Variant) -> int:
	var source:=str(value)
	var hex:=source.begins_with("0x") or source.begins_with("0X")
	var at:=2 if hex else 0
	if not hex:
		while at<source.length() and source[at] in [" ","\t","\r","\n"]:at+=1
	var sign:=1
	if not hex and at<source.length() and source[at] in ["+","-"]:
		if source[at]=="-":sign=-1
		at+=1
	var result:=0
	while at<source.length():
		var code:=source.unicode_at(at);var digit:=-1
		if code>=48 and code<=57:digit=code-48
		elif hex and code>=65 and code<=70:digit=code-55
		elif hex and code>=97 and code<=102:digit=code-87
		if digit<0 or digit>=(16 if hex else 10):break
		result=(result*(16 if hex else 10)+digit)&0xffffffff;at+=1
	return (result*sign)&0xffffffff
func network_rule_ref(table_name: String,index: int,column: String) -> Dictionary:
	var rows: Array=tables.get(table_name,{}).get("orderedRows",[])
	if index<0 or index>=rows.size() or not rows[index] is Dictionary:return {"found":false}
	var row: Dictionary=rows[index]
	for key in row:
		if str(key).to_lower()!=column.to_lower():continue
		var value: String=str(row[key])
		if value.is_empty() or value=="****":return {"found":false}
		return {"found":true,"ref":network_rule_number(value)}
	return {"found":false}
func token_value(token: Dictionary,context: Dictionary,state: Dictionary) -> String:
	var action:=int(token.action); var gender:=int(state.gender)
	if action==0: return network_raw({"strRef":int(token.refs[0])&0xffffffff},gender)
	if action==1: return network_raw({"strRef":int(token.refs[gender])&0xffffffff},gender) if gender>=0 and gender<4 else "<UNRECOGNIZED TOKEN>"
	if action>=2 and action<=14 or action==24:
		if context.is_empty() or int(context.get("objectType",0))!=5: return network_raw({"strRef":int(token.default)&0xffffffff},gender)
		var data: Dictionary=context.get("replicated",{}); var names: Dictionary=data.get("name",context.get("appearance",{}).get("name",{})); var stats: Dictionary=data.get("stats",{})
		if data.get("stats")==null and data.get("name")==null and context.get("appearance",{}).get("name")==null:return "NO STATS"
		var first:=network_raw(names.get("firstName",{}),gender); var last:=network_raw(names.get("lastName",{}),gender)
		if action==2: return (first+" "+last).strip_edges()
		if action==3: return first if not first.is_empty() else last
		if action==4: return last if not last.is_empty() else first
		if action in [5,6] and native_integer(stats.get("racialType"),-2147483648,4294967295):
			var reference:=network_rule_ref("racialtypes",int(stats.racialType)&65535,"ConverNameLower" if action==6 else "ConverName")
			if reference.found:
				state.gender=0
				var value:=network_raw({"strRef":reference.ref})
				state.gender=gender
				return value
		if action in [8,9,10] and not stats.get("classes",[]).is_empty() and stats.classes[0] is Dictionary:
			var selected: Dictionary=stats.classes[0]
			if action==10 and native_integer(selected.get("level"),-2147483648,4294967295):return str(int(selected.level)&255)
			if action in [8,9] and native_integer(selected.get("id"),-2147483648,4294967295):
				var reference:=network_rule_ref("classes",int(selected.id)&255,"Lower" if action==9 else "Name")
				if reference.found:
					state.gender=0
					var value:=network_raw({"strRef":reference.ref})
					state.gender=gender
					return value
		# Unavailable replicated providers are explicit, never local rules or
		# fabricated character stats. These actions need their native owners.
		token_diagnostic("Replicated token provider is unavailable",{"action":action,"sourceRow":int(token.get("sourceRow",-1))}); return "<UNIMPLEMENTED TOKEN>"
	if action in [19,20]:
		state.suppression=int(state.get("nativeBC",0))
		if state.suppression!=0 or int(state.get("nativeB8",0))!=0: return ""
		return "<c"+String.chr(1 if action==19 else 254)+String.chr(254 if action==19 else 1)+String.chr(1)+">"
	if action==21: return "" if int(state.get("nativeB8",0))!=0 else "<c"+String.chr(1)+String.chr(1)+String.chr(254)+">"
	if action==22:
		var show: bool=int(state.suppression)==0 and int(state.get("nativeB8",0))==0; state.suppression=0
		return "</c>" if show else ""
	if action==23:
		var id: int=int(state.get("nativeC0",0))&0xffffffff
		var name: Variant=null
		if id==int(state.get("playerId",0)) and state.has("playerName"):name=state.playerName
		elif players.has(id) and players[id] is Dictionary:name=players[id].get("name")
		return network_raw({"strRef":int(token.default)&0xffffffff},gender) if name==null else str(name)
	token_diagnostic("Replicated token provider is unavailable",{"action":action,"sourceRow":int(token.get("sourceRow",-1))}); return "<UNIMPLEMENTED TOKEN>"
static func network_color_width(bytes: PackedByteArray,at: int) -> int:
	if at+3<bytes.size() and bytes[at]==60 and bytes[at+1]==47 and bytes[at+2]==99 and bytes[at+3]==62:return 4
	return 6 if at+5<bytes.size() and bytes[at]==60 and bytes[at+1]==99 and bytes[at+5]==62 else 0
static func network_custom_name(bytes: PackedByteArray) -> bool:
	if bytes.size()<=6 or bytes.slice(0,6)!="CUSTOM".to_ascii_buffer():return false
	for at in range(6,bytes.size()):
		if bytes[at]<48 or bytes[at]>57:return false
	return true
func network_token_bytes(token: Dictionary,frame: Dictionary,context: Dictionary) -> Dictionary:
	var value: String=token_value(token,context,frame)
	var encoded: Dictionary=ScriptString.bytes(value)
	return {"ready":false,"error":str(encoded.error)} if encoded.has("error") else {"ready":true,"bytes":encoded.value}
func network_resolve(value: Variant,id: int,options: Dictionary={}) -> Dictionary:
	var input: String=network_raw(value)
	if not input.contains("<"):return {"ready":true,"body":input}
	var token_table: Dictionary=network_table("stringtokens")
	if not token_table.get("ready",false):return token_table
	if not named_ready:import_tokens()
	if not named_ready:return {"ready":false,"error":network_token_error if not network_token_error.is_empty() else "Native StringTokens metadata is unavailable."}
	var context_value: Variant=options.get("context",objects.get(id,{}))
	var context: Dictionary=context_value if context_value is Dictionary else {}
	var gender: int=int(context.get("appearance",{}).get("gender",0))
	var names_value: Variant=context.get("replicated",{}).get("name",context.get("appearance",{}).get("name",{}))
	var names: Dictionary=names_value if names_value is Dictionary else {}
	var first: String=network_raw(names.get("firstName"),gender)
	var last: String=network_raw(names.get("lastName"),gender)
	var state: Dictionary={"gender":gender,"suppression":0,"nativeB8":options.get("nativeB8",1),"nativeBC":options.get("nativeBC",0),"nativeC0":options.get("playerId",0),"playerId":options.get("playerId",0),"firstName":first,"lastName":last}
	if options.has("playerName"):state.playerName=options.playerName
	var encoded: Dictionary=ScriptString.bytes(input)
	if encoded.has("error"):return {"ready":false,"error":str(encoded.error)}
	var input_bytes: PackedByteArray=encoded.value
	var references: Dictionary={};var matched: Array=[];var at:=0;var end:=input_bytes.find(0)
	if end<0:end=input_bytes.size()
	while at<end:
		if input_bytes[at]!=60:at+=1;continue
		if at+1<end and input_bytes[at+1]==60:at+=2;continue
		var width:=network_color_width(input_bytes,at)
		if width>0 and at+width<=end:at+=width;continue
		var close:=at+1
		while close<end and input_bytes[close]!=62:close+=1
		if close>=end:break
		var name_bytes: PackedByteArray=input_bytes.slice(at+1,close)
		var name: String=GffText.decode(name_bytes)
		var token: Dictionary={}
		for candidate in named:
			if str(candidate.get("name",""))==name:
				token=candidate
				break
		if not token.is_empty():
			matched.append(token)
			references[int(token.default)&4294967295]=true
			for ref in token.refs:references[int(ref)&4294967295]=true
		elif not network_custom_name(name_bytes):token_diagnostic("Native network token data owner is unavailable",{"token":name})
		at=close+1
	var stats_value: Variant=context.get("replicated",{}).get("stats",{})
	var stats: Dictionary=stats_value if stats_value is Dictionary else {}
	for token in matched:
		var action: int=int(token.action)
		if action not in [5,6,8,9]:continue
		var race: bool=action<=6
		var table_name: String="racialtypes" if race else "classes"
		var rule: Dictionary=network_table(table_name)
		if rule.get("pending",false):return rule
		if not rule.get("ready",false):continue # Old rule load rejection is diagnosed by its provider.
		var row_id: Variant=stats.get("racialType") if race else null
		if not race and stats.get("classes") is Array and not stats.classes.is_empty() and stats.classes[0] is Dictionary:row_id=stats.classes[0].get("id")
		if not row_id is int:continue
		var column: String=("ConverNameLower" if action==6 else "ConverName") if race else ("Lower" if action==9 else "Name")
		var entry: Dictionary=network_rule_ref(table_name,int(row_id)&(65535 if race else 255),column)
		if entry.get("found",false):references[int(entry.ref)&4294967295]=true
	for ref in references:
		for selected_gender in [gender,0]:network_raw({"strRef":int(ref),"gender":selected_gender},selected_gender)
	var custom: Variant=options.get("localCustomTokens",server_tokens.snapshot())
	if custom is Dictionary and not options.get("localCustomTokensComplete",false):custom=server_tokens.snapshot()
	var providers: Dictionary={"named":named,"namedReady":true,"custom":custom,"customReady":true,"controlLength":func(bytes,offset):return network_color_width(bytes,offset),"resolve":func(token,frame):return network_token_bytes(token,frame,context)}
	var parsed: Dictionary=NativeParser.parse(input_bytes,state,providers)
	if not parsed.get("ready",false):return parsed if parsed.get("pending",false) else {"ready":false,"error":str(parsed.get("error",parsed.get("reason","Native network text parsing failed.")))}
	return {"ready":true,"body":GffText.decode(parsed.bytes),"bytes":parsed.bytes}
func resolve(value: Variant,id: int,options: Dictionary={}) -> String:
	network_last_error=""
	var result: Dictionary=network_resolve(value,id,options)
	if result.get("ready",false):return str(result.body)
	if not result.get("pending",false):
		network_last_error=str(result.get("error",result.get("reason","Native network text is unavailable.")))
		warn(network_last_error)
	return ""
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
func talk_string(ref: Variant,gender: Variant=0) -> Dictionary:
	# installedNetworkResources.talkString returned the FetchInternal status,
	# selected gender and the unparsed TLK text/sound/duration word.
	var fetched:=fetch_native_reference(ref,gender)
	if network_diagnostic.is_valid() and native_integer(ref,0,4294967295) and native_integer(gender,0,1):
		if fetched.has("warningLine"):
			network_diagnostic.call({"code":"network.talk-table-warning","reason":"Native talk-table lookup warning","line":int(fetched.warningLine),"strRef":int(ref)})
		var primary: Variant=custom if (int(ref)&0x01000000)!=0 else base
		if native_file_ready(primary) and int(primary.language) not in [0,1,2,3,4]:
			network_diagnostic.call({"code":"network.talk-table-encoding-unhandled","reason":"Non-Western network talk-table display encoding is not connected","language":int(primary.language)})
	var selected_gender: Variant=fetched.get("gender",gender)
	var result:={"status":1 if bool(fetched.get("found",false)) else 0,"text":str(fetched.get("text","")),"sound":str(fetched.get("sound","")),"durationBits":int(fetched.get("durationBits",0)),"gender":int(selected_gender) if selected_gender is int else 0}
	if fetched.has("reason"):result.error=str(fetched.reason)
	return result
func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selection: Dictionary) -> Dictionary:
	# A received name/header has already selected its runtime override. Read
	# the same live TLK family without borrowing a later override or mutating
	# the shared table. lookupComplete distinguishes native false/empty from
	# an unavailable file or uncertified selection.
	return native_reference_lookup(ref,gender,selection)
func native_reference_lookup(ref: Variant,gender: Variant,selection: Variant) -> Dictionary:
	# Raw native FetchInternal selection. Parsing is owned by the caller's
	# certified stage; legacy fetch_reference/resolve retain their old contract.
	var result:={"found":false,"text":"","sound":"","durationBits":0,"duration":0.0,"gender":null,"override":false}
	if selection!=null:result.lookupComplete=false
	if not native_integer(ref,-2147483648,4294967295) or not native_integer(gender,-2147483648,4294967295):
		result.reason="Native TLK reference or gender is malformed.";return result
	var id:=int(ref)&4294967295;var selected_gender:=int(gender)&255;result.gender=selected_gender
	# Native invalid guards precede the runtime override hash lookup and return
	# a successful empty STR_RES. They do not change the retained gender byte.
	if id==4294967295 or selected_gender>1:
		result.found=true
		if selected_gender>1:warn("Native talk-table lookup warning 0x17f")
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
			if is_custom:result.found=true;result.text="BadStrRef(%d)"%(id-4294967296 if id>=2147483648 else id)
			else:result.reason="Native selected TLK file is unavailable."
			if selection!=null:result.lookupComplete=result.found
			return result
		var index: int=(id&0x00ffffff) if is_custom else id
		if selected_gender==1 and index>=table.count:
			selected_gender=0;result.gender=0
			table=custom if is_custom else base
			if table.file==null and table.bytes.is_empty():
				if is_custom:result.found=true;result.text="BadStrRef(%d)"%(id-4294967296 if id>=2147483648 else id)
				else:result.reason="Native fallback TLK file is unavailable."
				if selection!=null:result.lookupComplete=result.found
				return result
		selected_table=table;selected_index=index
	# Keep body lookup virtual so the active owner and traced readers retain
	# one lookup boundary. Never reinterpret an in-range failure as a row miss.
	var fetched: Dictionary
	if selection==null:fetched=fetch_reference(id,selected_gender) if overridden else selected_table.native_record(selected_index)
	elif overridden:fetched={"found":true,"text":str(selection.text)}
	else:fetched=selected_table.native_record(selected_index)
	if selection!=null:result.lookupComplete=true
	result.found=fetched.get("found",false)==true;result.text=str(fetched.get("text",""));result.override=overridden
	if fetched.get("bytes") is PackedByteArray:result.bytes=fetched.bytes.duplicate()
	if overridden:
		if selection!=null and selection.get("bytes") is Array:
			var encoded:=NativeParser.value_bytes({"bytes":selection.bytes})
			if not encoded.get("ready",false):result.found=false;result.reason=encoded.reason;return result
			result.bytes=encoded.bytes
		elif selection==null and native_override_bytes.get(id) is Dictionary and native_override_bytes[id].get("text")==result.text:result.bytes=native_override_bytes[id].bytes.duplicate()
	if fetched.has("language"):result.language=fetched.language
	if fetched.has("warningLine"):
		result.warningLine=int(fetched.warningLine)
		warn("Native talk-table lookup warning 0x%x"%int(fetched.warningLine))
	if not overridden:
		result.sound=str(fetched.get("sound",""))
		result.durationBits=int(fetched.get("durationBits",0))
	if not overridden and (int(fetched.get("flags",0))&4)!=0:result.duration=float(fetched.get("duration",0.0))
	if not result.found:result.reason=str(fetched.get("error","Native selected TLK record is unavailable."))
	return result
func parse_native(input: String,call_state: Dictionary={}) -> Dictionary:
	var language: Variant=call_state.get("language",base.language)
	if not native_integer(language,0,4294967295):return NativeParser.pending("Native text language is malformed.")
	var encoded:=NativeParser.encode(input,int(language))
	if not encoded.get("ready",false):return encoded
	return parse_native_bytes(encoded.bytes,call_state)
func parse_native_bytes(input: PackedByteArray,call_state: Dictionary={}) -> Dictionary:
	var language: Variant=call_state.get("language",base.language)
	if not native_integer(language,0,4294967295):return NativeParser.pending("Native text language is malformed.")
	call_state=call_state.duplicate(true);call_state.language=int(language)
	# This is a private call frame, not the retained global context of other UI.
	var state:={"suppression":0}
	for key in ["gender","nativeB8","nativeBC","nativeC0"]:
		if call_state.has(key):
			if not native_integer(call_state[key],0 if key=="gender" else -2147483648,255 if key=="gender" else 4294967295):return {"ready":false,"reason":"Native talk call state is malformed: "+key}
			state[key]=int(call_state[key])
	if call_state.has("context"):
		if not call_state.context is Dictionary:return NativeParser.pending("Native talk context is not certified.")
		state.context=call_state.context.duplicate(true)
	var providers:={"language":int(language),"custom":call_state.get("localCustomTokens"),"customReady":call_state.get("localCustomTokensComplete")==true,"named":named,"namedReady":named_ready,"resolve":func(token,frame):return native_token_value(token,frame,call_state,0)}
	var parsed:=NativeParser.parse(input,state,providers)
	if not parsed.get("ready",false):return parsed
	# Received native strings are terminated. Keep exact bytes for diagnostics;
	# avoid feeding embedded NUL to Godot's Unicode string conversion.
	var visible: PackedByteArray=parsed.bytes;var zero:=visible.find(0)
	if zero>=0:visible=visible.slice(0,zero)
	var decoded:=NativeParser.Encoding.decode(visible,int(language),true)
	if not decoded.get("ready",false):decoded.bytes=parsed.bytes.duplicate();return decoded
	parsed.body=str(decoded.text);parsed.language=int(language)
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
	var encoded: Dictionary={"ready":true,"bytes":fetched.bytes.duplicate()} if fetched.get("bytes") is PackedByteArray else script_string_bytes(str(fetched.get("text","")))
	if not encoded.get("ready",false):return encoded
	if not fetched.override:return encoded
	# Native GetTokenValue fetches with parseFlag0, but runtime overrides still
	# execute their own ParseStr. Returned replacement is not re-parsed by caller.
	var providers:={"language":int(call_state.get("language",base.language)),"custom":call_state.get("localCustomTokens"),"customReady":call_state.get("localCustomTokensComplete")==true,"named":named,"namedReady":named_ready,"resolve":func(token,frame):return native_token_value(token,frame,call_state,depth+1)}
	return NativeParser.parse(encoded.bytes,state,providers)
static func script_string_bytes(value: Variant) -> Dictionary:
	var encoded:Dictionary=ScriptString.bytes(value)
	return {"ready":false,"reason":encoded.error} if encoded.has("error") else {"ready":true,"bytes":encoded.value}
func native_literal_name(value: Variant,language: int=0) -> Dictionary:
	if value is Dictionary and value.has("bytes"):return NativeParser.value_bytes(value,language)
	if value is String:return script_string_bytes(value)
	if value is Dictionary and value.get("text") is String:return script_string_bytes(value.text)
	return NativeParser.pending("Native literal name provider is unavailable.")
func native_rule_reference(table_name: String,index: Variant,column: String) -> Dictionary:
	if not native_integer(index,0,65535):return NativeParser.pending("Native token rule index is unavailable.")
	var rows: Variant=tables.get(table_name,{}).get("orderedRows")
	if not rows is Array or int(index)>=rows.size() or not rows[int(index)] is Dictionary:return NativeParser.pending("Native token rule row is unavailable.")
	for key in rows[int(index)]:
		if str(key).to_lower()!=column.to_lower():continue
		var cell: Variant=rows[int(index)][key]
		if cell is String and cell.is_valid_int():cell=int(cell)
		if native_integer(cell,-2147483648,4294967295):return {"ready":true,"ref":int(cell)&4294967295}
	return NativeParser.pending("Native token rule STRREF is unavailable.")
func native_getter_fetch(ref: Variant,state: Dictionary,call_state: Dictionary,depth: int) -> Dictionary:
	# Race/class/alignment lower getters set gender0, then GetTokenValue
	# restores the saved BYTE even if an override/female fallback changed it.
	var known:=state.has("gender");var saved: Variant=state.get("gender")
	state.gender=0
	var result:=native_fetch(ref,state,call_state,depth)
	if known:state.gender=saved
	else:state.erase("gender")
	return result
func native_stored_name(value: Dictionary,action: int,language: int=0) -> Dictionary:
	if action==2:
		var override: Variant=value.get("override")
		if not override is Dictionary or override.get("known")!=true or not override.get("text") is String:return NativeParser.pending("Native stored-name override is unavailable.")
		var encoded:=script_string_bytes(override.text)
		if not encoded.get("ready",false) or not encoded.bytes.is_empty():return encoded
	var first: Variant=value.get("first");var last: Variant=value.get("last")
	var selected: Variant=last if action==4 else first
	if not selected is Dictionary or selected.get("known")!=true or not selected.get("text") is String:return NativeParser.pending("Native stored-name component is unavailable.")
	var initial:=script_string_bytes(selected.text)
	if not initial.get("ready",false):return initial
	if action in [3,4] and not initial.bytes.is_empty():return initial
	var other: Variant=first if action==4 else last
	if not other is Dictionary or other.get("known")!=true or not other.get("text") is String:return NativeParser.pending("Native stored-name fallback is unavailable.")
	var fallback:=script_string_bytes(other.text)
	if not fallback.get("ready",false):return fallback
	if action in [3,4] or initial.bytes.is_empty():return fallback
	if not fallback.bytes.is_empty():initial.bytes.append(32);initial.bytes.append_array(fallback.bytes)
	return initial
static func native_alignment_bucket(value: int) -> int:return 2 if value<31 else (0 if value>69 else 1)
func native_creature_token(action: int,token: Dictionary,context: Dictionary,state: Dictionary,call_state: Dictionary,depth: int) -> Dictionary:
	var data: Variant=context.get("replicated",{})
	var language:=int(call_state.get("language",base.language))
	if not data is Dictionary:return NativeParser.pending("Native received creature provider is unavailable.")
	var appearance:Variant=context.get("appearance",{})
	if not data.get("stats") is Dictionary and not data.get("name") is Dictionary and not (appearance is Dictionary and appearance.get("name") is Dictionary):return script_string_bytes("NO STATS")
	if action in [2,3,4]:
		if context.has("nativeStoredName"):
			return native_stored_name(context.nativeStoredName,action,language) if context.nativeStoredName is Dictionary else NativeParser.pending("Native stored-name receipt is malformed.")
		if action==2:return NativeParser.pending("Native full-name stored getter is unavailable.")
		# P writes the actor's stored first/last; U/replicated.name writes a
		# separate roster label. A roster label cannot certify either getter.
		var names: Variant=context.appearance.get("name") if context.get("appearance") is Dictionary else null
		if not names is Dictionary:return NativeParser.pending("Native received name provider is unavailable.")
		if names.get("text") is String:names={"firstName":{"text":names.text},"lastName":{"text":""}}
		elif names.has("bytes"):names={"firstName":names,"lastName":{"bytes":[]}}
		var first:=native_literal_name(names.get("lastName" if action==4 else "firstName"),language)
		if not first.get("ready",false) or not first.bytes.is_empty():return first
		return native_literal_name(names.get("firstName" if action==4 else "lastName"),language)
	var stats: Variant=data.get("stats")
	if not stats is Dictionary:return NativeParser.pending("Native received token stats are unavailable.")
	if action==24:return native_literal_name(stats.get("fieldE58"),language)
	if action==7:
		var subrace:=native_literal_name(stats.get("fieldD28"),language)
		if not subrace.get("ready",false) or not subrace.bytes.is_empty():return subrace
	var reference: Dictionary
	if action in [5,6,7]:
		var race: Variant=stats.get("racialType",stats.get("fieldD20"))
		if stats.has("racialType") and stats.has("fieldD20") and stats.racialType!=stats.fieldD20:return NativeParser.pending("Native race aliases disagree.")
		reference=native_rule_reference("racialtypes",race,"Name" if action==7 else ("ConverNameLower" if action==6 else "ConverName"))
	elif action in [8,9,10]:
		var classes: Variant=stats.get("classes")
		if not classes is Array or classes.is_empty() or not classes[0] is Dictionary:return NativeParser.pending("Native first-class storage is unavailable.")
		if action==10:
			return script_string_bytes(str(int(classes[0].level))) if native_integer(classes[0].get("level"),0,255) else NativeParser.pending("Native first-class BYTE level is unavailable.")
		if not native_integer(classes[0].get("id"),0,255):return NativeParser.pending("Native first-class BYTE index is unavailable.")
		reference=native_rule_reference("classes",classes[0].id,"Lower" if action==9 else "Name")
	else:
		var scores: Dictionary={}
		for key in (["fieldDE6"] if action==13 else (["fieldDE4"] if action==14 else ["fieldDE6","fieldDE4"])):
			if not native_integer(stats.get(key),-32768,32767):return NativeParser.pending("Native received alignment SHORT is unavailable.")
			# Receiver781e80 clamps these wire SHORTs before writing Stats+c6/c8.
			scores[key]=clampi(int(stats[key]),0,100)
		if action in [13,14]:
			var refs: Variant=token.get("refs")
			if not refs is Array or refs.size()!=4:return NativeParser.pending("Native alignment-token references are unavailable.")
			var had_gender:=state.has("gender");var gender: Variant=state.get("gender")
			var result:=native_fetch(refs[native_alignment_bucket(scores["fieldDE6" if action==13 else "fieldDE4"])],state,call_state,depth)
			if had_gender:state.gender=gender
			else:state.erase("gender")
			return result
		reference={"ready":true,"ref":(0x1351 if action==12 else 0x70)+native_alignment_bucket(scores.fieldDE6)*3+native_alignment_bucket(scores.fieldDE4)}
	if not reference.get("ready",false):return reference
	return native_getter_fetch(reference.ref,state,call_state,depth)
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
		return native_creature_token(action,token,context,state,call_state,depth)
	if action in [15,16,17,18]:
		# Exact client-module fields, supplied by a certified caller. Do not
		# substitute wall clock time or run a local calendar simulation.
		var world: Variant=call_state.get("nativeWorld")
		if not world is Dictionary:return NativeParser.pending("Native module token snapshot is unavailable.")
		var field: String="native160" if action==15 else ("native164" if action==17 else "native16c")
		if not native_integer(world.get(field),-2147483648,4294967295):return NativeParser.pending("Native module token field is unavailable: "+field)
		var value: int=int(world[field])&4294967295
		if action in [15,17]:return script_string_bytes(str(value-4294967296 if value>=2147483648 else value))
		if action==16:return script_string_bytes(str((((value+11)&4294967295)%12)+1))
		for key in ["native17c","native17d"]:
			if not native_integer(world.get(key),0,255):return NativeParser.pending("Native module daylight BYTE is unavailable.")
		var first:=int(world.native17c);var last:=int(world.native17d);var index:=0
		if value>=first and value<=last:index=int((value-first)*3/(last-first+1))+1
		if not refs is Array or refs.size()!=4:return NativeParser.pending("Native daylight-token references are unavailable.")
		return native_fetch(refs[index],state,call_state,depth)
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
		return script_string_bytes("</c>") if int(state.nativeB8)==0 else {"ready":true,"bytes":PackedByteArray()}
	if action==23:
		if not state.has("nativeC0"):return NativeParser.pending("Native player-token C0 selection is unavailable.")
		var players: Variant=call_state.get("nativePlayers")
		if not players is Dictionary:return NativeParser.pending("Native receipt player lookup is unavailable.")
		var id:=int(state.nativeC0)&4294967295
		var selected: Variant=players.get(id,players.get(str(id)))
		if selected==null and not players.has(id) and not players.has(str(id)) and call_state.get("nativePlayersComplete")==true:return native_fetch(token.get("default"),state,call_state,depth)
		if not selected is Dictionary or selected.get("known")!=true or not selected.get("present") is bool:return NativeParser.pending("Native selected player lookup is unavailable.")
		if not selected.present:return native_fetch(token.get("default"),state,call_state,depth)
		return native_literal_name(selected.get("name"),int(call_state.get("language",base.language)))
	if action<0 or action>24:warn("Native GetTokenValue unknown action at line0x175: "+str(action));return {"ready":true}
	return NativeParser.pending("Native named-token provider is unavailable: "+str(action))
func rich(value: Variant,id: int) -> Dictionary: return Rich.parse(resolve(value,id))
func set_native_override(ref: int,value: String) -> void:
	if value.is_empty():overrides.erase(ref);native_override_bytes.erase(ref);return
	overrides[ref]=value
	var encoded:=NativeParser.encode(value,0) # Existing wire byte projection.
	if encoded.get("ready",false):native_override_bytes[ref]={"text":value,"bytes":encoded.bytes}
	else:native_override_bytes.erase(ref)
func reset_native_overrides() -> bool:
	var changed:=not overrides.is_empty() or not native_override_bytes.is_empty()
	overrides.clear();native_override_bytes.clear()
	if changed:mark_changed()
	return changed
func close() -> void:
	native_override_bytes.clear()
	named_ready=false
	native_families.clear()
	ruleset_owner.retire()
	base.close(); female.close(); custom.close(); custom_female.close(); objects.clear(); players.clear(); server_tokens.reset(); custom_tokens.clear(); overrides.clear(); named.clear(); tables.clear()
