import {EventEmitter} from 'node:events';
import {decodeServerGameMessage,serverStatusRequest,moduleReadyRequest,clientAreaReadyRequest} from '../src/network_game_messages.js';
import {resolveServerResources} from '../src/network_resources.js';
import {characterBlobRequest} from '../src/network_character.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {NetworkWorld} from '../src/network_world.js';
import {parseGff} from '../src/gff.js';
import {isNetworkBytes} from '../src/network_bytes.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {networkDoorClickState} from '../src/network_door.js';
import {quickbarAssignmentRequest} from '../src/network_quickbar.js';
import {emptyQuickbarButton} from '../src/quickbar.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {spellCastRequest,spellLikeCastRequest,spellPreparationRequest,spellPreparationClearRequest} from '../src/network_spell_input.js';
import {itemUseRequest} from '../src/network_item_input.js';
import {restRequest,characterSheetRequest,journalWindowRequest,playerAttitudeRequest} from '../src/network_hud_input.js';
import {featUseRequest,modeChangeRequest,possessFamiliarRequest} from '../src/network_feat_input.js';
import {associateCommandRequest,quickChatRequest,networkAssociateShortcut} from '../src/network_associate_input.js';
import {examineRequest} from '../src/network_player_requests.js';
import {walkToWaypointRequest,doorActionRequest,talkToRequest,useObjectRequest,attackRequest,dialogReplyRequest,inventoryWindowRequest,inventoryPanelRequest,equipItemRequest,unequipItemRequest,pickupItemRequest,dropItemRequest,moveItemRequest,toggleItemEquipmentRequest} from '../src/network_player_requests.js';

// Application admission/presentation owner, distinct from the reliable peer.
// Area-ready is acknowledged by the renderer after loading, never by a timer.
// This owner does not instantiate ModuleSession, scripts, AI or local rules.
export class NetworkGameSession extends EventEmitter {
 constructor({peer,identity,build,resources,language,openModule,onDiagnostic=()=>{},decodeMessage=decodeServerGameMessage,loadRules=loadNetworkObjectRules}){
  super();Object.assign(this,{peer,identity,build,resources,language,openModule,onDiagnostic,decodeMessage,loadRules});
  this.world=new NetworkWorld({onDiagnostic:d=>this.diagnose(d)});this.delivery=Promise.resolve();this.phase='new';this.closed=false;this.areaGeneration=0;this.objectRules={};this.movementSequences=new Map();
  peer.on('message',bytes=>{
   this.delivery=this.delivery.then(()=>this.receive(bytes)).catch(()=>{
    if(!this.closed){this.diagnose({code:'network.game-session-failed',reason:'Native game-message delivery failed'});void this.disconnect();}
   });
  });
  peer.on('closed',()=>this.finish());
 }
 diagnose(d){this.onDiagnostic(d);this.emit('diagnostic',d);}
 state(){return{phase:this.phase,closed:this.closed,resourcesReady:Boolean(this.resourceResult?.ready&&this.resolver),characterUploaded:Boolean(this.characterUploaded),characterConfirmed:Boolean(this.characterConfirmed),areaGeneration:this.areaGeneration,areaReady:Boolean(this.areaReadySent),world:this.world.snapshot()};}
 publish(){if(!this.closed)this.emit('state',this.state());}
 async connect(options){
  if(this.phase!=='new'||this.closed)throw new Error('Native game session has already started');
  this.phase='connecting';this.publish();
  try{const remote=await this.peer.connect(this.identity,options);if(this.closed)throw new Error('Native game session is closed');this.phase='resources';this.publish();await this.peer.sendGameMessage(serverStatusRequest());return remote;}
  catch{await this.disconnect();throw new Error('Native game session connection failed');}
 }
 async selectCharacter(bytes){
  if(this.closed||this.characterUploaded)throw new Error('Native character selection is unavailable');
  if(!isNetworkBytes(bytes)||bytes.length===0||bytes.length>948*65535-16)throw new Error('Invalid native character selection');
  parseGff(bytes,'BIC ');const owned=Uint8Array.from(bytes);this.character?.fill(0);this.character=owned;
  await this.uploadCharacter();
 }
 async uploadCharacter(){
  if(this.closed||!this.resourceResult?.ready||!this.resolver||!this.character||this.characterUploaded)return;
  // Set before awaiting: duplicate native requests must not upload twice.
  const bytes=this.character;this.character=null;this.characterUploaded=true;
  try{await this.peer.sendGameMessage(characterBlobRequest(bytes));if(!this.closed){this.phase='character';this.publish();}}finally{bytes.fill(0);}
 }
 async receive(bytes){
  if(this.closed)return;
  let message;
  try{message=this.decodeMessage(bytes,{clientBuild:this.build.build,objectRules:{...this.objectRules,objectState:id=>this.world.registry.get(id)?.replicated}});}
  catch{this.diagnose({code:'network.game-message-invalid',reason:'Native game-message fields are invalid',length:bytes.length});return;}
  this.world.apply(message);
  if(message.kind==='dialog-entry')this.dialog={...message,replies:null};
  if(message.kind==='dialog-replies'&&this.dialog)this.dialog.replies=message;
  if(message.kind==='dialog-close')this.dialog=null;
  if(message.kind==='server-resources'){
   const result=await resolveServerResources(message.requirements,{...this.resources,language:this.language,onDiagnostic:d=>this.diagnose(d)});
   if(this.closed)return;
   this.resourceResult=result;
   if(result.ready){
    const module=result.resolved.find(r=>r.kind==='nwm');
    if(!module){this.phase='resources-unavailable';this.diagnose({code:'network.module-resource-unavailable',reason:'A local module resource provider for this server is unavailable'});}
    else{
     const resolver=await this.openModule(module.resource,result.resolved);if(this.closed)return;
     const rules=await this.loadRules(resolver);if(this.closed)return;
     this.resolver=resolver;this.objectRules=rules;this.phase='character-selection';await this.uploadCharacter();
    }
   }else this.phase='resources-unavailable';
  }
  if(this.closed)return;
  if(message.kind==='character-confirmed'&&this.characterUploaded)this.characterConfirmed=true;
  if(message.kind==='character-rejected'){this.phase='character-rejected';this.diagnose({code:'network.character-rejected',reason:'The server rejected the selected character',strRef:message.reason});}
  if(message.kind==='module-info'&&this.characterConfirmed&&!this.moduleReadySent){this.moduleReadySent=true;await this.peer.sendGameMessage(moduleReadyRequest());}
  if(this.closed)return;
  if(message.kind==='client-area'){this.areaGeneration++;this.areaReadySent=false;this.phase='area-loading';this.dialog=null;}
  if(message.kind==='unsupported')this.diagnose({code:'network.game-message-unhandled',reason:'Native game-message handler is unavailable',major:message.major,minor:message.minor,length:message.length});
  if(message.kind==='object-updates'&&!message.complete)this.diagnose({code:'network.object-record-unhandled',...message.unhandled});
  // Parsed wire values only: no filesystem paths, authentication material or
  // original peer packets cross into a renderer through this event.
  this.emit('message',{message,areaGeneration:this.areaGeneration});this.publish();
 }
 async areaReady(generation){
  if(this.closed||this.phase!=='area-loading'||generation!==this.areaGeneration||this.areaReadySent)throw new Error('Native area presentation acknowledgement is stale');
  this.areaReadySent=true;
  try{await this.peer.sendGameMessage(clientAreaReadyRequest());if(!this.closed&&generation===this.areaGeneration){this.phase='playing';this.publish();}}
  catch(error){if(!this.closed&&generation===this.areaGeneration)this.areaReadySent=false;throw error;}
 }
 async getResource(resref,type){
  if(this.closed||!this.resolver)throw new Error('Native session resources are unavailable');
  // Resource references are archive keys. They are never filesystem paths.
  if(typeof resref!=='string'||!/^[a-zA-Z0-9_]{1,32}$/.test(resref)||!Object.values(RESOURCE_TYPE).includes(type))throw new Error('Invalid native resource request');
  const result=await this.resolver.getResource(resref,type);if(this.closed)throw new Error('Native game session is closed');return result;
 }
 async talkString(ref,gender=0){
  if(this.closed||!this.resourceResult?.ready||!Number.isInteger(ref)||ref<0||ref>0xffffffff||![0,1].includes(gender))throw new Error('Native talk-table request is unavailable');
  const value=await this.resources.talkString(ref,gender,this.resourceResult.resolved,d=>this.diagnose(d));if(this.closed)throw new Error('Native game session is closed');return value;
 }
 async replyDialog({areaId,areaGeneration,entryId,replyId,abort=false}){
  this.controlledActor(areaId,areaGeneration);const dialog=this.dialog,choices=dialog?.replies;
  if(!choices||choices.entryId!==entryId||![true,false].includes(abort)||(!abort&&!choices.replies.some(r=>r.id===replyId)&&!(choices.replies.length===0&&replyId===0xffffffff)))throw new Error('Native dialog reply is stale or unavailable');
  // Native Escape chooses the first reply instead of aborting when the
  // secondary reply count equals one (6f81e0 / panel fieldbc0).
  if(abort&&choices.secondCount===1){replyId=choices.replies[0]?.id??0xffffffff;abort=false;}
  await this.peer.sendGameMessage(dialogReplyRequest({ownerId:dialog.ownerId,entryId,replyId:abort?0xffffffff:replyId,abort}));return{sent:true};
 }
 controlledActor(areaId,areaGeneration){
  const id=this.world.localObjectId,actor=this.world.registry.get(id);
  if(this.closed||this.phase!=='playing'||!this.areaReadySent||areaGeneration!==this.areaGeneration||areaId!==this.world.areaId||actor?.objectType!==5||actor.areaId!==areaId||actor.replicationRemoved)throw new Error('Native controlled creature is not ready for input');
  return actor;
 }
 async inventoryWindow({areaId,areaGeneration,open,ownerId=this.world.localObjectId}){
  const actor=this.controlledActor(areaId,areaGeneration);
  // Associate inventory needs its native ownership/control path before it
  // can be exposed. Keep this initial request scoped to the controlled PC.
  if(ownerId!==actor.id||typeof open!=='boolean')throw new Error('Native inventory owner is unavailable');
  await this.peer.sendGameMessage(inventoryWindowRequest({ownerId,open}));return{sent:true};
 }
 async inventoryPanel({areaId,areaGeneration,panel}){
  this.controlledActor(areaId,areaGeneration);
  const packet=inventoryPanelRequest({panel,self:true});this.world.clearRepositoryView();await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async assignQuickbar({areaId,areaGeneration,index,button}){
  const actor=this.controlledActor(areaId,areaGeneration),b=button??{type:0},normalized=Object.fromEntries(Object.keys(emptyQuickbarButton()).filter(k=>Object.hasOwn(b,k)).map(k=>[k,structuredClone(b[k])]));
  if(b.type===1)for(const id of [b.itemId,b.secondaryItemId??0x7f000000]){if(id===0x7f000000)continue;const item=this.world.registry.get(id),location=item?.inventoryLocation,existing=this.world.quickbar.some(q=>q.type===1&&(q.itemId===id||q.secondaryItemId===id));if(item?.objectType!==6||item.replicationRemoved||!(existing||location?.ownerId===actor.id&&['R','I'].includes(location.channel)))throw new Error('Native quickbar item is unavailable');}
  const packet=quickbarAssignmentRequest({index,button:normalized});await this.peer.sendGameMessage(packet);this.controlledActor(areaId,areaGeneration);
  // Native8602a0 sends after the local widget changes and suppresses sends
  // during server refresh. This is a client-owned shortcut layout, not a
  // fabricated server packet or a local gameplay action/result.
  this.world.applyQuickbar({entries:[{index,button:normalized,items:[]}]});return{sent:true,button:normalized};
 }
 async prepareSpell({areaId,areaGeneration,actorId,clear=false,...request}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id||typeof clear!=='boolean')throw new Error('Native preparation belongs to an old controlled creature');
  await this.peer.sendGameMessage(clear?spellPreparationClearRequest(request):spellPreparationRequest(request));return{sent:true};
 }
 async rest({areaId,areaGeneration,actorId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw new Error('Rest belongs to an old controlled creature');
  await this.peer.sendGameMessage(restRequest());return{sent:true};
 }
 async examine({areaId,areaGeneration,actorId,targetId}){
  const actor=this.controlledActor(areaId,areaGeneration),target=this.world.registry.get(targetId);if(actor.id!==actorId||!target||target.replicationRemoved||![5,6,7,9,10].includes(target.objectType)||!(target.areaId===areaId||target.objectType===6&&target.inventoryLocation?.ownerId===actor.id))throw new Error('Native examination target is stale or unavailable');
  await this.peer.sendGameMessage(examineRequest({targetId}));return{sent:true};
 }
 async hudPanel({areaId,areaGeneration,actorId,panel,open,page=0}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id||typeof open!=='boolean')throw new Error('Native panel request is stale');
  const packet=panel==='character'?characterSheetRequest({targetId:actor.id,page:open?page:-1}):panel==='journal'?journalWindowRequest(open):null;if(!packet)throw new Error('Unsupported native panel request');
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async playerAttitude({areaId,areaGeneration,actorId,playerId,likes}){
  const actor=this.controlledActor(areaId,areaGeneration),player=this.world.players.get(playerId);if(actorId!==actor.id||!player||player.objectId===actor.id)throw new Error('Native player attitude target is stale');
  await this.peer.sendGameMessage(playerAttitudeRequest({targetId:player.objectId,likes}));return{sent:true};
 }
 async castSpell({areaId,areaGeneration,spellId,classIndex=0,domainLevel=0,metamagic=0,spontaneous=false,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration),spell=this.objectRules.spellInputInfo?.(spellId);if(!spell)throw new Error('Native spell input metadata is unavailable');
  this.validateCastTarget(areaId,actor,targetId);
  await this.peer.sendGameMessage(spellCastRequest({spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,position,targetType:spell.targetType}));return{sent:true};
 }
 validateCastTarget(areaId,actor,targetId){if(targetId!==OBJECT_INVALID){const target=this.world.registry.get(targetId),ownedItem=target?.objectType===6&&(target.inventoryLocation?.ownerId===actor.id||this.world.quickbar.some(b=>b.type===1&&(b.itemId===targetId||b.secondaryItemId===targetId)));if(!target||target.replicationRemoved||!(target.areaId===areaId||ownedItem))throw new Error('Native spell target is unavailable');}}
 async useItem({areaId,areaGeneration,itemId,propertyIndex,variant=255,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration),item=this.world.registry.get(itemId),location=item?.inventoryLocation,shortcut=this.world.quickbar.some(b=>b.type===1&&b.itemId===itemId);
  if(item?.objectType!==6||item.replicationRemoved||!(shortcut||location?.ownerId===actor.id&&['R','I'].includes(location.channel)))throw new Error('Native item-use source is unavailable');
  this.validateCastTarget(areaId,actor,targetId);
  await this.peer.sendGameMessage(itemUseRequest({itemId,propertyIndex,variant,targetId,position}));return{sent:true};
 }
 async castSpellLike({areaId,areaGeneration,spellId,casterLevel,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!this.objectRules.spellInputInfo?.(spellId))throw new Error('Native innate spell metadata is unavailable');this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(spellLikeCastRequest({spellId,casterLevel,targetId,position}));return{sent:true};
 }
 async useFeat({areaId,areaGeneration,featId,auxiliary=0,targetId=OBJECT_INVALID,position=null}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!this.objectRules.featInputInfo?.(featId))throw new Error('Native feat input metadata is unavailable');this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(featUseRequest({featId,auxiliary,targetId,position}));return{sent:true};
 }
 async changeMode({areaId,areaGeneration,modeId,targetId=OBJECT_INVALID}){
  const actor=this.controlledActor(areaId,areaGeneration);if(modeId===5)this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(modeChangeRequest({modeId,targetId}));return{sent:true};
 }
 async possessFamiliar({areaId,areaGeneration}){this.controlledActor(areaId,areaGeneration);await this.peer.sendGameMessage(possessFamiliarRequest());return{sent:true};}
 async associateCommand({areaId,areaGeneration,actorId,targetId,command}){
  const actor=this.controlledActor(areaId,areaGeneration),target=this.world.registry.get(targetId);
  if(actorId!==actor.id)throw new Error('Associate command belongs to an old controlled creature');
  if(target?.objectType!==5||target.replicationRemoved)throw new Error('Native associate command target is unavailable');
  await this.peer.sendGameMessage(associateCommandRequest({targetId,command}));return{sent:true};
 }
 async quickChat({areaId,areaGeneration,actorId,quickChat}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw new Error('Quick chat belongs to an old controlled creature');
  await this.peer.sendGameMessage(quickChatRequest({quickChat}));return{sent:true};
 }
 async activateQuickbar({areaId,areaGeneration,index}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!Number.isInteger(index)||index<0||index>=36)throw new Error('Invalid native quickbar index');const b=this.world.quickbar[index];
  if(b.type===38){await this.peer.sendGameMessage(possessFamiliarRequest());return{sent:true};}
  if(b.type===42){await this.peer.sendGameMessage(quickChatRequest({quickChat:b.intParam&65535}));return{sent:true};}
  if(b.type===39){const request=networkAssociateShortcut(b,actor);if(request)await this.peer.sendGameMessage(associateCommandRequest(request));return{sent:Boolean(request)};}
  // Original item widget85bec0 opens containers first; only equipable items
  // with property WORD255 route through805500 -> native12/11. A default
  // packed value alone does not make a potion/container an equipment action.
  const info=b.type===1?this.objectRules.quickbarItemInfo?.(this.world.registry.get(b.itemId)?.item?.baseItem):null;
  if(b.type===1&&info?.container===0&&info.equipableSlots!==0&&(b.intParam&65535)===255){for(const id of [b.itemId,b.secondaryItemId??OBJECT_INVALID]){if(id===OBJECT_INVALID)continue;const item=this.world.registry.get(id);if(item?.objectType!==6||item.replicationRemoved)throw new Error('Native shortcut item is unavailable');}await this.peer.sendGameMessage(toggleItemEquipmentRequest({itemId:b.itemId,secondId:b.secondaryItemId??OBJECT_INVALID}));return{sent:true};}
  this.diagnose({code:'network.quickbar-action-unhandled',reason:'Native quickbar activation request is not connected',index,type:b.type,parameter:b.intParam});throw new Error('This shortcut action is not connected yet');
 }
 async itemAction({areaId,areaGeneration,itemId,operation,slot,x=255,y=255,position}){
  const actor=this.controlledActor(areaId,areaGeneration),item=this.world.registry.get(itemId),location=item?.inventoryLocation;
  if(item?.objectType!==6||item.replicationRemoved)throw new Error('Native item is unavailable');
  const owned=location?.ownerId===actor.id&&['R','I'].includes(location.channel);let packet;
  if(operation==='pickup'){
   if(owned||item.equipmentOwnerId!=null||item.areaId!==areaId)throw new Error('Native pickup item is unavailable');
   packet=pickupItemRequest({itemId,destinationId:actor.id,x,y});
  }else{
   if(!owned)throw new Error('Native inventory item is unavailable');
   if(operation==='toggle')packet=toggleItemEquipmentRequest({itemId});
   else if(operation==='equip'){
    if(!Number.isInteger(slot)||slot<=0||slot>0x20000||(slot&(slot-1))!==0)throw new Error('Native equipment slot is unavailable');
    packet=equipItemRequest({itemId,slot,destinationId:actor.id});
   }else if(operation==='unequip'){
    if(location.channel!=='I')throw new Error('Native equipped item is unavailable');
    packet=unequipItemRequest({itemId,destinationId:actor.id,x,y});
   }else if(operation==='move'){
    if(location.channel!=='R')throw new Error('Native repository item is unavailable');
    packet=moveItemRequest({itemId,destinationId:actor.id,x,y});
   }else if(operation==='drop')packet=dropItemRequest({itemId,position:position??actor.replicated.position});
   else throw new Error('Native item action is unavailable');
  }
  // Native server455f50 queues the action. No local CanUseItem, cursed-item,
  // slot fit, ownership transfer, stack split, equip or drop is performed.
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async interact({areaId,areaGeneration,targetId,action,run=true}){
  this.controlledActor(areaId,areaGeneration);
  const target=this.world.registry.get(targetId);
  if(!target||target.areaId!==areaId||target.replicationRemoved)throw new Error('Native interaction target is unavailable');
  let packet;
  if(action==='door.open'||action==='door.close'){
   if(target.objectType!==10)throw new Error('Native door target is unavailable');
   packet=doorActionRequest({targetId,action:action==='door.open'?21:22});
  }else if(action==='door.transition'){
   const state=networkDoorClickState(target);
   if(target.objectType!==10||state===null||state===0||!target.replicated?.hasTransition)throw new Error('Native door transition is unavailable');
   // Original click wrappers6efca0/6efec0 send the door position/ID with
   // sequence0 and no client path. Native server action processing owns
   // approach, transition scripts and any resulting area change.
   packet=walkToWaypointRequest({areaId,position:target.replicated.position,targetId,sequence:0,run,clientPath:false,fractional:0});
  }else if(action==='conversation.start')packet=talkToRequest({targetId});
  else if(action==='object.use')packet=useObjectRequest({targetId,flag0:false,flag1:target.objectType===9});
  else if(action==='combat.attack')packet=attackRequest({targetId});
  else throw new Error('Native interaction request is not implemented');
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async walkTo({areaId,areaGeneration,position,run=true}){
  const {id}=this.controlledActor(areaId,areaGeneration);
  // Client initializer1407fb4b2 zeroes sequence2d2/last-sent2d3. Ground
  // input1406f3650 increments the BYTE before calling the packet sender.
  const sequence=((this.movementSequences.get(id)??0)+1)&255;
  const packet=walkToWaypointRequest({areaId,position,sequence,run,clientPath:false,fractional:0});
  // No client-computed path is advertised: authoritative updates own motion.
  // Sequence is presentation/request state, never a new object identity.
  this.movementSequences.set(id,sequence);await this.peer.sendGameMessage(packet);return{sequence};
 }
 disconnect(){
  if(this.disconnectPromise)return this.disconnectPromise;
  // Mark closed immediately, so outstanding resource I/O cannot upload or
  // publish state after cancellation. Peer cleanup has its own serial queue.
  this.finish();this.disconnectPromise=Promise.resolve().then(()=>this.peer.disconnect());return this.disconnectPromise;
 }
 finish(){
  if(this.closed)return;this.closed=true;this.phase='closed';this.character?.fill(0);this.character=null;this.resolver=null;this.objectRules={};this.identity.dispose();this.build.dispose();this.emit('state',this.state());this.emit('closed');
 }
}
