extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3d.gd"
# Identical startup/owner observation for BOTH actual roles; fixture run untouched.
var observer_startup:=""
var observer_ready:=""
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
  elif arg.begins_with("--case="):mode=arg.trim_prefix("--case=")
  elif arg.begins_with("--role="):role=arg.trim_prefix("--role=")
  elif arg.begins_with("--candidate-script="):candidate_script=arg.trim_prefix("--candidate-script=")
  elif arg.begins_with("--observer-startup="):observer_startup=arg.trim_prefix("--observer-startup=")
  elif arg.begins_with("--observer-ready="):observer_ready=arg.trim_prefix("--observer-ready=")
 call_deferred("wait_for_observer")
func wait_for_observer()->void:
 if observer_startup.is_empty() or observer_ready.is_empty():push_error("Isolated observer paths missing");quit(2);return
 var capability: Dictionary={}
 if ClassDB.class_exists("NwnStaticPrefixCursor"):
  var cursor: RefCounted=ClassDB.instantiate("NwnStaticPrefixCursor");capability=cursor.call("dispatch",0,{})
 var startup:={"pid":OS.get_process_id(),"case":mode,"role":role,"executable":OS.get_executable_path(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"display":DisplayServer.get_name(),"main_thread":OS.get_thread_caller_id()==OS.get_main_thread_id(),"capability":capability,"loaded_extensions":Array(GDExtensionManager.get_loaded_extensions()),"user_args":Array(OS.get_cmdline_user_args())}
 var file:=FileAccess.open(observer_startup,FileAccess.WRITE);file.store_string(JSON.stringify(startup));file.close()
 var deadline:=Time.get_ticks_msec()+15000
 while not FileAccess.file_exists(observer_ready):
  if Time.get_ticks_msec()>deadline:push_error("Isolated actual-module observer timed out");quit(2);return
  await process_frame
 var ready_file:=FileAccess.open(observer_ready,FileAccess.READ);var ready: Variant=JSON.parse_string(ready_file.get_as_text());ready_file.close()
 if not ready is Dictionary or ready.get("pid")!=OS.get_process_id() or ready.get("engine_sha256")!=startup.engine_sha256:push_error("Isolated observer process scope mismatch");quit(2);return
 await run()
func build_owner()->Node:
 var owner: Node=super.build_owner()
 var script=owner.get_script()
 var proof:={"pid":OS.get_process_id(),"case":mode,"role":role,"owner_script":script.resource_path if script!=null else "","owner_native_class":owner.get_class()}
 var file:=FileAccess.open(output+".owner.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
 return owner
