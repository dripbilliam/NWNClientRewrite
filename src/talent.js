import { OBJECT_INVALID } from './game_object_array.js';
import { creatureRoot } from './creature_rules.js';
import { featInfo } from './feat_uses.js';
import { intEntry } from './combat_stats.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native talent ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native talent provider ${name} is unavailable`);return p[name];};
const count=table=>{if(!table)throw new Error('Native talent rules table is unavailable');return table.orderedRows?.length??table.rows.size;};

// CScriptTalent14048bd50..14048bd73. Selector initialization1403faeb4
// overrides three constructor cells; an invalid result is still a value.
export function scriptTalent(type=-1,id=-1){return {type:type|0,id:id|0,classIndex:0,itemId:OBJECT_INVALID,itemPropertyIndex:-1,casterLevel:255,metamagic:255};}
export function selectionTalent(){return {...scriptTalent(),classIndex:255,metamagic:0};}
export function talentValid(t){return Number(integer(t?.type,'type')!==-1);}
const enabled=o=>{const word=integer(o.nativeField8d4,'creature WORD8d4')&65535;return (word&6)===6||word===0;};
const rank=async(p,o,id)=>(integer(await required(p,'skillRank')(o,id),'skill rank')<<24)>>24;
const untrained=(rules,id)=>intEntry(rules.skills,id,'Untrained').value;

// GetCreatureHasTalent1403faab0. Spell eligibility (including its distinct
// disabled-state branch) belongs to a separate provider, never a fake zero.
export async function hasTalent(o,type,id,metamagic,rules,p){
  type=integer(type,'type');id=integer(id,'ID');metamagic=integer(metamagic,'metamagic')&255;
  if(type===-1||id===-1)return 0;
  if(enabled(o)){
    if(type===1)return Number(required(p,'hasFeat')(o,id&65535)!==0&&(required(p,'remainingFeatUses')(o,id&65535)&255)!==0);
    if(type===2){const n=count(rules.skills);if(await rank(p,o,id&255)>0)return 1;
      if((id&65535)>=n)throw new Error('Native talent untrained skill metadata reads outside allocated storage');return Number(untrained(rules,id&65535)!==0);}
    if(type!==0)return 0;
  }else if(type!==0)return 0;
  return integer(await required(p,'hasSpellTalent')(o,id,metamagic,enabled(o)),'spell eligibility');
}

// Physical duplicates remain candidates. For feat/skill/item selectors the
// best argument only distinguishes -1 from other INTs; it is NOT a CR cap.
export class TalentCandidates {
  constructor(maxCR){this.maxCR=integer(maxCR,'maximum CR');this.rank=-100;this.values=[];}
  add(value,rank){
    rank=integer(rank,'candidate CR');
    if(this.maxCR!==-1){if(rank<this.rank)return;if(rank>this.rank){this.values=[];this.rank=rank;}}
    this.values.push(value);
  }
  pick(p){
    if(!this.values.length)return null;
    const random=integer(required(p,'random')(),'random draw');
    if(random<0||random>32767)throw new Error('Native talent CRT random draw is unsupported');
    return this.values[random%this.values.length];
  }
}

// GetCreatureTalentRandomFeat1403fb150: WORD owned IDs, INT list length.
export function featTalent(o,category,maxCR,rules,p){
  category=integer(category,'category');const pool=new TalentCandidates(maxCR),owned=creatureRoot(o)?.FeatList;
  if(!Array.isArray(owned))throw new Error('Native talent feat ownership is unavailable');
  if(owned.length>65535)throw new Error('Native talent feat scan would wrap its WORD cursor');
  for(const entry of owned){
    const id=integer(entry.Feat,'owned feat ID')&65535;
    if(!featInfo(rules,id)||intEntry(rules.feat,id,'Category').value!==category||!enabled(o))continue;
    if(required(p,'hasFeat')(o,id)===0||(required(p,'remainingFeatUses')(o,id)&255)===0)continue;
    pool.add({...selectionTalent(),type:1,id},intEntry(rules.feat,id,'MaxCR').value);
  }
  return pool.pick(p);
}

// GetCreatureTalentRandomSkill1403fc050 invokes the effective rank provider
// twice on matching rows. Class skill usability is deliberately not a gate.
export async function skillTalent(o,category,maxCR,rules,p){
  category=integer(category,'category');const pool=new TalentCandidates(maxCR);
  for(let id=0;id<(count(rules.skills)&255);id++){
    if(await rank(p,o,id)<=0&&untrained(rules,id)===0)continue;
    if(intEntry(rules.skills,id,'Category').value!==category||!enabled(o))continue;
    if(await rank(p,o,id)<=0&&untrained(rules,id)===0)continue;
    pool.add({...selectionTalent(),type:2,id},intEntry(rules.skills,id,'MaxCR').value);
  }
  return pool.pick(p);
}

// StatsGetCreatureTalentRandom1403fae70. Failed/repeated branch choices
// consume CRT draws. Spell-like abilities precede physical class entries;
// the item spell selector is the last spell fallback or a direct category.
export async function creatureTalent(o,category,maxCR,rules,p){
  if(o?.objectType!==5)return scriptTalent();const invalid=selectionTalent();
  category=integer(category,'category');maxCR=integer(maxCR,'maximum CR');
  if(category>16&&category<22&&category!==19)return await required(p,'itemSpellTalent')(o,category,maxCR)??invalid;
  const done=[false,false,false];
  while(!done.every(Boolean)){
    const draw=integer(required(p,'random')(),'random draw');
    if(draw<0||draw>32767)throw new Error('Native talent CRT random draw is unsupported');
    const branch=draw%3;if(done[branch])continue;
    let result;
    if(branch===1)result=featTalent(o,category,maxCR,rules,p);
    else if(branch===2)result=await skillTalent(o,category,maxCR,rules,p);
    else{
      result=await required(p,'spellLikeTalent')(o,category,maxCR);
      const classes=creatureRoot(o)?.ClassList;if(!Array.isArray(classes))throw new Error('Native talent class list is unavailable');
      for(let index=0;!result&&index<(classes.length&255);index++){
        const classId=integer(classes[index].Class,'class ID')&255;
        count(rules.classes);
        const method=intEntry(rules.classes,classId,'MemorizesSpells').value===0?'knownSpellTalent':'memorizedSpellTalent';
        result=await required(p,method)(o,category,maxCR,index);
      }
      if(!result)result=await required(p,'itemSpellTalent')(o,category,maxCR);
    }
    if(result)return result;
    done[branch]=true;
  }
  return invalid;
}
