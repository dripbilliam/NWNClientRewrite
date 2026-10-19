import {intEntry} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native script check ${n} is unavailable`);return v|0;};
const skillNames=new WeakMap();
// LoadSkillInfo allocates256 CNWSkill records, whose ctor initializes Name=-1,
// then fills only the BYTE physical row count. Unloaded records still exist.
export function skillNameReference(table,index){
 if(!table)throw new Error('Native skill-check name array is unavailable');index=integer(index,'skill name index')&65535;
 if(index>=256)throw new Error(`Native skill-check name index ${index} exceeds allocated array256`);
 if(!skillNames.has(table)){const names=Array(256).fill(-1),count=(table.orderedRows??[...table.rows.values()]).length&255;for(let row=0;row<count;row++)names[row]=intEntry(table,row,'Name').value;skillNames.set(table,names);}
 return skillNames.get(table)[index];
}

// Complete ExecuteCommandGetItemACValue140527d80..140527e47. This is
// cached base AC plus every passive type1 cost-value WORD, not final wearer AC.
export async function scriptItemACValue(p){
 const read=p.pop('object');if(!read.ok)return -639;
 const item=p.item(integer(read.value,'item ID')>>>0);let value=0;
 if(item){value=integer(p.baseArmor(item),'base armor');for(let index=0;index<p.passiveCount(item);index++){
  const property=p.passive(item,index);if(property&&(integer(property.type,'property type')&65535)===1)value=(value+(integer(property.costValue,'property cost value')&65535))|0;
 }}
 return p.push(value)?0:-638;
}

// Complete ExecuteCommandGetIsSkillSuccessful140527910..140527b85.
// Invalid target/skill still compares the default total0 against the supplied
// DC. Valid targets roll1d20 regardless of eligibility, and never take10/20.
export async function scriptSkillSuccessful(p){
 let read=p.pop('object');if(!read.ok)return -639;const id=integer(read.value,'target ID')>>>0;
 read=p.pop('int');if(!read.ok)return -639;const skill=integer(read.value,'skill');
 read=p.pop('int');if(!read.ok)return -639;const dc=integer(read.value,'difficulty');let total=0;
 if(skill<255){
  const lookup=p.lookup(id);if(!Number.isInteger(lookup.status))throw new Error('Native skill-check lookup status is unavailable');
  if((lookup.status&255)===0){const creature=p.asCreature(lookup.object);if(creature){
   const rank=integer(await p.rank(creature,skill&255,null,0),'rank')<<24>>24,roll=integer(p.dice(1,20),'die roll')&65535;total=(rank+roll)|0;
   const data=p.newData(),name=integer(p.skillName(skill&65535),'skill name');
   p.setObject(data,0,creature.id>>>0);for(const[index,value]of[name,roll,rank,dc,0,total>=dc?1:rank+20<dc?3:0].entries())p.setInteger(data,index,value);
   await p.broadcast(creature,data);
  }}
 }
 return p.push(Number(dc<=total))?0:-638;
}
