extends RefCounted
# Internal data-only completed-bundle loans. Packed arrays have reference
# semantics, so every route to one is copied and its packed wrapper duplicated.
# Only structurally immutable subtrees without packed leaves are shared.
const PACKED=[TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_COLOR_ARRAY,TYPE_PACKED_VECTOR4_ARRAY]
const UNSAFE=[TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]
const MAX_DEPTH=64
const MAX_CONTAINERS=262144
static func prepare(source: Dictionary) -> Dictionary:
	var stats:={"containers":0,"packed_leaves":0,"copy_branches":0,"shared_branches":0,"rejected":""}
	var result:=build(source,0,stats)
	if not result.ready:return {"ready":false,"reason":stats.rejected,"stats":stats}
	return {"ready":true,"value":result.value,"plan":{"source":result.value,"branch":result.plan},"stats":stats}
static func reject(stats: Dictionary,reason: String) -> Dictionary:
	stats.rejected=reason;return {"ready":false}
static func build(source: Variant,depth: int,stats: Dictionary) -> Dictionary:
	var kind:=typeof(source)
	if kind in UNSAFE:return reject(stats,"Object, callable, signal and RID payloads are not loanable")
	if kind in PACKED:
		stats.packed_leaves+=1
		var private=source.duplicate()
		return {"ready":true,"value":private,"plan":{"kind":kind,"source":private}}
	if source is Dictionary or source is Array:
		if depth>=MAX_DEPTH or stats.containers>=MAX_CONTAINERS:return reject(stats,"Container depth/count exceeds loan compilation bound")
		stats.containers+=1
		var result=source.duplicate();var changes: Dictionary={}
		if source is Dictionary:
			# Dictionary duplicate does not promise detached container/Object keys.
			# Native model bundles use scalar keys; other key kinds use fallback.
			for key in source:
				var key_kind:=typeof(key)
				if key_kind in UNSAFE or key_kind in PACKED or key is Dictionary or key is Array:return reject(stats,"Container and object dictionary keys are not loanable")
				var child:=build(source[key],depth+1,stats)
				if not child.ready:return child
				result[key]=child.value
				if child.plan!=null:changes[key]=child.plan
		else:
			if source.is_typed() and source.get_typed_builtin()==TYPE_OBJECT:return reject(stats,"Object-typed arrays are not loanable")
			for index in source.size():
				var child:=build(source[index],depth+1,stats)
				if not child.ready:return child
				result[index]=child.value
				if child.plan!=null:changes[index]=child.plan
		result.make_read_only()
		if changes.is_empty():stats.shared_branches+=1;return {"ready":true,"value":result,"plan":null}
		stats.copy_branches+=1
		return {"ready":true,"value":result,"plan":{"kind":kind,"source":result,"changes":changes}}
	return {"ready":true,"value":source,"plan":null}
static func copy_branch(plan: Dictionary):
	var source=plan.source
	if int(plan.kind) in PACKED:return source.duplicate()
	var result=source.duplicate()
	for key in plan.changes:result[key]=copy_branch(plan.changes[key])
	result.make_read_only();return result
static func borrow(plan: Dictionary) -> Dictionary:
	var value: Dictionary=plan.source if plan.branch==null else copy_branch(plan.branch)
	# Job/result publication owns its mutable outer header. Nested containers are
	# read-only; packed leaves are private per recipient, never cached storage.
	return value.duplicate()
