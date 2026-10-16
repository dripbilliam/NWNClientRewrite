// Two local canonical creatures imported from an installed BIC. Resources,
// rules, skills, RNG and actions remain live; AI/startup are isolated.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseCharacter} from '../src/character.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',rows=[];
for(const {visible,fake=false} of [{visible:true},{visible:false},{visible:true,fake:true}]){
 const bytes=await fs.readFile(`${root}/data/lcv/wizard.bic`),messages=[],s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
  runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize(['m0q1a'],{character:bytes});
 await s.enterArea('m0q1a',[24,0,-14]);
 const area=s.currentArea,counter=s.player,caster=s.register('creature','counterspell-probe:caster',{
  authored:parseCharacter(bytes),areaId:area.id,position:[26,0,-14],tag:'counterspell_probe',name:'Counterspell probe',isPC:false});
 await s.loadInventory(caster,caster.authored);await s.loadCreatureStats(caster);area.objects.push(caster.id);area.nativeSpatial.insert(caster.id);
 await s.combat.updatePerception(counter,caster,visible?1:0);await s.combat.updatePerception(caster,counter,1);
 if(!visible)counter.perception.set(caster.id,0);
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();s.random.seed(1);
 const spellId=100,uses=o=>s.spellBook.uses(o,spellId,0,0,0),before={caster:uses(caster),counter:uses(counter)},impacts=[],animations={caster:new Set(),counter:new Set()},start=runtimeDiagnostics.records.length;
 const run=s.runScript.bind(s);s.runScript=(name,id,options)=>{if(name.toLowerCase()===s.spellBook.castingSpell(spellId).impactScript.toLowerCase())impacts.push({name,id});return run(name,id,options);};
 const tick=async()=>{s.scheduler.advance(100);s.worldTimer.snapshot();for(const o of [counter,caster]){await s.combat.updateTimer(o,100);await s.combat.runActions(o,...Object.values(s.worldTimer.time()));}await s.scheduler.pump();for(const [key,o]of [['counter',counter],['caster',caster]])animations[key].add(o.animationState);};
 const order=s.queuePlayerMode(5,caster.id);await s.drainPlayerInputs();await order;await tick();assert.equal(counter.combatMode,4);assert.equal(counter.counterSpellTargetId,caster.id);
 if(fake)await s.commands.ActionCastFakeSpellAtObject([spellId,caster.id,0],{self:caster.id});
 else await s.commands.ActionCastSpellAtObject([spellId,caster.id,0,0,0,0,0,-1,0],{self:caster.id});
 for(let n=0;n<200;n++){await tick();if(!caster.objectActionState.list.count&&!caster.combatRound.started)break;}
 const after={caster:uses(caster),counter:uses(counter)},errors=runtimeDiagnostics.records.slice(start).filter(d=>d.severity==='error');
 assert.deepEqual(errors,[]);assert.equal(after.caster,before.caster-Number(!fake));assert.equal(after.counter,before.counter-Number(visible&&!fake));assert.equal(impacts.length,Number(!visible&&!fake));
 assert.equal(caster.objectActionState.list.count,0);assert.equal(caster.nativeCounterCount338,0);assert.ok(caster.nativeCounterspellers310.every(id=>id===OBJECT_INVALID));assert.equal(counter.combatMode,4);
 if(visible&&!fake){assert.ok(messages.some(m=>m.type===12));assert.ok([...animations.counter].some(id=>[15,16].includes(id)));assert.ok([...animations.counter].some(id=>[17,18,19,20,61].includes(id)));}
 if(fake){assert.ok(!messages.some(m=>[8,12].includes(m.type)));assert.ok(![...animations.counter].some(id=>[15,16,17,18,19,20,61].includes(id)));}
 await s.combat.clearActions(counter);assert.equal(counter.combatMode,0);assert.equal(counter.objectActionState.list.count,0);assert.equal(counter.lockOrientationId,OBJECT_INVALID);
 // The script binding must queue the same action and permit ordinary cleanup.
 await s.commands.ActionCounterSpell([caster.id],{self:counter.id});assert.ok([...counter.objectActionState.list].some(a=>a.actionId===50));await tick();assert.equal(counter.combatMode,4);await s.combat.clearActions(counter);assert.equal(counter.combatMode,0);
 rows.push({visible,fake,actorIds:{caster:caster.id,counter:counter.id},spellId,before,after,impacts,animations:Object.fromEntries(Object.entries(animations).map(([k,v])=>[k,[...v]])),messages,diagnostics:runtimeDiagnostics.records.slice(start)});
}
const report={rows,limits:'Actual installed BIC spell pools/skills and impact script; canonical test clone, local input, action/timer/round/effect owners. Visibility controlled. Startup/general AI disabled. Native owner parity is separately tested; this is not original-process multiplayer or rendered encounter acceptance.'};
await fs.writeFile('backups/animations/live-counterspell.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
