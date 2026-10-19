const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native on-hit payload provider ${n} is unavailable`);return p[n](...args);};

// GetCanSlayAlignment1403e3760..1403e382a. Parameter is the raw item BYTE,
// including native's permissive default for values outside the nine alignments.
export function canSlayAlignment(actor,target,property,p){
 const creature=call(p,'creature',target);if(!creature)return 0;
 const law=call(p,'alignment',creature,'lawChaos')&255,good=call(p,'alignment',creature,'goodEvil')&255,param=property.Param1Value&255;
 if(param>8)return 1;
 return Number(law===[2,1,3][Math.trunc(param/3)]&&good===[4,1,5][param%3]);
}

export const onHitInstantNames=Object.freeze(['Poison','Disease','AbilityDamage','LevelDrain','SlayRacialGroup','SlayAlignmentGroup','SlayAlignment','Vorpal','DispelMagic','Wounding','VampiricRegeneration']);
// Engine ApplyOnHit owners produce attack-owned effects, delivered by event5
// at impact. They do not directly change hit points or author spell outcomes.
export async function applyOnHitInstant(name,actor,target,property,p){
 if(!onHitInstantNames.includes(name))throw new Error(`Native on-hit payload owner ${name} is unavailable`);
 const param=property.Param1Value&255,creatureWeapon=(property.PropertyName&65535)===72;
 if(name==='SlayRacialGroup'){
  const creature=call(p,'creature',target);if(!creature||(call(p,'race',creature)&65535)!==param)return;
 }else if(name==='SlayAlignmentGroup'){
  const creature=call(p,'creature',target);if(!creature)return;
  if((call(p,'alignment',creature,'goodEvil')&255)!==param&&(call(p,'alignment',creature,'lawChaos')&255)!==param)return;
 }else if(name==='SlayAlignment'){
  call(p,'creature',target);if(canSlayAlignment(actor,target,property,p)===0)return;
 }
 let savedAttack=name==='DispelMagic'?actor.combatRound.currentAttack&255:undefined;
 const append=e=>call(p,'append',actor,e,savedAttack??(actor.combatRound.currentAttack&255));
 const configure=(e,type,integers,durationType=0,subtype=0)=>{
  e.type=type;integers.forEach((v,i)=>{e.integers[i]=v|0;});call(p,'setCreator',e,actor.id);e.durationType=durationType;e.subtype=subtype;return e;
 };
 const impact=['AbilityDamage','LevelDrain'].includes(name)?91:name.startsWith('Slay')?50:null;
 if(impact!==null){const visual=call(p,'create');if(!visual)return;configure(visual,30,[impact]);append(visual);}
 const effect=call(p,'create');if(!effect)return;
 switch(name){
  case 'Poison':{
   effect.type=35;
   if(creatureWeapon)effect.integers[0]=param;
   else{
    [2,param,1,2].forEach((v,i)=>{effect.integers[i]=v;});
    const table=await call(p,'costTable',24),entry=await call(p,'int',table,property.CostValue&65535,'Value');
    effect.integers[4]=(entry.found?entry.value:call(p,'rulesDC','ONHIT_EFFECT_DC',20))|0;
   }
   call(p,'setCreator',effect,actor.id);effect.durationType=2;effect.subtype=8;break;
  }
  case 'Disease':configure(effect,5,[param],2,16);break;
  case 'AbilityDamage':configure(effect,37,[param,1,5],2,creatureWeapon?16:24);break;
  case 'LevelDrain':configure(effect,82,[creatureWeapon?param+1:1,1],2,creatureWeapon?16:24);break;
  case 'DispelMagic':configure(effect,51,[10],0,8);break;
  case 'Wounding':configure(effect,84,[creatureWeapon?param+1:1],2);break;
  case 'VampiricRegeneration':{
   savedAttack=actor.combatRound.currentAttack&255;
   const damage=call(p,'totalDamage',actor,savedAttack);
   configure(effect,86,[property.CostValue&65535,damage]);break;
  }
  default:configure(effect,19,[0,1]);break;
 }
 append(effect);
}
