import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {selectInstalledLearnableScrolls} from './select-installed-scrolls.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-rest-v1.json',report={steps:[],events:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const actor=s.player;report.playerId=actor.id;report.noRest=s.currentArea.nativeMessageFields[0x100];assert.equal(report.noRest,0);
 const invoke=async(name,args=[])=>{const ordinal=s.vm.api.findIndex(api=>api?.name===name);assert.ok(ordinal>=0);const api=s.vm.api[ordinal],frame={stack:[]};for(let n=args.length-1;n>=0;n--)s.vm.push(frame,api.args[n].type,args[n]);return s.vm.run({name:'owned_installed_rest_command',instructions:new Map([[13,{op:5,command:ordinal,argc:args.length,pc:13,next:14}],[14,{op:0x20,pc:14,next:15}]])},actor.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 const dispatch=s.combat.dispatchEvent.bind(s.combat);s.combat.dispatchEvent=async(o,e)=>{if(e.eventId===10&&e.payload?.type===35)report.events.push({caller:e.callerId,target:o.id,state:e.payload.integers[0],time:s.scheduler.time});return dispatch(o,e);};
 const drain=async()=>{while(s.scheduler.events[0]?.due<=s.scheduler.time)await s.dispatch(s.scheduler.events.shift());};
 const tick=async ms=>{s.scheduler.advance(ms);s.worldTimer.snapshot();await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await drain();};
 const input=async request=>{const p=s.queuePlayerSpellPreparation(request);await s.drainPlayerInputs();assert.equal(await p,0);};
 const choice=(await selectInstalledLearnableScrolls(s))[0];report.choice=choice;const itemId=await s.createItem(choice.template,actor.id,1,'');s.scheduler.events=[];await s.items.inputLearn({itemId});await drain();
 assert.equal(s.items.lastLearnScroll.result,1);const pool=actor.nativeTalentClasses[choice.classIndex].memorized[choice.level];
 await input({classIndex:choice.classIndex,spellId:choice.spellId,slot:0,domainLevel:0,metamagic:0});assert.equal(pool[0].ready,0);assert.equal(s.spellBook.uses(actor,choice.spellId,choice.classIndex,0,0),0);
 const resourceCounts=()=>actor.inventory.map(id=>s.registry.get(id)).filter(Boolean).map(i=>({id:i.id,charges:i.charges,stackSize:i.stackSize})),inventoryBefore=resourceCounts();
 await s.damage.subtract(actor,10);const hpBefore=actor.stats.currentHP;
 const buff=s.effects.create(2,actor.id,[1,1,0],8);buff.durationType=1;buff.duration=100;await s.effects.applyNative(buff,actor.id);assert.ok(actor.nativeCreatedAreaEffects170.view().includes(actor.id));
 report.moduleRestScript=s.ifo.Mod_OnPlrRest??'';
 const start=runtimeDiagnostics.records.length,p=s.queuePlayerRest();await s.drainPlayerInputs();assert.equal(await p,0);assert.ok(actor.activities&16);assert.equal(pool[0].ready,0);
 for(let n=0;n<500;n++){await tick(100);if(n%10===0)report.steps.push({time:s.scheduler.time,hp:actor.stats.currentHP,ready:pool[0].ready,activity:actor.activities,animation:actor.animationState,queue:[...actor.objectActionState.list].map(n=>n.actionId)});if(!(actor.activities&16)&&actor.objectActionState.list.count===0)break;}
 report.normal={hpBefore,hpAfter:actor.stats.currentHP,maxHP:s.hitPoints(actor.id,true),ready:pool[0].ready,queue:[...actor.objectActionState.list].map(n=>n.actionId),timing:s.nativeLocalClient.guiTiming};
 assert.equal(report.normal.hpAfter,report.normal.maxHP);assert.equal(pool[0].ready,1);assert.equal(actor.effects.some(e=>e.id===buff.id),false);assert.equal(actor.nativeCreatedAreaEffects170.count,0);assert.equal(actor.activities&16,0);assert.equal(s.module.nativeLastPCRested380,actor.id);assert.equal(s.module.nativeLastRestEvent384,2);assert.deepEqual(resourceCounts(),inventoryBefore);
 const impacts=[],run=s.runScript.bind(s);s.runScript=async(name,id,options)=>{if(name===s.spellBook.castingSpell(choice.spellId).impactScript)impacts.push({name,id,time:s.scheduler.time});return run(name,id,options);};
 const cast=s.queuePlayerCastSpell({actorId:actor.id,areaId:actor.areaId,spellId:choice.spellId,classIndex:choice.classIndex,metamagic:0,domainLevel:0,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await cast,1);
 for(let n=0;n<250;n++){await tick(100);if(actor.objectActionState.list.count===0&&impacts.length)break;}
 s.runScript=run;report.cast={impacts,ready:pool[0].ready,queue:[...actor.objectActionState.list].map(n=>n.actionId),effects:actor.effects.map(e=>({id:e.id,type:e.type,spellId:e.spellId}))};assert.equal(impacts.length,1);assert.equal(pool[0].ready,0);assert.equal(actor.objectActionState.list.count,0);
 // Invoke actual VM commands; ordinary ActionRest requests an action, while
 // ForceRest performs the independently mapped immediate restoration owner.
 actor.excitedDuration=0;await invoke('ActionRest',[0]);await drain();await tick(100);assert.ok(actor.activities&16);const partial=pool[0].ready;
 await s.combat.clearActions(actor);await drain();report.cancel={readyBefore:partial,readyAfter:pool[0].ready,lastEvent:s.module.nativeLastRestEvent384};assert.equal(pool[0].ready,partial);assert.equal(s.module.nativeLastRestEvent384,3);assert.equal(actor.activities&16,0);
 await invoke('ForceRest',[actor.id]);await drain();report.force={ready:pool[0].ready,resting:(await invoke('GetIsResting',[actor.id])).stack[0].value,lastPC:(await invoke('GetLastPCRested')).stack[0].value,lastEvent:(await invoke('GetLastRestEventType')).stack[0].value};assert.equal(pool[0].ready,1);assert.equal(report.force.resting,0);assert.equal(report.force.lastPC,actor.id);assert.equal(report.force.lastEvent,3);
 report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
 report.limits='Read-only installed wizard, actual active-data-selected scroll and authored spell impact; shared learning/preparation/rest/cast and VM ActionRest/ForceRest/queries. Injury and timed mitigation buff are owned test inputs. Native action42 timing driven in 100ms steps, general AI/startup/area entry isolated. Module rest-event delivery is not suppressed; installed script runs when present (see moduleRestScript). No rendered/campaign/save/protocol parity claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({playerId:report.playerId,choice:report.choice,noRest:report.noRest,normal:report.normal,cast:report.cast,cancel:report.cancel,force:report.force,failure:report.failure}));if(report.failure)process.exitCode=1;
