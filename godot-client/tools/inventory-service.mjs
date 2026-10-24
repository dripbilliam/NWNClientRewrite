import {intEntry} from '../../src/combat_stats.js';
import {inventoryEquipmentLayout,inventorySummary} from '../../src/inventory_layout.js';
import {EQUIPMENT_SLOTS} from '../../src/character.js';
import {itemIconDescriptor} from '../../src/item_icon.js';
import {configureNetworkItemShortcut} from '../../src/network_quickbar_items.js';
import {emptyQuickbarButton} from '../../src/quickbar.js';
import {OBJECT_INVALID} from '../../src/game_object_array.js';
import {selectContainerPage} from '../../src/network_container.js';
import {StoreService} from './store-service.mjs';

// Presentation only: authoritative proxies and existing session packet senders
// own every item. An acknowledgement never fabricates an equipment transfer.
export class InventoryService{
 constructor({actions,onRequest=()=>{},now=()=>performance.now()}){Object.assign(this,{actions,onRequest,now});this.session=actions.session;this.serial=0;this.epoch=0;this.renderEpoch=0;this.opened=false;this.page=0;this.containerPage=0;this.containerSerial=0;this.pending=new Map();this.recentViews=new Map();this.iconTasks=new Set();this.store=new StoreService(this);}
 reset(){this.epoch++;this.renderEpoch++;this.opened=false;this.view=null;this.signature=null;this.pending.clear();this.recentViews.clear();this.store.reset();this.page=0;this.containerPage=0;this.automatic=false;}
 async retire(){this.reset();await Promise.allSettled([...this.iconTasks]);return{pendingIcons:this.iconTasks.size,closed:true};}
 scope(){const scope=this.actions.capture();scope.world=this.session.world;return scope;}
 owned(scope){return scope?.world===this.session.world&&this.actions.owned(scope);}
 emit(data){this.actions.emit(data);}
 async open(){const epoch=++this.epoch,scope=this.scope();if(!this.owned(scope))throw Error('Inventory owner is unavailable');this.opened=true;this.signature=null;await this.session.inventoryWindow({...this.base(scope),open:true});if(epoch!==this.epoch||!this.owned(scope))return;await this.session.inventoryPanel({...this.base(scope),panel:this.page});if(epoch===this.epoch&&this.owned(scope))await this.refresh(true);}
 base(scope){return{areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId};}
 async close(){const scope=this.scope();this.reset();const epoch=this.epoch;if(this.actions.menu?.inventory)this.actions.cancel({requestId:this.actions.requestId});if(!this.owned(scope))return;if(scope.world.store?.open)await this.session.storeInput({...this.base(scope),storeGeneration:scope.world.store.generation,operation:'close'});if(epoch!==this.epoch||!this.owned(scope))return;const targetId=this.session.world.containers.get('C');if(targetId!==undefined&&targetId!==OBJECT_INVALID)await this.session.containerInput({...this.base(scope),targetId,operation:'close'});if(epoch!==this.epoch||!this.owned(scope))return;await this.session.inventoryWindow({...this.base(scope),open:false});if(epoch===this.epoch&&this.owned(scope))this.emit({kind:'inventory-closed'});}
 snapshot(scope){const world=scope.world;return JSON.stringify([this.page,this.containerPage,this.containerSerial,scope.actor.inventoryStats,scope.actor.playerState?.combat,scope.actor.playerState?.abilities,world.containers.get('C'),this.store.snapshot(),...['I','R','C','M'].map(channel=>[channel,world.inventories.get(channel),...(world.inventories.get(channel)?.entries??[]).map(location=>{const object=world.registry.get(location.id);return[object?.item,object?.inventoryLocation,object?.replicationRemoved];})]),[...this.pending]]);}
 context(scope){const store=scope.world.store;return JSON.stringify([this.page,this.containerPage,this.containerSerial,scope.world.containers.get('C'),store?[store.open,store.generation,store.panel,store.page]:null,this.store.navigation??null]);}
 current(viewId){const view=this.view;if(!this.opened||!view||view.id!==viewId||!this.owned(view.scope)||view.context!==this.context(view.scope))throw Error('Inventory selection is stale');return view;}
 // A committed refresh can overtake a click already travelling from Godot.
 // Retain a bounded set of presentation owners for entry commands only;
 // canonical item identity, membership, location and metadata still must match.
 selected(viewId,entryId){const view=this.view?.id===viewId?this.current(viewId):this.recentViews.get(viewId);if(!this.opened||!view||!this.owned(view.scope)||view.context!==this.context(view.scope))throw Error('Inventory selection is stale');const row=view.rows.get(entryId),member=row&&(this.session.world.inventories.get(row.channel)?.entries??[]).find(v=>v.id===row.object.id);if(!row||this.session.world.registry.get(row.object.id)!==row.object||row.object.replicationRemoved||!member||['slot','x','y'].some(key=>member[key]!==row.location[key])||row.itemSignature!==JSON.stringify([row.object.item,row.object.inventoryLocation]))throw Error('Inventory item is stale');return{view,row};}
 async choose({viewId,page}){const view=this.current(viewId);if(!Number.isInteger(page)||page<0||page>=6)throw Error('Invalid inventory page');const epoch=++this.epoch;await this.session.inventoryPanel({...this.base(view.scope),panel:page});if(epoch!==this.epoch||!this.owned(view.scope))return;this.page=page;this.signature=null;await this.refresh(true);}
 async container({viewId,operation}){const view=this.current(viewId),scope=view.scope,targetId=scope.world.containers.get('C');if(targetId===undefined||targetId===OBJECT_INVALID||!['close','next','previous'].includes(operation))throw Error('Container request is stale');const epoch=++this.epoch,containerSerial=this.containerSerial,count=scope.world.inventories.get('C')?.pageCount??1;await this.session.containerInput({...this.base(scope),targetId,operation});if(epoch!==this.epoch||containerSerial!==this.containerSerial||!this.owned(scope)||operation!=='close'&&scope.world.containers.get('C')!==targetId)return;this.containerPage=operation==='close'?0:selectContainerPage(this.containerPage,count,operation==='next'?1:-1);this.signature=null;await this.refresh(true);}
 async refresh(force=false){
  if(!this.opened)return;const scope=this.scope();if(!this.owned(scope))return;
  this.store.expire(this.now());
  this.containerPage=Math.max(0,Math.min(this.containerPage,Math.max(0,(scope.world.inventories.get('C')?.pageCount??1)-1)));
  for(const [id,pending]of this.pending)if(this.now()-pending.at>6000){this.pending.delete(id);this.emit({kind:'inventory-notice',text:'The server has not confirmed that item action.'});}
  const signature=this.snapshot(scope);if(!force&&signature===this.signature&&this.view?.scope.actor===scope.actor)return;
  const epoch=++this.renderEpoch,windowEpoch=this.epoch;await this.actions.tables();const encumbrance=await this.actions.text.rules('encumbrance');if(epoch!==this.renderEpoch||windowEpoch!==this.epoch||!this.opened||!this.owned(scope))return;
  const rows=new Map(),items=[];
  for(const channel of ['I','R','C',...(scope.world.store?.open?['M']:[])])for(const location of scope.world.inventories.get(channel)?.entries??[]){
   const object=scope.world.registry.get(location.id);if(!object?.item||object.replicationRemoved)continue;
   const item=object.item,field=name=>{const result=intEntry(this.actions.rules.baseitems,item.baseItem,name);if(!result.found)throw Error('Item '+name+' is unavailable');return result.value;};
   const entryId=rows.size;rows.set(entryId,{object,location:{...location},channel,itemSignature:JSON.stringify([object.item,object.inventoryLocation])});
   items.push({entryId,itemId:object.id,channel,slot:location.slot??0,x:location.x??0,y:location.y??0,width:field('InvSlotWidth')&255,height:field('InvSlotHeight')&255,slotMask:field('EquipableSlots')>>>0,stack:item.stackSize??item.field454??1,name:await this.actions.text.resolve(item.name,scope.actorId),pending:this.pending.has(object.id),...this.store.decorate(object,channel)});
  }
  if(epoch!==this.renderEpoch||windowEpoch!==this.epoch||!this.opened||!this.owned(scope)||signature!==this.snapshot(scope))return;
  const id=++this.serial;
  const name=scope.actor.replicated?.name??scope.actor.appearance?.name;
  const title=name?.text??[await this.actions.text.resolve(name?.firstName,scope.actorId),await this.actions.text.resolve(name?.lastName,scope.actorId)].filter(Boolean).join(' ');
  if(epoch!==this.renderEpoch||windowEpoch!==this.epoch||!this.owned(scope))return;
  const containerId=scope.world.containers.get('C')??OBJECT_INVALID,container=scope.world.registry.get(containerId),containerTitle=containerId===OBJECT_INVALID?'':await this.actions.text.resolve(container?.item?.name??container?.replicated?.name??container?.staticState?.name,scope.actorId);
  const store=await this.store.metadata(scope);
  if(epoch!==this.renderEpoch||windowEpoch!==this.epoch||!this.owned(scope)||signature!==this.snapshot(scope))return;
  if(this.view){this.recentViews.set(this.view.id,this.view);while(this.recentViews.size>8)this.recentViews.delete(this.recentViews.keys().next().value);}
  this.signature=signature;this.view={id,scope,rows,signature,context:this.context(scope)};
  this.emit({kind:'inventory-view',viewId:id,title,page:this.page,automatic:Boolean(this.automatic),items,store,layout:inventoryEquipmentLayout(true).map(row=>({...row,label:EQUIPMENT_SLOTS[Math.log2(row.slot)]})),summary:inventorySummary(scope.actor,{encumbrance}),armorClass:scope.actor.playerState?.combat?.armorClass??null,container:{ownerId:containerId,serial:this.containerSerial,title:containerTitle,page:this.containerPage,pageCount:scope.world.inventories.get('C')?.pageCount??1}});
  const work=async(row)=>{const original=rows.get(row.entryId).object;try{const image=await this.actions.icon(itemIconDescriptor(original.item,scope.actor.appearance?.gender??0));if(image&&this.view?.id===id&&this.owned(scope)&&scope.world.registry.get(original.id)===original)this.emit({kind:'inventory-icon',viewId:id,entryId:row.entryId,image});}catch(error){if(this.view?.id===id){this.actions.diagnose('godot.inventory-icon-unavailable',error.message);this.emit({kind:'inventory-notice',text:'Item icon unavailable: '+row.name});}}};
  // Icons never hold metadata, packet decoding, or the native frame loop.
  const visible=items.filter(row=>row.channel==='I'||row.channel==='M'||row.channel==='R'&&Math.floor(row.y/6)===this.page||row.channel==='C'&&Math.floor(row.y/5)===this.containerPage);let cursor=0;
  const task=Promise.all(Array.from({length:Math.min(4,visible.length)},async()=>{while(cursor<visible.length&&this.view?.id===id)await work(visible[cursor++]);}));this.iconTasks.add(task);void task.finally(()=>this.iconTasks.delete(task));
 }
 receive(message){
  this.store.receive(message);
  if(message.kind==='container-status'){
   if(!message.primary)return;
   this.containerSerial++;this.containerPage=0;this.signature=null;this.automatic=message.targetId!==OBJECT_INVALID;
   if(this.automatic&&!this.opened)void this.open().catch(error=>this.emit({kind:'inventory-notice',text:error.message}));
   return;
  }
  if(message.kind!=='inventory-result'||message.alternate)return;
  const p=this.pending.get(message.itemId);
  if(p&&(p.operation===message.operation||p.operation==='toggle'&&['equip','unequip'].includes(message.operation)))this.pending.delete(message.itemId);
  if(!message.success)this.emit({kind:'inventory-notice',text:'The server rejected that item action.'});this.signature=null;
 }
 async activate(viewId,entryId){const {view,row}=this.selected(viewId,entryId),item=row.object;await this.actions.tables();this.selected(viewId,entryId);this.actions.targetScope=view.scope;
  if(this.store.open)throw Error('Select Buy or Sell in the store confirmation.');
  if(this.actions.targeter.active)return this.actions.targeter.select(item,[0,0,0]);
  if(row.channel==='C')return this.action({viewId,entryId,operation:'move',destination:'backpack'});
  if(intEntry(this.actions.rules.baseitems,item.item.baseItem,'Container').value)return this.session.interact({...this.base(view.scope),targetId:item.id,action:'object.use'});
  const configured=configureNetworkItemShortcut(this.session.world,this.actions.rules,emptyQuickbarButton(),{itemId:item.id,intParam:0xff00ff},{report:(code,reason)=>this.actions.diagnose(code,reason)});
  if(!configured)throw Error('That item cannot be activated');
  if((configured.button.intParam&65535)!==255)return this.actions.targeter.beginItem(item.id,configured.button.intParam);
  if(intEntry(this.actions.rules.baseitems,item.item.baseItem,'EquipableSlots').value)return this.action({viewId,entryId,operation:'toggle'});
  throw Error('This item has no available default action');
 }
 async action(request){const {view,row}=this.selected(request.viewId,request.entryId),scope=view.scope,id=row.object.id;
  if(request.operation==='examine')return this.session.examine({...this.base(scope),targetId:id});
  if(this.store.open||row.channel==='M')throw Error('Use the store confirmation for merchant item transactions.');
  if(this.pending.has(id))throw Error('That item is waiting for the server');
  const operation=request.operation;if(!['equip','unequip','toggle','move','drop'].includes(operation))throw Error('Unsupported inventory action');
  const fields={};if(operation==='equip'){const mask=intEntry(this.actions.rules.baseitems,row.object.item.baseItem,'EquipableSlots').value>>>0;if(!Number.isInteger(request.slot)||request.slot<=0||(request.slot&(request.slot-1))||!(mask&request.slot))throw Error('This item cannot be equipped in that slot');fields.slot=request.slot;}
  if(request.destination!==undefined){if(!['backpack','container'].includes(request.destination))throw Error('Invalid item destination');fields.destinationId=request.destination==='backpack'?scope.actorId:scope.world.containers.get('C');if(fields.destinationId===undefined||fields.destinationId===OBJECT_INVALID)throw Error('No container is open');}
  if(request.x!==undefined||request.y!==undefined){const width=request.destination==='container'?7:10,height=request.destination==='container'?255:36;if(!Number.isInteger(request.x)||!Number.isInteger(request.y)||request.x<0||request.x>=width||request.y<0||request.y>=height)throw Error('Invalid repository position');fields.x=request.x;fields.y=request.y;}
  this.pending.set(id,{operation,at:this.now()});this.signature=null;
  try{await this.session.itemAction({...this.base(scope),itemId:id,operation,...fields});this.onRequest({itemId:id,operation,...fields});}catch(error){this.pending.delete(id);throw error;}finally{if(this.owned(scope))await this.refresh(true);}
 }
}
