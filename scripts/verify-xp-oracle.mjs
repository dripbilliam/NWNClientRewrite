// Compares the same authored NCS on the original server and replacement VM.
// Canonical allocation IDs are allowed to differ; scripts log tags and values.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath='backups/native-xp-oracle/home/modules/codex_xp_oracle.mod',logPath='backups/native-xp-oracle/native-xp-log.txt']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/verify-xp-oracle.mjs <install> [fixture] [native capture]');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const manifest=JSON.parse(await fs.readFile(modulePath+'.manifest.json','utf8'));
const capture=JSON.parse((await fs.readFile(logPath+'.capture.json','utf8')).replace(/^\ufeff/,''));
assert.equal(hash(await fs.readFile(modulePath)),manifest.moduleSha256);assert.equal(capture.moduleSha256,manifest.moduleSha256);
assert.equal(capture.serverSha256,'98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6');
const bytes=await fs.readFile(logPath);assert.equal(hash(bytes),capture.logSha256);
const native=bytes.toString('utf8').replace(/^\ufeff/,'').split(/\r?\n/).filter(l=>l.startsWith('XP_ORACLE '));assert.equal(native.length,3);
const messages=[],s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,onMessage:m=>messages.push(m)}).initialize([]);
const actor=s.byTag('xo_killer')[0],victim=s.byTag('xo_victim')[0];assert.ok(actor&&victim);
// Observation sink only; all gameplay calls execute through the normal VM.
// Production PrintString routing remains a recorded unsupported engine call.
s.commands.PrintString=([text])=>messages.push({type:'script',text});
const identity=victim.id,begin=runtimeDiagnostics.records.length;
await s.vm.run(await s.program('xo_load'),s.module.id);
const replacement=messages.filter(m=>m.type==='script'&&m.text?.startsWith('XP_ORACLE ')).map(m=>m.text);
const failures=runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error');
console.log(JSON.stringify({native,replacement,failures:failures.map(r=>r.message),statsPC:actor.nativeStatsIsPCb0,objectPC:actor.isPC,
  factionMemberIds:[...s.factionManager.members(actor).view()],limits:'Deterministic scripted death/XP engine-state probe. PrintString observation sink only. No actual connected client or full encounter/frame/RNG/network parity proof.'}));
assert.deepEqual(replacement,native);assert.equal(failures.length,0);assert.equal(s.registry.get(identity),victim);
assert.equal(actor.stats.xp,50);assert.equal(victim.nativeDeathWord8d4,0);
