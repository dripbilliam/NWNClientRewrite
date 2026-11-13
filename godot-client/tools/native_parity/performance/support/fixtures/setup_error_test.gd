extends SceneTree
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var checks:=0
var errors: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label)
func run() -> void:
	check(Kernel.available(),"copied native DLL available")
	var geometry=Geometry.new()
	var source:={"vertices":PackedFloat32Array([-1,-1,1,1,-1,1,0,1,1]),"indices":PackedInt32Array([0,1,-1]),"native_planes":PackedFloat32Array([0,0,1,-1]),"native_surface_types":PackedInt32Array([30])}
	geometry.configure(source)
	# One deliberate native setup failure; no invalid face enters a GD query.
	check(geometry.prepare_native_unmasked_support()==null,"native setup failure returns no owner")
	check(geometry.native_support_reason=="Native collision vertex index invalid","actual setup error preserved explicitly")
	check(geometry.native_support_attempted and geometry.native_support_preparations==1,"failed cold preparation counted once")
	check(geometry.native_geometry==null and not geometry.native_attempted,"setup failure does not warm/change canonical owner")
	check(geometry.prepare_native_unmasked_support()==null and geometry.native_support_preparations==1,"failed attempt cached without repeated setup/error")
	source.indices=PackedInt32Array([0,1,2]);geometry.configure(source)
	check(not geometry.native_support_attempted and geometry.native_support_reason.is_empty() and geometry.native_support_preparations==0,"configure clears failure cache/reason")
	check(geometry.prepare_native_unmasked_support()!=null and geometry.native_support_reason.is_empty() and geometry.native_support_preparations==1,"fresh valid configuration prepares successfully")
	var result:={"marker":"PRIVATE_UNMASKED_SETUP_ERROR","checks":checks,"errors":errors,"expected_setup_diagnostic":"Native collision vertex index invalid","scope":"One deliberate native setup error and recovery; no invalid GD face query"}
	var file:=FileAccess.open("res://result-setup.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
