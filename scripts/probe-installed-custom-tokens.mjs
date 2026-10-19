import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-custom-token-v1.json',report={writes:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],client=s.combat.broadcastProviders().client(s.player.id);
 const invoke=async args=>{const ordinal=s.vm.api.findIndex(r=>r.name==='SetCustomToken');assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);await s.vm.run(parseNcs(ncs,'custom_token_probe'),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 const tokenWrites=[[42,'first'],[10,'lower'],[999,'upper'],[42,'replacement'],[42,'A\0B'],[42,'\0lead'],[42,'€\x80'],[9,'reserved'],[-1,'negative']];
 for(const[id,value]of tokenWrites){await invoke([id,value]);const server=s.talkTable.tokens.records.map(r=>({id:r.id,bytes:[...r.bytes]})),local=s.talkTable.tokensForClient(client).records.map(r=>({id:r.id,bytes:[...r.bytes]}));assert.deepEqual(local,server);report.writes.push({id,server});}
 assert.deepEqual(s.talkTable.tokens.records.map(r=>r.id),[10,42,999]);assert.deepEqual([...s.talkTable.tokens.records[1].bytes],[128,128]);assert.equal(s.registry.nextObjectId[0],cursor);report.lastDelivery=s.talkTable.lastTokenDelivery;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);assert.ok(report.diagnostics.some(r=>r.code==='text.custom-token-network-unimplemented'));report.validation='PASS';report.limits='Actual installed NCS setter, sorted table replacement, reserved/negative guards, byte ownership and local scalar message projection. Native table/wrapper/packet original oracle is separate. Full native client/network synchronization remains unavailable and diagnosed; this probe does not verify dialogue parsing or complete Deck/crafting behavior.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED NCS CUSTOM TOKEN TABLE/LOCAL BODY PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
