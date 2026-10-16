import {OBJECT_INVALID} from './game_object_array.js';
import {clearInventoryUpdateList} from './inventory_gui.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native container input ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native container input provider ${n} is unavailable`);return p[n];};

// ContainerGUI NextPage1404be8a0 and PreviousPage1404bec00. Only placeable
// repositories qualify. Clear primary LUO listA0 before count arithmetic.
export async function stepContainerPage(owner,client,direction,p){
 if(direction!==1&&direction!==-1)throw new Error('Native container page direction is unavailable');
 const placeable=await required(p,'placeable')(integer(owner.id,'owner ID')>>>0);if(!placeable)return;
 const repo=required(p,'repository')(placeable);if(!repo)return;
 await clearInventoryUpdateList(required(p,'primary')(client).lastUpdate,'listA0',p);
 const current=integer(owner.field8,'current page')&255;
 if(direction===-1&&current!==0){owner.field8=(current-1)&255;return;}
 const boundary=integer(repo.boundary,'page boundary')>>>0;if(boundary===0)throw new Error('Native container page divides by zero');
 const pages=Math.trunc(((integer(repo.width,'width')&255)*(integer(repo.height,'height')&255))/boundary)&255;
 owner.field8=direction===1?(current===((pages-1)>>>0)?0:(current+1)&255):(pages-1)&255;
}

// Full decoded GuiContainerMessage140451810..451b27. Closing the old owner
// precedes new lookup. A valid but denied item retains the old owner ID; do
// not replace that path with a universal clear or an access-control shortcut.
export async function receiveContainerInput(client,subtype,p){
 subtype=integer(subtype,'subtype')&255;
 if(subtype===2||subtype===3){await required(p,'step')(required(p,'primary')(client).openInventory,client,subtype===2?1:-1);return 1;}
 if(subtype!==1)return 1;
 const id=integer(required(p,'readObjectId')(),'requested owner ID')>>>0;
 if(integer(required(p,'overflow')(),'overflow')!==0||integer(required(p,'underflow')(),'underflow')!==0)return 0;
 const owner=required(p,'primary')(client).openInventory,previous=integer(owner.id,'previous owner ID')>>>0;
 if(previous!==OBJECT_INVALID){const controlled=await required(p,'clientObject')(client);if(controlled){const old=await required(p,'lookup')(previous);
  if(old.status===0){if(!old.object)throw new Error('Native container input dereferences null old lookup');
   if(old.object.objectType===6){const item=required(p,'asItem')(old.object);if(item)await required(p,'closeItem')(item,controlled.id,0);}
   else if(old.object.objectType===9){const placeable=required(p,'asPlaceable')(old.object);if(placeable)await required(p,'closePlaceable')(placeable,controlled.id,0);}
  }
 }}
 const target=await p.lookup(id);
 if(target.status===0){if(!target.object)throw new Error('Native container input dereferences null successful lookup');
  if(target.object.objectType===9)await required(p,'setOwner')(owner,client,id,0);
  else if(target.object.objectType===6){const item=p.asItem(target.object);if(!item)throw new Error('Native container input dereferences null item cast');
   if(required(p,'repository')(item)){const possessor=integer(item.possessorId,'bag possessor')>>>0,controlled=await p.clientObject(client);
    if(!controlled)throw new Error('Native container input dereferences null controlled object for bag');
    if(possessor===(integer(controlled.id,'controlled ID')>>>0))await p.setOwner(owner,client,id,0);
   }
  }else await p.setOwner(owner,client,OBJECT_INVALID,0);
 }else await p.setOwner(owner,client,OBJECT_INVALID,0);
 return 1;
}
