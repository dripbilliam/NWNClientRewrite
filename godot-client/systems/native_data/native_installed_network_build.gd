extends RefCounted
const TARGET_SHA256:="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const PLATFORM_KEY_RVA:=0x140bab8

class BuildIdentity:
	extends RefCounted
	var target: String=""
	var platformId:=2
	var build: Dictionary={}
	var key:=PackedByteArray()
	var disposed:=false
	func _init(platform_key: PackedByteArray,target_hash: String,build_data: Dictionary)->void:
		key=platform_key.duplicate()
		target=target_hash
		build=build_data.duplicate(true)
	func platform_identifier(crypto: RefCounted)->Dictionary:
		if disposed:return {"error":"Native build identity is disposed"}
		return await crypto.platform_identity(2,key)
	func platformIdentifier(crypto: RefCounted)->Dictionary:
		return await platform_identifier(crypto)
	func dispose()->void:
		if disposed:return
		key.fill(0)
		disposed=true
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE and not disposed:key.fill(0)

static func read(install: String,crypto: RefCounted=null)->Dictionary:
	var executable:=install.path_join("bin/win32/nwmain.exe")
	var bytes:=FileAccess.get_file_as_bytes(executable)
	if bytes.size()<0x1000:return {"error":"Unsupported native network client build"}
	var hash:=HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256)!=OK or hash.update(bytes)!=OK:return {"error":"Unsupported native network client build"}
	if hash.finish().hex_encode()!=TARGET_SHA256:return {"error":"Unsupported native network client build"}
	var pe: int=bytes.decode_u32(0x3c)
	if pe<0 or pe+24>bytes.size():return {"error":"Unsupported native network client build"}
	var sections: int=bytes.decode_u16(pe+6)
	var table: int=pe+24+bytes.decode_u16(pe+20)
	if sections<1 or sections>96 or table+sections*40>bytes.size():return {"error":"Unsupported native network client build"}
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
		if offset+delta+count>bytes.size():
			platform_key.fill(0)
			return {"error":"Native platform key storage is unavailable"}
		for n in range(count):platform_key[n]=bytes[offset+delta+n]
		found=true
		break
	if not found:return {"error":"Native platform key storage is unavailable"}
	var version_at: int=-1
	for index in range(bytes.size()-3):
		if bytes[index]==0xbd and bytes[index+1]==4 and bytes[index+2]==0xef and bytes[index+3]==0xfe:
			if version_at>=0:
				platform_key.fill(0)
				return {"error":"Native file version is ambiguous"}
			version_at=index
	if version_at<0 or version_at+16>bytes.size():
		platform_key.fill(0)
		return {"error":"Native file version is ambiguous"}
	var ms: int=bytes.decode_u32(version_at+8)
	var ls: int=bytes.decode_u32(version_at+12)
	bytes.fill(0)
	var build_file:=FileAccess.get_file_as_string(install.path_join("bin/win32/build.txt")).strip_edges()
	var commit: String=""
	for character in build_file:
		var code: int=character.unicode_at(0)
		if code in [9,10,11,12,13,32,160,5760,8232,8233,8239,8287,12288,65279] or code>=8192 and code<=8202:
			if commit.is_empty():continue
			break
		commit+=character
	if commit.length()!=40:
		platform_key.fill(0)
		return {"error":"Native build commit is unavailable"}
	for character in commit:
		if character not in "0123456789abcdef":
			platform_key.fill(0)
			return {"error":"Native build commit is unavailable"}
	var build_data: Dictionary={"number":ms & 65535,"revision":ls >> 16,"postfix":ls & 65535,"commit":commit.substr(0,8)}
	var identity:=BuildIdentity.new(platform_key,TARGET_SHA256,build_data)
	platform_key.fill(0)
	var result: Dictionary={"target":identity.target,"platformId":identity.platformId,"build":identity.build,"identityOwner":identity}
	# The current Session requests metadata before closing its crypto owner.
	# Keep that caller working while the deferred owner/disposal handoff is wired.
	if crypto!=null:
		var platform: Dictionary=await identity.platform_identifier(crypto)
		if not platform.has("identity"):
			identity.dispose()
			return {"error":platform.get("error","Native platform identity is unavailable")}
		result.platformIdentifier=platform.identity
	return result
