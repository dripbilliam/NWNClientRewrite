import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall';
const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[20,0,-20]);s.scheduler.events=[];
const o=s.player,choices=[];
for(let index=0;index<o.nativeTalentClasses.length;index++)for(let level=0;level<10;level++)for(const entry of o.nativeTalentClasses[index].memorized[level]){
 if(!entry?.ready)continue;
 const spell=s.spellBook.castingSpell(entry.id),domain=entry.domain?(level-s.spellBook.metamagicCost(entry.metamagic))&255:0;
 if(spell&&(spell.targetType&1)&&s.spellBook.uses(o,entry.id,index,domain,entry.metamagic))choices.push({spell,index,domain,meta:entry.metamagic});
}
console.log('Available self-target casts:',JSON.stringify(choices));assert.ok(choices.length);
const chosen=choices.find(c=>c.spell.hasProjectile===0)??choices[0],before=s.spellBook.uses(o,chosen.spell.id,chosen.index,chosen.domain,chosen.meta),start=runtimeDiagnostics.records.length;
const input=s.queuePlayerCastSpell({actorId:o.id,areaId:o.areaId,spellId:chosen.spell.id,classIndex:chosen.index,metamagic:chosen.meta,domainLevel:chosen.domain,targetId:o.id});
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
const after=s.spellBook.uses(o,chosen.spell.id,chosen.index,chosen.domain,chosen.meta),report={chosen,before,after,animations:[...new Set(animations)],impacts,errors,queue:[...o.objectActionState.list].map(n=>n.actionId),
 effects:o.effects.map(e=>({type:e.type,spellId:e.spellId})),diagnostics:runtimeDiagnostics.records.slice(start).map(r=>({code:r.code,message:r.message}))};
await fs.writeFile('backups/animations/live-casting-installed.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert.deepEqual(errors,[]);assert.equal(after,before-1);assert.equal(impacts.length,1);assert.equal(o.objectActionState.list.count,0);assert.ok(animations.some(id=>[15,16].includes(id)));assert.ok(animations.some(id=>[17,18,19,20,61,89,96].includes(id)));
