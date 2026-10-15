// Replacement integration against active installed tables/geometry. Owned NPC
// fixture gear and disabled scripts are explicit controls, not native parity.
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {NativeRandom} from '../src/native_random.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/smoke-ranged-strike.mjs <install> [authored module]');
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false}).initialize([]);
const actor=s.byTag('po_observer')[0],target=s.byTag('po_target')[0];assert.ok(actor&&target);
for(const object of s.registry.objects.values())if(object.objectType===5)object.scripts={};
for(const area of s.areas.values())area.scripts={};
actor.immortal=target.immortal=1;
const weapon=s.register('item','owned-ranged-bow',{ownerId:actor.id,equipmentSlot:16,authored:{BaseItem:8,StackSize:1,PropertiesList:[]}});
const ammo=s.register('item','owned-ranged-arrows',{ownerId:actor.id,equipmentSlot:2048,authored:{BaseItem:20,StackSize:100,PropertiesList:[]}});
actor.inventory.push(weapon.id,ammo.id);s.refreshCombat(actor);actor.perception.set(target.id,3);target.perception.set(actor.id,3);
s.random=new NativeRandom(42);const begin=runtimeDiagnostics.records.length,hpBefore=s.hitPoints(target.id,false);
await s.combat.resolveRanged(actor,target,3,500);
const records=actor.combatRound.attacks.slice(0,3).map(data=>({result:data.result,roll:data.roll,modifier:data.modifier,damage:[...data.damage],reactionDelay:data.reactionDelay}));
const queued=s.scheduler.events.map(e=>({due:e.due,target:e.targetId,id:e.event.eventId}));
for(let elapsed=0;elapsed<2000;elapsed+=100){s.scheduler.advance(100);await s.scheduler.pump();}
const failures=runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error');
console.log(JSON.stringify({actorId:actor.id,targetId:target.id,ammoId:ammo.id,records,queued,hpBefore,hpAfter:s.hitPoints(target.id,false),ammoBefore:100,ammoAfter:ammo.authored.StackSize,
  equippedWeight:actor.nativeEquippedWeight968,draws:s.random.draws,failureCount:failures.length,failures:failures.map(r=>r.message),
  limits:'Replacement strike/scheduler integration; authored equipped bow/arrows, immortal NPCs and disabled scripts. No complete original ranged encounter or network comparison.'}));
assert.equal(failures.length,0);assert.equal(ammo.authored.StackSize,97);assert.ok(s.hitPoints(target.id,false)<hpBefore);
