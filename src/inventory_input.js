import {OBJECT_INVALID} from './game_object_array.js';
import {clearInventoryUpdateList} from './inventory_gui.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native inventory input ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native inventory input provider ${n} is unavailable`);return p[n];};

// InventoryGUI::SetOwner1404beab0. Lookup both before changing either dirty
// flag; update the new creature's encumbrance before committing the owner ID.
export async function setInventoryCharacter(gui,id,p){
 id=integer(id,'character ID')>>>0;const old=integer(gui.ownerId,'previous character ID')>>>0;
 if(old!==id){const previous=await required(p,'creature')(old),next=await p.creature(id);
  if(previous)previous.nativeWeightDirty96c=0;
  if(next){next.nativeWeightDirty96c=1;await required(p,'encumbrance')(next,1);}
 }
 gui.ownerId=id;
}

// SetPanel1404beb40. Original re-fetches client54's game object before its
// virtual creature cast and compares against the LOW BYTE of page count.
export async function setInventoryPanel(gui,client,panel,p){
 panel=integer(panel,'panel BYTE')&255;const id=integer(required(p,'clientObjectId')(client),'client object ID')>>>0;
 let object=await required(p,'object')(id);if(!object||(object.objectType&255)<=4)return;
 object=await p.object(id);if(!object||(object.objectType&255)<=4)throw new Error('Native inventory panel dereferences a null second object lookup');
 const actor=required(p,'asCreature')(object);if(!actor)return;const repo=required(p,'repository')(actor);if(!repo)return;
 const boundary=integer(repo.boundary,'page boundary')>>>0;if(boundary===0)throw new Error('Native inventory panel divides by zero');
 const pages=Math.trunc(((integer(repo.width,'width')&255)*(integer(repo.height,'height')&255))/boundary)&255;
 if(panel>=pages||panel===(integer(gui.fieldC,'current panel')&255))return;
 await clearInventoryUpdateList(gui.lastUpdate,'list90',p);gui.fieldC=panel;
}

// Full decoded HandlePlayerToServerGuiInventoryMessage140451db0..452025.
// Subtype1 is raw BOOL open + OBJECT_ID character; subtype2 BYTE panel +
// raw BOOL selecting primary(nonzero) versus alternate(zero). Unknown accepted.
export async function receiveInventoryInput(client,subtype,p){
 subtype=integer(subtype,'message subtype')&255;
 if(subtype===1){const open=integer(required(p,'readBool')(),'open BOOL'),owner=integer(required(p,'readObjectId')(),'owner ID')>>>0;
  if(integer(required(p,'overflow')(),'overflow')!==0||integer(required(p,'underflow')(),'underflow')!==0)return 0;
  if(client&&await required(p,'clientObject')(client)){
   const object=await p.clientObject(client);if(!object)throw new Error('Native inventory input dereferences a null second controlled object');
   if(owner!==(integer(object.id,'controlled object ID')>>>0)&&owner!==OBJECT_INVALID){
    const gui=required(p,'alternate')(client);await required(p,'setOpen')(gui,open,1);await required(p,'setCharacter')(gui,open!==0?owner:OBJECT_INVALID);
   }else await p.setOpen(required(p,'primary')(client),open,1);
  }
 }else if(subtype===2){const panel=integer(required(p,'readByte')(),'panel BYTE')&255,primary=integer(required(p,'readBool')(),'primary BOOL');
  if(integer(required(p,'overflow')(),'overflow')!==0||integer(required(p,'underflow')(),'underflow')!==0)return 0;
  // Native assumes a valid client for subtype2; do not silently accept null.
  if(!client)throw new Error('Native inventory panel input dereferences a null client');
  await required(p,'setPanel')(required(p,primary!==0?'primary':'alternate')(client),client,panel);
 }
 return 1;
}
