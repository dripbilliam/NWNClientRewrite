import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {savingThrowEffectBonus} from '../src/combat_modifiers.js';
import {creatureRoot} from '../src/creature_rules.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-versus-effects-v1.json',report={spells:[],calls:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const actor=s.player;report.playerId=actor.id;
 const start=runtimeDiagnostics.records.length,original=s.commands.VersusAlignmentEffect;
 s.commands.VersusAlignmentEffect=(args,...rest)=>{const e=original(args,...rest);report.calls.push({spellId:actor.nativeSpellId218,type:e?.type,selectors:args.slice(1),integers:e?.integers});return e;};
 const drain=async()=>{for(let n=0;n<1000&&s.scheduler.events.length;n++){s.scheduler.time=Math.max(s.scheduler.time,s.scheduler.events[0].due);await s.dispatch(s.scheduler.events.shift());}};
 for(const script of ['nw_s0_previl','nw_s0_prgood','nw_s0_holyaura','nw_s0_unhaura']){
  const spellId=s.characterRules.spells.orderedRows.findIndex(r=>String(r.ImpactScript).toLowerCase()===script);assert.ok(spellId>=0,script);
  actor.nativeSpellId218=spellId;actor.nativeSpellTarget214=actor.id;actor.nativeSpellPoint208=[...actor.position];actor.nativeSpellClass22c=0;actor.nativeSpellFeat23c=65535;actor.nativeSpellMetamagic22d=0;actor.nativeSpellDomain21c=0;
  const before=new Set(actor.effects.map(e=>e.id)),callStart=report.calls.length;
  await s.runScript(script,actor.id);await drain();
  const added=actor.effects.filter(e=>!before.has(e.id)),filtered=added.filter(e=>[26,48].includes(e.type)),alignment=script==='nw_s0_previl'||script==='nw_s0_holyaura'?5:4;
  const result={script,spellId,calls:report.calls.slice(callStart),effects:structuredClone(added),conditionalSaves:[]};report.spells.push(result);
  assert.ok(result.calls.length>0,`${script} invokes shared wrapper`);assert.ok(filtered.some(e=>e.type===26),`${script} save effect retained`);assert.ok(filtered.some(e=>e.type===48),`${script} armor effect retained`);
  for(const e of filtered)assert.equal(e.integers[e.type===26?5:4],alignment,`${script} retained conditional axis`);
  for(const goodEvil of [4,5])result.conditionalSaves.push({goodEvil,...savingThrowEffectBonus(creatureRoot(actor),added,[],1,{target:{race:6,lawChaos:1,goodEvil}})});
  assert.ok(result.conditionalSaves.find(r=>r.goodEvil===alignment).total>0);assert.equal(result.conditionalSaves.find(r=>r.goodEvil!==alignment).total,0);
  for(const id of new Set(added.map(e=>e.id)))await s.effects.remove(actor.id,id);s.scheduler.events=[];
 }
 report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
 report.limits='Read-only active Prelude resolver and installed wizard; invokes four installed authored impact scripts with canonical native spell context. General AI/startup/entry isolated. Checks wrappers, retained linked effects and existing conditional saving-throw consumer; not full casting queue, rendered feedback, high-level eligibility, campaign/save/protocol completion.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({playerId:report.playerId,spells:report.spells.map(({script,spellId,conditionalSaves})=>({script,spellId,conditionalSaves})),calls:report.calls.length,failure:report.failure}));if(report.failure)process.exitCode=1;
