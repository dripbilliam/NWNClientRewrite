extends SceneTree
# Actual shared ingress/HUD methods; only passive drawing and canonical fixture
# publication are controlled. No catalog/worker/network/session is instantiated.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Hud=preload("res://systems/native_hud.gd")
const PlateState=preload("res://systems/native_data/nameplate_state.gd")
const SessionRoot=preload("res://native_session_world.gd")
const ModelTemplate=preload("res://systems/native_render/model_template.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const PopupRegistry=preload("res://systems/native_overhead_popup_registry.gd")
class ContextText extends "res://systems/native_data/talk_text.gd":
	var available_reference:=-1
	var context_reads: Array=[]
	func fetch_reference(ref: int,gender: int=0)->Dictionary:
		if ref==available_reference:return {"found":true,"text":"Authored <<FirstName> token provider","duration":0.0}
		return super.fetch_reference(ref,gender)
	func parse_native_bytes(raw_bytes: PackedByteArray,call_state: Dictionary={}) -> Dictionary:
		var input: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(call_state.get("language",base.language)),true).get("text","")
		# Provider boundary only: strict algorithm and append-only bytes have
		# their separate unchanged-original comparison. No ID-based lookup here.
		if input=="Authored <FirstName> token provider" and call_state.has("context"):
			var current: Dictionary=call_state.context;var object_id:=int(current.id);context_reads.append({"id":object_id,"knownLifetime":current.get("clientKnownLifetime"),"nativeBC":call_state.get("nativeBC"),"nativeB8":call_state.get("nativeB8")})
			return {"ready":true,"body":"Resolved context "+str(object_id)+" lifetime "+str(current.get("clientKnownLifetime"))}
		return super.parse_native_bytes(raw_bytes,call_state)
class EmptyPool extends RefCounted:
	var compact_static_parts:=false
class PassiveBubble extends Control:
	var layout_ready:=false
	var model: Dictionary={}
	var witness: Array=[]
	var placements:=0
	func configure(_art,_fonts,_source)->void:hide()
	func set_content(value: Dictionary,_portrait: String,identity: Array)->void:model=value.duplicate(true);witness=identity.duplicate();layout_ready=true
	func place(point: Vector2)->void:position=point;placements+=1;show()
	func release()->void:layout_ready=false;model={};witness=[];hide()
	func close()->void:release()
class ReceivedOwner extends "res://systems/native_overhead_speech.gd":
	var ingested: Array=[]
	func receive(message: Dictionary,receipt: Dictionary={})->Dictionary:
		ingested.append(message.duplicate(true));return super.receive(message,receipt)
	func _make_view()->Control:return PassiveBubble.new()
class SharedPopupSource extends Node:
	signal loaded(name: String)
	var closed:=false
	func close()->void:closed=true
class Desktop extends Node:
	var state: Dictionary={"players":[]}
	func close()->void:pass
class Registry extends RefCounted:
	var entities: Dictionary={}
	func nameplate_position(_id: int,_camera: Vector3)->Vector3:return Vector3.ZERO
class PassivePlate extends Control:
	var data: Dictionary={"available":true,"caption":{"text":"Authored received caption","spans":[],"nativeRawBytes":"Authored received caption".to_ascii_buffer()}}
	var placements:=0
	var presentation_active:=true
	var presentation_mode:=1
	func set_popup_preferences(mode: int,_font: String)->void:presentation_mode=mode
	func apply_popup_state(record: Dictionary,_mode: bool,_font: bool)->void:
		presentation_mode=int(record.mode);presentation_active=record.sceneActive and not record.hidden
	func place(_screen: Vector2,_viewport: Rect2,_native_projection: bool=false)->void:placements+=1;visible=presentation_active and presentation_mode!=0
	func set_content(value: Dictionary)->void:data=value.duplicate(true)
	func close()->void:hide()
var connection: Variant=null
var visual_ready:=false
var checks:=0
var failures: Array=[]
var expired: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:="";var fixture_path:="";var install:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--fixture="):fixture_path=argument.trim_prefix("--fixture=")
		if argument.begins_with("--install="):install=argument.trim_prefix("--install=")
	if output.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(SessionRoot!=null,"Actual current NativeSessionWorld/root graph parses without instantiation")
	var template:=ModelTemplate.new();var template_input:={"resource_name":"plc_speech_fixture","value":{"name":"embedded-name-is-not-the-resource","nodes":[]}}
	check(template.build(template_input,EmptyPool.new()) and template.source_model_name=="plc_speech_fixture","Actual mesh-free ModelTemplate retains installed native_model_name scalar")
	var placement=template.prepare_instance()
	check(is_instance_valid(placement) and placement.get_meta("native_model_name","")=="plc_speech_fixture","Actual template Placement propagates model resource identity for authored head_hit lookup")
	if is_instance_valid(placement):placement.free()
	check(fixture.messages.size()==75 and fixture.provenance.originalPackets==75,"Exactly75 retained original packets crossed actual decoder and Host metadata dispatch")
	root.size=Vector2i(800,600)
	var overlay:=Control.new();root.add_child(overlay)
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false)
	check(not install.is_empty() and ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Actual read-only installed TLK owner supplies original plain localized speech, without authored provider")
	var female_path:=install.path_join("lang/en/data/dialogf.tlk");var female_absent:=not FileAccess.file_exists(female_path)
	if not female_absent:ui.text.female.open_file(female_path)
	check(ui.text.publish_native_family(false,female_absent),"Actual installed loader pair preserves native shared-file alias and gender")
	ui.desktop=Desktop.new();ui.add_child(ui.desktop)
	ui.overhead_popup_source=SharedPopupSource.new();ui.add_child(ui.overhead_popup_source)
	var owner:=ReceivedOwner.new();ui.add_child(owner);ui.overhead=owner
	ui.native_connection_query=func():return connection
	ui.overhead_anchor_query=func(_id,_witness,_scope):return {"ready":visual_ready,"screen":Vector2(400,300)}
	owner.configure(overlay,ui.text,null,null,ui.overhead_popup_source,ui.overhead_context,ui.overhead_source,ui.overhead_anchor)
	owner.configure_processing(false);owner.expired.connect(func(id,witness,caption):expired.append({"id":id,"witness":witness.duplicate(),"caption":caption.duplicate(true)}))
	ui.overhead_popup_registry=PopupRegistry.new();ui.add_child(ui.overhead_popup_registry);ui.overhead_popup_registry.automatic=false;ui.overhead_popup_registry.configure(ui.overhead_context,ui.overhead_source,owner.settings);owner.bind_popup_registry(ui.overhead_popup_registry)
	ui.table_jobs[101]="unrelated-class-table";ui.tlk_jobs[102]=false
	var source: Dictionary=fixture.speaker.duplicate(true);var id:=int(source.id)
	# Canonical received caption fields are authored solely for the HUD boundary.
	source.replicated={"name":{"text":"Authored received caption"},"portraitRef":""}
	var raw_packet: Dictionary={}
	for frame in fixture.messages:
		var message: Dictionary=frame.message
		if int(message.channel)==1 and message.text.has("text") and not str(message.text.text).is_empty() and message.nativeTextEvent.source!=null:raw_packet=message;break
	check(not raw_packet.is_empty(),"An actual original raw-talk packet is available for deferred lifecycle checks")
	if raw_packet.is_empty():ui.close();ui.queue_free();overlay.queue_free();quit(3);return
	var original:=raw_packet.duplicate(true)
	ui.receive(raw_packet,2)
	check(owner.ingested.size()==1 and ui.queue.size()==1,"Actual Gameplay.receive dispatches overhead before unrelated table/TLK queue readiness")
	check(owner.state.speakers.is_empty(),"No event can adopt its own connection as current owner context")
	connection=3;ui.receive(raw_packet,2)
	check(owner.state.speakers.is_empty(),"Accepted connection alone retains deferred input without adopting an unknown generation/area")
	ui.generation=2;ui.area_id=7;ui.controlled_id=id;ui.text.objects[id]=source
	owner.observe_sources()
	check(owner.state.speakers.has(id),"Explicit current connection and raw speaker publication release pre-scope deferred input")
	check(ui.overhead_claims_nameplate(id,source) and not owner.has_popup(id,source),"Native timed-speech marker blocks hover even before a ready visual can publish the speech view")
	visual_ready=true;owner.observe_sources()
	check(ui.overhead_claims_nameplate(id,source),"Exact source lifetimes plus ready visual anchor claim current ordinary popup")
	check(ui.overhead_popup_registry.slots.has(id),"Actual Speech owner registers its exact popup lifetime in the shared logical registry")
	check(raw_packet==original,"Early dispatch and delayed resolution leave original payload/metadata unchanged")
	var hud:=Hud.new();root.add_child(hud);hud.registry=Registry.new();hud.registry.entities[id]={"eligible":true,"type":5}
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,10);hud.camera=camera
	hud.nameplate_root=Control.new();root.add_child(hud.nameplate_root);hud.bind_gameplay(ui)
	check(hud.nameplate_source==ui.overhead_popup_source and not hud.nameplate_source_owned,"Actual HUD borrows the current popup resource owner without taking its lifetime")
	var plate:=PassivePlate.new();hud.nameplate_root.add_child(plate);hud.nameplates[id]=plate
	hud.nameplate_signatures[id]=PlateState.signature(source,id,ui.text.revision)
	hud.nameplate_values[id]=plate.data.duplicate(true)
	hud.labels([id])
	check(plate.placements==0 and not plate.visible,"Actual HUD.labels suppresses its current caption while exact overhead popup is active")
	var cached: Dictionary=owner.state.speakers[id].ownerCaption.duplicate(true);plate.data.caption.text="Changed after publication"
	check(owner.state.speakers[id].ownerCaption==cached,"HUD cached-caption witness is detached from later nameplate mutations")
	owner.frame_advance(13.0);ui.overhead_popup_registry.advance_clocks(13.0);hud.labels([id])
	check(plate.placements==1 and plate.visible,"Actual HUD caption returns when ordinary GUI timer expires")
	check(ui.overhead_popup_registry.offers.has(id) and ui.overhead_popup_registry.offers[id].view.get_ref()==plate,"Actual HUD offers restored nameplate into the same exact popup slot")
	check(expired.size()==1 and expired[0].caption==cached,"Expiry emits only the detached caption from the matching speaker witness")
	owner.reset();owner.ingested.clear();ui.queue.clear()
	for frame in fixture.messages:ui.receive(frame.message,int(frame.generation))
	check(owner.ingested.size()==75 and ui.queue.size()==75,"All75 complete original Host messages reach early overhead and unchanged normal log queue")
	for index in fixture.messages.size():
		check(owner.ingested[index]==fixture.messages[index].message and ui.queue[index].message==fixture.messages[index].message,"Actual ingress preserves original packet and detachedmetadata "+str(index))
	var plain_count:=0
	for frame in fixture.messages:
		var received_message: Dictionary=frame.message
		if int(received_message.channel)!=11:continue
		check(received_message.nativeTextEvent.has("context") and received_message.nativeTextEvent.context==null and fixture.context==null,"Actual retained11 packet carries explicit unavailable canonical context")
		var plain: String=ui.text.raw(received_message.text)
		if plain.is_empty() or plain.contains("<"):continue
		owner.reset();ui.receive(received_message,2);plain_count+=1
		check(owner.state.speakers.has(id) and owner.state.speakers[id].model.text==plain,"Actual literal/TLK11 text resolves without any parser context or authored provider")
	check(plain_count==16,"All16 retained plain channel11 packets reach actual speech owner with absent context")
	var token_text:=ContextText.new();ui.text.close();ui.text=token_text;ui.text.objects[id]=source;owner.text=token_text
	var localized: Dictionary={}
	for frame in fixture.tokenContextFixture.messages:
		if int(frame.message.channel)==11 and frame.message.text.has("strRef") and frame.message.nativeTextEvent.get("context")!=null:localized=frame.message;break
	check(not localized.is_empty(),"Actual channel11 Host packet has a separately witnessed non-speaker token context")
	if not localized.is_empty():
		owner.reset();var context: Dictionary=fixture.tokenContextFixture.context.duplicate(true);var context_id:=int(context.id);ui.text.objects[context_id]=context
		check(context_id!=id and int(localized.nativeTextEvent.context.knownLifetime)==int(context.clientKnownLifetime),"Context identity uses the actual independent Host/snapshot owner pairing")
		ui.receive(localized,2);check(not owner.state.speakers.has(id),"Unavailable TLK keeps original localized event pending")
		var changed:=context.duplicate(true);changed.clientKnownLifetime=int(context.clientKnownLifetime)+1;ui.text.objects[context_id]=changed
		token_text.available_reference=int(localized.text.strRef);token_text.overrides[token_text.available_reference]="Authored <<FirstName> token provider";ui.text.mark_changed();owner.frame_advance(0.0)
		check(token_text.context_reads.size()==1 and token_text.context_reads[0].knownLifetime==int(context.clientKnownLifetime),"Late TLK publication uses the receipt's captured old context rather than a recycled disclosure")
		owner.reset();ui.text.objects[context_id]=context;ui.text.objects.erase(id);ui.receive(localized,2)
		check(token_text.context_reads.size()==2 and int(token_text.context_reads[-1].id)==context_id and token_text.context_reads[-1].nativeBC==1 and token_text.context_reads[-1].nativeB8==0,"Actual early ingress binds the independent current token provider with original BC1/B8zero flags")
		var resolved: String=owner.state.speakers[id].model.text
		ui.text.objects[context_id]=changed;ui.text.objects[id]=source;ui.text.mark_changed();owner.observe_sources([id]);owner.frame_advance(0.0)
		check(token_text.context_reads.size()==2 and owner.state.speakers[id].model.text==resolved,"Resolved body remains a detached cached string when context changes before speaker publication")
	owner.reset();ui.receive(raw_packet,2);owner.observe_sources()
	check(owner.state.speakers.has(id),"Current raw speech can reopen after private popup reset")
	var reused:=source.duplicate(true);reused.clientKnownLifetime=int(source.clientKnownLifetime)+1;ui.text.objects[id]=reused;owner.observe_sources([id])
	check(not owner.state.speakers.has(id) and not ui.overhead_claims_nameplate(id,reused),"Retained ID/native proxy with new disclosure cannot steal pending or active speech")
	ui.text.objects[id]=source;owner.reset();ui.receive(raw_packet,2);owner.observe_sources();connection=4;owner.frame_advance(0.0)
	check(owner.state.speakers.is_empty() and not ui.overhead_claims_nameplate(id,source),"Accepted connection callback change retires old popup before same-ID redisclosure")
	var before:=owner.state.speakers.size();ui.receive(raw_packet,2)
	check(owner.state.speakers.size()==before,"Old received packet cannot reopen a popup under the next connection")
	hud.clear_nameplates();hud.release_nameplate_source();hud.queue_free();camera.queue_free();hud.nameplate_root.queue_free()
	ui.close();ui.queue_free();overlay.queue_free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalPackets":75,"contextReads":token_text.context_reads,"scope":"Current actual SessionWorld graph compile and Gameplay early receive/connection callback/actual Owner lifetime+GUI timers/HUD suppression with controlled passive drawing.75 retained original sender packets through actual decoder/Host. No native pixels, live server, world admission, GPU, key or user-process action."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
