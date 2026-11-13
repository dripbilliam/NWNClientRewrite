extends SceneTree
# Actual Gameplay TLK job-completion hooks and native text owners. Synthetic
# byte fixtures supply files; no server, user profile, catalog workers or GPU.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const FloatingReceipt=preload("res://systems/native_data/script_floating_text_receipt.gd")
class ManifestCatalog extends RefCounted:
	var manifest: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
static func tlk(value: String) -> PackedByteArray:
	var encoded:=value.to_ascii_buffer();var bytes:=PackedByteArray();bytes.resize(60+encoded.size())
	var magic:="TLK V3.0".to_ascii_buffer()
	for at in magic.size():bytes[at]=magic[at]
	bytes.encode_u32(8,0);bytes.encode_u32(12,1);bytes.encode_u32(16,60)
	bytes.encode_u32(20,5);bytes.encode_u32(48,0);bytes.encode_u32(52,encoded.size());bytes.encode_float(56,1.25)
	for at in encoded.size():bytes[60+at]=encoded[at]
	return bytes
func make_ui():
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);ui.catalog=ManifestCatalog.new()
	ui.custom_tlk_requested=true
	return ui
func ready(ui,job: int,body: String) -> void:ui.prepared(job,{"bytes":tlk(body),"error":""})
func drop(ui) -> void:ui.close();ui.queue_free()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var ui=make_ui();var missing:=report.get_base_dir().path_join("not-supplied-female.tlk")
	check(not FileAccess.file_exists(missing) and ui.native_female_absent(false,"female",missing),"Actual disk lookup certifies absent female path without reading a user profile")
	ui.catalog.manifest={"talk":{"base":{}}}
	check(ui.native_female_absent(true,"female",""),"Recorded primary with no female manifest entry is known absence")
	ui.catalog.manifest.talk.female={"sha256":"present-but-unreadable"}
	check(not ui.native_female_absent(true,"female",""),"A recorded female entry with no readable path is failure, not absence")
	ui.catalog.manifest={"talk":{}}
	check(not ui.native_female_absent(true,"custom_female",""),"Unknown recorded primary cannot certify alternate-family absence")
	drop(ui);await process_frame
	ui=make_ui();ui.custom_tlk_female_absent=false;ui.text.retire_native_family(true);ui.tlk_jobs={101:false,102:true}
	ready(ui,102,"Current female")
	check(ui.tlk_jobs.size()==1 and not ui.text.fetch_native_reference(0x01000000,1).found,"Female completion before primary does not publish a partial current family")
	ready(ui,101,"Current male")
	var selected: Dictionary=ui.text.fetch_native_reference(0x01000000,1)
	check(ui.tlk_jobs.is_empty() and selected.found and selected.text=="Current female" and selected.gender==1,"Both successful out-of-order jobs publish the actual current female owner")
	check(ui.text.fetch_native_reference(0x01000000,0).text=="Current male","Completed current primary owns male lookups")
	drop(ui);await process_frame
	ui=make_ui();ui.custom_tlk_female_absent=true;ui.text.retire_native_family(true);ui.tlk_jobs={201:false}
	var receipt:=FloatingReceipt.capture(93,0x01000000,42,true,"",ui.text)
	check(not receipt.has("rawSnapshot") and FloatingReceipt.prepare(receipt,ui.text).get("pending",false),"Script text cannot snapshot an uncompleted alternate-family load")
	ready(ui,201,"Shared primary")
	selected=ui.text.fetch_native_reference(0x01000000,1)
	check(selected.found and selected.gender==1 and selected.text=="Shared primary" and ui.text.native_families[1].female==ui.text.custom,"Actual job completion publishes the exact primary table alias and retains gender1")
	check(FloatingReceipt.prepare(receipt,ui.text).get("ready",false) and receipt.body=="Shared primary","The unchanged pending Script93 receipt completes after actual family publication")
	drop(ui);await process_frame
	ui=make_ui();ui.custom_tlk_female_absent=false;ui.text.retire_native_family(true);ui.tlk_jobs={301:false,302:true}
	ready(ui,301,"Valid primary")
	ui.prepared(302,{"bytes":PackedByteArray([1,2,3]),"error":""})
	check(not ui.stats.errors.is_empty() and not ui.text.fetch_native_reference(0x01000000,0).found,"Malformed present female data keeps the entire native pair unavailable")
	check(ui.text.fetch_reference(0x01000000,0).text=="Valid primary","Native publication failure preserves legacy table ownership")
	drop(ui);await process_frame
	# Explicit family retirement must also fence bytes from a prior successful
	# load when one new job fails. The legacy resources intentionally survive.
	for failed_female in [false,true]:
		ui=make_ui();ui.custom_tlk_female_absent=false
		check(ui.text.custom.open_bytes(tlk("Previous primary")) and ui.text.custom_female.open_bytes(tlk("Previous female")) and ui.text.publish_native_family(true,false),"Prior native pair is fully loaded before a new explicit retirement")
		ui.text.retire_native_family(true);ui.tlk_jobs={401:false,402:true}
		ready(ui,401 if failed_female else 402,"New valid counterpart")
		check(not ui.text.fetch_native_reference(0x01000000,1).found,"Retired warm family stays unavailable while one replacement job is pending")
		ui.prepared(402 if failed_female else 401,{"bytes":PackedByteArray(),"error":"Owned fixture current-load read failed"})
		check(ui.tlk_jobs.is_empty() and not ui.text.fetch_native_reference(0x01000000,0).found and not ui.text.fetch_native_reference(0x01000000,1).found,"Failed current job cannot republish a prior loaded table as a new native family")
		check(ui.text.fetch_reference(0x01000000,1 if failed_female else 0).text==("Previous female" if failed_female else "Previous primary"),"Failed native replacement does not destroy the surviving legacy table")
		drop(ui);await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay native TLK family publication hooks with controlled valid/malformed/file-error bytes, manifest absence distinctions, concurrent job order, shared table aliases, pending Script93 and retired warm-family isolation. No configure workers, world/server/profile/GPU/native builds."}));file.close();print("NATIVE_TLK_FAMILY_PUBLICATION ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
