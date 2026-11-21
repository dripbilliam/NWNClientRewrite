extends RefCounted
# Direct projection of src/network_connection_failure.js. Only admitted labels,
# error codes, and reason names cross from a connection error into diagnostics.
const STAGES=["validate-options","resolve-address","bind-socket","application-identity","platform-identity","login-context","key-exchange","send-key-exchange","await-admission","session-connect"]
const NAMES=["Error","TypeError","RangeError","SyntaxError","AggregateError"]
const REASONS={
	"Concurrent native crypto operations are unavailable":"crypto-concurrent",
	"Native network crypto helper is closed":"crypto-closed",
	"Native network crypto helper is unavailable":"crypto-unavailable",
	"Native network crypto helper stopped":"crypto-stopped",
	"Native network crypto helper input failed":"crypto-input-failed",
	"Native network crypto helper timed out":"crypto-timeout",
	"Native network cryptographic authentication failed":"crypto-authentication",
	"Invalid native application identity output":"application-identity-invalid",
	"Invalid native platform identity output":"platform-identity-invalid",
	"Invalid native network connection settings":"invalid-options",
	"Native network login timed out":"server-timeout"
}

static func stage_name(value: Variant) -> String:
	return value if value is String and STAGES.has(value) else "session-connect"

static func code_suffix(value: String,offset: int,maximum: int) -> bool:
	var length:=value.length()-offset
	if length<1 or length>maximum:return false
	for index in range(offset,value.length()):
		var letter:=value.unicode_at(index)
		if not (letter>=65 and letter<=90 or letter>=48 and letter<=57 or letter==95):return false
	return true

static func standard_code(value: Variant) -> Variant:
	if not value is String:return null
	if value.begins_with("ERR_") and code_suffix(value,4,64):return value
	if value.begins_with("E") and code_suffix(value,1,24):return value
	return null

static func project(error: Variant,stage: Variant) -> Dictionary:
	var fields: Dictionary=error if error is Dictionary else {}
	var name: Variant=fields.get("name")
	var message: Variant=fields.get("message")
	return {"stage":stage_name(stage),"name":name if name is String and NAMES.has(name) else "Error","code":standard_code(fields.get("code")),"reason":REASONS.get(message,"connection-failed") if message is String else "connection-failed"}

static func failure_text(failure: Variant) -> String:
	var fields: Dictionary=failure if failure is Dictionary else {}
	var stage:=stage_name(fields.get("stage"))
	var detail: Variant=fields.get("code")
	if detail==null:
		var reason: Variant=fields.get("reason")
		if reason!=null and reason!="" and reason!="connection-failed":detail=reason
	return "Native game session connection failed ("+stage+(": "+str(detail) if detail!=null and detail!="" else "")+")"
