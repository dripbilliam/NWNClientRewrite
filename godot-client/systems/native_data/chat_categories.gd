extends RefCounted
# Original77c140 speech categories and8793c0/879560 pane masks.
const ALL:=0xffffffff
const LEFT:=0x74f
const RIGHT:=0x100000b0
const COMBAT:=0x80
const SERVER:=0x20
const NOTICE:=0x10000000
const ENTRIES=[
	{"slot":1,"bit":0x40,"icon":"ir_partychat","include":1399,"exclude":1400},
	{"slot":2,"bit":0x20,"icon":"ir_servermsg","include":1397,"exclude":1398},
	{"slot":3,"bit":0x400,"icon":"ir_dmchat","include":67572,"exclude":67573},
	{"slot":4,"bit":1,"icon":"ir_chat","include":67574,"exclude":67575},
	{"slot":5,"bit":0x80,"icon":"ir_cmbtinfo","include":1407,"exclude":1408},
	{"slot":6,"bit":4,"icon":"ir_shouts","include":1394,"exclude":1395}]
static func speech(channel: int) -> int:
	# DM talk/shout/whisper/tell/party override their ordinary categories.
	if channel in [17,18,19,20,22]: return 0x400
	if channel in [1,8,11,12]: return 1
	if channel in [2,9,14,30]: return 4
	if channel in [3,10]: return 8
	if channel==4: return 2
	if channel in [5,15]: return SERVER
	if channel==6: return 0x40
	return 0
static func bits(row: Dictionary) -> int:
	if row.has("chat_mask"): return int(row.chat_mask)&ALL
	if row.has("channel"): return speech(int(row.channel))
	var category:=str(row.get("category",""))
	if category.contains("-feedback"): return COMBAT
	return SERVER if row.get("system",false) else 1
static func mask(settings: Dictionary,index: int) -> int:
	return int(settings["mask_right" if index==1 else "mask_left" if settings.split else "mask_combined"])
static func menu(text,settings: Dictionary,index: int) -> Array:
	var combined:=not bool(settings.split); var value:=mask(settings,index)
	var result: Array=[{"slot":0,"icon":"ir_chatcombine" if combined else "ir_chatsplit","label":text.raw({"strRef":1405 if combined else 1406}),"bit":0}]
	for source in ENTRIES:
		var row: Dictionary=source.duplicate(); row.label=text.raw({"strRef":int(source.exclude) if value&int(source.bit) else int(source.include)}); result.append(row)
	return result
