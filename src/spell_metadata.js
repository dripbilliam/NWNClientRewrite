import { intEntry } from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';

// CNWSpellArray::GetSpell 1402af4a0 uses signed IDs and physical row count.
// Load 1402af8d0 writes UserType to +184 and maps the first School byte via
// 1402b2c1c (A,C,D,E,V,I,N,T). This subset serves contextual saving throws.
export function savingThrowSpell(rules,id){
  if(!Number.isInteger(id))throw new Error('Native spell ID is unavailable');
  id|=0;if(id<0)return null;
  const table=rules.spells;
  if(!table)throw new Error('Native spell rules are unavailable');
  const rows=table.orderedRows??[...table.rows.values()];id|=0;
  if(id<0||id>=rows.length)return null;
  const row=rows[id],schoolKey=Object.keys(row).find(k=>k.toLowerCase()==='school');
  const school=({A:1,C:2,D:3,E:4,V:5,I:6,N:7,T:8})[String(row[schoolKey]??'')[0]];
  const classification=intEntry(table,id,'UserType').value&255;
  return{classification,get school(){
    // The constructor leaves +29 uninitialized; an unknown letter does not
    // write it. Never pretend this native indeterminate value is school zero.
    if(school===undefined)throw new Error(`Native spell ${id} school reads uninitialized loader storage`);
    return school;
  }};
}

// CNWSpellArray::Load1402afb18..1402afbcb stores Category and derives
// ranking CR from the full INT Innate; +6f is loaded separately as BYTE.
// SubRadSpell1..8 are compacted by successful reads, including negative IDs.
export function talentSpell(rules,id){
  if(!Number.isInteger(id))throw new Error('Native spell ID is unavailable');
  id|=0;if(id<0)return null;
  const table=rules.spells;if(!table)throw new Error('Native spell rules are unavailable');
  const rows=table.orderedRows??[...table.rows.values()];id|=0;
  if(id<0||id>=rows.length)return null;
  const innate=intEntry(table,id,'Innate'),master=intEntry(table,id,'Master'),children=[];
  for(let i=1;i<=8;i++){const entry=intEntry(table,id,`SubRadSpell${i}`);if(entry.found)children.push(entry.value);}
  return {id,category:intEntry(table,id,'Category').value,maxCR:(Math.imul(innate.value,2)-1)|0,
    innate:innate.found?innate.value&255:255,master:master.found?master.value:id,children};
}

// C2DA GetSTRINGEntry1401a68f0: first physical matching column; empty
// cells clear output, unavailable row/column copies the table default.
export function nativeStringEntry(table,id,column){
  const rows=table.orderedRows??[...table.rows.values()],index=table.columns.findIndex(k=>k.toLowerCase()===column.toLowerCase());
  const valid=index>=0&&id>=0&&!!rows[id],cell=!valid?table.defaultValue:table.orderedCells?table.orderedCells[id][index]:rows[id][table.columns[index]];
  const value=cell===undefined||cell===''||cell==='****'?'':String(cell);return{found:valid&&value!=='',value};
}
export const spellStringEntry=(table,id,column)=>nativeStringEntry(table,id,column).value;
const lower=v=>v.replace(/[A-Z]/g,c=>c.toLowerCase()).split('\0')[0];
const enumValue=(map,text)=>Object.hasOwn(map,lower(text))?map[lower(text)]:0;
// CNWSpellArray::Load1402b0862..08f3 /0fce..11ab /1cb4..1eba.
// Point/touch map to6, attack7: native loops retain their NUL-inclusive
// character count. They must not be numbered by a guessed enum sequence.
export const conjureAnimationType=text=>enumValue({hand:1,head:2},text);
export const castAnimationType=text=>enumValue({out:1,self:2,up:3,area:4,point:6,touch:6,attack:7,creature:8},text);
export const projectilePathType=text=>enumValue({homing:1,ballistic:2,highballistic:3,accelerating:5,spiral:6,linked:7,bounce:8,burst:9,test:50},text);

// Active physical spell row, using the native loader's widths and strings.
// This subset is casting metadata, not a hardcoded spell effect database.
export function castingSpell(rules,id){
  if(!Number.isInteger(id))throw new Error('Native casting spell ID is unavailable');
  id|=0;if(id<0)return null;
  const table=rules.spells;if(!table)throw new Error('Native casting spell table is unavailable');
  const rows=table.orderedRows??[...table.rows.values()];id|=0;if(id<0||id>=rows.length)return null;
  const string=key=>spellStringEntry(table,id,key),number=key=>intEntry(table,id,key).value;
  const master=intEntry(table,id,'Master'),innate=intEntry(table,id,'Innate'),counter1=intEntry(table,id,'Counter1'),counter2=intEntry(table,id,'Counter2');
  return{id,components:string('VS'),range:string('Range').slice(0,1),impactScript:string('ImpactScript'),
    targetShape:({sphere:1,rectangle:2,cone:3,hsphere:4})[string('TargetShape').toLowerCase()]??0,targetSizeX:nativeFloatEntry(table,id,'TargetSizeX').value,targetSizeY:nativeFloatEntry(table,id,'TargetSizeY').value,targetFlags:number('TargetFlags'),
    master:master.found?master.value:id,innate:innate.found?innate.value&255:255,metamagic:number('MetaMagic')&255,
    counter1:counter1.found?counter1.value:-1,counter2:counter2.found?counter2.value:-1,
    targetType:number('TargetType')&65535,conjureTime:number('ConjTime')>>>0,conjureAnimation:conjureAnimationType(string('ConjAnim')),
    castTime:number('CastTime')>>>0,castAnimation:castAnimationType(string('CastAnim')),useProjectile:number('Proj')|0,
    projectilePath:projectilePathType(string('ProjType')),userType:number('UserType')&255,spontaneouslyCast:number('SpontaneouslyCast')|0,
    useConcentration:number('UseConcentration')|0,hasProjectile:number('HasProjectile')|0};
}
