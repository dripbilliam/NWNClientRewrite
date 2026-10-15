// Replacement integration with an installed BIC read in memory. Fixture-only
// changes disable immortality/scripts, establish hostility, and align CR with
// the imported PC level.
// This is NOT a complete original-game encounter comparison.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {NativeRandom} from '../src/native_random.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,fixture='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod',bic='fighter.bic',offset='2']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/smoke-player-death-xp.mjs <install> [authored fixture] [installed BIC filename]');
const startOffset=Number(offset);if(!Number.isFinite(startOffset))throw new Error('Invalid authored starting offset');
const messages=[],s=await new ModuleSession(await openLocalModule(install,fixture),{onMessage:m=>messages.push(m),runStartupScripts:true})
  .initialize([],{character:await fs.readFile(path.join(install,'data/lcv',bic))});
const pc=s.player,target=s.byTag('po_target')[0];assert.ok(pc.characterLoaded&&target);
for(const actor of s.registry.objects.values())if(actor.objectType===5)actor.scripts={};
for(const area of s.areas.values())area.scripts={};s.ifo.Mod_OnModLoad='';s.ifo.Mod_OnModStart='';s.ifo.Mod_OnClientEntr='';
target.immortal=0;target.nativeChallengeRatingD0=Math.fround(pc.stats.level);
pc.factionReputation[target.factionId-1]=0;
s.commands.SetAILevel([target.id,3]);await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+startOffset,target.position[1],target.position[2]]);
s.random=new NativeRandom(12345);
for(let elapsed=0;elapsed<8000;elapsed+=100){s.scheduler.advance(100);await s.scheduler.pump();}
assert.equal(s.commands.GetObjectSeen([target.id,pc.id]),1);
const begin=runtimeDiagnostics.records.length,xpBefore=pc.stats.xp,hpBefore=s.hitPoints(target.id,false),draws=s.random.draws;
const expectedXP=s.combat.calculateDeathExperience(target,s.combat.potentialLevel(pc),s.combat.potentialLevel(pc));
const input=s.queuePlayerAttack(target.id);await s.scheduler.pump();const accepted=await input;assert.equal(accepted,1);
for(let elapsed=0;elapsed<60000&&target.nativeDeathWord8d4!==0;elapsed+=100){s.scheduler.advance(100);await s.scheduler.pump();}
const records=runtimeDiagnostics.records.slice(begin),failures=records.filter(r=>r.severity==='error');
const result={bic,startOffset,accepted,pcId:pc.id,targetId:target.id,pcFaction:pc.factionId,targetFaction:target.factionId,
  hpBefore,hpAfter:s.hitPoints(target.id,false),deathWord:target.nativeDeathWord8d4,xpBefore,xpAfter:pc.stats.xp,expectedXP,
  nativeActionCount:target.objectActionState.list.length,randomDraws:s.random.draws-draws,
  failureCount:failures.length,failures:failures.slice(0,12).map(r=>({message:r.message,objectId:r.context.objectId,operation:r.context.operation})),
  pendingOwners:[...new Set(records.filter(r=>r.code.endsWith('unimplemented')).map(r=>r.message))],
  limits:'Loaded real-PC replacement integration. Explicit fixture immortality/script/hostility/CR overrides; no native frame/seed/network or complete death lifecycle parity proof.'};
console.log(JSON.stringify(result));
assert.equal(failures.length,0,'Player combat/death produced failing engine operations');
assert.equal(target.nativeDeathWord8d4,0,'Player attack did not complete target death');
assert.ok(result.hpAfter<=-11);assert.equal(pc.stats.xp,xpBefore+Math.trunc(expectedXP));assert.ok(expectedXP>0);
assert.equal(s.registry.get(target.id),target,'Death must retain the canonical corpse object');
