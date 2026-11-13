extends RefCounted
# Private Appearance dialog state. No world/draft mutation or asset scanning.
# Original8e0eb0/8e0f50,8e2ce0/8e2d30 and8e7a40/8e7bc0.
const TATTOO_ENABLED=[false,false,true,true,false,false,false,true,false,false,true,true,true,true,false,false,false,false,false]
const Math=preload("res://systems/native_render/particle_math.gd")
var source:Dictionary={}
var value:Dictionary={}
var failure:=""
func reset(context:Dictionary)->void:
	source=context.duplicate(true);value=context.get("value",{}).duplicate(true);failure=""
static func whole(value:Variant,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and int(value)==value
static func phenotype_step(current:int,mask:int,direction:int)->Dictionary:
	if current<0 or current>255 or direction not in [-1,1]:return {"available":false,"reason":"Unknown native BYTE/direction"}
	mask&=0xffffffff
	var candidate:=current+1 if direction>0 else (31 if current==0 else current-1)
	# Nonempty masks terminate within this BYTE-domain bound. An empty mask
	# and an out-of-range current BYTE can loop forever in the original; return
	# explicit unavailability instead of hanging the client on malformed data.
	for iteration in 512:
		if direction<0 and candidate==current:return {"available":true,"value":current}
		if (mask>>(candidate&31))&1:return {"available":true,"value":candidate&255}
		candidate=(candidate+1)&31 if direction>0 else (31 if candidate==0 else candidate-1)
		if direction>0 and candidate==current:return {"available":true,"value":current}
	return {"available":false,"reason":"Original phenotype loop has no terminating choice"}
static func head_step(current:int,exists:Dictionary,direction:int)->Dictionary:
	if current<0 or current>65535 or direction not in [-1,1]:return {"available":false,"reason":"Unknown native WORD/direction"}
	var candidate:=(current+direction)&65535
	if exists.has(candidate):return {"available":true,"value":candidate}
	if direction>0:return {"available":true,"value":1}
	candidate=(candidate+1)&65535
	for iteration in 65536:
		if not exists.has(candidate):return {"available":true,"value":(candidate-1)&65535}
		candidate=(candidate+1)&65535
	return {"available":false,"reason":"Original head loop has no missing resource"}
static func tattoo_parts(pattern:int,parts:Array)->Dictionary:
	if pattern<0 or pattern>15 or parts.size()!=19 or not parts.all(func(part):return whole(part,65535)):return {"available":false,"reason":"Unknown native tattoo pattern/body parts"}
	var skin:Array=[]
	for index in 19:
		var part:=1
		if index==7:part=1+int((pattern&1)!=0)
		elif index in [12,13]:part=1+int((pattern&2)!=0)
		elif index in [2,3]:part=1+int((pattern&4)!=0)
		elif index in [10,11]:part=1+int((pattern&8)!=0)
		if index in [8,14,15,18]:part=0
		skin.append(part)
	var actual:=parts.duplicate()
	for index in 19:
		if int(actual[index])<3 and TATTOO_ENABLED[index]:actual[index]=skin[index]
	return {"available":true,"parts":actual,"skinParts":skin,"pattern":pattern}
func editable(kind:String)->bool:
	# CompareNoCase16ae00 returns BOOL equality, not a strcmp ordering. The
	# original177c flag is true for a non-P model and disables these controls.
	if source.get("appearanceValid")!=true or not source.get("modelType") is String or str(source.modelType).to_upper()!="P":return false
	return kind!="clothes" or source.get("customizeMode")==0
func step(kind:String,direction:int)->bool:
	failure=""
	if direction not in [-1,1] or not editable(kind):return false
	var result:Dictionary={}
	match kind:
		"body":
			var mask:Variant=source.get("enabledPhenotypes")
			if not whole(value.get("phenotype"),255) or not (mask is int or mask is float) or not is_finite(float(mask)) or mask< -2147483648 or mask>4294967295 or int(mask)!=mask:return false
			result=phenotype_step(int(value.phenotype),int(source.enabledPhenotypes),direction)
			if result.available:value.phenotype=result.value
		"head":
			if not whole(value.get("head"),65535) or source.get("headIndexComplete")!=true or not source.get("heads") is Dictionary:return false
			result=head_step(int(value.head),source.heads,direction)
			if result.available:value.head=result.value
		"tattoo":
			if not whole(value.get("tattooPattern"),15) or not value.get("bodyParts") is Array:return false
			result=tattoo_parts((int(value.tattooPattern)+direction+16)%16,value.bodyParts)
			if result.available:value.bodyParts=result.parts;value.skinParts=result.skinParts;value.tattooPattern=result.pattern
		"clothes":
			var choices:Variant=source.get("clothing")
			if not choices is Array or choices.is_empty() or not whole(value.get("clothingIndex"),choices.size()-1):return false
			var selected: int=(int(value.clothingIndex)+direction+choices.size())%choices.size();var choice:Variant=choices[selected]
			if not choice is Dictionary or not choice.get("bodyParts") is Array or choice.bodyParts.size()!=19 or not choice.bodyParts.all(func(part):return whole(part,65535)) or not choice.get("colors") is Array or choice.colors.size()!=6 or not choice.colors.all(func(color):return whole(color,255)) or not whole(choice.get("id"),2147483647) or not choice.get("resRef") is String:return false
			if not value.get("skinParts") is Array or value.skinParts.size()!=19 or not value.skinParts.all(func(part):return whole(part,65535)):return false
			var parts:Array=choice.bodyParts.duplicate()
			for part in 19:
				if int(parts[part])==1 and TATTOO_ENABLED[part]:parts[part]=value.skinParts[part]
			value.clothingIndex=selected;value.clothes=choice.id;value.clothingResRef=choice.resRef;value.bodyParts=parts;value.materialColors=choice.colors.duplicate();result={"available":true}
		_:return false
	if not result.get("available",false):failure=str(result.get("reason","Appearance data unavailable"));return false
	return true
func color(field:String,index:int)->bool:
	if field not in ["skin","hair","tattoo1","tattoo2"] or not editable(field):return false
	var count:Variant=source.get("paletteSizes",{}).get(field)
	if not whole(count,65535) or index<0 or index>=mini(int(count),256):return false
	value[field]=index;return true
static func palette_index(world_delta:Vector2,rows:int=11)->Variant:
	# Original8e3170 uses binary32 divide/add, CVTTSS2SI and signed truncating
	# division16. In particular, a small negative coordinate is not floor(-x).
	if not world_delta.is_finite() or rows<1 or rows>16:return null
	var x:=int(Math.f(Math.f(Math.f(world_delta.x)/Math.f(.01))+Math.f(.5)))
	var y:=int(Math.f(Math.f(Math.f(world_delta.y)/Math.f(.01))+Math.f(.5)))
	var column:=(x+((x>>31)&15))>>4;var row:=rows-((y+((y>>31)&15))>>4)-1
	return column+row*16 if column>=0 and column<16 and row>=0 and row<rows else null
func snapshot()->Dictionary:return value.duplicate(true)
