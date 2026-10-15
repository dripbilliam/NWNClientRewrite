import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native corpse transfer ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native corpse transfer provider ${n} is unavailable`);return p[n];};

// CNWSPlaceable::AcquireItem1404b11d0..1404b134e. Source removal precedes
// the destination-null check. AddItem's return is deliberately ignored;
// successful owner entry returns1 even when fitting/merging returns0.
export async function acquirePlaceableItem(actor,ref,source,x,y,feedback,p){
  source=integer(source,'source ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;feedback=integer(feedback,'feedback');
  const repo=required(p,'repository')(actor);if(!ref.item)throw new Error('Native placeable acquisition item pointer is null');
  if((integer(ref.item.possessorId,'possessor')>>>0)!==source)return 0;
  const owner=required(p,'object')(source);
  if(owner){
    if(owner.objectType===5)await required(p,'removeCreature')(owner,ref.item,0,feedback,0,1);
    else if(owner.objectType===9)await required(p,'removePlaceable')(owner,ref.item,1);
    else if(owner.objectType===6&&integer(required(p,'baseInfo')(owner).container,'container')===1)await required(p,'removeRepository')(p.repository(owner),ref.item);
  }else await required(p,'removeFromArea')(ref.item);
  if(!repo)return 0;
  await required(p,'addItem')(repo,ref,x,y,0,1);
  if(ref.item)await required(p,'setPossessor')(ref.item,actor.id,1,1,0);return 1;
}

// AcquireItemsFromObject1404b1350..1404b1879. Equipment and direct
// repository entries are collected first, then acquired in five size buckets.
// The first14 equipment slots are examined; head/chest/right/left are copied
// into newly allocated canonical objects. Gold uses its native template.
export async function acquireCorpseItems(actor,sourceId,filter,p){
  sourceId=integer(sourceId,'source ID')>>>0;filter=integer(filter,'droppable filter');
  const creature=required(p,'creature')(sourceId),placeable=required(p,'placeable')(sourceId);
  if(!creature&&!placeable)return 0;
  if(creature&&(!required(p,'hasEquipment')(creature)||!required(p,'repository')(creature)))return 0;
  if(placeable&&!p.repository(placeable))return 0;
  const owner=creature??placeable,repo=p.repository(owner),categories=Array.from({length:5},()=>[]);if(!creature)filter=0;
  const collect=async(item,slot)=>{
    if(!item)return;
    const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native corpse base-item query returned null');
    if(filter!==0&&integer(item.droppable,'droppable')===0)return;
    if(slot!==undefined&&[1,2,16,32].includes(slot))item=await required(p,'copyItem')(item,1);
    if(!item)throw new Error('Native corpse item copy returned null');
    const width=integer(base.width,'width')&255,height=integer(base.height,'height')&255;
    categories[width>2?0:width===2?height>2?1:2:height>2?3:4].push(item);
  };
  if(creature)for(let index=0;index<14;index++)await collect(required(p,'equipment')(creature,1<<index),1<<index);
  for(let node=repo.head;node;node=node.next)await collect(required(p,'repositoryItem')(repo,node));
  let count=0;
  for(const category of categories){
    // Native BYTE index wraps indefinitely at256. Diagnose the same fault
    // domain instead of silently truncating items or inventing a wider index.
    if(category.length>255)throw new Error('Native corpse category traversal wraps its BYTE index');
    for(const item of category)if(await required(p,'acquire')(actor,{item},owner.id,255,255,1)!==0)count=(count+1)>>>0;
  }
  if(creature&&integer(creature.nativeGold898,'gold')!==0){
    const item=await required(p,'constructItem')();if(!item)throw new Error('Native corpse gold allocation returned null');
    await required(p,'loadTemplate')(item,'NW_IT_GOLD001',0);
    item.stackSize=integer(creature.nativeGold898,'gold');item.droppable=1;await required(p,'setGold')(creature,0);
    if(await p.acquire(actor,{item},OBJECT_INVALID,255,255,1)!==0)count=(count+1)>>>0;
  }
  return count;
}
