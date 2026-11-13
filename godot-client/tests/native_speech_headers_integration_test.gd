extends SceneTree
# Actual receive/queue/speech/present and Chat with controlled native TLK data.
# Optional startup/menu tables stay unready; no fabricated world/actor result.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionGraph=preload("res://native_session_world.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Chat=preload("res://systems/server_chat.gd")
const Categories=preload("res://systems/native_data/chat_categories.gd")
class TracingTalk extends Talk:
	var events: Array=[]
	var native_parses: Array=[]
	var legacy_parses:=0
	func fetch_native_reference(ref: Variant,gender: Variant=0)->Dictionary:
		events.append({"kind":"fetch","ref":int(ref),"gender":int(gender)});return super.fetch_native_reference(ref,gender)
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selected: Dictionary)->Dictionary:
		events.append({"kind":"fetch","ref":int(ref),"gender":int(gender)});return super.fetch_native_reference_snapshot(ref,gender,selected)
	func parse_native_bytes(raw_bytes: PackedByteArray,state: Dictionary={}) -> Dictionary:
		var input: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(state.get("language",base.language)),true).get("text","")
		events.append({"kind":"parse","raw":input.to_utf8_buffer()});native_parses.append({"raw":input,"state":state.duplicate(true)});return super.parse_native_bytes(raw_bytes,state)
	func resolve(_value: Variant,_id: int,_options: Dictionary={})->String:legacy_parses+=1;return "FORBIDDEN LEGACY"
var checks:=0
var failures: Array=[]
var connection:=3
var serial:=0
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
static func tlk(rows: Dictionary)->PackedByteArray:
	var count:=1
	for key in rows:count=maxi(count,int(key)+1)
	var bytes:=PackedByteArray();bytes.resize(20+count*40);var magic:="TLK V3.0".to_ascii_buffer()
	for index in magic.size():bytes[index]=magic[index]
	bytes.encode_u32(8,0);bytes.encode_u32(12,count);bytes.encode_u32(16,bytes.size());var offset:=0
	for key in rows:
		var raw:=str(rows[key]).to_ascii_buffer();var at:=20+int(key)*40;bytes.encode_u32(at,1);bytes.encode_u32(at+28,offset);bytes.encode_u32(at+32,raw.size());bytes.append_array(raw);offset+=raw.size()
	return bytes
static func actor(id: int,first: String,native_lifetime: int,known: int)->Dictionary:
	return {"id":id,"objectType":5,"areaId":91,"nativeLifetime":native_lifetime,"clientKnownLifetime":known,"appearance":{"name":{"firstName":{"text":first},"lastName":{"text":""}}},"replicated":{"name":{"firstName":{"text":first},"lastName":{"text":""}},"stats":{"race":0}}}
func packet(channel: int=2,body: Variant={"text":"Body"})->Dictionary:
	serial+=1
	return {"kind":"server-speech","channel":channel,"objectId":42,"contextId":99,"text":body.duplicate(true) if body is Dictionary else body,"speakerName":{"text":"Remote Name"},"nativeTextEvent":{"version":1,"serial":serial,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":5,"areaId":91,"nativeLifetime":2,"knownLifetime":3},"context":{"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func queued(ui,message: Dictionary)->Dictionary:
	var before: Dictionary=message.duplicate(true);ui.receive(message,7)
	check(message==before and ui.queue.size()==1,"Actual receive leaves packet unchanged and captures one bounded log queue entry")
	return ui.queue.pop_front()
func show(ui,entry: Dictionary)->Dictionary:
	var before: int=ui.chat.rows.size();ui.present(entry.message,entry.speechText)
	return ui.chat.rows[-1] if ui.chat.rows.size()>before else {}
func run()->void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(SessionGraph!=null,"Current actual SessionWorld/Gameplay graph compiles without startup")
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.text.close();ui.text=TracingTalk.new();ui.feedback.text=ui.text
	ui.generation=7;ui.area_id=91;ui.controlled_id=42
	ui.native_connection_query=func():return connection
	ui.text.objects={42:actor(42,"Controlled actor never used",2,3),99:actor(99,"Context at receipt",8,13)}
	ui.text.named=[{"name":"FirstName","hash":Talk.token_hash("FirstName"),"action":3,"default":0,"refs":[0,0,0,0]},{"name":"Nested","hash":Talk.token_hash("Nested"),"action":0,"default":0,"refs":[300,300,300,300]}];ui.text.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash));ui.text.named_ready=true;ui.text.custom_tokens[12]="Receive "
	ui.chat=Chat.new();ui.add_child(ui.chat);ui.chat.setup();ui.table_jobs[100]="unrelated-pending-menu"
	check(ui.text.base.open_bytes(tlk({100:" First ",101:" Last ",200:"System reference body",300:"Nested base",5189:"Unknown",10299:"System ",10300:"<FirstName> << raw ",10301:"Whisper ",10302:"Tell ",10303:"Party ",66756:"DM Label"})) and ui.text.publish_native_family(false,true),"Actual native TLK pair with explicit male-file alias provides header/body data")
	var message:=packet();message.speakerName={"text":"<FirstName> << literal"};var entry:=queued(ui,message)
	check(entry.speechText.has("header") and entry.speechText.header.tokens[12]=="Receive " and not ui.tables_ready and ui.table_jobs.has(100),"Every actual server-speech receipt captures Header before unrelated menu readiness")
	var row: Dictionary=show(ui,entry)
	check(row.name.text=="<FirstName> << literal" and row.rich.text=="<FirstName> << raw Body" and ui.text.native_parses.is_empty(),"Actual speech/present leaves remote literal and normal base prefix raw without token/escape parsing")
	check(ui.text.events==[{"kind":"fetch","ref":10300,"gender":0}] and ui.text.legacy_parses==0,"Actual base-prefix path uses one native fetchgender0 and no legacy resolve")
	check(row.channel==2 and not row.system and Categories.bits(row)==4 and ui.chat.messages.get_parsed_text().contains("<FirstName> << literal: <FirstName> << raw Body"),"Actual Chat preserves channel/filter category, non-system flag and caller formatting")
	ui.text.events.clear();ui.text.native_parses.clear();message=packet();message.speakerName={"firstName":{"strRef":100,"gender":1},"lastName":{"strRef":101,"gender":0}}
	entry=queued(ui,message);row=show(ui,entry)
	check(row.name.text==" First   Last " and ui.text.events==[{"kind":"fetch","ref":100,"gender":1},{"kind":"fetch","ref":101,"gender":0},{"kind":"fetch","ref":10300,"gender":0}],"Actual remote localized first/last preserve wire genders, exact separator/whitespace and first-last-prefix order")
	message=packet();message.speakerName={"firstName":{"text":""},"lastName":{"text":""}};entry=queued(ui,message);row=show(ui,entry)
	check(row.name.text==" " and ui.chat.messages.get_parsed_text().ends_with(" : <FirstName> << raw Body\n"),"Actual remote empty+empty split remains one space, retaining normal colon formatting")
	ui.text.overrides[10300]="<CUSTOM12>";ui.text.custom_tokens[12]="Receive ";message=packet();message.speakerName={"text":"Queue-captured remote"};entry=queued(ui,message)
	message.speakerName.text="Mutated original";ui.text.custom_tokens[12]="Later ";ui.text.overrides[10300]="Changed direct override";ui.text.objects[42]=actor(42,"Reused actor",20,30);ui.text.native_parses.clear();row=show(ui,entry)
	check(row.name.text=="Queue-captured remote" and row.rich.text=="Receive Body","Actual receive-to-present preserves captured remote/CUSTOM/direct override across packet, token and source mutation")
	check(ui.text.native_parses.size()==1 and ui.text.native_parses[0].raw=="<CUSTOM12>" and ui.text.native_parses[0].state.gender==0 and not ui.text.native_parses[0].state.has("context"),"Only captured runtime prefix override invokes native ParseStr with fetchgender0 and no controlled context")
	ui.text.objects[42]=actor(42,"Controlled actor never used",2,3);ui.text.overrides[10300]="<FirstName>";ui.text.native_parses.clear();entry=queued(ui,packet());var count: int=ui.chat.rows.size();ui.present(entry.message,entry.speechText)
	check(ui.chat.rows.size()==count and ui.pending_speech_logs.size()==1 and ui.pending_speech_logs[0].receipt.has("header"),"Unknown retained named context remains pending in the actual existing log receipt path")
	# Finish only the authored unrelated blocker before invoking the existing
	# deferred drain. No global startup/table-ready result is fabricated.
	ui.table_jobs.erase(100);var parse_count: int=ui.text.native_parses.size()
	ui.text.objects[42].replicated.name.firstName.text="Changed controlled actor";ui.drain_speech_logs()
	check(ui.chat.rows.size()==count and ui.pending_speech_logs.size()==1 and ui.text.native_parses.size()>parse_count and not ui.tables_ready and ui.text.native_parses.all(func(call):return not call.state.has("context")),"Actual retry cannot invent controlled-actor context when the native retained frame was unavailable")
	connection=4;ui.drain_speech_logs();check(ui.pending_speech_logs.is_empty() and ui.chat.rows.size()==count,"Pending Header log belonging to retired accepted connection is dropped by actual drain owner")
	connection=3;ui.text.overrides.erase(10300);ui.text.native_parses.clear();message=packet();message.speakerName={"firstName":{"strRef":100,"gender":1},"lastName":{"strRef":101,"gender":0}};entry=queued(ui,message)
	ui.text.objects.erase(42);row=show(ui,entry)
	check(row.name.text==" First   Last " and row.rich.text=="<FirstName> << raw Body","Captured explicit remote name does not depend on later source removal or current canonical-name adapter")
	ui.text.objects[42]=actor(42,"Controlled actor",2,3);ui.text.overrides[100]="<CUSTOM12>";ui.text.custom_tokens[12]="Override first";ui.text.events.clear();ui.text.native_parses.clear();entry=queued(ui,message);row=show(ui,entry)
	check(row.name.text=="Override first  Last " and ui.text.native_parses.size()==1 and ui.text.native_parses[0].state.gender==1 and ui.text.events==[{"kind":"fetch","ref":100,"gender":1},{"kind":"parse","raw":"<CUSTOM12>".to_utf8_buffer()},{"kind":"fetch","ref":101,"gender":0},{"kind":"fetch","ref":10300,"gender":0}],"Remote snapshot fetch parses only its own override under wire gender before the later base component/prefix")
	ui.text.overrides.erase(100)
	for channel in [5,15]:
		message=packet(channel,{"strRef":200} if channel==15 else {"text":"System literal"});entry=queued(ui,message);row=show(ui,entry)
		check(row.system and row.channel==channel and Categories.bits(row)==32 and row.name.text=="" and row.rich.text.begins_with("System "),"Actual channel system/category/prefix fields stay native for "+str(channel))
	for channel in [14,30]:
		message=packet(channel);entry=queued(ui,message);row=show(ui,entry)
		check(row.rich.text=="[DM Label] Body" and not row.system and Categories.bits(row)==4,"Actual DM wrapper adds only receiver brackets for "+str(channel))
	ui.text.overrides[66756]="";entry=queued(ui,packet(14));row=show(ui,entry)
	check(row.rich.text=="[] Body","Actual receiver adds14 brackets even for an empty native label")
	ui.text.overrides.erase(10300);ui.text.native_parses.clear();entry=queued(ui,packet());ui.text.overrides[10300]="Wrong override after receipt";row=show(ui,entry)
	check(row.rich.text=="<FirstName> << raw Body" and ui.text.native_parses.is_empty(),"Actual receive snapshots absent prefix override and later presentation reads original base without a new ParseStr")
	ui.text.overrides[10300]="<Nested>";ui.text.events.clear();entry=queued(ui,packet());ui.text.overrides[300]="Wrong later nested override";count=ui.chat.rows.size();ui.present(entry.message,entry.speechText)
	check(ui.chat.rows.size()==count and ui.pending_speech_logs.size()==1 and not ui.text.events.any(func(event):return event.kind=="fetch" and event.ref==300),"Actual Header defers an uncaptured nested selection instead of reading a later live override")
	check(ui.text.legacy_parses==0,"No integrated native header/body tested path silently invokes legacy resolve")
	ui.close();ui.queue_free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay.receive/queue/speech/present and Chat with real native TalkText TLK/parser over controlled bytes, source rows and context omissions. Partial header prefix/explicit remote promotion: base raw vs override parse, snapshot mutation isolation, wire fetch order/gender/whitespace, empty split, pending retained context, current connection retirement, removed source, system/filter categories and DM brackets. Canonical local-name stored ctor ownership remains existing adapter/backlog. No network/server/GPU/profile/key/build/process or rendered-pixel acceptance."}));file.close();quit(0 if failures.is_empty() else 1)
