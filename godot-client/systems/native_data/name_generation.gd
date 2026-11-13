extends RefCounted
# Original2359b0 with explicit captured RNG/filter inputs. No catalog, worker,
# live draft, global RNG state or invented name is owned by this pure generator.
const Letters=preload("res://systems/native_data/letter_table.gd")
const ALPHABET="abcdefghijklmnopqrstuvwxyz'-"
var draw:=Callable()
var count:=0
var limit:=0
var failed:=""
static func binary32(value: float) -> float:return PackedFloat32Array([value])[0]
func random_value() -> int:
	if not failed.is_empty():return 0
	if count>=limit:failed="The native name probability/RNG budget was exhausted.";return 0
	count+=1
	var value: Variant=draw.call()
	if not value is int or value<0 or value>32767:failed="The native name RNG sample is unavailable.";return 0
	return value
func choose(table: Dictionary,order: int,mode: int,sample: int,left: int=0,right: int=0) -> int:
	var size: int=table.count;var start:=Letters.offset(size,order,mode,left,right);var probability:=binary32(float(sample)/32767.0)
	for index in size:
		if probability<float(table.values[start+index]):return index
	return size
func candidate(table: Dictionary) -> String:
	var size: int=table.count;var output: Array=[];var restart:=true;var backtracks:=0
	while failed.is_empty():
		if restart:
			backtracks=0
			var first:=choose(table,1,0,random_value())
			if first>=size:continue
			var second:=choose(table,2,0,random_value(),first)
			if second>=size:continue
			var third:=choose(table,3,0,random_value(),first,second)
			if third>=size:continue
			output=[first,second,third];restart=false
		var sample:=random_value();var end_chance:=random_value();var next:=size;var ending:=false
		var left: int=output[-2];var right: int=output[-1]
		if end_chance%12<=output.size():
			next=choose(table,3,2,sample,left,right);ending=next<size
		if not ending:next=choose(table,3,1,sample,left,right)
		if next<size:
			if output.size()>=63:failed="The original name buffer limit was exceeded.";break
			output.append(next)
			if ending:
				var name:=""
				for index in output:name+=ALPHABET[index]
				return name.left(1).to_upper()+name.substr(1)
		elif output.size()<4 or backtracks>99:restart=true
		else:output.pop_back();backtracks+=1
	return ""
func generate(table: Dictionary,rng: Callable,filter_names: Variant,sample_limit: int=100000) -> Dictionary:
	count=0;limit=sample_limit;failed="";draw=rng
	if not Letters.valid(table) or table.count<1 or table.count>ALPHABET.length():failed="The native name alphabet is unavailable."
	elif not rng.is_valid() or sample_limit<1:failed="The native name RNG is unavailable."
	elif not filter_names is Array or filter_names.any(func(name):return not name is String):failed="The active native name-filter result is unavailable."
	while failed.is_empty():
		var name:=candidate(table)
		if not failed.is_empty():break
		# Original CExoString::CompareNoCase is a boolean equality helper.
		if filter_names.any(func(value):return str(value).nocasecmp_to(name)==0):continue
		draw=Callable();return {"ready":true,"name":name,"draws":count}
	draw=Callable();return {"ready":false,"reason":failed,"draws":count}
