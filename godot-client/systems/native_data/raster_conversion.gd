extends RefCounted
# Pure byte arithmetic in the pinned GDExtension. No engine Image/scene/GPU
# objects are constructed by workers. Missing extension keeps the GD reference.
static var available:=ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","raster_tga") and ClassDB.class_has_method("NwnParticleKernel","raster_bgra") and ClassDB.class_has_method("NwnParticleKernel","plt_layer_order") and ClassDB.class_has_method("NwnParticleKernel","plt_colorize")
static func configured_enabled() -> bool: return not OS.get_cmdline_user_args().has("--raster-conversion=gd")
static func tga(bytes: PackedByteArray) -> PackedByteArray: return ClassDB.class_call_static("NwnParticleKernel","raster_tga",bytes)
static func bgra(bytes: PackedByteArray,offset: int,count: int,stride: int) -> PackedByteArray: return ClassDB.class_call_static("NwnParticleKernel","raster_bgra",bytes,offset,count,stride)
static func layer_mask(bytes: PackedByteArray) -> int: return int(ClassDB.class_call_static("NwnParticleKernel","plt_layer_mask",bytes))
static func layer_order(bytes: PackedByteArray) -> int: return int(ClassDB.class_call_static("NwnParticleKernel","plt_layer_order",bytes))
static func colorize(bytes: PackedByteArray,lookup: PackedByteArray) -> PackedByteArray: return ClassDB.class_call_static("NwnParticleKernel","plt_colorize",bytes,lookup)
static func snapshot() -> Dictionary: return {"enabled":configured_enabled(),"available":available,"scope":"Data-only bounded TGA/DDS/PLT byte loops; pixel output/parity checked independently"}
