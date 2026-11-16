extends SceneTree
const Store=preload("res://systems/native_data/native_network_store.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-store-observations.json")
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not oracle is Dictionary or oracle.get("cases",[]).size()!=80:fail("Original store writer oracle unavailable");return
	var open_count:=0;var transaction_count:=0;var sender_count:=0;var malformed:=0
	for row in oracle.cases:
		var native:=str(row.packet).hex_decode()
		if row.kind=="open":
			var decoded: Dictionary=Store.decode_packet(native,int(row.format))
			if decoded.has("error") or decoded.kind!="store-open" or decoded.panel!=2 or decoded.sellRate!=int(row.sellRate) or decoded.buyRate!=37 or decoded.blackMarketRate!=20 or decoded.identifyPrice!=100 or decoded.maxBuyPrice!=25000 or decoded.gold!=-1 or decoded.blackMarket!=int(bool(row.blackMarket)) or decoded.restricted!=int(bool(row.restricted)) or decoded.baseItems!=[1,255]:fail("Original store-open fields differ format="+str(row.format));return
			open_count+=1
			for end in range(3,native.size()):
				if not Store.decode_packet(native.slice(0,end),int(row.format)).has("error"):fail("Truncated store open admitted");return
			malformed+=native.size()-3
		elif row.kind=="transaction":
			var decoded: Dictionary=Store.decode_packet(native,int(row.format))
			var expected: int=int(row.itemId)
			if expected!=Store.INVALID:expected|=0x80000000
			if decoded.has("error") or decoded.kind!="store-transaction" or decoded.itemId!=expected or decoded.gold!=-1 or decoded.has("success"):fail("Original store transaction implied success or changed identity");return
			transaction_count+=1
		elif int(row.format)==1:
			var result: Dictionary=Store.request(str(row.kind),int(row.itemId),255,6,0xffffffff,3,3)
			if result.has("error") or result.bytes.size()!=native.size():fail("Original store client request rejected or changed length: "+str(row.kind));return
			if row.kind=="close":
				if result.bytes!=native:fail("Original store close differs");return
			elif result.bytes.slice(0,-1)!=native.slice(0,-1) or (result.bytes[-1]&(0xff<<(8-(native[-1]>>5))))!=(native[-1]&(0xff<<(8-(native[-1]>>5)))):fail("Original store request bytes differ: "+str(row.kind));return
			sender_count+=1
	if open_count!=24 or transaction_count!=8 or sender_count!=24 or Store.decode_packet(PackedByteArray([80,7,6])).kind!="store-close" or not Store.decode_packet(PackedByteArray([80,7,6,0])).has("error") or not Store.request("buy",-1).has("error") or not Store.request("page",-1,255,255,Store.INVALID,-1,256).has("error") or not Store.request("open").has("error"):fail("Store protocol fixture counts or validation differ");return
	print("NWN79 Godot store packet PASS: native-open=24 transaction=8 writer=24 malformed="+str(malformed))
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot store packet failed: "+reason)
	quit(1)
