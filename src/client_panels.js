import { OBJECT_INVALID } from './game_object_array.js';
import {createInventoryGUI} from './inventory_gui.js';
import {createCharacterSheetGUI} from './character_sheet.js';

const f=Math.fround,invalid=OBJECT_INVALID;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native client-panel provider ${n} is unavailable`);return p[n];};
const id=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native client-panel ${n} is unavailable`);return v>>>0;};
const squared=(a,b)=>{
  if(!Array.isArray(a)||!Array.isArray(b)||![...a,...b].every(Number.isFinite))throw new Error('Native panel distance points are unavailable');
  const x=f(f(a[0])-f(b[0])),y=f(f(-a[2])-f(-b[2])),z=f(f(a[1])-f(b[1]));return f(f(f(x*x)+f(y*y))+f(z*z));
};

// Selected local client GUI/area state, not full CNWSPlayer/network replication.
// InventoryGUI1404b7bf0 and StoreGUI1404b7c80 constructors initialize their
// open-container/store IDs to INVALID. Unmapped LUO inventory is separate.
export function createLocalClientPanelState(object,skillCount=0){
  // CNWSPlayer ctor1404b79be/1404b7a39/1404b7b5c/1404b7b6d. No
  // PLAYER_ID is invented here: the native sender requires an explicit one.
  const client={object,nativeAreaTransitionBmp20:-1,nativeUserTransitionBmp28:'',nativeLoadState50:0,nativeModuleInfoSucceededCC:0,nativeLastUpdateObjectA8:null,
    inventoryGUI:createInventoryGUI(),alternateInventoryGUI:createInventoryGUI(),
    storeGUI:{id:invalid,field4:5,field5:0,position:[0,0,-0]}};
  // Defer JS backing allocation until this panel is used. Constructor values
  // stay native; unrelated inventory/message consumers need no skill-table data.
  let sheet;Object.defineProperty(client,'characterSheetGUI',{enumerable:true,get:()=>sheet??=createCharacterSheetGUI(typeof skillCount==='function'?skillCount():skillCount)});
  return client;
}

// AutoCloseGUIPanels140382920..140382bae: inventory first, then store,
// then barter. A local character panel is unrelated to an open container.
// Store/barter distance tests happen BEFORE the walk commits new position.
export async function autoClosePanels(actor,checkDistance,p){
  const client=await p.client(actor.id);if(!client)return;
  const inventory=client.inventoryGUI,store=client.storeGUI;
  if(!inventory?.openInventory||!store)throw new Error('Native client GUI ownership is unavailable');
  const containerId=id(inventory.openInventory.id,'open inventory ID');
  if(containerId!==invalid){
    const object=await p.object(containerId);
    if(object?.objectType===6)await required(p,'closeItemInventory')(object,actor.id,1);
    else if(object?.objectType===9)await required(p,'closePlaceableInventory')(object,actor.id,1);
  }
  if(id(client.storeGUI.id,'store ID')!==invalid){
    const currentStore=client.storeGUI;
    if(checkDistance===0||squared(currentStore.position,(await required(p,'clientObject')(client)).position)>4){
      await required(p,'closeStore')(currentStore,client,1);await required(p,'closeStoreMessage')(client);
    }
  }
  const barter=actor.nativeBarter;
  if(barter!==null&&barter!==undefined){
    const peerId=id(barter.peerId,'barter peer');
    if(peerId!==invalid){
      const peer=await required(p,'creature')(peerId);
      if(peer){
        if(checkDistance===0)await required(p,'cleanBarter')(barter);
        else{const gameObject=await required(p,'clientObject')(client),range=f(await required(p,'talkRange')());
          if(squared(peer.position,gameObject.position)>f(range*range))await required(p,'cleanBarter')(barter);}
      }
    }
  }
}
