extends RefCounted
# Private transaction provenance for received creature records. This owns no
# world rows or timers. The World caller owns stable Proxy handles separately
# from its copied Dictionary rows.
const SOURCE:="native_client_clock_lifecycle_v1"
const MAX:=9007199254740991
const U32:=0xffffffff
static var next_private_epoch:=0

class Proxy extends RefCounted:
	var id: int
	var objectType:=5
	func _init(object_id: int)->void:id=object_id

static func make_proxy(object_id: int)->Proxy:return Proxy.new(object_id)
static func _safe(value: Variant)->bool:return value is int and value>=0 and value<=MAX
static func _uint(value: Variant)->bool:return value is int and value>=0 and value<=U32
static func _external(value: Variant)->bool:
	if not _uint(value) or value<0x80000000:return false
	var low: int=value&0x7fffffff
	return (low&0x7f000000)==0 or low>=0x7f000001
static func _area(value: Variant)->bool:return value==null or _uint(value)
static func _proxy(value: Variant,object_id: int)->bool:return value is Proxy and is_instance_valid(value) and value.id==object_id and value.objectType==5
static func _clone(value: Variant)->Variant:
	if value is Dictionary or value is Array:return value.duplicate(true)
	return value

var owner: WeakRef
var epoch:=0
var connection: Variant=null
var record_history:=false
var record_reason: Variant=null
var construction_history:=false
var construction_reason: Variant=null
var error: String=""
var _owners: Dictionary={}
var _transactions: Dictionary={}
var _accepted: Dictionary={}
var _tokens: Dictionary={}
var _unbound_owners: Dictionary={}
var _active: Object=null
var _revision:=0
var _physical_serial:=0
var _transaction_serial:=0

func _init(options: Dictionary={}) -> void:
	var given_owner: Variant=options.get("owner")
	var given_connection: Variant=options.get("connection")
	if not given_owner is Object or not is_instance_valid(given_owner) or given_connection!=null and not _safe(given_connection) or not options.get("recordHistoryComplete",false) is bool or not options.get("externalRegistryHistoryComplete",false) is bool or next_private_epoch>=MAX:
		error="initial boundary";return
	owner=weakref(given_owner)
	next_private_epoch+=1;epoch=next_private_epoch
	connection=given_connection
	record_history=options.get("recordHistoryComplete",false)
	construction_history=options.get("externalRegistryHistoryComplete",false)
	record_reason=null if record_history else "unverified-record-history"
	construction_reason=null if construction_history else "unverified-external-registry-history"

func _fail(reason: String)->Dictionary:error=reason;return {"ok":false,"reason":reason}
func _taint(reason: String)->void:
	record_history=false
	if record_reason==null:record_reason=reason
	construction_history=false
	if construction_reason==null:construction_reason=reason
	_revision+=1
func _reject(tx: Dictionary,reason: String)->Dictionary:
	if not tx.is_empty():tx.failed=true
	_taint(reason)
	return _fail(reason)
func _entry(table: Dictionary,key: Variant)->Dictionary:
	if not key is Object or not is_instance_valid(key):return {}
	var entry: Dictionary=table.get(key.get_instance_id(),{})
	if entry.is_empty():return {}
	var reference: WeakRef=entry.get("ref")
	if reference==null or reference.get_ref()!=key:return {}
	return entry
func _put(table: Dictionary,key: Object,value: Variant)->void:
	table[key.get_instance_id()]={"ref":weakref(key),"value":value}
func _tx(key: Variant)->Dictionary:
	var entry:=_entry(_transactions,key)
	var tx: Dictionary=entry.get("value",{})
	if tx.is_empty() or _active!=key or tx.get("status")!="open" or tx.get("failed",false):
		_reject(tx,"stale-or-untracked-transaction")
		return {}
	return tx
func _owner_value(proxy: Variant)->Variant:
	return _entry(_owners,proxy).get("value")
func _token(physical: Variant)->Variant:
	return _entry(_tokens,physical).get("value")

func bind_connection(given_owner: Object,given_connection: Variant)->Dictionary:
	if owner==null or given_owner!=owner.get_ref() or not _safe(given_connection):return _fail("connection owner")
	if connection!=null and connection!=given_connection:
		_taint("connection-rebind");return _fail("connection rebind requires new registry epoch")
	if _active!=null:
		_taint("connection-bind-during-transaction");return _fail("connection bind during transaction")
	connection=given_connection
	return history(given_owner)

func begin(transaction: Object,options: Dictionary={}) -> Dictionary:
	var complete: Variant=options.get("complete")
	var count: Variant=options.get("recordCount")
	if epoch==0 or not transaction is Object or not is_instance_valid(transaction) or not _entry(_transactions,transaction).is_empty() or _active!=null or not complete is bool or not _safe(count):return _reject({},"transaction begin")
	var records_complete: bool=record_history and complete
	var tx:={"status":"open","failed":false,"nextIndex":0,"recordCount":int(count),"recordHistoryComplete":records_complete,"recordReason":record_reason if record_reason!=null else (null if complete else "incomplete-record-history"),"constructionHistoryComplete":construction_history and records_complete,"constructionReason":construction_reason if construction_reason!=null else (null if records_complete else "incomplete-record-history"),"baseRevision":_revision,"touched":{},"events":[],"prepared":null,"boundaries":[]}
	_put(_transactions,transaction,tx);_active=transaction
	error=""
	return {"version":1,"source":SOURCE,"epoch":epoch,"connection":connection,"complete":records_complete,"recordHistoryComplete":records_complete,"constructionHistoryComplete":tx.constructionHistoryComplete}

func observe(transaction: Object,record: Variant,index: Variant,boundary: Dictionary={}) -> Dictionary:
	var tx:=_tx(transaction)
	if tx.is_empty():return {"ok":false,"reason":error}
	if not record is Dictionary or not index is int or index!=tx.nextIndex or index>=tx.recordCount:return _reject(tx,"ordered record index")
	var action: Variant=record.get("action")
	var object_type: Variant=record.get("objectType")
	if not action is String:return _reject(tx,"record action")
	if object_type!=5:
		tx.nextIndex+=1
		return {"observed":true,"lifecycle":false}
	if action not in ["create","delete","appearance","update","player-state","inventory-stats"]:return _reject(tx,"creature record action")
	var object_id: Variant=record.get("id")
	if not _external(object_id):return _reject(tx,"external creature identity")
	var canonical: Variant=boundary.get("canonicalBefore")
	var staged: Variant=boundary.get("stagedProxy")
	var external_owner: Variant=boundary.get("externalOwner")
	var area_id: Variant=boundary.get("areaId")
	if external_owner not in ["absent","live","retained","unknown"] or not _area(area_id) or not (canonical==null or _proxy(canonical,object_id)) or not (staged==null or _proxy(staged,object_id)):return _reject(tx,"private pre-record boundary")
	if staged==null and not (action=="delete" and canonical==null):return _reject(tx,"missing staged creature proxy")
	var touched: Dictionary=tx.touched.get(object_id,{})
	if not touched.is_empty() and touched.canonical!=canonical:return _reject(tx,"staged proxy alias")
	if not touched.is_empty() and touched.staged!=staged:
		var first_allocation: bool=touched.staged==null and touched.certifiedAbsent==true and touched.current==null and tx.constructionHistoryComplete and action=="create" and external_owner=="absent" and canonical==null and staged!=null
		if not first_allocation:return _reject(tx,"staged proxy alias")
		touched.staged=staged;touched.certifiedAbsent=false
	if touched.is_empty():
		var prior: Variant=_owner_value(canonical) if canonical!=null else null
		if prior==null:prior=_unbound_owners.get(object_id)
		if prior is Dictionary and prior.get("objectId")!=object_id:return _reject(tx,"canonical proxy alias")
		touched={"canonical":canonical,"staged":staged,"current":prior.duplicate() if prior is Dictionary else null,"certifiedAbsent":false}
		tx.touched[object_id]=touched
	var previous: Variant=touched.current
	var current: Variant=previous.duplicate() if previous is Dictionary else null
	var event: Variant=null
	var event_construction_known:=false
	var event_construction_reason: Variant=null
	if action=="create":
		var fresh: bool=tx.constructionHistoryComplete and external_owner=="absent" and canonical==null and previous==null
		var private_live: bool=tx.recordHistoryComplete and previous is Dictionary and previous.get("presence")=="live" and previous.get("physicalCurrent",false)
		var retained: bool=external_owner=="retained" or external_owner=="live" and (not previous is Dictionary or previous.get("presence")!="removed-ambiguous") or external_owner=="unknown" and private_live
		var ownership:="unknown"
		var physical: Variant=null
		var birth_known:=false
		if fresh:
			ownership="new";physical=RefCounted.new();birth_known=true
		elif retained:
			ownership="retained"
			var same_physical: bool=external_owner=="retained" or tx.recordHistoryComplete and previous is Dictionary and previous.get("physicalCurrent",false)
			physical=previous.get("physical") if same_physical and previous is Dictionary else null
			if physical==null:physical=RefCounted.new()
			birth_known=same_physical and previous is Dictionary and previous.get("birthKnown",false)
		event_construction_known=physical!=null and birth_known
		event_construction_reason=null if event_construction_known else ("retained-creature-birth-unknown" if ownership=="retained" else "unknown-creature-construction")
		current={"objectId":object_id,"areaId":area_id,"presence":"live","physical":physical if physical!=null else (previous.get("physical") if previous is Dictionary else null),"physicalCurrent":physical!=null,"birthKnown":birth_known if physical!=null else (previous.get("birthKnown",false) if previous is Dictionary else false),"constructionReason":event_construction_reason}
		event={"operation":"create","recordIndex":index,"objectId":object_id,"objectType":5,"ownership":ownership,"deletionFlag":null,"areaId":area_id,"physical":physical,"ownerAbsentCertified":false,"constructionCertified":fresh,"aiRegistrationCertified":fresh}
	elif action=="delete":
		var deletion_flag: Variant=record.get("remove")
		if deletion_flag is bool:deletion_flag=int(deletion_flag)
		if deletion_flag!=0 and deletion_flag!=1:return _reject(tx,"raw deletion BOOL bit")
		var owner_absent_certified: bool=tx.constructionHistoryComplete and external_owner=="absent" and canonical==null and staged==null and previous==null
		var known: bool=previous is Dictionary and previous.get("physical")!=null and (external_owner=="retained" or tx.recordHistoryComplete and previous.get("physicalCurrent",false) and external_owner!="absent")
		event_construction_known=owner_absent_certified or known and previous.get("birthKnown",false)
		event_construction_reason=null if event_construction_known else ("retained-creature-birth-unknown" if known else "untracked-creature-removal")
		current=null if owner_absent_certified else {"objectId":object_id,"areaId":area_id,"presence":"removed-ambiguous","physical":previous.get("physical") if previous is Dictionary else null,"physicalCurrent":false,"birthKnown":previous.get("birthKnown",false) if previous is Dictionary else false,"constructionReason":"removed-owner-retention-ambiguous"}
		touched.certifiedAbsent=owner_absent_certified
		event={"operation":"remove","recordIndex":index,"objectId":object_id,"objectType":5,"ownership":"retained" if known else "unknown","deletionFlag":deletion_flag,"areaId":area_id,"physical":previous.physical if known else null,"ownerAbsentCertified":owner_absent_certified,"constructionCertified":false,"aiRegistrationCertified":false}
	else:
		# I/P/U may allocate a proxy without proving physical construction.
		if previous==null:current={"objectId":object_id,"areaId":area_id,"presence":"unknown","physical":null,"physicalCurrent":false,"birthKnown":false,"constructionReason":"untracked-creature-proxy"}
		else:current.areaId=area_id
	touched.current=current
	if event!=null:
		tx.events.append({"event":event,"complete":tx.recordHistoryComplete,"recordReason":tx.recordReason,"constructionHistoryComplete":tx.constructionHistoryComplete and event_construction_known,"constructionReason":tx.constructionReason if tx.constructionReason!=null else event_construction_reason})
	tx.nextIndex+=1
	return {"observed":true,"lifecycle":event!=null}

func _commit_rejected(tx: Dictionary,detail: String)->Array:
	tx.status="aborted";_active=null;_taint("commit-rejected")
	error="commit: "+detail
	return []
func commit(transaction: Object,resolve_canonical: Callable)->Array:
	var tx:=_tx(transaction)
	if tx.is_empty():return []
	if not resolve_canonical.is_valid() or tx.nextIndex!=tx.recordCount or tx.baseRevision!=_revision:
		_reject(tx,"incomplete or stale commit");return []
	tx.status="committing"
	var resolved: Array=[]
	var unbound: Array=[]
	var new_physical: Dictionary={}
	# Callback validation finishes before any accepted owner is published.
	for object_id in tx.touched:
		var touched: Dictionary=tx.touched[object_id]
		var canonical: Variant=resolve_canonical.call(object_id)
		if touched.staged==null:
			if canonical!=null:return _commit_rejected(tx,"Absent removal acquired a proxy")
			var absent_value: Variant=touched.current.duplicate() if tx.constructionHistoryComplete and touched.current is Dictionary else null
			unbound.append([object_id,absent_value]);continue
		if not _proxy(canonical,object_id) or touched.canonical!=null and canonical!=touched.canonical or touched.canonical==null and canonical!=touched.staged:return _commit_rejected(tx,"Canonical commit identity changed")
		resolved.append([canonical,touched.current])
		unbound.append([object_id,null])
	if _active!=transaction or tx.baseRevision!=_revision:return _commit_rejected(tx,"Reentrant commit changed owner")
	for row in tx.events:
		var physical: Variant=row.event.physical
		if physical!=null and _token(physical)==null:new_physical[physical]=true
	for row in resolved:
		var value: Variant=row[1]
		if value is Dictionary and value.get("physical")!=null and _token(value.physical)==null:new_physical[value.physical]=true
	if _physical_serial>MAX-new_physical.size() or _transaction_serial>=MAX:return _commit_rejected(tx,"Lifecycle token namespace exhausted")
	var physical_serial:=_physical_serial
	var pending_tokens: Dictionary={}
	for physical in new_physical:
		physical_serial+=1
		pending_tokens[physical]="client-clock:%s:%s:%s"%[epoch,str(connection) if connection!=null else "unbound",physical_serial]
	var transaction_serial:=_transaction_serial+1
	var boundaries: Array=[]
	var values: Array=[]
	for row in tx.events:
		var event: Dictionary=row.event
		var fact: Dictionary=event.duplicate()
		var physical: Variant=fact.get("physical")
		fact.erase("physical")
		fact.physicalToken=(_token(physical) if _token(physical)!=null else pending_tokens.get(physical)) if physical!=null else null
		var value:={"version":1,"source":SOURCE,"epoch":epoch,"connection":connection,"transaction":transaction_serial,"complete":row.complete,"recordHistoryComplete":row.complete,"recordReason":row.recordReason,"constructionHistoryComplete":row.constructionHistoryComplete,"constructionReason":row.constructionReason,"fact":fact}
		var boundary:=RefCounted.new()
		boundaries.append(boundary);values.append([boundary,value])
	var frozen_resolved: Array=[]
	for row in resolved:frozen_resolved.append([row[0],row[1].duplicate() if row[1] is Dictionary else null])
	tx.prepared={"resolved":frozen_resolved,"unbound":unbound,"pendingTokens":pending_tokens,"physicalSerial":physical_serial,"transactionSerial":transaction_serial,"values":values}
	tx.boundaries=boundaries.duplicate()
	tx.status="prepared"
	error=""
	return boundaries.duplicate()

func publish(transaction: Object)->Variant:
	var entry:=_entry(_transactions,transaction)
	var tx: Dictionary=entry.get("value",{})
	if tx.is_empty() or _active!=transaction or tx.get("status")!="prepared" or tx.get("failed",false) or tx.get("baseRevision")!=_revision:
		_taint("publication-rejected");error="publication-rejected";return null
	var prepared: Dictionary=tx.prepared
	# The World has already committed. Publication performs no callbacks or
	# semantic validation, matching the old post-commit boundary.
	for physical in prepared.pendingTokens:_put(_tokens,physical,prepared.pendingTokens[physical])
	for row in prepared.resolved:_put(_owners,row[0],row[1])
	for row in prepared.unbound:
		if row[1]!=null:_unbound_owners[row[0]]=row[1]
		else:_unbound_owners.erase(row[0])
	for row in prepared.values:_put(_accepted,row[0],row[1])
	_physical_serial=prepared.physicalSerial;_transaction_serial=prepared.transactionSerial
	if not tx.recordHistoryComplete:
		record_history=false
		if record_reason==null:record_reason=tx.recordReason if tx.recordReason!=null else "untracked-record-history"
	if not tx.constructionHistoryComplete:
		construction_history=false
		if construction_reason==null:construction_reason=tx.constructionReason if tx.constructionReason!=null else "untracked-construction-history"
	tx.status="published";tx.touched.clear();tx.events.clear();tx.prepared=null;_active=null;_revision+=1
	error=""
	return tx.boundaries.duplicate()

func abort(transaction: Object,reason: Variant="rejected-native-transaction")->Dictionary:
	var tx: Dictionary=_entry(_transactions,transaction).get("value",{})
	if tx.is_empty() or _active!=transaction or tx.get("status") not in ["open","committing","prepared"]:
		_taint("untracked-transaction-abort")
		return {"aborted":false}
	if not reason is String or reason.is_empty() or reason.length()>64:
		reason="rejected-native-transaction"
	else:
		for byte in reason.to_utf8_buffer():
			if not (byte>=65 and byte<=90 or byte>=97 and byte<=122 or byte>=48 and byte<=57 or byte in [95,46,58,45]):
				reason="rejected-native-transaction";break
	tx.failed=true;tx.status="aborted";tx.touched.clear();tx.events.clear();tx.prepared=null;tx.boundaries=[]
	_active=null;_taint(reason)
	return {"aborted":true}

func accepted_boundary(given_owner: Object,boundary: Object)->Variant:
	if owner==null or given_owner!=owner.get_ref():return null
	var value: Variant=_entry(_accepted,boundary).get("value")
	return _clone(value) if value!=null else null

func accepted_batch(given_owner: Object,transaction: Object)->Variant:
	if owner==null or given_owner!=owner.get_ref():return null
	var tx: Dictionary=_entry(_transactions,transaction).get("value",{})
	return tx.boundaries.duplicate() if not tx.is_empty() and tx.get("status")=="published" else null

func state_for(given_owner: Object,canonical: Object)->Variant:
	if owner==null or given_owner!=owner.get_ref():return null
	var value: Variant=_owner_value(canonical)
	if not value is Dictionary or not _proxy(canonical,value.objectId):return null
	var physical: Variant=value.get("physical")
	return {"version":1,"source":SOURCE,"epoch":epoch,"connection":connection,"objectId":value.objectId,"objectType":5,"areaId":value.areaId,"presence":value.presence,"physicalToken":_token(physical) if physical!=null else null,"physicalCurrent":value.physicalCurrent and record_history,"recordHistoryComplete":record_history,"constructionHistoryComplete":construction_history and record_history and value.physicalCurrent and value.get("birthKnown",false),"constructionReason":construction_reason if construction_reason!=null else value.get("constructionReason")}

func history(given_owner: Object)->Variant:
	if owner==null or given_owner!=owner.get_ref():return null
	return {"version":1,"source":SOURCE,"epoch":epoch,"connection":connection,"complete":record_history,"recordHistoryComplete":record_history,"recordReason":record_reason,"constructionHistoryComplete":construction_history,"constructionReason":construction_reason}
