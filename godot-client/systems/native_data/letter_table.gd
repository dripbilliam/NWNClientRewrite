extends RefCounted
# CResLTR::OnResourceServiced236810. Flat owned binary32 storage replaces
# pointer forests; byte order and per-prefix start/middle/end order stay native.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<9 or bytes.slice(0,8).get_string_from_ascii()!="LTR V1.0":return {"ready":false,"reason":"Invalid original LTR header."}
	var count:=int(bytes[8]);var values:=3*(count+count*count+count*count*count);var needed:=9+values*4
	if bytes.size()<needed:return {"ready":false,"reason":"Original LTR probability data is truncated."}
	return {"ready":true,"count":count,"values":bytes.slice(9,needed).to_float32_array(),"consumedBytes":needed}
static func valid(table: Dictionary) -> bool:
	var count: Variant=table.get("count");var values: Variant=table.get("values")
	return table.get("ready")==true and count is int and count>=0 and count<=255 and values is PackedFloat32Array and values.size()==3*(count+count*count+count*count*count)
static func offset(count: int,order: int,mode: int,left: int=0,right: int=0) -> int:
	if order==1:return mode*count
	if order==2:return 3*count+left*3*count+mode*count
	return 3*(count+count*count)+(left*count+right)*3*count+mode*count
