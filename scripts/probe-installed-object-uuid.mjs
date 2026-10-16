import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-object-uuid-v1.json',report={};
const data=(value,type=10)=>parseGff(writeGff('UTW ',gffRecord({UUID:gffField(type,value)}))).root;
function query(uuid,api){
 const id=api.findIndex(s=>s?.name==='GetObjectByUUID');assert.equal(id,0x382);
 const string=Buffer.from(uuid,'latin1'),code=[4,5,string.length>>>8,string.length&255,...string,5,0,id>>>8,id&255,1,0x20,0],bytes=Buffer.alloc(13+code.length);
 bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(code,13);return parseNcs(bytes,'uuid_lookup_fixture');
}
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const waypoints=[...s.registry.objects.values()].filter(o=>o.objectType===12);assert.ok(waypoints.length>=2);const [a,b]=waypoints,ids=[...s.registry.nextObjectId],first='01234567-89ab-cdef-0123-456789abcdef',second='11234567-89ab-cdef-0123-456789abcdef';
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length;
 const lookup=async value=>{const result=await s.vm.run(query(value,s.vm.api),s.player.id);assert.equal(result.stack.length,1);assert.equal(result.stack[0].type,6);return result.stack[0].value;};
 assert.equal(await lookup(first),OBJECT_INVALID);assert.equal(await s.loadNativeUUID(a,data(first)),1);assert.equal(await lookup(first),a.id);
 assert.equal(await s.loadNativeUUID(b,data(first)),0);assert.equal(await s.loadNativeUUID(b,data(first.toUpperCase())),0);assert.equal(b.nativeUUID.value,'');
 assert.equal(await s.loadNativeUUID(a,data('wrong_type',11)),1);assert.equal(a.nativeUUID.value,first);
 assert.equal(await s.loadNativeUUID(a,data(`${second}\0saved_tail`)),1);assert.equal(a.nativeUUID.value,`${second}\0saved_tail`);assert.equal(await lookup(`${second}\0query_tail`),a.id);assert.equal(await lookup(first),a.id);assert.deepEqual(s.registry.nextObjectId,ids);
 report.source={id:a.id,tag:a.tag,areaId:a.areaId};report.otherId=b.id;report.playerId=s.player.id;
 await s.lifecycle.destroy(a);assert.equal(s.registry.get(a.id),undefined);assert.equal(await lookup(second),OBJECT_INVALID);assert.equal(await lookup(first),a.id);assert.deepEqual(s.registry.nextObjectId,ids);
 report.retainedOldAlias=await lookup(first);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.equal(report.diagnostics.filter(r=>r.code==='object.uuid-warning').length,2);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);
 report.limits='Real installed Prelude waypoint objects and active NWScript command898 via NCS/VM. UUID fields are typed in-memory fixtures only; original resources untouched. Startup/AI disabled. Verifies canonical IDs, collision/invalid diagnostics, exact GFF type, embedded NUL, old aliases and current-key destructor removal. Random UUID generation, other object data-loader imports, CreateObject243 and campaign progression remain separate work. Historic alias retains the old object record/ID; no claim about reading original freed native memory.';
 report.validation='PASS';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,source:report.source,player:report.playerId,retainedOldAlias:report.retainedOldAlias,failure:report.failure}));if(report.failure)process.exitCode=1;
