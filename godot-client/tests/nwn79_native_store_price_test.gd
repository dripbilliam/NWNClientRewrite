extends SceneTree
const Inventory=preload("res://systems/native_inventory.gd")

func _initialize()->void:
	var inventory:=Inventory.new();inventory.store={"open":true,"sellRate":150,"buyRate":37,"blackMarketRate":20,"maxBuyPrice":-1}
	var cases: Array=[
		[{"cost":123},true,184],
		[{"cost":123},false,45],
		[{"cost":123,"field458":1},false,24],
		[{"cost":1},false,1],
		[{"cost":0},true,0]]
	for row in cases:
		if inventory.store_price(row[0],row[1])!=row[2]:fail("Original store price baseline differs");return
	inventory.store.maxBuyPrice=20
	if inventory.store_price({"cost":123},false)!=20:fail("Original positive store cap differs");return
	inventory.store.maxBuyPrice=-1;inventory.store.sellRate=-1
	if inventory.store_price({"cost":100},true)!=4294967295:fail("Original unsigned negative-rate conversion differs");return
	inventory.store.sellRate=150;inventory.store.maxBuyPrice=-2
	if inventory.store_price({"cost":123},false)!=4294967294:fail("Original signed maximum price comparison differs");return
	inventory.store.maxBuyPrice=-1;inventory.store.sellRate=32767
	if inventory.store_price({"cost":4294967295},true)!=2877627760:fail("Original high-cost uint32 price differs");return
	inventory.free()
	print("NWN79 Godot store price PASS: 9 original-oracle cases including unsigned wrap and signed cap")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot store price failed: "+reason)
	quit(1)
