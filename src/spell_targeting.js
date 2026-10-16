// Client target setup140704720 and creature veto140704640. A parent's FIRST
// child supplies target/preview metadata, one level only. The submitted spell
// ID remains the original packed WORD; this is not radial child selection.
export function spellTargetDefinition(spellId,p){
  if(!Number.isInteger(spellId))throw new Error('Client spell target ID is unavailable');
  let spell=p.spell(spellId&65535);if(!spell)return null;
  if(spell.children.length)spell=p.spell(spell.children[0]>>>0);
  return spell;
}

export function prepareSpellTarget(actor,request,p,{autoSelf=1,inventoryMode=null,containerMode=null}={}){
  if(!actor)return {mode:'unavailable'};
  const definition=spellTargetDefinition(request.spellId,p);if(!definition)return {mode:'unavailable'};
  const mask=definition.targetType&65535;
  let self=((mask-1)&65531)===0&&(autoSelf&255)!==0;
  if(mask===9)self=(autoSelf&255)!==0&&inventoryMode!==1&&containerMode!==1;
  const targetTypes=[];
  for(const [bit,type]of [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]])if(mask&bit)targetTypes.push(type);
  return {mode:self?'self':'target',request:{...request,spellId:request.spellId&65535},definition,targetTypes};
}

// Returns the original callback's veto (1), not a general object mask test.
// The targeter's registered types perform the remaining object-type admission.
export function spellCreatureTargetVeto(spellId,actor,target,p){
  const definition=spellTargetDefinition(spellId,p);if(!definition)return 1;
  if(target?.objectType===5){
    if(!(definition.targetType&1)&&target.id===actor.id)return 1;
    if(!(definition.targetType&2)&&target.id!==actor.id)return 1;
  }
  return 0;
}
