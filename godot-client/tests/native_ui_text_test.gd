extends SceneTree
const Ui=preload("res://systems/native_gameplay_ui.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Tlk=preload("res://systems/native_data/talk_table.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30: failures.append(label)
func wait_until(predicate: Callable) -> bool:
	var start:=Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec()-start<15000: await process_frame
	return predicate.call()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var catalog:=Catalog.new(); check(catalog.mount_install(oracle.install),"Native UI catalog indexes installed originals")
	check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000000),"Native Prelude UI resource stack")
	var ui:=Ui.new(); root.add_child(ui); ui.configure(catalog,oracle.install,ProjectSettings.globalize_path("user://native-prepared-v2"))
	check(await wait_until(func(): return ui.tables_ready),"Original UI rule tables prepare on native workers")
	check(ui.stats.errors.is_empty(),"Native UI setup has no original resource errors: "+str(ui.stats.errors))
	var path:=str(oracle.install).path_join("lang/en/data/dialog.tlk")
	check(Cache.digest(FileAccess.get_file_as_bytes(path))==oracle.tlkSha256,"Original TLK fixture identity")
	for record in oracle.records:
		var value: Dictionary=ui.text.base.entry(int(record.ref))
		check(value.found and Cache.digest(str(value.text).to_utf8_buffer())==record.textSha256,"Native original TLK record text hash %d"%int(record.ref))
		check(int(value.get("stored_bytes",-1))==int(record.storedBytes),"Native original TLK stored length %d"%int(record.ref))
	var reads:=ui.text.base.reads; ui.text.base.entry(int(oracle.records[0].ref)); check(ui.text.base.reads==reads,"Requested original TLK entries reuse native cache")
	check(not ui.text.base.entry(-1).found and not ui.text.base.entry(ui.text.base.count).found,"Unavailable TLK references remain explicit")
	ui.text.objects={1:oracle.object}
	for token in oracle.customTokens: ui.text.custom_tokens[int(token.id)]=token.text
	for sample in oracle.cases:
		ui.text.objects[1].appearance.gender=int(sample.gender)
		var resolved:=ui.text.resolve({"text":sample.input},int(sample.context)); var actual:=Rich.parse(resolved)
		check(resolved==sample.resolved,"Native raw token replacement %s/%d/%d"%[sample.input,int(sample.context),int(sample.gender)])
		check(actual==sample.expected,"Native rich spans after token replacement "+str(sample.input))
	for sample in oracle.richCases: check(Rich.parse(sample.input)==sample.expected,"Fixed-width original RGB byte %d"%checks)
	var authored:=PackedByteArray(); authored.resize(63); authored.fill(0); authored.encode_u32(8,0); authored.encode_u32(12,1); authored.encode_u32(16,60)
	var header:="TLK V3.0".to_ascii_buffer()
	for index in header.size(): authored[index]=header[index]
	authored.encode_u32(20,1); authored.encode_u32(52,3); authored[60]=65; authored[61]=128; authored[62]=255
	var parser:=Tlk.new(); check(parser.open_bytes(authored) and parser.entry(0).text=="A€ÿ","Native Western TLK byte conversion is host independent")
	var bad_offset:=authored.duplicate(); bad_offset.encode_u32(16,0)
	var bad_count:=authored.duplicate(); bad_count.encode_u32(12,1000001)
	for bad in [authored.slice(0,19),bad_offset,bad_count]:
		check(not parser.open_bytes(bad),"Malformed TLK header/table is rejected")
	var invalid:=authored.duplicate(); invalid.encode_u32(48,0xffffffff)
	check(parser.open_bytes(invalid) and not parser.entry(0).found and not parser.failure.is_empty(),"Out-of-bounds native TLK text is rejected")
	parser.close()
	ui.set_world(7,42,1,[oracle.object]); var requests: Array=[]; ui.request.connect(func(message): requests.append(message.duplicate(true)))
	ui.receive({"kind":"server-speech","channel":1,"objectId":1,"text":{"text":"Native <CUSTOM18>"}},7)
	ui.receive({"kind":"dialog-entry","ownerId":1,"speakerId":1,"tokenObjectId":1,"text":{"text":"Choose <CUSTOM18>"}},7)
	ui.receive({"kind":"dialog-replies","entryId":77,"end":false,"tokenObjectId":1,"replies":[{"id":55,"text":{"text":"Reply"}}]},7)
	ui.receive({"kind":"examine","targetId":1,"type":"creature","hasDetails":true,"name":{"text":"Native creature"},"description":{"text":"A <CUSTOM18> description"},"damageLevel":0,"reaction":1,"portraitId":65534,"portrait":"po_clsbard_"},7)
	check(await wait_until(func(): return ui.queue.is_empty()),"Raw protocol speech/dialog/examine queue drains into Godot controls")
	check(ui.chat.rows.size()==1 and ui.chat.messages.get_parsed_text().contains("Native authored token"),"Raw speech renders native token text in chat")
	check(ui.conversation.visible and ui.conversation.body.get_parsed_text()=="Choose authored token" and ui.conversation.reply_ids==[55],"Raw conversation displays native text and server-owned reply IDs")
	ui.conversation.replies.get_child(0).pressed.emit()
	check(requests.size()==1 and requests[0].kind=="reply" and int(requests[0].entryId)==77 and int(requests[0].replyId)==55,"Native reply control sends original protocol identifiers")
	ui.chat.submit("authored outgoing text")
	check(requests.size()==2 and requests[1].kind=="chat" and requests[1].text=="authored outgoing text","Native chat control emits text without JS formatting")
	check(ui.examine.visible and ui.examine.body.get_child(2).get_parsed_text()=="A authored token description","Raw creature examine description is preserved by native controls")
	check(await wait_until(func(): return ui.portrait_jobs.is_empty()),"Original portrait decodes through native worker/cache path")
	check(ui.stats.portraits==1 and ui.examine.portrait.texture!=null and ui.pool.stats.textures_created==1,"Native original portrait resource binds directly without PNG/base64 transfer")
	check(not ui.examine.set_native_portrait(ui.examine.portrait.texture,1,-1),"Stale portrait revision cannot overwrite current examine view")
	ui.receive({"kind":"examine","targetId":1,"type":"creature","description":{"text":"Stale"}},6)
	check(await wait_until(func(): return ui.queue.is_empty()) and ui.stats.stale_messages==1,"Old generation UI message is discarded")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":123,"text":"replacement"}]},7)
	check(ui.text.raw({"strRef":123})=="replacement","Server TLK override is applied natively")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":123,"text":""}]},7)
	check(not ui.text.overrides.has(123),"Empty server override restores native table owner")
	var state:=ui.snapshot(); ui.close()
	check(ui.assets.running.is_empty() and ui.assets.pending.is_empty() and ui.queue.is_empty(),"Native UI worker and queued-message owners drain")
	ui.receive({"kind":"server-speech","channel":5,"text":{"text":"late"}},7); check(ui.queue.is_empty(),"Closed native UI ignores late protocol data")
	ui.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"original_tlk_records":oracle.records.size(),"token_cases":oracle.cases.size(),"rich_byte_cases":oracle.richCases.size(),"ui":state,"gpu_verified":false,"live_server_verified":false,"scope":"Headless native original TLK/rule reads, token/RGB parity and raw chat/dialog/creature examine controls. Fonts, portrait GPU readback, full token/item providers and public/live server acceptance pending."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
