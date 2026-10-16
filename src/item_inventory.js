import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item inventory ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native item inventory provider ${n} is unavailable`);return p[n];};
const isContainer=(o,p)=>{const base=required(p,'baseInfo')(o);if(!base)throw new Error('Native item inventory dereferences null base rules');return integer(base.container,'Container rule')!==0;};

// CNWSItem::OpenInventory14046ad80. Alternate is selected only when the
// possessor differs from the player AND matches that alternate character.
export async function openItemInventory(item,playerId,p){
 playerId=integer(playerId,'opening player ID')>>>0;if(!isContainer(item,p))return;
 const client=await required(p,'client')(playerId);
 if(client){let gui=required(p,'primary')(client),primary=1;const possessor=integer(item.possessorId,'possessor ID')>>>0;
  if(possessor!==playerId){const alternate=required(p,'alternate')(client);if(possessor===(integer(alternate.ownerId,'alternate character ID')>>>0)){gui=alternate;primary=0;}}
  const previous=integer(gui.openInventory.id,'previous container ID')>>>0;if(previous===(item.id>>>0))return;
  if(previous!==OBJECT_INVALID){const controlled=await required(p,'clientObject')(client);if(controlled){const result=await required(p,'lookup')(previous);
   if(result.status===0){const old=result.object;if(!old)throw new Error('Native item open dereferences a null successful lookup');
    if(old.objectType===6){const cast=required(p,'asItem')(old);if(cast)await required(p,'closeItem')(cast,controlled.id,0);}
    else if(old.objectType===9){const cast=required(p,'asPlaceable')(old);if(cast)await required(p,'closePlaceable')(cast,controlled.id,0);}
   }
  }}
  await required(p,'setOwner')(gui.openInventory,client,item.id,integer(gui.field8,'previous GUI open flag')===0?1:0);
  await required(p,'setOpen')(gui,1,0);await required(p,'guiMessage')(client,item.id,primary);
 }
 if(integer(item.nativeInventoryObservers364,'observer count')===0)await required(p,'enqueue')(playerId,item.id,10,{type:22});
 item.nativeInventoryObservers364=(integer(item.nativeInventoryObservers364,'observer count')+1)|0;
}

// CNWSItem::CloseInventory140465f80. The status-close SetOpen always targets
// PRIMARY, even when the container owner was found in the alternate GUI.
export async function closeItemInventory(item,playerId,closeGUI,p){
 playerId=integer(playerId,'closing player ID')>>>0;closeGUI=integer(closeGUI,'close GUI flag');
 if(!isContainer(item,p)||integer(item.nativeInventoryObservers364,'observer count')===0)return;
 if(closeGUI!==0){const client=await required(p,'client')(playerId);if(client){
  let gui=required(p,'primary')(client),statusOwner=OBJECT_INVALID,primary=1;
  if((integer(gui.openInventory.id,'primary container ID')>>>0)!==(item.id>>>0)){gui=required(p,'alternate')(client);statusOwner=integer(gui.ownerId,'alternate character ID')>>>0;primary=0;if((integer(gui.openInventory.id,'alternate container ID')>>>0)!==(item.id>>>0))return;}
  if(integer(gui.openInventory.field4,'container open field4')!==0){await required(p,'inventoryStatus')(client,0,statusOwner);await required(p,'setOpen')(p.primary(client),0,0);}
  await required(p,'setOwner')(gui.openInventory,client,OBJECT_INVALID,0);await required(p,'guiMessage')(client,OBJECT_INVALID,primary);
 }}
 if(integer(item.nativeInventoryObservers364,'observer count')===1)await required(p,'enqueue')(playerId,item.id,10,{type:23});
 item.nativeInventoryObservers364=(integer(item.nativeInventoryObservers364,'observer count')-1)|0;
}

// Item EventHandler140466f70..467fdb has no event10 branch. Unlike a
// placeable, a bag's22/23 payload does not run an OnOpen/OnClosed script.
export function receiveItemInventoryEvent(event){
 if(event.eventId!==10)throw new Error('Native item inventory event is unavailable');
}
