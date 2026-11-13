extends RefCounted
# Original ui.tooltip-delay registration6b755a..75fb uses microseconds:
# default100000, constrained to1000..5000000. Its callback6bdb70 updates
# the shared GUI delay and saved normal delay, not the active countdown.
const DEFAULT_USEC:=100000
const MIN_USEC:=1000
const MAX_USEC:=5000000
const Highlight=preload("res://systems/native_data/tooltip_highlight.gd")
static var delay_usec:=DEFAULT_USEC
static var doubletap_ms:=Highlight.DEFAULT_MS
static func clean(value: Variant) -> int:
	return clampi(value,MIN_USEC,MAX_USEC) if value is int else DEFAULT_USEC
static func apply(value: Variant) -> int:
	delay_usec=clean(value)
	# The native item bubble and the remaining engine tooltip consumers share
	# this delay. Their full movement/ownership policy still needs integration.
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",float(delay_usec)/1000000.0)
	return delay_usec
static func save(path: String,value: Variant) -> int:
	var normalized:=apply(value)
	if not path.is_empty():
		var config:=ConfigFile.new(); config.load(path)
		config.set_value("interface","tooltip_delay_usec",normalized); config.save(path)
	return normalized
static func clean_doubletap(value: Variant) -> int:
	return clampi(value,Highlight.MIN_MS,Highlight.MAX_MS) if value is int else Highlight.DEFAULT_MS
static func apply_doubletap(value: Variant) -> int:
	doubletap_ms=clean_doubletap(value); return doubletap_ms
static func save_doubletap(path: String,value: Variant) -> int:
	var normalized:=apply_doubletap(value)
	if not path.is_empty():
		var config:=ConfigFile.new(); config.load(path); config.set_value("interface","tooltip_doubletap_ms",normalized); config.save(path)
	return normalized
