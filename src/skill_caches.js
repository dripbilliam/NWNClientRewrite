import { intEntry } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';

const signedByte=value=>(value<<24)>>24;
const physicalRow=(table,index)=>table?.orderedRows?table.orderedRows[index]:table?.rows.get(index);
function cell(table,index,name){
  if(!table)throw new Error(`Native skill cache table for ${name} is unavailable`);
  const row=physicalRow(table,index),key=Object.keys(row??{}).find(k=>k.toLowerCase()===name.toLowerCase());
  return key===undefined?undefined:row[key];
}

// ComputeArmourClass 140388220..1403889b0. Initialize an imported creature's
// +dd0/+dd1 caches by applying its current chest/shield once, after the stats
// constructor's zero write. This is NOT a replacement for equip/unequip side
// effects. In particular the native chest operation ADDS, not assigns ACCHECK.
export function initializeSkillArmorPenalties(object,items,rules){
  if(object.skillArmorPenalties!==undefined)return object.skillArmorPenalties;
  let chestPenalty=0,shieldPenalty=0;
  const chest=items.find(i=>i.slot===2),shield=items.find(i=>i.slot===32);
  if(chest){
    if(!rules.armor)throw new Error('Native armor skill cache rules are unavailable');
    const value=cell(rules.parts_chest,(chest.data.ArmorPart_Torso??0)&65535,'ACBonus');
    const parsed=value===undefined||value==='****'?0:parseFloat(value);
    const ac=Number.isFinite(parsed)?Math.trunc(Math.fround(parsed)):0;
    chestPenalty=signedByte(intEntry(rules.armor,ac,'ACCHECK').value);
  }
  if(shield&&[14,56,57].includes(shield.data.BaseItem)){
    if(!rules.baseitems)throw new Error('Native shield skill cache rules are unavailable');
    shieldPenalty=signedByte(intEntry(rules.baseitems,shield.data.BaseItem,'ArmorCheckPen').value);
  }
  object.skillArmorPenalties=[chestPenalty,shieldPenalty];return object.skillArmorPenalties;
}

// ReadStatsFromGff 140410af6 initializes +25e to zero after every loaded
// class level. Keep the byte on each mutable class record so slot changes and
// XP cloning retain its identity. Negative-level mutation remains unimplemented.
export function initializeClassSkillPenalties(object){
  const classes=creatureRoot(object).ClassList;
  if(!Array.isArray(classes))throw new Error('Native skill class records are unavailable');
  for(const c of classes)if(c.skillPenaltyByte===undefined)c.skillPenaltyByte=0;
}

// IsSkillUseable 14029a300: AllClassesCanUse bypasses the loaded class list;
// otherwise ANY SkillIndex match admits use, regardless of ClassSkill value.
// LoadSkillsTable 14029b430 stores physical rows as ushort/int pairs.
export function classSkillUsable(rules,classId,skill,warning=()=>{}){
  if(!rules.skills)throw new Error('Native class skill rules are unavailable');
  skill&=65535;
  if(skill>=((rules.skills.orderedRows?.length??rules.skills.rows.size)&255)){
    warning('Native warning: CNWClass:SkillUseable() Invalid skill id.');return 0;
  }
  if(intEntry(rules.skills,skill,'AllClassesCanUse').value!==0)return 1;
  const name=cell(rules.classes,classId&255,'SkillsTable');
  if(typeof name!=='string'||!name||name==='****')return 0;
  const table=rules.classTables?.get(name.toLowerCase());
  if(!table)throw new Error(`Native class skill table ${name} is unavailable`);
  const count=(table.orderedRows?.length??table.rows.size)&65535;
  for(let i=0;i<count;i++){
    const entry=intEntry(table,i,'SkillIndex');
    // GetINTEntry writes zero for empty cells and atoi(DEFAULT) for missing
    // rows/columns even when it returns false; LoadSkillsTable ignores that
    // return and always stores the output ushort at 14029b719..14029b71d.
    if((entry.value&65535)===skill)return 1;
  }
  return 0;
}
