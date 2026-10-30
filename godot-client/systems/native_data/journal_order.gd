extends RefCounted
# Original journal index ordering7d6cd0, comparators7d6830/69c0/6c30.
const Rich=preload("res://systems/native_data/rich_text.gd")
static func date_compare(a: Dictionary,b: Dictionary,day_length: int) -> int:
	var at:=int(a.get("time",0))&0xffffffff; var bt:=int(b.get("time",0))&0xffffffff
	if at>=(day_length&0xffffffff) or bt>=(day_length&0xffffffff): return -2
	var ad:=int(a.get("date",0))&0xffffffff; var bd:=int(b.get("date",0))&0xffffffff
	if ad==bd: return 1 if at>bt else -1 if at<bt else 0
	return 1 if ad>bd else -1
static func text_compare(a: String,b: String) -> int:
	# CExoLocString is resolved before the original unsigned-byte comparison.
	# Preserve case and legacy code-page ordering, including CP1252 high bytes.
	for at in maxi(a.length(),b.length())+1:
		var av:=Rich.byte_value(a.unicode_at(at)) if at<a.length() else 0
		var bv:=Rich.byte_value(b.unicode_at(at)) if at<b.length() else 0
		if av!=bv: return 1 if av<bv else -1
		if av==0: return 0
	return 0
static func compare(a: Dictionary,b: Dictionary,mode: int,day_length: int) -> int:
	if mode==1: return text_compare(str(a.get("sortTitle","")),str(b.get("sortTitle","")))
	if mode==2:
		var ap:=int(a.get("priority",0))&0xffffffff; var bp:=int(b.get("priority",0))&0xffffffff
		if ap!=bp: return -1 if ap>bp else 1
	return date_compare(a,b,day_length)
static func indices(entries: Array,mode: int,day_length: int) -> Array[int]:
	var result: Array[int]=[]
	for at in entries.size(): result.append(at)
	# The original selection-sort exchanges also define equal-key ordering.
	# Do not substitute a comparator sort with unrelated tie behavior.
	for first in result.size():
		var selected:=first
		for next in range(first+1,result.size()):
			if compare(entries[result[selected]],entries[result[next]],mode,day_length)<0: selected=next
		var saved: int=result[first]; result[first]=result[selected]; result[selected]=saved
	return result
