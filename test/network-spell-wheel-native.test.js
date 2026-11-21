import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clientSpellGainWithBonus,networkSpellGain} from '../src/network_spell_gain.js';
import {NetworkWorld} from '../src/network_world.js';
import {prepareNetworkSpellMenus,replicatedSpellActor} from '../src/network_spell_menu.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
test('1756 complete original client spell-gain cases match signed byte arithmetic, specialization and prestige/rival query levels',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-spell-gain-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,1756);const six=v=>Array.isArray(v)?v:Array(6).fill(v);
 for(const row of f.cases){const c=row.case,queries=[],p={classes:()=>c.classes,classInfo:id=>({...c.defs[id],ability:c.ability}),abilityBonus:n=>six(c.bonus)[n],baseAbility:n=>six(c.base)[n],raceAbility:n=>six(c.race)[n],abilityIncrease:n=>six(c.gain)[n],modifier:n=>six(c.modifier)[n],dexBonus:()=>c.dex,minimum:()=>c.minimum,classGain:(id,level,spellLevel)=>{queries.push({id,level,spellLevel});return c.returnGain;}};assert.equal(clientSpellGainWithBonus(c.index,c.level,p),row.result,JSON.stringify(c));assert.deepEqual(queries,row.queries,JSON.stringify(c));}
});

test('installed campaign rules and real replicated wizard/sorcerer state build native menus without local gameplay',async()=>{
 const install='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,install+'/data/nwm/Prelude.nwm'),objectRules=await loadNetworkObjectRules(resolver),names=['spells','classes','feat','skills','domains','racialtypes','ruleset','metamagic'],rules=Object.fromEntries(await Promise.all(names.map(async name=>[name,parse2da(decodeResourceText(await resolver.getResource(name,2017)))])));
 const walk=menu=>menu.entries.flatMap(e=>e.children?walk(e.children()):[e]);
 for(const [version,expected]of [[51,[2,1,0]],[53,[6,5]]]){const r=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}.json`,import.meta.url))),world=new NetworkWorld(),counts=[];
 for(const hex of r.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...objectRules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);const actor=world.registry.get(world.localObjectId);if(!actor?.playerState?.spellbooks||!actor?.replicated?.stats?.classes)continue;const n=Object.values(actor.playerState.spellbooks[0].memorized).flat().filter(s=>s?.spell===100&&s.ready).length;
  const count=version===51?n:actor.playerState.spellbooks[0].usesLeft[0];if(counts.at(-1)===count)continue;
  // The server sends spell pools and ability cells in separate initial I
  // records. Exercise the populated menu after both arrive, as in the UI run.
  if(version===53&&(!actor.playerState.spellbooks[0].known.includes(100)||!actor.clientAbilityCache?.base))continue;
  const before=structuredClone([...world.registry.objects]),options=await prepareNetworkSpellMenus(actor,actor,rules,resolver,async ({strRef})=>String(strRef),()=>{}),root=options.castMenu(),leaves=walk(root),light=leaves.find(e=>e.binding?.spellId===100&&!e.binding.metamagic);
  assert.ok(root.entries.some(e=>e.slot===5));assert.equal(root.entries.some(e=>e.label==='Metamagic'),[...(actor.playerState.feats??[]),...(actor.playerState.bonusFeats??[])].some(id=>[11,12,25,29,33,37].includes(id)));assert.ok(light);assert.equal(light.uses,count);assert.equal(light.disabled,count===0);assert.ok(options.abilityMenu().entries.length);assert.equal(replicatedSpellActor(actor,rules).id,actor.id);assert.deepEqual([...world.registry.objects],before);counts.push(count);
  if(version===51&&count===2){const projection=structuredClone(actor);projection.playerState.feats=[];projection.playerState.bonusFeats=[];projection.replicated.stats.classes[0].domains=[0];const changed={...rules,domains:parse2da('2DA V2.0\n\nName GrantedFeat\n0 1 11\n')},menu=await prepareNetworkSpellMenus(projection,projection,changed,resolver,async ({strRef})=>String(strRef),()=>{});assert.equal(menu.castMenu().entries.some(e=>e.label==='Metamagic'),false,'domain label prefetch must not invent server-owned feats');}
  if(version===53&&count===6){const projection=structuredClone(actor);projection.replicated.stats.classes[0].level=1;projection.replicated.stats.racialType=6;projection.replicated.stats.fieldD20=6;projection.replicated.stats.race=0;projection.clientAbilityCache={base:Array(6).fill(12),current:Array(6).fill(12),bonuses:Array(6).fill(0),dex:0};assert.ok(networkSpellGain(projection,options.rules,0,1)>0,'the racialtypes WORD, not the legacy BYTE, gates a human caster');projection.replicated.stats.racialType=0;assert.equal(networkSpellGain(projection,options.rules,0,1),0,'active dwarf Charisma adjustment changes the same native level gate');}
 }
 assert.deepEqual(counts,expected);}
});
test('I and character-sheet ability updates share native cells in arrival order; absent I values do not erase them',()=>{
 const w=new NetworkWorld(),id=0xffffffff,A=[8,10,12,14,16,18],B=[9,11,13,15,17,19];w.applyObjectUpdates([{action:'player-state',id,objectType:5,state:{abilities:{base:A,current:B}}}]);const o=w.registry.get(id);assert.deepEqual(o.clientAbilityCache,{base:A,current:B,bonuses:[0,0,0,0,0,0],dex:0});
 w.applyObjectUpdates([{action:'inventory-stats',id,objectType:5,state:{fields70:A,fields76:[...B,-2],fields7d:[1,2,3,4,5,6]}}]);assert.deepEqual(o.clientAbilityCache,{base:B,current:A,bonuses:[1,2,3,4,5,6],dex:-2});w.applyObjectUpdates([{action:'player-state',id,objectType:5,state:{abilities:null}}]);assert.deepEqual(o.clientAbilityCache.current,A);
 w.applyObjectUpdates([{action:'player-state',id,objectType:5,state:{abilities:{base:A,current:B}}}]);assert.deepEqual(o.clientAbilityCache,{base:A,current:B,bonuses:[1,2,3,4,5,6],dex:-2});assert.equal(w.registry.get(id),o);
});

test('real vanilla wheel casts consume prepared slots and spontaneous per-day uses only through server updates',()=>{
 for(const [version,expected,steps]of [[51,[2,1,0],10],[53,[6,5],5]]){
  const r=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}.json`,import.meta.url))),d=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}-diagnostics.json`,import.meta.url)));assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,steps);assert.ok(r.paintFrames>1000);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.states.at(-1).closed,true);assert.deepEqual(d.filter(e=>e.severity==='error'),[]);
  const counts=[];for(const s of r.samples){const book=s.server.spellbooks?.[0];if(!book)continue;const n=version===51?Object.values(book.memorized).flat().filter(v=>v?.spell===100&&v.ready).length:book.usesLeft[0];if(counts.at(-1)!==n)counts.push(n);}assert.deepEqual(counts,expected);
  assert.equal(r.quickbarRequests.filter(e=>e.packet.startsWith('700612')).length,expected.length-1);assert.ok(r.quickbarActions.filter(e=>e.step.mode==='menuChoice').some(e=>e.result.chosen==='Light'));
  const clips=new Set([...r.samples.flatMap(s=>s.scene?.objects.filter(o=>o.id===r.renderer.world.localObjectId).map(o=>o.clip)??[]),...r.renderer.scene.combat.events.map(e=>e.clip)]);for(const name of ['conjure2','castup','castuplp','pause1'])assert.ok(clips.has(name),name);
 }
});
