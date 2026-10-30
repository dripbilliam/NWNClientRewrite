extends RefCounted
const Writer=preload("res://systems/native_data/gff_writer.gd")
# Complete original CCharPageFeats::SetData1409c0920 admission semantics.
# Row insertion/sorting is separate. Do not change general gameplay ownership.
static func feat_admission(primary: Array,bonus: Array,lookup: Callable) -> Dictionary:
	primary=primary.map(func(id):return int(id)&65535); bonus=bonus.map(func(id):return int(id)&65535)
	var ids: Array=[]; var errors: Array=[]
	for source in primary:
		var id:=int(source)&65535; var visited: Dictionary={}; var valid:=true
		while true:
			if visited.has(id): errors.append("Original character-sheet feat successor cycle"); valid=false; break
			visited[id]=true
			var next: Variant=lookup.call(id)
			if next==null: valid=false; break
			var successor:=int(next)&65535
			if successor==0 or not primary.has(successor) and not bonus.has(successor): break
			id=successor
		if valid and not ids.has(id): ids.append(id)
	# Native secondary-list admission excludes primary membership, but does not
	# deduplicate against an ID already selected by a primary successor walk.
	for source in bonus:
		var id:=int(source)&65535
		if not primary.has(id) and lookup.call(id)!=null: ids.append(id)
	return {"ids":ids,"errors":errors}
static func compare(first: PackedByteArray,second: PackedByteArray) -> int:
	# Original default _stricmp path is bytewise ASCII folding, not natural or
	# Unicode locale collation. It stops at the first source NUL.
	var at:=0
	while true:
		var a: int=first[at] if at<first.size() else 0; var b: int=second[at] if at<second.size() else 0
		if a>=65 and a<=90: a+=32
		if b>=65 and b<=90: b+=32
		if a!=b or a==0: return a-b
		at+=1
	return 0
static func ordered(entries: Array) -> Array:
	var rows: Array=[]; var keys: Array=[]; var writer:=Writer.new()
	for entry in entries:
		var key:=writer.text(str(entry.name)); var first:=0; var last:=rows.size()
		while first<last:
			var middle: int=(first+last)/2
			if compare(key,keys[middle])>0: first=middle+1
			else: last=middle
		rows.insert(first,entry); keys.insert(first,key)
	return rows
