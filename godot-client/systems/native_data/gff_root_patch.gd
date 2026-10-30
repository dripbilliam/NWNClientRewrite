extends RefCounted
# Replaces primitive root fields without decoding/re-encoding any untouched
# field, graph, localized string, integer, floating-point bit pattern or blob.
# All existing physical struct/field/label IDs remain stable. Missing root
# fields append; unrelated root duplicates and unreachable records survive.
const Reader=preload("res://systems/native_data/gff_document.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const MAX_BYTES:=948*65535-16
var failure:=""
func reject(reason: String) -> PackedByteArray:
	failure=reason; return PackedByteArray()
func apply(source: PackedByteArray,changes: Dictionary,kind: String="BIC ") -> PackedByteArray:
	failure=""
	if source.size()>MAX_BYTES: return reject("Character resource exceeds supported bounds.")
	var reader:=Reader.new(); reader.parse(source,kind,true)
	if not reader.failure.is_empty(): return reject(reader.failure)
	if changes.is_empty(): return source.duplicate()
	var parts: Array=[]
	for index in 6:
		var offset:=source.decode_u32(8+index*8); var count:=source.decode_u32(12+index*8)
		parts.append(source.slice(offset,offset+count*[12,12,16,1,1,1][index]))
	var root_count: int=parts[0].decode_u32(8); var first: int=parts[0].decode_u32(4); var root_fields: Array=[]
	if root_count==1: root_fields.append(first)
	elif root_count>1:
		for index in root_count: root_fields.append(parts[4].decode_u32(first+index*4))
	var root_labels: Dictionary={}
	var references: Dictionary={}
	for row in reader.structs:
		var ids: Array=[]
		if row.count==1: ids.append(row.first)
		elif row.count>1:
			if int(row.first)%4!=0 or int(row.first)>parts[4].size() or int(row.count)>(parts[4].size()-int(row.first))/4: return reject("Invalid physical GFF field references.")
			for index in int(row.count): ids.append(parts[4].decode_u32(int(row.first)+index*4))
		for id in ids:
			if int(id)>=reader.fields.size(): return reject("Invalid physical GFF field reference.")
			references[int(id)]=int(references.get(int(id),0))+1
	for id in root_fields:
		var label_id: int=parts[1].decode_u32(int(id)*12+4)
		var label: String=reader.labels[label_id]
		if not root_labels.has(label): root_labels[label]=[]
		root_labels[label].append(int(id))
	for label in changes:
		var spec: Variant=changes[label]
		if not label is String or not spec is Dictionary or not spec.get("type") is int or not spec.has("value") or spec.type in [14,15] or spec.type<0 or spec.type>18: return reject("Root patch requires typed primitive fields.")
		if root_labels.get(label,[]).size()>1: return reject("The edited root field is ambiguous: "+str(label))
		var writer:=Writer.new(); var encoded:=writer.write(kind,Writer.record({label:spec}))
		if not writer.failure.is_empty(): return reject(writer.failure)
		var encoded_field:=encoded.decode_u32(16); var value:=encoded.decode_u32(encoded_field+8)
		if int(spec.type)>=6 and int(spec.type)!=8:
			value+=parts[3].size()
			var offset:=encoded.decode_u32(32); parts[3].append_array(encoded.slice(offset,offset+encoded.decode_u32(36)))
		var label_id:=reader.labels.find(label)
		if label_id<0:
			label_id=reader.labels.size(); reader.labels.append(label)
			var bytes: PackedByteArray=label.to_ascii_buffer(); bytes.resize(16); parts[2].append_array(bytes)
		var original_id: int=int(root_labels[label][0]) if root_labels.has(label) else -1
		var field_id:=original_id
		if original_id<0 or int(references.get(original_id,0))>1:
			# A field ID can be shared by root and nested structs. Copy only the
			# edited root edge, so changing Age cannot change an item/local value.
			field_id=parts[1].size()/12
			parts[1].append_array(PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0]))
			if original_id<0: root_fields.append(field_id)
			else: root_fields[root_fields.find(original_id)]=field_id
		parts[1].encode_u32(field_id*12,int(spec.type)); parts[1].encode_u32(field_id*12+4,label_id); parts[1].encode_u32(field_id*12+8,value)
	if root_fields.size()>1:
		first=parts[4].size()
		for id in root_fields: parts[4].append_array(Writer.u32(int(id)))
	else: first=int(root_fields[0]) if root_fields.size()==1 else 0
	parts[0].encode_u32(4,first); parts[0].encode_u32(8,root_fields.size())
	var result:=source.slice(0,8); var offset:=56
	for index in 6:
		var count: int=parts[index].size()/[12,12,16,1,1,1][index]
		result.append_array(Writer.u32(offset)); result.append_array(Writer.u32(count)); offset+=parts[index].size()
	if offset>MAX_BYTES: return reject("Edited character resource exceeds supported bounds.")
	for bytes in parts: result.append_array(bytes)
	# Keep malformed type/offset results from escaping to a future file owner.
	reader.parse(result,kind,true)
	if not reader.failure.is_empty(): return reject(reader.failure)
	return result
