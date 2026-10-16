const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native scroll learning ${n} is unavailable`);return v|0;};

// Complete CNWSCreature::LearnScroll140396b80. Read the first physical
// active property without a type gate; independently visit every learnable
// class, and consume one scroll only if at least one class reaches AddKnown.
export async function learnScroll(actor,itemId,p){
 const item=p.item(integer(itemId,'item ID')>>>0);
 const feedback=(code,data=null)=>p.feedback(actor,code,data);
 if(!item||integer(item.baseItem,'base item')!==75){await feedback(78);return 0;}
 const property=p.activeProperty(item,0);if(!property)return 0;
 const id=integer(p.propertySpell(property),'spell ID')>>>0,spell=p.spell(id);if(!spell)return 0;
 let repository=null;const owner=p.object(item.possessorId>>>0);
 if(owner){
  if(owner.objectType===5)repository=p.repository(p.asCreature(owner));
  else if(owner.objectType===6&&p.asItem(owner).possessorId===actor.id)repository=p.repository(p.asItem(owner));
  else{await feedback(220);return 0;}
 }
 if(p.contains(repository,item,0)===0){await feedback(220);return 0;}
 let learned=0,error=0;
 const count=integer(p.classCount(actor),'class count')&255;
 for(let index=0;index<count;index++){
  const type=integer(p.classType(actor,index),'class type')&255;if(integer(p.canLearn(type),'LearnScroll flag')===0)continue;
  const level=integer(p.spellLevel(spell,type),'spell level')&255;
  if(level===255){error=224;continue;}
  if((integer(p.spellGain(actor,index,level),'spell gain')&255)===0){error=80;continue;}
  if(integer(p.minimumAbility(actor,index,level),'minimum ability')===0){error=81;continue;}
  const school=integer(p.classSchool(actor,index),'class school')&255;
  if(school!==0){const opposition=p.opposition(school);if(opposition.status===1&&integer(p.spellSchool(spell),'spell school')===integer(opposition.value,'opposition school')){error=219;continue;}}
  let duplicate=false;
  for(let n=0;n<(integer(p.knownCount(actor,index,level),'known spell count')&65535);n++)if((integer(p.known(actor,index,level,n&255),'known spell ID')>>>0)===id){duplicate=true;break;}
  if(duplicate){error=221;continue;}
  await p.addKnown(actor,index,id);learned=1;
 }
 if(learned===0){await feedback((error||79)&65535);return 0;}
 if(integer(item.stackSize,'stack size')>1)item.stackSize=(item.stackSize-1)|0;
 else{await p.removeItem(actor,item,1,1,0,1);await p.destroyItem(item,1);}
 const data=p.feedbackData();p.feedbackInteger(data,0,id|0);await feedback(222,data);return 1;
}

// Item-menu callback1409a81e0. Pending is set even when transport is absent;
// send still occurs when the item lookup fails. Actual writer uses12/13.
export async function selectLearnScroll(itemId,p){
 itemId=integer(itemId,'selected item ID')>>>0;const item=p.item(itemId);if(item)item.nativeItemPending240=1;
 const transport=p.transport();if(transport)await p.send(transport,itemId);
}

// HandlePlayerToServerInventoryMessage140455f50, subtype13. The learn
// result does not gate reply14, which releases the client's pending item.
export async function receiveLearnScrollInput(p){
 if(p.overflow()!==0)return 0;
 const id=p.readObjectId()>>>0;if(p.overflow()!==0||p.underflow()!==0)return 0;
 const message=p.message(),object=p.clientObject(),actor=p.asCreature(object);if(!actor)return 0;
 await p.learn(actor,id);await p.reply(message,p.clientId(),id,14);return 1;
}

// HandleServerToPlayerInventory14079f150, subtype14, with the shared item
// widget refresh14076b760 as a presentation boundary. It acknowledges rejection
// too; a consumed item's absent ID does not prevent successful receipt.
export function receiveLearnScrollReply(p){
 const id=p.readObjectId()>>>0,alternate=p.readBool();
 let context;
 if(alternate===0){context=p.inventory();p.controlled();}
 else{context=p.alternateInventory();p.creature(p.inventoryOwner(context));}
 if(!p.repositoryUI(context)){p.warning('pGuiInvRepository');return 0;}
 if(p.overflow()!==0||!p.objectArray())return 0;
 if(p.overflow()!==0||p.underflow()!==0)return 0;
 const object=p.object(id),item=object?p.asItem(object):null;
 if(item){p.refreshItem(item,context);item.nativeItemPending240=0;}
 return 1;
}
