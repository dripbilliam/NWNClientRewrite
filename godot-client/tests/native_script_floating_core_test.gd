extends SceneTree
const Owner=preload("res://systems/native_script_floating.gd")
const Markup=preload("res://systems/native_data/script_floating_markup.gd")
const Frame=preload("res://systems/native_data/script_floating_frame.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Resources=preload("res://systems/native_script_floating_resources.gd")
const View=preload("res://systems/native_script_floating_view.gd")
var checks:=0
var failures: Array=[]
var closing_cases: Array=[]
var current:={"connection":3,"generation":7,"areaId":91,"enabled":true}
var rows: Dictionary={}
var logs: Array=[]
var heights: Array=[]
class EmptyCatalog extends RefCounted:
	func fork():return self
class PassiveView extends Control:
	var layout_ready:=true
	var model: Dictionary={}
	var frames: Array=[]
	var colours:=0
	func configure(_art,_fonts,_resources) -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE;hide()
	func set_content(value: Dictionary) -> void:model=value;frames=[]
	func apply_frame(point: Vector2,alpha: float) -> void:position=point;frames.append({"point":point,"alpha":alpha});show()
	func prepare_colors() -> void:colours+=1
	func release() -> void:model={};hide()
	func close() -> void:release()
class ControlledOwner extends Owner:
	func _make_view() -> Control:return PassiveView.new()
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func context() -> Dictionary:return current
func source(id: int) -> Dictionary:return rows.get(id,{})
func anchor(id: int,witness: Array,scope: Array,height: float) -> Dictionary:
	heights.append(height)
	if not rows.has(id) or witness!=[id,int(rows[id].nativeLifetime),int(rows[id].clientKnownLifetime)] or scope!=[3,7,91]:return {"ready":false}
	return {"ready":true,"point":Vector3(3,5+height,-4),"screen":Vector2(12.5,99.5),"viewportHeight":100.0}
func creature() -> Dictionary:return {"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"position":[3,4,5],"name":{"firstName":{"text":"Wrong speaker context"}}}}
func packet(serial: int,type: int=94,raw: String="Line",show: int=1) -> Dictionary:
	return {"kind":"combat-feedback","type":type,"color":"","data":{"objects":{"0":42},"integers":{"0":show} if type==94 else {"0":7000,"1":show},"strings":{"0":{"text":raw}} if type==94 else {}},"nativeTextEvent":{"version":1,"serial":serial,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
func markup_checks() -> void:
	var tag:="<c"+String.chr(255)+String.chr(1)+String.chr(1)+">";var ring:=Markup.Ring.new();var program:=Markup.compile("base"+tag+"tag</c>tail")
	var colors:=Markup.colors(program,ring,Color(1,1,1,0.2))
	check(program.plain=="basetagtail" and colors[0].a==Color(1,1,1,0.2).a and colors[2].a==1.0 and colors[4].a==Color(1,1,1,0.2).a,"Native opening RGB tag resets alpha1 and closing restores fading base RGBA")
	check(ring.index==0,"Balanced source tags preserve global ring index")
	colors=Markup.colors(Markup.compile("</c>unmatched"),Markup.Ring.new(),Color(1,1,1,0.2));check(colors[1]==Color.WHITE,"Unmatched close restores initialized slot15 without balanced-stack clamp")
	var overflow:=Markup.Ring.new();var original:=Color(0.2,0.3,0.4,0.5)
	for index in 17:overflow.push(Color(float(index)/32.0,0,0,1))
	check(overflow.index==1 and overflow.pop().r==0.5 and overflow.index==0,"Native16-slot overwrite and wrapping close order")
	check(not Markup.requires_named_tokens("plain <CUSTOM12> << <c"+String.chr(1)+String.chr(1)+String.chr(1)+">x</c>") and Markup.requires_named_tokens("<FirstName>"),"Only named-provider tokens wait for StringTokens metadata")
func closing_markup_checks() -> void:
	# Original ProcessTextMarkup4c470 tests '/' and 'c' after caller '<',
	# restores the ring, and returns4 without checking the fourth byte.
	var open:="<c"+String.chr(255)+String.chr(1)+String.chr(1)+">"
	var base:=Color(0.2,0.3,0.4,0.25)
	var cases: Array=[
		{"name":"standard close","raw":open+"tag</c>tail","plain":"tagtail","ops":["open","text","close","text"],"last":base,"index":0},
		{"name":"different fourth byte","raw":open+"tag</cXtail","plain":"tagtail","ops":["open","text","close","text"],"last":base,"index":0},
		{"name":"newline fourth byte consumed","raw":"</c\nAfter","plain":"After","ops":["close","text"],"last":Color.WHITE,"index":15},
		{"name":"less-than fourth byte consumed","raw":"</c<After","plain":"After","ops":["close","text"],"last":Color.WHITE,"index":15},
		{"name":"short close at terminator","raw":open+"tag</c","plain":"tag","ops":["open","text","close"],"last":Color(1,1.0/255.0,1.0/255.0,1),"index":0},
		{"name":"case-sensitive close","raw":"</C>tail","plain":"</C>tail","ops":["text"],"last":base,"index":0},
		{"name":"different third byte","raw":"</x>tail","plain":"</x>tail","ops":["text"],"last":base,"index":0},
		{"name":"truncated before c","raw":"</","plain":"</","ops":["text"],"last":base,"index":0},
		{"name":"caller less-than required","raw":"/c>tail","plain":"/c>tail","ops":["text"],"last":base,"index":0}
	]
	for item in cases:
		var ring:=Markup.Ring.new();var program:=Markup.compile(item.raw);var colors:=Markup.colors(program,ring,base)
		var ops: Array=program.commands.map(func(command):return command.op)
		var last: Color=colors.values()[-1] if not colors.is_empty() else base
		check(program.ready and program.plain==item.plain and ops==item.ops and ring.index==item.index and last.is_equal_approx(item.last),"Original three-byte close: "+item.name)
		var input_bytes: Array=[]
		for byte_at in item.raw.length():input_bytes.append(item.raw.unicode_at(byte_at))
		closing_cases.append({"name":item.name,"inputNativeBytes":input_bytes,"expectedPlain":item.plain,"actualPlain":program.plain,"expectedOps":item.ops,"actualOps":ops,"expectedRingIndex":item.index,"actualRingIndex":ring.index})
func owner_checks(surface: Control,talk) -> void:
	rows={42:creature()};logs=[];heights=[];current={"connection":3,"generation":7,"areaId":91,"enabled":true}
	var owner:=ControlledOwner.new();root.add_child(owner);owner.configure_processing(false);owner.configure(surface,talk,null,null,EmptyCatalog.new(),context,source,anchor);owner.log_message.connect(func(row):logs.append(row))
	var raw:=packet(1,94,"<CUSTOM12>");var before:=raw.duplicate(true);owner.receive(raw);owner.receive(packet(2,94,"Second",0))
	check(owner.entries.size()==2 and owner.active_entries.is_empty() and owner.views.is_empty(),"Each event queues its own widget; receipt does not activate GUI timer")
	check(logs.size()==1 and logs[0].text=="<CUSTOM12>" and logs[0].flags==128 and logs[0].chat_mask==128,"Literal94 is not TLK-parsed and echoes once independently of activation")
	owner.frame_advance(0.1,0)
	check(owner.entries[1].status=="active" and owner.entries[2].status=="queued" and owner.queues.values()[0].cooldown==400,"Native ownerframe activates/popFIRST and starts400ms cooldown")
	check(is_equal_approx(owner.entries[1].remaining,1.4) and owner.entries[2].remaining==1.5 and owner.views[1].frames[0].point==Vector2(13,99),"New activation ticks in same GUI frame; pending timer does not run; projection rounds GUI-up once")
	owner.frame_advance(0.2,400);check(owner.entries[2].status=="queued" and owner.queues.values()[0].cooldown==0,"Crossing cooldown tozero only subtracts; no activation in that frame")
	owner.frame_advance(0,0);check(owner.entries[2].status=="active" and owner.views.size()==2,"Next ownerframe activates independent second widget without replacing first")
	check(raw==before and owner.entries[1].model.raw=="<CUSTOM12>","Detached input/body snapshots preserve original packet")
	owner.reset();owner.receive(packet(3));owner.frame_advance(0,0);owner.frame_advance(1.1,1100);owner.frame_advance(0.1,100)
	var view=owner.views[3];var last_point: Vector2=view.position;var last_alpha: float=view.frames[-1].alpha;var painted: int=view.frames.size();rows.erase(42);owner.observe_sources([42]);owner.frame_advance(0.05,50)
	check(owner.entries.has(3) and view.position==last_point and view.frames.size()==painted and view.frames[-1].alpha==last_alpha,"Transient missing owner leaves last paint/color and only decrements timer")
	rows[42]=creature();owner.receive(packet(4,94,"Pending after old"));owner.observe_sources([], [42])
	check(owner.entries.has(3) and owner.entries[3].orphan and not owner.entries.has(4),"Explicit object removal clears pending FIFO but leaves activated orphan lifetime")
	var reused:=creature();reused.clientKnownLifetime=14;rows[42]=reused;owner.observe_sources([42]);owner.frame_advance(0.01,10)
	check(view.frames.size()==painted,"Orphan cannot adopt reused ID/current lifetime")
	var remaining: float=owner.entries[3].remaining;owner.frame_advance(remaining,0);check(not owner.entries.has(3) and owner.views.is_empty() and not owner.pool.is_empty(),"Atdelta>=remaining active widget is destroyed before final paint and view pools")
	owner.reset();rows[42]=creature();rows[42].clientKnownLifetime=12;owner.configure_processing(true);owner.receive(packet(5))
	check(not owner.is_processing() and owner.entries[5].status=="queued","Unbound older raw publication is dormant instead of polling or binding wrong lifetime")
	rows[42]=creature();owner.observe_sources([42]);check(owner.is_processing(),"Exact later raw witness wakes dormant source queue via publication")
	owner.configure_processing(false);owner.frame_advance(0,0);check(owner.entries[5].status=="active","New Host witness can activate once older Godot row catches up")
	owner.reset();logs=[];talk.custom_tokens={12:"Before"};talk.overrides[7000]="<FirstName> <CUSTOM12> <CUSTOM13>";talk.overrides[7100]="Native default"
	owner.receive(packet(6,93));check(not owner.entries[6].bodyReady and logs.is_empty(),"Named93 never caches UNRECOGNIZED before actual StringTokens import")
	talk.custom_tokens[12]="After";talk.custom_tokens[13]="Added later";talk.overrides[7000]="Future override"
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","R0","R1","R2","R3"],"orderedRows":[{"TOKEN":"FirstName","ACTION":"3","DEFAULT":"7100","R0":"-1","R1":"-1","R2":"-1","R3":"-1"}]});talk.import_tokens();owner.data_changed()
	check(owner.entries[6].bodyReady and owner.entries[6].body=="Native default Before <UNRECOGNIZED TOKEN>","NULL context/gender0 and receipt raw/custom-token snapshot reject future override and future-added token")
	check(talk.custom_tokens[12]=="After" and logs.size()==1,"Native formatting leaves live token provider unmodified and echoes exactly once")
	owner.data_changed();check(logs.size()==1,"Repeated metadata publication cannot duplicate echo")
	owner.reset();var invalid:=packet(7);invalid.erase("nativeTextEvent");owner.receive(invalid);check(owner.entries.is_empty() and owner.views.is_empty(),"Absent transport witness cannot create widget or local event")
	invalid=packet(8);invalid.nativeTextEvent.version=2;owner.receive(invalid);check(owner.entries.is_empty(),"Malformed explicit metadata never creates display state")
	var no_target:=packet(9);no_target.nativeTextEvent.source=null;owner.receive(no_target);check(owner.entries.is_empty() and logs.size()==2,"Unanchored valid event preserves echo independently of widget target")
	owner.reset();rows[42]=creature();talk.overrides.erase(7000);owner.receive(packet(11,93,"",0));owner.frame_advance(0.1,0)
	check(owner.entries[11].status=="active" and owner.entries[11].has("lastPaint") and not owner.views.has(11),"Active unresolved body retains successful exact-witness paint without allocating a fake view")
	var cached: Dictionary=owner.entries[11].lastPaint.duplicate(true);var waited_remaining: float=owner.entries[11].remaining
	owner.observe_sources([], [42]);rows.erase(42);talk.overrides[7000]="Late native body";talk.mark_changed();owner.data_changed()
	check(owner.entries[11].orphan and owner.views.has(11) and owner.views[11].position==cached.point and owner.views[11].frames[0].alpha==cached.alpha and owner.entries[11].remaining==waited_remaining,"Late TLK body uses retained pose/alpha after explicit source loss without restarting timer")
	owner.frame_advance(0.1,100);check(owner.views[11].frames.size()==1,"Orphan late view never queries/rebinds a future pose")
	owner.reset();rows[42]=creature();owner.receive(packet(10));owner.frame_advance(0,0);current.connection=4;owner.frame_advance(0,0);check(owner.entries.is_empty() and owner.queues.is_empty() and owner.views.is_empty(),"Connection/scope retirement clears pending and active UI")
	owner.close();owner.queue_free()
func real_view_checks(surface: Control,install: String,report: String) -> void:
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Read-only actual native catalog")
	var fonts:=Fonts.new();root.add_child(fonts);fonts.configure(catalog,report.get_base_dir().path_join("font-cache"))
	var resources:=Resources.new();root.add_child(resources);resources.configure(catalog,report.get_base_dir().path_join("model-cache"))
	check(not resources.assets.is_processing(),"Unrequested private model assets have no idle callback")
	var view:=View.new();surface.add_child(view);view.configure(null,fonts,resources)
	var raw:="base <c"+String.chr(255)+String.chr(1)+String.chr(1)+">tag</c> tail\nSecond line";view.set_content({"raw":raw,"program":Markup.compile(raw)})
	view.apply_frame(Vector2(-3,99),0.2);check(view.has_frame and not view.layout_ready and not view.visible,"Successful native paint is retained while font/model delivery is pending")
	var deadline:=Time.get_ticks_msec()+20000
	while not view.layout_ready and resources.plan.get("pending",false) and Time.get_ticks_msec()<deadline:await process_frame
	while not view.layout_ready and fonts.failed.is_empty() and not resources.plan.has("reason") and Time.get_ticks_msec()<deadline:await process_frame
	check(view.layout_ready and view.font_target.get_meta("native_font_applied","")=="ttf fnt_maintext 17","Actual source-remapped TTF MainText17 and pnl_floatytext dummy hooks load")
	check(view.visible and view.position==Vector2(-3,99) and is_equal_approx(view.base_alpha,0.2),"Late font/model layout becomes visible from retained paint without another anchor call")
	check(resources.plan.get("ready",false) and resources.plan.hooks.foreground.offset==Vector2.ZERO and is_equal_approx(resources.plan.hooks.background.offset.x,-1.0) and is_equal_approx(resources.plan.hooks.background.offset.y,-1.0),"Actual native model supplies Foreground0/Background(-1,-1) with no panel rectangle")
	view.apply_frame(Vector2(-3,99),0.2);view.prepare_colors();var alpha: Array=[]
	for value in view.run_colors.values():alpha.append(value.a)
	check(alpha.any(func(value):return is_equal_approx(value,0.2)) and alpha.has(1.0) and view.modulate.a==1.0,"Cached shaped runs fade base alpha while native RGB-tagged runs remain opaque")
	var count: int=view.layouts;var identities: Array=view.shaped.map(func(run):return run.shape.get_instance_id())
	for index in 20:view.apply_frame(Vector2(index,index),float(index)/20.0);view.prepare_colors()
	check(view.layouts==count and view.shaped.map(func(run):return run.shape.get_instance_id())==identities,"Position/fade/color-ring replay never reshapes text or reloads font/model")
	check(view.mouse_filter==Control.MOUSE_FILTER_IGNORE and view.focus_mode==Control.FOCUS_NONE and not view.is_processing(),"Passive view has no input/focus or per-view callback")
	check(not resources.assets.is_processing(),"Finished original model preparation disables private asset callback")
	view.release();fonts.loaded.emit("ttf fnt_maintext 17");resources.loaded.emit();check(not view.visible and not view.wanted and not view.has_frame,"Released pooled view clears retained paint and cannot revive from stale font/resource callbacks")
	view.close();check(fonts.bindings.is_empty(),"Font target unbinds on view close")
	view.queue_free();resources.close();resources.queue_free();fonts.close();fonts.queue_free();catalog=null;await process_frame;await process_frame
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	markup_checks();closing_markup_checks();var surface:=Control.new();root.add_child(surface);var talk:=Talk.new();owner_checks(surface,talk);talk.close();await process_frame
	await real_view_checks(surface,str(args.install),str(args.report));surface.queue_free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"closingCases":closing_cases,"closingSource":{"report":"reports/native-script-floating-original-v1.json","key":"script-float-string-0x14004c470","evidenceId":"ev_9accef9e66771c259f5166283ea7bc73a9542146075ce63f5fc5b906b6c0419c"},"scope":"Native script93/94 FIFO400/split clocks/active GUI lifetime/scope/echo/token snapshots plus actual native MainText17 font and pnl_floatytext source hooks with cached shaped runs; original three-byte closing matcher and fourth-byte/truncated cases. No pixels, native clock-selector branches, cross-other-UI unbalanced markup history, live server or full shared Gameplay integration.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("SCRIPT_FLOATING_CORE ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
