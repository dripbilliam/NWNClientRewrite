import {OBJECT_INVALID} from './game_object_array.js';
import {activeItemProperty} from './combat_on_hit.js';

// Decoded script commands after successful typed VM pops. Engine-structure
// release is supplied explicitly; no game object IDs are allocated here.
export async function scriptAddItemProperty(duration,value,targetId,seconds,p){
 const effect=value;duration|=0;
 if(duration===1){effect.durationType=(effect.durationType&0xfff9)|1;effect.duration=Math.fround(seconds);}
 else if(duration===2)effect.durationType=(effect.durationType&0xfffa)|2;
 else{if(effect)await p.release(effect);return;}
 const object=await p.object(targetId>>>0),item=object?await p.asItem(object):null;
 if(!item){await p.release(effect);return;}
 await p.apply(object,effect,0,1);
 if(duration===2&&await p.ilrSetting()===1){
  const owner=await p.creature(item.possessorId);
  if(owner&&await p.hasStats(owner)&&await p.equipmentLocked(owner)===0&&effect.spellId===419&&await p.slot(owner,item)!==0){
   const level=(await p.level(owner))&255,minimum=(await p.minimumLevel(item))&255;
   if(level<minimum){await p.unequip(owner,item,0,1);const ref={item};await p.repositoryAdd(owner,ref,255,255,0,1);}
  }
 }
}

// RemoveItemProperty14053b4a0..14053b627. Exposure changes on every matching
// ID; the event owns the last matching pointer. Returned VM copies stay intact.
export async function scriptRemoveItemProperty(targetId,value,callerId,p){
 if(!value)return;
 const object=await p.object(targetId>>>0),item=object?await p.asItem(object):null;
 if(!item){await p.release(value);return;}
 let selected=null;
 for(let i=0;i<object.effects.length;i++)if(object.effects[i].id===value.id){selected=object.effects[i];selected.exposed=false;}
 if(selected)await p.event(14,callerId>>>0,targetId>>>0,0,selected);
}

// OnApplyItemProperty post-materialization14042e83e..14042e942, in original
// order. Equipped lookup occurs only after canonical possessor admission.
export async function itemPropertyApplied(item,property,effect,p){
 await p.weight(item);
 if(item.possessorId!==OBJECT_INVALID){
  const owner=await p.creature(item.possessorId);
  if(owner){
   if(await p.equipped(owner,item)!==0){
    const ai=await p.ai();if(ai){const slot=await p.slot(owner,item);await p.applyProperty(ai,item,property,owner,slot,0);}
    await p.combatInformation(owner);
   }
   if([11,81,32].includes(effect.integers[0]|0)){
    if(item.nativeRepository)await p.contentsWeight(item.nativeRepository);else await p.weight(item);
    await p.encumbrance(owner,1);
   }
  }
 }
 await p.visual(item);if(property.durationType===2)item.nativePriceDirty398=1;
}

// OnRemoveItemProperty1404373c0..14043776b. Pool matching deliberately uses
// narrowed values/duration, not propertyId. Active and passive predicates differ.
export async function removeItemProperty(item,effect,p){
 if(item?.objectType!==6)return 1;
 const v=effect.integers,duration=(effect.durationType&7)===1?1:2,active=activeItemProperty(v[0]),pool=active?item.activeProperties:item.passiveProperties;
 let index=-1,property=null;
 for(let i=0;i<pool.length;i++){
  property=pool[i];if(property&&property.type===(v[0]|0)&&property.durationType===duration&&property.subtype===(v[1]&65535)&&property.costTable===(v[2]&255)&&property.costValue===(v[3]&65535)&&property.param1===(v[4]&255)&&property.param1Value===(v[5]&255)&&(active?property.chance===(v[7]&255):property.usesPerDay===(v[6]&255))){index=i;break;}
 }
 if(active){if(index>=0){await p.removeActive(item,index);await p.activeChanged(item,1);}}
 else{
  let owner=null,equipped=false;await p.weight(item);
  if(item.possessorId!==OBJECT_INVALID){owner=await p.creature(item.possessorId);if(owner&&await p.equipped(owner,item)!==0){equipped=true;const ai=await p.ai();if(ai){const slot=await p.slot(owner,item);await p.removeProperty(ai,item,property,owner,slot);}}}
  if(index>=0){await p.removePassive(item,index);if(equipped&&owner)await p.combatInformation(owner);}
  if([11,81,32].includes(v[0]|0)){
   if(item.nativeRepository)await p.contentsWeight(item.nativeRepository);else await p.weight(item);
   if(owner)await p.encumbrance(owner,1);
  }
 }
 await p.visual(item);item.nativePriceDirty398=1;return 1;
}

// CNWSItemPropertyHandler::OnItemPropertyApplied140473790..140473ace:
// snapshot pointer identity, invoke the selected materializer, annotate only
// newly retained effects except innate4. Existing effects are never relabeled.
export async function materializeItemProperty(handler,item,property,owner,slot,loading,p){
 if(!property||(property.type&65535)>=88)return;
 const apply=p.handler(handler,property.type&65535);if(!apply)return;
 const before=new Set(owner.effects);await apply(item,property,owner,slot>>>0,loading|0);
 for(let i=0;i<owner.effects.length;i++){
  const effect=owner.effects[i],duration=effect.durationType&7;
  if(!before.has(effect)&&duration!==4){
   if(duration!==3)await p.warning('duration');
   if(effect.creatorId!==item.id)await p.warning('creator');
   effect.propertyId=property.propertyId;
  }
 }
}

// Removal140473ad0..140473c2f snapshots exact pointers sharing propertyId.
// RemoveEffect(pointer) differs from RemoveEffectById when IDs are duplicated.
export async function dematerializeItemProperty(item,property,owner,slot,p){
 if(!property)return 0;
 const effects=owner.effects.filter(effect=>effect.propertyId===property.propertyId);
 for(const effect of effects)await p.remove(owner,effect);
 if((property.type&65535)<88){const remove=p.handler(property.type&65535);if(remove)return await remove(item,property,owner,slot>>>0);}
 return 0;
}
