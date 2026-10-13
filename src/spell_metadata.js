import { intEntry } from './combat_stats.js';

// CNWSpellArray::GetSpell 1402af4a0 uses signed IDs and physical row count.
// Load 1402af8d0 writes UserType to +184 and maps the first School byte via
// 1402b2c1c (A,C,D,E,V,I,N,T). This subset serves contextual saving throws.
export function savingThrowSpell(rules,id){
  if(!Number.isInteger(id))throw new Error('Native spell ID is unavailable');
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
