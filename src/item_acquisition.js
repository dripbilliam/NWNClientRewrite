import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native acquisition ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native acquisition provider ${n} is unavailable`);return p[n];};

// CNWSCreature::AcquireItem1403cff30. Source/destination direct IDs, mutable
// item pointer, repository membership and possession remain separate phases.
export async function acquireCreatureItem(actor,ref,source,destination,x,y,allowDrop,feedback,p){
  source=integer(source,'source ID')>>>0;destination=integer(destination,'destination ID')>>>0;
  x=integer(x,'x')&255;y=integer(y,'y')&255;allowDrop=integer(allowDrop,'allow-drop');feedback=integer(feedback,'feedback');
  const item=ref.item;if(!item)throw new Error('Native acquisition dereferences a null item');
  const quantity=integer(item.stackSize,'quantity'),possessor=integer(item.possessorId,'possessor')>>>0;
  let bag=null,otherCreature=null;
  if(possessor!==source){bag=required(p,'itemById')(possessor);if(!bag||bag.possessorId!==source)return 0;source=possessor;}
  let repo;
  if(destination===OBJECT_INVALID)repo=required(p,'repository')(actor);
  else{
    bag=p.itemById(destination);
    if(bag)repo=p.repository(bag);
    else{otherCreature=required(p,'creatureById')(destination);if(!otherCreature)return 0;repo=p.repository(otherCreature);}
  }
  if(!repo)return 0;
  if(x===255&&y===255){const position=await required(p,'findPosition')(repo,ref.item,allowDrop);if(!position)return 0;({x,y}=position);if(required(p,'fit')(repo,ref.item,x,y)===0)return 0;}
  const previous=required(p,'objectById')(source);
  if(previous){
    if(previous.objectType===5)await required(p,'removeCreatureItem')(previous,ref.item,0,1,0,0);
    else if(previous.objectType===9)await required(p,'removePlaceableItem')(previous,ref.item,0);
    else if(previous.objectType===6&&p.repository(previous))await required(p,'removeRepositoryItem')(p.repository(previous),ref.item);
  }else if(bag){
    const incoming=required(p,'baseInfo')(ref.item),container=p.baseInfo(bag);
    if(!incoming||!container)throw new Error('Native nested-container acquisition dereferences unavailable base storage');
    if(incoming.container!==0&&container.container!==0)return 0;
  }
  const result=await required(p,'add')(repo,ref,x,y,allowDrop,1);
  if(result===1){
    await required(p,'encumbrance')(actor,feedback);if(otherCreature)await p.encumbrance(otherCreature,feedback);
    if(!previous&&ref.item)await required(p,'removeFromArea')(ref.item);
    if(ref.item)await required(p,'setPossessor')(ref.item,destination===OBJECT_INVALID?actor.id:destination,1,feedback,quantity);
  }
  return result;
}

// CNWSPlaceable::AcquireItem1404b11d0. Source must equal the incoming direct
// possessor. Old-owner removal precedes the destination repository NULL check.
// AddItem's result is ignored: a nonnull repository returns1 and sets possession
// even on failed insertion. Keep that native asymmetry with creature acquisition.
export async function acquirePlaceableItem(placeable,ref,source,x,y,feedback,p){
 source=integer(source,'source ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;feedback=integer(feedback,'feedback');
 const repository=required(p,'repository')(placeable),item=ref.item;
 if(!item)throw new Error('Native placeable acquisition dereferences a null item');
 if((item.possessorId>>>0)!==source)return 0;
 const previous=required(p,'objectById')(source);
 if(previous){
  if(previous.objectType===5)await required(p,'removeCreatureItem')(previous,ref.item,0,feedback,0,1);
  else if(previous.objectType===9)await required(p,'removePlaceableItem')(previous,ref.item,1);
  else if(previous.objectType===6){
   const info=required(p,'baseInfo')(previous);if(!info)throw new Error('Native placeable acquisition dereferences unavailable container rules');
   if(info.container===1)await required(p,'removeRepositoryItem')(p.repository(previous),ref.item);
  }
 }else await required(p,'removeFromArea')(ref.item);
 if(!repository)return 0;
 await required(p,'add')(repository,ref,x,y,0,1);
 if(ref.item)await required(p,'setPossessor')(ref.item,placeable.id,1,1,0);
 return 1;
}

// Complete CNWSItem::AcquireItem140463e80..1404640d8. A repository on
// the incoming item rejects it even when empty; containers cannot be nested.
export async function acquireContainerItem(container,ref,source,x,y,feedback,p){
 source=integer(source,'source ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;feedback=integer(feedback,'feedback');
 let item=ref.item,bag=null;if(!item)throw new Error('Native container acquisition dereferences a null item');
 if(required(p,'repository')(item))return 0;
 if((integer(item.possessorId,'possessor')>>>0)!==source){bag=required(p,'itemById')(item.possessorId);if(!bag||(integer(bag.possessorId,'bag possessor')>>>0)!==source)return 0;source=integer(ref.item.possessorId,'possessor')>>>0;item=ref.item;}
 const repo=p.repository(container);if(!repo)return 0;
 if(x===255&&y===255){const point=await required(p,'findPosition')(repo,item,0);if(!point)return 0;({x,y}=point);if(await required(p,'fit')(repo,ref.item,x,y)===0)return 0;}
 const previous=required(p,'objectById')(source);
 if(previous){
  if(previous.objectType===5)await required(p,'removeCreatureItem')(previous,ref.item,0,feedback,0,1);
  else if(previous.objectType===9)await required(p,'removePlaceableItem')(previous,ref.item,1);
  else if(previous.objectType===6&&p.repository(previous))await required(p,'removeRepositoryItem')(p.repository(previous),ref.item);
 }else if(bag){
  const incoming=required(p,'baseInfo')(ref.item);if(!incoming)throw new Error('Native container acquisition base storage is unavailable');
  if(incoming.container!==0){const info=p.baseInfo(bag);if(!info)throw new Error('Native container acquisition bag base storage is unavailable');if(info.container!==0)return 0;}
 }
 const result=await required(p,'add')(repo,ref,x,y,0,1);
 if(result===1){if(!previous&&ref.item)await required(p,'removeFromArea')(ref.item);if(ref.item)await required(p,'setPossessor')(ref.item,container.id,1,feedback,0);}
 return result;
}

// CNWSPlaceable::RemoveItem1404b69d0. Only exact membership result1 removes;
// optional possession clearing treats any nonzero INT as true.
export async function removePlaceableItem(placeable,item,clearPossessor,p){
 clearPossessor=integer(clearPossessor,'clear possessor');const repository=required(p,'repository')(placeable);
 if(await required(p,'contains')(repository,item,0)!==1)return 0;
 await required(p,'removeRepositoryItem')(repository,item);
 if(clearPossessor!==0)await required(p,'setPossessor')(item,OBJECT_INVALID,1,1,0);
 return 1;
}

// ExecuteCommandCreateItemOnObject1405138a0. Acquisition's BOOL is ignored;
// even failed acquisition can return a still-registered, unpossessed item ID.
export async function scriptCreateItem(template,target,stack,newTag,p){
  if(!target)return OBJECT_INVALID;
  const item=await required(p,'construct')();
  if(await required(p,'loadTemplate')(item,template,newTag)===0){await required(p,'destroy')(item);return OBJECT_INVALID;}
  item.droppable=1;stack=integer(stack,'requested stack');
  const base=required(p,'baseInfo')(item);if(base)stack=Math.min(stack,integer(base.stacking,'maximum stack')&65535);
  if(stack<1){await p.destroy(item);return OBJECT_INVALID;}
  item.stackSize=stack&65535;const ref={item};
  if(target.objectType===5)await required(p,'acquireCreature')(target,ref,OBJECT_INVALID,OBJECT_INVALID,255,255,1,1);
  else if(target.objectType===9)await required(p,'acquirePlaceable')(target,ref,OBJECT_INVALID,255,255,1);
  else if(target.objectType===14)await required(p,'addStore')(target,item,0,255,255);
  else if(target.objectType===6)await required(p,'acquireContainer')(target,ref,OBJECT_INVALID,255,255,1);
  else{await p.destroy(item);return OBJECT_INVALID;}
  return ref.item?.id??OBJECT_INVALID;
}
