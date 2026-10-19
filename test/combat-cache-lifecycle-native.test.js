import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCombatInformation,copyCombatInformation,assignCombatInformation,disposeCombatInformation,combatInformationEqual,combatInformationDifferent} from '../src/combat_information.js';
import {PolymorphRuntime} from '../src/polymorph_runtime.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-combat-cache-lifecycle-observations.json',import.meta.url)));
const rows=mode=>capture.rows.filter(r=>r.case.mode===mode);
function cache(c,shared){const v=createCombatInformation();v.scalars.set(c.scalars);v.initialized.fill(1);v.weaponIds=[...c.weaponIds];v.text=[...c.text];v.flags=c.flags;for(const kind of ['attack','damage']){v[kind+'Nodes']=c[kind+'Nodes'].map((n,i)=>n===null?null:shared?shared[kind+'Nodes'][i]:Uint8Array.from(n));v[kind+'Capacity']=c[kind+'Capacity'];}return v;}
const state=o=>({scalars:[...o.scalars],weaponIds:[...o.weaponIds],text:[...o.text],flags:o.flags,attackNodes:o.attackNodes.map(n=>n===null?null:[...n]),damageNodes:o.damageNodes.map(n=>n===null?null:[...n]),attackCapacity:o.attackCapacity,damageCapacity:o.damageCapacity});
function compare(actual,expected,label){const projected=state(actual);for(const[key,value]of Object.entries(projected))if(key==='scalars'){for(let i=0;i<32;i++)if(actual.initialized[i])assert.equal(value[i],expected.scalars[i],`${label} scalar ${i}`);}else assert.deepEqual(value,expected[key],`${label} ${key}`);}

test('combat-information copy constructor matches original selected fields/strings/flags and intentionally empty node arrays',()=>{
 assert.equal(rows('copy').length,12);
 for(const row of rows('copy')){
  const source=cache(row.case.source),before=state(source),result=copyCombatInformation(source);compare(result,row.target,'copy');assert.deepEqual(state(source),before);assert.deepEqual(source.scalars.slice(16,19),Uint8Array.from(row.case.source.scalars.slice(16,19)));assert.deepEqual([...result.initialized.slice(16,19)],[0,0,0]);assert.notEqual(result.scalars,source.scalars);assert.notEqual(result.text,source.text);assert.notEqual(result.weaponIds,source.weaponIds);
 }
});
test('combat-information assignment matches original independent node copies/capacity, retained text/flags and self no-op',()=>{
 for(const row of rows('assign')){
  const source=cache(row.case.source),target=row.case.self?source:cache(row.case.target),oldNodes=[...target.attackNodes,...target.damageNodes],oldScalars=target.scalars,oldText=target.text,oldList=target.attackNodes;
  assert.equal(assignCombatInformation(target,source),target);compare(target,row.target,'assignment');assert.equal(target.scalars,oldScalars);assert.equal(target.text,oldText);
  if(row.case.self){assert.equal(target.attackNodes,oldList);continue;}
  for(const kind of ['attack','damage'])for(let i=0;i<source[kind+'Nodes'].length;i++){assert.notEqual(target[kind+'Nodes'][i],source[kind+'Nodes'][i]);assert.deepEqual(target[kind+'Nodes'][i],source[kind+'Nodes'][i]);}
  assert.ok(oldNodes.every(n=>n===null||!n.disposed),'native assignment frees old pointer arrays without destroying old nodes');compare(source,row.source,'unmodified source');
 }
});
test('native combat equality uses node identity while inequality uses node values; neither compares text or flags',()=>{
 for(const row of [...rows('equal'),...rows('different')]){
  const c=row.case,source=cache(c.source),target=cache(c.target,c.shareNodes?source:null),result=c.mode==='equal'?combatInformationEqual(target,source):combatInformationDifferent(target,source);assert.equal(result,row.value,JSON.stringify(c));
 }
 const a=createCombatInformation(),b=createCombatInformation();a.attackNodes.push(Uint8Array.of(1,2,3,4,5,6));b.attackNodes.push(Uint8Array.of(1,2,3,4,5,6));assert.equal(combatInformationEqual(a,b),0);assert.equal(combatInformationDifferent(a,b),0);
});
test('combat-information destruction matches original forward node disposal, empty storage and retained scalars',()=>{
 for(const row of rows('dispose')){
  const target=cache(row.case.target),released=[];
  for(const kind of ['attack','damage'])target[kind+'Nodes'].forEach((node,index)=>{if(node)Object.defineProperty(node,'disposed',{set:value=>{assert.equal(value,true);released.push('target'+kind+index);}});});
  disposeCombatInformation(target);compare(target,row.target,'destruction');assert.equal(target.disposed,true);assert.deepEqual(released,row.calls.filter(c=>c[0]==='free'&&/^target(attack|damage)\d+$/.test(c[1])).map(c=>c[1]));
 }
});
test('actual polymorph snapshot provider matches original old-snapshot destruction and copy-construction block',()=>{
 for(const row of rows('snapshot')){
  const source=cache(row.case.source),previous=row.case.oldSnapshot?cache(row.case.target):null,sourceBefore=state(source),actor={nativeCombatInformationD70:source,nativeCombatInformationA48:previous};
  const runtime=new PolymorphRuntime({effects:{abilityProviders:()=>({})},combat:{jumpProviders:()=>({})}}),result=runtime.providers().copyCombatInformation(actor);
  compare(result,row.target,'saved snapshot');if(previous)assert.equal(previous.disposed,true);assert.deepEqual(state(source),sourceBefore);assert.notEqual(result,source);assert.equal(source.disposed,undefined);assert.equal(result.representation,undefined);
 }
});
