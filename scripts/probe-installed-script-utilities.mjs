import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-script-utilities-v1.json',report={};
const storage=new DataView(new ArrayBuffer(4)),bits=value=>{storage.setFloat32(0,value,true);return storage.getUint32(0,true);},value=raw=>{storage.setUint32(0,raw,true);return storage.getFloat32(0,true);};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const start=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const oracle=JSON.parse(await fs.readFile('backups/animations/native-script-utilities-observations.json','utf8'));
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(row=>row.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return s.vm.run(parseNcs(ncs,'utility_runtime_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 report.locations=[];
 for(const vector of[[2,-3,4],[-1,-0.,0],[1e30,-1e30,0],[0,0,0]]){
  const row=oracle.rows.find(r=>r.case.mode==='location'&&r.case.command===undefined&&JSON.stringify(r.case.vectorBits)===JSON.stringify(vector.map(bits)));assert.ok(row);
  const location={areaId:s.currentArea.id,position:[-2,5.25,0],nativeOrientation:vector,orientation:12345},result=await invoke('GetFacingFromLocation',[location]);assert.equal(bits(result.stack[0].value),row.output.bits);
  const area=(await invoke('GetAreaFromLocation',[location])).stack[0].value;assert.equal(area,s.currentArea.id);assert.equal(s.registry.get(area),s.currentArea);
  report.locations.push({vectorBits:vector.map(bits),facingBits:row.output.bits,areaId:area});
 }
 report.vectors=[];for(const vector of[[0,0,0],[-0.,-0.,-0.],[2,-3,4],[1e-30,-1e-30,1e-30],[1e-20,0,0]]){
  const row=oracle.rows.find(r=>r.case.mode==='normalize'&&JSON.stringify(r.case.vectorBits)===JSON.stringify(vector.map(bits)));assert.ok(row);
  const frame=await invoke('VectorNormalize',[vector]);assert.equal(frame.stack.length,3);assert.ok(frame.stack.every(cell=>cell.type===4));const result=frame.stack.map(cell=>cell.value);assert.deepEqual(result.map(bits),row.output.bits);report.vectors.push({input:vector.map(bits),output:result.map(bits)});
 }
 const result=await invoke('PrintString',['Parsed NCS %s\0not printed']);assert.equal(result.stack.length,0);const log=runtimeDiagnostics.records.slice(start).filter(r=>r.code==='script.print-string');assert.equal(log.length,1);assert.equal(log[0].message,'Parsed NCS %s\n');assert.equal(log[0].context.script,'utility_runtime_PrintString');assert.equal(log[0].context.objectId,s.player.id);report.scriptLog=log[0];
 assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Real parsed NCS engine commands225/224/137/1, installed character/module and canonical area/PC identities. Expected values come from original-code observations; raw stored vectors override compatibility orientation metadata. No cast, full impact-script or campaign-completion claim.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED NCS LOCATION ACCESS, VECTOR NORMALIZE AND SCRIPT LOGGING PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
