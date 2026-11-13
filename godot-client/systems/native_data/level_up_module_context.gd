extends RefCounted
# LoadModule7cd2c0 receives these two BOOLs into client+24/+28;838950
# consumes them for maximum die and hidden HP text. No local setting/default.
static func native_bool(value: Variant) -> Variant:
	if value is bool:return value
	# NativeMessageReader.readBool publishes the actual bit as numeric0/1;
	# JSON transports it as a float. Accept only those exact finite values.
	if (value is int or value is float) and is_finite(float(value)) and (value==0 or value==1):return int(value)==1
	return null
static func compose(module: Variant) -> Dictionary:
	var flags: Dictionary=module.get("serverFlags",{}) if module is Dictionary and module.get("serverFlags") is Dictionary else {}
	return {"forceMaximum":native_bool(flags.get("field158")),"hideHitPointGain":native_bool(flags.get("field164"))}
