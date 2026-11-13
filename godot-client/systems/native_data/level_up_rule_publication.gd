extends RefCounted
# A level-up transaction owns this private CNWClass view. Only the shared
# original field compiler is reused, never a first-level character snapshot.
# Other active tables are immutable publication references, not deep copies.
const Metadata=preload("res://systems/native_data/level_up_class_metadata.gd")
var scope: Array=[]
var publication:=0
var class_compiles:=0
var ready:=false
var reason:="Private mode1 class rules are unavailable."
var raw_tables: Dictionary={}
var tables: Dictionary={}
var raw_classes: Variant=null
var class_view: Dictionary={}
var unknown: Dictionary={}
var private_tables: Dictionary={}
var catalog
var private_request:=-1
var request_floor:=-1
static func valid_scope(value: Array) -> bool:
	return value.size()==4 and value.all(func(item):return item is int and item>=0 and item<=9007199254740991)
func owns(value: Array) -> bool:return not scope.is_empty() and value==scope
func same_sources(active: Dictionary) -> bool:
	if active.size()!=raw_tables.size():return false
	for key in raw_tables:
		if not active.has(key) or not is_same(active[key],raw_tables[key]):return false
	return true
func view(value: Array,expected: int=-1) -> Dictionary:
	if not owns(value) or expected>=0 and expected!=publication:return {"ready":false,"reason":"Retired mode1 class-rule publication."}
	return {"ready":ready,"reason":reason,"scope":scope.duplicate(),"publication":publication,"tables":tables,"rawClasses":raw_classes,"unknown":unknown.duplicate(true),"compiledFields":Metadata.NUMERIC+["SpellcastingAbil","SpellTableColumn","CLMultiplier"]}
func current(active: Dictionary,value: Array,expected: int) -> bool:
	return ready and owns(value) and expected==publication and same_sources(active)
func begin(active: Dictionary,value: Array,active_catalog: Object=null) -> Dictionary:
	retire()
	if not valid_scope(value):return {"ready":false,"reason":"Private mode1 transaction scope is unavailable."}
	scope=value.duplicate();catalog=active_catalog;return publish(active,value)
func open_private_request(value: Array,active_catalog: Object,request: int) -> bool:
	if not owns(value) or catalog==null or active_catalog!=catalog or request<=request_floor:return false
	private_request=request;request_floor=request;return true
func finish_private_request(value: Array,active_catalog: Object,request: int) -> void:
	if owns(value) and active_catalog==catalog and request==private_request:private_request=-1
func publish_private(name: String,data: Dictionary,value: Array,active_catalog: Object,request: int) -> Dictionary:
	if not ready or not owns(value) or catalog==null or active_catalog!=catalog or request<0 or request!=private_request or name=="classes" or raw_tables.has(name):return {"ready":false,"reason":"Retired or nonprivate mode1 dependency publication."}
	private_tables[name]=data;tables=tables.duplicate();tables[name]=data;publication+=1;return view(value)
func publish(active: Dictionary,value: Array) -> Dictionary:
	if not owns(value):return {"ready":false,"reason":"Retired mode1 class-rule publication."}
	if same_sources(active):return view(value)
	publication+=1;raw_tables=active.duplicate();tables=active.duplicate();ready=false;unknown={};reason="The active physical class table is unavailable."
	for name in private_tables:
		if not tables.has(name):tables[name]=private_tables[name]
	var source: Variant=active.get("classes")
	if not source is Dictionary or not source.get("orderedRows") is Array:
		raw_classes=source;class_view={};tables.erase("classes");return view(value)
	if not is_same(raw_classes,source) or class_view.is_empty():
		var compiled:=Metadata.compile(source);class_compiles+=1;raw_classes=source
		if not compiled.ready:class_view={};tables.erase("classes");reason=str(compiled.reason);return view(value)
		class_view=compiled.table
		var provenance: Dictionary=class_view.nativeClassProjection.duplicate(true);provenance.scope="mode1_private";provenance.adapter="level_up_rule_publication";class_view.nativeClassProjection=provenance
	else:raw_classes=source
	# This is deliberately a partial native field projection. Uncovered mode1
	# prestige/getter fields remain raw; their own typed adapters can stay pending.
	unknown=class_view.nativeClassProjection.get("unknown",{}).duplicate(true)
	tables.classes=class_view;ready=true;reason="";return view(value)
func retire() -> void:
	scope=[];publication+=1;ready=false;reason="Private mode1 class rules are unavailable.";raw_tables={};tables={};raw_classes=null;class_view={};unknown={};private_tables={};catalog=null;private_request=-1;request_floor=-1
