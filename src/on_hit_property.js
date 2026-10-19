const f=Math.fround;
const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native on-hit property provider ${n} is unavailable`);return p[n](...a);};
// ResolveOnHitEffect1403e7840: engine handler selection, NOT spell metadata.
// Each selected handler remains a separately implemented original owner.
const ordinary={0:['Sleep','duration',3,1],1:['Stun','duration',3,1],2:['Hold','duration',3,0],3:['Confusion','duration',3,1],5:['Daze','duration',3,1],6:['Doom','duration',3,0],7:['Fear','duration',3,4],8:['Knock','item',0,0],9:['Slow','duration',3,0],10:['LesserDispel','item',0,0],11:['DispelMagic','item',0,0],12:['GreaterDispel','item',0,0],13:['MordysDisjunction','item',0,0],14:['Silence','duration',3,0],15:['Deafness','duration',1,0],16:['Blindness','duration',1,0],17:['LevelDrain','property',1,10],18:['AbilityDamage','property',1,10],19:['Poison','property',0,0],20:['Disease','property',0,0],21:['SlayRacialGroup','property',1,11],22:['SlayAlignmentGroup','property',1,11],23:['SlayAlignment','property',1,11],24:['Vorpal','critical',2,0],25:['Wounding','critical',1,0]};
const creatureWeapon={0:['AbilityDamage','property',1,10],1:['Confusion','duration',3,1],2:['Disease','property',0,0],3:['Doom','duration',3,0],4:['Fear','duration',3,4],5:['LevelDrain','property',1,10],6:['Poison','property',0,0],7:['Slow','duration',3,0],8:['Stun','duration',3,1],9:['Wounding','critical',0,0]};
export async function resolveOnHitProperty(actor,target,item,property,offhand,critical,p){
 const type=property.PropertyName&65535,subtype=property.Subtype&65535,param=property.Param1Value&255,cost=property.CostValue&65535,creature=call(p,'creature',target);
 let spec,readParameter=false;
 if(type===67&&creature)spec=['VampiricRegeneration','property',0,0];
 else if(type===36)spec=['DispelMagic','property',0,0];
 else if(type===72)spec=creatureWeapon[subtype];
 else{spec=ordinary[subtype];readParameter=true;}
 if(!spec)return;
 let[name,kind,save,category]=spec;if(kind==='critical'&&name==='Vorpal'&&critical===0){kind='none';save=0;}
 let chance=0,rounds=0,dc=0;
 if(readParameter){
  const reference=await call(p,'int','onhit',subtype,'Param1ResRef');
  if(reference.found&&reference.value===1){const c=await call(p,'int','duration',param,'EffectChance'),d=await call(p,'int','duration',param,'DurationRounds');chance=c.found?c.value|0:0;rounds=d.found?d.value|0:0;}
 }
 const level=()=>call(p,'level',actor)&255;
 const difficulty=async()=>{
  if(type===72)return((subtype===5?(level()>>>1)+10+(creature?call(p,'constitution',creature):0):Math.trunc(level()/3)+10))|0;
  const table=await call(p,'costTable',24),entry=await call(p,'int',table,cost,'Value');return entry.found?entry.value|0:call(p,'rulesDC','ONHIT_EFFECT_DC',20)|0;
 };
 const failedSave=async()=>!save||Boolean(creature)&&((await call(p,'save',creature,save,dc&65535,category,actor.id>>>0,1,0,1))&255)===0;
 if(kind==='duration'){
  if(type===72){dc=Math.trunc(level()/3)+10;if(await failedSave()){rounds=Math.max(1,Math.trunc(f(f(level())/f(3.5))));await call(p,'apply',name,actor,target,rounds);}return;}
  if(chance<1||rounds<1||chance<=call(p,'random')%100)return;
  dc=await difficulty();if(await failedSave())await call(p,'apply',name,actor,target,rounds);return;
 }
 if(kind==='critical'){
  dc=await difficulty();if(await failedSave())await call(p,'apply',name,actor,target,property);return;
 }
 if(kind==='none')return;
 // Non-duration handlers retain their separate native 50% gate, except
 // subtype8 (Knock) and creature-weapon properties, which bypass it.
 if(type!==72&&subtype!==8&&call(p,'random')%100>49)return;
 dc=await difficulty();
 let forceSave=false;
 if(subtype===21&&creature){if((call(p,'race',creature)&65535)!==param)return;forceSave=true;}
 else if(subtype===22&&creature){if((call(p,'alignment',creature,'goodEvil')&255)!==param&&(call(p,'alignment',creature,'lawChaos')&255)!==param)return;forceSave=true;}
 else if(subtype===23&&creature){if(call(p,'canSlay',actor,target,property)===0)return;forceSave=true;}
 if(forceSave){if(((await call(p,'save',creature,save,dc&65535,category,actor.id>>>0,1,0,1))&255)!==0)return;}
 else if(!await failedSave())return;
 if(kind==='item'){
  if(subtype===8){const placeable=call(p,'placeable',target);if(placeable&&dc>=(call(p,'placeableLevel',placeable)&255))return call(p,'apply',name,actor,target,item.id>>>0);const door=call(p,'door',target);if(door&&dc>=(call(p,'doorLevel',door)&255))return call(p,'apply',name,actor,target,item.id>>>0);return;}
  return call(p,'apply',name,actor,target,item.id>>>0);
 }
 return call(p,'apply',name,actor,target,property);
}
