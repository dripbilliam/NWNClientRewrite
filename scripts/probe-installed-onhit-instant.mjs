import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {resolveOnHitProperty} from '../src/on_hit_property.js';
import {getAttackData} from '../src/combat_attack_data.js';
import {advanceLocalClocks} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-onhit-instant-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)}),actor=s.player,target=s.byTag('M1Q0D19Goblin').find(o=>!o.plot&&!s.isDead(o));assert.ok(target);
 await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
 const item=s.equippedItems(actor).find(i=>(i.data.PropertiesList??[]).some(p=>p.PropertyName===48&&p.Subtype===9));assert.ok(item);const template=item.data.PropertiesList.find(p=>p.PropertyName===48&&p.Subtype===9),round=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255),begin=runtimeDiagnostics.records.length,refs=[...s.registry.objects],cursor=s.registry.nextObjectId[0];
 const drain=async()=>{for(const payload of round.lists[0].splice(0))await s.combat.dispatchEvent(target,{eventId:5,callerId:actor.id,payload});await s.scheduler.pump();};
 const admit=async(name,type,subtype,param=0,cost=template.CostValue)=>{
  const property={...template,PropertyName:type,Subtype:subtype,Param1Value:param,CostValue:cost},attempts=[];let payloads=[];
  for(let seed=1;seed<=128;seed++){s.random.seed(seed);round.lists[0].length=0;await resolveOnHitProperty(actor,target,item,property,0,1,s.combat.onHitPropertyProviders(item,property));attempts.push({seed,types:round.lists[0].map(e=>e.type)});if(round.lists[0].length){payloads=structuredClone(round.lists[0]);break;}}
  assert.ok(payloads.length,`${name}: native admission must produce a payload`);return{name,property,attempts,payloads};
 };
 for(const[name,type,subtype,expected]of[['Poison',48,19,35],['Disease',48,20,5],['AbilityDamage',48,18,37],['DispelMagic',36,0,51]]){
  report.current=await admit(name,type,subtype);assert.ok(report.current.payloads.some(e=>e.type===expected));const before=target.effects.map(e=>e.id);
  if(name==='Poison'){
   // Application has its own save after dispatcher admission. Explicit seed
   // search exercises a real failed save rather than only a consumed payload.
   for(let seed=1;seed<=128;seed++){s.random.seed(seed);round.lists[0].splice(0,round.lists[0].length,...structuredClone(report.current.payloads));await drain();report.current.applicationSeed=seed;if(target.effects.some(e=>e.type===35))break;}
   assert.ok(target.effects.some(e=>e.type===35),'Poison: real application save must fail and retain the timed affliction');
  }else await drain();report.current.active=structuredClone(target.effects);report.current.hp=target.stats.currentHP;
  if([5,37,82].includes(expected))assert.ok(target.effects.some(e=>e.type===expected),`${name}: real effect applied`);
  for(const e of target.effects.slice())if(!before.includes(e.id))await s.effects.remove(target.id,e.id);report.checks.push(report.current);
 }
 // Wounding is retained with a shared-ID icon; exact clock boundary cannot
 // bleed early. Controlled HP prevents unrelated death from hiding the tick.
 report.current=await admit('Wounding',48,25);await drain();const wound=target.effects.find(e=>e.type===84);assert.ok(wound);assert.ok(target.effects.some(e=>e.id===wound.id&&e.type===67&&e.integers[0]===129));assert.ok(target.nativeEffectIcons778.records.some(r=>r.iconId===129));
 const now=s.activeTimer(target.id).time();wound.integers[1]=now.day;wound.integers[2]=now.time;target.stats.currentHP=s.hitPoints(target.id,true);s.damage.synchronize(target);const hp=target.stats.currentHP;
 advanceLocalClocks(s,6000);await s.effects.updateObject(target,s.activeTimer(target.id).time());await s.scheduler.pump();assert.equal(target.stats.currentHP,hp);
 advanceLocalClocks(s,1);await s.effects.updateObject(target,s.activeTimer(target.id).time());const damageEvent=s.scheduler.events.find(e=>e.event.eventId===5);report.current.queuedDamage=structuredClone(damageEvent);assert.ok(damageEvent);await s.scheduler.pump();assert.equal(target.stats.currentHP,hp-wound.integers[0]);report.current.afterTick=target.stats.currentHP;
 await s.effects.applyNative(s.effects.create(39,actor.id,[1]),target.id);assert.ok(!target.effects.some(e=>e.id===wound.id));assert.ok(!target.nativeEffectIcons778.records.some(r=>r.iconId===129));report.current.cured=true;report.checks.push(report.current);
 // Vampiric healing is capped by actual strike damage and affects the
 // original canonical creator, not the defender receiving the payload.
 for(const cap of[4,2]){
  actor.stats.currentHP=s.hitPoints(actor.id,true)-10;s.damage.synchronize(actor);const injured=actor.stats.currentHP;round.damage.fill(-1);round.damage[12]=3;
  report.current=await admit(`VampiricRegeneration cap${cap}`,67,0,0,cap);const vamp=report.current.payloads.find(e=>e.type===86);assert.ok(vamp);await drain();assert.equal(actor.stats.currentHP,injured+Math.min(cap,3));assert.ok(!target.effects.some(e=>e.type===86));report.current.healed=actor.stats.currentHP-injured;report.checks.push(report.current);
 }
 // A source that leaves queues removal but still permits its final due tick.
 report.current=await admit('Wounding source leaves area',48,25);await drain();const abandoned=target.effects.find(e=>e.type===84);assert.ok(abandoned);const stamp=s.activeTimer(target.id).time();abandoned.integers[1]=stamp.day;abandoned.integers[2]=stamp.time;const oldArea=actor.areaId;actor.areaId=0x7f000000;
 advanceLocalClocks(s,6001);await s.effects.updateObject(target,s.activeTimer(target.id).time());actor.areaId=oldArea;report.current.events=s.scheduler.events.map(e=>({eventId:e.event.eventId,callerId:e.event.callerId,targetId:e.targetId}));assert.ok(report.current.events.some(e=>e.eventId===14));assert.ok(report.current.events.some(e=>e.eventId===5));await s.scheduler.pump();assert.ok(!target.effects.some(e=>e.id===abandoned.id));assert.ok(!target.nativeEffectIcons778.records.some(r=>r.iconId===129));report.checks.push(report.current);
 // This authored goblin has one level. The final negative level therefore
 // queues native death and consumes its effects; retaining82 is not expected.
 report.current=await admit('LevelDrain last level causes death',48,17);assert.ok(report.current.payloads.some(e=>e.type===82));await drain();assert.ok(s.isDead(target));report.current.dead=true;report.checks.push(report.current);
 for(const[id,o]of refs)assert.equal(s.registry.get(id),o);report.registry={before:cursor,after:s.registry.nextObjectId[0],sameReferences:true,added:[...s.registry.objects].filter(([id])=>!refs.some(([prior])=>id===prior)).map(([id,o])=>({id,kind:o.kind,tag:o.tag,sourceKey:o.sourceKey}))};runtimeDiagnostics.flushRepeated();report.diagnostics=runtimeDiagnostics.records.slice(begin);report.loadDiagnostics=runtimeDiagnostics.records.slice(0,begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed Prelude/cleric/goblin with temporary owned property variants, native dispatcher tables/chance/saves, real event5 delivery/effect application, wound tick damage/healing/shared-icon cleanup, capped vampiric healing and source-area removal. Seed search and controlled HP/tick timestamps isolate owners; startup/general AI and full strike admission are separate. Slay/vorpal payloads are original-code verified, not whole death/corpse acceptance. Existing canonical objects stable; all diagnostics retained. Not full spells/combat/campaign completion.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.name),current:report.current?.name,error:report.error,diagnostics:report.diagnostics?.length}));
