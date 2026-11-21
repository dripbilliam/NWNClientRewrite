extends RefCounted
# Direct client-mode projection of game_object_array.js. Status 1 is BAD_ID;
# status 4 is NULL_OBJECT. The two bucket halves retain the full external bit.
const OBJECT_INVALID:=0x7f000000
const EXTERNAL_OBJECT:=0x80000000
const GAME_OBJECT_TYPE:={"module":3,"area":4,"creature":5,"player":5,"item":6,"trigger":7,"projectile":8,"placeable":9,"door":10,"areaOfEffect":11,"waypoint":12,"encounter":13,"store":14,"portal":15,"sound":16}
const OBJECT_ARRAY_RESULT:={"SUCCESS":0,"BAD_ID":1,"NULL_OBJECT":4}
var client_mode:=true
var cache_size:=65536
var buckets:Array=[]
var next_object_id:Array=[0,0]
var next_character_id:Array=[0x7fffffff,0x7fffffff]
var objects:Dictionary={}
var init_error:Variant=null

static func uint32(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=0xffffffff

func _init(options: Dictionary={}) -> void:
	var bits:Variant=options.get("cacheBits",16)
	if not uint32(bits) or bits<1 or bits>20:
		init_error="Invalid object cache size"
		return
	client_mode=bool(options.get("clientMode",true))
	cache_size=1<<int(bits)
	buckets.resize(cache_size*(2 if client_mode else 1))
	buckets.fill(null)

func bucket(id: int) -> int:
	return id%cache_size+(cache_size if id>=EXTERNAL_OBJECT else 0)

func get_game_object(id: Variant) -> Dictionary:
	if not uint32(id) or bucket(int(id))>=buckets.size():return {"status":1,"object":null}
	var node:Variant=buckets[bucket(int(id))]
	while node!=null:
		if node.id==(int(id)&0x7fffffff):return {"status":0,"object":node.object}
		node=node.next
	return {"status":1,"object":null}

func lookup(id: Variant) -> Variant:
	return get_game_object(id).object

func insert(id: int,object: Variant) -> Dictionary:
	var slot:int=bucket(id)
	var stripped:int=id&0x7fffffff
	var node:Dictionary={"id":stripped,"object":object,"next":null}
	var previous:Variant=null
	var current:Variant=buckets[slot]
	while current!=null and int(current.id)>stripped:
		previous=current
		current=current.next
	node.next=current
	if previous!=null:previous.next=node
	else:buckets[slot]=node
	if object is Dictionary:object.id=id
	elif object is Object:object.set("id",id)
	objects[id]=object
	return {"status":0,"id":id,"object":object}

func add_internal_object(object: Variant,options: Dictionary={}) -> Dictionary:
	if object==null or (object is bool and not object):return {"status":4,"id":OBJECT_INVALID}
	var object_id:Variant=object.get("id") if object is Dictionary or object is Object else null
	if uint32(object_id) and lookup(object_id)!=null:return {"status":1,"id":OBJECT_INVALID}
	var character_object:bool=bool(options.get("characterObject",false))
	var id:int=int(next_character_id[0]) if character_object else int(next_object_id[0])
	if (id<=0x7f000001 if character_object else id>=0x7effffff) or lookup(id)!=null:
		return {"status":1,"id":OBJECT_INVALID}
	if character_object:next_character_id[0]-=1
	else:next_object_id[0]+=1
	return insert(id,object)

func add_external_object(id: Variant,object: Variant) -> Dictionary:
	if object==null or (object is bool and not object):return {"status":4,"id":OBJECT_INVALID}
	if not uint32(id) or not client_mode or lookup(id)!=null:return {"status":1,"id":OBJECT_INVALID}
	var external_id:int=((int(id)&0x7fffffff)|EXTERNAL_OBJECT)&0xffffffff
	return add_object_at_pos(external_id,object)

func add_object_at_pos(id: Variant,object: Variant) -> Dictionary:
	if object==null or (object is bool and not object):return {"status":4,"id":OBJECT_INVALID}
	if not uint32(id) or bucket(int(id))>=buckets.size() or lookup(id)!=null:return {"status":1,"id":OBJECT_INVALID}
	var stripped:int=int(id)&0x7fffffff
	var half:int=1 if int(id)>=EXTERNAL_OBJECT else 0
	if (stripped&0x7f000000)!=0:
		if stripped<0x7f000001:return {"status":1,"id":OBJECT_INVALID}
		next_character_id[half]=mini(int(next_character_id[half]),stripped-1)
	else:
		next_object_id[half]=maxi(int(next_object_id[half]),stripped+1)
	return insert(int(id),object)

func remove(id: Variant) -> Dictionary:
	if not uint32(id) or bucket(int(id))>=buckets.size():return {"status":1,"object":null}
	var slot:int=bucket(int(id))
	var previous:Variant=null
	var node:Variant=buckets[slot]
	while node!=null and int(node.id)!=(int(id)&0x7fffffff):
		previous=node
		node=node.next
	if node==null:return {"status":1,"object":null}
	if previous!=null:previous.next=node.next
	else:buckets[slot]=node.next
	objects.erase(id)
	return {"status":0,"object":node.object}

func clean(_list: Variant=null) -> void:
	pass
