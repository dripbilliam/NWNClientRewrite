import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {getGffFieldTypes} from '../src/gff.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-creature-immortality-v1.json',report={imports:[],writes:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'immortality_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
 const creatures=[...s.registry.objects.values()].filter(o=>o.objectType===5&&o.creatureData);
 for(const actor of creatures){const root=actor.creatureData,expected=getGffFieldTypes(root)?.IsImmortal===0?Number((root.IsImmortal&255)!==0):0;assert.equal(await invoke('GetImmortal',[actor.id]),expected);assert.equal(actor.immortal,expected);report.imports.push({id:actor.id,tag:actor.tag,expected});}
 const a=s.player,initial=a.nativeFlag8b8;
 try{for(const value of[0,1,2,-1,255,256,0x7fffffff,-0x80000000]){await invoke('SetImmortal',[a.id,value]);assert.equal(await invoke('GetImmortal',[a.id]),value);assert.equal(a.immortal,value);assert.equal(a.nativeFlag8b8,value);report.writes.push({value,stored:a.nativeFlag8b8});}}finally{await invoke('SetImmortal',[a.id,initial]);}
 for(const id of[s.areas.values().next().value.id,0x12345678]){await invoke('SetImmortal',[id,1]);assert.equal(await invoke('GetImmortal',[id]),0);}
 assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);assert.ok(report.imports.length>1);report.validation='PASS';report.limits='Installed Prelude typed BIC/UTC imports and actual NCS getter/setter dispatch, canonical state and no ID allocation. Separate original-code oracle covers both bounded import paths and complete wrappers. Does not claim Banishment/Infestation impact completion, saves/export, natural death or campaign readiness.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(`INSTALLED IMMORTALITY IMPORT/NCS PASS (${report.imports.length} creatures)`);
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
