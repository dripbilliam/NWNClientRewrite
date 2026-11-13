extends SceneTree
const Parser=preload("res://systems/native_data/native_talk_parser.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Receipt=preload("res://systems/native_data/script_floating_text_receipt.gd")
var checks:=0
var failures: Array=[]
var compared:=0
var undefined_cases:=0
var callback_calls: Array=[]
var active_case: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func resolve_fixture(token: Dictionary,state: Dictionary) -> Dictionary:
	var kind:=int(token.kind);callback_calls.append(kind)
	if kind in [1,2]:state.suppression=1 if kind==1 else 0;return {"ready":true,"bytes":PackedByteArray()}
	return {"ready":true,"bytes":str(active_case.namedValue).hex_decode()}
func compare_corpus(corpus: Dictionary,label: String,hashes: Dictionary) -> void:
	for row in corpus.rows:
		active_case=row.case;callback_calls=[]
		var custom: Array=[]
		for item in active_case.tokens:custom.append({"id":int(item.id),"bytes":str(item.value).hex_decode()})
		var named: Array=[]
		if active_case.named:
			for name in ["NAME","HIDE","SHOW"]:named.append({"name":str(name).to_ascii_buffer(),"hash":int(hashes[name]),"kind":["NAME","HIDE","SHOW"].find(name)})
		if active_case.get("collision",false):named=[{"name":"OTHER".to_ascii_buffer(),"hash":int(hashes.NAME),"kind":0}]
		named.sort_custom(func(a,b):return int(a.hash)<int(b.hash))
		var state:={"suppression":int(row.get("retainedState",{}).get("suppression",77))}
		var input: PackedByteArray=str(active_case.input).hex_decode();var before:=input.duplicate()
		var result:=Parser.parse(input,state,{"custom":custom,"customReady":true,"named":named,"namedReady":true,"resolve":resolve_fixture})
		if not result.get("ready",false) and str(result.get("reason","")).contains("unterminated"):
			undefined_cases+=1;check(not result.get("pending",false),label+" undefined native string boundary remains explicit");continue
		check(result.get("ready",false),label+" complete original input is ready "+str(compared))
		if not result.get("ready",false):continue
		check(result.bytes.hex_encode()==str(row.value),label+" exact original output bytes "+str(compared))
		var expected_calls: Array=[]
		for value in row.calls:expected_calls.append(int(value))
		check(int(state.suppression)==int(row.suppression) and callback_calls==expected_calls,label+" original suppression and provider call order "+str(compared))
		check(input==before,label+" input bytes remain detached "+str(compared));compared+=1
func tlk_bytes(values: Array,duration: float=0.0) -> PackedByteArray:
	var strings:=PackedByteArray();var result:=PackedByteArray();result.resize(20+values.size()*40)
	for index in 8:result[index]="TLK V3.0".to_ascii_buffer()[index]
	result.encode_u32(12,values.size());result.encode_u32(16,result.size())
	for index in values.size():
		var encoded:=str(values[index]).to_ascii_buffer();var row:=20+index*40
		result.encode_u32(row,5 if duration!=0.0 else 1);result.encode_u32(row+28,strings.size());result.encode_u32(row+32,encoded.size());result.encode_float(row+36,duration)
		strings.append_array(encoded)
	result.append_array(strings);return result
func native_fetch_checks() -> void:
	var talk:=Talk.new();check(talk.base.open_bytes(tlk_bytes(["Male0","Male1"],3.25)),"Native-fetch fixture uses a valid original TLK table")
	var result:=talk.fetch_native_reference(1,1)
	check(not result.found and result.gender==1,"Missing base female file is unavailable, not a guessed male fallback")
	check(talk.female.open_bytes(tlk_bytes([])),"Existing zero-row female file is distinct from no file")
	result=talk.fetch_native_reference(1,1)
	check(result.found and result.text=="Male1" and result.gender==0 and result.duration==3.25 and not result.override,"Existing empty female file retries male and exposes the mutated native gender")
	check(talk.female.open_bytes(tlk_bytes(["Female0"])),"Short female fixture has its own actual record")
	result=talk.fetch_native_reference(0.0,1.0)
	check(result.found and result.text=="Female0" and result.gender==1 and result.duration==0.0,"In-range female lookup retains female gender and exact no-duration flag")
	result=talk.fetch_native_reference(1,1)
	check(result.found and result.text=="Male1" and result.gender==0,"Female out-of-range retry mutates gender before later named callbacks")
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":[{"TOKEN":"Gender","ACTION":"1","DEFAULT":"-1","A":"0","B":"1","C":"-1","D":"-1"}]});talk.import_tokens()
	var state:={"gender":1};var before:=state.duplicate(true);result=talk.parse_native("<Gender>/<Gender>",state)
	check(result.get("ready",false) and result.body=="Male1/Male0" and result.state.gender==0 and state==before,"Adjacent native named references observe female fallback mutation in one private call frame")
	talk.overrides[1]="Native override";talk.female.close();result=talk.fetch_native_reference(1,1)
	check(result.found and result.text=="Native override" and result.gender==1 and result.override and result.duration==0.0,"Runtime override precedes missing-file handling and does not mutate native gender")
	talk.overrides[4294967295]="Invalid override";result=talk.fetch_native_reference(4294967295,1)
	check(result.found and result.text.is_empty() and result.gender==1 and not result.override,"INVALID STRREF guard precedes override lookup")
	result=talk.fetch_native_reference(-1,0)
	check(result.found and result.text.is_empty() and result.gender==0,"Signed named INVALID is projected to the same native DWORD")
	talk.named.append({"name":"Invalid","hash":Talk.token_hash("Invalid",16),"action":0,"default":-1,"refs":[-1,-1,-1,-1]});talk.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash))
	result=talk.parse_native("<Invalid>")
	check(result.get("ready",false) and result.body.is_empty() and not result.state.has("gender"),"Native INVALID reference short-circuits an otherwise unavailable retained gender")
	result=talk.fetch_native_reference(1,2)
	check(result.found and result.text.is_empty() and result.gender==2 and not result.override,"Invalid native gender byte also precedes runtime override lookup")
	for invalid in [null,"1",1.5,-1,256]:
		result=talk.fetch_native_reference(1,invalid);check(not result.found and result.has("reason"),"Malformed native gender remains explicit: "+str(invalid))
	for invalid in [null,"1",1.5,-2147483649,4294967296]:
		result=talk.fetch_native_reference(invalid,0);check(not result.found and result.has("reason"),"Malformed native STRREF remains explicit: "+str(invalid))
	result=talk.fetch_native_reference(0x01000001,1)
	check(result.found and result.text=="BadStrRef(16777217)" and result.gender==1,"Missing selected custom-family file preserves native BadStrRef result without changing gender")
	check(talk.custom.open_bytes(tlk_bytes(["Custom0","Custom1"])) and talk.custom_female.open_bytes(tlk_bytes(["CustomFemale0"])),"Custom TLK fixtures retain separate physical families")
	result=talk.fetch_native_reference(0x01000001,1)
	check(result.found and result.text=="Custom1" and result.gender==0,"Existing short custom female file retries its male custom family using the original STRREF")
	var malformed:=tlk_bytes(["Invalid female row"]);malformed.encode_u32(20+28,999999);check(talk.female.open_bytes(malformed),"Malformed string-bound fixture retains valid header and in-range record")
	result=talk.fetch_native_reference(0,1)
	check(not result.found and result.gender==1,"In-range string-data failure never silently borrows a male record")
	talk.close()
func native_family_checks() -> void:
	var talk:=Talk.new();check(talk.base.open_bytes(tlk_bytes(["PairMale0","PairMale1"])) and talk.custom.open_bytes(tlk_bytes(["PairCustom0","PairCustom1"])),"Pair-publication fixtures have actual loaded primary files")
	check(talk.publish_native_family(false,true) and talk.publish_native_family(true,true),"Certified missing female lookup publishes native base/custom aliases")
	check(talk.native_families[0].female==talk.base and talk.native_families[1].female==talk.custom,"Native aliases retain exact existing table owners without TLK copies")
	var result:=talk.fetch_native_reference(1,1)
	check(result.found and result.text=="PairMale1" and result.gender==1,"Native loader male alias reads female request without changing gender")
	result=talk.fetch_native_reference(0x01000001,1)
	check(result.found and result.text=="PairCustom1" and result.gender==1,"Alternate-family loader alias preserves the same native gender semantics")
	talk.overrides[4294967295]="Forbidden invalid-reference override"
	var invalid_receipt:=Receipt.capture(93,4294967295,42,true,"",talk)
	result=Receipt.prepare(invalid_receipt,talk)
	check(result.get("ready",false) and invalid_receipt.body.is_empty() and Receipt.take_log(invalid_receipt).is_empty(),"Script93 top fetch applies native INVALID-before-override priority without echoing the forbidden override")
	var literal_receipt:=Receipt.capture(94,{"text":"Literal unchanged"},42,true,"",talk)
	check(Receipt.prepare(literal_receipt,talk).get("ready",false) and literal_receipt.body=="Literal unchanged","Script94 remains literal regardless of native fetch overrides")
	talk.retire_native_family(true)
	var custom_receipt:=Receipt.capture(93,0x01000001,42,true,"",talk)
	check(not custom_receipt.has("rawSnapshot") and Receipt.prepare(custom_receipt,talk).get("pending",false),"Script93 top snapshot cannot borrow a retired custom native family through legacy fetch")
	check(talk.publish_native_family(true,true),"Current custom pair can publish after the source load is complete")
	result=Receipt.prepare(custom_receipt,talk)
	check(result.get("ready",false) and custom_receipt.body=="PairCustom1","Script93 retries its unchanged raw reference after explicit native-family publication")
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":[{"TOKEN":"Gender","ACTION":"1","DEFAULT":"-1","A":"0","B":"1","C":"-1","D":"-1"}]});talk.import_tokens()
	result=talk.parse_native("<Gender>/<Gender>",{"gender":1})
	check(result.get("ready",false) and result.body=="PairMale1/PairMale1" and result.state.gender==1,"Adjacent gender callbacks preserve pointer-alias state rather than row-fallback state")
	talk.retire_native_family(false);result=talk.fetch_native_reference(0,0)
	check(not result.found and result.has("reason") and talk.fetch_reference(0,0).text=="PairMale0","Retired native family is pending without closing or changing legacy resources")
	talk.overrides[5]="Independent override";result=talk.fetch_native_reference(5,1)
	check(result.found and result.override and result.gender==1,"Native runtime override still precedes a retired file pair")
	check(talk.publish_native_family(false,true),"Current load publication can restore the explicitly absent-female alias")
	check(talk.female.open_bytes(tlk_bytes(["ActualFemale0"])),"A later actual female delivery has its own opened file")
	result=talk.fetch_native_reference(0,1)
	check(not result.found and result.has("reason"),"A new female delivery cannot silently reuse the earlier alias receipt")
	check(not talk.publish_native_family(false,true),"False absence declaration cannot alias an actually opened female table")
	check(talk.publish_native_family(false,false),"Current valid two-file load publication replaces the alias")
	result=talk.fetch_native_reference(0,1)
	check(result.found and result.text=="ActualFemale0" and result.gender==1,"Published distinct female file owns in-range reads")
	result=talk.fetch_native_reference(1,1)
	check(result.found and result.text=="PairMale1" and result.gender==0,"Distinct short female table still follows native gender-reset fallback")
	var malformed:=PackedByteArray();malformed.resize(20);check(not talk.female.open_bytes(malformed),"Malformed opened female header is observed explicitly")
	check(not talk.publish_native_family(false,false),"Malformed female header does not become a male alias")
	result=talk.fetch_native_reference(0,0)
	check(not result.found and talk.fetch_reference(0,0).text=="PairMale0","Failed native pair blocks even male reads while preserving legacy resource ownership")
	talk.close();check(talk.native_families.is_empty(),"Close retires all base/custom native alias receipts")
func api_checks() -> void:
	var talk:=Talk.new();var tag:="<c"+String.chr(255)+String.chr(1)+String.chr(1)+">"
	var escaped:="<"+tag+"tag<</c>";var raw:=tag+"tag</c>"
	var result:=talk.parse_native(escaped)
	check(result.get("ready",false) and result.body==raw,"Certified escapes need no named metadata, actor or flag defaults")
	result=talk.parse_native(raw);check(not result.get("ready",false) and result.get("pending",false),"Unescaped colour tokens await active named metadata rather than bypassing lookup")
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":[]});talk.import_tokens()
	result=talk.parse_native(raw);check(result.get("ready",false) and result.body=="<UNRECOGNIZED TOKEN>tag<UNRECOGNIZED TOKEN>","Strict native parser does not treat raw input RGB/closing tags as presentation controls")
	check(talk.resolve({"text":raw},-1)==raw,"Legacy rich Talk.resolve behavior stays unchanged")
	talk.custom_tokens[42]="future global";var receipt:={42:raw}
	result=talk.parse_native("<CUSTOM42>",{"localCustomTokens":receipt,"localCustomTokensComplete":true})
	check(result.get("ready",false) and result.body==raw,"CUSTOM replacement RGB bytes append once without recursive token lookup")
	result=talk.parse_native("<CUSTOM42>",{"localCustomTokens":{},"localCustomTokensComplete":true})
	check(result.get("ready",false) and result.body=="<UNRECOGNIZED TOKEN>","Complete receipt map never borrows a later live custom token")
	result=talk.parse_native("<CUSTOM42>");check(result.get("pending",false),"A valid CUSTOM lookup requires authoritative receipt state")
	result=talk.parse_native("<CUSTOMbad>");check(result.get("ready",false) and result.body=="<UNRECOGNIZED TOKEN>","Invalid native CUSTOM decimal needs no fabricated custom-token state")
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":[{"TOKEN":"FirstName","ACTION":"3","DEFAULT":"7100","A":"-1","B":"-1","C":"-1","D":"-1"},{"TOKEN":"Start","ACTION":"19","DEFAULT":"-1","A":"-1","B":"-1","C":"-1","D":"-1"},{"TOKEN":"Stop","ACTION":"22","DEFAULT":"-1","A":"-1","B":"-1","C":"-1","D":"-1"}]});talk.import_tokens();talk.overrides[7100]="Native default"
	result=talk.parse_native("<FirstName>");check(result.get("pending",false),"Unknown retained context is not silently NULL or a controlled actor")
	var call_state:={"context":{},"gender":0,"nativeB8":0,"nativeBC":0,"localCustomTokens":{},"localCustomTokensComplete":true};var before:=call_state.duplicate(true)
	result=talk.parse_native("<FirstName>",call_state)
	check(result.get("ready",false) and result.body=="Native default" and call_state==before,"Explicit NULL/gender0 fetches source default without mutating caller state")
	talk.overrides[7100]="<<CUSTOM42>"
	result=talk.parse_native("<FirstName>",call_state)
	check(result.get("ready",false) and result.body=="<CUSTOM42>","Provider FetchInternal override parses once, outer parser appends result without another pass")
	result=talk.parse_native("head<Start>hidden<Stop>tail",{"nativeBC":1})
	check(result.get("ready",false) and result.body=="headtail" and result.suppression==0,"Native BC suppression/reset short-circuits unavailable B8 exactly")
	result=talk.parse_native("<Start>",{"nativeBC":0});check(result.get("pending",false),"Unsuppressed colour provider requires its real B8 state")
	result=talk.parse_native("<Start>green<Stop>",{"nativeBC":0,"nativeB8":0})
	check(result.get("ready",false) and result.body=="<c"+String.chr(1)+String.chr(254)+String.chr(1)+">green</c>","Named colour providers append renderer tags without recursively parsing them")
	var actor:={"objectType":5,"appearance":{"name":{"firstName":{"text":"Exact first"},"lastName":{"text":""}}},"replicated":{"name":{"firstName":{"text":"Roster name"},"lastName":{"text":""}}}}
	result=talk.parse_native("<FirstName>",{"context":actor})
	check(result.get("ready",false) and result.body=="Exact first","Certified literal current-name provider uses only explicit received context")
	result=talk.parse_native("<FirstName>",{"context":{"objectType":5}});check(result.get("pending",false),"Missing received provider fields are not fabricated native NO STATS/default data")
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":[]})
	result=talk.parse_native(raw);check(result.get("pending",false),"Active named-table replacement invalidates lookup readiness")
	talk.import_tokens();talk.overrides[7000]=raw
	var native93:=Receipt.capture(93,7000,42,true,"",talk);var literal94:=Receipt.capture(94,{"text":raw},42,true,"",talk)
	var native_result:=Receipt.prepare(native93,talk);var literal_result:=Receipt.prepare(literal94,talk)
	check(native_result.get("ready",false) and native93.body=="<UNRECOGNIZED TOKEN>tag<UNRECOGNIZED TOKEN>","Source ScriptFloating93 uses strict certified ParseStr instead of legacy colour passthrough")
	check(literal_result.get("ready",false) and literal94.body==raw,"ScriptFloating94 remains literal native font markup")
	talk.overrides[7000]="<CUSTOM42>";talk.custom_tokens[42]=raw;native93=Receipt.capture(93,7000,42,true,"",talk);talk.custom_tokens[42]="future";talk.overrides[7000]="future reference"
	native_result=Receipt.prepare(native93,talk)
	check(native_result.get("ready",false) and native93.body==raw,"Strict93 preserves receipt raw/custom snapshots and does not reparse generated colour commands")
	talk.close()
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","original","supplement"]) or FileAccess.file_exists(args.report):quit(2);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.original));var supplement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.supplement))
	for row in original.hashRows:check(Parser.hash_bytes(str(row.value).hex_decode(),int(row.count))==int(row.result),"Original CRC/hash byte and NUL boundaries")
	compare_corpus(original,"retained580",original.nameHashes);compare_corpus(supplement,"new288",original.nameHashes);api_checks();native_fetch_checks();native_family_checks()
	var record:={"success":failures.is_empty(),"checks":checks,"failures":failures,"compared":compared,"undefinedCases":undefined_cases,"originalRows":original.rows.size(),"supplementRows":supplement.rows.size(),"scope":"Exact native ParseStr bytes/suppression/provider order and CRC corpus plus native-only TalkText API with explicit provider readiness; legacy resolve untouched. Authored named lowers, not whole game providers/UI/server.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(record,"\t"));file.close();print("NATIVE_TALK_PARSER ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
