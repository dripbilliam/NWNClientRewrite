extends RefCounted
# Original CPlayModuleUpDownKeyHackControl710a90 and callback70f3c0.
static func direction(key: int) -> int:
	return -1 if key in [0x125,0x126] else 1 if key in [0x127,0x128] else 0
static func move(selected: int,count: int,delta: int,scroll: int,row_height: int,viewport_height: int) -> Dictionary:
	if count<=0 or delta==0: return {"index":selected,"scroll":null}
	var index:=maxi(0,mini(selected+delta,count-1)); var request: Variant=null
	if viewport_height+scroll<(index+1)*row_height-1 or index*row_height-1<scroll: request=maxi(0,scroll+row_height*delta)
	return {"index":index,"scroll":request}
