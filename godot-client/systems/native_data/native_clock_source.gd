extends RefCounted
# Absolute Win32 microseconds. Explicit loading below .cache leaves the editor's
# extension list alone. This is native direct-Real, not the cached timer thread.
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const DESCRIPTOR="res://.cache/native-clock-source-v1/clock_source.gdextension"
const LIBRARY="res://.cache/native-clock-source-v1/nwn-clock-source.dll"
const LIBRARY_SHA256="497e483e44595a7518b860f92c55e3ab3cef9cd372b15c53a2ac31dfd2498190"
const DESCRIPTOR_TEXT="[configuration]\nentry_symbol=\"nwn_clock_source_candidate_init\"\ncompatibility_minimum=\"4.7\"\nreloadable=false\n[libraries]\nwindows.x86_64=\"res://.cache/native-clock-source-v1/nwn-clock-source.dll\"\n"
const NATIVE_CLASS=&"NwnClockSourceCandidate"
var attempted:=false
var library_ready:=false
var failure:=""
var samples:=0
var unavailable_samples:=0
var last_sample: Dictionary={}
func initialize()->Dictionary:
	if attempted:return {"ready":library_ready,"reason":failure,"phase":"direct-real-only"}
	attempted=true
	if OS.get_name()!="Windows":return reject("The native absolute clock provider is not installed for this platform.")
	if not FileAccess.file_exists(DESCRIPTOR) or FileAccess.get_file_as_string(DESCRIPTOR)!=DESCRIPTOR_TEXT:return reject("Reviewed native clock descriptor is unavailable or changed.")
	if not FileAccess.file_exists(LIBRARY) or FileAccess.get_sha256(LIBRARY)!=LIBRARY_SHA256:return reject("Reviewed native clock library is unavailable or changed.")
	if not GDExtensionManager.is_extension_loaded(DESCRIPTOR):
		# A same-named class from another descriptor is not this reviewed source.
		if ClassDB.class_exists(NATIVE_CLASS):return reject("Native clock class already belongs to another extension.")
		GDExtensionManager.load_extension(DESCRIPTOR)
	if not GDExtensionManager.is_extension_loaded(DESCRIPTOR) or not ClassDB.class_exists(NATIVE_CLASS) or not ClassDB.class_has_method(NATIVE_CLASS,&"sample"):return reject("Native absolute clock extension did not register its source.")
	library_ready=true;failure=""
	return {"ready":true,"phase":"direct-real-only"}
func reject(reason: String)->Dictionary:
	failure=reason;library_ready=false
	return {"ready":false,"reason":failure,"phase":"direct-real-only"}
func read()->Variant:
	if not initialize().ready:return null
	var sample: Variant=ClassDB.class_call_static(NATIVE_CLASS,&"sample")
	samples=mini(samples+1,9007199254740991)
	if not sample is Dictionary or sample.get("ready")!=true or sample.get("source")!="native-direct-real-candidate-v1" or sample.get("phase")!="direct-real-only":
		unavailable_samples=mini(unavailable_samples+1,9007199254740991);last_sample={"ready":false,"reason":"Native absolute sample is unavailable."};return null
	var value:=NativeWorldTimer.words(sample.get("microseconds"))
	if value.is_empty():
		unavailable_samples=mini(unavailable_samples+1,9007199254740991);last_sample={"ready":false,"reason":"Native absolute sample has malformed unsigned words."};return null
	# Retain bounded measured metadata, never a stream or fabricated zero sample.
	last_sample={"ready":true,"phase":sample.phase,"source":sample.source,"branch":sample.get("branch"),"microseconds":value.duplicate(),"frequencyKnown":sample.get("frequency_known"),"qpcKnown":sample.get("qpc_known"),"tickMillisecondsKnown":sample.get("tick_ms_known")}
	return value
func state_view()->Dictionary:
	return {"attempted":attempted,"libraryReady":library_ready,"reason":failure,"phase":"direct-real-only","samples":samples,"unavailableSamples":unavailable_samples,"lastSample":last_sample.duplicate(true)}
