extends SceneTree
const Cursor=preload("res://systems/native_mouse_cursor.gd")
const Policy=preload("res://systems/native_data/mouse_cursor.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var checks:=0
var failures: Array=[]
var calls: Array=[]
var packets: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func pixels() -> Image:
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.8,.5));image.set_pixel(0,0,Color.RED);image.set_pixel(0,31,Color.BLUE);return image
func configured():
	var cursor:=Cursor.new();root.add_child(cursor);cursor.set_process(false);cursor.set_process_input(false)
	cursor.images[1]=pixels();cursor.images[91]=pixels();cursor.images[92]=pixels();cursor.missing[93]=true
	return cursor
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(DisplayServer.get_name()=="headless","Transport fixture is headless and never changes physical cursor")
	var cursor=configured();cursor.hardware_publisher=func(image,shape,hotspot):calls.append({"image":image,"shape":shape,"hotspot":hotspot})
	var original: PackedByteArray=cursor.images[92].get_data()
	cursor.publish(Policy.selection(91,true),true,2.)
	check(calls.size()==3,"One physical publication emits exactly three cursor shape calls")
	check(calls.map(func(row):return row.shape)==[Input.CURSOR_ARROW,Input.CURSOR_POINTING_HAND,Input.CURSOR_HELP],"Arrow/pointing/help shape order is preserved")
	check(calls.all(func(row):return row.image is Image and not row.image is Texture2D),"Every physical call receives CPU Image instead of GPU texture")
	check(calls.all(func(row):return row.hotspot==Vector2(32,32)),"Original centered hotspot follows actual2x geometry")
	check(is_same(calls[0].image,calls[1].image) and is_same(calls[1].image,calls[2].image),"Three shape calls reuse the same retained CPU image")
	var expected: Image=cursor.images[92].duplicate();expected.resize(64,64,Image.INTERPOLATE_NEAREST)
	check(calls[0].image.get_size()==Vector2i(64,64) and calls[0].image.get_data()==expected.get_data(),"Pressed variant92 retains exact nearest-scaled prepared pixel bytes")
	check(cursor.images[92].get_size()==Vector2i(32,32) and cursor.images[92].get_data()==original,"Publication never mutates prepared source image")
	check(cursor.textures.is_empty() and cursor.cursor_images.size()==1,"Physical route creates zero ImageTextures and one cached CPU image")
	var first: Image=calls[0].image;cursor.publish(Policy.selection(91,true),true,2.)
	check(calls.size()==3 and cursor.publications==1,"Unchanged cursor does not republish or allocate")
	cursor.publish(Policy.selection(91,false),true,2.)
	check(calls.size()==6 and is_same(calls[3].image,first) and calls[3].hotspot==Vector2.ZERO,"Hotspot-only change reuses CPU image and preserves corner alignment")
	cursor.publish(Policy.selection(91,true),false,2.)
	check(calls.size()==9 and not is_same(calls[6].image,first) and cursor.cursor_images.size()==2,"Button release selects original unpressed variant with separate image cache entry")
	check(cursor.textures.is_empty(),"Press/release still makes zero physical-path GPU textures")
	for size in range(1,130):cursor.publish(Policy.selection(91,true),false,float(size)/32.)
	check(cursor.cursor_images.size()==128 and cursor.texture_order.size()==128 and cursor.textures.is_empty(),"CPU cache retains exact128-entry bound across sizes without GPU upload")
	check(cursor.texture_order.all(func(key):return cursor.cursor_images.has(key)),"Cache LRU order names only retained CPU images")
	var before:=calls.size();cursor.publish(Policy.selection(93,true),false,1.)
	check(calls.size()==before+3 and calls[-1].hotspot==Vector2.ZERO and calls[-1].image.get_data()==cursor.images[1].get_data(),"Missing custom artwork uses original CPU arrow and noncentered fallback hotspot")
	before=calls.size();cursor.publish(Policy.selection(93,true),false,1.)
	check(calls.size()==before,"Missing fallback stamp suppresses repeated physical publication")
	cursor.release()
	check(calls.size()==before+3 and calls.slice(-3).all(func(row):return row.image==null and row.hotspot==Vector2.ZERO),"Release resets all three hardware shapes without texture reads")
	before=calls.size();cursor.release();check(calls.size()==before,"Repeated release is idempotent")
	cursor.publish(Policy.selection(91),false,1.);before=calls.size();cursor.close()
	check(calls.size()==before+3 and cursor.images.is_empty() and cursor.cursor_images.is_empty() and cursor.textures.is_empty() and cursor.texture_order.is_empty(),"Closing published owner resets shapes and drops prepared/CPU/GPU cache ownership")
	before=calls.size();cursor.publish(Policy.selection(91),false,1.);cursor.prepared(1,{})
	check(calls.size()==before and cursor.closed and not cursor.hardware_publisher.is_valid(),"Closed owner rejects publication and late completion and clears injected hardware callback")
	cursor.free();calls.clear();first=null;expected=null
	var legacy=configured();legacy.publisher=func(packet):packets.append(packet.duplicate());legacy.hardware_publisher=func(image,shape,hotspot):calls.append({"image":image,"shape":shape,"hotspot":hotspot})
	legacy.publish(Policy.selection(91,true),true,1.5)
	check(packets.size()==1 and calls.is_empty(),"Existing injected publisher remains exclusive and never reaches physical sink")
	check(packets[0].id==92 and packets[0].size==48 and packets[0].hotspot==Vector2(24,24),"Existing publisher packet identity/geometry contract is preserved")
	check(packets[0].texture is ImageTexture and packets[0].texture.get_size()==Vector2(48,48) and packets[0].image is Image,"Legacy TextureRect publisher receives lazily created compatible texture plus CPU image")
	check(legacy.textures.size()==1 and legacy.cursor_images.size()==1,"Injected publisher creates exactly one lazy diagnostic texture")
	legacy.publish(Policy.selection(91,true),true,1.5);check(packets.size()==1 and legacy.textures.size()==1,"Legacy repeated stamp reuses lazy texture without republishing")
	legacy.close();check(packets[-1].get("reset",false) and legacy.textures.is_empty() and legacy.cursor_images.is_empty(),"Legacy publisher close retains reset contract and clears both caches")
	legacy.free();packets.clear();calls.clear()
	check(Timing.CALLBACKS.count("callback_mouse_cursor")==1,"Cursor callback is included exactly once in disjoint main-thread owner accounting")
	check(Timing.CALLBACKS.count("callback_ui")==1 and not Timing.CALLBACKS.has("physics_pointer"),"UI remains a separate owner and physics-pointer child is not double-counted")
	for frame in 2:await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"physicalPointerCalls":0,"gpuRuns":0,"publicConnections":0,"nativeBuilds":0,"scope":"Isolated CPU Image transport candidate with injected fake hardware sink. Authored RGBA source checks bytes/scaling/cache/lifetime and legacy publisher contract. No physical OS publication, GPU timing or native-client performance claim."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("CURSOR_CPU_IMAGE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
