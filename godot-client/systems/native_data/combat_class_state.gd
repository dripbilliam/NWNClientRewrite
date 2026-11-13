extends RefCounted
# Private client presentation state only. CNWCCreatureStats7ea230 constructs
# count1/class4 before class disclosure; selector80ffd0 therefore sees no5.
# This never creates canonical class/level/stat fields or table entries.
static func integer(value: Variant,minimum: int,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum
static func unknown(id: Variant=null,lifetime: Variant=null,reason: String="invalid-owner") -> Dictionary:
	return {"id":id,"lifetime":lifetime,"known":false,"monk":null,"source":reason}
static func project(object: Dictionary,previous: Dictionary={}) -> Dictionary:
	var id: Variant=object.get("id"); var lifetime: Variant=object.get("nativeLifetime")
	if not integer(object.get("objectType"),5,5) or not integer(id,0,0xffffffff) or int(id)==0x7f000000 or not integer(lifetime,1,9007199254740991): return unknown()
	id=int(id); lifetime=int(lifetime)
	var replicated: Variant=object.get("replicated",{})
	if not replicated is Dictionary: return unknown(id,lifetime,"malformed-replication")
	var stats: Variant=replicated.get("stats",{})
	if not stats is Dictionary: return unknown(id,lifetime,"malformed-stats")
	if stats.has("classes"):
		var classes: Variant=stats.classes
		if not classes is Array or classes.size()>8: return unknown(id,lifetime,"malformed-classes")
		var monk:=false
		for row in classes:
			if not row is Dictionary or not integer(row.get("id"),0,255): return unknown(id,lifetime,"malformed-class-id")
			if int(row.id)==5: monk=true
		return {"id":id,"lifetime":lifetime,"known":true,"monk":monk,"source":"received-creature-classes"}
	# A model replacement is not a new logical creature. Retain its last private
	# projection only for the exact owned identity, including explicit unknown.
	if previous.get("id") is int and previous.get("lifetime") is int and int(previous.id)==id and int(previous.lifetime)==lifetime and previous.get("known") is bool:
		if (previous.known and previous.get("monk") is bool) or (not previous.known and previous.get("monk")==null): return previous.duplicate(true)
	return {"id":id,"lifetime":lifetime,"known":true,"monk":false,"source":"native-constructor-7ea230"}
