extends RefCounted
# Typed native GFF V3.2 output. Struct IDs and field widths are wire contracts.
const Binary=preload("res://systems/native_data/binary_data.gd")
var failure:=""
var structs: Array=[]
var fields: Array=[]
var labels: Array=[]
var data:=PackedByteArray()
var lists: Array=[]
static func field(type: int,value: Variant) -> Dictionary: return {"type":type,"value":value}
static func record(values: Dictionary,type: int=4294967295) -> Dictionary: return {"fields":values,"type":type}
func reject(reason: String) -> void:
	if failure.is_empty(): failure=reason
func text(value: String) -> PackedByteArray:
	var result:=PackedByteArray()
	for code in value.length():
		var point:=value.unicode_at(code); var byte:=point
		if point>=128 and point<=159 or point>255:
			var index:=Binary.CP1252_HIGH.find(point)
			if index<0: reject("Text cannot be encoded in the original client character set"); return PackedByteArray()
			byte=128+index
		result.append(byte)
	return result
static func u32(value: int) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_u32(0,value&0xffffffff); return bytes
func push(bytes: PackedByteArray) -> int:
	var at:=data.size(); data.append_array(bytes); return at
func typed(document: Dictionary,node: Dictionary,type_override: int=-1,depth: int=0) -> Dictionary:
	if depth>128: reject("GFF typed resource is too deep"); return {}
	var index:=-1
	for id in document.records:
		if is_same(document.records[id],node): index=int(id); break
	if index<0: reject("GFF field metadata is unavailable"); return {}
	var values: Dictionary={}
	for key in node:
		var type:=int(document.field_types[index][key]); var value: Variant=node[key]
		if type==14: value=typed(document,value,-1,depth+1)
		elif type==15:
			var entries: Array=[]
			for child in value: entries.append(typed(document,child,-1,depth+1))
			value=entries
		values[key]=field(type,value)
	return record(values,type_override if type_override>=0 else int(document.struct_types[index]))
func add(node: Dictionary,ancestors: Array=[]) -> int:
	if ancestors.size()>128 or structs.size()>100000 or fields.size()>1000000: reject("GFF structure bounds exceeded"); return 0
	for parent in ancestors:
		if is_same(parent,node): reject("Cyclic GFF structure"); return 0
	var index:=structs.size(); var structure:={"type":int(node.get("type",4294967295)),"indices":[]}; structs.append(structure)
	for key in node.get("fields",{}):
		var label:=str(key)
		if label.is_empty() or label.length()>16: reject("Invalid GFF label"); return 0
		for code in label.to_ascii_buffer():
			if code<32 or code>126: reject("Invalid GFF label"); return 0
		var label_id:=labels.find(label)
		if label_id<0: label_id=labels.size(); labels.append(label)
		var source: Dictionary=node.fields[key]; var type:=int(source.type); var value: Variant=source.value
		var entry:={"type":type,"label":label_id,"value":0}; structure.indices.append(fields.size()); fields.append(entry)
		if type>=0 and type<=5:
			var limits: Array=[[0,255],[-128,127],[0,65535],[-32768,32767],[0,4294967295],[-2147483648,2147483647]][type]
			if not value is int or value<limits[0] or value>limits[1]: reject("GFF integer out of range: "+label); return 0
			entry.value=value&0xffffffff
		elif type in [6,7,9]:
			var bytes:=PackedByteArray(); bytes.resize(8)
			if type==9: bytes.encode_double(0,float(value))
			elif type==6 and value is Dictionary: bytes.encode_u32(0,int(value.unsigned64_low)); bytes.encode_u32(4,int(value.unsigned64_high))
			else: bytes.encode_s64(0,int(value))
			entry.value=push(bytes)
		elif type==8:
			var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_float(0,float(value)); entry.value=bytes.decode_u32(0)
		elif type in [10,11]:
			var bytes:=text(str(value))
			if type==11 and bytes.size()>16: reject("GFF resref is too long"); return 0
			var prefix:=PackedByteArray([bytes.size()]) if type==11 else u32(bytes.size()); prefix.append_array(bytes); entry.value=push(prefix)
		elif type==12:
			var loc: Dictionary={"strRef":4294967295,"entries":[{"languageId":0,"text":value}]} if value is String else value
			var body:=u32(int(loc.get("strRef",4294967295))); body.append_array(u32(loc.get("entries",[]).size()))
			for row in loc.get("entries",[]):
				var bytes:=text(str(row.text)); body.append_array(u32(int(row.languageId))); body.append_array(u32(bytes.size())); body.append_array(bytes)
			var prefix:=u32(body.size()); prefix.append_array(body); entry.value=push(prefix)
		elif type==13:
			var bytes:=PackedByteArray(value); var prefix:=u32(bytes.size()); prefix.append_array(bytes); entry.value=push(prefix)
		elif type==14: entry.value=add(value,ancestors+[node])
		elif type==15:
			var at:=lists.size(); lists.append(value.size()); lists.resize(lists.size()+value.size())
			for child in value.size(): lists[at+child+1]=add(value[child],ancestors+[node])
			entry.value=at*4
		elif type in [16,17]:
			var count:=4 if type==16 else 3
			if not value is Array or value.size()!=count: reject("Invalid GFF vector"); return 0
			var bytes:=PackedByteArray(); bytes.resize(count*4)
			for part in count: bytes.encode_float(part*4,float(value[part]))
			entry.value=push(bytes)
		elif type==18: entry.value=push(u32(int(value)))
		else: reject("Unsupported GFF field type"); return 0
		if not failure.is_empty(): return 0
	return index
func write(kind: String,root: Dictionary) -> PackedByteArray:
	failure=""; structs.clear(); fields.clear(); labels.clear(); data.clear(); lists.clear()
	if kind.length()!=4: reject("GFF type must have four characters"); return PackedByteArray()
	add(root)
	if not failure.is_empty(): return PackedByteArray()
	var structures:=PackedByteArray(); var field_bytes:=PackedByteArray(); var label_bytes:=PackedByteArray(); var indices:=PackedByteArray(); var list_bytes:=PackedByteArray()
	for row in structs:
		structures.append_array(u32(row.type)); structures.append_array(u32(int(row.indices[0]) if row.indices.size()==1 else indices.size() if row.indices.size()>1 else 0)); structures.append_array(u32(row.indices.size()))
		if row.indices.size()>1:
			for id in row.indices: indices.append_array(u32(int(id)))
	for row in fields:
		for key in ["type","label","value"]: field_bytes.append_array(u32(int(row[key])))
	for label in labels:
		var bytes:=str(label).to_ascii_buffer(); bytes.resize(16); label_bytes.append_array(bytes)
	for id in lists: list_bytes.append_array(u32(int(id)))
	var output: PackedByteArray=(kind+"V3.2").to_ascii_buffer(); var sections: Array=[structures,field_bytes,label_bytes,data,indices,list_bytes]; var counts: Array=[structs.size(),fields.size(),labels.size(),data.size(),indices.size(),list_bytes.size()]; var at:=56
	for index in sections.size(): output.append_array(u32(at)); output.append_array(u32(int(counts[index]))); at+=sections[index].size()
	for bytes in sections: output.append_array(bytes)
	return output
