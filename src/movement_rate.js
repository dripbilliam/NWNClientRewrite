import { rulesetFloat } from './combat_stats.js';

const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native movement-rate ${n} is unavailable`);return v|0;};
const value=(row,column)=>row?.[Object.keys(row).find(k=>k.toLowerCase()===column.toLowerCase())];
const rows=table=>{if(!table)throw new Error('Native movement-rate 2DA is unavailable');return table.orderedRows??[...table.rows.values()];};
const float=value=>{const match=String(value??'').match(/^\s*[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/);return f(match?Number(match[0]):0);};
// C2DA::GetFLOATEntry1401a6c70: missing row/column writes table default,
// an empty cell writes0. All callers here retain output on unsuccessful reads.
export function nativeFloatEntry(table,index,column){
  const list=rows(table),row=list[index];
  if(!row||!table.columns.some(k=>k.toLowerCase()===column.toLowerCase()))return{found:false,value:float(table.defaultValue)};
  const cell=value(row,column);return cell===undefined||cell===''||cell==='****'?{found:false,value:0}:{found:true,value:float(cell)};
}

// SetMovementRate1404160a0..140416410. Category7 resolves appearance
// MOVERATE against CreatureSpeed.2DAName case-insensitively, in physical order.
export function setMovementRate(actor,category,rules){
  category=integer(category,'category');const speed=rules.creaturespeed,list=rows(speed);
  if(category===7){
    const appearances=rows(rules.appearance),root=actor.creatureData??actor.authored;
    const appearance=integer(root?.Appearance_Type,'appearance')&65535;
    const name=value(appearances[appearance],'MOVERATE');category=0;
    if(name!==undefined&&name!==''&&name!=='****'){
      const index=list.findIndex(row=>String(value(row,'2DAName')??'').toLowerCase()===String(name).toLowerCase());
      if(index>=0)category=index;
    }
  }
  actor.nativeMovementRate=category;
  actor.nativeWalkRate=f(nativeFloatEntry(speed,category,'WALKRATE').value);
  actor.nativeRunRate=f(nativeFloatEntry(speed,category,'RUNRATE').value);
  if(category===1)actor.nativeMovementFlags8d4=integer(actor.nativeMovementFlags8d4,'flags +8d4')&0xfffd;
}

// ReadStatsFromGff140412194..1404121ef: BYTE MovementRate takes priority;
// missing field permits the older INT WalkRate after SetMovementRate(default0).
export function loadMovementRate(actor,rules){
  const root=actor.creatureData??actor.authored??{};
  setMovementRate(actor,integer(root.MovementRate??0,'GFF MovementRate')&255,rules);
  if(root.MovementRate===undefined)setMovementRate(actor,integer(root.WalkRate??actor.nativeMovementRate,'GFF WalkRate'),rules);
}

function cap(value,monkLevel,rules,uncapped=0){
  const minimum=()=>rulesetFloat(rules,'MOVEMENT_SPEED_PENALTY_CAP',.125);
  if(value<minimum())return minimum();
  if(uncapped!==0)return value;
  const standard=()=>rulesetFloat(rules,'MOVEMENT_SPEED_BONUS_DEFAULT_CAP',1.5);
  if(value>standard()&&monkLevel===0)return standard();
  const monk=()=>rulesetFloat(rules,'MOVEMENT_SPEED_BONUS_MONK_CAP',3);
  return value>monk()?monk():value;
}
// Constructor14037a775..14037a8ba has a newly empty stats class list.
export const initialMovementFactor=rules=>cap(f(1),0,rules);
const monkLevel=actor=>{
  const list=(actor.creatureData??actor.authored)?.ClassList??[];let level=0;
  for(const entry of list.slice(0,list.length&255))if((integer(entry.Class,'class ID')&255)===5)level=integer(entry.ClassLevel,'class level')&255;
  return level;
};
// GetMovementRateFactor140391fe0..140392214. Monk abilities RESET the
// barbarian-adjusted local to the stored factor before adding monk speed.
export async function movementRateFactor(actor,rules,p){
  let factor=f(actor.nativeMovementFactor8e8);
  if(!Number.isFinite(factor))throw new Error('Native stored movement factor is unavailable');
  if(integer(actor.nativeCollisionFlag788,'collision flag')===1){
    if(!Number.isFinite(actor.nativeMovementFactor78c))throw new Error('Native collision movement factor is unavailable');
    return f(actor.nativeMovementFactor78c);
  }
  if(integer(await p.hasFeat(actor,194),'barbarian feat')!==0)factor=f(factor+rulesetFloat(rules,'BARBARIAN_ENDURANCE_BONUS',.1));
  let level=0;
  if(integer(await p.hasFeat(actor,207),'monk feat')!==0&&integer(await p.monkAbilities(actor),'monk abilities')===1){
    level=monkLevel(actor);factor=f(f(actor.nativeMovementFactor8e8)+f(f(Math.trunc(level/3))*f(.1)));
  }
  return cap(factor,level,rules,integer(actor.nativeHaste308,'haste flag'));
}
// GetWalkRate140396730 / GetRunRate140393080 multiply BASE*1000 first,
// then factor. Pseudocode reassociates these operations incorrectly.
export async function movementRate(actor,running,rules,p){
  if(actor.nativeMovementRate===undefined)loadMovementRate(actor,rules);
  const base=running?actor.nativeRunRate:actor.nativeWalkRate;
  if(!Number.isFinite(base))throw new Error('Native cached movement rate is unavailable');
  return f(await movementRateFactor(actor,rules,p)*f(base*f(1000)));
}
