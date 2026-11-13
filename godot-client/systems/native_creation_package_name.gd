extends Node
# Original package OK8e4620 uses GetRandomName(0xfe) before storing Associate
# and completing8008. Reuse the same native LTR/filter worker as manual names;
# this owner only fences its asynchronous result to one package invocation.
const Names=preload("res://systems/native_associate_names.gd")
var names
var generation:=0
var request_id:=-1
var reply: Dictionary={}
var identity: Array=[]
var closed:=false
func current(epoch: int,valid: Callable) -> bool:
	return not closed and generation==epoch and valid.is_valid() and bool(valid.call())
func generate(catalog,value_scope: Array,valid: Callable) -> Dictionary:
	if closed or not valid.is_valid() or not bool(valid.call()):return {"ready":false,"cancelled":true}
	generation+=1;var epoch:=generation;request_id=-1;reply={};identity=value_scope.duplicate()
	if not is_instance_valid(names):
		names=Names.new();add_child(names);names.name_ready.connect(received)
	names.configure(catalog,identity)
	while current(epoch,valid) and not names.resources_ready and names.failure.is_empty():await get_tree().process_frame
	if not current(epoch,valid):
		if epoch==generation:retire()
		return {"ready":false,"cancelled":true}
	if not names.failure.is_empty():return {"ready":false,"error":str(names.failure)}
	request_id=names.request_name(identity)
	if request_id<0:return {"ready":false,"error":"The associate name request could not begin."}
	while current(epoch,valid) and reply.is_empty():await get_tree().process_frame
	if not current(epoch,valid):
		if epoch==generation:retire()
		return {"ready":false,"cancelled":true}
	if not reply.get("ready",false) or not reply.get("name") is String or str(reply.name).is_empty():return {"ready":false,"error":str(reply.get("reason","The associate name could not be generated."))}
	return {"ready":true,"name":str(reply.name)}
func received(id: int,value: Dictionary) -> void:
	if closed or id!=request_id or value.get("scope",[])!=identity:return
	reply=value.duplicate(true)
func retire() -> void:generation+=1;request_id=-1;reply={};identity=[]
func close() -> void:
	if closed:return
	closed=true;retire()
	if is_instance_valid(names):names.close()
func _exit_tree() -> void:close()
