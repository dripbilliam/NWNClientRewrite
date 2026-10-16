import {OBJECT_INVALID} from './game_object_array.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry,rulesetInt} from './combat_stats.js';
import {nativeDistanceSquared} from './nearest_objects.js';

// These IDs and thresholds are original engine counterspell alternatives,
// not replacement spell outcomes. Ruleset overrides remain authoritative.
const dispels=[
  [94,'COUNTERSPELL_LESSER_DISPEL_THRESHOLD',2],
  [41,'COUNTERSPELL_DISPEL_THRESHOLD',3],
  [67,'COUNTERSPELL_GREATER_DISPEL_THRESHOLD',5],
  [122,'COUNTERSPELL_MORDENKAINENS_DISJUNCTION',9]
];
const classes=o=>creatureRoot(o).ClassList;
const flag=(rules,type,name)=>intEntry(rules.classes,type&255,name).value!==0;
function* alternatives(spell,rules){
  yield spell.id>>>0;yield spell.counter1>>>0;yield spell.counter2>>>0;
  for(const [id,key,fallback] of dispels)if(spell.innate<=rulesetInt(rules,key,fallback))yield id;
}

// GetNumCounterSpellingCreatures140392830. Both loops in this particular
// owner require MemorizesSpells!=0, including the uses query loop. Selection
// in BroadcastSpellCast below has a different nonmemorizing second pass.
export function countCounterspellers(actor,spell,rules,p){
  const area=p.area(actor);if(!area)return 0;
  let count=0;
  for(let i=0;i<p.ids(area).length;i++){
    const candidate=p.creature(p.ids(area)[i]);
    if(!candidate||(candidate.combatMode&255)!==4||candidate.counterSpellTargetId!==actor.id||
      nativeDistanceSquared(actor.position,candidate.position)>Math.fround(p.range*p.range))continue;
    let qualified=0;
    for(const query of ['readyCount','uses'])for(let index=0;index<(classes(candidate).length&255);index++){
      const type=classes(candidate)[index].Class&255;
      if(!flag(rules,type,'SpellCaster')||!flag(rules,type,'MemorizesSpells'))continue;
      for(const id of alternatives(spell,rules))if((p[query](candidate,index,id)&255)!==0){qualified=1;break;}
    }
    if(actor.nativeHaste760===1)qualified&=candidate.nativeHaste760;
    if(qualified===1&&count<10)count++;
  }
  return count;
}

// ValidateCounterSpellData1403aae30. Last matching slot wins, including
// an unready slot. Empty/null slots expose native invalid ID/metamagic255.
export function validateCounterspell(actor,id,index,level,p){
  id>>>=0;index&=255;level&=255;let meta=0,domain=0;
  for(let slot=0;slot<(p.slotCount(actor,index,level)&255);slot++)if((p.slotId(actor,index,level,slot)>>>0)===id){
    meta=p.slotMetamagic(actor,index,level,slot)&255;domain=p.slotDomain(actor,index,level,slot)|0;
  }
  actor.nativeCounterSpell7fc=id;actor.nativeCounterClass800=index;
  actor.nativeCounterMeta801=meta;actor.nativeCounterDomain802=domain!==0?level:0;
}

// BroadcastSpellCast140384654..140384c61. Each successful class overwrites
// the selection, so the last eligible class wins. Nonmemorizing selection
// uses the incoming spell's class level even when a dispel alternative wins.
export function selectCounterspell(actor,viewer,spell,index,feat,count,rank,rules,p){
  if((viewer.combatMode&255)!==4||viewer.counterSpellTargetId!==actor.id||viewer.areaId!==actor.areaId||
    (feat&65535)!==65535||(index&255)===254)return {qualified:0,rank};
  rank=(rank+count)|0;let qualified=0;
  for(let classIndex=0;classIndex<(classes(viewer).length&255);classIndex++){
    const type=classes(viewer)[classIndex].Class&255;
    if(!flag(rules,type,'SpellCaster')||!flag(rules,type,'MemorizesSpells'))continue;
    for(const id of alternatives(spell,rules)){
      const ready=p.ready(viewer,classIndex,id);
      if((ready.count&255)!==0){p.validate(viewer,id,classIndex,ready.level&255);qualified=1;break;}
    }
  }
  if(!qualified)for(let classIndex=0;classIndex<(classes(viewer).length&255);classIndex++){
    const type=classes(viewer)[classIndex].Class&255;
    if(!flag(rules,type,'SpellCaster')||flag(rules,type,'MemorizesSpells'))continue;
    for(const id of alternatives(spell,rules))if((p.uses(viewer,classIndex,id)&255)!==0){
      p.validate(viewer,id,classIndex,p.level(spell.id,type)&255);qualified=1;break;
    }
  }
  return {qualified,rank};
}

export function counterspellPoolProviders(){
  const pool=(o,index,level)=>{
    if((index&255)>7||(index&255)>=(classes(o).length&255)||(level&255)>=10)return [];
    const values=o.nativeTalentClasses?.[index&255]?.memorized?.[level&255];
    if(!Array.isArray(values))throw new Error('Native counterspell memorized pool is unavailable');return values;
  };
  return {slotCount:(o,i,l)=>pool(o,i,l).length&255,slotId:(o,i,l,n)=>pool(o,i,l)[n]?.id??0xffffffff,
    slotMetamagic:(o,i,l,n)=>pool(o,i,l)[n]?.metamagic??255,slotDomain:(o,i,l,n)=>pool(o,i,l)[n]?.domain??0};
}

// RemoveCounterspeller14039e5b0 does not compact IDs or stop when count
// reaches zero. Duplicate IDs can decrement the stored count below zero.
export function removeCounterspeller(actor,id){
  if(!Number.isInteger(actor.nativeCounterCount338)||!Array.isArray(actor.nativeCounterspellers310)||actor.nativeCounterspellers310.length!==10)throw new Error('Native counterspeller storage is unavailable');
  if(actor.nativeCounterCount338>0)for(let slot=0;slot<10;slot++)if(actor.nativeCounterspellers310[slot]===(id>>>0)){
    actor.nativeCounterspellers310[slot]=OBJECT_INVALID;actor.nativeCounterCount338=(actor.nativeCounterCount338-1)|0;
  }
}

// RemoveSpellActionFromRound14039ecb0 always visits all ten slots,
// regardless of the count, then the caster. It retains IDs and resources.
export function removeCounterspellRoundActions(actor,p){
  if(!Array.isArray(actor.nativeCounterspellers310)||actor.nativeCounterspellers310.length!==10)throw new Error('Native counterspeller storage is unavailable');
  for(let slot=0;slot<10;slot++)if(actor.nativeCounterspellers310[slot]!==OBJECT_INVALID){
    const candidate=p.creature(actor.nativeCounterspellers310[slot]);
    if(candidate&&p.pending(candidate)===1)p.remove(candidate);
  }
  if(p.pending(actor)===1)p.remove(actor);
}

// All cast-action counter loops visit the ten physical slots, gated by338.
// Holes retain their position, and a missing creature is not a new object.
export function* liveCounterspellers(actor,p){
  if((actor.nativeCounterCount338??0)<=0)return;
  if(!Array.isArray(actor.nativeCounterspellers310)||actor.nativeCounterspellers310.length!==10)throw new Error('Native counterspeller storage is unavailable');
  for(let slot=0;slot<10;slot++){
    const id=actor.nativeCounterspellers310[slot];if(id===OBJECT_INVALID)continue;
    yield {slot,creature:p.creature(id)};
  }
}

// BroadcastSpellCast140384d11..140384e3d, after the observer's roll/message.
export function recordCounterspeller(actor,viewer,qualified,identified,index,feat,casterHaste=actor.nativeHaste760){
  if(casterHaste===1)qualified&=viewer.nativeHaste760;
  if((viewer.combatMode&255)!==4||viewer.counterSpellTargetId!==actor.id||viewer.areaId!==actor.areaId||
    (feat&65535)!==65535||(index&255)===254||qualified!==1||identified===0)return;
  if(!Array.isArray(actor.nativeCounterspellers310)||actor.nativeCounterspellers310.length!==10||!Number.isInteger(actor.nativeCounterCount338))throw new Error('Native counterspeller storage is unavailable');
  const slot=actor.nativeCounterspellers310.indexOf(OBJECT_INVALID);
  if(slot>=0){actor.nativeCounterspellers310[slot]=viewer.id;actor.nativeCounterCount338=(actor.nativeCounterCount338+1)|0;}
}

export async function cancelCounterspellReactions(actor,code,p){
  for(const {creature:o} of liveCounterspellers(actor,p))if(o){
    await p.setAnimation(o,1);await p.setLock(o,OBJECT_INVALID);o.nativeField81c=0;await p.feedback(o,code);
  }
}

export async function consumeCounterspells(actor,p){
  for(const {slot,creature:o} of liveCounterspellers(actor,p))if(o){
    if(await p.consume(o,o.nativeCounterSpell7fc,o.nativeCounterClass800,o.nativeCounterDomain802,o.nativeCounterMeta801,255)===0){
      actor.nativeCounterspellers310[slot]=OBJECT_INVALID;actor.nativeCounterCount338=(actor.nativeCounterCount338-1)|0;
    }else o.nativeField81c=1;
  }
}

export async function finishCounterspellReactions(actor,p){
  for(const {slot,creature:o} of liveCounterspellers(actor,p)){
    if(o){await p.setAnimation(o,1);await p.setLock(o,OBJECT_INVALID);o.nativeField81c=0;}
    actor.nativeCounterspellers310[slot]=OBJECT_INVALID;actor.nativeCounterCount338=(actor.nativeCounterCount338-1)|0;
  }
}
