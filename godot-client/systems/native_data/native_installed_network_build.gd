extends RefCounted
const TARGET_SHA256:="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const PLATFORM_KEY_RVA:=0x140bab8

static func read(install: String,crypto: RefCounted)->Dictionary:
	var executable:=install.path_join("bin/win32/nwmain.exe")
	var bytes:=FileAccess.get_file_as_bytes(executable)
	if bytes.size()<0x1000:return {"error":"Original NWN executable is unavailable"}
	var hash:=HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256)!=OK or hash.update(bytes)!=OK:return {"error":"Original NWN build verification failed"}
	if hash.finish().hex_encode()!=TARGET_SHA256:return {"error":"Unsupported original NWN network client build"}
	var pe: int=bytes.decode_u32(0x3c)
	if pe<0 or pe+24>bytes.size():return {"error":"Invalid original NWN PE header"}
	var sections: int=bytes.decode_u16(pe+6)
	var table: int=pe+24+bytes.decode_u16(pe+20)
	if sections<1 or sections>96 or table+sections*40>bytes.size():return {"error":"Invalid original NWN section table"}
	var platform_key:=PackedByteArray();platform_key.resize(32)
	var found:=false
	for index in range(sections):
		var at: int=table+index*40
		var virtual_size: int=bytes.decode_u32(at+8)
		var rva: int=bytes.decode_u32(at+12)
		var size: int=bytes.decode_u32(at+16)
		var offset: int=bytes.decode_u32(at+20)
		if PLATFORM_KEY_RVA<rva or PLATFORM_KEY_RVA+32>rva+maxi(virtual_size,size):continue
		var delta: int=PLATFORM_KEY_RVA-rva
		var count: int=mini(32,maxi(0,size-delta))
		if offset+delta+count>bytes.size():return {"error":"Original NWN platform identity storage is truncated"}
		for n in range(count):platform_key[n]=bytes[offset+delta+n]
		found=true
		break
	if not found:return {"error":"Original NWN platform identity storage is unavailable"}
	var version_at: int=-1
	for index in range(bytes.size()-16):
		if bytes[index]==0xbd and bytes[index+1]==4 and bytes[index+2]==0xef and bytes[index+3]==0xfe:
			if version_at>=0:return {"error":"Original NWN file version is ambiguous"}
			version_at=index
	if version_at<0:return {"error":"Original NWN file version is unavailable"}
	var ms: int=bytes.decode_u32(version_at+8)
	var ls: int=bytes.decode_u32(version_at+12)
	bytes.fill(0)
	var build_file:=FileAccess.get_file_as_string(install.path_join("bin/win32/build.txt"))
	var parts:=build_file.strip_edges().split(" ",false)
	if parts.is_empty():return {"error":"Original NWN build commit is unavailable"}
	var commit: String=parts[0].split("\n",false)[0].split("\t",false)[0]
	if commit.length()!=40:return {"error":"Original NWN build commit is unavailable"}
	for character in commit:
		if character not in "0123456789abcdef":return {"error":"Original NWN build commit is unavailable"}
	var platform: Dictionary=crypto.platform_identity(2,platform_key)
	platform_key.fill(0)
	if not platform.has("identity"):return {"error":platform.get("error","Original NWN platform identity is unavailable")}
	return {"target":TARGET_SHA256,"platformId":2,"platformIdentifier":platform.identity,"build":{"number":ms & 65535,"revision":ls >> 16,"postfix":ls & 65535,"commit":commit.substr(0,8)}}
