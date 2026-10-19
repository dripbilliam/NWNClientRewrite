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
import {applyNetworkAutomap} from './network_automap.js';

// A connection owns its client proxies. No ModuleSession, script VM, AI,
// combat resolver or ID allocator runs when importing server state.
export class NetworkWorld {
 constructor({onDiagnostic=d=>runtimeDiagnostics.record(d.code,d.reason,d)}={}){this.onDiagnostic=onDiagnostic;this.reset();}
 reset(){this.registry=new GameObjectArray({clientMode:true});this.module=null;this.areaId=OBJECT_INVALID;this.entry=null;this.time={};this.controls=new Map();this.players=new Map();this.party=[];this.inventories=new Map();this.quickbar=Array.from({length:36},emptyQuickbarButton);this.presentationChanges=[];this.localObjectId=OBJECT_INVALID;this.journal={entries:new Map(),worldEntries:new Map(),loaded:false};this.playerAttitudes=new Map();this.mapPins=new Map();this.timing=null;}
 apply(message){
  if(message.kind==='examine'){if(message.type==='item'&&!message.close){const item=this.registry.get(message.targetId)?.item;if(item){item.identified=message.identified;if(message.canUse!==undefined)item.canUse=message.canUse;}}return true;}
  if(message.kind==='gui-timing'){this.timing={...message,version:(this.timing?.version??0)+1};return true;}
  if(message.kind==='player-attitude'){if(message.clear)this.playerAttitudes.clear();else this.playerAttitudes.set(message.playerId,{...message});return true;}
  if(message.kind==='map-pin-created'){this.mapPins.set(message.id,{...message});return true;}
  if(message.kind==='map-pin-enabled'){const pin=this.mapPins.get(message.id);if(pin)pin.enabled=message.enabled;return true;}
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
  if(message.kind==='party-list'){this.party=applyNetworkParty(this.party,message);return true;}
  if(message.kind==='quickbar')return this.applyQuickbar(message);
  if(message.kind==='module-info'){this.module=structuredClone(message.module);return true;}
  if(message.kind==='module-time'){Object.assign(this.time,message.changes);return true;}
  if(message.kind==='object-control'){this.controls.set(message.playerId,message.objectId);return true;}
  if(message.kind==='player-list-all'||message.kind==='player-list-add'){
   if(message.kind==='player-list-all'){this.players.clear();this.controls.clear();}
   for(const p of message.players){this.players.set(p.playerId,structuredClone(p));this.controls.set(p.playerId,p.objectId);}return true;
  }
  if(message.kind==='player-list-delete'){this.players.delete(message.playerId);this.controls.delete(message.playerId);return true;}
  if(message.kind==='object-updates')return this.applyObjectUpdates(message.records);
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
   for(const sound of area.sounds)stage(sound.id,GAME_OBJECT_TYPE.sound,{areaId:area.id,state:sound});
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
   for(const record of records.values()){
    const old=this.registry.get(record.id);
    if(old)Object.assign(old,record);else this.registry.addObjectAtPos(record.id,record);
   }
   this.mapPins=new Map(area.mapPins.map(pin=>[pin.id,{...pin}]));this.areaId=area.id;this.entry={loadingScreen:entry.loadingScreen,position:entry.position,facing:entry.facing,flag:entry.flag};this.time={...area.time};return true;
  }catch(error){this.onDiagnostic({code:'network.area-import-failed',reason:error.message});throw error;}
 }
 // Native inventory panel8562e0 clears its repository grid882700 before
 // requesting the new panel. This is GUI membership, not item destruction:
 // canonical objects and their last replicated metadata remain cached.
 clearRepositoryView(self=true){const view=this.inventories.get(self?'R':'r');if(view)view.entries=[];}
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
 applyObjectUpdates(records){
  const staged=new Map(),events=[],inventories=structuredClone(this.inventories);let localObjectId=this.localObjectId;
  const object=(id,type)=>{
   if(!Number.isInteger(id)||id<EXTERNAL_OBJECT||id>0xffffffff||!Object.values(GAME_OBJECT_TYPE).includes(type))throw new Error('Invalid replicated object identity');
   let o=staged.get(id);if(o){if(o.objectType!==type)throw new Error('Conflicting replicated object type');return o;}
   const old=this.registry.get(id);if(old&&old.objectType!==type)throw new Error('Conflicting replicated object type');
   o=old?structuredClone(old):{id,objectType:type,areaId:this.areaId,replicated:{}};o.replicated??={};staged.set(id,o);return o;
  };
  try{
   for(const record of records){
    if(record.action==='work-remaining'){events.push(structuredClone(record));continue;}
    if(record.action==='item-use-counts'){
     for(const entry of record.entries){const old=staged.get(entry.id)??this.registry.get(entry.id);if(!old||old.objectType!==GAME_OBJECT_TYPE.item||old.replicationRemoved)continue;const o=object(entry.id,GAME_OBJECT_TYPE.item);if(o.item){const kind=applyClientItemUses(o.item,entry);events.push({action:'item-use-count',...entry,kind});}}
     continue;
    }
    if(record.action==='inventory'){
     const {channel,operation}=record,existing=inventories.has(channel),view=inventories.get(channel)??{entries:[]};inventories.set(channel,view);
     // Uppercase R/I/C belong to the primary GUI; lowercase variants are
     // a separate associate GUI. Do not infer an associate owner from names.
     const ownerId=['R','I','C'].includes(channel)?localObjectId:null;
     if(!existing&&ownerId===null)events.push({action:'inventory-owner-unavailable',channel});
     if(record.page!==undefined){view.page=record.page;continue;}
     if(record.state){view.stats={...view.stats,...structuredClone(record.state)};if(ownerId!==null)Object.assign(object(ownerId,GAME_OBJECT_TYPE.creature).inventoryStats??={},structuredClone(record.state));continue;}
     const key=channel.toUpperCase()==='I'?'slot':'id',index=view.entries.findIndex(e=>e[key]===record[key]);
     if(operation==='D'){
      const old=index>=0?view.entries.splice(index,1)[0]:null;
      if(old){const item=object(old.id,GAME_OBJECT_TYPE.item);if(item.inventoryLocation?.channel===channel)item.inventoryLocation=null;}
     }else if(operation==='A'){
      const item=object(record.id,GAME_OBJECT_TYPE.item);item.item=mergeNetworkItem(item.item,record.item);item.replicationRemoved=false;item.areaId=OBJECT_INVALID;item.equipmentOwnerId=channel==='I'?ownerId:null;
      const displaced=index>=0?view.entries[index]:null;
      if(displaced&&displaced.id!==record.id){const previous=object(displaced.id,GAME_OBJECT_TYPE.item);if(previous.inventoryLocation?.channel===channel)previous.inventoryLocation=null;}
      const group=channel===channel.toUpperCase()?['R','I','C']:['r','i','c'];
      if(group.includes(channel))for(const c of group){const v=inventories.get(c);if(v)v.entries=v.entries.filter(e=>e.id!==record.id&&(c!==channel||e[key]!==record[key]));}
      else view.entries=view.entries.filter(e=>e.id!==record.id&&e[key]!==record[key]);
      item.inventoryLocation={channel,ownerId,...(record.slot!==undefined?{slot:record.slot}:{x:record.x,y:record.y})};view.entries.push({id:record.id,...(record.slot!==undefined?{slot:record.slot}:{x:record.x,y:record.y})});
     }else if(operation==='U'||operation==='M'){
      const item=object(record.id,GAME_OBJECT_TYPE.item);
      if(record.stackSize!==undefined){item.item??={};item.item.stackSize=record.stackSize;item.item.field280=record.field280;}
      if(record.x!==undefined&&index>=0){Object.assign(view.entries[index],{x:record.x,y:record.y});item.inventoryLocation={channel,ownerId,x:record.x,y:record.y};}
     }else throw new Error('Unsupported replicated inventory operation');
     continue;
    }
    if(record.action==='delete'&&!staged.has(record.id)&&!this.registry.get(record.id)){events.push(structuredClone(record));continue;}
    const o=object(record.id,record.objectType);
    if(record.action==='delete'){
     // Preserve native deletion flag verbatim pending client-side cleanup
     // ownership. Renderers can remove the visual on this explicit event.
     o.replicationRemoved=true;o.deletionFlag=record.remove;events.push(structuredClone(record));continue;
    }
    if(record.action==='create'){
     o.replicationRemoved=false;
     // Original A/type6 dispatch7b23e0 ->79fe30(param2=0) attaches an
     // existing inventory item to the current client area. The server can
     // reuse that ID and omit a separate area field in the following U.
     if(o.objectType===GAME_OBJECT_TYPE.item){o.areaId=this.areaId;o.inventoryLocation=null;o.equipmentOwnerId=null;if(record.state?.item)o.item=mergeNetworkItem(o.item,record.state.item);for(const view of inventories.values())view.entries=view.entries.filter(e=>e.id!==o.id);}
    }
    const state=structuredClone(record.state);
    if(record.action==='player-state'){o.playerState=applyPlayerState(o.playerState,state);if(state.automap){const area=this.registry.get(this.areaId)?.state;if(!area)throw new Error('Native automap area is unavailable');o.playerState.mapExploration??={};o.playerState.mapExploration[this.areaId]=applyNetworkAutomap(o.playerState.mapExploration[this.areaId],state.automap,area.width,area.height);}if(state.abilities)o.clientAbilityCache=mergeNetworkAbilityCache(o.clientAbilityCache,state,'player');localObjectId=record.id;}
    else if(record.action==='inventory-stats'){
     o.inventoryStats??={};
     if(state.fields70||state.fields76||state.fields7d)o.clientAbilityCache=mergeNetworkAbilityCache(o.clientAbilityCache,state,'stats');
     if(state.skills){const skills=new Map(o.inventoryStats.skills?.map(v=>[v.index,v]));for(const v of state.skills)skills.set(v.index,{...v,flag:v.flag||skills.get(v.index)?.flag||0});state.skills=[...skills.values()];}
     if(state.featsRemoved||state.featsAdded){const feats=new Map(o.inventoryStats.feats?.map(v=>[v.id,v]));for(const id of state.featsRemoved??[])feats.delete(id);for(const v of state.featsAdded??[])feats.set(v.id,v);state.feats=[...feats.values()];delete state.featsRemoved;delete state.featsAdded;}
     Object.assign(o.inventoryStats,state);
    }
    else if(record.action==='appearance'){
     o.appearance??={};
     for(const e of state.equipment??[])if(e.action==='A')e.item=mergeNetworkItem((staged.get(e.id)??this.registry.get(e.id))?.item,e.item);
     if(state.bodyParts){const parts=new Map(o.appearance.bodyParts?.map(p=>[p.index,p.value]));for(const p of state.bodyParts)parts.set(p.index,p.value);state.bodyParts=[...parts].sort((a,b)=>a[0]-b[0]).map(([index,value])=>({index,value}));}
     if(state.equipment){const equipment=new Map(o.appearance.equipment?.map(e=>[e.slot,e]));for(const e of state.equipment){if(e.action==='D'){const previous=equipment.get(e.slot);equipment.delete(e.slot);const id=e.id>=EXTERNAL_OBJECT?e.id:previous?.id;if(id!==undefined&&(staged.has(id)||this.registry.get(id))){const item=object(id,GAME_OBJECT_TYPE.item);if(item.equipmentOwnerId===o.id)item.equipmentOwnerId=null;}}else if(e.action==='A'){equipment.set(e.slot,e);const item=object(e.id,GAME_OBJECT_TYPE.item);item.item=e.item;item.areaId=OBJECT_INVALID;item.equipmentOwnerId=o.id;}else throw new Error('Unsupported replicated equipment change');}state.equipment=[...equipment.values()];}
     Object.assign(o.appearance,state);
    }else{
     // Looping effects are change records, not a replacement effect list.
     if(state.visualEffects){events.push({action:'visual-effects',id:o.id,changes:state.visualEffects});delete state.visualEffects;}
     // Attack groups are delivered on every update, even when the base WORD
     // and speed FLOAT match the preceding round. Presentation consumes these
     // events; retaining a group as ordinary state would replay stale attacks.
     if(o.objectType===GAME_OBJECT_TYPE.creature&&state.animation!==undefined){
      if(state.animationTime!==undefined)state.animationSpeed=state.animationTime;
      if(state.animation===9){events.push({action:'attack-animation',id:o.id,animation:9,speed:state.animationTime,records:networkAttackAnimationRecords(o.id,state.attacks)});delete state.attacks;}
      else if(networkCastReleaseBase(state.animation)!==null&&state.cast)events.push({action:'cast-animation',id:o.id,animation:state.animation,record:networkCastAnimationRecord(state.cast)});
     }
     if(o.objectType===GAME_OBJECT_TYPE.creature&&['position','orientation','animation','path','walkRate','runRate'].some(key=>state[key]!==undefined))events.push({action:'movement',id:o.id,created:record.action==='create',changes:Object.fromEntries(['position','orientation','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'].filter(key=>state[key]!==undefined).map(key=>[key,structuredClone(state[key])]))});
     Object.assign(o.replicated,state);
     if(o.objectType===GAME_OBJECT_TYPE.creature)applyNetworkAssociateState(o,state,id=>{const owner=staged.get(id)??this.registry.get(id);return owner?.objectType===GAME_OBJECT_TYPE.creature&&!owner.replicationRemoved?object(id,GAME_OBJECT_TYPE.creature):null;});
     if(o.objectType===10&&state.animation!==undefined){const open=applyNetworkDoorOpenState(o.replicated.doorOpenState,state.animation,record.action==='create');if(open!==undefined&&open!==null)o.replicated.doorOpenState=open;}
     if(state.areaId!==undefined)o.areaId=state.areaId;
    }
   }
   const validation=new GameObjectArray({clientMode:true});for(const o of staged.values())if(validation.addObjectAtPos(o.id,{...o}).status!==0)throw new Error('Replicated object ID cannot be registered');
   for(const o of staged.values()){const old=this.registry.get(o.id);if(old)Object.assign(old,o);else this.registry.addObjectAtPos(o.id,o);}this.inventories=inventories;this.presentationChanges=events;this.localObjectId=localObjectId;
   for(const event of events)if(event.action==='inventory-owner-unavailable')this.onDiagnostic({code:'network.inventory-owner-unavailable',reason:'Native inventory GUI owner binding is unavailable',channel:event.channel});return true;
  }catch(error){this.onDiagnostic({code:'network.object-import-failed',reason:error.message});throw error;}
 }
 snapshot(){return{areaId:this.areaId,localObjectId:this.localObjectId,entry:structuredClone(this.entry),time:{...this.time},objects:this.registry.objects.size,controls:[...this.controls].map(([playerId,objectId])=>({playerId,objectId}))};}
}
