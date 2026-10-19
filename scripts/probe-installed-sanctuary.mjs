import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-sanctuary-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();s.random.seed(1);
 const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],actor=s.player,spellId=s.characterRules.spells.orderedRows.findIndex(row=>String(row.ImpactScript).toLowerCase()==='nw_s0_sanctuary');assert.ok(spellId>=0);
 const spell=s.spellBook.castingSpell(spellId),observer=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==actor&&o.areaId===actor.areaId);assert.ok(observer);
 const invoke=async(name,args,self=actor.id)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'sanctuary_'+name),self,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
 // Authored control fixture: an already visible observer targeting the subject.
 observer.perception.set(actor.id,1);observer.attackActionTargetId=actor.id;observer.nativeField700=1;observer.nativeField704=8000;
 const e=await invoke('EffectSanctuary',[257]);assert.equal(e.integers[4],257);assert.equal(e.integers[5],1);
 // Installed nwscript declares only DC, although the binary admits an optional
 // second flag. Author the no-save control payload without changing active ABI.
 e.integers[5]=0;await invoke('ApplyEffectToObject',[2,e,actor.id,0]);
 assert.equal(observer.perception.get(actor.id)&12,4);assert.equal(observer.nativeField700,0);assert.equal(observer.nativeAttackTarget724,OBJECT_INVALID);assert.ok(s.module.nativeInvisibleCreatureIds330.includes(actor.id));assert.ok(actor.effects.some(v=>v.id===e.id&&v.type===67&&v.integers[0]===107));
 await s.combat.removeInvisibility(actor);assert.ok(!actor.effects.some(v=>v.id===e.id));assert.equal(observer.perception.get(actor.id),undefined);assert.ok(!s.module.nativeInvisibleCreatureIds330.includes(actor.id));report.checks.push({check:'NCS-apply-pacify-linked-remove',observer:observer.id});
 observer.perception.set(actor.id,1);
 const choices=[];for(const[index,state]of actor.nativeTalentClasses.entries())for(const[level,slots]of state.memorized.entries())for(const slot of slots){if(slot?.id===spellId&&slot.ready)choices.push({index,domain:slot.domain?level-s.spellBook.metamagicCost(slot.metamagic):0,meta:slot.metamagic});}
 const choice=choices.find(c=>s.spellBook.uses(actor,spellId,c.index,c.domain,c.meta)>0),impacts=[],run=s.runScript.bind(s);s.runScript=(name,id,options)=>{if(name===spell.impactScript)impacts.push({name,id});return run(name,id,options);};
 let beforeUses;if(choice){beforeUses=s.spellBook.uses(actor,spellId,choice.index,choice.domain,choice.meta);const input=s.queuePlayerCastSpell({spellId,classIndex:choice.index,domainLevel:choice.domain,metamagic:choice.meta,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await input,1);}
 else await invoke('ActionCastSpellAtObject',[spellId,actor.id,0,1]);
 for(let n=0;n<150;n++){s.scheduler.advance(100);s.worldTimer.snapshot();await s.combat.updateTimer(actor,100);if(actor.objectActionState.list.count)await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await s.scheduler.pump();if(impacts.length&&actor.effects.some(e=>e.type===63)&&!actor.objectActionState.list.count)break;}
 assert.equal(impacts.length,1);assert.ok(actor.effects.some(e=>e.type===63&&e.spellId===spellId));assert.ok(actor.nativeEffectIcons778.records.some(e=>e.iconId===52));
 if(choice)assert.equal(s.spellBook.uses(actor,spellId,choice.index,choice.domain,choice.meta),beforeUses-1);
 report.checks.push({check:choice?'prepared-player-cast':'native-script-cheat-cast',spellId,script:spell.impactScript,impacts:impacts.length,elapsed:s.scheduler.time,slotConsumed:Boolean(choice)});
 await s.combat.removeInvisibility(actor);assert.ok(!actor.effects.some(e=>e.type===63));assert.ok(!actor.nativeEffectIcons778.records.some(e=>[52,107].includes(e.iconId)));assert.ok(!s.module.nativeInvisibleCreatureIds330.includes(actor.id));
 await invoke('AddHenchman',[actor.id,observer.id]);assert.equal(observer.masterId,actor.id);const invis=await invoke('EffectInvisibility',[1]);await invoke('ApplyEffectToObject',[2,invis,observer.id,0]);assert.ok(observer.effects.some(e=>e.id===invis.id&&e.type===47));
 await invoke('RemoveHenchman',[actor.id,observer.id]);assert.equal(observer.masterId,OBJECT_INVALID);assert.equal(observer.associateType,0);assert.ok(!observer.effects.some(e=>e.id===invis.id));assert.ok(!s.module.nativeInvisibleCreatureIds330.includes(observer.id));report.checks.push({check:'invisible-henchman-dismissal',id:observer.id});assert.equal(s.registry.nextObjectId[0],cursor);
 report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed Prelude/cleric, actual NCS constructor/apply and ordinary cast action/timing through untouched Sanctuary impact script, linked cleanup and canonical IDs. Control observer visibility/attack target authored for deterministic pacify fixture. Prepared slot use asserted when installed preset provides it; otherwise explicit native script cheat path. AI/startup isolated; not campaign, renderer, full AI/save/transport proof.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks,diagnostics:report.diagnostics.length}));
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
