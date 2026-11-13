extends SceneTree
const Receipt=preload("res://systems/native_data/ordinary_speech_text_receipt.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
class TracedTalk extends Talk:
	var parses: Array=[]
	var genders: Array=[]
	var base_rows: Dictionary={}
	func fetch_reference(ref: int,gender: int=0) -> Dictionary:
		genders.append(gender)
		if not overrides.has(ref) and base_rows.has(ref):return {"found":true,"text":base_rows[ref],"duration":7.5 if gender==1 else 5.0}
		return super.fetch_reference(ref,gender)
	func fetch_native_reference(ref: Variant,gender: Variant=0) -> Dictionary:
		if not overrides.has(ref) and base_rows.has(ref):
			var fetched:=fetch_reference(int(ref),int(gender));fetched.gender=int(gender);fetched.override=false;return fetched
		return super.fetch_native_reference(ref,gender)
	func parse_native(input: String,call_state: Dictionary={}) -> Dictionary:
		parses.append({"input":input,"state":call_state.duplicate(true)})
		return super.parse_native(input,call_state)
class Chat extends Node:
	var rows: Array=[]
	func append_message(row: Dictionary) -> void:rows.append(row.duplicate(true))
var current:=Scope.context(3,7,91)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func row() -> Dictionary:return {"id":99,"areaId":91,"objectType":5,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"firstName":{"text":"Before"},"lastName":{"text":"After"}}}}
func message(value: Variant,channel: int=11) -> Dictionary:
	return {"kind":"server-speech","channel":channel,"objectId":42,"contextId":99,"text":value,"nativeTextEvent":{"version":1,"serial":1,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":5,"areaId":91,"nativeLifetime":2,"knownLifetime":3},"context":{"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var talk:=TracedTalk.new();talk.named_ready=true
	talk.named=[{"name":"FirstName","hash":Talk.token_hash("FirstName"),"action":3,"default":4294967295,"refs":[]},{"name":"BeginHighlight","hash":Talk.token_hash("BeginHighlight"),"action":19},{"name":"EndHighlight","hash":Talk.token_hash("EndHighlight"),"action":22}]
	talk.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash))
	talk.objects[99]=row();talk.custom_tokens[12]="Receipt token"
	var original:=message({"text":"<CUSTOM12>"});var original_copy:=original.duplicate(true)
	var receipt:=Receipt.capture(original,talk,current)
	talk.custom_tokens[12]="Future token";talk.objects[99].replicated.name.firstName.text="Future name"
	check(Receipt.prepare(receipt,talk,current).body=="Receipt token","Complete custom-token snapshot never borrows a future value")
	check(original==original_copy,"Receipt leaves received packet and provenance unchanged")
	receipt=Receipt.capture(message({"text":"<FirstName>"}),talk,current);talk.objects[99]=row()
	check(Receipt.prepare(receipt,talk,current).body=="Future name","Matched context row is copied at receipt before later modification")
	var escaped:=message({"text":"<<FirstName>"});escaped.nativeTextEvent.context=null
	check(Receipt.prepare(Receipt.capture(escaped,talk,current),talk,current).body=="<FirstName>","Literal localized escape requires no context provider")
	talk.base_rows[100]="<<FirstName>";talk.overrides[101]="<<FirstName>"
	var base:=Receipt.capture(message({"strRef":100,"gender":1}),talk,current)
	check(Receipt.prepare(base,talk,current).body=="<FirstName>" and Receipt.prepare(base,talk,current).forced==7.5,"Base localized TLK has one explicit parse and preserves wire-gender duration")
	var over:=Receipt.capture(message({"strRef":101,"gender":1}),talk,current);talk.parses.clear()
	check(Receipt.prepare(over,talk,current).body=="Before","Override has initial retained-state parse before explicit context copy")
	check(talk.parses.size()==2 and not talk.parses[0].state.has("context") and not talk.parses[0].state.has("nativeB8") and talk.parses[0].state.gender==1 and talk.parses[1].state.nativeBC==1,"Override initial context/flags stay unknown; explicit overhead copy has BC1")
	check(Receipt.prepare(over,talk,current,true).body=="Before" and talk.parses.size()==3 and talk.parses[2].state.nativeBC==0,"Log uses a distinct explicit BC0 copy of the same fetched body")
	Receipt.prepare(over,talk,current);Receipt.prepare(over,talk,current,true)
	check(talk.parses.size()==3,"Resolved copies are cached; repeated consumers do not parse again")
	talk.overrides[102]="<FirstName>";over=Receipt.capture(message({"strRef":102,"gender":0}),talk,current)
	check(Receipt.prepare(over,talk,current).get("pending",false) and not over.has("fetchedBody"),"Override cannot use newly supplied message context for the initial retained-state pass")
	talk.overrides[103]="<CUSTOM12>";over=Receipt.capture(message({"strRef":103},8),talk,current)
	check(Receipt.prepare(over,talk,current).body=="Future token","Ordinary override CUSTOM is actor-independent and no longer blanket-blocked")
	talk.overrides[104]="<<FirstName>";talk.parses.clear();over=Receipt.capture(message({"strRef":104},8),talk,current)
	check(Receipt.prepare(over,talk,current).body=="<FirstName>" and talk.parses.size()==1 and talk.parses[0].state.gender==0,"Ordinary override has exactly one pass with gender0")
	talk.base_rows[105]="<FirstName>";talk.parses.clear()
	check(Receipt.prepare(Receipt.capture(message({"strRef":105},8),talk,current),talk,current).body=="<FirstName>" and talk.parses.is_empty(),"Ordinary base TLK parseFlag0 leaves token-shaped bytes raw")
	var color:="<c"+String.chr(1)+String.chr(254)+String.chr(1)+">Raw</c>"
	check(Receipt.prepare(Receipt.capture(message({"text":color}),talk,current),talk,current).body=="<UNRECOGNIZED TOKEN>Raw<UNRECOGNIZED TOKEN>","Certified native calls do not bypass raw RGB tags")
	var begin:="<BeginHighlight>Important<EndHighlight>"
	receipt=Receipt.capture(message({"text":begin}),talk,current)
	check(Receipt.prepare(receipt,talk,current).body=="","Overhead BC1 suppresses the enclosed text, matching original ParseStr")
	check(Receipt.prepare(receipt,talk,current,true).body==color.left(6)+"Important</c>","Independent log BC0 emits provider-generated color bytes")
	var unknown:=message({"text":"<FirstName>"});unknown.nativeTextEvent.context=null
	check(Receipt.prepare(Receipt.capture(unknown,talk,current),talk,current).get("pending",false),"Unknown context does not adopt any row by ID")
	unknown.contextId=Receipt.OBJECT_INVALID
	check(Receipt.prepare(Receipt.capture(unknown,talk,current),talk,current).body=="","Explicit OBJECT_INVALID is known NULL and uses native default reference")
	unknown=message({"text":"<FirstName>"});talk.objects[99].clientKnownLifetime=14
	check(Receipt.prepare(Receipt.capture(unknown,talk,current),talk,current).get("pending",false),"Wrong lifetime cannot be captured as message context")
	talk.objects[99]=row();talk.base_rows.erase(106);receipt=Receipt.capture(message({"strRef":106,"gender":0}),talk,current)
	talk.objects[99].clientKnownLifetime=14;talk.objects[99].replicated.name.firstName.text="Reused";talk.base_rows[106]="<FirstName>"
	check(Receipt.prepare(receipt,talk,current).body=="Before","Late resource completion uses already captured exact context, not reused object")
	check(not Receipt.prepare(Receipt.capture(message({"strRef":100}),talk,current),talk,current).get("ready",false),"Missing localized wire gender is unavailable rather than silently defaulted")
	talk.objects[99]=row();talk.objects[99].appearance={"gender":0};talk.objects[99].replicated.stats={"race":1,"classes":[{"level":6},{"level":99}]};talk.parses.clear()
	receipt=Receipt.capture(message({"text":"<FirstName>"}),talk,current);talk.objects[99].replicated.stats.race=0;Receipt.prepare(receipt,talk,current)
	check(talk.parses.size()==1 and talk.parses[0].state.gender==1,"Explicit copy uses receipt Stats+68 BYTE rather than wire/appearance gender or a future update")
	check(receipt.context.replicated.stats.classes.size()==1 and receipt.context.replicated.stats.classes[0].level==6,"Token context copies only certified first-class data, not an entire actor graph")
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.text.close();ui.text=talk;ui.generation=7;ui.area_id=91;ui.native_connection_query=func():return 3
	ui.chat=Chat.new();ui.add_child(ui.chat)
	var delayed:=message({"text":"<UnknownNativeToken>"});talk.named_ready=false
	ui.receive(delayed,7);check(ui.queue.size()==1 and ui.queue[0].speechText.tokensReady,"Actual Gameplay ingress captures a shared receipt without optional menu readiness")
	check(ui.queue[0].speechText.has("context") and int(ui.queue[0].speechText.context.id)==99,"Actual raw Gameplay owner scope captures the witnessed context at receipt, before deferred parsing")
	var queued: Dictionary=ui.queue.pop_front();ui.present(queued.message,queued.speechText)
	check(ui.pending_speech_logs.size()==1 and ui.chat.rows.is_empty(),"Unavailable named table defers its log without displaying fabricated text")
	talk.named_ready=true;ui.drain_speech_logs()
	check(ui.pending_speech_logs.is_empty() and ui.chat.rows.size()==1 and ui.chat.rows[0].text=="<UNRECOGNIZED TOKEN>","State-update drain publishes resolved log exactly once")
	ui.drain_speech_logs();check(ui.chat.rows.size()==1,"Repeated data update cannot duplicate a published log")
	talk.named_ready=false;ui.present(delayed,Receipt.capture(delayed,talk,current));ui.generation=8;talk.named_ready=true;ui.drain_speech_logs()
	check(ui.pending_speech_logs.is_empty() and ui.chat.rows.size()==1,"Old-generation deferred log retires rather than entering next area")
	ui.close();ui.queue_free();await process_frame
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Source-certified ordinary FetchInternal/ParseStr stages, receipt mutation/lifetime isolation and actual Gameplay ingress/deferred log delivery; authored text providers. No live server, GPU or pixels."}));file.close();print("NATIVE_ORDINARY_TEXT_RECEIPT ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
