// Compares observations made by the unmodified native server with providers
// in this client. This is a narrow oracle, not proof of full combat parity.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';

const [install, modulePath = 'backups/native-combat-oracle/home/modules/codex_combat_oracle.mod', logPath = 'backups/native-combat-oracle/native-combat-log.txt'] = process.argv.slice(2);
if (!install) throw new Error('Usage: node scripts/verify-combat-oracle.mjs <install> [authored module] [native server log]');
const manifest=JSON.parse(await fs.readFile(`${modulePath}.manifest.json`,'utf8'));
const capture=JSON.parse(await fs.readFile(`${logPath}.capture.json`,'utf8'));
assert.equal(manifest.moduleSha256,createHash('sha256').update(await fs.readFile(modulePath)).digest('hex'));
assert.equal(capture.moduleSha256,manifest.moduleSha256,'Native capture belongs to another fixture');
assert.equal(capture.logSha256,createHash('sha256').update(await fs.readFile(logPath)).digest('hex'));
const native = (await fs.readFile(logPath, 'utf8')).split(/\r?\n/).filter(line => line.startsWith('ORACLE '));
assert.ok(native.some(line => /^ORACLE LOAD /.test(line)), 'Native module never loaded');
const resolver = await openLocalModule(install, modulePath), messages = [];
const session = await new ModuleSession(resolver, { runStartupScripts:false, onMessage:m=>messages.push(m) }).initialize([]);
const actors = [...session.registry.objects.values()].filter(o=>o.objectType === 5 && o.tag?.startsWith('oc_'));
assert.equal(actors.length,3); const find = tag => actors.find(o=>o.tag === tag);
// Native allocation differs when the replacement session also owns a PC.
// Compare actor tags/stat values, and preserve each runtime's canonical IDs.
const nativeIds = new Map();
for (const tag of ['oc_a','oc_b','oc_i']) {
  const pattern = tag === 'oc_i' ? /^ORACLE PROBE id=([\da-f]+) BAB=(-?\d+) AC=(-?\d+) HP=(-?\d+)/ : /^ORACLE START id=([\da-f]+) BAB=(-?\d+) AC=(-?\d+) HP=(-?\d+)\/(-?\d+)/;
  const candidates = native.map(line=>line.match(pattern)).filter(Boolean), index = tag === 'oc_b' ? 1 : 0, row = candidates[index];
  assert.ok(row, `No native baseline for ${tag}`); const actor = find(tag); nativeIds.set(tag,row[1]);
  assert.equal(session.commands.GetBaseAttackBonus([actor.id]),Number(row[2]),`${tag} BAB`);
  assert.equal(session.commands.GetAC([actor.id,0]),Number(row[3]),`${tag} AC`);
  assert.equal(session.commands.GetCurrentHitPoints([actor.id]),Number(row[4]),`${tag} HP`);
  if (row[5]) assert.equal(session.commands.GetMaxHitPoints([actor.id]),Number(row[5]));
}
const probe = find('oc_i'), identity = probe.id, stats = probe.stats;
assert.equal(probe.creatureData.IsImmortal,1);
// The fixture's actual native script applies this same deterministic effect.
await session.effects.apply(0, session.commands.EffectDamage([50,4096,6],{self:probe.id}),probe.id);
assert.equal(session.registry.get(identity),probe);assert.equal(probe.stats,stats);
assert.equal(probe.stats.currentHP,1);assert.equal(session.damage.total(probe),50);
assert.equal(probe.lastDamagerId,probe.id);
assert.ok(native.some(line=>line.startsWith(`ORACLE IMMORTAL id=${nativeIds.get('oc_i')} HP=1 `)));
assert.ok(native.some(line=>line.startsWith(`ORACLE DAMAGED id=${nativeIds.get('oc_i')} caller=${nativeIds.get('oc_i')} damage=50 HP=1 `)));
const skills=[];
for(const skill of [10,16]){
  const row=native.find(line=>line.startsWith(`ORACLE SKILL id=${nativeIds.get('oc_i')} skill=${skill} base=`));
  assert.ok(row,`Native skill ${skill} missing`);const [,base,effective]=row.match(/base=(-?\d+) effective=(-?\d+)/).map(Number);
  assert.equal(session.commands.GetSkillRank([skill,probe.id,1]),base);
  const actual=await session.commands.GetSkillRank([skill,probe.id,0]);
  assert.equal(actual,effective);skills.push({skill,base,native:effective,replacement:actual});
}
await session.effects.apply(2,session.commands.EffectImmunity([2],{self:probe.id}),probe.id);
const saves=[];
for(const [kind,save] of [['FortitudeSave',1],['ReflexSave',2],['WillSave',3]]){
  const row=native.find(line=>line.startsWith(`ORACLE SAVE id=${nativeIds.get('oc_i')} kind=${kind} dc=65535 category=2 result=`));
  assert.ok(row,`Native ${kind} missing`);const result=Number(row.match(/result=(\d+)/)[1]);assert.equal(result,2);
  const actual=await session.combat.savingThrow(probe,save,65535,2,probe.id,1,0,0);
  assert.equal(actual,result);saves.push({kind,native:result,replacement:actual});
}
const skillEffects=[];
for(const [stage,name,amount] of [['up5','EffectSkillIncrease',5],['up3','EffectSkillIncrease',3],['down2','EffectSkillDecrease',2]]){
  const row=native.find(line=>line.startsWith(`ORACLE SKILL_EFFECT id=${nativeIds.get('oc_i')} stage=${stage} base=`));
  assert.ok(row,`Native skill effect ${stage} missing`);const [,base,effective]=row.match(/base=(-?\d+) effective=(-?\d+)/).map(Number);
  await session.effects.apply(2,session.commands[name]([10,amount],{self:probe.id}),probe.id);
  assert.equal(session.commands.GetSkillRank([10,probe.id,1]),base);
  const actual=await session.commands.GetSkillRank([10,probe.id,0]);
  assert.equal(actual,effective);skillEffects.push({stage,base,native:effective,replacement:actual});
}
const source = find('oc_a'), victim = find('oc_b'), data = source.combatRound.attacks[0];
const featUses=[];
function checkFeat(stage,feat){
  const row=native.find(line=>line.startsWith(`ORACLE FEAT id=${nativeIds.get('oc_i')} stage=${stage} feat=${feat} `));
  assert.ok(row,`Native feat ${stage}/${feat} missing`);
  const [,has,owned,uses]=row.match(/has=(\d+) owned=(\d+) uses=(\d+)/).map(Number);
  assert.equal(session.commands.GetHasFeat([feat,probe.id,0]),has);assert.equal(session.commands.GetHasFeat([feat,probe.id,1]),owned);
  assert.equal(session.commands.GetFeatRemainingUses([feat,probe.id]),uses);featUses.push({stage,feat,has,owned,uses});
}
for(const feat of [223,39,5])checkFeat('loaded',feat);
for(const stage of ['consume1','consume2','exhausted']){session.commands.DecrementRemainingFeatUses([probe.id,39]);checkFeat(stage,39);}
session.commands.IncrementRemainingFeatUses([probe.id,39]);checkFeat('restore',39);
data.result=1;data.weaponAttackType=7;data.targetId=victim.id;
const beforeHP=victim.stats.currentHP, rolled=[];
for(let index=0;index<10;index++) {
  const amount=await session.damage.roll(source,victim,data,{offhand:false,critical:false,sneak:false,death:false,maximize:false});
  assert.ok(amount>=1&&amount<=3);rolled.push(amount);
}
assert.equal(victim.stats.currentHP,beforeHP);assert.equal(data.damage[12],-1,'Damage dice provider must not commit attack record or HP');
// Validate observed native strike history and cumulative HP independently of
// any guessed seed, attack count, fixed reaction duration or actor allocation.
let hits = 0, notifications = 0; const hp = new Map(['oc_a','oc_b'].map(tag=>[nativeIds.get(tag),20]));
const attacks = new Map();
for (const line of native) {
  let row = line.match(/^ORACLE ATTACKED id=([\da-f]+) caller=([\da-f]+) type=(\d+) mode=(\d+)/);
  if (row && hp.has(row[1])) { assert.equal(row[3],'0');assert.equal(row[4],'0');attacks.set(row[1],row[2]);notifications++; }
  row = line.match(/^ORACLE DAMAGED id=([\da-f]+) caller=([\da-f]+) damage=(\d+) HP=(-?\d+)/);
  if (row && hp.has(row[1])) {
    assert.equal(attacks.get(row[1]),row[2], 'Damage arrived without the corresponding prior attack notification');
    const damage = Number(row[3]);assert.ok(damage>=1 && damage<=6,'Naked fighter damage outside native unarmed/critical range');
    const remaining = Math.max(1,hp.get(row[1])-damage);assert.equal(Number(row[4]),remaining);hp.set(row[1],remaining);hits++;
  }
}
assert.ok(hits>0);assert.ok(notifications>=hits);
for (const tag of ['oc_a','oc_b']) {
  const rounds = native.map(line=>line.match(/^ORACLE ROUND id=([\da-f]+) count=(\d+)/)).filter(row=>row && row[1]===nativeIds.get(tag)).map(row=>Number(row[2]));
  assert.deepEqual(rounds,[1,2,3],`${tag} did not complete and stop after three rounds`);
}
console.log(JSON.stringify({ module:resolver.moduleName,moduleSha256:manifest.moduleSha256, nativeObservations:native.length, attackNotifications:notifications, damagingStrikes:hits, providerBaselines:3,saves,skills,skillEffects,featUses, replacementBareDamageRolls:rolled, immortalProbe:{nativeHP:1,replacementHP:probe.stats.currentHP,damageHistory:session.damage.total(probe)}, limits:'Independent original-server baselines, attack/damage ordering, HP arithmetic, immortality, poison-immune saves, bare/buffed skills and saved/consumed/restored feat uses. Replacement live attack loop, seed/draw-order, movement, special attacks, ranged, other defenses, presentation and network parity remain unverified.' }));
