extends RefCounted
# Copy data, never Godot object ownership. duplicate(true) alone retains Objects.
const MAX_DEPTH:=64
static func copy(value: Variant,unavailable: Array=[],path: String="$",ancestors: Array=[],budget: Dictionary={}) -> Variant:
	var kind:=typeof(value)
	if not budget.is_empty():
		budget.nodes=int(budget.get("nodes",0))+1
		if budget.get("exceeded",false) or budget.nodes>int(budget.get("max_nodes",8192)) or ancestors.size()>int(budget.get("max_depth",48)) or path.length()>int(budget.get("max_path_chars",2048)):
			budget.exceeded=true; return null
		if kind in [TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH]:
			budget.text_chars=int(budget.get("text_chars",0))+str(value).length()
			if budget.text_chars>int(budget.get("max_text_chars",65536)): budget.exceeded=true; return null
	if kind in [TYPE_DICTIONARY,TYPE_ARRAY]:
		if ancestors.size()>=MAX_DEPTH or ancestors.any(func(parent):return is_same(parent,value)):
			unavailable.append(path); return null
		var parents:=ancestors.duplicate(); parents.append(value)
		if kind==TYPE_DICTIONARY:
			var result: Dictionary={}
			for key in value:
				if budget.get("exceeded",false): break
				if not budget.is_empty():
					budget.entries=int(budget.get("entries",0))+1
					if budget.entries>int(budget.get("max_nodes",8192)): budget.exceeded=true; break
				if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT,TYPE_FLOAT,TYPE_BOOL]: unavailable.append(path+".<key>"); continue
				if not budget.is_empty():
					if str(key).length()>int(budget.get("max_key_chars",256)): budget.exceeded=true; break
					budget.text_chars=int(budget.get("text_chars",0))+str(key).length()
					if budget.text_chars>int(budget.get("max_text_chars",65536)): budget.exceeded=true; break
				result[key]=copy(value[key],unavailable,path+"."+str(key),parents,budget)
			return result
		var result: Array=[]
		for index in value.size():
			if budget.get("exceeded",false): break
			result.append(copy(value[index],unavailable,path+"["+str(index)+"]",parents,budget))
		return result
	if kind>=TYPE_PACKED_BYTE_ARRAY and kind<=TYPE_PACKED_VECTOR4_ARRAY:
		var result: Array=[]
		for item in value:
			if budget.get("exceeded",false): break
			result.append(copy(item,unavailable,path,ancestors,budget))
		return result
	if kind in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]:
		unavailable.append(path); return null
	return value

static func freeze(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item in value: freeze(item)
		value.make_read_only()
	return value

static func event(value: Dictionary) -> Dictionary:
	return freeze(copy(value))
