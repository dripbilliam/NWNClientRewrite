// Transaction-private protocol provenance only. No clocks, timestamps, world
// rows, native object simulation, rendering or construction from DTO flags.
export const NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE='native_client_clock_lifecycle_v1';
const MAX=Number.MAX_SAFE_INTEGER;
let nextPrivateEpoch=0;
const ref=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const own=(value,key)=>{if(!ref(value))return undefined;const d=Object.getOwnPropertyDescriptor(value,key);return d&&Object.hasOwn(d,'value')?d.value:undefined;};
const safe=value=>Number.isSafeInteger(value)&&value>=0;
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const external=value=>{if(!uint(value)||value<0x80000000)return false;const low=value&0x7fffffff;return !(low&0x7f000000)||low>=0x7f000001;};
const area=value=>value===null||uint(value);
const freeze=value=>{if(ref(value)||Array.isArray(value)){for(const key of Object.keys(value))freeze(value[key]);Object.freeze(value);}return value;};
const copy=value=>structuredClone(value);
const fail=reason=>{throw new TypeError('Invalid native client clock lifecycle '+reason);};

export class NativeClientClockLifecycle {
 #owner; #epoch; #connection; #recordHistory; #recordReason; #constructionHistory; #constructionReason; #owners=new WeakMap(); #transactions=new WeakMap(); #accepted=new WeakMap(); #tokens=new WeakMap();
 // Only negative, ID-local facts lacking a canonical proxy. No world rows;
 // ordinary certified-absent D adds nothing, and real global gaps need none.
 #unboundOwners=new Map();
 #active=null; #revision=0; #physicalSerial=0; #transactionSerial=0;
 constructor({owner,connection=null,recordHistoryComplete=false,externalRegistryHistoryComplete=false}={}){
  if(!ref(owner)||connection!==null&&!safe(connection)||typeof recordHistoryComplete!=='boolean'||typeof externalRegistryHistoryComplete!=='boolean'||nextPrivateEpoch>=MAX)fail('initial boundary');
  this.#owner=owner;this.#epoch=++nextPrivateEpoch;this.#connection=connection;
  this.#recordHistory=recordHistoryComplete;this.#recordReason=recordHistoryComplete?null:'unverified-record-history';
  this.#constructionHistory=externalRegistryHistoryComplete;this.#constructionReason=externalRegistryHistoryComplete?null:'unverified-external-registry-history';
 }
 #taint(reason){this.#recordHistory=false;this.#recordReason??=reason;this.#constructionHistory=false;this.#constructionReason??=reason;this.#revision++;}
 #reject(tx,reason){if(tx)tx.failed=true;this.#taint(reason);fail(reason);}
 #transaction(key){const tx=ref(key)?this.#transactions.get(key):null;if(!tx||this.#active!==key||tx.status!=='open'||tx.failed)this.#reject(tx,'stale-or-untracked-transaction');return tx;}
 #proxy(value,id){return ref(value)&&own(value,'id')===id&&own(value,'objectType')===5;}
 bindConnection(owner,connection){
  if(owner!==this.#owner||!safe(connection))fail('connection owner');
  if(this.#connection!==null&&connection!==this.#connection){this.#taint('connection-rebind');fail('connection rebind requires new registry epoch');}
  if(this.#active!==null){this.#taint('connection-bind-during-transaction');fail('connection bind during transaction');}
  this.#connection=connection;return this.history(owner);
 }
 begin(transaction,{complete,recordCount}={}){
  if(!ref(transaction)||this.#transactions.has(transaction)||this.#active!==null||typeof complete!=='boolean'||!safe(recordCount))this.#reject(null,'transaction begin');
  const recordHistoryComplete=this.#recordHistory&&complete;
  const tx={status:'open',failed:false,nextIndex:0,recordCount,recordHistoryComplete,recordReason:this.#recordReason??(complete?null:'incomplete-record-history'),constructionHistoryComplete:this.#constructionHistory&&recordHistoryComplete,constructionReason:this.#constructionReason??(recordHistoryComplete?null:'incomplete-record-history'),baseRevision:this.#revision,touched:new Map(),events:[]};
  this.#transactions.set(transaction,tx);this.#active=transaction;
  return {version:1,source:NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE,epoch:this.#epoch,connection:this.#connection,complete:tx.recordHistoryComplete,recordHistoryComplete:tx.recordHistoryComplete,constructionHistoryComplete:tx.constructionHistoryComplete};
 }
 observe(transaction,record,index,boundary={}){
  const tx=this.#transaction(transaction);
  if(!ref(record)||index!==tx.nextIndex||index>=tx.recordCount)this.#reject(tx,'ordered record index');
  const action=own(record,'action'),type=own(record,'objectType');
  if(typeof action!=='string')this.#reject(tx,'record action');
  if(type!==5){tx.nextIndex++;return {observed:true,lifecycle:false};}
  if(!['create','delete','appearance','update','player-state','inventory-stats'].includes(action))this.#reject(tx,'creature record action');
  const id=own(record,'id');if(!external(id))this.#reject(tx,'external creature identity');
  const canonical=own(boundary,'canonicalBefore'),staged=own(boundary,'stagedProxy'),externalOwner=own(boundary,'externalOwner'),areaId=own(boundary,'areaId');
  if(!['absent','live','retained','unknown'].includes(externalOwner)||!area(areaId)||!(canonical===null||this.#proxy(canonical,id))||!(staged===null||this.#proxy(staged,id)))this.#reject(tx,'private pre-record boundary');
  if(staged===null&&!(action==='delete'&&canonical===null))this.#reject(tx,'missing staged creature proxy');
  let touched=tx.touched.get(id);
  if(touched&&touched.canonical!==canonical)this.#reject(tx,'staged proxy alias');
  if(touched&&touched.staged!==staged){
   const firstAllocation=touched.staged===null&&touched.certifiedAbsent===true&&touched.current===null&&tx.constructionHistoryComplete&&action==='create'&&externalOwner==='absent'&&canonical===null&&staged!==null;
   if(!firstAllocation)this.#reject(tx,'staged proxy alias');
   touched.staged=staged;touched.certifiedAbsent=false;
  }
  if(!touched){
   const prior=(canonical===null?null:this.#owners.get(canonical))??this.#unboundOwners.get(id)??null;
   if(prior&&prior.objectId!==id)this.#reject(tx,'canonical proxy alias');
   touched={canonical,staged,current:prior?{...prior}:null,certifiedAbsent:false};tx.touched.set(id,touched);
  }
  const previous=touched.current;
  let current=previous?{...previous}:null,event=null,eventConstructionKnown=false,eventConstructionReason=null;
  if(action==='create'){
   const fresh=tx.constructionHistoryComplete&&externalOwner==='absent'&&canonical===null&&previous===null;
   const privateLive=tx.recordHistoryComplete&&previous?.presence==='live'&&previous.physicalCurrent;
   const retained=externalOwner==='retained'||externalOwner==='live'&&previous?.presence!=='removed-ambiguous'||externalOwner==='unknown'&&privateLive;
   let ownership='unknown',physical=null,birthKnown=false;
   if(fresh){ownership='new';physical={};birthKnown=true;}
   else if(retained){
    ownership='retained';
    // A live typed owner is not proof that an ambiguous historical owner is
    // the SAME physical instance. Only complete private live history or an
    // explicit retained-owner witness may reuse that old opaque token.
    const samePhysical=externalOwner==='retained'||tx.recordHistoryComplete&&previous?.physicalCurrent===true;
    physical=samePhysical?previous?.physical??{}:{};
    birthKnown=samePhysical&&previous?.birthKnown===true;
   }
   eventConstructionKnown=physical!==null&&birthKnown;
   eventConstructionReason=eventConstructionKnown?null:ownership==='retained'?'retained-creature-birth-unknown':'unknown-creature-construction';
   current={objectId:id,areaId,presence:'live',physical:physical??previous?.physical??null,physicalCurrent:physical!==null,birthKnown:physical!==null?birthKnown:previous?.birthKnown===true,constructionReason:eventConstructionReason};
   event={operation:'create',recordIndex:index,objectId:id,objectType:5,ownership,deletionFlag:null,areaId,physical,ownerAbsentCertified:false,constructionCertified:fresh,aiRegistrationCertified:fresh};
  }else if(action==='delete'){
   const deletionFlag=own(record,'remove');if(deletionFlag!==0&&deletionFlag!==1)this.#reject(tx,'raw deletion BOOL bit');
   const ownerAbsentCertified=tx.constructionHistoryComplete&&externalOwner==='absent'&&canonical===null&&staged===null&&previous===null;
   const known=previous?.physical!==null&&previous?.physical!==undefined&&(externalOwner==='retained'||tx.recordHistoryComplete&&previous.physicalCurrent===true&&externalOwner!=='absent');
   eventConstructionKnown=ownerAbsentCertified||known&&previous.birthKnown===true;
   eventConstructionReason=eventConstructionKnown?null:known?'retained-creature-birth-unknown':'untracked-creature-removal';
   current=ownerAbsentCertified?null:{objectId:id,areaId,presence:'removed-ambiguous',physical:previous?.physical??null,physicalCurrent:false,birthKnown:previous?.birthKnown===true,constructionReason:'removed-owner-retention-ambiguous'};
   touched.certifiedAbsent=ownerAbsentCertified;
   event={operation:'remove',recordIndex:index,objectId:id,objectType:5,ownership:known?'retained':'unknown',deletionFlag,areaId,physical:known?previous.physical:null,ownerAbsentCertified,constructionCertified:false,aiRegistrationCertified:false};
  }else{
   // Generic I/P/U can allocate a JS proxy without proving native birth. It
   // must make a later A conservative, even if the final DTO looks complete.
   if(!previous)current={objectId:id,areaId,presence:'unknown',physical:null,physicalCurrent:false,birthKnown:false,constructionReason:'untracked-creature-proxy'};
   else current={...previous,areaId};
  }
  touched.current=current;
  if(event)tx.events.push({event,complete:tx.recordHistoryComplete,recordReason:tx.recordReason,constructionHistoryComplete:tx.constructionHistoryComplete&&eventConstructionKnown,constructionReason:tx.constructionReason??eventConstructionReason});
  tx.nextIndex++;return {observed:true,lifecycle:event!==null};
 }
 commit(transaction,resolveCanonical){
  const tx=this.#transaction(transaction);
  if(typeof resolveCanonical!=='function'||tx.nextIndex!==tx.recordCount||tx.baseRevision!==this.#revision)this.#reject(tx,'incomplete or stale commit');
  tx.status='committing';
  const resolved=[],unbound=[],newPhysical=new Set();
  try{
   // Resolve only touched IDs; all callback validation precedes publication.
   for(const [id,touched] of tx.touched){
    const canonical=resolveCanonical(id);
    if(touched.staged===null){if(canonical!==null&&canonical!==undefined)throw Error('Absent removal acquired a proxy');unbound.push([id,tx.constructionHistoryComplete&&touched.current?freeze({...touched.current}):null]);continue;}
    if(!this.#proxy(canonical,id)||touched.canonical!==null&&canonical!==touched.canonical||touched.canonical===null&&canonical!==touched.staged)throw Error('Canonical commit identity changed');
    resolved.push([canonical,touched.current]);
    unbound.push([id,null]);
   }
   if(this.#active!==transaction||tx.baseRevision!==this.#revision)throw Error('Reentrant commit changed owner');
   for(const {event} of tx.events)if(event.physical&&!this.#tokens.has(event.physical))newPhysical.add(event.physical);
   for(const [,value] of resolved)if(value.physical&&!this.#tokens.has(value.physical))newPhysical.add(value.physical);
   if(this.#physicalSerial>MAX-newPhysical.size||this.#transactionSerial>=MAX)throw Error('Lifecycle token namespace exhausted');
  }catch(error){tx.status='aborted';this.#active=null;this.#taint('commit-rejected');throw new TypeError('Invalid native client clock lifecycle commit: '+error.message);}
  let physicalSerial=this.#physicalSerial;
  const pendingTokens=new Map();for(const physical of newPhysical)pendingTokens.set(physical,`client-clock:${this.#epoch}:${this.#connection??'unbound'}:${++physicalSerial}`);
  const transactionSerial=this.#transactionSerial+1,boundaries=[],values=[];
  for(const {event,complete,recordReason,constructionHistoryComplete,constructionReason} of tx.events){
   const {physical,...scalars}=event;
   const value=freeze({version:1,source:NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE,epoch:this.#epoch,connection:this.#connection,transaction:transactionSerial,complete,recordHistoryComplete:complete,recordReason,constructionHistoryComplete,constructionReason,fact:{...scalars,physicalToken:physical?this.#tokens.get(physical)??pendingTokens.get(physical):null}});
   const boundary=Object.freeze({});boundaries.push(boundary);values.push([boundary,value]);
  }
  tx.prepared={resolved:resolved.map(([canonical,value])=>[canonical,freeze({...value})]),unbound,pendingTokens,physicalSerial,transactionSerial,values};
  tx.boundaries=Object.freeze(boundaries);tx.status='prepared';
  return tx.boundaries;
 }
 publish(transaction){
  const tx=ref(transaction)?this.#transactions.get(transaction):null;
  if(!tx||this.#active!==transaction||tx.status!=='prepared'||tx.failed||tx.baseRevision!==this.#revision){this.#taint('publication-rejected');return null;}
  const prepared=tx.prepared;
  // No resolver, row reads, token arithmetic or semantic validation after the
  // World commit. All possibly failing preparation occurred in commit above.
  for(const [physical,token] of prepared.pendingTokens)this.#tokens.set(physical,token);
  for(const [canonical,value] of prepared.resolved)this.#owners.set(canonical,value);
  for(const [id,value] of prepared.unbound){if(value)this.#unboundOwners.set(id,value);else this.#unboundOwners.delete(id);}
  for(const [boundary,value] of prepared.values)this.#accepted.set(boundary,value);
  this.#physicalSerial=prepared.physicalSerial;this.#transactionSerial=prepared.transactionSerial;
  if(!tx.recordHistoryComplete){this.#recordHistory=false;this.#recordReason??=tx.recordReason??'untracked-record-history';}
  if(!tx.constructionHistoryComplete){this.#constructionHistory=false;this.#constructionReason??=tx.constructionReason??'untracked-construction-history';}
  tx.status='published';tx.touched.clear();tx.events=[];tx.prepared=null;this.#active=null;this.#revision++;
  return tx.boundaries;
 }
 abort(transaction,reason='rejected-native-transaction'){
  const tx=ref(transaction)?this.#transactions.get(transaction):null;
  if(!tx||this.#active!==transaction||!['open','committing','prepared'].includes(tx.status)){this.#taint('untracked-transaction-abort');return {aborted:false};}
  if(typeof reason!=='string'||!/^[A-Za-z0-9_.:-]{1,64}$/.test(reason))reason='rejected-native-transaction';
  tx.failed=true;tx.status='aborted';tx.touched.clear();tx.events=[];tx.prepared=null;tx.boundaries=null;this.#active=null;this.#taint(reason);return {aborted:true};
 }
 acceptedBoundary(owner,boundary){if(owner!==this.#owner||!ref(boundary))return null;const value=this.#accepted.get(boundary);return value?copy(value):null;}
 acceptedBatch(owner,transaction){if(owner!==this.#owner||!ref(transaction))return null;const tx=this.#transactions.get(transaction);return tx?.status==='published'?Object.freeze([...tx.boundaries]):null;}
 stateFor(owner,canonical){
  if(owner!==this.#owner||!ref(canonical))return null;const value=this.#owners.get(canonical);if(!value||!this.#proxy(canonical,value.objectId))return null;
  return {version:1,source:NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE,epoch:this.#epoch,connection:this.#connection,objectId:value.objectId,objectType:5,areaId:value.areaId,presence:value.presence,physicalToken:value.physical?this.#tokens.get(value.physical)??null:null,physicalCurrent:value.physicalCurrent&&this.#recordHistory,recordHistoryComplete:this.#recordHistory,constructionHistoryComplete:this.#constructionHistory&&this.#recordHistory&&value.physicalCurrent&&value.birthKnown===true,constructionReason:this.#constructionReason??value.constructionReason};
 }
 history(owner){return owner===this.#owner?{version:1,source:NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE,epoch:this.#epoch,connection:this.#connection,complete:this.#recordHistory,recordHistoryComplete:this.#recordHistory,recordReason:this.#recordReason,constructionHistoryComplete:this.#constructionHistory,constructionReason:this.#constructionReason}:null;}
}
