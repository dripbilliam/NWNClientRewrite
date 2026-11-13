extends "res://native_session_world.gd"
# This is the actual entry SceneTree. Do not create a second tree or call run().
var reset_checks:=0
var reset_failures: Array=[]
const DEFAULT_CAPTION="Native renderer · choose a server or character"

func _initialize() -> void:
	call_deferred("test_reset")

func reset_check(value: bool,description: String) -> void:
	reset_checks+=1
	if not value:reset_failures.append(description)

func test_reset() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	label=Label.new();root.add_child(label)
	reset_check(native_clock_runtime==null and not authenticated and peer.get_status()==StreamPeerTCP.STATUS_NONE and ticket.is_empty() and args.is_empty(),"Startup is suppressed: no native clock, protocol connection, ticket or base run")
	var prior_catalog: RefCounted=catalog
	label.text="Partial world"
	raw_world={"serial":18,"generation":7,"count":3,"data":{"objects":[{"id":42}]}}
	accepted_raw_serial=17;raw_serial=18;epoch=7;initialized=true;catalog_loading=true
	pending_combat=[{"kind":"authored-pending"}];pending_visual=[{}];pending_voice=[{}];pending_script_sounds=[{}];pending_creator={"connection":8}
	reset_session()
	reset_check(raw_world.is_empty(),"Actual reset clears an incomplete raw-world assembler")
	reset_check(accepted_raw_serial==-1,"Actual reset invalidates the accepted raw delta base")
	reset_check(raw_serial==18,"Reset preserves the Host's globally increasing raw serial")
	reset_check(epoch==-1 and not initialized and not catalog_loading,"Existing epoch/catalog readiness resets remain active")
	reset_check(label.text==DEFAULT_CAPTION,"Reset restores the default connection caption")
	reset_check(pending_combat.is_empty() and pending_visual.is_empty() and pending_voice.is_empty() and pending_script_sounds.is_empty() and pending_creator.is_empty(),"Existing pending presentation and creator queues clear")
	reset_check(catalog!=null and catalog!=prior_catalog and native_clock_runtime==null,"Reset replaces only the inert catalog and does not start native clocks")
	reset_session()
	reset_check(raw_world.is_empty() and accepted_raw_serial==-1 and raw_serial==18 and label.text==DEFAULT_CAPTION,"Repeated reset remains idempotent for raw ownership and caption")

	var pending: Dictionary={"serial":19,"generation":9,"count":2,"data":{"objects":[{"id":88}]}}
	raw_world=pending.duplicate(true);accepted_raw_serial=18
	reset_check(native_pointer_blocked(Vector2(-3.25,2.75)) and raw_world==pending and accepted_raw_serial==18 and raw_serial==18,"No-world pointer guard returns true without mutating raw state")
	var pointer_world:=Node3D.new();root.add_child(pointer_world);world=pointer_world
	var pointer_blocked: bool=native_pointer_blocked(Vector2(-3.25,2.75))
	reset_check(not pointer_blocked and raw_world==pending and accepted_raw_serial==18 and raw_serial==18,"Actual empty-world pointer policy returns false and leaves raw state unchanged")
	world=null;pointer_world.free()

	session_connection=8;cancelled_connection=-1
	var stale_before: int=int(report.get("stale_session_messages",0))
	receive({"kind":"raw-world-begin","connection":7,"serial":99,"generation":9,"count":0,"data":{"bridgeMode":"delta","bridgeBaseSerial":18}})
	reset_check(int(report.get("stale_session_messages",0))==stale_before+1 and raw_world==pending and accepted_raw_serial==18 and raw_serial==18 and not closing,"Retired-connection delta rejects before assembler/base interpretation")
	cancelled_connection=8
	var cancelled_before: int=int(report.get("cancelled_session_messages",0))
	receive({"kind":"raw-world-begin","connection":8,"serial":99,"generation":9,"count":0,"data":{"bridgeMode":"delta","bridgeBaseSerial":18}})
	reset_check(int(report.get("cancelled_session_messages",0))==cancelled_before+1 and raw_world==pending and raw_serial==18 and not closing,"Cancelled current connection cannot mutate the partial assembler")
	cancelled_connection=-1;reset_session()
	receive({"kind":"raw-world-begin","connection":8,"serial":19,"generation":1,"count":1,"data":{"bridgeMode":"full"}})
	receive({"kind":"raw-world-chunk","connection":8,"serial":19,"generation":1,"objects":[{"id":42}]})
	reset_check(raw_serial==19 and accepted_raw_serial==-1 and raw_world.get("data",{}).get("objects",[])==[{"id":42}] and not closing,"A higher-serial full frame can begin after reset without reusing an accepted delta base")
	reset_session()
	reset_check(raw_world.is_empty() and accepted_raw_serial==-1 and raw_serial==19 and label.text==DEFAULT_CAPTION and native_clock_runtime==null and peer.get_status()==StreamPeerTCP.STATUS_NONE,"Final reset releases the new partial frame and leaves all startup paths inert")
	prior_catalog=null;catalog=null;render_pool.clear();label.queue_free();label=null
	await process_frame
	var result: Dictionary={"success":reset_failures.is_empty(),"checks":reset_checks,"failures":reset_failures,"globalRawSerial":raw_serial,"staleRejected":int(report.get("stale_session_messages",0)),"cancelledRejected":int(report.get("cancelled_session_messages",0)),"scope":"Actual SessionWorld SceneTree with startup suppressed; label/inert catalog only. Reset partial assembler/base/caption, preserve global raw serial, pointer read-only and retired/cancelled raw admission. Authored protocol dictionaries; no peer/resources/native-clock startup, profile, socket/server, GPU, native rebuild or original-server acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_SESSION_RESET ",reset_checks," checks, ",reset_failures.size()," failures")
	quit(0 if reset_failures.is_empty() else 1)
