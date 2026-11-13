extends RefCounted
# Optional native GUI clock owner. Unavailable is never a fabricated zero or a
# fallback to renderer delta after an explicit native reader has been bound.
static func read(reader: Callable,engine_delta: float)->Dictionary:
	var sample: Variant=reader.call() if reader.is_valid() else {"ready":true,"seconds":engine_delta}
	if not sample is Dictionary or sample.get("ready")!=true:return {"ready":false}
	var seconds: Variant=sample.get("seconds")
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds<0:return {"ready":false}
	return {"ready":true,"seconds":float(seconds)}
