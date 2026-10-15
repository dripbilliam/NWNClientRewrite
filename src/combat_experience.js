import { nativeFloatEntryByIndex } from './movement_rate.js';
import { NativeIdList } from './native_id_list.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { intEntry } from './combat_stats.js';

const f=Math.fround;
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native death XP ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native death XP provider ${name} is unavailable`);return p[name];};
const cvtt=v=>Number.isFinite(v)&&v>=-2147483648&&v<2147483648?Math.trunc(v):-2147483648;

// IsOfficialCampaign14047e430..14047e658. Exact names are engine branches,
// never inferred from the selected filename, module tag or authored display
// name. LoadModuleStart reads Mod_NWMResName only for Mod_IsNWMFile==1.
export function officialCampaign(module){
  if(integer(module.nativeIsNWM448,'NWM flag')===0)return 0;
  let name=module.nativeNWMName450;
  if(typeof name!=='string')throw new Error('Native NWM campaign name is unavailable');
  name=name.split('\0')[0];
  if(['Prelude','Chapter1','Chapter1E','Chapter2','Chapter2E','Chapter3','Chapter4'].includes(name))return 1;
  if(['XP1-Chapter 1','XP1-Chapter 2','XP1-Chapter 3'].includes(name))return 2;
  if(['XP2_Chapter1','XP2_Chapter2','XP2_Chapter3'].includes(name))return 3;
  return 0;
}
export function initializeModuleExperience(module,ifo){
  module.nativeXPScale3be=(ifo.Mod_XPScale??10)&255;
  module.nativeIsNWM448=integer(ifo.Mod_IsNWMFile??0,'authored NWM flag');
  module.nativeNWMName450=module.nativeIsNWM448===1?String(ifo.Mod_NWMResName??''):'';
}

// CalculateDeathExperience140386070..1403861bc, also inlined by
// ApplyDeathExperience14038191d..140381a14. CR+0.49 is added FIRST in f32,
// then the signed clamped potential/effective level difference. Numeric
// XPTable columns are CR+1, physical rows potentialLevel-1. The GetFLOATEntry
// status is ignored by the game; it always writes0/default on failed lookups.
export function calculateDeathExperience(actor,potential,effective,p){
  potential=integer(potential,'potential level');effective=integer(effective,'effective level');
  const module=required(p,'module')(),campaign=module?integer(required(p,'officialCampaign')(module),'campaign classification')&255:0;
  potential=Math.min(Math.max(1,potential),integer(required(p,'maximumLevel')(),'first maximum level'));
  effective=Math.min(Math.max(1,effective),integer(required(p,'maximumLevel')(),'second maximum level'));
  const cr=required(p,'challengeRating')(actor);
  if(typeof cr!=='number')throw new Error('Native death XP challenge rating is unavailable');
  const column=Math.min(Math.max(0,cvtt(f(f((potential-effective)|0)+f(f(cr)+f(.49))))),campaign===3?20:40)+1;
  const value=nativeFloatEntryByIndex(required(p,'xpTable')(),potential-1,column).value;
  const liveModule=required(p,'module')();
  if(!liveModule)throw new Error('Native death XP final module is unavailable');
  const scale=integer(liveModule.nativeXPScale3be,'module XP scale')&255;
  return f(f(f(Math.min(200,scale))/f(10))*value);
}

export function initializeCreatureExperience(actor,root,isDMFile=0){
  actor.nativeStatsIsPCb0=integer(isDMFile,'DM file')!==0?0:integer(root.IsPC??1,'authored stats IsPC');
  const cr=root.ChallengeRating??0;
  if(typeof cr!=='number')throw new Error('Native authored challenge rating is unavailable');
  actor.nativeChallengeRatingD0=f(cr);
}
// GetPotentialLevel1404058f0. Level is BYTE; IsPC must be exactly1.
function advancePotentialLevel(actor,level,p){
  while((integer(required(p,'threshold')(level),'XP threshold')>>>0)<=(integer(required(p,'experience')(actor),'experience')>>>0)){
      if(integer(required(p,'maximumLevel')(),'maximum level')<=level)return level;
      level=(level+1)&255;
      if(level===0)throw new Error('Native potential-level loop wraps its BYTE level; configured maximum is unsupported');
  }
  return level;
}
export function potentialLevel(actor,p){
  const level=integer(required(p,'level')(actor),'level')&255;
  return integer(required(p,'statsIsPC')(actor),'stats IsPC')===1?advancePotentialLevel(actor,level,p):level;
}
// GetEffectiveCRForPotentialLevel140400d70. PC class slots contribute
// loaded EffCRLvlNN for levels2..40; levels0/1/>40 retain their own BYTE.
// Non-PC returns GetLevel, without class effective-CR substitution.
export function effectiveCRForPotentialLevel(actor,rules,p){
  const level=integer(required(p,'level')(actor),'level')&255;
  if(integer(required(p,'statsIsPC')(actor),'stats IsPC')!==1)return level;
  const extra=(advancePotentialLevel(actor,level,p)-level)&255;
  if(!rules.classes)throw new Error('Native effective-CR class table is unavailable');
  const classes=required(p,'classes')(actor);
  if(!Array.isArray(classes)||classes.length>255)throw new Error('Native effective-CR class slots are unavailable');
  let total=extra;
  for(const slot of classes){
    const id=integer(slot.id,'class ID')&255,n=integer(slot.level,'class level')&255;
    const value=((n-2)&255)<39?intEntry(rules.classes,id,`EffCRLvl${String(n).padStart(2,'0')}`).value&255:n;
    total=(total+value)&255;
  }
  return total;
}
const objectId=(v,name)=>{if(!Number.isInteger(v)||v<0||v>0xffffffff)throw new Error(`Native death XP ${name} OBJECT_ID is unavailable`);return v>>>0;};
const awardU32=value=>!Number.isFinite(value)||value<-(2**63)||value>=2**63?0:Number(BigInt.asUintN(32,BigInt(Math.trunc(value))));

// CNWSCreatureStats::AddExperience1403eef50..1403ef167. Unlike the
// GiveXP script command, this engine entry accepts the full unsigned amount.
// Favored class and XP eligibility are active physical 2DA rows; the BYTE
// class levels and IDs match the loaded class slot representation.
export function nativeExperienceAward(actor,amount,rules,p){
  amount=objectId(amount,'award');
  const classes=required(p,'classes')(actor);
  if(!Array.isArray(classes)||classes.length>255)throw new Error('Native XP class slots are unavailable');
  if(classes.length<=1)return amount;
  if(!rules.racialtypes||!rules.classes)throw new Error('Native XP race/class tables are unavailable');
  const row=(table,index)=>table.orderedRows?table.orderedRows[index]:table.rows.get(index);
  const cell=(entry,name)=>entry?.[Object.keys(entry).find(key=>key.toLowerCase()===name.toLowerCase())];
  const race=integer(required(p,'race')(actor),'race')&65535;
  if(!row(rules.racialtypes,race))throw new Error('Native XP race index is outside the loaded rule allocation');
  const favoredEntry=intEntry(rules.racialtypes,race,'Favored');
  // CNWRace ctor1402a13e6 initializes Favored255; LoadRaceInfo1402aac12
  // overwrites the BYTE only when GetINTEntry succeeds.
  let favored=favoredEntry.found?favoredEntry.value&255:255;
  const slots=classes.map(c=>({id:integer(c.id,'class ID')&255,level:integer(c.level,'class level')&255}));
  const info=index=>{const entry=row(rules.classes,index);if(!entry)throw new Error('Native XP class index is outside the loaded rule allocation');return entry;};
  if(favored===255){
    let position=0,highest=0;
    for(let n=0;n<slots.length;n++){
      const slot=slots[n];if(slot.level<=highest)continue;
      const prerequisite=cell(info(slot.id),'PreReqTable');
      if(prerequisite===undefined||prerequisite===''||prerequisite==='****'){highest=slot.level;position=n;}
    }
    favored=slots[position].id;
  }
  const eligible=slot=>slot.id!==favored&&(info(slot.id),intEntry(rules.classes,slot.id,'XPPenalty').value===1);
  let highest=0,penalties=0;
  for(const slot of slots)if(eligible(slot)&&slot.level>highest)highest=slot.level;
  for(const slot of slots)if(eligible(slot)&&highest-slot.level>=2)penalties+=1;
  // Native SSE double constants1 and0.2, cvttsd2si64 followed by low DWORD.
  return awardU32((1-penalties*.2)*amount);
}
export async function addNativeExperience(actor,amount,rules,p){
  amount=objectId(amount,'award');
  if((integer(actor.associateType,'award associate type')&65535)!==0)return;
  const award=nativeExperienceAward(actor,amount,rules,p);
  await required(p,'setExperience')(actor,((integer(required(p,'experience')(actor),'current experience')>>>0)+award)>>>0,1);
}

// CanLevelUp1403f1b30..1403f1bf0. The40 cap depends on actual client
// ownership; an NPC with stats IsPC0 needs no XP threshold at all.
export function nativeCanLevelUp(actor,p){
  const associate=integer(actor.associateType,'level-up associate type')&65535;
  if(((associate-5)&65535)<=3||associate===3)return 0;
  const level=()=>integer(required(p,'level')(actor),'level-up level')&255;
  if(required(p,'client')(actor.id)&&level()>=40)return 0;
  if(level()>=integer(required(p,'maximumLevel')(),'maximum level'))return 0;
  if(integer(required(p,'statsIsPC')(actor),'level-up stats PC')!==0&&
    (integer(required(p,'experience')(actor),'level-up XP')>>>0)<(integer(required(p,'threshold')(level()),'level-up threshold')>>>0))return 0;
  return 1;
}
// SetExperience140415640..140415956. Feedback precedes the XP write;
// signed delta chooses level-history direction independently of unsigned
// gain/loss feedback. History owners remain caller-supplied native operations.
export async function setNativeExperience(actor,xp,update,p){
  xp=objectId(xp,'new experience');update=integer(update,'experience update flag');
  const client=required(p,'client')(actor.id),old=integer(required(p,'experience')(actor),'old experience')>>>0,delta=(xp-old)|0;
  if(integer(required(p,'dm')(actor),'experience DM')!==0)return;
  if(update!==0&&client&&delta!==0){
    const current=integer(required(p,'experience')(actor),'feedback experience')>>>0;
    if(xp>current)await required(p,'feedback')(actor,182,{type:0,integers:[delta]});
    else if(xp<current)await required(p,'feedback')(actor,183,{type:0,integers:[(-delta)|0]});
  }
  await required(p,'writeExperience')(actor,xp);
  if(update===0)return;
  if(delta<0){
    let level=integer(required(p,'level')(actor),'delevel level')&255;
    if(level>integer(required(p,'minimumLevel')(),'initial minimum level'))for(;;){
      if(level===0)break;level=(level-1)&255;
      if((integer(required(p,'threshold')(level),'delevel threshold')>>>0)<=(integer(required(p,'experience')(actor),'delevel XP')>>>0))break;
      if(level<integer(required(p,'historyCount')(actor),'delevel history count')){
        const history=required(p,'history')(actor,level);if(history)await required(p,'levelDown')(actor,history);
      }
      if(level<=integer(required(p,'minimumLevel')(),'live minimum level'))break;
    }
  }else if(delta>0){
    let count=0,can=integer(required(p,'canLevelUp')(actor),'initial level-up eligibility');
    while(can!==0){
      const historyCount=integer(required(p,'historyCount')(actor),'level-up history count');
      if(historyCount<=(integer(required(p,'level')(actor),'history comparison level')&255))break;
      const level=integer(required(p,'level')(actor),'history index level')&255,history=required(p,'history')(actor,level);
      if(history)await required(p,'levelUp')(actor,history,0,0,0,0);
      can=integer(required(p,'canLevelUp')(actor),'live level-up eligibility');
      if(++count>255)throw new Error('Native XP history loop is not making supported BYTE-level progress');
    }
  }
  if(client&&integer(required(p,'canLevelUp')(actor),'notification level-up eligibility')!==0){
    const threshold=integer(required(p,'threshold')(integer(required(p,'level')(actor),'notification level')&255),'notification threshold')>>>0;
    if(old<threshold)await required(p,'feedback')(actor,11,null);
  }
}

// ApplyDeathExperience1403814d0..140381aa6. Caller supplies the captured
// native faction member list; it is NOT reconstructed from registry order.
// Recipient IDs are frozen after scanning, then looked up again for awards.
export async function applyDeathExperience(actor,p){
  const initialCampaign=integer(required(p,'officialCampaign')(required(p,'module')()),'initial campaign')&255;
  if(((integer(actor.associateType,'victim associate type')-2)&65535)<=2)return;
  const cause=required(p,'object')(objectId(actor.lastKillerId,'killer'));if(!cause)return;
  let killer=null;
  if([7,9,10].includes(cause.objectType)){
    const cast=required(p,'asDeathOwner')(cause);if(!cast)return;
    if(objectId(required(p,'deathOwnerId')(required(p,'asDeathOwner')(cause)),'trap owner')===OBJECT_INVALID)return;
    const owner=objectId(required(p,'deathOwnerId')(required(p,'asDeathOwner')(cause)),'trap owner');
    killer=required(p,'creature')(owner);
  }else if(cause.objectType===5)killer=required(p,'asCreature')(cause);
  else return;
  if(!killer||integer(required(p,'faction')(killer),'killer faction')===integer(required(p,'faction')(actor),'victim faction'))return;
  const members=required(p,'factionMembers')(killer);
  if(!(members instanceof NativeIdList))throw new Error('Native death XP canonical faction member storage is unavailable');
  const recipients=new NativeIdList();let potentialSum=0,effectiveSum=0,weight=f(0);
  for(let i=0;i<members.count;i++){
    const member=required(p,'creature')(members.ids[i]);if(!member)continue;
    if(integer(required(p,'dead')(member),'member dead')!==0||integer(required(p,'dying')(member),'member dying')!==0)continue;
    if(!(member.areaId===actor.areaId&&nativeDistanceSquared(actor.position,member.position)<=f(1600))&&member.id!==killer.id)continue;
    if(integer(required(p,'isPC')(member),'member PC')!==0||integer(required(p,'possessed')(member),'member possessed')!==0){
      potentialSum=(potentialSum+(integer(required(p,'potentialLevel')(member),'potential level')&255))|0;
      effectiveSum=(effectiveSum+(integer(required(p,'effectiveLevel')(member),'effective level')&255))|0;
      recipients.append(objectId(member.id,'recipient'));
    }
    // Separate PC/possession queries are repeated by the weight owner.
    weight=f(weight+(integer(required(p,'isPC')(member),'weight PC')!==0||integer(required(p,'possessed')(member),'weight possessed')!==0?f(1):f(.25)));
  }
  const count=f(recipients.count),potential=cvtt(f(f(potentialSum)/count));
  const effective=cvtt(f(f(initialCampaign===1?effectiveSum:potentialSum)/count));
  const total=calculateDeathExperience(actor,potential,effective,p),share=f(total/Math.max(f(1),weight));
  for(let i=0;i<recipients.count;i++){
    const member=required(p,'creature')(recipients.ids[i]);if(!member)continue;
    if(integer(required(p,'isPC')(member),'award PC')!==0||integer(required(p,'possessed')(member),'award possessed')!==0)
      await required(p,'addExperience')(member,awardU32(share));
  }
}
