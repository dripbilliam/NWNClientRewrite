extends SceneTree
const Adapter=preload("res://tools/native_parity/visibility/bsp_collector_kernel.gd")
func _initialize() -> void:
	var adapter:=Adapter.new()
	var success: bool=not Adapter.kernel_available() and not adapter.bind_scope({"connection":"one","area":"one"},func(_scope):return true).available and not adapter.build(1,1,0,10).available
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.substr(9),FileAccess.WRITE).store_string(JSON.stringify({"success":success,"checks":3,"scope":"Missing separate kernel remains unavailable; no silent GDS traversal fallback."}))
	print("NATIVE_BSP_KERNEL_MISSING ",success);quit(0 if success else 1)
