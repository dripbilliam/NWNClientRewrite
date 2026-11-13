import {GameObjectArray,GAME_OBJECT_TYPE,OBJECT_INVALID,EXTERNAL_OBJECT} from './game_object_array.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {applyPlayerState} from './network_player_state_store.js';
import {applyNetworkDoorOpenState} from './network_door.js';
import {nativeCosf,nativeSinf} from './native_math.js';
import {networkAttackAnimationRecords} from './network_attack_animation.js';
import {applyClientItemUses,mergeNetworkItem} from './network_item_uses.js';
import {emptyQuickbarButton} from './quickbar.js';
import {networkCastReleaseBase,networkCastAnimationRecord} from './network_cast_animation.js';
import {mergeNetworkAbilityCache} from './network_spell_gain.js';
import {applyNetworkAssociateState} from './network_associates.js';
import {applyNetworkParty} from './network_party.js';
import {setCustomToken} from './custom_tokens.js';
import {scriptStringBytes} from './script_string.js';
import {applyNetworkAutomap} from './network_automap.js';
import {NuiState} from './nui_state.js';
import {applyAreaWeather} from './network_area_weather.js';
import {applyAreaWind} from './network_area_wind.js';
import {applyNetworkBarter,retireNetworkBarter} from './network_barter.js';
import {applyInventoryEquipmentResult,setClientEquipmentSlot} from './network_equipment_cache.js';
import {GuiPanelAccess} from './network_gui_panel_access.js';
import {EntityDisclosureLifetimes} from './network_entity_lifetimes.js';
import {mergeNativeSkillAdmission} from './network_skill_admission.js';
import {NetworkInventoryWindows} from './network_inventory_window_status.js';
import {validGameMasterPermission,DM_PERMISSION_SOURCE,normalConnectionPermission} from './network_dm_permission.js';
import {stagePlayerRoster} from './network_player_roster.js';
import {stageNativeActorName} from './network_actor_name_state.js';
import {NativeClientClockLifecycle} from './network_client_clock_lifecycle.js';
const immutableActorName=value=>{
 if(value&&typeof value==='object'&&!Object.isFrozen(value)){for(const child of Object.values(value))immutableActorName(child);Object.freeze(value);}
 return value;
};

// A connection owns its client proxies. No ModuleSession, script VM, AI,
// combat resolver or ID allocator runs when importing server state.
export class NetworkWorld {
 #actorNameStates;
 #actorNameHistoryComplete;
 #actorNameSequence;
 #clockLifecycle;
 #clockLifecycleRecords;
 #clockLifecycleFailures;
 constructor({onDiagnostic=d=>runtimeDiagnostics.record(d.code,d.reason,d)}={}){this.onDiagnostic=onDiagnostic;this.reset();}
 reset(){this.#clockLifecycle=new NativeClientClockLifecycle({owner:this,recordHistoryComplete:true,externalRegistryHistoryComplete:true});this.#clockLifecycleRecords=new WeakMap();this.#clockLifecycleFailures=0;this.#actorNameStates=new WeakMap();this.#actorNameHistoryComplete=true;this.#actorNameSequence=0;this.playerRosterKnown=false;this.gameMasterPermission=null;this.inventoryWindows=new NetworkInventoryWindows();this.entityDisclosures??=new EntityDisclosureLifetimes();this.entityDisclosures.reset();this.guiPanelAccess=new GuiPanelAccess();this.partyListRevision=0;this.partyInviteNotice=null;this.spellTargetingOverrides=new Map();this.scriptTargeting=null;this.scriptTargetingData=null;this.scriptTargetVersion=0;this.nui=new NuiState();this.store=null;this.registry=new GameObjectArray({clientMode:true});this.module=null;this.areaId=OBJECT_INVALID;this.entry=null;this.time={};this.controls=new Map();this.players=new Map();this.party=[];this.inventories=new Map();this.containers=new Map();this.quickbar=Array.from({length:36},emptyQuickbarButton);this.presentationChanges=[];this.localObjectId=OBJECT_INVALID;this.journal={entries:new Map(),worldEntries:new Map(),loaded:false};this.customTokens={records:[]};this.tlkOverrides=new Map();this.tlkOverrideVersion=0;this.playerAttitudes=new Map();this.mapPins=new Map();this.timing=null;this.barter={open:false,serial:0};}
 beginClientConnection(connectionType){
  const value=normalConnectionPermission(connectionType);if(!value)return false;
  // Native254ed0 resets normal16 permission on both connection-start paths.
  // This is client initialization, not received stats or an actor override.
  this.gameMasterPermission=value;return true;
 }
 apply(message){
  if(message.kind==='game-master-permission'){
   if(!validGameMasterPermission(message))throw Error('Invalid received native game-master permission');
   const actor=this.registry.get(this.localObjectId),target=actor?.objectType===GAME_OBJECT_TYPE.creature&&!actor.replicationRemoved?actor:null;
   const cleared=target&&message.permission===0?mergeNativeSkillAdmission(target.clientSkillAdmission,message,'permission'):null;
   // Connection permission is current even without a creature; the original
   // does not replay its stats110 clear onto a later controlled actor.
   this.gameMasterPermission={permission:message.permission,field114:message.field114,parameter:message.parameter,source:DM_PERMISSION_SOURCE};
   if(cleared)target.clientSkillAdmission=cleared;
   return true;
  }
  if(message.kind==='inventory-window-status')return this.inventoryWindows.observe(this,message);
  if(message.kind==='gui-panel-disabled'||message.kind==='gui-panel-popup')return this.guiPanelAccess.observe(message);
  if(message.kind==='inventory-result')return applyInventoryEquipmentResult(this,message);
  if(message.kind==='item-text-bubble-override'){
   const object=this.registry.get(message.itemId);
   if(object?.objectType!==GAME_OBJECT_TYPE.item||!object.item)return false;
   object.item.field2b8=message.mode;object.item.field2c0=message.text;return true;
  }
  if(message.kind==='party-invite-notice'){this.partyInviteNotice={name:message.name,serial:(this.partyInviteNotice?.serial??0)+1};return true;}
  if(message.kind.startsWith('barter-')&&message.kind!=='barter-reject')return applyNetworkBarter(this,message);
  if(message.kind==='script-targeting'){this.scriptTargetVersion=(this.scriptTargetVersion??0)+1;this.scriptTargeting=message.objectMask?{...message,version:this.scriptTargetVersion,areaId:this.areaId,actorId:this.localObjectId}:null;return true;}
  if(message.kind==='script-targeting-data'){this.scriptTargetingData={...message};return true;}
  if(message.kind==='spell-targeting-data'){this.spellTargetingOverrides.set(message.spellId,{...message});return true;}
  if(message.kind.startsWith('nui-')){this.nui??=new NuiState();return this.nui.apply(message);}
  if(message.kind==='store-open'){if(!this.store?.open){this.store={...structuredClone(message),open:true,generation:(this.store?.generation??0)+1,page:0};this.inventories.set('M',{entries:[],panel:message.panel,pageCount:1});}return true;}
  if(message.kind==='store-close'){if(this.store)this.store.open=false;this.inventories.delete('M');return true;}
  if(message.kind==='store-transaction'){if(this.store){this.store.gold=message.gold;this.store.lastTransaction={itemId:message.itemId};}return true;}
  if(message.kind==='sound-object')return this.applySoundObject(message);
  if(message.kind==='custom-token'){setCustomToken(this.customTokens,message.id,scriptStringBytes(message.text));return true;}
  if(message.kind==='tlk-overrides'){for(const {strRef,text}of message.entries){if(text.length)this.tlkOverrides.set(strRef,text);else this.tlkOverrides.delete(strRef);}if(message.entries.length)this.tlkOverrideVersion++;return true;}
  if(message.kind==='container-status'){const channel=message.primary?'C':'c';this.containers.set(channel,message.targetId);this.inventories.set(channel,{entries:[],pageCount:1,ownerId:message.targetId});return true;}
  if(message.kind==='examine'){if(message.type==='item'&&!message.close){const item=this.registry.get(message.targetId)?.item;if(item){item.identified=message.identified;if(message.canUse!==undefined)item.canUse=message.canUse;}}return true;}
  if(message.kind==='gui-timing'){this.timing={...message,version:(this.timing?.version??0)+1};return true;}
  if(message.kind==='player-attitude'){const old=this.playerAttitudes.get(message.playerId)??{ownLikes:1,incomingLikes:1};this.playerAttitudes.set(message.playerId,{...old,...message,[(message.own??message.clear)?'ownLikes':'incomingLikes']:message.likes});return true;}
  if(message.kind==='map-pin-created'){this.mapPins.set(message.id,{...message});return true;}
  if(message.kind==='map-pin-enabled'){const pin=this.mapPins.get(message.id);if(pin)pin.enabled=message.enabled;return true;}
  if(message.kind==='map-pin-added'){
   const area=this.registry.get(this.areaId)?.state;if(!area)return false;
   area.playerMapPins=[...(area.playerMapPins??[]).filter(pin=>(pin.index>>>0)!==message.index),{index:message.index,text:message.text,position:[...message.position]}];return true;
  }
  if(message.kind==='journal'){
   const j=this.journal,m=message;if(m.operation===6)j.entries.set(m.entry.tag,{...m.entry});
   else if(m.operation===7)j.entries.delete(m.tag);
   else if(m.operation===8){const entry=j.entries.get(m.tag);if(entry)entry.picture=m.picture;}
   else if(m.operation===9){if(m.present){if(m.full)j.entries.clear();for(const e of m.entries){if(e.mask&0x4000)j.entries.delete(e.tag);else j.entries.set(e.tag,{...j.entries.get(e.tag),...e});}}j.loaded=true;}
   else if(m.operation===12)j.notification={title:m.title,quest:m.quest,changed:m.changed};
   else if(m.worldEntry)j.worldEntries.set(m.worldEntry.id,{...m.worldEntry});
   else if(m.operation===3)j.worldEntries.delete(m.worldId);
   else if(m.operation===4)for(const [id,e]of j.worldEntries)if(e.strRef===m.worldStrRef)j.worldEntries.delete(id);
   else if(m.operation===5)j.worldEntries.clear();return true;
  }
  if(message.kind==='party-list'){this.party=applyNetworkParty(this.party,message);this.partyListRevision++;return true;}
  if(message.kind==='quickbar')return this.applyQuickbar(message);
  if(message.kind==='module-info'){this.module=structuredClone(message.module);return true;}
  if(message.kind==='module-time'){Object.assign(this.time,message.changes);return true;}
  if(message.kind==='area-weather')return applyAreaWeather(this,message);
  if(message.kind==='area-wind')return applyAreaWind(this,message);
  if(message.kind==='object-control'){
   this.controls.set(message.playerId,message.objectId);
   // Original GameObjectUpdate/2 ->781380 sets the controlled ID through
   // 6acc50 before looking up the creature. Party/14 only updates a roster
   // entry: it must never steal local control or fabricate a creature proxy.
   if(message.major===5&&message.minor===2){if(this.localObjectId!==message.objectId)this.scriptTargeting=null;this.localObjectId=message.objectId;}
   return true;
  }
  if(message.kind==='player-list-all'||message.kind==='player-list-add'){
   const staged=stagePlayerRoster(message);
   if(message.kind==='player-list-all'){this.players.clear();this.controls.clear();this.playerRosterKnown=staged.complete;}
   for(const p of staged.rows){this.players.set(p.playerId,p);this.controls.set(p.playerId,p.objectId);}return true;
  }
   if(message.kind==='player-list-delete'){this.players.delete(message.playerId);this.controls.delete(message.playerId);this.playerAttitudes.delete(message.playerId);return true;}
  if(message.kind==='object-updates')return this.applyObjectUpdates(message.records,{complete:message.complete});
  if(message.kind!=='client-area')return false;
  try{
   const entry=structuredClone(message),area=entry.area,records=new Map();
   const stage=(id,type,data)=>{
    if(!Number.isInteger(id)||id<EXTERNAL_OBJECT||id>0xffffffff)throw new Error('Invalid server object ID in area information');
    const old=records.get(id)??this.registry.get(id);
    if(old&&old.objectType!==type)throw new Error('Conflicting server object types in area information');
    records.set(id,{...records.get(id),id,objectType:type,...data});
   };
   stage(area.id,GAME_OBJECT_TYPE.area,{state:area});
   for(const pin of area.mapPins)stage(pin.id,GAME_OBJECT_TYPE.waypoint,{areaId:area.id,mapPin:pin});
   for(const sound of area.sounds)stage(sound.id,GAME_OBJECT_TYPE.sound,{areaId:area.id,state:sound,nativeSoundHeight:sound.position[2]});
   for(const light of area.placeableLights)stage(light.id,GAME_OBJECT_TYPE.placeable,{areaId:area.id,lightState:light});
   for(const placeable of area.staticPlaceables)stage(placeable.id,GAME_OBJECT_TYPE.placeable,{areaId:area.id,staticState:placeable});
   // HandleServerToPlayerArea76d910 explicitly reattaches the existing
   // controlled creature and sets the transmitted entry pose. Subsequent
   // updates can omit an area bit and an A record for that same object.
   const controlled=this.registry.get(this.localObjectId);
   if(controlled?.objectType===GAME_OBJECT_TYPE.creature)stage(controlled.id,GAME_OBJECT_TYPE.creature,{areaId:area.id,replicationRemoved:false,replicated:{...controlled.replicated,position:[...entry.position],orientation:[nativeCosf(entry.facing),nativeSinf(entry.facing),0]}});
   // Validate all explicit IDs through the existing native-compatible table
   // before committing; a rejected record must not leave half an area loaded.
   const staged=new GameObjectArray({clientMode:true});
   for(const record of records.values())if(staged.addObjectAtPos(record.id,{...record}).status!==0)throw new Error('Server area object ID cannot be registered');
   // Native area teardown7e7770 stops/deletes its type16 objects before
   // loading the new area. Preserve unrelated creature/item/party proxies.
   const previousArea=this.registry.get(this.areaId)?.state;
   for(const old of [...this.registry.objects.values()])if(old.objectType===GAME_OBJECT_TYPE.sound&&old.areaId===this.areaId)this.registry.delete(old.id);
   if(previousArea?.sounds)previousArea.sounds=[];
   for(const record of records.values()){
    const old=this.registry.get(record.id);
    if(old)Object.assign(old,record);else this.registry.addObjectAtPos(record.id,record);
   }
   retireNetworkBarter(this);this.scriptTargeting=null;this.containers.clear();this.inventories.delete('C');this.inventories.delete('c');this.store=null;this.inventories.delete('M');this.mapPins=new Map(area.mapPins.map(pin=>[pin.id,{...pin}]));this.areaId=area.id;this.entry={loadingScreen:entry.loadingScreen,position:entry.position,facing:entry.facing,flag:entry.flag};this.time={...area.time};return true;
  }catch(error){this.onDiagnostic({code:'network.area-import-failed',reason:error.message});throw error;}
 }
 applySoundObject(message){
  const {operation,objectId}=message,old=this.registry.get(objectId),isSound=old?.objectType===GAME_OBJECT_TYPE.sound;
  if(operation===6){
   if(old){this.onDiagnostic({code:'network.sound-create-duplicate',reason:'Native sound create references an existing object',objectId});return false;}
   if(message.areaId!==this.areaId){this.onDiagnostic({code:'network.sound-create-wrong-area',reason:'Native sound create references another area',objectId,areaId:message.areaId});return false;}
   const sound=message.sound;if(sound.id!==objectId||!Number.isInteger(sound.id)||sound.id<EXTERNAL_OBJECT||sound.id>0xffffffff){this.onDiagnostic({code:'network.sound-create-invalid-id',reason:'Native sound create has inconsistent canonical IDs',objectId,packedId:sound.id});return false;}
   const record={id:sound.id,objectType:GAME_OBJECT_TYPE.sound,areaId:message.areaId,state:structuredClone(sound),nativeSoundHeight:sound.position[2]};
   if(this.registry.addExternalObject(sound.id,record).status!==0)throw new Error('Native sound object ID cannot be registered');const area=this.registry.get(this.areaId)?.state;if(area?.sounds)area.sounds.push(record.state);return true;
  }
  if(!isSound){if(operation===7)this.onDiagnostic({code:'network.sound-destroy-missing',reason:'Native sound destroy has no matching sound object',objectId});return false;}
  if(operation===2||operation===3)old.state.fields['308']=operation===2?1:0;
  else if(operation===4)old.state.fields['314']=message.volume;
  else if(operation===5){const position=message.position.map(Math.fround);position[2]=Math.fround(position[2]+Math.fround(old.nativeSoundHeight??old.state.position[2]));old.state.position=position;}
  else if(operation===7){this.registry.delete(objectId);const area=this.registry.get(old.areaId)?.state;if(area?.sounds)area.sounds=area.sounds.filter(s=>s.id!==objectId);}
  return true;
 }
 // Native inventory panel8562e0 clears its repository grid882700 before
 // requesting the new panel. This is GUI membership, not item destruction:
 // canonical objects and their last replicated metadata remain cached.
 clearRepositoryView(self=true){const view=this.inventories.get(self?'R':'r');if(view)view.entries=[];}
 // Native855d00/855be0 clear GUI membership before sending a page command.
 // Cached canonical items and their last metadata/locations survive this clear.
 clearContainerView(primary=true){const view=this.inventories.get(primary?'C':'c');if(view)view.entries=[];}
 applyQuickbar(message){
  const buttons=structuredClone(this.quickbar),items=new Map();
  for(const entry of message.entries){
   if(!Number.isInteger(entry.index)||entry.index<0||entry.index>=36)throw new Error('Invalid replicated quickbar index');
   Object.assign(buttons[entry.index],structuredClone(entry.button));if(entry.button.type===0)buttons[entry.index].intParam=0;
   for(const value of entry.items){
    if(!Number.isInteger(value.id)||value.id<EXTERNAL_OBJECT||value.id>0xffffffff)throw new Error('Invalid quickbar item identity');
    const old=items.get(value.id)??this.registry.get(value.id);if(old&&old.objectType!==GAME_OBJECT_TYPE.item)throw new Error('Conflicting quickbar item type');
    const o=old?structuredClone(old):{id:value.id,objectType:GAME_OBJECT_TYPE.item,areaId:OBJECT_INVALID,replicated:{}};
    o.item=mergeNetworkItem(o.item,value.item);o.replicationRemoved=false;items.set(o.id,o);
   }
  }
  const validation=new GameObjectArray({clientMode:true});for(const o of items.values())if(validation.addObjectAtPos(o.id,{...o}).status!==0)throw new Error('Quickbar item ID cannot be registered');
  for(const o of items.values()){const old=this.registry.get(o.id);if(old)Object.assign(old,o);else this.registry.addObjectAtPos(o.id,o);}this.quickbar=buttons;return true;
 }
 bindNativeClockConnection(connection){return this.#clockLifecycle.bindConnection(this,connection);}
 nativeClockLifecycleHistory(){return {...this.#clockLifecycle.history(this),observerFailures:this.#clockLifecycleFailures};}
 nativeClockLifecycleState(object){
  if(!object||this.registry.get(object.id)!==object)return null;
  return this.#clockLifecycle.stateFor(this,object);
 }
 nativeClockOwnerTransport(object){
  const value=this.nativeClockLifecycleState(object);if(!value)return null;
  // Client presentation provenance, not received server fields. Historical
  // physical tokens after D are deliberately not current lookup handles.
  return {version:1,source:'native-client-clock-owner-v1',epoch:value.epoch,connection:value.connection,physicalCurrent:value.physicalCurrent,physicalToken:value.physicalCurrent?value.physicalToken:null};
 }
 nativeClockLifecycleBoundaries(records){return this.#clockLifecycleRecords.get(records)??null;}
 nativeClockLifecycleBoundary(boundary){return this.#clockLifecycle.acceptedBoundary(this,boundary);}
 nativeActorNameFor(object){
  if(!object||object.objectType!==GAME_OBJECT_TYPE.creature||this.registry.get(object.id)!==object)return null;
  const value=this.#actorNameStates.get(object);return value?structuredClone(value):null;
 }
 nativeActorNameTransport(object){
  // Internal raw transport can borrow immutable metadata. Public reads above
  // remain detached; unchanged names need no deep copy on every world frame.
  if(!object||object.objectType!==GAME_OBJECT_TYPE.creature||this.registry.get(object.id)!==object)return null;
  return this.#actorNameStates.get(object)??null;
 }
 nativeActorNameHistory(){return {version:1,complete:this.#actorNameHistoryComplete};}
 nativeActorNameSequence(){return this.#actorNameSequence;}
 applyObjectUpdates(records,protocol={}){
  const staged=new Map(),actorNames=new Map(),events=[],inventories=structuredClone(this.inventories);let localObjectId=this.localObjectId;
  let clockTracked=false,clockPrepared=false;
  const rejectClock=()=>{
   this.#clockLifecycleFailures=Math.min(Number.MAX_SAFE_INTEGER,this.#clockLifecycleFailures+1);
   this.#clockLifecycle.abort(staged,'world-clock-observer-rejected');clockTracked=false;clockPrepared=false;
  };
  const historyComplete=this.#actorNameHistoryComplete&&protocol.complete===true;
  let actorNameSequence=this.#actorNameSequence;
  const stageActorName=(record,hadProxy)=>{
   if(typeof protocol.complete!=='boolean')return; // Untracked callers cannot certify native history.
   if(record.objectType!==GAME_OBJECT_TYPE.creature||!['create','delete','appearance'].includes(record.action))return;
   if(record.action==='appearance'&&!Object.hasOwn(record.state??{},'name'))return;
   const old=this.registry.get(record.id),current=actorNames.has(record.id)?actorNames.get(record.id):this.#actorNameStates.get(old)??null;
   const typedOwner=current?.presence==='present'?'present':!hadProxy&&historyComplete?'absent':'unknown';
   if(actorNameSequence>=Number.MAX_SAFE_INTEGER)throw Error('Native actor-name sequence exhausted');
   const next=stageNativeActorName(current,record,{sequence:++actorNameSequence,typedOwner,historyComplete},{overrides:this.tlkOverrides,customTokens:this.customTokens});
   actorNames.set(record.id,next);
  };
  const object=(id,type)=>{
   if(!Number.isInteger(id)||id<EXTERNAL_OBJECT||id>0xffffffff||!Object.values(GAME_OBJECT_TYPE).includes(type))throw new Error('Invalid replicated object identity');
   let o=staged.get(id);if(o){if(o.objectType!==type)throw new Error('Conflicting replicated object type');return o;}
   const old=this.registry.get(id);if(old&&old.objectType!==type)throw new Error('Conflicting replicated object type');
   o=old?structuredClone(old):{id,objectType:type,areaId:this.areaId,replicated:{}};o.replicated??={};staged.set(id,o);return o;
  };
  const observeClock=(record,index,proxy=null,alreadyStaged=false)=>{
   if(!clockTracked)return;
   try{
    let boundary={};
    if(record.objectType===GAME_OBJECT_TYPE.creature){
     const canonical=this.registry.get(record.id)??null;
     const privateOwner=canonical?this.#clockLifecycle.stateFor(this,canonical):null;
     // Only the known registry epoch plus an absent typed admission permits a
     // fresh proof. A generic proxy or retained D never supplies one.
     const externalOwner=privateOwner?.physicalCurrent&&privateOwner.presence==='live'?'live':canonical===null&&!alreadyStaged?'absent':'unknown';
     boundary={canonicalBefore:canonical,stagedProxy:proxy,externalOwner,areaId:record.state?.areaId??proxy?.areaId??this.areaId};
    }
    this.#clockLifecycle.observe(staged,record,index,boundary);
   }catch{rejectClock();}
  };
  try{
   try{this.#clockLifecycle.begin(staged,{complete:protocol.complete===true,recordCount:records.length});clockTracked=true;}catch{rejectClock();}
   let clockRecordIndex=0;
   for(const record of records){
    const clockIndex=clockRecordIndex++,clockDeferred=record.objectType===GAME_OBJECT_TYPE.creature&&!['work-remaining','item-use-counts','inventory'].includes(record.action);
    if(!clockDeferred)observeClock(record,clockIndex);
    if(record.action==='work-remaining'){events.push(structuredClone(record));continue;}
    if(record.action==='item-use-counts'){
     for(const entry of record.entries){const old=staged.get(entry.id)??this.registry.get(entry.id);if(!old||old.objectType!==GAME_OBJECT_TYPE.item||old.replicationRemoved)continue;const o=object(entry.id,GAME_OBJECT_TYPE.item);if(o.item){const kind=applyClientItemUses(o.item,entry);events.push({action:'item-use-count',...entry,kind});}}
     continue;
    }
    if(record.action==='inventory'){
     const {channel,operation}=record,existing=inventories.has(channel),view=inventories.get(channel)??{entries:[]};inventories.set(channel,view);
     // Uppercase R/I/C belong to the primary GUI; lowercase variants are
     // a separate associate GUI. Do not infer an associate owner from names.
     const ownerId=['C','c'].includes(channel)?this.containers.get(channel)??null:['R','I'].includes(channel)?localObjectId:['r','i'].includes(channel)?this.inventoryWindows.alternateOwner(this):this.barter?.open&&channel==='B'?localObjectId:this.barter?.open&&channel==='A'?this.barter.partnerId:null;
     if(!existing&&ownerId===null&&channel!=='M')events.push({action:'inventory-owner-unavailable',channel});
     if(record.pageCount!==undefined){view.pageCount=record.pageCount;if(record.panel!==undefined)view.panel=record.panel;continue;}
     if(record.state){view.stats={...view.stats,...structuredClone(record.state)};if(ownerId!==null)Object.assign(object(ownerId,GAME_OBJECT_TYPE.creature).inventoryStats??={},structuredClone(record.state));continue;}
     const key=channel.toUpperCase()==='I'?'slot':'id',index=view.entries.findIndex(e=>e[key]===record[key]);
     if(operation==='D'){
      const old=index>=0?view.entries.splice(index,1)[0]:null;
      if(old){const item=object(old.id,GAME_OBJECT_TYPE.item);if(item.inventoryLocation?.channel===channel)item.inventoryLocation=null;}
     }else if(operation==='A'){
      const item=object(record.id,GAME_OBJECT_TYPE.item);item.item=mergeNetworkItem(item.item,record.item);item.replicationRemoved=false;item.areaId=OBJECT_INVALID;if(!['I','i'].includes(channel))item.equipmentOwnerId=null;
      item.inventoryLocationStatus='current';
      if(channel==='I'){item.inventoryEquipmentSlot=record.slot;const actor=staged.get(ownerId)??this.registry.get(ownerId);if(actor?.objectType===GAME_OBJECT_TYPE.creature)setClientEquipmentSlot(object(ownerId,GAME_OBJECT_TYPE.creature),record.slot,item,id=>{const old=staged.get(id)??this.registry.get(id);return old?.objectType===GAME_OBJECT_TYPE.item?object(id,GAME_OBJECT_TYPE.item):null;});}
      const displaced=index>=0?view.entries[index]:null;
      if(displaced&&displaced.id!==record.id){const previous=object(displaced.id,GAME_OBJECT_TYPE.item);if(previous.inventoryLocation?.channel===channel)previous.inventoryLocation=null;}
      const group=channel===channel.toUpperCase()?['R','I','C','M','A','B']:['r','i','c'];
      if(group.includes(channel))for(const c of group){const v=inventories.get(c);if(v)v.entries=v.entries.filter(e=>e.id!==record.id&&(c!==channel||e[key]!==record[key]));}
      else view.entries=view.entries.filter(e=>e.id!==record.id&&e[key]!==record[key]);
      item.inventoryLocation={channel,ownerId,...(record.slot!==undefined?{slot:record.slot}:{x:record.x,y:record.y})};view.entries.push({id:record.id,...(record.slot!==undefined?{slot:record.slot}:{x:record.x,y:record.y})});
     }else if(operation==='U'||operation==='M'){
      const item=object(record.id,GAME_OBJECT_TYPE.item);
      if(record.stackSize!==undefined){item.item??={};item.item.stackSize=record.stackSize;item.item.field280=record.field280;item.item.cost=record.field280;}
      if(record.x!==undefined&&index>=0){Object.assign(view.entries[index],{x:record.x,y:record.y});item.inventoryLocation={channel,ownerId,x:record.x,y:record.y};item.inventoryLocationStatus='current';}
     }else throw new Error('Unsupported replicated inventory operation');
     continue;
    }
    if(record.action==='delete'&&!staged.has(record.id)&&!this.registry.get(record.id)){if(clockDeferred)observeClock(record,clockIndex);events.push(structuredClone(record));continue;}
    const hadProxy=staged.has(record.id)||Boolean(this.registry.get(record.id));
    const o=object(record.id,record.objectType);
    if(clockDeferred)observeClock(record,clockIndex,o,hadProxy);
    stageActorName(record,hadProxy);
    if(record.action==='delete'){
     // Preserve native deletion flag verbatim pending client-side cleanup
     // ownership. Renderers can remove the visual on this explicit event.
     // Explicit null survives Object.assign into the retained proxy at commit;
     // deleting a staged property would leave its old live value behind.
     o.clientSkillAdmission=null;o.replicationRemoved=true;o.deletionFlag=record.remove;events.push(structuredClone(record));continue;
    }
    if(record.action==='create'){
     if(o.replicationRemoved)o.clientSkillAdmission=null;
     o.replicationRemoved=false;
     // Original A/type6 dispatch7b23e0 ->79fe30(param2=0) attaches an
     // existing inventory item to the current client area. The server can
     // reuse that ID and omit a separate area field in the following U.
     if(o.objectType===GAME_OBJECT_TYPE.item){o.areaId=this.areaId;o.inventoryLocation=null;o.inventoryLocationStatus='current';o.equipmentOwnerId=null;if(record.state?.item)o.item=mergeNetworkItem(o.item,record.state.item);for(const view of inventories.values())view.entries=view.entries.filter(e=>e.id!==o.id);}
    }
    const state=structuredClone(record.state);
    if(record.action==='player-state'){if(Object.hasOwn(state,'skillFlags'))o.clientSkillAdmission=mergeNativeSkillAdmission(o.clientSkillAdmission,state,'player');o.playerState=applyPlayerState(o.playerState,state);if(state.automap){const area=this.registry.get(this.areaId)?.state;if(!area)throw new Error('Native automap area is unavailable');o.playerState.mapExploration??={};o.playerState.mapExploration[this.areaId]=applyNetworkAutomap(o.playerState.mapExploration[this.areaId],state.automap,area.width,area.height);}if(state.abilities)o.clientAbilityCache=mergeNetworkAbilityCache(o.clientAbilityCache,state,'player');localObjectId=record.id;}
    else if(record.action==='inventory-stats'){
     o.inventoryStats??={};
     // Use the incoming ordered flags, before raw inventory's sticky merge.
     if(Object.hasOwn(state,'skills'))o.clientSkillAdmission=mergeNativeSkillAdmission(o.clientSkillAdmission,state,'inventory');
     if(state.fields70||state.fields76||state.fields7d)o.clientAbilityCache=mergeNetworkAbilityCache(o.clientAbilityCache,state,'stats');
     if(state.skills){const skills=new Map(o.inventoryStats.skills?.map(v=>[v.index,v]));for(const v of state.skills)skills.set(v.index,{...v,flag:v.flag||skills.get(v.index)?.flag||0});state.skills=[...skills.values()];}
     if(state.featsRemoved||state.featsAdded){const feats=new Map(o.inventoryStats.feats?.map(v=>[v.id,v]));for(const id of state.featsRemoved??[])feats.delete(id);for(const v of state.featsAdded??[])feats.set(v.id,v);state.feats=[...feats.values()];delete state.featsRemoved;delete state.featsAdded;}
     Object.assign(o.inventoryStats,state);
    }
    else if(record.action==='appearance'){
     o.appearance??={};
     for(const e of state.equipment??[])if(e.action==='A')e.item=mergeNetworkItem((staged.get(e.id)??this.registry.get(e.id))?.item,e.item);
     if(state.bodyParts){const parts=new Map(o.appearance.bodyParts?.map(p=>[p.index,p.value]));for(const p of state.bodyParts)parts.set(p.index,p.value);state.bodyParts=[...parts].sort((a,b)=>a[0]-b[0]).map(([index,value])=>({index,value}));}
     if(state.equipment){
      const equipment=new Map(o.appearance.equipment?.map(e=>[e.slot,e]));
      for(const e of state.equipment){
       if(e.action==='D'){equipment.delete(e.slot);setClientEquipmentSlot(o,e.slot,null,id=>{const old=staged.get(id)??this.registry.get(id);return old?.objectType===GAME_OBJECT_TYPE.item?object(id,GAME_OBJECT_TYPE.item):null;});}
       else if(e.action==='A'){equipment.set(e.slot,e);const item=object(e.id,GAME_OBJECT_TYPE.item);item.item=e.item;item.areaId=OBJECT_INVALID;setClientEquipmentSlot(o,e.slot,item,id=>{const old=staged.get(id)??this.registry.get(id);return old?.objectType===GAME_OBJECT_TYPE.item?object(id,GAME_OBJECT_TYPE.item):null;});}
       else if(e.action==='U'){
        // Native77fe10 looks up the existing item. It never creates an item,
        // equips a different ID, or changes ownership for this visual delta.
        const old=staged.get(e.id)??this.registry.get(e.id);
        if(old?.objectType!==GAME_OBJECT_TYPE.item)continue;
        const item=object(e.id,GAME_OBJECT_TYPE.item);item.item=mergeNetworkItem(item.item,e.item);
        for(const [slot,entry]of equipment)if(entry.id===e.id)equipment.set(slot,{...entry,item:item.item});
       }else throw new Error('Unsupported replicated equipment change');
      }
      state.equipment=[...equipment.values()];
     }
     Object.assign(o.appearance,state);
    }else{
     // Looping effects are change records, not a replacement effect list.
     if(state.visualEffects){events.push({action:'visual-effects',id:o.id,changes:state.visualEffects});delete state.visualEffects;}
     // Attack groups are delivered on every update, even when the base WORD
     // and speed FLOAT match the preceding round. Presentation consumes these
     // events; retaining a group as ordinary state would replay stale attacks.
     if(o.objectType===GAME_OBJECT_TYPE.creature&&state.animation!==undefined){
      if(state.animationTime!==undefined)state.animationSpeed=state.animationTime;
      // Native A only discloses the initial animation WORD. Timed attack
      // groups belong to U/mask4; a newly visible attacking actor has none.
      if(state.animation===9&&record.action!=='create'){events.push({action:'attack-animation',id:o.id,animation:9,speed:state.animationTime,records:networkAttackAnimationRecords(o.id,state.attacks)});delete state.attacks;}
      else if(networkCastReleaseBase(state.animation)!==null&&state.cast)events.push({action:'cast-animation',id:o.id,animation:state.animation,record:networkCastAnimationRecord(state.cast)});
     }
     if(o.objectType===GAME_OBJECT_TYPE.creature&&['position','orientation','facingTarget','animation','path','walkRate','runRate'].some(key=>state[key]!==undefined))events.push({action:'movement',id:o.id,created:record.action==='create',changes:Object.fromEntries(['position','orientation','facingTarget','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'].filter(key=>state[key]!==undefined).map(key=>[key,structuredClone(state[key])]))});
     Object.assign(o.replicated,state);
     // Original item primary+16c/+170 and object subobject+124/+128 are the
     // same storage. Retain the latest received value across G/A/U and24/5.
     if(o.objectType===GAME_OBJECT_TYPE.item&&state.light?.field270!==undefined){o.item??={};o.item.field2b8=state.light.field270;o.item.field2c0=state.light.field278;}
     if(o.objectType===GAME_OBJECT_TYPE.creature)applyNetworkAssociateState(o,state,id=>{const owner=staged.get(id)??this.registry.get(id);return owner?.objectType===GAME_OBJECT_TYPE.creature&&!owner.replicationRemoved?object(id,GAME_OBJECT_TYPE.creature):null;});
     if(o.objectType===10&&state.animation!==undefined){const open=applyNetworkDoorOpenState(o.replicated.doorOpenState,state.animation,record.action==='create');if(open!==undefined&&open!==null)o.replicated.doorOpenState=open;}
     if(state.areaId!==undefined)o.areaId=state.areaId;
    }
   }
   const validation=new GameObjectArray({clientMode:true});for(const o of staged.values())if(validation.addObjectAtPos(o.id,{...o}).status!==0)throw new Error('Replicated object ID cannot be registered');
   // All observer validation and canonical identity resolution precede the
   // existing canonical assignments. Observer failure cannot reject gameplay.
   if(clockTracked){try{this.#clockLifecycle.commit(staged,id=>this.registry.get(id)??staged.get(id)??null);clockPrepared=true;}catch{rejectClock();}}
   for(const o of staged.values()){
    const old=this.registry.get(o.id);if(old)Object.assign(old,o);else this.registry.addObjectAtPos(o.id,o);
    if(actorNames.has(o.id)){
     const canonical=old??o,value=actorNames.get(o.id);
     if(value)this.#actorNameStates.set(canonical,immutableActorName(structuredClone(value)));else this.#actorNameStates.delete(canonical);
    }
   }
   if(clockPrepared){const boundaries=this.#clockLifecycle.publish(staged);if(boundaries!==null)this.#clockLifecycleRecords.set(records,boundaries);else rejectClock();}
   this.#actorNameSequence=actorNameSequence;this.#actorNameHistoryComplete=historyComplete;
   this.inventories=inventories;this.presentationChanges=events;if(this.localObjectId!==localObjectId){this.scriptTargeting=null;retireNetworkBarter(this);}this.localObjectId=localObjectId;
   for(const event of events)if(event.action==='inventory-owner-unavailable')this.onDiagnostic({code:'network.inventory-owner-unavailable',reason:'Native inventory GUI owner binding is unavailable',channel:event.channel});this.entityDisclosures.observeAccepted(records,this.registry);return true;
  }catch(error){if(clockTracked||clockPrepared)rejectClock();this.#actorNameHistoryComplete=false;this.onDiagnostic({code:'network.object-import-failed',reason:error.message});throw error;}
 }
 snapshot(){return{areaId:this.areaId,localObjectId:this.localObjectId,entry:structuredClone(this.entry),time:{...this.time},objects:this.registry.objects.size,controls:[...this.controls].map(([playerId,objectId])=>({playerId,objectId}))};}
}
