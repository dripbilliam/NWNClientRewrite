import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {spellsOfLevelReady} from '../src/spell_conversion.js';
const install=process.argv.slice(2).find(a=>!a.startsWith('--'))??'../FullDecomp/NwnRootInstall';
const enemy=process.argv.includes('--enemy'),itemTarget=process.argv.includes('--item'),converted=process.argv.includes('--convert'),character=process.argv.find(a=>a.startsWith('--character='))?.slice(12)??'wizard',wanted=process.argv.find(a=>a.startsWith('--spell='))?.slice(8),suffix=itemTarget?`item-${wanted??'default'}`:converted?`conversion-${character}-${wanted??'default'}`:enemy?`enemy-${wanted??'default'}`:'installed';
const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/${character}.bic`)});
await s.enterArea('m0q1a',[20,0,-20]);s.scheduler.events=[];
const o=s.player,choices=[];
for(let index=0;index<o.nativeTalentClasses.length;index++)for(let level=0;level<10;level++)for(const entry of o.nativeTalentClasses[index].memorized[level]){
 if(!entry?.ready)continue;
 const spell=s.spellBook.castingSpell(entry.id),domain=entry.domain?(level-s.spellBook.metamagicCost(entry.metamagic))&255:0;
 if(spell&&s.spellBook.uses(o,entry.id,index,domain,entry.metamagic))choices.push({spell,index,domain,meta:entry.metamagic});
}
if(converted){choices.length=0;for(let index=0;index<o.nativeTalentClasses.length;index++)for(let id=0;id<s.characterRules.spells.orderedRows.length;id++){
 const spell=s.spellBook.castingSpell(id),level=s.spellBook.level(id,(o.creatureData??o.authored).ClassList[index].Class);
 if(spell.spontaneouslyCast!==0&&level<10&&spellsOfLevelReady(o,index,level)!==0&&s.spellBook.uses(o,id,index,0,0)===0)choices.push({spell,index,domain:0,meta:0,spontaneous:1,level});
}}
console.log('Available casts:',JSON.stringify(choices));assert.ok(choices.length);
const chosen=wanted?choices.find(c=>c.spell.id===Number(wanted)):choices.find(c=>(c.spell.targetType&1)&&c.spell.hasProjectile===0);assert.ok(chosen);
let target=o;
if(enemy){target=[...s.registry.objects.values()].find(v=>v.objectType===5&&/goblin/i.test(v.tag));assert.ok(target);const area=s.registry.get(target.areaId);await s.enterArea(area.resRef,[target.position[0]+2,target.position[1],target.position[2]]);await s.combat.updatePerception(o,target,1);}
if(itemTarget){target=o.inventory.map(id=>s.registry.get(id)).find(v=>v?.baseItem===22&&v.possessorId===o.id);assert.ok(target);}
s.scheduler.events=[];
const uses=()=>converted?spellsOfLevelReady(o,chosen.index,chosen.level):s.spellBook.uses(o,chosen.spell.id,chosen.index,chosen.domain,chosen.meta);
const targetHP=target.stats?.currentHP,before=uses(),start=runtimeDiagnostics.records.length,slotsBefore=structuredClone(o.nativeTalentClasses[chosen.index].memorized);
const input=s.queuePlayerCastSpell({actorId:o.id,areaId:o.areaId,spellId:chosen.spell.id,classIndex:chosen.index,metamagic:chosen.meta,domainLevel:chosen.domain,targetId:target.id,spontaneous:chosen.spontaneous??0});
await s.drainPlayerInputs();assert.equal(await input,1);
const animations=[],impacts=[],errors=[],run=s.runScript.bind(s);
s.runScript=async(name,id,options)=>{if(name===chosen.spell.impactScript)impacts.push({name,id,at:s.scheduler.time});return run(name,id,options);};
for(let n=0;n<150;n++){
 s.scheduler.advance(100);s.worldTimer.snapshot();
 try{await s.combat.runActions(o,...Object.values(s.worldTimer.time()));}catch(error){errors.push(error.message);break;}
 animations.push(o.animationState);
 while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(error){errors.push(error.message);}}
 if(o.objectActionState.list.count===0&&impacts.length)break;
}
const after=uses(),report={chosen,before,after,slotsBefore,slotsAfter:o.nativeTalentClasses[chosen.index].memorized,spontaneousContext:o.nativeSpellSpontaneous228,animations:[...new Set(animations)],impacts,errors,queue:[...o.objectActionState.list].map(n=>n.actionId),
 target:{id:target.id,hpBefore:targetHP,hpAfter:target.stats?.currentHP,possessorId:target.possessorId,effects:structuredClone(target.effects)},effects:o.effects.map(e=>({type:e.type,spellId:e.spellId})),diagnostics:runtimeDiagnostics.records.slice(start).map(r=>({code:r.code,severity:r.severity,message:r.message}))};
await fs.writeFile(`backups/animations/live-casting-${suffix}.json`,JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert.deepEqual(errors,[]);assert.equal(after,before-1);assert.equal(impacts.length,1);assert.equal(o.objectActionState.list.count,0);assert.ok(animations.some(id=>[15,16].includes(id)));assert.ok(animations.some(id=>[17,18,19,20,61,89,96].includes(id)));
if(enemy)assert.ok(target.stats.currentHP<targetHP,'Authored damage spell must actually damage its canonical target');
if(itemTarget){assert.ok(target.effects.some(e=>e.type===91&&e.spellId===chosen.spell.id),'Normal prepared cast must apply its authored item property');assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);}
