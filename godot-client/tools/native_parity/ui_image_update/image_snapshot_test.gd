extends SceneTree
# The proposed engine fix uses Image::_duplicate's native shallow COW path.
# No upload/render thread or game state is required for the COW contract.
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	var costs: Array=[]
	for format in [Image.FORMAT_LA8,Image.FORMAT_RGBA8]:
		for edge in [256,512,1024]:
			var source:=Image.create_empty(edge,edge,false,format);source.fill(Color(1,1,1,0.4))
			var wrapper: Image=source.duplicate()
			check(wrapper.get_instance_id()!=source.get_instance_id(),"Snapshot has independent Image identity")
			check(wrapper.get_data()==source.get_data(),"Snapshot starts with exact atlas bytes")
			source.set_pixel(0,0,Color(0.2,0.2,0.2,0.8))
			check(wrapper.get_pixel(0,0)!=source.get_pixel(0,0),"Later live glyph write leaves upload snapshot unchanged")
			wrapper.set_pixel(1,1,Color(0.3,0.3,0.3,0.6))
			check(wrapper.get_pixel(1,1)!=source.get_pixel(1,1),"Snapshot mutation leaves live atlas unchanged")
			var snapshots: Array[Image]=[];var begin:=Time.get_ticks_usec()
			for at in 128:
				var image:=Image.new();image.copy_from(source);snapshots.append(image)
			var wrapper_us:=(Time.get_ticks_usec()-begin)/128.0
			var data:=source.get_data();begin=Time.get_ticks_usec()
			for at in 128:
				var image:=source.duplicate();snapshots.append(image)
			var duplicate_us:=(Time.get_ticks_usec()-begin)/128.0
			begin=Time.get_ticks_usec();source.set_pixel(4,4,Color(0.7,0.7,0.7,1));var cow_write_us:=Time.get_ticks_usec()-begin
			check(not source.is_empty() and snapshots.size()==256 and data.size()==source.get_data_size(),"Wrapper retention and copy-on-write preserve complete atlas")
			costs.append({"format":format,"edge":edge,"bytes":source.get_data_size(),"image_copy_from_wrapper_us":wrapper_us,"image_duplicate_wrapper_us":duplicate_us,"first_live_write_with_retained_snapshot_us":cow_write_us,"iterations":128})
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"costs":costs,"timing_scope":"Headless diagnostic, GDS overhead included; no GPU/FPS/gameplay claim","network_connections":0,"native_builds":0}
	if not output.is_empty():var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("IMAGE_SNAPSHOT_CHECKS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
