extends SceneTree
const Header=preload("res://systems/native_data/ordinary_speech_header_receipt.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
class TracingTalk extends Talk:
	var fetches: Array=[]
	var parses: Array=[]
	var legacy:=0
	func fetch_native_reference(ref: Variant,gender: Variant=0)->Dictionary:
		fetches.append([int(ref),int(gender)]);return super.fetch_native_reference(ref,gender)
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selected: Dictionary)->Dictionary:
		fetches.append([int(ref),int(gender)]);return super.fetch_native_reference_snapshot(ref,gender,selected)
	func parse_native_bytes(raw_bytes: PackedByteArray,state: Dictionary={}) -> Dictionary:
		var input: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(state.get("language",base.language)),true).get("text","")
		parses.append({"raw":input.to_utf8_buffer(),"state":state.duplicate(true)});return super.parse_native_bytes(raw_bytes,state)
	func resolve(_value: Variant,_id: int,_options: Dictionary={})->String:legacy+=1;return "FORBIDDEN LEGACY"
var checks:=0
var failures: Array=[]
var current:={"connection":3,"generation":7,"areaId":91}
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
static func tlk(rows: Dictionary)->PackedByteArray:
	var count:=1
	for index in rows:count=maxi(count,int(index)+1)
	var bytes:=PackedByteArray();bytes.resize(20+count*40);var magic:="TLK V3.0".to_ascii_buffer()
	for index in magic.size():bytes[index]=magic[index]
	bytes.encode_u32(8,0);bytes.encode_u32(12,count);bytes.encode_u32(16,bytes.size());var offset:=0
	for key in rows:
		var raw:=str(rows[key]).to_ascii_buffer();var at:=20+int(key)*40;bytes.encode_u32(at,1);bytes.encode_u32(at+28,offset);bytes.encode_u32(at+32,raw.size());bytes.append_array(raw);offset+=raw.size()
	return bytes
func packet(channel: int=1,type: int=10)->Dictionary:
	return {"kind":"server-speech","channel":channel,"objectId":42,"speakerName":{"text":"remote"},"nativeTextEvent":{"version":1,"serial":1,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":type,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func row(type: int=10)->Dictionary:return {"id":42,"objectType":type,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Door stored"}}}
func _initialize()->void:run.call_deferred()
func run()->void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var talk:=TracingTalk.new();talk.named_ready=true;talk.custom_tokens={12:"RECEIVED"}
	talk.named=[{"name":"FirstName","hash":Talk.token_hash("FirstName"),"action":3,"default":0,"refs":[0,0,0,0]},{"name":"Nested","hash":Talk.token_hash("Nested"),"action":0,"default":0,"refs":[300,300,300,300]}];talk.named.sort_custom(func(a,b):return int(a.hash)<int(b.hash))
	check(talk.base.open_bytes(tlk({100:" First ",101:" Last ",110:"Base Item",120:"Placeable Table",300:"Captured nested base",556:"Trigger Default",5189:"Unknown Provider",5548:"Unidentified",10299:"System Label",10300:"<FirstName> << raw",10301:"Whisper Label",10302:"Tell Label",10303:"Party Label",66756:"DM Label"})) and talk.publish_native_family(false,true),"Actual native TLK pair publishes controlled header records with male-file alias")
	talk.objects={42:row()};var message:=packet(2);message.speakerName={"text":"<FirstName> << literal"}
	var receipt:=Header.capture(message,talk,current);var result:=Header.prepare(receipt,talk,current)
	check(result.ready and result.name=="<FirstName> << literal" and result.prefix=="<FirstName> << raw" and talk.parses.is_empty(),"Remote literal and ordinary base prefix remain raw without ParseStr or escape expansion")
	check(talk.fetches==[[10300,0]],"Only actual channel label fetch runs with gender0 and no unknown-name fallback")
	talk.fetches.clear();message.speakerName={"firstName":{"strRef":100,"gender":1},"lastName":{"strRef":101,"gender":0}}
	receipt=Header.capture(message,talk,current);result=Header.prepare(receipt,talk,current)
	check(result.ready and result.name==" First   Last " and talk.fetches==[[100,1],[101,0],[10300,0]],"Remote first then exact single space then last preserves whitespace and wire fetch genders/order")
	talk.fetches.clear();message.speakerName={"firstName":{"text":""},"lastName":{"text":""}};message.nativeTextEvent.source=null
	receipt=Header.capture(message,talk,current);result=Header.prepare(receipt,talk,current)
	check(result.ready and result.name==" " and not talk.fetches.any(func(call):return call[0]==5189),"Remote empty split yields one space and never triggers provider fallback")
	message.speakerName={"text":""};receipt=Header.capture(message,talk,current);result=Header.prepare(receipt,talk,current)
	check(result.ready and result.name=="Unknown Provider","Known absent source provider with empty remote literal uses native5189")
	message=packet(1);talk.objects[42]=row();talk.objects[42].replicated.name={"text":""};receipt=Header.capture(message,talk,current);result=Header.prepare_name(receipt,talk,current)
	check(result.ready and result.name=="","Supported door provider succeeds with empty cached name without5189")
	var empty:=Header.value(receipt,"lower",Header.stored_creature({"text":""},{"text":""},{"text":""}),talk,{})
	check(empty.ready and empty.text=="","Pure certified creature stored-slot lower returns empty success without fallback")
	var joined:=Header.value(receipt,"lower",Header.stored_creature({"text":""},{"text":"First "},{"text":" Last"}),talk,{})
	check(joined.ready and joined.text=="First   Last","Creature stored join inserts separator only when both strings are nonempty and never trims")
	talk.objects[42]=row(5);talk.objects[42].appearance={"name":{"firstName":{"text":"Actual first"},"lastName":{"text":"Actual last"}}};talk.objects[42].replicated.name={"text":"Party row only"}
	receipt=Header.capture(packet(1,5),talk,current);result=Header.prepare_name(receipt,talk,current)
	check(result.get("pending",false),"Wire P/U declarations alone do not invent retained stats+40 or prior resolved canonical names")
	receipt=Header.capture(packet(3,5),talk,current);result=Header.prepare_prefix(receipt,talk,current)
	check(result.ready and result.prefix=="Whisper Label" and Header.prepare_name(receipt,talk,current).get("pending",false),"Proven prefix stage remains independent of missing canonical creature name provenance")
	talk.objects[42]=row(6);talk.objects[42].item={"identified":0.0,"baseItem":2,"name":{"text":"Ignored unidentified stored name"}};talk.tables.baseitems={"orderedRows":[{},{},{"Name":"110"}]}
	receipt=Header.capture(packet(1,6),talk,current);result=Header.prepare_name(receipt,talk,current)
	check(result.ready and result.name=="Base Item Unidentified","Actual item identification bit/baseitems Name+5548 provider uses native fetch0 and exact suffix separator")
	talk.objects[42].item.identified=1;talk.objects[42].item.name={"text":"Known stored item"};receipt=Header.capture(packet(1,6),talk,current);result=Header.prepare_name(receipt,talk,current)
	check(result.ready and result.name=="Known stored item","Identified nonempty stored item name bypasses base-item fallback")
	talk.objects[42]=row(9);talk.objects[42].replicated.name={"text":""};talk.objects[42].replicated.appearance=1;talk.tables.placeables={"orderedRows":[{},{"StrRef":"120"}]}
	receipt=Header.capture(packet(1,9),talk,current);result=Header.prepare_name(receipt,talk,current);check(result.ready and result.name=="Placeable Table","Empty placeable provider uses actual active appearance row StrRef")
	talk.objects[42]=row(7);talk.objects[42].replicated.name={"text":""};receipt=Header.capture(packet(1,7),talk,current);result=Header.prepare_name(receipt,talk,current);check(result.ready and result.name=="Trigger Default","Empty trigger provider fetches native556")
	# Snapshot mutable packet, row, CUSTOM and explicit retained frame separately.
	talk.objects[42]=row();message=packet(2);message.speakerName={"text":"Wire before"};talk.overrides[10300]="<CUSTOM12>"
	receipt=Header.capture(message,talk,current);message.speakerName.text="After";talk.custom_tokens[12]="LATER";talk.overrides[10300]="CHANGED"
	result=Header.prepare(receipt,talk,current)
	check(result.ready and result.name=="Wire before" and result.prefix=="RECEIVED","Header freezes packet literal, receipt-time override and CUSTOM even if active owners change")
	talk.overrides[10300]="<FirstName>";talk.custom_tokens[12]="RECEIVED";var provider_context:={"id":77,"objectType":5,"areaId":91,"nativeLifetime":20,"clientKnownLifetime":30,"appearance":{"name":{"firstName":{"text":"Context before"},"lastName":{"text":""}}}}
	receipt=Header.capture(packet(2),talk,current,{"context":provider_context,"nativeB8":0,"nativeBC":0});provider_context.appearance.name.firstName.text="Reused after";result=Header.prepare(receipt,talk,current)
	check(result.ready and result.prefix=="Context before","Override-only ParseStr receives a detached explicit current context, never the controlled actor or later row")
	talk.overrides[10300]="<FirstName>";receipt=Header.capture(packet(2),talk,current);result=Header.prepare(receipt,talk,current)
	check(result.get("pending",false),"Unknown retained native context remains explicit instead of controlled-actor fallback")
	talk.overrides.erase(10300);receipt=Header.capture(packet(2),talk,current);talk.overrides[10300]="new override after receipt";result=Header.prepare(receipt,talk,current)
	check(result.ready and result.prefix=="<FirstName> << raw","P-time absent prefix override reads the actual base despite a newly arrived live override")
	talk.overrides[10300]="<Nested>";receipt=Header.capture(packet(2),talk,current);talk.overrides[300]="Late wrong nested override";talk.fetches.clear();result=Header.prepare_prefix(receipt,talk,current)
	check(result.get("pending",false) and not talk.fetches.any(func(call):return call[0]==300),"Uncaptured nested named-token reference remains pending without consulting a later live override")
	message=packet(2);message.speakerName={"firstName":{"strRef":300,"gender":0},"lastName":{"text":""}};talk.overrides.erase(300);receipt=Header.capture(message,talk,current);talk.overrides[300]="Later wrong nested override";result=Header.prepare(receipt,talk,current)
	check(result.ready and result.name=="Captured nested base " and result.prefix=="Captured nested base","Captured direct remote reference also supplies the exact snapshot for a nested prefix reference")
	talk.overrides.erase(300)
	talk.overrides.erase(10300);talk.objects[42]=row();receipt=Header.capture(packet(1),talk,current);talk.objects[42].clientKnownLifetime=14;talk.objects[42].replicated.name.text="New ID owner";result=Header.prepare_name(receipt,talk,current)
	check(result.ready and result.name=="Door stored","Captured canonical bytes never retarget when the ID is subsequently reused")
	receipt=Header.capture(packet(1),talk,current);result=Header.prepare_name(receipt,talk,current)
	check(result.get("pending",false),"Mismatched current source lifetime is not snapshotted as the earlier speaker")
	check(talk.legacy==0,"No name, prefix or provider path uses legacy resolve")
	talk.close();var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"New detached header receipt only with actual native TalkText fetch/parser, controlled TLK/name/provider rows and explicit contexts; source-backed remote/fallback/provider/prefix order, whitespace, literal/override distinction, CUSTOM/context isolation and ID reuse. Canonical creature constructor/override provenance remains pending; no Gameplay integration, server/GPU/key/profile/build/process actions."}));file.close();quit(0 if failures.is_empty() else 1)
