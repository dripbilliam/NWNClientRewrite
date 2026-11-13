extends SceneTree
const Talk=preload("res://systems/native_data/talk_text.gd")
const Parser=preload("res://systems/native_data/native_talk_parser.gd")
const Encoding=preload("res://systems/native_data/native_text_encoding.gd")
const Context=preload("res://systems/native_data/native_token_context.gd")
const Speech=preload("res://systems/native_data/ordinary_speech_text_receipt.gd")
const ScriptText=preload("res://systems/native_data/script_floating_text_receipt.gd")
var checks:=0
var compared:=0
var failures: Array=[]
class OracleTalk extends Talk:
	var calls: Array=[]
	var fetch_gender:=-1
	var getter_refs: Array=[]
	func native_fetch(ref: Variant,state: Dictionary,_call: Dictionary,_depth: int) -> Dictionary:
		calls.append(["fetch",int(ref)&4294967295])
		if fetch_gender>=0:state.gender=fetch_gender
		return Parser.value_bytes("R"+str(int(ref)&4294967295))
	func native_getter_fetch(ref: Variant,_state: Dictionary,_call: Dictionary,_depth: int) -> Dictionary:
		getter_refs.append(int(ref))
		return Parser.value_bytes({200:"RACE",201:"race",202:"CLASS",203:"class"}.get(int(ref),"align" if int(ref)>=0x1351 else "ALIGN"))
	func warn(_reason: String) -> void:calls.append(["warning",0x175])
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label)
func token(action: int) -> Dictionary:return {"name":"T","hash":Talk.token_hash("T"),"action":action,"default":199,"refs":[100,101,102,103]}
func install_tokens(talk) -> void:
	var rows: Array=[]
	for action in 25:rows.append({"TOKEN":"T"+str(action),"ACTION":str(action),"DEFAULT":"199","A":"100","B":"101","C":"102","D":"103"})
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","A","B","C","D"],"orderedRows":rows});talk.import_tokens()
func tlk(values: Array,language: int=0) -> PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(20+40*values.size());var strings:=PackedByteArray()
	for at in 8:bytes[at]="TLK V3.0".to_ascii_buffer()[at]
	bytes.encode_u32(8,language);bytes.encode_u32(12,values.size());bytes.encode_u32(16,bytes.size())
	for at in values.size():
		var encoded: PackedByteArray=values[at] if values[at] is PackedByteArray else Encoding.encode(str(values[at]),language).get("bytes",PackedByteArray())
		bytes.encode_u32(20+40*at,1);bytes.encode_u32(48+40*at,strings.size());bytes.encode_u32(52+40*at,encoded.size());strings.append_array(encoded)
	bytes.append_array(strings);return bytes
func actor() -> Dictionary:
	return {"id":42,"objectType":5,"areaId":7,"nativeLifetime":1,"clientKnownLifetime":2,"nativeStoredName":{"override":{"known":true,"text":""},"first":{"known":true,"text":"  Ada"},"last":{"known":true,"text":"Lovelace  "}},"replicated":{"name":{"firstName":{"text":"Wrong roster"},"lastName":{"text":"Name"}},"stats":{"race":1,"racialType":0,"fieldD20":0,"fieldD28":"Moon elf","fieldE58":"Mystra","fieldDE4":85,"fieldDE6":15,"classes":[{"id":0,"level":2},{"id":1,"level":20}]}}}
func source_corpus(rows: Array) -> void:
	var talk:=OracleTalk.new();talk.publish_table("racialtypes",{"orderedRows":[{"ConverName":200,"ConverNameLower":201}]});talk.publish_table("classes",{"orderedRows":[{"Name":202,"Lower":203}]})
	for row in rows:
		var c: Dictionary=row.case
		if c.get("mode")=="alignment":
			var law: int=int(c.law)&65535;var good: int=int(c.good)&65535
			if law>=32768:law-=65536
			if good>=32768:good-=65536
			var alignment_state:={"context":{"objectType":5,"replicated":{"stats":{"fieldDE6":law,"fieldDE4":good}}},"gender":1,"suppression":0}
			talk.getter_refs=[];var alignment_result:=talk.native_token_value(token(12 if int(c.lower)!=0 else 11),alignment_state,{},0)
			check(alignment_result.get("ready",false) and talk.getter_refs==[int(row.result)] and alignment_state.gender==1,"Original signed-WORD alignment reference grid")
			continue
		var action:=int(c.action);var creature_action: bool=action>=2 and action<=14 or action==24
		# Original harness captured these absent lower owners. No received field
		# establishes native NO OBJECT/NO STATS, so those stay explicitly pending.
		if creature_action and c.context and (not c.object or c.creature and not c.stats):continue
		var context: Dictionary={}
		if c.context:
			context={"objectType":5 if c.creature else 6,"nativeStoredName":{"override":{"known":true,"text":"FULL"},"first":{"known":true,"text":c.first},"last":{"known":true,"text":c.last}},"replicated":{"stats":{"racialType":0,"fieldD28":"SUBRACE","fieldE58":"DEITY","fieldDE4":(int(c.good)&65535)-65536 if (int(c.good)&65535)>=32768 else int(c.good)&65535,"fieldDE6":(int(c.law)&65535)-65536 if (int(c.law)&65535)>=32768 else int(c.law)&65535,"classes":[{"id":0,"level":int(c.level)&255}]}}}
		var state:={"context":context,"gender":int(c.gender),"suppression":int(c.suppression),"nativeB8":int(c.b8),"nativeBC":int(c.bc),"nativeC0":123}
		var call:={"nativeWorld":{"native160":-5,"native164":25,"native16c":int(c.world),"native17c":6,"native17d":18},"nativePlayers":{123:{"known":true,"present":bool(c.player),"name":"PLAYER"}}}
		talk.fetch_gender=int(c.fetchGender);talk.calls=[]
		var value:=talk.native_token_value(token(action),state,call,0)
		check(value.get("ready",false),"Original provider ready "+str(compared))
		check(value.get("bytes","seed".to_ascii_buffer()).hex_encode()==str(row.value),"Original provider bytes "+str(compared)+" action"+str(action))
		check(int(state.gender)==int(row.gender) and int(state.suppression)==int(row.suppression),"Original gender/suppression "+str(compared))
		var expected_calls: Array=[]
		for entry in row.calls:expected_calls.append([str(entry[0]),int(entry[1])])
		check(talk.calls==expected_calls,"Original lower calls "+str(compared));compared+=1
	talk.close()
func provider_checks() -> void:
	var talk:=Talk.new();install_tokens(talk)
	var values: Array=[];values.resize(5000);values.fill("")
	for index in [100,101,102,103,199,200,201,202,203,112,0x1351]:values[index]="R"+str(index)
	check(talk.base.open_bytes(tlk(values)) and talk.publish_native_family(false,true),"Actual native-format base TLK is published")
	talk.publish_table("racialtypes",{"orderedRows":[{"ConverName":"200","ConverNameLower":"201","Name":"200"}]});talk.publish_table("classes",{"orderedRows":[{"Name":"202","Lower":"203"}]})
	var context:=actor();var call:={"context":context,"gender":1,"nativeB8":0,"nativeBC":0,"localCustomTokensComplete":true,"localCustomTokens":{42:"captured"}};var before:=call.duplicate(true)
	var result:=talk.parse_native("<T2>|<T3>|<T4>|<T5>|<T6>|<T7>|<T8>|<T9>|<T10>|<T24>",call)
	check(result.get("ready",false) and result.body=="  Ada Lovelace  |  Ada|Lovelace  |R200|R201|Moon elf|R202|R203|2|Mystra","All name/race/class/subrace/deity providers use exact stored fields and first class")
	check(call==before and result.get("state",{}).get("gender")==1,"Providers preserve caller storage and enclosing gender")
	context.nativeStoredName.override.text="Exact Override";result=talk.parse_native("<T2>/<T3>",call)
	check(result.get("ready",false) and result.body=="Exact Override/  Ada","Full-name override does not replace first-name token")
	context.nativeStoredName.first.text="";context.nativeStoredName.last.text="";context.nativeStoredName.override.text="";result=talk.parse_native("<T2>/<T3>/<T4>",call)
	check(result.get("ready",false) and result.body=="//","Known empty stored names do not become default or roster labels")
	context.replicated.stats.fieldD28="";result=talk.parse_native("<T7>",call)
	check(result.get("ready",false) and result.body=="R200","Empty subrace uses native race Name getter")
	context.replicated.stats.erase("fieldD28");check(talk.parse_native("<T7>",call).get("pending",false),"Missing subrace differs from empty subrace")
	for action in [2,5,6,7,8,9,10,11,12,13,14,24]:
		check(talk.parse_native("<T"+str(action)+">",{"context":{},"gender":1}).get("body")=="R199","Native NULL selects default action"+str(action))
		check(talk.parse_native("<T"+str(action)+">",{"context":{"objectType":5}}).get("pending",false),"Unavailable creature provider stays pending action"+str(action))
	for score in [-32768,-1,0,30,31,69,70,100,32767]:
		context=actor();context.replicated.stats.fieldDE6=score;context.replicated.stats.fieldDE4=score
		var index:=2 if score<31 else (0 if score>69 else 1)
		result=talk.parse_native("<T13>/<T14>",{"context":context,"gender":1})
		check(result.get("ready",false) and result.body=="R%d/R%d"%[100+index,100+index] and result.state.gender==1,"Native signed received alignment thresholds "+str(score))
	# Rule getter override parses under gender0; its enclosing callback restores1.
	context=actor();call.context=context;talk.overrides[200]="<T1>";result=talk.parse_native("<T5>/<T1>",call)
	check(result.get("ready",false) and result.body=="R100/R101" and result.state.gender==1,"Nested getter reference resets gender0 then restores enclosing gender1")
	talk.overrides[200]="<<T3>";result=talk.parse_native("<T5>",call)
	check(result.get("ready",false) and result.body=="<T3>","Override parses once; callback replacement is append-only")
	talk.overrides[200]="<T5>";result=talk.parse_native("<T5>",call)
	check(not result.get("ready",false) and str(result.get("reason","")).contains("nesting"),"Cyclic override remains within owned recursion bound")
	talk.overrides.clear();talk.publish_table("classes",{"orderedRows":[{"Name":"203","Lower":"202"}]});result=talk.parse_native("<T8>",call)
	check(result.get("body")=="R203","Rule reload does not borrow a stale STRREF")
	talk.publish_table("classes",{"orderedRows":[{"Name":"****"}]});check(talk.parse_native("<T8>",call).get("pending",false),"Unavailable rule cell is not invented ref0")
	for hour in [0,5,6,12,18,19,23,4294967295]:
		var world:={"native160":4294967295,"native164":11,"native16c":hour,"native17c":6,"native17d":18}
		result=talk.parse_native("<T15>/<T16>/<T17>/<T18>",{"gender":1,"nativeWorld":world})
		var index:=0 if hour<6 or hour>18 else int((hour-6)*3/13)+1
		check(result.get("body")=="-1/%d/11/R%d"%[(((hour+11)&4294967295)%12)+1,100+index],"Original world DWORD wrap/daylight partition "+str(hour))
	check(talk.parse_native("<T15>").get("pending",false),"World token cannot borrow OS time")
	check(talk.parse_native("<T23>",{"nativePlayers":{123:{"known":true,"present":true,"name":"User"}}}).get("pending",false),"Player lookup requires retained native C0 selection")
	result=talk.parse_native("<T23>",{"nativeC0":123,"nativePlayers":{123:{"known":true,"present":true,"name":""}}})
	check(result.get("ready",false) and result.body.is_empty(),"Known present empty player name stays empty")
	result=talk.parse_native("<T23>",{"gender":1,"nativeC0":123,"nativePlayers":{},"nativePlayersComplete":true})
	check(result.get("body")=="R199","Only certified player absence uses native default")
	check(talk.parse_native("<T23>",{"nativeC0":123,"nativePlayers":{}}).get("pending",false),"Partial roster does not certify absent selected player")
	talk.close()
func localization_checks() -> void:
	# Independently recorded strict Windows codec outputs, not a decoder /
	# encoder roundtrip alone (which could conceal a swapped language map).
	for item in [[0,"Café – €","436166e920962080"],[5,"Zażółć gęślą jaźń","5a61bff3b3e62067ea9c6cb9206a619ff1"],[128,"한글 이름","c7d1b1db20c0ccb8a7"],[129,"繁體中文","c163c5e9a4a4a4e5"],[130,"简体中文","bcf2cce5d6d0cec4"],[131,"日本語 名前","93fa967b8cea2096bc914f"]]:
		check(Encoding.encode(str(item[1]),int(item[0])).get("bytes",PackedByteArray()).hex_encode()==str(item[2]),"Independent codepage encode golden "+str(item[0]))
		check(Encoding.decode(str(item[2]).hex_decode(),int(item[0])).get("text")==str(item[1]),"Independent codepage decode golden "+str(item[0]))
	for item in [[0,"Café – €"],[1,"Français"],[2,"Deutsch – Straße"],[3,"Italiano è"],[4,"Español ¿Qué?"],[5,"Zażółć gęślą jaźń"],[128,"한글 이름"],[129,"繁體中文"],[130,"简体中文"],[131,"日本語 名前"]]:
		var language:=int(item[0]);var value:=str(item[1]);var encoded:=Encoding.encode(value,language)
		check(encoded.get("ready",false),"Language string encodes "+str(language))
		var talk:=Talk.new();install_tokens(talk)
		check(talk.base.open_bytes(tlk([encoded.get("bytes",PackedByteArray())],language)) and talk.publish_native_family(false,true),"Localized native TLK publication "+str(language))
		var fetched:=talk.fetch_native_reference(0,1)
		check(fetched.get("text")==value and fetched.get("bytes")==encoded.get("bytes") and fetched.gender==1,"Localized TLK retains original bytes and alias gender "+str(language))
		var call:={"language":language,"localCustomTokens":{42:encoded.get("bytes")},"localCustomTokensComplete":true,"nativeB8":0,"nativeBC":0}
		var result:=talk.parse_native("<T21><CUSTOM42><T22>",call)
		check(result.get("ready",false) and result.body=="<c"+String.chr(1)+String.chr(1)+String.chr(254)+">"+value+"</c>","Localized bytes and generated RGB payloads use separate decoders "+str(language))
		var program:=preload("res://systems/native_data/script_floating_markup.gd").compile_native(result.get("bytes",PackedByteArray()),language)
		check(program.get("ready",false) and program.get("plain")==value and program.commands.size()==3 and program.commands[0].op=="open" and program.commands[2].op=="close" and program.nativeBytes==result.bytes.size(),"Native font-command compilation preserves byte counts and Unicode text spans "+str(language))
		check(not Encoding.encode("😀",language).get("ready",false),"Unrepresentable Unicode is explicit "+str(language));talk.close()
	check(not Encoding.decode(PackedByteArray([0x82]),131).get("ready",false),"Truncated DBCS lead byte is unavailable, not replacement text")
	check(not Encoding.decode(PackedByteArray([0x82,0x20]),131).get("ready",false),"Invalid DBCS pair is unavailable")
	check(not Encoding.encode("text",77).get("ready",false),"Unsupported language does not default to Western")
func receipt_checks(fixture: Dictionary) -> void:
	var talk:=Talk.new();install_tokens(talk);var context:=actor();talk.objects[42]=context
	var metadata:={"version":1,"serial":1,"connection":3,"generation":2,"areaId":7,"source":null,"context":{"id":42,"objectType":5,"areaId":7,"nativeLifetime":1,"knownLifetime":2},"contextData":Context.project(context),"nativeWorld":{"native160":1372}}
	var message:={"channel":11,"objectId":99,"contextId":42,"text":{"text":"<T7>/<T10>/<T15>/<CUSTOM42>"},"nativeTextEvent":metadata};var current:={"connection":3,"generation":2,"areaId":7}
	talk.custom_tokens[42]="receipt";var receipt:=Speech.capture(message,talk,current)
	context.replicated.stats.fieldD28="future";context.replicated.stats.classes[0].level=99;metadata.contextData.replicated.stats.fieldD28="mutated packet";metadata.nativeWorld.native160=9999;talk.custom_tokens[42]="future"
	var result:=Speech.prepare(receipt,talk,current,true)
	check(result.get("body")=="Moon elf/2/1372/receipt","Delayed localized receipt retains original context, world, custom tokens and overhead-before-log stages")
	check(not receipt.context.has("inventory"),"Provider snapshots do not copy unrelated actor graphs")
	var frame:={"nativeWorld":{"native160":1372}};talk.overrides[7000]="<T15>";var script:=ScriptText.capture(93,7000,42,true,"",talk,frame);frame.nativeWorld.native160=9999
	result=ScriptText.prepare(script,talk)
	check(result.get("ready",false) and script.body=="1372","Script93 shares receipt world values with its independently scoped echo")
	var native_row:=actor();native_row.id=int(fixture.id);native_row.erase("nativeStoredName");talk.objects[int(fixture.id)]=native_row
	var packet: Dictionary=fixture.cases.literal.duplicate(true)
	metadata={"version":1,"serial":2,"connection":3,"generation":2,"areaId":7,"source":null,"context":{"id":int(fixture.id),"objectType":5,"areaId":7,"nativeLifetime":1,"knownLifetime":2},"contextData":Context.project(native_row),"contextActorName":{"version":1,"historyComplete":true,"state":packet}}
	message={"channel":11,"objectId":99,"contextId":int(fixture.id),"text":{"text":"<T2>"},"nativeTextEvent":metadata};receipt=Speech.capture(message,talk,current)
	packet.publication.first.text="Future P";talk.objects.clear();result=Speech.prepare(receipt,talk,current,true)
	check(result.get("body")=="First   Last","Actual protocol-generated context-name provenance resolves FullName despite later P/removal")
	check(not Context.event_frame(metadata).has("context"),"Transport context witness is never retained parser context")
	check(talk.parse_native("<T3>",{"context":{"objectType":5,"replicated":{"name":{"firstName":{"text":"Roster only"},"lastName":{"text":""}}}}}).get("pending",false),"Roster names cannot certify native first/last getters")
	var malformed_players:=Context.frame({"nativePlayers":{123:null},"nativePlayersComplete":true});malformed_players.nativeC0=123
	check(talk.parse_native("<T23>",malformed_players).get("pending",false),"Malformed present roster row cannot become certified absence")
	# A Japanese wire literal and custom token arrive through the existing
	# CP1252 byte projection. Native parsing must preserve their original bytes.
	var japanese:="93fa967b8cea2096bc914f".hex_decode();var projected:=preload("res://systems/native_data/binary_data.gd").new(japanese).text(0,japanese.size())
	check(talk.base.open_bytes(tlk([japanese],131)) and talk.publish_native_family(false,true),"Japanese native family reload is explicit")
	metadata={"version":1,"serial":3,"connection":3,"generation":2,"areaId":7,"source":null,"context":null,"nativeByteProjection":"windows-1252"}
	message={"channel":11,"contextId":Speech.OBJECT_INVALID,"text":{"text":projected+"/<CUSTOM42>"},"nativeTextEvent":metadata};talk.custom_tokens[42]=projected
	receipt=Speech.capture(message,talk,current);talk.custom_tokens[42]="Future";result=Speech.prepare(receipt,talk,current,true)
	check(result.get("body")=="日本語 名前/日本語 名前","Localized literal/custom receipt retains wire bytes across both copy stages")
	talk.set_native_override(7001,projected+"/<CUSTOM42>");script=ScriptText.capture(93,7001,42,true,"",talk,metadata);result=ScriptText.prepare(script,talk)
	check(result.get("ready",false) and script.body=="日本語 名前/Future","Runtime override uses exact wire bytes in the active codepage")
	# Strict Windows decoding rejects best-fit extension bytes. Preserve the
	# parsed bytes and expose that boundary instead of fabricating a glyph.
	var alias:="eef9".hex_decode();var raw_result:=Parser.parse(alias,{"suppression":0},{})
	check(raw_result.get("ready",false) and raw_result.bytes==alias,"Strict native parser retains undecoded extension bytes exactly")
	result=talk.parse_native_bytes(alias,{"language":131})
	check(not result.get("ready",false) and result.get("bytes")==alias and not result.has("body"),"Uncertified best-fit glyph decoding remains explicit with exact bytes")
	talk.close()
func visual_preview(report: String) -> void:
	var panel:=PanelContainer.new();panel.position=Vector2(28,24);panel.size=Vector2(1200,820);root.add_child(panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin);var list:=VBoxContainer.new();list.add_theme_constant_override("separation",14);margin.add_child(list)
	for value in ["NWN-33 • Native text providers",str(checks)+" checks passed · offline · receipt-time bytes", "English: Café – €", "Français: été, cœur", "Deutsch: Straße", "Italiano: perché", "Español: ¿Qué?", "Polski: Zażółć gęślą jaźń", "한국어: 한글 이름", "繁體中文: 繁體中文", "简体中文: 简体中文", "日本語: 日本語 名前", "Name / class / race / alignment / player / world providers"]:
		var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",22);list.add_child(label)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(report.get_base_dir().path_join("preview.png"))
	panel.queue_free();await process_frame
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","game-corpus"]):quit(2);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args["game-corpus"]))
	source_corpus(original.rows);provider_checks();localization_checks();receipt_checks(JSON.parse_string(FileAccess.get_file_as_string(args.fixture)))
	if DisplayServer.get_name()!="headless":await visual_preview(str(args.report))
	var window:={"screen":DisplayServer.window_get_current_screen(),"primary":DisplayServer.get_primary_screen(),"focused":DisplayServer.window_is_focused(),"unfocusable":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)} if DisplayServer.get_name()!="headless" else {}
	if not window.is_empty():check(window.unfocusable and not window.focused and window.screen!=window.primary,"Graphical client stays unfocused on a secondary screen")
	var result:={"success":failures.is_empty(),"checks":checks,"compared":compared,"failures":failures,"window":window,"serverConnections":0}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_TEXT_PROVIDERS ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
