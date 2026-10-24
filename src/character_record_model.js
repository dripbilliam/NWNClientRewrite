import {abilityModifier,rulesetInt,intEntry} from './combat_stats.js';
import {attackWeapon,criticalProfile,usesMonkAttackTables,weaponRule} from './combat_weapon.js';
import {unarmedDamageProfile} from './unarmed_damage.js';

export const RECORD_ABILITIES=[['Str','Strength'],['Dex','Dexterity'],['Con','Constitution'],['Int','Intelligence'],['Wis','Wisdom'],['Cha','Charisma']];
export const recordCell=(row,name)=>row?.[Object.keys(row).find(k=>k.toLowerCase()===name.toLowerCase())];
const row=(tables,name,id)=>tables?.[name]?.orderedRows?.[id]??tables?.[name]?.rows?.get(id);
const signed=n=>(n<<24)>>24;
export const signedBonus=n=>n>0?'+'+n:String(n);
// NWCCreatureStats::GetAlignmentStringRef7ef2f0: Good/Evil at+C6,
// Law/Chaos at+C8; thresholds are31/70, with names from the active TLK.
export function recordAlignmentRef(law,good){
 if(!Number.isFinite(law)||!Number.isFinite(good))return null;
 const l=law<31?2:law>69?0:1,g=good<31?2:good>69?0:1;
 return 0x70+l*3+g;
}
export async function recordRuleText(tables,resolve,table,id,column){
 const r=row(tables,table,id),v=recordCell(r,column);
 return v!==undefined&&v!=='****'?await resolve({strRef:Number(v)>>>0}):'';
}
export async function recordEntries(records,table,tables,resolve){
 return(await Promise.all(records.map(async e=>{const r=row(tables,table,e.id);return{...e,name:await recordRuleText(tables,resolve,table,e.id,table==='feat'?'FEAT':'Name')||recordCell(r,'Label')||`${table} ${e.id}`,description:await recordRuleText(tables,resolve,table,e.id,'Description'),icon:recordCell(r,'Icon')};}))).sort((a,b)=>a.name.localeCompare(b.name)||a.id-b.id);
}
export async function recordLabels(resolve){
 const refs={experience:314,nextLevel:315,fortitude:317,reflex:318,will:319,baseAttack:40424,mainWeapon:58290,unarmed:58291,attack:58292,damage:58313,offhandWeapon:58328,notApplicable:58329,spellResistance:58349,arcaneFailure:58350,armorPenalty:58351,critical:58312};
 return Object.fromEntries(await Promise.all(Object.entries(refs).map(async([k,ref])=>[k,await resolve({strRef:ref})])));
}
export function recordAbilities(current,bonuses,rules,modifiers=null){
 return RECORD_ABILITIES.map(([key,label],i)=>{const score=current?.[i],adjustment=bonuses?.[i]??0,modifier=modifiers?.[i]??(Number.isInteger(score)?abilityModifier(score&255,rules):null);return{key,label,score,adjustment,modifier,modifierAdjustment:score===undefined?0:modifier-abilityModifier((score-adjustment)&255,rules)};});
}
// Native7f4070/7f6590 projection of the received CCombatInformation. These
// are display modifiers only; no local attack roll or server stat replacement.
export function recordAttacks(info,bab,monk,rules,offhand=false,feats=[],hasMainWeapon=false){
 if(!info||!Number.isInteger(bab)||bab===-1)return null;
 const count=offhand?(info.field18?(feats.includes(20)?2:1):0):info.field0;
 if(!count)return'';const bonus=offhand?info.field3:info.field1;if(!Number.isInteger(bonus))return null;
 const universal=(info.group0??[]).filter(n=>[1,2,6,7].includes(n.field2)&&n.field2!==(offhand?1:2)&&(!hasMainWeapon||n.field2!==7)&&n.field5===28&&!n.field3&&!n.field4).reduce((n,e)=>n+e.field0,0);
 const step=rulesetInt(rules,monk?'MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER_MONK':'MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER',monk?3:5);
 return Array.from({length:count},(_,i)=>signedBonus(bab+signed(bonus)+universal-step*i)).join('/');
}
// Native7f2990: display each received damage node with active GameString,
// CharsheetStrref, damage-group colors and optional alignment/race qualifiers.
export async function recordDamageBonuses(nodes,tables,resolve,{offhand=false,hasMainWeapon=false}={}){
 const result=[];
 for(const n of nodes??[]){
  if(![1,2,6,7].includes(n.field2)||n.field2===(offhand?1:2)||hasMainWeapon&&n.field2===7)continue;
  const amount=n.field0<6?signedBonus(n.field0):await recordRuleText(tables,resolve,'iprp_damagecost',n.field0,'GameString');
  const type=await recordRuleText(tables,resolve,'damagetypes',n.field1,'CharsheetStrref'),group=intEntry(tables.damagetypes,n.field1,'DamageTypeGroup');let color=null;
  if(group.found&&tables.damagetypegroups){const rgb=['ColorR','ColorG','ColorB'].map(c=>intEntry(tables.damagetypegroups,group.value,c));if(rgb.every(c=>c.found))color='rgb('+rgb.map(c=>Math.max(1,Math.min(255,c.value))).join(',')+')';}
  let suffix='';const qualifiers=[];
  if(n.field3)qualifiers.push(await resolve({strRef:n.field3===2?268:n.field3===3?267:n.field4===1?116:264}));
  if(n.field4)qualifiers.push(await resolve({strRef:n.field4===4?265:n.field4===5?266:264}));
  if(n.field5!==28)qualifiers.push(await recordRuleText(tables,resolve,'racialtypes',n.field5,'NamePlural'));
  if(qualifiers.length)suffix=' '+await resolve({strRef:7603})+' '+qualifiers.filter(Boolean).join(' ');
  const prefix=amount.includes('+')||amount.startsWith('-')?amount:'+'+amount;
  result.push({value:prefix+' '+type+suffix,tone:'damage',parts:[{text:prefix+' '},{text:type,color},{text:suffix}]});
 }
 return result;
}
export async function networkCharacterRecord(world,actor,{tables,resolve,portrait,identity}){
 const s=actor.inventoryStats??{},p=actor.playerState??{},r=actor.replicated??{},stats=r.stats??{},names=r.name??actor.appearance?.name;
 const name=names?.text??(await Promise.all([resolve(names?.firstName),resolve(names?.lastName)])).filter(Boolean).join(' ');
 const labels=await recordLabels(resolve),abilities=recordAbilities(s.fields70??p.abilities?.current,s.fields7d,tables),racial=stats.racialType;
 const alignmentRef=recordAlignmentRef(stats.fieldDE6,stats.fieldDE4),classes=await Promise.all((stats.classes??[]).map(async c=>`${await recordRuleText(tables,resolve,'classes',c.id,'Name')} (${c.level})`));
 const level=(stats.classes??[]).reduce((n,c)=>n+c.level,0),xp=intEntry(tables.exptable,level,'XP'),hp=r.hitPoints;
 const feats=[...new Set([...(p.feats??[]),...(p.bonusFeats??[]),...(s.feats??[]).map(f=>f.id),...(s.fields118??[]),...(s.fields128??[])])];
 const details=[],add=(label,value,tone)=>details.push({label,value,tone}),info=s.combatInformation;
 const equipment=world.inventories.get('I')?.entries,weapon=slot=>equipment?world.registry.get(equipment.find(e=>e.slot===slot)?.id)?.item:actor.appearance?.equipment?.find(e=>e.slot===slot)?.item;
 const right=weapon(16),left=weapon(32),base=item=>item?row(tables,'baseitems',item.baseItem):null;
 add(labels.mainWeapon,right?await resolve(right.name):labels.unarmed);
 add(labels.attack,recordAttacks(info,s.field9b,s.fielda0,tables,false,feats,Boolean(right)));
 const damage=(item,offhand)=>{
  if(!info)return null;if(offhand&&!info.field18)return labels.notApplicable;
  const b=base(item),dice=item?Number(recordCell(b,'NumDice')):info.field8,die=item?Number(recordCell(b,'DieToRoll')):info.field9,bonus=offhand?info.field4:info.field2;
  if(!Number.isInteger(dice)||!Number.isInteger(die)||!Number.isInteger(bonus))return null;
  const threat=offhand?info.field1c:info.field13,mult=offhand?info.field1d:info.field14;
  return `${dice}-${dice*die}${bonus?' '+(bonus<0?'-':'+')+' '+Math.abs(bonus):''} (${labels.critical||'Critical:'} ${threat<=1?'20':21-threat+'-20'} / x${mult})`;
 };
 add(labels.damage,damage(right,false));details.push(...await recordDamageBonuses(info?.group1,tables,resolve,{hasMainWeapon:Boolean(right)}));add(labels.offhandWeapon,info?.field18?await resolve((left??right)?.name):labels.notApplicable);
 if(info?.field18){add(labels.attack,recordAttacks(info,s.field9b,s.fielda0,tables,true,feats,Boolean(right)));add(labels.damage,damage(left??right,true));details.push(...await recordDamageBonuses(info.group1,tables,resolve,{offhand:true,hasMainWeapon:Boolean(right)}));}
 // SetData9b6380 assembly:98=>TLK13d,9a=>13e,99=>13f. XP is94.
 add(labels.fortitude,s.field98);add(labels.reflex,s.field9a);add(labels.will,s.field99);add(labels.baseAttack,s.field9b===-1?null:s.field9b);
 add(labels.spellResistance,info?.field5);add(labels.arcaneFailure,info?`${info.field6}%`:null);add(labels.armorPenalty,info?info.field7===0?'0':'-'+info.field7:null);
 return{identity,name,labels,race:stats.fieldD28||await recordRuleText(tables,resolve,'racialtypes',racial,'Name'),alignment:alignmentRef===null?'':await resolve({strRef:alignmentRef}),classes,abilities,portrait:await portrait(),armorClass:p.combat?.armorClass,currentHP:hp?hp.current+(hp.fieldE8??0):null,maximumHP:hp?.maximum,experience:s.field94,nextExperience:xp.found?xp.value:null,details,
  skills:await recordEntries((s.skills??[]).filter(e=>e.flag).map(e=>({id:e.index,value:e.value,binding:e.value>0?{type:3,intParam:e.index}:null})),'skills',tables,resolve),feats:await recordEntries(feats.map(id=>({id,binding:{type:4,intParam:id}})),'feat',tables,resolve),waiting:{Skills:'Waiting for server skill details.',Feats:'Waiting for server feat details.'}};
}

export async function localCharacterRecord(session,{resolve,portrait,tab='Character'}){
 const actor=session.player,s=actor.stats,rules=session.characterRules,root=actor.creatureData??actor.authored,labels=await recordLabels(resolve),alignment=recordAlignmentRef(root.LawfulChaotic,root.GoodEvil),details=[];
 const add=(label,value)=>details.push({label,value}),items=session.equippedItems(actor),right=attackWeapon(items,rules),left=attackWeapon(items,rules,true),cache=actor.nativeCombatInformationD70?.scalars;
 if(s?.combat){
  add(labels.mainWeapon,right?await resolve(right.data.LocalizedName)||right.name:labels.unarmed);
  const monk=usesMonkAttackTables(actor,items,rules),step=rulesetInt(rules,monk?'MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER_MONK':'MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER',monk?3:5),count=cache?.[0];
  const attacks=hand=>{const bonus=s.combat.attackBonuses?.[hand?'offhand':weaponRule(right,rules,'RangedWeapon')?'ranged':'melee'];return bonus===undefined||count===undefined?null:Array.from({length:hand?(cache?.[24]?(s.feats.includes(20)?2:1):0):count},(_,i)=>signedBonus(bonus-step*i)).join('/');};
  const damage=hand=>{const item=hand?left:right,unarmed=unarmedDamageProfile(actor,rules),dice=item?weaponRule(item,rules,'NumDice'):unarmed.dice,die=item?weaponRule(item,rules,'DieToRoll'):unarmed.sides,bonus=cache===undefined?null:signed(cache[hand?4:2]),critical=criticalProfile(actor,items,rules,hand);return bonus===null?null:`${dice}-${dice*die}${bonus?' '+(bonus<0?'-':'+')+' '+Math.abs(bonus):''} (${labels.critical||'Critical:'} ${critical.threat===20?'20':critical.threat+'-20'} / x${critical.multiplier})`;};
  const nodes=actor.nativeCombatInformationD70?.damageNodes?.map(n=>Object.fromEntries([...n].map((v,i)=>['field'+i,i===0?signed(v):v])));
  add(labels.attack,attacks(false));add(labels.damage,damage(false));details.push(...await recordDamageBonuses(nodes,rules,resolve,{hasMainWeapon:Boolean(right)}));add(labels.offhandWeapon,cache?.[24]?left?await resolve(left.data.LocalizedName)||left.name:null:labels.notApplicable);
  if(cache?.[24]){add(labels.attack,attacks(true));add(labels.damage,damage(true));details.push(...await recordDamageBonuses(nodes,rules,resolve,{offhand:true,hasMainWeapon:Boolean(right)}));}
  for(const name of ['fortitude','reflex','will'])add(labels[name],s.combat.saves?.[name]);add(labels.baseAttack,s.combat.baseAttackBonus);add(labels.spellResistance,cache?.[5]);add(labels.arcaneFailure,cache?cache[6]+'%':null);add(labels.armorPenalty,cache?cache[7]===0?'0':'-'+cache[7]:null);
 }
 const skills=[];
 if(tab==='Skills'&&s)for(let id=0;id<rules.skills.orderedRows.length;id++)if(await session.combat.canUseSkill(actor,id))skills.push({id,value:await session.combat.skill(actor,id,null,0),binding:{type:3,intParam:id}});
 return{identity:actor,name:actor.name,labels,portrait:await portrait(),race:s?.subrace||await recordRuleText(rules,resolve,'racialtypes',s?.race,'Name'),alignment:alignment===null?'':await resolve({strRef:alignment}),classes:await Promise.all((s?.classes??[]).map(async c=>`${await recordRuleText(rules,resolve,'classes',c.id,'Name')} (${c.level})`)),abilities:recordAbilities(RECORD_ABILITIES.map(([key])=>s?.equippedAbilities[key]),RECORD_ABILITIES.map(([key])=>s?.abilityBonuses[key]??0),rules),armorClass:s?.combat?.armorClass,currentHP:session.hitPoints(actor.id,false),maximumHP:s?.maxHP,experience:s?.xp,nextExperience:s?.nextXP,details,skills:await recordEntries(skills,'skills',rules,resolve),feats:tab==='Feats'?await recordEntries((s?.feats??[]).map(id=>({id,binding:{type:4,intParam:id}})),'feat',rules,resolve):[]};
}
