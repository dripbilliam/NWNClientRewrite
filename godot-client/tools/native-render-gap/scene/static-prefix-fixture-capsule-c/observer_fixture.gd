extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v2b.gd"
# Private startup barrier only; the pinned full fixture run() remains inherited.
var observer_startup:=""
var observer_ready:=""
func _initialize()->void:call_deferred("wait_for_observer")
func wait_for_observer()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--observer-startup="):observer_startup=argument.substr(19)
  elif argument.begins_with("--observer-ready="):observer_ready=argument.substr(17)
 if observer_startup.is_empty() or observer_ready.is_empty():push_error("Observer paths absent");quit(2);return
 var capability: Dictionary={}
 if ClassDB.class_exists("NwnStaticPrefixCursor"):
  var cursor: RefCounted=ClassDB.instantiate("NwnStaticPrefixCursor");capability=cursor.call("dispatch",0,{})
 var value:={"pid":OS.get_process_id(),"executable":OS.get_executable_path(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"display":DisplayServer.get_name(),"main_thread":OS.get_thread_caller_id()==OS.get_main_thread_id(),"capability":capability,"loaded_extensions":Array(GDExtensionManager.get_loaded_extensions()),"user_args":Array(OS.get_cmdline_user_args())}
 var file:=FileAccess.open(observer_startup,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
 var deadline:=Time.get_ticks_msec()+15000
 while not FileAccess.file_exists(observer_ready):
  if Time.get_ticks_msec()>deadline:push_error("Actual module observer did not release startup barrier");quit(2);return
  await process_frame
 var ready_file:=FileAccess.open(observer_ready,FileAccess.READ);var ready: Variant=JSON.parse_string(ready_file.get_as_text());ready_file.close()
 if not ready is Dictionary or ready.get("pid")!=OS.get_process_id() or ready.get("engine_sha256")!=value.engine_sha256:push_error("Observer scope differs");quit(2);return
 await run()
