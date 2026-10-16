import {OBJECT_INVALID} from './game_object_array.js';
import {creatureRoot} from './creature_rules.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native polymorph form ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native polymorph form provider ${n} is unavailable`);return p[n](...args);};
const byte=v=>integer(v,'BYTE')&255,word=v=>integer(v,'WORD')&65535,short=v=>(integer(v,'SHORT')<<16)>>16;
const resref=v=>{if(typeof v!=='string')throw new Error('Native polymorph portrait CResRef is unavailable');return v.split('\0')[0].slice(0,16).toLowerCase();};
const slots=o=>{for(const name of ['nativePolymorphEquipment980','nativePolymorphEquipmentA00'])if(!Array.isArray(o[name])||o[name].length!==18)throw new Error(`Native polymorph ${name} storage is unavailable`);};

// Creature ctor14037a*. These are canonical saved cells, not copies of item
// objects. The existing 9f4/97c/9f8 cells are shared with area/equipment owners.
export function initializePolymorphState(o){
 o.nativeField9fc??=0;o.nativePolymorphEquipment980??=Array(18).fill(OBJECT_INVALID);o.nativePolymorphEquipmentA00??=Array(18).fill(OBJECT_INVALID);
 o.nativePortrait9c8??='';o.nativePortraitId9da??=65535;
 for(const n of ['nativeAppearance9dc','nativeStr9de','nativeCon9df','nativeDex9e0','nativeRace9e2','nativeSound9e4','nativeArmorA50','nativeBaseAttackA54','nativeMaximumHPA58','nativeFortitudeA5a','nativeReflexA5b','nativeWillA5c'])o[n]??=0;
 o.nativeCombatInformationA48??=null;
}

async function racial(o,parent,loading,p){
 const e=parent?call(p,'copyConstruct',parent,0):call(p,'create',0,OBJECT_INVALID,[],0);
 e.type=68;e.durationType=4;call(p,'setCreator',e,o.id);e.integers[0]=word(creatureRoot(o).Race);await call(p,'apply',o,e,loading);
}
async function removeFirstRacial(o,p){const e=call(p,'effects',o).find(e=>(e.type&65535)===68);if(e)await call(p,'remove',o,e.id);}
async function createEquipment(o,table,form,column,slot,identified,p){
 const entry=call(p,'string',table,form,column);if(!entry.found)return;
 const item=call(p,'constructItem');
 if(await call(p,'loadItem',item,entry.value)!==0){if(identified)call(p,'identified',item,1);await call(p,'equip',o,slot,item,1,0,1);}
 else await call(p,'destroyItem',item);
}
async function relocate(o,reset,p){
 const area=call(p,'area',o);if(!area)return;
 const point=call(p,'position',o),out={point:[0,0,0]};
 // Original data140d82170 is float20.0, not the creature radius.
 if(await call(p,'safeLocation',area,point,Math.fround(20),o.nativePathInfo,1,out)!==0)await call(p,'setPosition',o,out.point,0);
 if(reset){const destination=[...call(p,'position',o)];await call(p,'removeFromArea',o,1);await call(p,'addToArea',o,area,...destination,0,1);}
}

// Complete coordinator Polymorph140399e20..14039b3d7. Lower combat snapshot,
// stats, equipment, effects, appearance and area owners are supplied explicitly.
export async function polymorphCreature(o,form,parent,loading,p){
 form=integer(form,'index');loading=integer(loading,'loading flag');slots(o);
 const reuse=integer(o.nativeField9fc,'saved equipment flag');o.nativeField9fc=0;
 if(integer(o.nativeField97c,'equipment lock')!==0)return 0;
 o.nativeField9f4=1;
 try{
  const table=await call(p,'table');if(!table||form>=call(p,'rowCount',table))return 0;
  const appearance=call(p,'int',table,form,'AppearanceType');if(!appearance.found)return 0;
  const root=creatureRoot(o);
  o.nativeAppearance9dc=word(root.Appearance_Type);o.nativePortraitId9da=word(call(p,'portraitId',o));o.nativePortrait9c8=resref(call(p,'portrait',o));
  o.nativeStr9de=byte(root.Str);o.nativeCon9df=byte(root.Con);o.nativeDex9e0=byte(root.Dex);o.nativeRace9e2=word(root.Race);o.nativeSound9e4=word(call(p,'sound',o));
  o.nativeSpellOverride9e8=-1;o.nativeSpellOverride9ec=-1;o.nativeSpellOverride9f0=-1;
  o.nativeCombatInformationA48=call(p,'copyCombatInformation',o);
  o.nativeArmorA50=short(call(p,'armor',o));o.nativeBaseAttackA54=integer(call(p,'baseAttack',o),'base attack');o.nativeMaximumHPA58=short(call(p,'maximumHP',o,1));
  o.nativeFortitudeA5a=byte(call(p,'fortitude',o,0));o.nativeReflexA5b=byte(call(p,'reflex',o,0));o.nativeWillA5c=byte(call(p,'will',o,0));
  root.Appearance_Type=word(appearance.value);
  for(const [column,set]of [['RacialType',v=>{root.Race=word(v);}],['SoundSet',v=>call(p,'setSound',o,word(v))]]){const e=call(p,'int',table,form,column);if(e.found)set(e.value);}
  const portraitId=call(p,'int',table,form,'PortraitId');
  if(portraitId.found&&portraitId.value!==65535)call(p,'setPortraitId',o,word(portraitId.value));
  else{const e=call(p,'string',table,form,'Portrait');call(p,'setPortrait',o,e.found?resref(`po_${e.value}_`):o.nativePortrait9c8);}
  for(const [column,ability]of [['STR',0],['CON',2],['DEX',1]]){const e=call(p,'int',table,form,column);if(e.found)await call(p,'setBaseAbility',o,ability,byte(e.value),ability===2?1:0);}
  const natural=call(p,'int',table,form,'NATURALACBONUS');o.nativeNaturalACD51=natural.found&&natural.value>0?byte(natural.value):0;
  if(loading===0){const hp=call(p,'int',table,form,'HPBONUS');if(hp.found){const e=call(p,'create',15,o.id,[hp.value,1],0);e.durationType=4;await call(p,'apply',o,e,0);}}
  for(let n=0;n<18;n++){
   const item=call(p,'equipped',o,1<<n);if(item)await call(p,'unequip',o,item,0,Number(loading===0));
   // The native ammo comparisons use INDEX against0x800/1000/2000. None
   // match0..17. Keep its actual all-slot snapshot, rather than infer intent.
   o.nativePolymorphEquipment980[n]=item?item.id>>>0:OBJECT_INVALID;
  }
  if(loading!==0&&reuse!==0){
   for(let n=0;n<18;n++){const item=call(p,'item',o.nativePolymorphEquipmentA00[n]);if(item)await call(p,'equip',o,1<<n,item,1,loading,1);o.nativePolymorphEquipmentA00[n]=OBJECT_INVALID;}
  }else{
   for(let n=0;n<18;n++){const item=call(p,'item',o.nativePolymorphEquipmentA00[n]);if(item)await call(p,'destroyItem',item);o.nativePolymorphEquipmentA00[n]=OBJECT_INVALID;}
   // Equipped query SUCCESS suppresses ALL three CreatureWeapon queries,
   // even when the chosen template subsequently fails to load.
   const equipped=call(p,'string',table,form,'Equipped');
   if(equipped.found){const item=call(p,'constructItem');if(await call(p,'loadItem',item,equipped.value)!==0)await call(p,'equip',o,16,item,1,0,1);else await call(p,'destroyItem',item);}
   else for(let n=0;n<3;n++)await createEquipment(o,table,form,`CreatureWeapon${n+1}`,0x4000<<n,true,p);
   await createEquipment(o,table,form,'HideItem',0x20000,true,p);
  }
  for(const [column,field]of [['Spell1','nativeSpellOverride9e8'],['Spell2','nativeSpellOverride9ec'],['Spell3','nativeSpellOverride9f0']]){const e=call(p,'int',table,form,column);if(e.found)o[field]=integer(e.value,column);}
  await removeFirstRacial(o,p);await racial(o,parent,loading,p);
  await call(p,'personalSpace',o);await call(p,'appearanceInfo',o);o.nativeField97c=1;
  if(loading===0)await relocate(o,true,p);
  if(short(call(p,'currentHP',o,0))<1)call(p,'writeHP',o,1);
  return 1;
 }finally{o.nativeField9f4=0;}
}

// Complete UnPolymorph1403a5b50..1403a6150. Restore only the native saved
// fields; stale naturalAC/spell overrides/9f8 deliberately remain gated97c.
export async function unpolymorphCreature(o,parent,p){
 slots(o);const wasDead=call(p,'dead',o);
 if(integer(o.nativeField97c,'equipment lock')===0)return 1;
 o.nativeField9f4=1;
 try{
  const temporary=call(p,'effects',o).find(e=>(e.type&65535)===15&&(e.integers[1]===1||e.integers[1]===0&&(e.durationType&7)===4));
  if(temporary)await call(p,'remove',o,temporary.id);
  o.nativeField97c=0;
  for(const slot of [16,0x4000,0x8000,0x10000,0x20000]){const item=call(p,'equipped',o,slot);if(item){await call(p,'unequip',o,item,0,1);await call(p,'destroyItem',item);}}
  for(let n=0;n<18;n++){const item=call(p,'item',o.nativePolymorphEquipment980[n]);if(item)await call(p,'equip',o,1<<n,item,1,0,1);o.nativePolymorphEquipment980[n]=OBJECT_INVALID;}
  const root=creatureRoot(o);root.Appearance_Type=word(o.nativeAppearance9dc);o.nativeAppearance9dc=0;root.Race=word(o.nativeRace9e2);o.nativeRace9e2=0;call(p,'setSound',o,word(o.nativeSound9e4));o.nativeSound9e4=0;
  if(word(o.nativePortraitId9da)<65534){call(p,'setPortraitId',o,word(o.nativePortraitId9da));o.nativePortrait9c8='';o.nativePortraitId9da=65535;}
  else{call(p,'setPortraitId',o,65535);call(p,'setPortrait',o,resref(o.nativePortrait9c8));o.nativePortrait9c8='';}
  await call(p,'setBaseAbility',o,0,byte(o.nativeStr9de),0);o.nativeStr9de=0;
  await call(p,'setBaseAbility',o,2,byte(o.nativeCon9df),1);o.nativeCon9df=0;
  const dead=call(p,'dead',o);if(dead===1&&wasDead===0||dead!==1&&wasDead===0&&short(call(p,'currentHP',o,0))<1)call(p,'writeHP',o,1);
  await call(p,'setBaseAbility',o,1,byte(o.nativeDex9e0),0);o.nativeDex9e0=0;
  if(!parent)await removeFirstRacial(o,p);await racial(o,null,0,p);
  await call(p,'personalSpace',o);await call(p,'appearanceInfo',o);await relocate(o,false,p);return 1;
 }finally{o.nativeField9f4=0;}
}
