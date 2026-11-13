extends SceneTree
# SOURCE ONLY. Native projection/config fixture, no world/server/native library.
const Policy=preload("res://tools/native_parity/ui/camera_fov_projection.gd")
const Binding=preload("res://tools/native_parity/ui/camera_fov_binding.gd")
const Settings=preload("res://systems/native_render_settings.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func run() -> void:
	check(Policy.DEFAULT_DEGREES==45,"Native module-created gameplay camera default is vertical45degrees")
	for value in [null,"45",NAN,INF,-INF,0,180,-1]:check(not Policy.valid(value),"Unavailable/invalid saved FOV cannot become projection input")
	var directory:=OS.get_environment("NWN_PARITY_UI_TEST_DIR")
	if directory.is_empty():directory="user://"
	var file:=directory.path_join("native-parity-fov-test-"+str(Time.get_ticks_usec())+".cfg")
	var settings:=Settings.new();root.add_child(settings);settings.setup(file,"")
	check(settings.fov_degrees==45 and settings.fov_control.value==45,"Absent preference starts at confirmed native default")
	var binding:=Binding.new();binding.configure(settings)
	var camera:=Camera3D.new();root.add_child(camera)
	check(binding.bind(camera) and camera.fov==45 and camera.keep_aspect==Camera3D.KEEP_HEIGHT,"First actual camera bind applies vertical native convention")
	settings.fov_control.value=80
	check(camera.fov==80 and settings.fov_degrees==80,"Saved slider updates current camera immediately")
	var config:=ConfigFile.new();config.load(file)
	check(config.get_value("rendering","fov_degrees")==80,"User angle persists independently from camera pose/orbit")
	settings.fov_reset.pressed.emit();check(camera.fov==45 and settings.fov_degrees==45,"Original reset restores native45degrees")
	for size_value in [Vector2i(800,600),Vector2i(1600,900),Vector2i(900,1200)]:
		root.size=size_value;await process_frame
		var projection: Projection=camera.get_camera_projection()
		var aspect:=float(size_value.x)/float(size_value.y)
		var vertical:=1.0/tan(deg_to_rad(45.0)*0.5)
		check(absf(projection.y.y-vertical)<0.00001 and absf(projection.x.x-vertical/aspect)<0.00001,"Aspect changes preserve vertical angle and expand horizontal extent")
		var horizontal:=rad_to_deg(2*atan(aspect*tan(deg_to_rad(45)*0.5)))
		check(absf(Policy.horizontal_degrees(45,aspect)-horizontal)<0.00001,"Pure horizontal conversion matches native corner construction")
	camera.fov=60
	check(binding.bind(camera) and camera.fov==60,"Same-camera boundary does not overwrite a later authored/replay projection")
	settings.fov_reset.pressed.emit();check(camera.fov==45,"Explicit Original reset applies even if slider was already45")
	camera.fov=65;binding.unbind()
	check(binding.camera_id==0 and binding.camera==null and binding.settings.get_ref()==settings,"Session unbind drops camera only and keeps settings subscription")
	check(binding.bind(camera) and camera.fov==45,"Reconnect rebind reapplies settings even when Camera3D instance was retained")
	var replacement:=Camera3D.new();root.add_child(replacement)
	check(binding.bind(replacement) and replacement.fov==45,"Replacement camera receives current saved preference")
	binding.close();settings.free();camera.free();replacement.free()
	config.set_value("rendering","fov_degrees",80.0);config.save(file)
	var restored:=Settings.new();root.add_child(restored);restored.setup(file,"")
	check(restored.fov_degrees==80,"Saved numeric FOV reloads")
	restored.free();config.set_value("rendering","fov_degrees","80");config.save(file)
	var malformed:=Settings.new();root.add_child(malformed);malformed.setup(file,"")
	check(malformed.fov_degrees==45,"Wrong-typed saved FOV falls back to native default")
	malformed.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("NATIVE_PARITY_CAMERA_FOV ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
