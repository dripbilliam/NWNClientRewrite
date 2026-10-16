const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native affliction ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native affliction provider ${n} is unavailable`);return p[n](...args);};
const get=(e,i)=>integer(e.integers?.[i],`integer${i}`),set=(e,i,v)=>{e.integers[i]=integer(v,`integer${i}`);};
const cstring=v=>String(v).split('\0')[0];
function selector(text,fallback){const index=['STR','DEX','CON','INT','WIS','CHA'].indexOf(cstring(text));return index<0?fallback:index;}
const entry=(p,kind,id,column)=>integer(call(p,'tableInt',kind,id,column).value,`${kind}.${column}`);
async function immune(actor,effect,category,code,p){
 const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);
 if(integer(effect.bypassImmunity,'immunity override')!==0||await call(p,'immunity',actor,category,source,1)===0)return false;
 const data={objectIds:[actor.id>>>0]};if(source)await call(p,'feedback',source,code,structuredClone(data));await call(p,'feedback',actor,code,data);return true;
}
async function icon(actor,effect,id,loading,p){const child=call(p,'copyConstruct',effect,1);child.type=67;set(child,0,id);await call(p,'apply',actor,child,loading);}
async function visual(actor,effect,id,p,loading=0){const child=call(p,'copyConstruct',effect,0);child.type=30;set(child,0,id);await call(p,'apply',actor,child,loading);}
function abilityDamage(effect,ability,amount,kind,p){
 const child=call(p,'create',37,effect.creatorId,[],0);
 child.duration=effect.duration;child.subtype=(integer(child.subtype,'new subtype')&0xffc0)|(integer(effect.subtype,'source subtype')&56);child.durationType=effect.durationType&7;child.spellId=effect.spellId;
 set(child,0,ability);set(child,1,amount);set(child,2,kind);child.exposed=true;return child;
}
async function save(actor,effect,dc,category,p){return(integer(await call(p,'save',actor,1,dc&65535,category,effect.creatorId>>>0,1,0,0),'save result')&255)!==0;}

// Complete OnApplyPoison14042fce0. Default_* strings compare case-sensitively;
// unknown primary selectors fall back to Dice_1, secondary keeps primary kind.
export async function applyPoison(actor,effect,p,loading=0){
 if(!call(p,'asCreature',actor))return 1;
 if(loading!==0){if(call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;await icon(actor,effect,20,loading,p);return 0;}
 if((effect.durationType&7)===0)effect.durationType=2;
 if(call(p,'plot',actor)!==0||await immune(actor,effect,2,133,p))return 1;
 if(call(p,'effects',actor).some(e=>(e.type&65535)===35))return 1;
 const id=get(effect,0),table=[1,2,3,4].every(i=>get(effect,i)===0);let ability,count,sides,dc,script='';
 if(table){
  sides=entry(p,'poison',id,'Dice_1');count=entry(p,'poison',id,'Dam_1');dc=entry(p,'poison',id,'Save_DC');
  ability=selector(call(p,'tableString','poison',id,'Default_1').value,sides);script=String(call(p,'tableString','poison',id,'Script_1').value);
 }else{ability=get(effect,1);count=get(effect,2);sides=get(effect,3);dc=get(effect,4);}
 const amount=integer(call(p,'roll',count&255,sides&255),'initial damage')&65535;
 if(await save(actor,effect,dc,2,p))return 1;
 await call(p,'floatySelf',actor,66946);await call(p,'apply',actor,abilityDamage(effect,ability,amount,1,p),0);await visual(actor,effect,84,p);
 if(script.length)await call(p,'script',script,actor);
 if(table){sides=entry(p,'poison',id,'Dice_2');count=entry(p,'poison',id,'Dam_2');ability=selector(call(p,'tableString','poison',id,'Default_2').value,ability);script=String(call(p,'tableString','poison',id,'Script_2').value);}
 const secondary=integer(call(p,'roll',count&255,sides&255),'secondary damage')&65535;
 set(effect,1,ability);set(effect,2,secondary);set(effect,3,dc);(effect.strings??=Array(6).fill(''))[0]=script;
 const due=call(p,'addTime',call(p,'time'),{day:0,time:60000});set(effect,4,due.day);set(effect,5,due.time);set(effect,6,0);
 await icon(actor,effect,20,loading,p);return 0;
}
// Complete ApplyPoisonPayload1403822d0: marks attempted before saving. Damage
// queues through native event5, then the instant impact/script run immediately.
export async function applyPoisonPayload(actor,effect,p){
 if((effect.type&65535)!==35)return 0;
 const ability=get(effect,1),amount=get(effect,2),dc=get(effect,3),script=String(effect.strings?.[0]??'');set(effect,6,1);
 if(await save(actor,effect,dc,2,p))return 0;
 await call(p,'floatySelf',actor,66947);await call(p,'enqueue',actor,5,abilityDamage(effect,ability,amount,1,p));
 const child=call(p,'copyConstruct',effect,0);child.durationType=0;child.type=30;set(child,0,84);await call(p,'apply',actor,child,0);
 if(script.length)await call(p,'script',script,actor);return 1;
}
// Complete OnApplyDisease14042c1f0; incubation scales by the active module's
// minutes-per-hour BYTE. Only one disease parent can be active at a time.
export async function applyDisease(actor,effect,p,loading=0){
 if(!call(p,'asCreature',actor))return 1;
 if(loading!==0){if(call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;await icon(actor,effect,21,loading,p);await visual(actor,effect,51,p,loading);return 0;}
 if((effect.durationType&7)===0)effect.durationType=2;
 const id=get(effect,0);if(call(p,'plot',actor)!==0||await immune(actor,effect,3,125,p))return 1;
 if(call(p,'effects',actor).some(e=>(e.type&65535)===5))return 1;
 const dc=entry(p,'disease',id,'First_Save');if(await save(actor,effect,dc,3,p))return 1;
 const name=entry(p,'disease',id,'Name');if(integer(typeof effect.exposed==='boolean'?Number(effect.exposed):effect.exposed,'exposed')!==0)await call(p,'floaty',actor,name>>>0);
 await call(p,'floatySelf',actor,66533);
 const now=call(p,'time'),hours=entry(p,'disease',id,'Incu_Hours'),minutes=integer(call(p,'minutesPerHour'),'module minutes per hour')&255;
 const due=call(p,'addTime',now,{day:0,time:Math.imul(Math.imul(minutes,60000),hours)>>>0});set(effect,3,due.day);set(effect,4,due.time);
 await icon(actor,effect,21,loading,p);const child=call(p,'copyConstruct',effect,0);child.type=30;set(child,0,51);await call(p,'apply',actor,child,loading);return 0;
}
// Complete ApplyDiseasePayload140381ab0. After a script, native full-value
// equality re-finds the live record; it may have been removed or changed.
export async function applyDiseasePayload(actor,input,now,p){
 if((input.type&65535)!==5)return 0;let effect=input,result=1;
 const id=get(effect,0),dc=entry(p,'disease',id,'Subs_Save');
 if(await save(actor,effect,dc,3,p)){
  if(get(effect,1)===1){await call(p,'floatySelf',actor,66537);await call(p,'enqueue',actor,14,effect);}else{await call(p,'floatySelf',actor,66536);set(effect,1,1);}
  if(get(effect,2)===0)set(effect,2,1);result=0;
 }else{
  for(let i=1;i<4;i++){
   const sides=call(p,'tableInt','disease',id,`Dice_${i}`);if(!sides.found)continue;
   const count=call(p,'tableInt','disease',id,`Dam_${i}`);if(!count.found)continue;
   const kind=call(p,'tableInt','disease',id,`Type_${i}`);if(!kind.found)continue;
   const amount=integer(call(p,'roll',integer(count.value,'disease count')&255,integer(sides.value,'disease sides')&255),'disease damage')&65535;
   await call(p,'enqueue',actor,5,abilityDamage(effect,integer(kind.value,'disease ability'),amount,2,p));
  }
  await visual(actor,effect,84,p);
  const first=get(effect,2)===0,script=String(call(p,'tableString','disease',id,first?'End_Incu_Script':'24_Hour_Script').value);
  if(script.length){
   const snapshot=call(p,'copyAssign',effect);await call(p,'script',script,actor);
   effect=call(p,'effects',actor).find(candidate=>call(p,'equal',candidate,snapshot));if(!effect)return 0;
  }
  if(first)set(effect,2,1);await call(p,'floatySelf',actor,66535);
 }
 const due=call(p,'addTime',now,{day:1,time:0});set(effect,3,due.day);set(effect,4,due.time);return result;
}
// Only the affliction branches of UpdateEffectList14049dd55..de8a. General
// expiry/other effect owners remain separate. Compare includes exact equality.
export async function updateAffliction(actor,effect,now,p){
 if(effect.type===35){if(get(effect,6)!==0)return false;if(call(p,'compareTime',now,{day:get(effect,4)>>>0,time:get(effect,5)>>>0})<0||!call(p,'asCreature',actor))return false;await call(p,'poisonPayload',actor,effect,now);await call(p,'enqueue',actor,14,effect);return true;}
 else if(effect.type===5){if(call(p,'compareTime',now,{day:get(effect,3)>>>0,time:get(effect,4)>>>0})<0||!call(p,'asCreature',actor))return false;await call(p,'diseasePayload',actor,effect,now);return true;}
 return false;
}
