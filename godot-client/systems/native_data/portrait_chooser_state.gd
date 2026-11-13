extends RefCounted
# CGuiPortraitSelect9d1350/9d28d0: pooled physical buttons, not page rebuilds.
const COLUMNS:=6
const POOL:=24
const PAGE_CHOICES:=18
const ROW_UNITS:=107
const VISIBLE_UNITS:=321
var choices: Array=[]
var selected:=""
var position:=0
static func scroll_range(count: int) -> int:
	return (maxi(0,count)/PAGE_CHOICES)*VISIBLE_UNITS+1
func reset(values: Array,current: String) -> bool:
	choices=values.duplicate(); selected=""; position=0
	var index:=choices.find(current.to_lower().left(16))
	if index<0: return false
	selected=str(choices[index]); position=(index/PAGE_CHOICES)*VISIBLE_UNITS
	return true
func scroll(value: int) -> void:
	position=clampi(value,0,scroll_range(choices.size())-1)
func slots() -> Array:
	var out: Array=[]; var first: int=(position/ROW_UNITS)*COLUMNS
	for slot in mini(POOL,choices.size()):
		var index:=first+slot; var base:=str(choices[index]) if index<choices.size() else ""
		out.append({"index":index,"base":base,"selected":not base.is_empty() and base==selected})
	return out
func choose(slot: int) -> bool:
	var index: int=(position/ROW_UNITS)*COLUMNS+slot
	if slot<0 or slot>=mini(POOL,choices.size()) or index>=choices.size(): return false
	selected=str(choices[index]); return true
func can_accept() -> bool: return not selected.is_empty() and choices.has(selected)
func preview() -> String: return selected if can_accept() else "gui_po_nwnlogo_"
