import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item destruction ${n} is unavailable`);return v|0;};
// Item EventHandler140466f70, event11 branch140467c22..140467f66.
// Ownership removal precedes RemoveFromArea and the actual destructor. A
// scheduled destroy event tests destroyable, independently of the plot flag.
export async function receiveItemDestroy(item,p){
 if(integer(item.nativeDestroyableF0,'destroyable')===0)return;
 const base=p.baseInfo(item);
 if(base&&integer(base.container,'container flag')!==0)for(const client of p.clients()){
  const controlled=p.clientObject(client);if(controlled&&p.openContainerId(client)===item.id)await p.closeContainer(item,controlled.id,1);
 }
 const owner=p.object(item.possessorId>>>0);
 if(owner){
  if(owner.objectType===5)await p.removeCreatureItem(p.asCreature(owner),item,0,1,0,1);
  else if([6,9,14].includes(owner.objectType)){
   let repositoryOwner=null;
   if(owner.objectType===6)repositoryOwner=p.asItem(owner);
   else if(owner.objectType===9){const placeable=p.asPlaceable(owner);if(integer(p.hasInventory(placeable),'placeable inventory')===1)repositoryOwner=placeable;}
   if(repositoryOwner){
    const repo=p.repository(repositoryOwner);
    for(const id of p.repositoryIds(repo)){const object=p.object(id>>>0);if(object===item){await p.removeRepositoryItem(repo,item);break;}}
   }else if(owner.objectType===14){const store=p.asStore(owner);if(await p.inStore(store,item.id)===1)await p.removeStoreItem(store,item);}
   await p.setPossessor(item,OBJECT_INVALID,1,1,0);
  }
 }else{
  const holder=p.object(integer(p.lastHolder(item),'last holder ID')>>>0);
  if(holder&&p.asCreature(holder)&&p.conversation(p.asCreature(holder),1))await p.removeDialogItem(p.conversation(p.asCreature(holder),1),item.id);
 }
 await p.removeFromArea(item);await p.destroy(item,1);
}
