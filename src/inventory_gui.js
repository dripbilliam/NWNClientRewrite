import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native inventory GUI ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native inventory GUI provider ${n} is unavailable`);return p[n];};

// CNWSPlayerLUOInventory ctor1404c1d50. Four physically distinct lists and
//18 cached item/companion cells; uninitialized c0/c4 are not invented here.
export function createInventoryLastUpdate(){return{
 items:Array(18).fill(OBJECT_INVALID),itemFields:Array(18).fill(-1),list90:[],field98:OBJECT_INVALID,listA0:[],dirtyA8:1,listB0:[],listB8:[],
};}
export function createInventoryGUI(){return{lastUpdate:createInventoryLastUpdate(),field8:0,fieldC:0,ownerId:OBJECT_INVALID,openInventory:{id:OBJECT_INVALID,field4:0,field8:0}};}

// Reset helpers1404c2dc0/2d80/2b00/2b40. List B8 is intentionally retained.
export function resetInventoryEquipment(luo){
 if(!luo?.items||luo.items.length!==18||!luo.itemFields||luo.itemFields.length!==18)throw new Error('Native inventory LUO equipment storage is unavailable');
 for(let n=0;n<18;n++){luo.items[n]=OBJECT_INVALID;luo.itemFields[n]=-1;}
}
export async function clearInventoryUpdateList(luo,name,p){
 const list=luo?.[name];if(!Array.isArray(list)||!['list90','listA0','listB0'].includes(name))throw new Error('Native inventory LUO list storage is unavailable');
 while(list.length)await required(p,'releaseEntry')(list.shift());
 if(name==='listA0')luo.dirtyA8=1;
}

// LUOInventory owner setter1404be930. If old ID matches both primary and
// alternate GUIs, primary wins even when the passed owner belongs to alternate.
export async function setOpenInventory(owner,client,id,open,p){
 id=integer(id,'new inventory ID')>>>0;open=integer(open,'open field4');
 const previous=integer(owner.id,'old inventory ID')>>>0;
 if(id!==previous&&client){
  let gui=required(p,'primary')(client);
  if((integer(gui.openInventory.id,'primary inventory ID')>>>0)!==previous){
   gui=required(p,'alternate')(client);if((integer(gui.openInventory.id,'alternate inventory ID')>>>0)!==previous)gui=null;
  }
  if(gui)await clearInventoryUpdateList(gui.lastUpdate,'listA0',p);
 }
 owner.field4=open;owner.id=id;owner.field8=0;
}

// InventoryGUI::SetOpen1404be9a0. Exact notify1 closes the previous item or
// placeable with GUI flag0. The separate character ownerId/fieldC remain intact.
export async function setInventoryGUIOpen(gui,value,notify,p){
 value=integer(value,'open value');notify=integer(notify,'close notification');
 if(value===0&&integer(gui.field8,'previous open flag')!==0){
  resetInventoryEquipment(gui.lastUpdate);await clearInventoryUpdateList(gui.lastUpdate,'list90',p);await clearInventoryUpdateList(gui.lastUpdate,'listB0',p);
  if(notify===1){const id=integer(gui.openInventory.id,'previous container ID')>>>0;
   if(id!==OBJECT_INVALID){const result=await required(p,'lookup')(id);
    if(result.status===0){const object=result.object;if(!object)throw new Error('Native inventory GUI dereferences a null successful lookup');
     if(object.objectType===6){const item=required(p,'asItem')(object);if(item)await required(p,'closeItem')(item,integer(gui.ownerId,'character owner ID')>>>0,0);}
     else if(object.objectType===9){const placeable=required(p,'asPlaceable')(object);if(placeable)await required(p,'closePlaceable')(placeable,integer(gui.ownerId,'character owner ID')>>>0,0);}
    }
   }
  }
  gui.openInventory.id=OBJECT_INVALID;gui.openInventory.field4=0;gui.openInventory.field8=0;
  await clearInventoryUpdateList(gui.lastUpdate,'listA0',p);
 }
 gui.field8=value;
}

// Placeable OpenInventory1404b6720 and CloseInventory1404b1e10. The
// observer count changes even when there is no current client. Reopening the
// same retained ID is an early return, not another observer. Close flag0 does
// no client lookup; exact owner mismatch with a found client does not decrement.
export async function openPlaceableInventory(object,playerId,p){
 playerId=integer(playerId,'opening player ID')>>>0;
 if(integer(object.nativeHasInventory4f8,'HasInventory')===0)return;
 const client=await required(p,'client')(playerId);
 if(client){
  const previous=integer(required(p,'primary')(client).openInventory.id,'previous container ID')>>>0;
  if(previous===(object.id>>>0))return;
  if(previous!==OBJECT_INVALID){const controlled=await required(p,'clientObject')(client);
   if(controlled){const result=await required(p,'lookup')(previous);if(result.status===0){
    const old=result.object;if(!old)throw new Error('Native placeable open dereferences a null successful lookup');
    if(old.objectType===6){const item=required(p,'asItem')(old);if(item)await required(p,'closeItem')(item,controlled.id,0);}
    else if(old.objectType===9){const placeable=required(p,'asPlaceable')(old);if(placeable)await required(p,'closePlaceable')(placeable,controlled.id,0);}
   }}
  }
  const gui=p.primary(client);await required(p,'setOwner')(gui.openInventory,client,object.id,integer(gui.field8,'previous GUI open flag')===0?1:0);
  await required(p,'setOpen')(p.primary(client),1,0);await required(p,'guiMessage')(client,object.id,1);
 }
 if(integer(object.nativeField508,'observer count')===0){await required(p,'enqueue')(playerId,object.id,10,{type:22});await required(p,'animation')(object,75);}
 object.nativeField508=(integer(object.nativeField508,'observer count')+1)|0;
}
export async function closePlaceableInventoryForPlayer(object,playerId,closeGUI,p){
 playerId=integer(playerId,'closing player ID')>>>0;closeGUI=integer(closeGUI,'close GUI flag');
 if(integer(object.nativeHasInventory4f8,'HasInventory')===0||integer(object.nativeField508,'observer count')===0)return;
 if(closeGUI!==0){const client=await required(p,'client')(playerId);if(client){
  if((integer(required(p,'primary')(client).openInventory.id,'current container ID')>>>0)!==(object.id>>>0))return;
  if(integer(p.primary(client).openInventory.field4,'container open field4')!==0){await required(p,'inventoryStatus')(client,0,OBJECT_INVALID);await required(p,'setOpen')(p.primary(client),0,0);}
  await required(p,'setOwner')(p.primary(client).openInventory,client,OBJECT_INVALID,0);await required(p,'guiMessage')(client,OBJECT_INVALID,1);
 }}
 if(integer(object.nativeField508,'observer count')===1){await required(p,'enqueue')(playerId,object.id,10,{type:23});await required(p,'animation')(object,76);}
 object.nativeField508=(integer(object.nativeField508,'observer count')-1)|0;
}

// EventHandler switch22/23 ->1404b32f1/3302 ->3878. No additional
// HasInventory/observer gate at delivery: callbacks see current world state.
export async function receivePlaceableInventoryEvent(object,caller,payload,p){
 const type=integer(payload.type,'script event')&65535;caller=integer(caller,'script caller')>>>0;
 if(type===22){object.nativeLastOpenedBy520=caller;object.eventObjects.opened=caller;await required(p,'runEventScript')(object,8,0);}
 else if(type===23){object.nativeLastClosedBy524=caller;object.eventObjects.closed=caller;await required(p,'runEventScript')(object,0,0);}
 else throw new Error('Native placeable inventory script event is unavailable');
}
