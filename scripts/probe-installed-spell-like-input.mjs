// Owned in-memory ability fixtures copy existing installed pools. No install
// writes; normal input/queue/conjure/release/script owners remain connected.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-spell-like-input-v1.json',report={rows:[]};
try{
 for(const [wanted,location]of [[36,1],[126,0]]){
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
  const o=s.player,source=[...s.registry.objects.values()].find(a=>a.nativeSpellLikeAbilities?.some(e=>e.id===wanted));assert.ok(source);
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics??=[...runtimeDiagnostics.records];
  const authored=source.nativeSpellLikeAbilities.find(e=>e.id===wanted);o.nativeSpellLikeAbilities=[structuredClone(authored)];const pool=o.nativeSpellLikeAbilities,classes=structuredClone(o.nativeTalentClasses),before=structuredClone(pool),start=runtimeDiagnostics.records.length,spell=s.spellBook.castingSpell(wanted),impacts=[],animations=[],errors=[],run=s.runScript.bind(s);
  s.runScript=async(name,id,options)=>{if(name===spell.impactScript)impacts.push({name,id,at:s.scheduler.time});return run(name,id,options);};
  const input=s.queuePlayerSpellLike({actorId:o.id,areaId:o.areaId,spellId:wanted,domainLevel:authored.casterLevel,targetId:location?0x7f000000:o.id,position:[24,14,0],location});await s.drainPlayerInputs();assert.equal(await input,0,'Native input35 returns0 after dispatch');assert.ok(o.objectActionState.list.count>0);
  for(let n=0;n<160;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();try{await s.combat.runActions(o,...Object.values(s.worldTimer.time()));}catch(error){errors.push(error.message);break;}animations.push(o.animationState);
   while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(error){errors.push(error.message);}}
   if(o.objectActionState.list.count===0&&impacts.length)break;
  }
  const after=structuredClone(pool),diagnostics=runtimeDiagnostics.records.slice(start);report.rows.push({spellId:wanted,sourceId:source.id,sourceAbility:authored,location,before,after,impacts,animations:[...new Set(animations)],errors,diagnostics,queue:[...o.objectActionState.list].map(n=>n.actionId)});
  assert.deepEqual(errors,[]);assert.equal(pool,o.nativeSpellLikeAbilities);assert.equal(after[0].remaining,0);assert.equal(impacts.length,1);assert.equal(o.objectActionState.list.count,0);assert.deepEqual(o.nativeTalentClasses,classes);assert.ok(animations.some(id=>[15,16].includes(id)));assert.ok(animations.some(id=>[17,18,19,20,61,89,96].includes(id)));assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
 }
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({cases:report.rows.length,rows:report.rows.map(r=>({spellId:r.spellId,before:r.before,after:r.after,impacts:r.impacts,errors:r.errors})),failure:report.failure}));if(report.failure)process.exitCode=1;
