extends RefCounted
# JSON values retain Variant type/precision where ordinary JSON cannot.
const MAX_NODES:=16384
const MAX_DEPTH:=48
const MAX_STRING_CHARS:=131072
const SAFE_INTEGER:=9007199254740991
static func encode(value: Variant) -> Dictionary:
	var state:={"nodes":0,"text_chars":0,"failed":false,"unavailable":[]}
	var converted: Variant=_value(value,state,"$",0)
	return {"ok":not state.failed,"value":converted,"unavailable_paths":state.unavailable}
static func _tag(name: String,parts: Variant,state: Dictionary,path: String,depth: int) -> Dictionary:
	return {"$type":name,"value":_value(parts,state,path,depth+1)}
static func _value(value: Variant,state: Dictionary,path: String,depth: int) -> Variant:
	state.nodes+=1
	if state.failed or state.nodes>MAX_NODES or depth>MAX_DEPTH:
		state.failed=true; return null
	match typeof(value):
		TYPE_NIL,TYPE_BOOL: return value
		TYPE_INT: return {"$type":"int64","value":str(value)} if value>SAFE_INTEGER or value< -SAFE_INTEGER else value
		TYPE_FLOAT:
			return value if is_finite(value) else {"$type":"float","value":"NaN" if is_nan(value) else ("Infinity" if value>0 else "-Infinity")}
		TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH:
			state.text_chars+=str(value).length()
			if state.text_chars>MAX_STRING_CHARS: state.failed=true; return null
			return str(value)
		TYPE_ARRAY:
			var result: Array=[]
			for index in value.size():
				if state.failed: break
				result.append(_value(value[index],state,path+"["+str(index)+"]",depth+1))
			return result
		TYPE_DICTIONARY:
			if value.has("$type") or value.keys().any(func(key):return not (key is String or key is StringName)):
				var entries: Array=[]
				for key in value:
					if state.failed: break
					entries.append([_value(key,state,path+".<key>",depth+1),_value(value[key],state,path+".<value>",depth+1)])
				return {"$type":"Dictionary","entries":entries}
			var result: Dictionary={}
			for key in value:
				if state.failed: break
				state.text_chars+=str(key).length()
				if str(key).length()>1024 or state.text_chars>MAX_STRING_CHARS: state.failed=true; break
				result[str(key)]=_value(value[key],state,path+"."+str(key),depth+1)
			return result
		TYPE_VECTOR2,TYPE_VECTOR2I: return _tag("Vector2i" if value is Vector2i else "Vector2",[value.x,value.y],state,path,depth)
		TYPE_VECTOR3,TYPE_VECTOR3I: return _tag("Vector3i" if value is Vector3i else "Vector3",[value.x,value.y,value.z],state,path,depth)
		TYPE_VECTOR4,TYPE_VECTOR4I: return _tag("Vector4i" if value is Vector4i else "Vector4",[value.x,value.y,value.z,value.w],state,path,depth)
		TYPE_COLOR: return _tag("Color",[value.r,value.g,value.b,value.a],state,path,depth)
		TYPE_QUATERNION: return _tag("Quaternion",[value.x,value.y,value.z,value.w],state,path,depth)
		TYPE_RECT2,TYPE_RECT2I: return _tag("Rect2i" if value is Rect2i else "Rect2",[value.position,value.size],state,path,depth)
		TYPE_AABB: return _tag("AABB",[value.position,value.size],state,path,depth)
		TYPE_BASIS: return _tag("Basis",[value.x,value.y,value.z],state,path,depth)
		TYPE_TRANSFORM2D: return _tag("Transform2D",[value.x,value.y,value.origin],state,path,depth)
		TYPE_TRANSFORM3D: return _tag("Transform3D",[value.basis,value.origin],state,path,depth)
		TYPE_PLANE: return _tag("Plane",[value.normal,value.d],state,path,depth)
		TYPE_PROJECTION: return _tag("Projection",[value.x,value.y,value.z,value.w],state,path,depth)
		_:
			if typeof(value)>=TYPE_PACKED_BYTE_ARRAY and typeof(value)<=TYPE_PACKED_VECTOR4_ARRAY:
				var result: Array=[]
				for item in value:
					if state.failed: break
					result.append(_value(item,state,path,depth+1))
				return result
			state.unavailable.append(path); return null
