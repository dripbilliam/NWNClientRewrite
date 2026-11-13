extends Node
# Read-only actual ordinary Owner/visual/Bubble/registry observation. The only
# stimulus is real native Chat.submit; no pose/model/clock/frame is authored.
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
const FIRST="NATIVE_SPEECH_FIRST"
const REPLACEMENT="NATIVE_SPEECH_REPLACEMENT"
const EXPECTED_MODE=2
const EXPECTED_LARGE=true
const EXPECTED_FONT="ttf fnt_default_hr 16"
var client
var ui
var speech_owner
var popup_registry
var visual
var scope: Dictionary={}
var source: Dictionary={}
var bindings: Dictionary={}
var visual_info: Dictionary={}
var first: Dictionary={}
var replacement: Dictionary={}
var expiry: Array=[]
var checks:=0
var failures: Array=[]
var phase:="first"
var last_reason:="waiting-receipt"
var before_replacement:=-1.0
var fresh_preferences: Dictionary={}
func check(ok: bool,label: String)->bool:
	checks+=1
	if not ok:failures.append(label)
	return ok
func current()->bool:
	if not is_instance_valid(client) or client.closing or client.session_connection!=scope.connection or client.epoch!=scope.generation or not is_instance_valid(client.world) or client.world.area_id!=scope.areaId:return false
	var row: Dictionary=ui.text.objects.get(int(source.id),{})
	return row.get("nativeLifetime") == source.nativeLifetime and row.get("clientKnownLifetime")==source.knownLifetime and not row.get("replicationRemoved",false) and client.world.instances.get(int(source.id))==visual
func anchor_bindings()->Dictionary:
	var a: Variant=speech_owner.anchor_reader;var b: Variant=ui.overhead_anchor_query
	return {"ownerToGameplay":a is Callable and a.is_valid() and a.get_object()==ui and str(a.get_method())=="overhead_anchor","gameplayToNativeRoot":b is Callable and b.is_valid() and b.get_object()==client and str(b.get_method())=="native_text_anchor","ownerMethod":str(a.get_method()) if a is Callable else "","rootMethod":str(b.get_method()) if b is Callable else "","worldInstance":client.world.get_instance_id(),"cameraInstance":client.camera.get_instance_id()}
func expired(id: int,witness: Array,caption: Dictionary)->void:
	if id==int(source.id) and expiry.size()<4:expiry.append({"frame":Engine.get_process_frames(),"phase":phase,"witness":witness.duplicate(),"cachedOwnerCaptionPresent":not caption.is_empty()})
func observe(marker: String)->Dictionary:
	var id:=int(source.id);var entry: Dictionary=speech_owner.state.speakers.get(id,{})
	if entry.is_empty() or str(entry.get("model",{}).get("text",""))!=marker:last_reason="waiting-receipt";return {}
	var view: Variant=speech_owner.views.get(id);var expected: Array=[id,int(source.nativeLifetime),int(source.knownLifetime)];var expected_scope: Array=[int(scope.connection),int(scope.generation),int(scope.areaId)]
	if entry.get("witness")!=expected or entry.get("scope")!=expected_scope or not entry.get("sourceBound",false):last_reason="scope-or-source-not-bound";return {}
	if not is_instance_valid(view) or not view is Control or str(view.get_script().resource_path)!="res://systems/native_overhead_bubble.gd":last_reason="waiting-real-bubble";return {}
	if not view.layout_ready or not view.is_visible_in_tree() or not view.position.is_finite() or view.witness!=expected:last_reason="waiting-visible-layout";return {}
	var caption: RichTextLabel=view.caption
	if not is_instance_valid(caption) or not caption.is_visible_in_tree() or not caption.has_meta("native_font_applied") or str(caption.get_meta("native_font_applied"))!=EXPECTED_FONT or view.font_resource!=EXPECTED_FONT or entry.model.font!=EXPECTED_FONT or int(entry.model.mode)!=EXPECTED_MODE or caption.get_parsed_text().replace("\n","")!=marker:last_reason="waiting-exact-caption-native-default-font";return {}
	var slot: Dictionary=popup_registry.slots.get(id,{});var offer: Dictionary=popup_registry.offers.get(id,{})
	if slot.get("witness")!=expected or offer.get("witness")!=expected or not offer.has("view") or offer.view.get_ref()!=view:last_reason="waiting-real-registry-offer";return {}
	var record: Variant=slot.get("caption")
	var clock:={"delegated":entry.get("delegated")==true,"sharedRecord":record is Dictionary and is_same(entry.get("popup"),record),"registryTracked":popup_registry.clocks.has(id),"registered":record.get("guiRegistered")==true if record is Dictionary else false}
	if not clock.delegated or not clock.sharedRecord or not clock.registryTracked or not clock.registered:last_reason="waiting-one-registry-caption-clock";return {}
	# Read-only projection of the current actual visual/camera. No callback is
	# replaced or injected. Registry may legitimately displace final position.
	var anchor: Dictionary=ui.overhead_anchor_query.call(id,expected,expected_scope)
	if not anchor.get("ready",false) or not anchor.get("point") is Vector3 or not anchor.get("screen") is Vector2:last_reason="waiting-actual-head-projection";return {}
	var mapped:=GuiProjection.screen_down(anchor.screen,view.get_viewport_rect().size.y)
	if not mapped.get("ready",false) or offer.get("position")!=mapped.screen-Vector2(view.size.x*0.5,view.size.y):last_reason="pre-overlap-head-position-mismatch";return {}
	if not ui.overhead_claims_nameplate(id,ui.text.objects[id]):last_reason="waiting-nameplate-claim";return {}
	# The registry record owns the clock. Owner.remaining is a compatibility
	# mirror sampled before the registry's later GUI tick, never live authority.
	var remaining:=float(record.remaining)
	if not is_finite(remaining) or remaining<=0:last_reason="timer-not-active";return {}
	last_reason="published"
	return {"serial":int(entry.serial),"revision":int(entry.revision),"viewInstance":view.get_instance_id(),"registryOrdinal":int(slot.ordinal),"seconds":float(entry.model.seconds),"mode":int(record.mode),"font":str(view.font_resource),"clock":clock,"captionUtf8":Array(caption.get_parsed_text().to_utf8_buffer()),"sample":{"frame":Engine.get_process_frames(),"remaining":remaining,"position":[view.position.x,view.position.y],"preOverlapPosition":[offer.position.x,offer.position.y],"rawHeadScreen":[anchor.screen.x,anchor.screen.y],"headPoint":[anchor.point.x,anchor.point.y,anchor.point.z],"viewportHeight":view.get_viewport_rect().size.y,"size":[view.size.x,view.size.y],"visibleInTree":view.is_visible_in_tree(),"captionVisibleInTree":caption.is_visible_in_tree(),"layoutReady":view.layout_ready,"fontApplied":str(caption.get_meta("native_font_applied")),"registryOfferFrame":int(offer.frame),"nameplateClaim":true,"clock":clock.duplicate(),"witness":expected,"scope":expected_scope}}
func collect(marker: String,result: Dictionary)->void:
	var next:=observe(marker)
	if next.is_empty():return
	if result.is_empty():result.merge(next);result.samples=[]
	if result.serial!=next.serial or result.viewInstance!=next.viewInstance:return
	var sample: Dictionary=next.sample;var samples: Array=result.samples
	if samples.size()<2 and (samples.is_empty() or sample.frame!=samples[-1].frame and sample.remaining<samples[-1].remaining):samples.append(sample)
	result.erase("sample")
static func diagnostic_scalars(value: Variant,keys: Array)->Dictionary:
	var result: Dictionary={}
	if not value is Dictionary:return result
	for key in keys:
		var item: Variant=value.get(key)
		if item==null or item is String or item is bool or item is int or item is float:result[key]=item
	return result
func actor_name_observation()->Dictionary:
	# Diagnostic only: no readiness/default/constructor inference or pass gate.
	if not is_instance_valid(ui) or not is_instance_valid(ui.text):return {"available":false}
	var id:=int(source.get("id",-1));var row: Dictionary=ui.text.objects.get(id,{})
	var metadata: Variant=row.get("nativeActorNameState")
	var summary:=diagnostic_scalars(metadata,["source","version","id","revision","presence"])
	if metadata is Dictionary:
		summary.construction=diagnostic_scalars(metadata.get("construction"),["kind","source","sequence"])
		summary.override=diagnostic_scalars(metadata.get("override"),["known"])
		var publication: Variant=metadata.get("publication")
		if publication is Dictionary:
			summary.publication=diagnostic_scalars(publication,["revision","current"])
			summary.publication.first=diagnostic_scalars(publication.get("first"),["kind","strRef","gender"])
			summary.publication.last=diagnostic_scalars(publication.get("last"),["kind","strRef","gender"])
		else:summary.publication=null
	var resolved: Dictionary={"available":false}
	if is_instance_valid(ui.actor_names) and ui.has_method("actor_name_context"):
		var actual: Dictionary=ui.actor_names.name(row,ui.actor_name_context())
		var encoded:=JSON.stringify(actual).to_utf8_buffer()
		resolved=actual.duplicate(true) if encoded.size()<=8192 else {"omitted":true,"utf8Bytes":encoded.size(),"reason":"Name diagnostic exceeds8KiB"}
	var observed_rows: Array=[];var total:=0;var scanned:=0
	if is_instance_valid(ui.chat) and ui.chat.rows is Array:
		total=ui.chat.rows.size()
		for index in range(maxi(0,total-512),total):
			scanned+=1;var actual: Variant=ui.chat.rows[index]
			if not actual is Dictionary or not actual.get("text") in [FIRST,REPLACEMENT]:continue
			var label: Variant=actual.get("name",{}).get("text") if actual.get("name") is Dictionary else null
			var observed:={"name":label if label is String else null,"nativeNameResolved":actual.get("nativeNameResolved") if actual.get("nativeNameResolved") is bool else null,"objectId":actual.get("objectId"),"body":actual.text}
			if label is String and label.to_utf8_buffer().size()>2048:observed.name=null;observed.nameOmitted=true;observed.nameUtf8Bytes=label.to_utf8_buffer().size()
			observed_rows.append(observed)
			if observed_rows.size()==2:break
	return {"available":true,"headerHistoryComplete":ui.actor_name_history_complete if ui.actor_name_history_complete is bool else null,"currentRow":diagnostic_scalars(row,["id","objectType","areaId","nativeLifetime","clientKnownLifetime","replicationRemoved"]),"metadata":summary,"resolved":resolved,"chatRows":observed_rows,"totalChatRows":total,"scannedChatRows":scanned}
func payload()->Dictionary:
	if is_instance_valid(speech_owner) and speech_owner.expired.is_connected(expired):speech_owner.expired.disconnect(expired)
	return {"version":2,"success":failures.is_empty(),"checks":checks,"failures":failures.duplicate(),"scope":scope.duplicate(),"source":source.duplicate(),"freshPopupPreferences":fresh_preferences.duplicate(true),"anchorBindings":bindings.duplicate(true),"visual":visual_info.duplicate(true),"first":first.duplicate(true),"replacement":replacement.duplicate(true),"preReplacementRemaining":before_replacement,"expiry":expiry.duplicate(true),"lastObservationState":last_reason,"actorNames":actor_name_observation(),"scopeDescription":"Actual ordinary native Chat/Owner/model-head/Bubble/font/registry with explicit fresh mode2/large font16 and one shared registry clock, same-popup replacement and natural GUI expiry. Headless projection/Canvas visibility only; no pixels/movement/OS focus/pointer. Claim API observed; no authored hover caption and no live HUD hover restoration claim. Actor-name diagnostics are bounded read-only observations, not extra success criteria."}
func run(value,accepted_scope: Dictionary,accepted_source: Dictionary)->Dictionary:
	client=value;ui=client.gameplay_ui;scope=accepted_scope.duplicate();source=accepted_source.duplicate();speech_owner=ui.overhead;popup_registry=ui.overhead_popup_registry;visual=client.world.instances.get(int(source.id))
	var stored: Dictionary=ui.popup_options.values if is_instance_valid(ui.popup_options) else {}
	fresh_preferences={"stored":{"mode":stored.get("ui.text-bubble-mode"),"largeFont":stored.get("ui.large-font")},"gameplay":ui.popup_settings(),"owner":speech_owner.settings(),"registry":popup_registry.preference.duplicate()}
	var expected_preferences:={"mode":EXPECTED_MODE,"largeFont":EXPECTED_LARGE}
	if not check(fresh_preferences.values().all(func(item):return item==expected_preferences),"Fresh persisted popup defaults are explicitly native mode2/largeFonttrue at stored, Gameplay, Owner and Registry boundaries"):return payload()
	var expected: Array=[int(source.id),int(source.nativeLifetime),int(source.knownLifetime)];var expected_scope: Array=[int(scope.connection),int(scope.generation),int(scope.areaId)]
	if not check(is_instance_valid(visual) and visual is Node3D and current(),"Actual current disclosed actor has its existing installed visual instance"):return payload()
	if not check(visual.get_meta("native_speech_identity",[])==expected and visual.get_meta("native_speech_scope",[])==expected_scope and visual.has_meta("native_nameplate_height") and is_finite(float(visual.get_meta("native_nameplate_height"))),"Actor visual carries exact received lifetime/scope stamps and installed native head height"):return payload()
	bindings=anchor_bindings()
	if not check(bindings.ownerToGameplay and bindings.gameplayToNativeRoot and str(speech_owner.get_script().resource_path)=="res://systems/native_overhead_speech.gd" and str(popup_registry.get_script().resource_path)=="res://systems/native_overhead_popup_registry.gd","Actual ordinary Owner binds Gameplay wrapper then current native model-head anchor and shared registry"):return payload()
	visual_info={"instance":visual.get_instance_id(),"script":str(visual.get_script().resource_path),"witness":expected,"scope":expected_scope,"nativeNameplateHeight":float(visual.get_meta("native_nameplate_height")),"models":visual.model_names.slice(0,32) if visual.get("model_names") is Array else [],"worldPosition":[visual.global_position.x,visual.global_position.y,visual.global_position.z]}
	speech_owner.expired.connect(expired)
	ui.chat.submit(FIRST)
	var deadline:=Time.get_ticks_msec()+20000
	while current() and Time.get_ticks_msec()<deadline:
		collect(FIRST,first)
		var entry: Dictionary=speech_owner.state.speakers.get(int(source.id),{})
		if first.get("samples",[]).size()==2 and entry.get("serial")==first.serial and float(entry.popup.remaining)<=float(entry.model.seconds)-0.5:
			before_replacement=float(entry.popup.remaining);break
		await client.process_frame
	if not check(current() and first.get("samples",[]).size()==2 and before_replacement>0,"First real Talk receipt has exact font/caption/head projection, registry/claim and two naturally timed visible samples"):return payload()
	if not check(first.mode==EXPECTED_MODE and first.font==EXPECTED_FONT and first.clock.values().all(func(item):return item==true),"Actual default popup uses full mode2/native large font16 and the sole shared Registry caption clock"):return payload()
	phase="replacement";ui.chat.submit(REPLACEMENT)
	while current() and Time.get_ticks_msec()<deadline:
		collect(REPLACEMENT,replacement)
		if replacement.get("samples",[]).size()==2:break
		await client.process_frame
	if not check(current() and replacement.get("samples",[]).size()==2,"Second real Talk receipt publishes replacement caption through real font/layout and current head anchor"):return payload()
	check(replacement.serial>first.serial and replacement.revision>first.revision and replacement.viewInstance==first.viewInstance and replacement.registryOrdinal==first.registryOrdinal,"New receipt replaces the same real popup and logical registry slot")
	check(first.seconds==4.0 and replacement.seconds==4.0 and replacement.samples[0].remaining>before_replacement and replacement.samples[1].remaining<replacement.samples[0].remaining,"Native byte-duration clamp and replacement timer reset advance only on real GUI frames")
	while current() and Time.get_ticks_msec()<deadline and speech_owner.state.speakers.has(int(source.id)):await client.process_frame
	check(current(),"Accepted connection/source/visual remain current throughout ordinary speech expiry")
	var id:=int(source.id);var slot: Dictionary=popup_registry.slots.get(id,{})
	check(not speech_owner.state.speakers.has(id) and not speech_owner.views.has(id) and not ui.overhead_claims_nameplate(id,ui.text.objects[id]),"Natural GUI expiry releases real popup and nameplate claim")
	var released: Variant=instance_from_id(int(first.viewInstance))
	check(is_instance_valid(released) and not released.is_visible_in_tree() and speech_owner.pool.has(released),"Expired real Bubble is hidden and returned to its existing private pool")
	check(expiry.any(func(row):return row.phase=="replacement" and row.witness==expected),"Actual ordinary Owner expiry signal retains the same lifetime witness")
	check(slot.get("witness")==expected and slot.get("ordinal")==first.registryOrdinal,"Expiry retains the original logical shared popup construction slot")
	check(anchor_bindings()==bindings,"Actual model-head anchor/current world/camera callable owners remain unchanged")
	return payload()
