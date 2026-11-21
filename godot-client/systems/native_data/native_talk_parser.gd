extends RefCounted
# Strict CTlkTable::ParseStr199e20 over terminated native bytes. Presentation
# colour commands have no special bypass here. Provider results append once.
const Rich=preload("res://systems/native_data/rich_text.gd")
const Encoding=preload("res://systems/native_data/native_text_encoding.gd")
static func pending(reason: String) -> Dictionary:return {"ready":false,"pending":true,"reason":reason}
static func encode(value: String,language: int=0) -> Dictionary:return Encoding.encode(value,language)
static func hash_bytes(bytes: PackedByteArray,limit: int=2147483647) -> int:
	var value:=0
	for at in mini(bytes.size(),limit):
		if bytes[at]==0:break
		var word: int=(value^bytes[at])&255
		for bit in 8:word=(word>>1)^(0xedb88320 if word&1 else 0)
		value=(word^(value>>8))&4294967295
	return value
static func assigned(bytes: PackedByteArray) -> PackedByteArray:
	return PackedByteArray() if not bytes.is_empty() and bytes[0]==0 else bytes.duplicate()
static func value_bytes(value: Variant,language: int=0) -> Dictionary:
	if value is PackedByteArray:return {"ready":true,"bytes":assigned(value)}
	if value is Dictionary and value.get("bytes") is Array:
		var bytes:=PackedByteArray()
		for byte in value.bytes:
			if not (byte is int or byte is float) or not is_finite(float(byte)) or floorf(float(byte))!=float(byte) or byte<0 or byte>255:return pending("Native talk byte projection is malformed.")
			bytes.append(int(byte))
		return {"ready":true,"bytes":assigned(bytes)}
	if value is String:
		var encoded:=encode(value,language)
		if encoded.get("ready",false):encoded.bytes=assigned(encoded.bytes)
		return encoded
	return pending("Native talk replacement bytes are unavailable.")
static func find_record(rows: Array,key: int,field: String) -> Dictionary:
	var low:=0;var high:=rows.size()
	while low<high:
		var middle: int=(low+high)>>1;var row: Variant=rows[middle]
		if not row is Dictionary:return {}
		var current: int=int(row.get(field,-1))&4294967295
		if current>key:high=middle
		elif current<key:low=middle+1
		else:return row
	return {}
static func parse(input: PackedByteArray,state: Dictionary,providers: Dictionary) -> Dictionary:
	state.suppression=0
	var end:=input.find(0)
	if end<0:end=input.size()
	var output:=PackedByteArray();var at:=0;var segment:=0;var changed:=false
	var unknown: PackedByteArray="<UNRECOGNIZED TOKEN>".to_ascii_buffer()
	while at<end:
		if input[at]!=60:at+=1;continue
		if at+1<end and input[at+1]==60:
			if int(state.suppression)==0:output.append_array(input.slice(segment,at+1))
			at+=2;segment=at;changed=true;continue
		if int(state.suppression)==0:output.append_array(input.slice(segment,at))
		var close:=at+1
		while close<end and input[close]!=62:close+=1
		if close==end:return {"ready":false,"reason":"Native unterminated talk token has no certified string-buffer boundary."}
		var name:=input.slice(at+1,close);var replacement:=unknown
		if name.size()>6 and name.slice(0,6)=="CUSTOM".to_ascii_buffer():
			var key:=0;var place:=1;var valid:=true
			for index in range(name.size()-1,5,-1):
				var digit: int=name[index]-48
				if digit<0 or digit>9:valid=false;break
				key=(key+digit*place)&4294967295;place=(place*10)&4294967295
			if valid and key!=4294967295:
				if providers.get("customReady")!=true:return pending("Native receipt custom-token state is unavailable.")
				var custom: Variant=providers.get("custom");var selected: Dictionary={};var found:=false;var value: Variant
				if custom is Dictionary:found=custom.has(key);value=custom.get(key)
				elif custom is Array:selected=find_record(custom,key,"id");found=not selected.is_empty();value=selected.get("bytes")
				else:return pending("Native receipt custom-token records are unavailable.")
				if found:
					var encoded:=value_bytes(value,int(providers.get("language",0)))
					if not encoded.get("ready",false):return encoded
					replacement=encoded.bytes
		elif not name.is_empty():
			if providers.get("namedReady")!=true:return pending("Native StringTokens metadata is unavailable.")
			var rows: Variant=providers.get("named")
			if not rows is Array:return pending("Native StringTokens records are unavailable.")
			var token:=find_record(rows,hash_bytes(name),"hash")
			if not token.is_empty():
				var token_name:=value_bytes(token.get("name"))
				if not token_name.get("ready",false):return token_name
				if token_name.bytes==name:
					var resolver: Variant=providers.get("resolve")
					if not resolver is Callable or not resolver.is_valid():return pending("Native named-token provider is unavailable.")
					var resolved: Variant=resolver.call(token,state)
					if not resolved is Dictionary or not resolved.get("ready",false):return resolved if resolved is Dictionary else pending("Native named-token provider returned no value.")
					if resolved.has("bytes"):
						var encoded:=value_bytes(resolved.bytes)
						if not encoded.get("ready",false):return encoded
						replacement=encoded.bytes
		output.append_array(replacement);at=close+1;segment=at;changed=true
	if not changed:return {"ready":true,"bytes":input.duplicate(),"suppression":int(state.suppression)}
	if segment<end and int(state.suppression)==0:output.append_array(input.slice(segment,end))
	return {"ready":true,"bytes":assigned(output),"suppression":int(state.suppression)}
