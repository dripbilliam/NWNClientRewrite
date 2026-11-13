extends SceneTree
# Actual Gameplay.speech/receive and native body receipts. These authored
# strings exercise the source-proved branch matrix, not a fake server outcome.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Receipt=preload("res://systems/native_data/ordinary_speech_text_receipt.gd")
const Overhead=preload("res://systems/native_overhead_speech.gd")
class Chat extends Node:
	var rows: Array=[]
	func append_message(value: Dictionary) -> void:rows.append(value.duplicate(true))
class TracingTalk extends Talk:
	var parses: Array=[]
	func fetch_native_reference(ref: Variant,gender: Variant=0) -> Dictionary:
		# This fixture isolates body parsing. Header fetches now have their own
		# actual Talk/TLK integration gate; provide explicit base labels here.
		if int(ref) in [10300,10301,10302,10299,10303,66756]:return {"found":true,"text":"","duration":0.0,"gender":int(gender),"override":false}
		return super.fetch_native_reference(ref,gender)
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selection: Dictionary) -> Dictionary:
		if int(ref) in [10300,10301,10302,10299,10303,66756]:return {"found":true,"text":"","duration":0.0,"gender":int(gender),"override":false,"lookupComplete":true}
		return super.fetch_native_reference_snapshot(ref,gender,selection)
	func parse_native(input: String,call_state: Dictionary={}) -> Dictionary:
		parses.append({"input":input,"state":call_state.duplicate(true)})
		return super.parse_native(input,call_state)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
static func tlk(values: Array) -> PackedByteArray:
	var size:=20+values.size()*40
	for value in values:size+=str(value).to_ascii_buffer().size()
	var data:=PackedByteArray();data.resize(size);var magic:="TLK V3.0".to_ascii_buffer()
	for at in magic.size():data[at]=magic[at]
	var offset:=20+values.size()*40;var relative:=0
	data.encode_u32(8,0);data.encode_u32(12,values.size());data.encode_u32(16,offset)
	for index in values.size():
		var bytes:=str(values[index]).to_ascii_buffer();var at:=20+index*40
		data.encode_u32(at,1);data.encode_u32(at+28,relative);data.encode_u32(at+32,bytes.size())
		for byte in bytes.size():data[offset+relative+byte]=bytes[byte]
		relative+=bytes.size()
	return data
static func actor(id: int,native_lifetime: int,known: int,first: String) -> Dictionary:
	return {"id":id,"areaId":91,"objectType":5,"nativeLifetime":native_lifetime,"clientKnownLifetime":known,"replicated":{"name":{"firstName":{"text":first},"lastName":{"text":""}},"stats":{"race":0}}}
static func message(channel: int,value: Variant) -> Dictionary:
	return {"kind":"server-speech","channel":channel,"objectId":42,"contextId":99,"text":value,"nativeTextEvent":{"version":1,"serial":1,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"areaId":91,"objectType":5,"nativeLifetime":2,"knownLifetime":3},"context":{"id":99,"areaId":91,"objectType":5,"nativeLifetime":8,"knownLifetime":13}}}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.text.close();ui.text=TracingTalk.new()
	ui.generation=7;ui.area_id=91;ui.controlled_id=42;ui.native_connection_query=func():return 3
	ui.text.objects={42:actor(42,2,3,"Speaker"),99:actor(99,8,13,"Context")};ui.text.custom_tokens[12]="Unexpected replacement"
	ui.text.named=[{"name":"FirstName","hash":Talk.token_hash("FirstName"),"action":3,"default":4294967295,"refs":[]},{"name":"Start","hash":Talk.token_hash("Start"),"action":19},{"name":"Stop","hash":Talk.token_hash("Stop"),"action":22}]
	ui.text.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash));ui.text.named_ready=true
	ui.chat=Chat.new();ui.add_child(ui.chat)
	var literal:="Literal <CUSTOM12> <FirstName> <<angle>"
	for channel in [1,2,3,4,5,6,14,17,18,19,20,22,30]:
		var row: Dictionary=ui.speech(message(channel,{"text":literal}))
		check(not row.is_empty() and row.text==literal,"Native literal body is not talk-token parsed for channel "+str(channel))
		check(row.get("rich",{}).get("text","").ends_with(literal),"Existing prefix and log formatting preserve the exact literal body for channel "+str(channel))
	check(ui.text.parses.is_empty(),"Literal chat does not invoke the certified talk parser as a substitute for font markup")
	var colored:="<c"+String.chr(1)+String.chr(254)+String.chr(1)+">Tint</c>"
	var row: Dictionary=ui.speech(message(1,{"text":colored}))
	check(row.text=="Tint" and row.rich.spans.any(func(span):return span.get("text","")=="Tint" and span.has("color")),"Literal native color commands still reach the font-markup projection")
	check(ui.text.base.open_bytes(tlk(["<CUSTOM12>","", "<<FirstName>"])) and ui.text.publish_native_family(false,true),"Reference fixtures use an actual loaded native TLK pair")
	row=ui.speech(message(15,{"strRef":0}))
	check(row.text=="<CUSTOM12>" and row.system,"Channel15 base TLK parseFlag0 remains raw in the system log")
	check(ui.speech(message(15,{"strRef":1})).is_empty(),"Native empty reference body is dropped for channel15")
	ui.text.overrides[0]="<CUSTOM12>";ui.text.custom_tokens[12]="Receipt-time replacement"
	var event:=message(15,{"strRef":0});var receipt:=Receipt.capture(event,ui.text,ui.overhead_context())
	ui.text.custom_tokens[12]="Later replacement";ui.text.parses.clear();row=ui.speech(event,receipt)
	check(row.text=="Receipt-time replacement" and ui.text.parses.size()==1 and ui.text.parses[0].state.gender==0,"Channel15 override gets one retained-state parse with its complete receipt snapshot")
	var overlay:=Control.new();ui.add_child(overlay)
	ui.overhead=Overhead.new();ui.add_child(ui.overhead);ui.overhead.configure_processing(false)
	ui.overhead.configure(overlay,ui.text,null,null,null,ui.overhead_context,ui.overhead_source,ui.overhead_anchor)
	ui.text.parses.clear();event=message(12,{"text":"<Start>Hidden<Stop> <FirstName>"});var unchanged:=event.duplicate(true)
	ui.receive(event,7)
	check(ui.queue.size()==1 and ui.overhead.state.speakers.is_empty() and ui.overhead.pending.is_empty() and ui.overhead.views.is_empty(),"Channel12 reaches the actual log queue without publishing ordinary overhead")
	var queued: Dictionary=ui.queue.pop_front();ui.present(queued.message,queued.speechText)
	check(ui.chat.rows.size()==1 and ui.chat.rows[0].text=="Hidden Context","Channel12 logs its independently BC0-parsed localized body")
	check(ui.text.parses.size()==2 and ui.text.parses[0].state.nativeBC==1 and ui.text.parses[1].state.nativeBC==0,"Channel12 still executes the unused BC1 copy before the BC0 log copy")
	check(queued.speechText.overhead.body==" Context" and event==unchanged,"Suppressed copy is separate and the received packet is unchanged")
	ui.text.parses.clear();ui.text.overrides[2]="<<FirstName>";event=message(12,{"strRef":2,"gender":1})
	receipt=Receipt.capture(event,ui.text,ui.overhead_context());row=ui.speech(event,receipt)
	check(row.text=="Context" and ui.text.parses.size()==3,"Channel12 override performs initial fetch parse and both explicit copies")
	check(ui.text.parses[0].state.gender==1 and not ui.text.parses[0].state.has("context") and ui.text.parses[1].state.gender==0 and ui.text.parses[2].state.gender==0,"Localized initial wire gender remains separate from both context-derived copy genders")
	ui.close();ui.queue_free();await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"literalChannels":13,"scope":"Actual Gameplay literal-channel log projection, reference15 base/override/empty semantics, localized12 initial/BC1/BC0 order, independent context gender and absence of ordinary popup. Controlled received fields/TLK bytes; no optional word filter, server/GPU/native pixels or prefix/name native-provider claim."}));file.close();print("NATIVE_SPEECH_LOG_BODIES ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
