import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveCreatureStats} from '../src/creature_stats_save.js';
import {saveCombatInformation} from '../src/combat_information_save.js';
import {gffField,gffRecord,writeGff} from '../src/gff_writer.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';

const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-stats-save-observations.json',import.meta.url)));
const cache=value=>({...structuredClone(value),scalars:Uint8Array.from(value.scalars),initialized:Uint8Array.from(value.initialized),attackNodes:value.attackNodes.map(n=>Uint8Array.from(n)),damageNodes:value.damageNodes.map(n=>Uint8Array.from(n))});
function fixture(c){
 const live=cache(c.cache),saved=cache(c.savedCache),calls=[];
 const lower=(name,...args)=>{calls.push([name,...args]);return c.lower[name];};
 return{live,saved,calls,p:{stats:n=>c.stats[n],creature:n=>c.creature[n],saved:n=>c.saved[n],locked:()=>c.locked,
  baseAttack:n=>lower('baseAttack',n),save:(name,n)=>lower(name,n),armor:()=>lower('armor'),isDM:()=>lower('isDM'),
  maximumHP:n=>lower('maximumHP',n),currentHP:n=>lower('currentHP',n),portraitId:()=>lower('portraitId'),portrait:()=>{calls.push(['portrait']);return c.portrait;},
  classInfo:root=>{calls.push(['classInfo']);root.fields.ClassSaveMarker=gffField(5,42);},combatInformation:locked=>locked?saved:live,
  item:id=>{id>>>=0;calls.push(['item',id]);const i=c.items[id];return i?{...i,id}:null;},
  itemName:(item,old,l,g,t)=>{calls.push(['name',String(item.id),old,l,g,t]);return item.name??old;},
  baseItem:item=>{calls.push(['base',item.base]);return c.bases[item.base];},baseItemById:id=>{calls.push(['base',id]);return c.bases[id];},
  equipped:slot=>{calls.push(['equipped',slot]);const id=c.equipment[slot];return c.items[id]?{...c.items[id],id}:null;},
 }};
}
test('SaveStats and CombatInformation::SaveData match complete original owners and lower call order',async()=>{
 assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls:expected,cache:liveExpected,savedCache:savedExpected}of observations.cases){
  const {live,saved,calls,p}=fixture(c),root=c.combatOnly?saveCombatInformation(live,gffRecord({})):await saveCreatureStats(p);
  assert.deepEqual(root,output,c.name);assert.deepEqual(calls,expected,c.name);
  assert.deepEqual({text:live.text,flags:live.flags},liveExpected,c.name);assert.deepEqual({text:saved.text,flags:saved.flags},savedExpected,c.name);
 }
});
test('native extended fields preserve large values and reset the legacy byte to zero',async()=>{
 const c=observations.cases.find(x=>x.case.name==='extended-65535').case,{p}=fixture(c),root=parseGff(writeGff('UTC ',await saveCreatureStats(p)),'UTC ').root;
 assert.equal(root.StartingPackage,0);assert.equal(root.xStartingPackage,65535);assert.equal(getGffFieldTypes(root).xStartingPackage,4);
 assert.equal(root.Appearance_Head,0);assert.equal(root.xAppearance_Head,65535);assert.equal(getGffFieldTypes(root).xAppearance_Head,2);
 assert.equal(root.ArmorPart_RFoot,0);assert.equal(root.xArmorPart_RFoot,65535);assert.ok(!('BodyPart_RFoot'in root));
 assert.equal(getGffStructType(root.CombatInfo),0xcaaa);assert.equal(getGffStructType(root.CombatInfo.AttackList[0]),0xaaee);
 assert.equal(getGffStructType(root.CombatInfo.DamageList[0]),0xddee);assert.equal(root.CombatInfo.AttackList[0].Modifier,-1);
});
test('locked save retains original form and caps PregameCurrent with saved maximum HP',async()=>{
 const c=observations.cases.find(x=>x.case.name==='hp-plot-1-1-0-32767').case,{p}=fixture(c),root=await saveCreatureStats(p);
 assert.equal(root.fields.MaxHitPoints.value,c.saved.MaxHitPoints);assert.equal(root.fields.PregameCurrent.value,c.saved.MaxHitPoints);
 assert.equal(root.fields.Race.value,c.saved.Race);assert.equal(root.fields.Str.value,c.saved.Str);assert.equal(root.fields.Plot.value,0);
});
test('uninitialized combat bytes and missing live stat fields cannot produce a successful save',async()=>{
 const c=observations.cases[0].case,{p,live}=fixture(c);live.initialized[5]=0;
 await assert.rejects(saveCreatureStats(p),/scalar 5 is uninitialized/);
 const f=fixture(c);f.p.stats=n=>n==='Str'?undefined:c.stats[n];await assert.rejects(saveCreatureStats(f.p),/Str is unavailable/);
});
