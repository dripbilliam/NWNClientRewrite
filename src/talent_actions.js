import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native talent action ${name} is unavailable`);return v|0;};

// Complete AddUseTalentOnObjectActions140380fb0 and
// AddUseTalentAtLocationActions140380e20. Target lookup deliberately resolves
// a creature here, including spell and item talents. Lower action owners are
// separate; wrapper success ignores their result, as in the original.
export async function addTalentOnObject(actor,type,id,targetId,classIndex,itemId,propertyIndex,casterLevel,metamagic,p){
 type=integer(type,'kind');id=integer(id,'ID');targetId=integer(targetId,'target ID')>>>0;
 const target=p.creature(targetId);if(!target||integer(actor.nativeFieldEc,'commandability')===0)return 0;
 const point=p.position(target).map(Math.fround),area=p.area(actor)?p.area(actor).id>>>0:OBJECT_INVALID;
 if(type===1){
  const auxiliary=id===5?65000+(integer(p.random(),'random')%2):0;
  await p.useFeat(actor,id&65535,auxiliary,targetId,area,null);
 }else if(type===2)await p.useSkill(actor,id&255,0,targetId,point,area,OBJECT_INVALID,0);
 else if(type===0){
  itemId=integer(itemId,'item ID')>>>0;propertyIndex=integer(propertyIndex,'item property index');
  if(itemId!==OBJECT_INVALID&&propertyIndex!==-1)await p.useItem(actor,itemId,propertyIndex&255,0,targetId,point,area,1);
  else await p.addCast(actor,{spellId:id>>>0,classIndex:integer(classIndex,'class index')&255,domainLevel:0,
   metamagic:integer(metamagic,'metamagic')&255,spontaneous:0,position:point,targetId,location:0,
   front:0,cheat:0,path:0,instant:0,featId:-1,casterLevel:integer(casterLevel,'caster level')&255});
 }
 return 1;
}
export async function addTalentAtLocation(actor,type,id,point,classIndex,itemId,propertyIndex,casterLevel,metamagic,p){
 if(integer(actor.nativeFieldEc,'commandability')===0)return 0;
 if(integer(type,'kind')===0){
  itemId=integer(itemId,'item ID')>>>0;propertyIndex=integer(propertyIndex,'item property index');
  if(itemId!==OBJECT_INVALID&&propertyIndex!==-1){
   if(!p.area(actor)||p.area(actor).id>>>0===OBJECT_INVALID)return 1;
   await p.clearActions(actor);const area=p.area(actor);
   await p.useItem(actor,itemId,propertyIndex&255,0,OBJECT_INVALID,point.map(Math.fround),area.id>>>0,1);
  }else await p.addCast(actor,{spellId:integer(id,'ID')>>>0,classIndex:integer(classIndex,'class index')&255,domainLevel:0,
   metamagic:integer(metamagic,'metamagic')&255,spontaneous:0,position:point.map(Math.fround),targetId:OBJECT_INVALID,
   location:1,front:0,cheat:0,path:0,instant:0,featId:-1,casterLevel:integer(casterLevel,'caster level')&255});
 }
 return 1;
}

// ExecuteCommandActionUseTalent14050f620. Native conditional pops matter:
// invalid kinds and absent self leave the target argument on the VM stack.
// The value fields are copied before resolving self or popping the target.
export async function scriptUseTalent(ordinal,self,reader,p){
 const talent=reader.talent(),type=integer(talent?.type,'script kind');
 if(type<=-1)return 0;
 const id=integer(talent.id,'script ID'),classIndex=integer(talent.classIndex,'script class index')&255,
  itemId=integer(talent.itemId,'script item ID')>>>0,propertyIndex=integer(talent.itemPropertyIndex,'script item property index'),
  casterLevel=integer(talent.casterLevel,'script caster level')&255,metamagic=integer(talent.metamagic,'script metamagic')&255;
 const actor=p.creature(integer(self,'script self')>>>0);if(!actor)return 0;
 if(ordinal===309)await p.onObject(actor,type,id,integer(reader.object(),'script target')>>>0,classIndex,itemId,propertyIndex,casterLevel,metamagic);
 else if(ordinal===310){
  const location=reader.location();if(!Array.isArray(location?.position)||location.position.length!==3)throw new Error('Native talent location storage is unavailable');
  await p.atLocation(actor,type,id,location.position.map(Math.fround),classIndex,itemId,propertyIndex,casterLevel,metamagic);
 }
 return 0;
}

// TalentAccess1405485f0 reads raw signed INTs; validity is not a gate.
export function talentAccess(ordinal,talent){
 if(ordinal!==362&&ordinal!==363)throw new Error('Native talent accessor command is invalid');
 return integer(ordinal===362?talent?.type:talent?.id,'accessor value');
}
