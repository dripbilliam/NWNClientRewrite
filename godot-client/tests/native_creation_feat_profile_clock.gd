extends RefCounted
static var enabled:=false
static var stack: Array=[]
static var totals: Dictionary={}
static func reset() -> void:stack=[];totals={};enabled=true
static func enter(label: String) -> int:
	if not enabled:return 0
	stack.append({"label":label,"start":Time.get_ticks_usec(),"children":0});return stack.size()
static func leave(token: int) -> void:
	if token==0:return
	assert(stack.size()==token,"Profile spans must close in call order")
	var frame: Dictionary=stack.pop_back();var elapsed:=Time.get_ticks_usec()-int(frame.start)
	var row: Dictionary=totals.get_or_add(str(frame.label),{"calls":0,"inclusiveUsec":0,"exclusiveUsec":0,"maxUsec":0})
	row.calls+=1;row.inclusiveUsec+=elapsed;row.exclusiveUsec+=maxi(0,elapsed-int(frame.children));row.maxUsec=maxi(int(row.maxUsec),elapsed)
	if not stack.is_empty():stack[-1].children+=elapsed
static func finish() -> Dictionary:
	enabled=false;assert(stack.is_empty(),"No pending synchronous spans")
	return totals.duplicate(true)
