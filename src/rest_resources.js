// The base-object +170 target list is shared with created area effects.
// ApplyEffect14048e350 tail registers only these two native classifications.
export function tracksCasterEffect(effect){return(effect.subtype&0x38)===8||(effect.type&65535)===91&&(effect.durationType&7)===1;}
export function trackCasterEffect(target,effect,p){
 if(!tracksCasterEffect(effect))return;const source=p.object(effect.creatorId),world=source&&p.asWorld(source);if(!world)return;
 const list=p.asWorld(source).nativeCreatedAreaEffects170;if(!list)throw new Error('Native caster effect-target list is unavailable');if(list.indexOf(target.id)<0)list.append(target.id);
}
// RemoveBadEffects14039e020. Live sorted traversal restarts after every
// removal attempt. A retained match is a native non-progress condition.
export async function removeRestEffects(o,p){
 let index=0;while(index<p.effects(o).length){const e=p.effects(o)[index],type=e.type&65535;if(type>99)return;
  const subtype=e.subtype&0x38,duration=e.durationType&7;
  if(subtype!==32&&(duration===1||duration===2&&((subtype-8)&0xffef)===0)){await p.remove(o,e.id);index=0;}
  else index++;
 }
}
// ClearSpellEffectsOnOthers140491110. Iterate original physical target
// cursor backwards, but re-read the owned list after callbacks. AoE destruction
// is queued; effect removal runs synchronously. Clear count, retain capacity.
export async function clearCasterEffects(o,p){
 const list=o.nativeCreatedAreaEffects170;if(!list)throw new Error('Native caster effect-target list is unavailable');
 for(let at=list.count-1;at>=0;at--){const target=p.object(list.ids[at]);if(!target||!p.asWorld(target))continue;
  const areaEffect=p.asAreaEffect(target);
  if(areaEffect&&p.areaEffectCreator(p.asAreaEffect(target))===o.id){await p.destroyLater(o,list.ids[at]);continue;}
  const world=p.asWorld(target);let index=0;while(index<p.effects(world).length){const e=p.effects(world)[index];
   if((e.creatorId>>>0)===(o.id>>>0)&&tracksCasterEffect(e)){await p.remove(p.asWorld(target),e.id);index=0;}
   else index++;
  }
 }
 list.count=0;
}
// RestoreItemProperties14039f760 and recursive repository14039f860.
// Equipped containers are not recursed; carried containers are visited before
// their own properties. Preserve physical repository iteration and duplicates.
export async function restoreRepositoryItems(o,repository,p){
 if(!repository)return;
 for(let cursor=p.first(repository);cursor;cursor=p.next(repository,cursor)){
  const item=p.at(repository,cursor);if(!item)continue;const base=p.baseInfo(item);
  if(base&&p.container(base)!==0)await restoreRepositoryItems(o,p.repository(item),p);
  await p.restore(item,0);await p.update(item,0);
 }
}
export async function restoreCreatureItems(o,p){
 for(let n=0,slot=1;n<18;n++,slot=(slot<<1|slot>>>31)>>>0){const item=p.equipped(o,slot);if(item){await p.restore(item,0);await p.update(item,0);}}
 await restoreRepositoryItems(o,p.repository(o),p);
}
// RemoveDominationEffect1403d7160. After removal the native cursor resets
// then increments, skipping physical index0 on the next pass.
export async function removeDominationEffect(o,p){
 for(let index=0;index<p.effects(o).length;index++){
  const effect=p.effects(o)[index];if((effect.type&65535)===8&&(effect.integers?.[0]|0)===7&&(effect.creatorId>>>0)===(o.masterId>>>0)){await p.remove(o,effect.id);index=0;}
 }
}
