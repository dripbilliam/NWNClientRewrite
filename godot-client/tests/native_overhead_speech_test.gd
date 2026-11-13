extends SceneTree
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Rules=preload("res://systems/native_data/overhead_speech_rules.gd")
const State=preload("res://systems/native_data/overhead_speech_state.gd")
const Owner=preload("res://systems/native_overhead_speech.gd")
const Bubble=preload("res://systems/native_overhead_bubble.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Resources=preload("res://systems/native_nameplate_resources.gd")
var checks:=0
var failures: Array=[]
var clicks:=0
var expiry: Array=[]
var current:={"connection":3,"generation":7,"areaId":91,"enabled":true}
var rows: Dictionary={}
var anchors: Dictionary={}
var preference:={"mode":1,"largeFont":false}
class TestView extends Control:
	var layout_ready:=true
	var model: Dictionary={}
	var witness: Array=[]
	var sets:=0
	func configure(_art,_fonts,_source) -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
	func set_content(value: Dictionary,_portrait: String,identity: Array) -> void:model=value;witness=identity;sets+=1
	func place(point: Vector2) -> void:position=point;show()
	func release() -> void:hide();model={};witness=[]
	func close() -> void:release()
class TestOwner extends Owner:
	func _make_view() -> Control:return TestView.new()
class TracingTalk extends Talk:
	var parses:=0
	func resolve(value: Variant,id: int,options: Dictionary={}) -> String:
		parses+=1;return super.resolve(value,id,options)
class RasterArt extends Node:
	var image: Texture2D
	func bind(target: Object,_name: String) -> void:target.texture=image
	func unbind(_target: Object) -> void:pass
	func portrait_resource(name: String) -> String:return name
class RegistryProbe extends Node:
	var registered: Array=[]
	var offered: Array=[]
	func register(id: int,_row: Dictionary) -> bool:registered.append(id);return true
	func offer(id: int,_row: Dictionary,_view: Control) -> void:offered.append(id)
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func packet(serial: int=1,id: int=42,type: Variant=5,body: String="Hello") -> Dictionary:
	return {"kind":"server-speech","channel":1,"objectId":id,"text":{"text":body},"nativeTextEvent":{"version":1,"serial":serial,"connection":3,"generation":7,"areaId":91,"source":{"id":id,"objectType":type,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func speaker(id: int=42,type: int=5) -> Dictionary:
	return {"id":id,"objectType":type,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Raw Name"},"portraitRef":"po_hu_m_01"}}
func context() -> Dictionary:return current
func row(id: int) -> Dictionary:return rows.get(id,{})
func settings() -> Dictionary:return preference
func anchor(id: int,witness: Array,scope: Array) -> Dictionary:
	if not rows.has(id):return {"ready":false}
	var value: Dictionary=rows[id]
	if witness!=[id,int(value.nativeLifetime),int(value.clientKnownLifetime)] or scope!=[3,7,91]:return {"ready":false,"retired":true}
	return anchors.get(id,{"ready":true,"point":Vector3(1,2,3),"screen":Vector2(-40,-50)})
func rule_checks() -> void:
	for channel in 32:
		check(Rules.compose(channel,5,"Hello","",0.0,1,false).get("eligible",false)==Rules.CHANNELS.has(channel),"Native receive-channel eligibility "+str(channel))
	check(Rules.compose(1,5,"","",0.0,1,false).eligible and not Rules.compose(11,5,"","",0.0,1,false).eligible,"Literal empty replaces; native empty localized path returns")
	var marked:="<c"+String.chr(1)+String.chr(254)+String.chr(1)+">Hello</c>\n"
	var model:=Rules.compose(1,9,marked,"Raw Name",0.0,2,false)
	check(model.text=="[Raw Name]: "+marked and model.byteLength==model.text.length() and model.minimumLines==2,"Raw prefix/markup/newline count native bytes before fitting")
	check(Rules.duration(1,1).seconds==4.0 and Rules.duration(1000,1).seconds==12.0,"Native automatic minimum and maximum duration")
	check(Rules.duration(60,11).seconds==6.75 and Rules.duration(60,1).seconds==9.0,"Channel11 native scale is three quarters")
	check(Rules.duration(10,11,0.15).seconds==4.0 and Rules.duration(10,11,0.2).seconds==Vector2(0.2,0).x and Rules.duration(10,11,40.0).seconds==40.0,"Strict forced-duration threshold bypasses automatic clamps")
	check(not Rules.c_string("Unrepresentable "+String.chr(0x4e00)).ready,"Unknown native byte encoding cannot fabricate a C-string length")
	check(Rules.c_string("€Œÿ").byteLength==3 and model.extraOutline==0 and model.extraShadow==Vector2.ZERO,"Western native byte mapping and no invented speech shadow")
	check(Rules.compose(1,5,"Large","",0.0,1,true).font=="ttf fnt_default_hr 16" and not Rules.compose(1,5,"Off","",0.0,0,false).registered,"Native large font and mode0 registration")
func state_checks() -> void:
	var current_scope:=Scope.context(3,7,91);var owner:=State.new();owner.begin(current_scope)
	var event:=Scope.event(packet(),current_scope);var model:=Rules.compose(1,5,"Hello","",0.0,1,false)
	owner.replace(event,model,{"text":"Cached owner caption"});owner.observe_source(42,speaker(),current_scope)
	check(owner.advance(4.0).is_empty() and owner.speakers[42].remaining==0.0,"Exactly zero keeps the original timer registered")
	var ended:=owner.advance(0.001)
	check(ended.size()==1 and ended[0].ownerCaption.text=="Cached owner caption" and owner.speakers.is_empty(),"Strict negative expires and restores cached owner text")
	owner.replace(Scope.event(packet(11,43),current_scope),model)
	check(owner.replace(Scope.event(packet(10,42),current_scope),model).ready,"Another speaker's later serial cannot erase a delayed earlier event")
	check(not owner.replace(Scope.event(packet(9,42),current_scope),model).ready,"Older same-speaker replacement cannot overwrite newer text")
	var replacement:=speaker();replacement.clientKnownLifetime=14
	check(owner.observe_source(42,replacement,current_scope).get("mismatch",false) and owner.speakers.has(42),"Unbound event may precede exact raw lifetime publication")
	owner.observe_source(42,speaker(),current_scope)
	check(owner.observe_source(42,replacement,current_scope).get("retired",false) and not owner.speakers.has(42),"Bound popup retires rather than retargeting redisclosed same ID")
	owner.replace(Scope.event(packet(12),current_scope),model);owner.observe_source(42,speaker(),current_scope)
	var removed:=speaker();removed.replicationRemoved=true
	check(owner.observe_source(42,removed,current_scope).get("ready",false),"Already-bound fading visual retains its timer despite Delete+104")
	check(not Scope.received_source(event,removed,current_scope).get("ready",false),"The same deletion blocks new speech")
	owner.observe_source(42,{},current_scope)
	check(not owner.speakers.has(42),"Actual current visual/raw removal retires its bound popup")
	owner.close()
func owner_checks(surface: Control,talk) -> void:
	rows={};anchors={};current={"connection":3,"generation":7,"areaId":91,"enabled":true}
	var owner:=TestOwner.new();root.add_child(owner);owner.configure_processing(false);owner.configure(surface,talk,null,null,null,context,row,anchor,settings)
	var registry:=RegistryProbe.new();root.add_child(registry);owner.popup_registry=registry
	owner.expired.connect(func(id,witness,caption):expiry.append([id,witness,caption]))
	var raw:=packet();var before:=raw.duplicate(true);owner.receive(raw)
	check(owner.state.speakers.has(42) and not owner.has_popup(42,{},Scope.context(3,7,91)),"Speech timer starts before exact source/model readiness without origin fallback")
	owner.views[42].layout_ready=false;owner.frame_advance(1.0)
	check(owner.state.speakers[42].remaining==3.0,"Font/model pending does not pause timer")
	rows[42]=speaker();owner.observe_sources([42]);owner.views[42].layout_ready=true;owner.frame_advance(0.0)
	check(owner.has_popup(42,rows[42]) and owner.views[42].position==Vector2(-40,-50),"Actual anchor is allowed outside viewport without clamp/camera cull")
	check(registry.registered==[42] and registry.offered.has(42),"Popup construction registers once and actual placed view joins shared native registry")
	var instance: int=owner.views[42].get_instance_id();owner.receive(packet(2,42,5,"Replacement"))
	check(owner.views.size()==1 and owner.views[42].get_instance_id()==instance and owner.state.speakers[42].model.text=="Replacement" and owner.state.speakers[42].remaining==4.0,"Same speaker replaces text/timer in the same pooled node")
	check(registry.registered==[42],"Same logical popup replacement never changes construction ordinal")
	owner.update_owner_caption(42,[42,8,13],{"text":"Owner name"});owner.frame_advance(4.0)
	check(owner.has_popup(42,rows[42]),"Strict zero remains visible in actual owner")
	owner.frame_advance(0.001)
	check(not owner.views.has(42) and owner.pool.size()==1 and expiry[-1][2].text=="Owner name","Expiry releases to pool and reports cached owner caption")
	owner.receive(packet(3,43,9,"Pending name"));owner.frame_advance(2.0);owner.receive(packet(4,44,5,"Other speaker"))
	rows[43]=speaker(43,9);owner.observe_sources([43])
	check(owner.state.speakers[43].model.text=="[Raw Name]: Pending name" and owner.state.speakers[43].remaining==2.0,"Earlier pending speaker publishes after later speaker with elapsed GUI time preserved")
	owner.receive(packet(5,45,null,"Old"));owner.receive(packet(6,45,null,"Newest"));rows[45]=speaker(45);owner.observe_sources([45])
	check(owner.state.speakers[45].model.text=="Newest" and not owner.pending.has(45),"Only latest same-speaker pending text survives")
	var old_life: Dictionary=rows[45].duplicate(true);rows[45].clientKnownLifetime=14;owner.observe_sources([45]);rows[45]=old_life;owner.observe_sources([45])
	check(not owner.state.speakers.has(45),"A bound popup cannot revive after lifetime mismatch even if the old row later returns")
	check(raw==before,"Raw text/metadata never mutated by owner publication")
	talk.objects[99]=speaker(99);talk.custom_tokens[12]="Native token"
	var localized:=packet(7,42,5,"<CUSTOM12>");localized.channel=11;localized.contextId=99;localized.nativeTextEvent.context={"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13};owner.receive(localized)
	check(owner.state.speakers[42].model.text=="Native token","Channel11 resolves native tokens under explicit message context with overhead flags")
	localized=packet(8,42,5,"<CUSTOM12>");owner.receive(localized)
	check(owner.state.speakers[42].model.text=="<CUSTOM12>","Ordinary literal speech is not passed through an invented token context")
	talk.overrides[700001]="Active literal override";localized=packet(9);localized.channel=8;localized.text={"strRef":700001};owner.receive(localized)
	check(owner.state.speakers[42].model.text=="Active literal override" and not owner.pending.has(42),"Literal active TLK override is independent of unavailable retained parser context")
	talk.overrides[700002]="<CUSTOM12>";localized=packet(10);localized.channel=8;localized.text={"strRef":700002};owner.receive(localized)
	check(not owner.pending.has(42) and owner.state.speakers[42].model.text=="Native token","Actor-independent CUSTOM override resolves with its receipt snapshot under unknown retained context")
	talk.named=[{"name":"CTXNAME","hash":Talk.token_hash("CTXNAME"),"action":3,"default":4294967295,"refs":[]}];talk.named_ready=true
	var old_context: Dictionary=talk.objects[99].duplicate(true)
	localized=packet(11,42,5,"<CTXNAME>");localized.channel=11;localized.contextId=99;localized.nativeTextEvent.context={"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13};talk.objects[99].clientKnownLifetime=14;owner.receive(localized)
	check(owner.pending.has(42) and not owner.pending[42].has("resolvedBody") and owner.state.speakers[42].model.text=="Native token","Wrong context known lifetime cannot provide a matched actor token to an existing popup")
	talk.objects[99]=old_context.duplicate(true);talk.objects[99].nativeLifetime=9;localized.nativeTextEvent.serial=12;owner.receive(localized)
	check(owner.pending.has(42) and not owner.pending[42].has("resolvedBody"),"Wrong context native lifetime cannot parse despite matching ID/disclosure number")
	localized.nativeTextEvent.serial=13;localized.nativeTextEvent.context=null;talk.objects[99]=old_context.duplicate(true);owner.receive(localized);talk.mark_changed();owner.frame_advance(0.0)
	check(owner.pending.has(42) and not owner.pending[42].has("resolvedBody"),"Absent explicit context witness never adopts a later same-ID row")
	talk.objects[99].replicated.name={"firstName":{"text":"Context Before"},"lastName":{"text":""}}
	localized=packet(14,46,9,"<CTXNAME>");localized.channel=11;localized.contextId=99;localized.nativeTextEvent.context={"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13};owner.receive(localized)
	check(owner.pending[46].resolvedBody.body=="Context Before","Different-speaker token context resolves immediately while speaker prefix is pending")
	talk.objects[99].clientKnownLifetime=15;talk.objects[99].replicated.name.firstName.text="Context Reused";rows[46]=speaker(46,9);owner.observe_sources([46])
	check(owner.state.speakers[46].model.text=="[Raw Name]: Context Before","Cached resolved body cannot retarget when context ID is redisclosed before speaker publication")
	talk.objects[99]=old_context.duplicate(true);localized=packet(15,47,5);localized.channel=11;localized.contextId=99;localized.text={"strRef":700003,"gender":0};localized.nativeTextEvent.context={"id":99,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13};owner.receive(localized)
	talk.overrides[700003]="<CTXNAME>";talk.objects[99].clientKnownLifetime=16;talk.mark_changed();owner.frame_advance(0.0)
	check(owner.pending.has(47) and not owner.pending[47].has("resolvedBody") and not owner.state.speakers.has(47),"Delayed custom text cannot first resolve against a recycled token context")
	owner.reset();current={"connection":3,"generation":-1,"areaId":-1,"enabled":false};owner.receive(packet(7));owner.frame_advance(1.5)
	check(owner.before_scope.size()==1 and owner.state.speakers.is_empty(),"Pre-firstsnapshot message waits only under explicit accepted connection")
	current={"connection":3,"generation":7,"areaId":91,"enabled":true};owner.frame_advance(0.5)
	check(owner.state.speakers[42].remaining==2.0 and owner.before_scope.is_empty(),"First authoritative scope preserves elapsed time and consumes each delta once")
	owner.reset();current={"connection":3,"generation":-1,"areaId":-1};owner.receive(packet(8));current.connection=4;current.generation=7;current.areaId=91;owner.frame_advance(0.0)
	check(owner.state.speakers.is_empty() and owner.pending.is_empty(),"Old pre-snapshot speech cannot attach to a new accepted connection")
	owner.reset();current={"connection":3,"generation":7,"areaId":91,"enabled":true};owner.receive(packet(9));owner.configure_processing(true)
	check(owner.process_priority==100 and owner.is_processing(),"Live owner runs late after default camera controllers only while needed")
	owner.reset();check(not owner.is_processing(),"Zero active/pending speech disables per-frame work")
	preference.mode=0;rows[48]=speaker(48);owner.receive(packet(20,48))
	check(registry.registered[-1]==48 and not owner.views.has(48) and not owner.state.speakers[48].registered and not owner.is_processing(),"Mode0 constructs its logical registry slot without a view, active timer or idle processing")
	preference.mode=1
	owner.close();owner.queue_free();registry.queue_free()
func real_view_checks(surface: Control,install: String,report: String) -> void:
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Actual installed read-only native resource catalog")
	var fonts:=Fonts.new();root.add_child(fonts);fonts.configure(catalog,report.get_base_dir().path_join("font-cache"))
	var resources:=Resources.new();root.add_child(resources);resources.configure(catalog,report.get_base_dir().path_join("popup-cache"))
	var art:=RasterArt.new();root.add_child(art);art.image=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	var bubble:=Bubble.new();surface.add_child(bubble);bubble.configure(art,fonts,resources)
	var model:=Rules.compose(1,5,"Native wrapped speech. Native wrapped speech.\nNext line.","",0.0,1,false);bubble.set_content(model,"",[42,8,13])
	var deadline:=Time.get_ticks_msec()+20000
	while not bubble.layout_ready and fonts.failed.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(bubble.layout_ready and bubble.caption.get_meta("native_font_applied","")=="ttf fnt_default 14","Actual Default dialog TTF decoded and bound")
	bubble.place(Vector2(-10,-20));check(bubble.visible and bubble.position.x==-9-bubble.size.x*0.5 and bubble.position.y==-20-bubble.size.y,"Center-bottom footprint rounds native GUI-up before reflecting to screen-down, without viewport clamp")
	bubble.place(Vector2(10.5,20.5));check(bubble.position==Vector2(11-bubble.size.x*0.5,20-bubble.size.y),"Native half-pixel Y tie is resolved before GUI-up reflection")
	check(not bubble.backdrop.visible and not bubble.portrait_frame.visible and bubble.caption.get_theme_constant("outline_size")==0 and bubble.caption.get_theme_constant("shadow_offset_x")==0,"Mode1 native text-only has no invented background/outline/shadow")
	check(bubble.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE and bubble.focus_mode==Control.FOCUS_NONE,"Native bubble is passive to pointer and keyboard focus")
	var layouts: int=bubble.layouts
	for index in 30:bubble.place(Vector2(index,index))
	check(bubble.layouts==layouts,"Position-only updates do not rerun wrapping or font/resource binds")
	model=Rules.compose(1,5,"Full native popup","",0.0,2,false);bubble.set_content(model,"po_hu_m_01t",[42,8,13]);deadline=Time.get_ticks_msec()+20000
	while (bubble.backdrop.plan.is_empty() or bubble.portrait_frame.plan.is_empty()) and resources.failures.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(resources.failures.is_empty() and not bubble.backdrop.plan.is_empty() and not bubble.portrait_frame.plan.is_empty(),"Actual original popup and portrait GUI models prepare through shared native data workers")
	check(bubble.caption.position.x==23.0 and bubble.portrait_frame.visible and bubble.backdrop.visible,"Mode2 native portrait reserves exactly23 pixels")
	model=Rules.compose(1,5,"Large native font","",0.0,1,true);bubble.set_content(model,"",[42,8,13]);deadline=Time.get_ticks_msec()+20000
	while not bubble.layout_ready and fonts.failed.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(bubble.layout_ready and bubble.caption.get_meta("native_font_applied","")=="ttf fnt_default_hr 16","Actual Large dialog TTF decoded and rebound")
	bubble.release();fonts.loaded.emit("ttf fnt_default 14");resources.loaded.emit(bubble.bubble_resource)
	check(not bubble.visible and not bubble.wanted,"Stale font/model callbacks cannot revive released popup")
	bubble.close();check(fonts.bindings.is_empty() and not fonts.loaded.is_connected(bubble.font_loaded) and not resources.loaded.is_connected(bubble.source_loaded),"Close unbinds owned font target and disconnects resource callbacks")
	bubble.queue_free();resources.close();resources.queue_free();fonts.close();fonts.queue_free();art.queue_free();catalog=null
	await process_frame;await process_frame
func retained_plain_checks(surface: Control,fixture: Dictionary,install: String) -> void:
	var talk:=TracingTalk.new();check(talk.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Actual installed TLK for retained localized11 packets")
	var female_path:=install.path_join("lang/en/data/dialogf.tlk");var female_absent:=not FileAccess.file_exists(female_path)
	if not female_absent:talk.female.open_file(female_path)
	check(talk.publish_native_family(false,female_absent),"Actual installed pair publishes original loader alias only after known female-file absence")
	current=fixture.scope.duplicate();current.enabled=false
	var source: Dictionary=fixture.speaker;var id:=int(source.id);rows={id:source};anchors={};talk.objects=rows
	var unavailable_anchor: Callable=func(_id,_witness,_scope):return {"ready":false}
	var owner:=TestOwner.new();root.add_child(owner);owner.configure_processing(false);owner.configure(surface,talk,null,null,null,context,row,unavailable_anchor)
	var count:=0
	for frame in fixture.messages:
		if int(frame.message.channel)!=11:continue
		var message: Dictionary=frame.message.duplicate(true);count+=1;owner.reset()
		check(message.contextId==4294967295 and message.nativeTextEvent.context==null,"Retained channel11 actual Host has unavailable/invalid context "+str(count))
		var raw: String=talk.raw(message.text,0);var forced:=0.0
		if message.text.has("strRef"):forced=float(talk.fetch_reference(int(message.text.strRef),0).get("duration",0.0))
		owner.receive(message)
		check(owner.state.speakers.has(id) and owner.state.speakers[id].model.text==raw and owner.state.speakers[id].remaining==Rules.duration(raw.length(),11,forced).seconds,"Retained plain channel11 bypasses unused context with actual TLK duration "+str(count))
		owner.reset();message.nativeTextEvent.context={"id":-1,"objectType":null,"areaId":null,"nativeLifetime":0,"knownLifetime":0};owner.receive(message)
		check(owner.state.speakers.has(id) and owner.state.speakers[id].model.text==raw,"Invalid unrelated context metadata cannot hide token-free native prompt "+str(count))
	check(count==16 and talk.parses==0,"All16 retained localized11 prompts resolve without legacy rich-parser or context-provider lookup")
	owner.close();owner.queue_free();talk.close()
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var parts:=argument.trim_prefix("--").split("=",true,1)
		if parts.size()==2:args[parts[0]]=parts[1]
	if not args.has("report") or not args.has("install") or not args.has("fixture") or FileAccess.file_exists(args.report):quit(2);return
	rule_checks();state_checks()
	var surface:=Control.new();root.add_child(surface);surface.size=Vector2(800,600);var talk:=Talk.new();owner_checks(surface,talk);talk.close();await process_frame
	retained_plain_checks(surface,JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture))),str(args.install));await process_frame
	await real_view_checks(surface,str(args.install),str(args.report));surface.queue_free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native ordinary-speech rules, GUI-delta replacement/lifetime/pooling; all16 retained original channel11 packets through actual decoder/Host with context:null/invalid and installed TLK; actual installed dialog fonts and native popup GUI-model geometry with controlled rasters. No pixels, live server speech, world integration, overlap registry or context-sensitive TLK override acceptance.","gpu":false,"serverConnections":0}
	var output:=FileAccess.open(str(args.report),FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close();print("OVERHEAD_SPEECH ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
