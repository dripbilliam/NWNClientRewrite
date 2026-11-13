extends SceneTree
const NameState=preload("res://systems/native_data/actor_name_state.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
class TracingTalk extends Talk:
	var fetches: Array=[]
	var parses: Array=[]
	var legacy:=0
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selected: Dictionary)->Dictionary:
		fetches.append({"ref":ref,"gender":gender,"selection":selected.duplicate(true)});return super.fetch_native_reference_snapshot(ref,gender,selected)
	func parse_native_bytes(raw_bytes: PackedByteArray,state: Dictionary={}) -> Dictionary:
		var input: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(state.get("language",base.language)),true).get("text","")
		parses.append({"input":input,"state":state.duplicate(true)});return super.parse_native_bytes(raw_bytes,state)
	func resolve(_value: Variant,_id: int,_state: Dictionary={})->String:legacy+=1;return "FORBIDDEN LEGACY"
class LastPendingTalk extends TracingTalk:
	var hold_last:=true
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selected: Dictionary)->Dictionary:
		if ref==101 and hold_last:return {"found":false,"lookupComplete":false,"gender":gender,"reason":"Authored last-component resource wait"}
		return super.fetch_native_reference_snapshot(ref,gender,selected)
var checks:=0
var failures: Array=[]
var fixture: Dictionary={}
var current:={"connection":3,"generation":7,"areaId":91,"actorNameHistoryComplete":true}
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
static func tlk(rows: Dictionary)->PackedByteArray:
	var count:=1
	for key in rows:count=maxi(count,int(key)+1)
	var bytes:=PackedByteArray();bytes.resize(20+count*40);var magic:="TLK V3.0".to_ascii_buffer()
	for at in magic.size():bytes[at]=magic[at]
	bytes.encode_u32(8,0);bytes.encode_u32(12,count);bytes.encode_u32(16,bytes.size());var offset:=0
	for key in rows:
		var raw:=str(rows[key]).to_ascii_buffer();var at:=20+int(key)*40;bytes.encode_u32(at,1);bytes.encode_u32(at+28,offset);bytes.encode_u32(at+32,raw.size());bytes.append_array(raw);offset+=raw.size()
	return bytes
func source(native_lifetime: int=7,known: int=11)->Dictionary:
	return {"id":int(fixture.id),"objectType":5,"areaId":91,"nativeLifetime":native_lifetime,"clientKnownLifetime":known,"replicated":{"name":{"text":"Never use U party label"}},"appearance":{"name":{"text":"Never refetch P declaration"}}}
func observe(owner,row: Dictionary,label: String,talk,current_scope: Dictionary={})->Dictionary:
	if current_scope.is_empty():current_scope=current
	talk.objects[int(row.id)]=row
	return owner.observe(row,fixture.cases[label],talk,current_scope)
func base(talk)->bool:return talk.base.open_bytes(tlk({0:"Default Context",100:"First ",101:" Last",102:"<FirstName> << Base",200:"Base200",201:"Base201",300:"Base Nested"})) and talk.publish_native_family(false,true)
static func detached(value: Variant)->bool:
	if value is Dictionary:
		for key in value:
			if not detached(key) or not detached(value[key]):return false
		return true
	if value is Array:
		for part in value:
			if not detached(part):return false
		return true
	return value==null or value is String or value is StringName or value is int or value is float or value is bool
func received_cases(talk: TracingTalk,row: Dictionary)->void:
	var owner:=NameState.new();observe(owner,row,"base",talk);var before:=owner.records.duplicate(true);var count:=talk.fetches.size();var parses:=talk.parses.size()
	var receipt:=owner.capture_received(row,fixture.cases.base,talk,current);var result:=owner.resolve_received(receipt,talk,current)
	check(result.ready and result.name=="First   Last" and talk.fetches.size()==count and talk.parses.size()==parses and owner.records==before,"CHAT capture copies the exact cached ready publication with no repeated TLK fetch or global mutation")
	check(detached(receipt) and receipt.record.reader==talk.get_instance_id(),"Received name receipt contains detached dictionaries/scalars and a scalar reader identity, never Nodes or Resources")
	result.name="Returned result mutation";result.witness[1]=999
	check(owner.resolve_received(receipt,talk,current).name=="First   Last" and receipt.result.witness[1]==7,"Ready name result is detached and frozen across later caller mutation")
	observe(owner,row,"newPublication",talk);count=talk.fetches.size()
	check(owner.resolve_received(receipt,talk,current).name=="First   Last" and owner.name(row,current).name=="New P" and talk.fetches.size()==count,"Newer P cannot rewrite an already captured earlier CHAT name")
	var earlier:=owner.capture_received(row,fixture.cases.literal,talk,current)
	check(owner.resolve_received(earlier,talk,current).name=="First   Last" and owner.name(row,current).name=="New P","CHAT private metadata older than coalesced raw cache creates an isolated exact older name")
	owner.reset();observe(owner,row,"literal",talk);before=owner.records.duplicate(true)
	var ahead:=owner.capture_received(row,fixture.cases.newPublication,talk,current)
	check(owner.resolve_received(ahead,talk,current).name=="New P" and owner.records==before and owner.name(row,current).name=="First   Last","CHAT private metadata newer than coalesced raw cache resolves without overwriting that cache")
	var pending_talk:=TracingTalk.new();var pending_owner:=NameState.new();var input: Dictionary=fixture.receivedPending.duplicate(true)
	var delayed:=pending_owner.capture_received(row,input,pending_talk,current)
	check(delayed.get("version")==1 and delayed.result==null and pending_owner.records.is_empty(),"Unavailable captured P named-token table creates an isolated pending receipt without a global name record")
	input.publication.environment.customTokens.records[0].bytes[0]=88;input.publication.first.override.text="Changed caller metadata"
	var other_count:=talk.fetches.size()
	check(pending_owner.resolve_received(delayed,talk,current).get("pending",false) and talk.fetches.size()==other_count,"Pending captured reference refuses a different Text owner before any fetch")
	observe(pending_owner,row,"newPublication",talk);pending_owner.retire(int(row.id));var reused:=source(8,15);observe(pending_owner,reused,"replacement",talk)
	check(base(pending_talk),"Captured pending Text owner receives its own controlled native family")
	pending_talk.named=talk.named.duplicate(true);pending_talk.named_ready=true
	pending_talk.objects[int(row.id)]=reused;pending_talk.overrides[200]="LATE LIVE WRONG";pending_talk.custom_tokens[12]="LATE LIVE TOKEN"
	var tainted:=current.duplicate();tainted.actorNameHistoryComplete=false
	result=pending_owner.resolve_received(delayed,pending_talk,tainted)
	check(result.ready and result.name=="At receipt Café   Last" and pending_owner.name(reused,current).name=="Replacement owner","Captured historical history/context/CUSTOM/selection survives later P/removal/ID reuse and unrelated live history taint without retargeting")
	pending_talk.close();count=talk.fetches.size()
	check(pending_owner.resolve_received(delayed,talk,current).name=="At receipt Café   Last" and talk.fetches.size()==count,"Already-ready historical strings no longer need their captured Text owner")
	var gated:=LastPendingTalk.new();check(base(gated),"Component-order receipt fixture uses real native reference fetches")
	var ordered:=owner.capture_received(row,fixture.cases.base,gated,current)
	check(ordered.result==null and ordered.record.slots.first.ready and ordered.record.slots.first.text=="First ","First component remains stored while the second component waits")
	gated.base.open_bytes(tlk({100:"WRONG LATER FIRST",101:"Later Last"}));gated.hold_last=false
	result=owner.resolve_received(ordered,gated,current)
	check(result.ready and result.name=="First  Later Last","Deferred second component cannot refetch the completed first component after base resource changes")
	var next_scope:=current.duplicate();next_scope.generation=8
	check(owner.resolve_received(receipt,talk,next_scope).get("pending",false),"Historical ready receipt rejects a different area generation")
	next_scope=current.duplicate();next_scope.areaId=92
	check(owner.resolve_received(receipt,talk,next_scope).get("pending",false),"Historical ready receipt rejects a different active area")
	next_scope=current.duplicate();next_scope.connection=4
	check(owner.resolve_received(receipt,talk,next_scope).get("pending",false),"Historical ready receipt rejects a different accepted connection")
	check(not owner.capture_received(row,fixture.cases.literal,talk,tainted).has("version"),"Uncertified CHAT history cannot create a historical receipt even with plausible source metadata")
	var missing_scope:=current.duplicate();missing_scope.areaId=null
	check(not owner.capture_received(row,fixture.cases.literal,talk,missing_scope).has("version"),"CHAT scope still pending does not invent an area; caller retains raw metadata until admission")
	var unknown:=owner.capture_received(row,fixture.cases.unknownContext,talk,current);talk.objects[99]={"id":99,"objectType":5,"appearance":{"name":{"text":"Later unsafe provider"}}}
	check(owner.resolve_received(unknown,talk,current).get("pending",false),"Historical pending P context cannot be filled from a later live same-ID provider")
	var encoded:=JSON.stringify(delayed);var decoded: Variant=JSON.parse_string(encoded)
	check(decoded is Dictionary and pending_owner.resolve_received(decoded,talk,current).get("name")=="At receipt Café   Last","Detached ready name receipt survives an actual JSON number/string round trip")
	owner.close();check(owner.resolve_received(receipt,talk,current).get("pending",false),"Closed name owner refuses historical receipt callbacks")
	gated.close();pending_owner.close()
func run()->void:
	var report:="";var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
	if report.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(fixture.source==NameState.SOURCE and fixture.provenance.jsTextResolution==false and fixture.cases.size()==25,"Actual protocol helper generated all25 metadata cases with no JS text resolution")
	var talk:=TracingTalk.new();check(base(talk),"Actual TalkText native TLK pair supplies name-reference records")
	talk.named=[{"name":"FirstName","hash":Talk.token_hash("FirstName"),"action":3,"default":0,"refs":[0,0,0,0]},{"name":"Nested","hash":Talk.token_hash("Nested"),"action":0,"default":0,"refs":[300,300,300,300]}];talk.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash));talk.named_ready=true;talk.custom_tokens={12:"LIVE LATER"}
	var owner:=NameState.new();var row:=source();var before:=row.duplicate(true);var result:=observe(owner,row,"fresh",talk)
	check(result.ready and result.name=="" and result.first.known and result.last.known and result.override.known and row==before,"Explicit fresh ctor initializes all3known empty without mutating actual source row")
	check(talk.fetches.is_empty() and talk.parses.is_empty(),"Constructor defaults require no TLK/parser or party-name borrowing")
	result=observe(owner,row,"literal",talk)
	check(result.ready and result.name=="First   Last" and result.first.text=="First " and result.last.text==" Last","Actual P metadata resolves conditional native stored join without trimming")
	var fetched_count:=talk.fetches.size();var parsed_count:=talk.parses.size()
	for _index in 20:owner.name(row,current)
	check(talk.fetches.size()==fetched_count and talk.parses.size()==parsed_count,"Reading stored slots at speech time does not refetch or reparse")
	for label in ["raw","empty"]:
		owner.reset();result=observe(owner,row,label,talk)
		check(result.ready and result.name==("  Raw  " if label=="raw" else ""),"Raw P first/known-empty last and empty-success stay native: "+label)
	owner.reset();talk.fetches.clear();talk.parses.clear();result=observe(owner,row,"base",talk)
	check(result.ready and result.name=="First   Last" and talk.fetches.size()==2 and talk.fetches[0].ref==100 and talk.fetches[0].gender==1 and talk.fetches[1].ref==101 and talk.fetches[1].gender==0,"First/last native reference fetch order and explicit wire genders are retained")
	check(talk.parses.is_empty() and owner.records[int(row.id)].slots.first.gender==1,"Base fetchFlag0 never invokes ParseStr; aliased female keeps effective gender1")
	owner.reset();result=observe(owner,row,"rawBase",talk);check(result.ready and result.name=="<FirstName> << Base","Stored normal TLK text preserves tokens and escapes without a second parse")
	owner.reset();talk.overrides[200]="LATER DIRECT";talk.parses.clear();var input: Dictionary=fixture.cases.override.duplicate(true);talk.objects[int(row.id)]=row;result=owner.observe(row,input,talk,current)
	input.publication.environment.customTokens.records[0].bytes[0]=88;talk.custom_tokens[12]="AFTER";talk.overrides[200]="EVEN LATER";owner.data_changed(talk,current)
	check(result.ready and owner.name(row,current).name=="Café   Last" and talk.parses.size()==1 and talk.parses[0].state.gender==1,"Captured selected override/CUSTOM bytes resolve once in Godot and remain detached from later metadata/live updates")
	owner.reset();talk.overrides[100]="NEW AFTER P";result=observe(owner,row,"absentBeforeLateOverride",talk)
	check(result.ready and result.name=="First  Last","P-time known absent override reads actual base through snapshot API, never the later live override")
	talk.overrides.erase(100);owner.reset();talk.parses.clear();result=observe(owner,row,"unknownContext",talk)
	check(result.get("pending",false) and owner.pending.has(int(row.id)),"Actual context-dependent override remains pending when P retained state was unknown")
	talk.objects[99]={"id":99,"objectType":5,"replicated":{"name":{"firstName":{"text":"UNSAFE LATER"},"lastName":{"text":""}}}};owner.data_changed(talk,current)
	check(owner.name(row,current).get("pending",false) and talk.parses.all(func(call):return not call.state.has("context")),"Deferred P never borrows later chat/actor/global context")
	owner.reset();result=observe(owner,row,"nullContext",talk)
	check(result.get("pending",false) and talk.parses[-1].state.context.is_empty(),"Explicit native NULL maps correctly but an uncaptured nested default reference stays unavailable")
	owner.reset();result=observe(owner,row,"nullContextCovered",talk)
	check(result.ready and result.name=="Default Context Default Context","Certified NULL default can resolve when its exact reference selection was captured by the other direct component")
	owner.reset();talk.overrides[300]="LATE WRONG NESTED";result=observe(owner,row,"nested",talk)
	check(result.get("pending",false),"Uncaptured named-token reference cannot borrow a later live override while resolving a stored P name")
	owner.reset();result=observe(owner,row,"nestedCovered",talk)
	check(result.ready and result.name=="Base Nested Base Nested","A nested reference captured as a direct component uses its P-time absent selection instead of the late live override")
	talk.overrides.erase(300)
	owner.reset();result=observe(owner,row,"frozenContext",talk);fixture.cases.frozenContext.publication.environment.parserState.context.appearance.name.firstName.text="Changed after capture"
	check(result.ready and owner.name(row,current).name=="At P Last","Explicit P-time provider context is detached and never becomes a later same-ID name")
	owner.reset();result=observe(owner,row,"failed",talk);fetched_count=talk.fetches.size();talk.base.open_bytes(tlk({999:"FUTURE DIFFERENT"}));owner.data_changed(talk,current)
	check(result.ready and result.name=="Last" and owner.records[int(row.id)].slots.first.source=="failed-native-fetch" and talk.fetches.size()==fetched_count and owner.name(row,current).name=="Last","Completed failed native fetch stores empty once; later TLK content cannot retroactively rename it")
	check(base(talk),"Restore controlled native family for remaining independent cases")
	owner.reset();result=observe(owner,row,"invalid",talk);check(result.ready and result.name=="Last","Native invalid-reference guard stores successful empty instead of perpetual pending")
	owner.reset();result=observe(owner,row,"unknownOverride",talk);check(result.get("pending",false),"Genuinely unavailable P-time override selection remains pending despite live base data")
	owner.reset();result=observe(owner,row,"preexisting",talk);check(result.get("pending",false),"Preexisting P without ctor/override ownership never receives invented empty override")
	owner.reset();observe(owner,row,"literal",talk);owner.retire(int(row.id));var redisclosed:=source(7,14);result=observe(owner,redisclosed,"confirmedRedisclosure",talk)
	check(result.ready and result.name=="First   Last" and owner.name(row,current).get("pending",false),"Explicit same typed owner/publication can rebind resolved strings to current known life; old references stay retired")
	owner.reset();observe(owner,row,"literal",talk);owner.retire(int(row.id));result=observe(owner,redisclosed,"ambiguousRedisclosure",talk)
	check(result.get("pending",false) and not owner.pending.has(int(row.id)),"Ambiguous D+A publication.current=false stays dormant without resetting cached defaults or polling")
	result=observe(owner,redisclosed,"afterAmbiguous",talk);check(result.ready and result.name=="New P after redisclosure","A newly captured actual P restores current name publication after ambiguous redisclosure")
	owner.reset();observe(owner,row,"literal",talk);var next_scope:=current.duplicate();next_scope.generation=8;fetched_count=talk.fetches.size();result=observe(owner,row,"literal",talk,next_scope)
	check(result.ready and result.name=="First   Last" and talk.fetches.size()==fetched_count and owner.name(row,current).get("pending",false),"Resolved strings can rebind under current explicit same owner fact without old-scope reference revival")
	owner.reset();observe(owner,row,"unknownContext",talk);result=observe(owner,row,"unknownContext",talk,next_scope);owner.data_changed(talk,next_scope)
	check(result.get("pending",false) and owner.records[int(row.id)].blocked and owner.pending.is_empty(),"Unresolved old-scope P receipt cannot resolve or be silently recaptured in the next generation")
	result=observe(owner,row,"newPublication",talk,next_scope);check(result.ready and result.name=="New P","New publication revision can replace an old-scope blocked receipt")
	result=observe(owner,row,"literal",talk,current);check(result.get("pending",false) and owner.name(row,next_scope).name=="New P","Old-generation observe cannot rebind a newer stored-name owner backwards")
	owner.reset();observe(owner,row,"unknownContext",talk);observe(owner,row,"newPending",talk,next_scope);parsed_count=talk.parses.size();owner.data_changed(talk,current)
	check(owner.pending.has(int(row.id)) and talk.parses.size()==parsed_count,"Old-scope data_changed cannot erase or resolve a current pending name receipt")
	owner.reset();observe(owner,row,"literal",talk);var reused:=source(8,15);result=observe(owner,reused,"replacement",talk)
	check(result.ready and result.name=="Replacement owner" and owner.name(row,current).get("pending",false),"New native source plus explicit new construction fact replaces prior cached name without ID retargeting")
	var uncertain:=current.duplicate();uncertain.actorNameHistoryComplete=false
	check(owner.name(reused,uncertain).get("pending",false),"Global complete-history gate is separate from base Scope and blocks otherwise ready names")
	owner.reset();result=observe(owner,row,"fresh",talk,uncertain);check(result.get("pending",false) and owner.records.is_empty(),"History-uncertain capture cannot fabricate fresh stats from a valid-looking metadata/token tuple")
	observe(owner,row,"literal",talk,current)
	var new_connection:=current.duplicate();new_connection.connection=4;result=observe(owner,reused,"fresh",talk,new_connection)
	check(result.ready and result.name=="" and owner.connection==4 and owner.name(reused,current).get("pending",false),"Fresh accepted connection gets its own ctor defaults and cannot borrow old scope")
	result=observe(owner,row,"literal",talk,current);check(result.get("pending",false) and owner.connection==4,"Retired connection callback cannot rebind a later actor-name owner backwards")
	owner.reset();observe(owner,row,"literal",talk);var malformed: Dictionary=fixture.cases.newPublication.duplicate(true);malformed.source="untrusted";result=owner.observe(row,malformed,talk,current)
	check(result.get("pending",false) and owner.name(row,current).get("pending",false),"Invalid same-witness current metadata cannot expose a prior ready stored name")
	observe(owner,row,"literal",talk);result=owner.observe(row,null,talk,current)
	check(result.get("pending",false) and owner.name(row,current).get("pending",false),"Omitted current protocol metadata retires certification without inferring constructor from lifetimes")
	observe(owner,row,"literal",talk);var changed: Dictionary=fixture.cases.literal.duplicate(true);changed.publication.first.text="INJECTED same revision";result=owner.observe(row,changed,talk,current)
	check(result.get("pending",false) and owner.name(row,current).get("pending",false) and owner.records[int(row.id)].slots.first.text=="First ","Exact same-revision metadata comparison rejects changed content and preserves old bytes dormant, without a hash proof")
	received_cases(talk,row)
	owner.close();owner.data_changed(talk,current);check(owner.records.is_empty() and owner.pending.is_empty() and owner.name(row,current).get("pending",false),"Close clears all small records/receipts and rejects stale retries with no processing loop")
	check(talk.legacy==0 and owner.get_class()=="RefCounted" and not owner.has_method("_process"),"No legacy resolve, renderer, Node or frame processing is used")
	talk.close();var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual JS protocol helper metadata -> JSON -> Godot stored actor-name state with real TalkText selected fetch/parser and controlled TLK bytes. Explicit authored accepted-boundary facts test ctor/P/retained/unknown metadata only, not original execution. Stored-string caching, exact join/empty success, selected override/CUSTOM/context timing, native failure versus pending, scope/history/lifetime and no speech-time lookup. No Gameplay/Header integration, server/GPU/key/profile/build/process/pixel acceptance."}));file.close();quit(0 if failures.is_empty() else 1)
