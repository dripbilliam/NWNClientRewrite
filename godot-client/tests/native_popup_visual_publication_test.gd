extends "res://native_live_world.gd"
# Suppress launcher/network startup; exercise the actual NativeLiveWorld
# publication method, identity stamp and real Gameplay/Owner/Registry wake.
const PopupOwner=preload("res://systems/native_overhead_speech.gd")
const PopupRegistry=preload("res://systems/native_overhead_popup_registry.gd")
class PublicationWorld extends Node3D:
	var area_id:=91
	var closed:=false
	var retiring:=false
	var desired: Dictionary={}
	var instances: Dictionary={}
class SelectionProbe extends RefCounted:
	var registrations:=0
	func register_native(_id: int,_row: Dictionary,_instance)->bool:registrations+=1;return false
var checks:=0
var failures: Array=[]
var diagnostic: Array=[]
var visual_connection:=3
func _initialize() -> void:run_proof.call_deferred()
func native_text_connection() -> Variant:return visual_connection
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func actor()->Dictionary:return {"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13,"replicated":{"name":{"text":"Controlled source"},"portraitRef":""}}
func run_proof()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(800,600);epoch=7
	world=PublicationWorld.new();root.add_child(world);registry=SelectionProbe.new()
	camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,8,8);camera.look_at(Vector3.ZERO)
	gameplay_ui=GameplayUi.new();root.add_child(gameplay_ui);gameplay_ui.set_process(false);gameplay_ui.generation=7;gameplay_ui.area_id=91;gameplay_ui.controlled_id=42
	gameplay_ui.native_connection_query=func():return 3
	gameplay_ui.overhead_anchor_query=native_text_anchor;gameplay_ui.popup_preferences={"mode":0,"largeFont":false}
	var source:=actor();gameplay_ui.text.objects={42:source};world.desired={42:{"object":source}}
	var overlay:=Control.new();gameplay_ui.add_child(overlay)
	var popup_registry:=PopupRegistry.new();gameplay_ui.add_child(popup_registry);popup_registry.automatic=false
	popup_registry.configure(gameplay_ui.overhead_context,gameplay_ui.overhead_source,gameplay_ui.popup_settings,gameplay_ui.popup_name_caption,gameplay_ui.popup_restoration)
	gameplay_ui.overhead_popup_registry=popup_registry
	var popup_owner:=PopupOwner.new();gameplay_ui.add_child(popup_owner)
	popup_owner.configure(overlay,gameplay_ui.text,null,null,null,gameplay_ui.overhead_context,gameplay_ui.overhead_source,gameplay_ui.overhead_anchor,gameplay_ui.popup_settings)
	popup_owner.bind_popup_registry(popup_registry);gameplay_ui.overhead=popup_owner
	var packet:={"kind":"server-speech","channel":1,"objectId":42,"text":{"text":"Wait"},"nativeTextEvent":{"version":1,"serial":1,"connection":3,"generation":7,"areaId":91,"source":{"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"knownLifetime":13}}}
	popup_owner.receive(packet)
	var record: Dictionary=popup_registry.slots[42].caption
	diagnostic.append({"at":"received-off","mode":record.mode,"gui":record.guiRegistered,"timed":record.timedFlag,"settings":popup_owner.settings(),"registrySettings":popup_registry.preference.duplicate()})
	check(record.mode==0 and record.timedFlag==1 and not record.guiRegistered,"Fresh Off speech retains a logical candidate without an active GUI clock")
	gameplay_ui.popup_preferences_changed({"ui.text-bubble-mode":1,"ui.large-font":false})
	popup_owner.frame_advance(0.0)
	diagnostic.append({"at":"enabled-wait","mode":record.mode,"gui":record.guiRegistered,"timed":record.timedFlag,"awaiting":popup_owner.awaiting_visual.size(),"processing":popup_owner.is_processing(),"remaining":record.remaining})
	check(popup_owner.awaiting_visual.has(42) and not popup_owner.is_processing() and not record.guiRegistered,"Enabled candidate waits dormantly for actual visual publication")
	await process_frame;await process_frame
	check(popup_owner.awaiting_visual.has(42) and record.remaining==4.0,"No raw update or idle polling advances an inactive waiting candidate")
	var instance:=Node3D.new();world.add_child(instance);instance.set_meta("native_nameplate_height",1.8);world.instances[42]=instance
	var wrong:=source.duplicate(true);wrong.clientKnownLifetime=14
	_profile_instance_ready(42,wrong,instance)
	check(not record.guiRegistered and popup_owner.awaiting_visual.has(42),"Actual publication rejects a visual with a different disclosed lifetime")
	epoch=8;_profile_instance_ready(42,source,instance);epoch=7
	check(not record.guiRegistered and popup_owner.awaiting_visual.has(42),"Actual publication cannot wake an earlier area generation")
	visual_connection=4;_profile_instance_ready(42,source,instance);visual_connection=3
	check(not record.guiRegistered and popup_owner.awaiting_visual.has(42),"Visual publication cannot adopt its connection as Gameplay's accepted connection")
	var revision: int=gameplay_ui.text.revision
	_profile_instance_ready(42,source,instance)
	check(instance.get_meta("native_speech_identity",[])==[42,8,13] and instance.get_meta("native_speech_scope",[])==[3,7,91],"Actual Root identity stamp precedes the popup wake")
	check(record.sceneActive and record.guiRegistered and not popup_owner.awaiting_visual.has(42),"Late model publication wakes the exact dormant popup through real Gameplay and Owner")
	check(gameplay_ui.text.revision==revision and gameplay_ui.queue.is_empty(),"Wake requires no new raw entity/header/chat update or queue entry")
	check(registry.registrations==4,"Existing selection-registration boundary remains active after each visual publication")
	popup_registry.advance_clocks(4.0)
	check(record.remaining==0.0 and record.guiRegistered,"Activated GUI clock keeps exact-zero behavior")
	popup_registry.advance_clocks(0.001)
	check(not record.guiRegistered and record.timedFlag==0 and popup_owner.state.speakers.is_empty(),"A later GUI delta expires the previously dormant speech and releases hover priority")
	_profile_instance_ready(42,source,instance)
	check(not record.guiRegistered and popup_owner.state.speakers.is_empty(),"Later repeated publication cannot resurrect expired speech")
	gameplay_ui.close();_profile_instance_ready(42,source,instance)
	check(popup_owner.closed and not popup_owner.is_processing(),"Closed Gameplay rejects a late visual wake")
	gameplay_ui.queue_free();world.queue_free();camera.queue_free();await process_frame;await process_frame
	gameplay_ui=null;world=null;camera=null;registry=null;render_pool.clear();catalog=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"scope":"Actual NativeLiveWorld publication/identity stamp to real Gameplay/Owner/Registry; controlled model node/camera, current scope and exact lifetime fences, no raw-update wake, one GUI clock and expiry. Startup suppressed: no server, real model preparation, popup pixels, GPU, native rebuild or user-process action."}));file.close();print("NATIVE_POPUP_VISUAL_PUBLICATION ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
