import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {resolveOnHitProperty} from '../src/on_hit_property.js';
import {getAttackData} from '../src/combat_attack_data.js';
import {advanceLocalClocks} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-onhit-engine-spells-v1.json',report={checks:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),character=await fs.readFile(`${install}/data/lcv/cleric.bic`);
 for(const[name,subtype,spellId,level]of[['LesserDispel',10,94,5],['DispelMagic',11,41,10],['GreaterDispel',12,67,15],['MordysDisjunction',13,122,20],['Knock',8,93,1]]){
  const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character}),actor=s.player;
  const target=name==='Knock'?[...s.registry.objects.values()].find(o=>o.objectType===10&&!o.plot):s.byTag('M1Q0D19Goblin').find(o=>!o.plot&&!s.isDead(o));assert.ok(target);
  await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
  const begin=runtimeDiagnostics.records.length,refs=[...s.registry.objects],cursor=s.registry.nextObjectId[0],item=s.equippedItems(actor).find(i=>(i.data.PropertiesList??[]).some(p=>p.PropertyName===48&&p.Subtype===9));assert.ok(item);const template=item.data.PropertiesList.find(p=>p.PropertyName===48&&p.Subtype===9),property={...template,Subtype:subtype};
  report.current={name,subtype,spellId,level,targetId:target.id,loadDiagnostics:runtimeDiagnostics.records.slice(0,begin)};
  let protectedDoors=[];
  if(name==='Knock'){
   const calls=[],lookup=s.vm.command,watch=new Set(['GetFirstObjectInShape','GetNextObjectInShape','GetPlotFlag','GetLocked','AssignCommand','SetLocked','GetLocalInt']);report.current.calls=calls;
   s.vm.command=n=>{const handler=lookup(n);if(!handler||!watch.has(n))return handler;return async(args,frame)=>{const value=await handler(args,frame);calls.push({name:n,self:frame.self,args:args.map(a=>typeof a==='object'?'[captured value]':a),result:typeof value==='object'?'[object]':value});return value;};};
  }
  const invoke=async(id,caster)=>{caster.nativeSpellClass22c=0;caster.nativeSpellDomain21c=0;caster.nativeSpellMetamagic22d=0;const spell=s.spellBook.castingSpell(id);s.combat.enqueueEvent(8,caster.id,caster.id,0,{spellId:id,casterId:caster.id,targetId:target.id,itemId:0x7f000000,featId:65535,position:[target.position[0],-target.position[2],target.position[1]],script:spell.impactScript});await s.scheduler.pump();};
  if(name==='Knock'){
   // Explicit live lock fixture; no original UTD/module resources change.
   report.current.authoredLock={locked:target.locked,openDC:target.nativeDoorOpenLockDC41f};target.locked=1;target.nativeDoorOpenLockDC41f=1;
   protectedDoors=[...s.registry.objects.values()].filter(o=>o!==target&&o.objectType===10&&o.areaId===target.areaId&&o.position.reduce((n,v,i)=>n+(v-target.position[i])**2,0)<1600).slice(0,2);assert.equal(protectedDoors.length,2);
   protectedDoors[0].locked=1;protectedDoors[0].plot=true;protectedDoors[0].nativeDoorKeyRequired450=0;
   protectedDoors[1].locked=1;protectedDoors[1].plot=false;protectedDoors[1].nativeDoorKeyRequired450=1;
   report.current.protectedDoors=protectedDoors.map(o=>({id:o.id,plot:o.plot,keyRequired:o.nativeDoorKeyRequired450}));
  }else{await invoke(100,target);await invoke(365,target);assert.ok(target.effects.some(e=>e.spellId===100));assert.ok(target.effects.some(e=>e.spellId===365));report.current.before=structuredClone(target.effects);}
  actor.combatRound.currentAttack=0;const attack=getAttackData(actor.combatRound,0),attempts=[];
  for(let seed=1;seed<=128;seed++){s.random.seed(seed);attack.lists[1].length=0;await resolveOnHitProperty(actor,target,item,property,0,0,s.combat.onHitPropertyProviders(item,property));attempts.push({seed,count:attack.lists[1].length});if(attack.lists[1].length)break;}
  assert.equal(attack.lists[1].length,1);const payload=attack.lists[1][0];report.current.payload=structuredClone(payload);report.current.attempts=attempts;assert.equal(payload.spellId,spellId);assert.equal(payload.casterLevel,level);assert.equal(payload.script,s.spellBook.castingSpell(spellId).impactScript);assert.equal(payload.itemId,item.id);assert.equal(payload.targetId,target.id);
  const scripts=[],run=s.runScript.bind(s);s.runScript=(script,id,options)=>{scripts.push({script,id,override:actor.nativeCasterOverride820,level:actor.nativeCasterOverride824});return run(script,id,options);};
  const contextBefore=[actor.nativeCasterOverride820,actor.nativeCasterOverride824],emitted=[];
  // Execute the actual melee signal owner; capture unrelated hit/damage event
  // boundaries so this fixture isolates the new spell path from door combat.
  attack.result=1;attack.animationDuration=20;actor.combatRound.currentAttack=1;
  await s.combat.signalMelee(actor,target,1,{enqueue:(id,caller,victim,delay,data)=>{emitted.push({id,caller,victim,delay});if(id===19)return s.combat.enqueueEvent(id,caller,victim,delay,data);}});
  assert.ok(emitted.some(e=>e.id===19&&e.victim===actor.id));advanceLocalClocks(s,10);await s.scheduler.pump();
  for(let n=0;n<20&&s.scheduler.events.length;n++){const next=s.scheduler.events[0],delta=next.due-s.scheduler.time;if(!Number.isFinite(delta)||delta>1000)break;if(delta>0)advanceLocalClocks(s,delta);await s.scheduler.pump();}
  assert.ok(scripts.some(c=>c.script.toLowerCase()===payload.script.toLowerCase()&&c.id===actor.id&&c.override===1&&c.level===level));assert.deepEqual([actor.nativeCasterOverride820,actor.nativeCasterOverride824],contextBefore);
  if(name==='Knock'){
   report.current.actionsBefore=structuredClone(target.objectActionState);const now=s.activeTimer(target.id).time();
   for(const o of[target,...protectedDoors]){for(let n=0;n<8&&o.objectActionState.list.count;n++){await s.combat.runActions(o,now.day,now.time);await s.scheduler.pump();}}
   report.current.actionsAfter=structuredClone(target.objectActionState);assert.equal(target.eventObjects.unlocked,target.id);
   for(const o of protectedDoors){assert.equal(o.nativeLastSpell234,93,'Protected fixtures must actually receive the authored notification');assert.equal(o.locked,1);}
   assert.equal(protectedDoors[1].nativeDoorField4b4,protectedDoors[1].id,'Key-required native action must deliver failed-unlock event34');
  }
  report.current.scripts=scripts;report.current.emitted=emitted;
  if(name==='Knock'){report.current.afterLocked=target.locked;assert.equal(target.locked,0);}
  else{report.current.after=structuredClone(target.effects);assert.ok(report.current.before.some(e=>!target.effects.some(a=>a.id===e.id)),'Real installed dispel must remove at least one shared buff ID');}
  for(const[id,o]of refs)assert.equal(s.registry.get(id),o);assert.equal(s.registry.nextObjectId[0],cursor);report.current.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.current.diagnostics.filter(d=>d.severity==='error'),[]);report.checks.push(report.current);
 }
 report.validation='PASS';report.limits='Installed Prelude/cleric, goblin buffs and controlled live door lock. Active property/DC rules, chance seed search, exact spell request metadata, actual melee signal event19 scheduling and installed NCS scripts, positive buff removal/unlock and caster override restoration. Other signal events captured, startup/general AI disabled; not full strike, door combat, presentation or campaign acceptance. All diagnostics retained, canonical references/cursor stable.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.name),current:report.current?.name,error:report.error}));
