import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-find-magnitude-v1.json',report={find:[],magnitude:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'find_magnitude_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0].value;};
 for(const [args,expected]of[[['abcabc','bc'],1],[['abcabc','bc',2],4],[['ab\0cd','cd',0],-1],[['ab\0cd','cd',3],3],[['€é€','€',1],2],[['abc','',0],-1],[['abc','a',-1],-1]]){const result=await invoke('FindSubString',args);assert.equal(result,expected);report.find.push({args,result});}
 for(const[vector,expected]of[[[0,0,0],0],[[3,4,0],5],[[1e-30,1e-30,0],0],[[1e30,-1e30,0],Infinity]]){const result=await invoke('VectorMagnitude',[vector]);assert.equal(result,expected);report.magnitude.push({vector,result:Number.isFinite(result)?result:String(result)});}
 assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Actual parsed NCS dispatch and omitted optional offset over installed nwscript API. Original-code oracle is separate. The replacement VM represents ordinary empty strings semantically; native allocated-empty/null-buffer representation is documented separately. No affected impact-script completion claim.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED FIND/MAGNITUDE NCS PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
