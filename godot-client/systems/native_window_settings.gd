extends Node
# Native, read-only mode discovery and this game's own canvas/window settings.
# Applying UI scale uses canvas-items scaling; never the lower-resolution
# viewport stretch path. No JS, monitor mode changes or pointer activation.
signal changed
const Policy=preload("res://systems/native_data/video_options_layout.gd")
var window: Window
var preference_path:="user://native-options.cfg"
var fixed_scale:=1.0
var applied_scale:=1.0
var maximum_scale:=1.0
var written_scale:=1.0
var unconstrained:=false
var screens: Array=[]
var error:=""
var worker: Thread
var closed:=false
var query_ready:=false
var applies:=0
var resize_pending:=false
var resize_updates:=0
var query_sources: Dictionary={}
var query_binary:=""
func configure(owner: Window,path: String="user://native-options.cfg") -> void:
	window=owner; preference_path=path
	var saved:=ConfigFile.new(); saved.load(path)
	var value: Variant=saved.get_value("interface","ui_scale",1.0)
	fixed_scale=float(value) if (value is int or value is float) and is_finite(float(value)) and float(value)>=1.0 and float(value)<=16.0 else 1.0
	written_scale=Policy.f(fixed_scale)
	value=saved.get_value("interface","ui_scale_unconstrained",false); unconstrained=value if value is bool else false
	apply_scale(fixed_scale,false)
	window.size_changed.connect(window_resized)
	worker=Thread.new(); var result:=worker.start(query_modes)
	if result!=OK: worker=null; error="Native mode query could not start"; query_ready=true
func query_modes() -> Dictionary:
	var executable:=ProjectSettings.globalize_path("res://.cache/native-window/nwn-window-modes.exe")
	if not FileAccess.file_exists(executable): return {"error":"Native mode query is not built"}
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://.cache/native-window/build-manifest.json"))
	if not manifest is Dictionary or str(manifest.get("source",""))!=FileAccess.get_sha256("res://native/window_modes.c") or str(manifest.get("builder",""))!=FileAccess.get_sha256("res://tools/build-window-modes.ps1") or str(manifest.get("binary",""))!=FileAccess.get_sha256(executable): return {"error":"Native mode query needs rebuilding"}
	var output: Array=[]; var code:=OS.execute(executable,[],output,false,false)
	var value: Variant=JSON.parse_string("".join(output))
	if code!=0 or not value is Dictionary or not value.get("readOnly",false) or int(value.get("errors",1))!=0: return {"error":"Native display mode query failed"}
	return {"error":"","screens":value.get("screens",[]),"sources":{"native/window_modes.c":manifest.source,"tools/build-window-modes.ps1":manifest.builder},"binary":manifest.binary}
func _process(_delta: float) -> void:
	if closed or worker==null or worker.is_alive(): return
	var value: Dictionary=worker.wait_to_finish(); worker=null; error=str(value.get("error","")); screens=value.get("screens",[]); query_sources=value.get("sources",{}); query_binary=str(value.get("binary","")); query_ready=true; changed.emit()
func modes() -> Array:
	if window==null: return []
	var index:=window.current_screen
	for screen in screens:
		if int(screen.get("index",-1))==index:
			return Policy.display_modes(screen.get("modes",[]))
	return []
func current() -> Dictionary:
	return {"width":window.size.x,"height":window.size.y,"scale":applied_scale,"maximum":maximum_scale,"minimum":1.0,"windowed":window.mode not in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN],"unconstrained":unconstrained}
func apply_scale(value: float,persist: bool=false) -> bool:
	if closed or window==null or not is_finite(value) or value<0 or value>16: return false
	fixed_scale=Policy.f(value)
	var state:=Policy.scale_update(window.size.x,window.size.y,fixed_scale,applied_scale,unconstrained)
	maximum_scale=state.maximum; applied_scale=state.scale
	# A matching base size prevents automatic fit from multiplying our explicit
	# scale. Canvas Items keeps the 3D target at the physical window resolution.
	if window.content_scale_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS: window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if window.content_scale_size!=window.size: window.content_scale_size=window.size
	if window.content_scale_factor!=applied_scale: window.content_scale_factor=applied_scale
	if persist: commit()
	applies+=1; changed.emit(); return true
func window_resized() -> void:
	# size_changed runs inside Window::_update_viewport_size(), before that
	# function attaches its calculated screen rectangle. Changing content scale
	# here recursively updates the viewport; the outer call then overwrites the
	# corrected attachment with its old-aspect rectangle. Logical hit testing
	# and visible pixels consequently disagree. Apply after the callback returns
	# and coalesce resize bursts using the final client size.
	if closed or resize_pending: return
	resize_pending=true
	call_deferred("settle_resize")
func settle_resize() -> void:
	resize_pending=false
	if closed or not is_instance_valid(window): return
	resize_updates+=1
	apply_scale(fixed_scale,false)
func apply_choice(value: float) -> bool:
	if not is_finite(value) or value<1.0 or value>maximum_scale: return false
	written_scale=Policy.f(value)
	return apply_scale(Policy.fixed_override(value,maximum_scale),false)
func commit() -> void:
	if closed or preference_path.is_empty(): return
	var saved:=ConfigFile.new(); saved.load(preference_path); saved.set_value("interface","ui_scale",written_scale); saved.save(preference_path)
func snapshot() -> Dictionary:
	var geometry: Dictionary={}
	if is_instance_valid(window):
		var logical:=window.get_visible_rect().size; var transform:=window.get_final_transform()
		geometry={"physical":[window.size.x,window.size.y],"base":[window.content_scale_size.x,window.content_scale_size.y],"logical":[logical.x,logical.y],"transform":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y],"mode":window.mode,"screen":window.current_screen}
	return {"ready":query_ready,"error":error,"screens":screens.size(),"modes":modes().size(),"scale":applied_scale,"maximum":maximum_scale,"fixed":fixed_scale,"applies":applies,"resize_updates":resize_updates,"resize_pending":resize_pending,"geometry":geometry,"worker":worker!=null,"query_sources":query_sources.duplicate(),"query_binary":query_binary,"native_only":true,"display_changes":0,"full_video_parity":false}
func close() -> void:
	if closed: return
	closed=true
	if worker!=null: worker.wait_to_finish(); worker=null
	if is_instance_valid(window) and window.size_changed.is_connected(window_resized): window.size_changed.disconnect(window_resized)
	window=null
func _exit_tree() -> void: close()
