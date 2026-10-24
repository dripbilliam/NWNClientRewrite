// Offline authored fixture validation. This is a typed bytecode/ABI check, not
// an original-server or client compatibility claim. No socket or renderer used.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {NwScriptVm} from '../../src/nwscript_vm.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const name=process.argv.find(v=>v.startsWith('--module='))?.slice(9)??'GodotNui2';
const reportName=process.argv.find(v=>v.startsWith('--report='))?.slice(9);
if(!/^GodotNui[0-9]*$/.test(name)||!/^[a-z0-9-]+\.json$/.test(reportName??''))throw Error('Provide an authored module and unused report');
const context=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
const api=parseScriptApi(decodeResourceText(await context.getResource('nwscript',2009)));
const archive=parseErf(await fs.readFile(path.resolve('runtime-logs/local-multiplayer-server/modules',name+'.mod')));
const program=parseNcs(archive.entries.get('godot_nui:2010'),'authored_nui');
const targetProgram=parseNcs(archive.entries.get('godot_target:2010'),'authored_nui_target');
const locals=new Map();
const windows=new Map([['root',1]]),binds=new Map(),watch=new Set(),calls=[];
let type='open',element='_window_',index=-1,token=1;
const handlers={
 WriteTimestampedLogEntry:([text])=>calls.push({type:'trace',text}),
 JsonInt:([value])=>value,JsonParse:([s])=>JSON.parse(s),
 GetLastPlayerToSelectTarget:()=>42,GetTargetingModeSelectedObject:()=>42,
 SetLocalInt:([p,k,v])=>locals.set(p+'/'+k,v),GetLocalInt:([p,k])=>locals.get(p+'/'+k)??0,
 SetLocalObject:([p,k,v])=>locals.set(p+'/'+k,v),GetLocalObject:([p,k],frame)=>locals.get((p===0?frame.self:p)+'/'+k),
 AssignCommand:async([p,action])=>{assert.equal(p,42);const result=await vm.run(action.program,p,{situation:action});assert.deepEqual(result.stack,[]);},
 ActionCastSpellAtObject:args=>{assert.deepEqual(args,[100,42,0,0,0,0,0,10,0]);calls.push({type:'cast',spell:100,target:42,cheat:false});},NuiGetEventType:()=>type,NuiGetEventPlayer:()=>42,NuiGetEventWindow:()=>token,NuiGetEventElement:()=>element,NuiGetEventArrayIndex:()=>index,
 NuiFindWindow:([p,id])=>{assert.equal(p,42);return windows.get(id)??0;},
 SendMessageToPC:([p,text])=>{assert.equal(p,42);calls.push({type:'message',text});},
 NuiSetBind:([p,t,k,v])=>{assert.equal(p,42);assert.equal(t,token);binds.set(k,structuredClone(v));calls.push({type:'bind',name:k});},
 NuiGetBind:([p,t,k])=>{assert.equal(p,42);assert.equal(t,token);return structuredClone(binds.get(k)??null);},
 NuiSetBindWatch:([p,t,k,b])=>{assert.equal(p,42);assert.equal(t,token);assert.equal(b,1);watch.add(k);return 1;},
 NuiCreate:([p,layout,id,script])=>{assert.equal(p,42);assert.equal(script,'godot_nui');assert.ok(layout.root);const value=windows.size+1;windows.set(id,value);calls.push({type:'create',id,layout});return value;},
 NuiCreateFromResRef:([p,resref,id,script])=>{assert.equal(p,42);assert.equal(script,'godot_nui');assert.ok(archive.entries.has(resref+':2083'));windows.set(id,windows.size+1);calls.push({type:'resource-create',id});return windows.size;},
 NuiSetGroupLayout:([p,t,id,layout])=>{assert.equal(p,42);assert.equal(t,token);assert.equal(id,'replace');assert.equal(layout.id,'replaced');calls.push({type:'group',id});},
 EnterTargetingMode:([p,types,cursor,bad])=>{assert.equal(p,42);assert.deepEqual([types,cursor,bad],[32767,29,31]);calls.push({type:'target'});},
 NuiDestroy:([p,t])=>{assert.equal(p,42);for(const[k,v]of windows)if(v===t)windows.delete(k);calls.push({type:'destroy',token:t});}
};
const vm=new NwScriptVm({api,command:n=>handlers[n],diagnostics:{error:e=>calls.push({type:'error',message:e.message})}});
async function run(t,e='_window_',i=-1){type=t;element=e;index=i;const result=await vm.run(program,42);assert.deepEqual(result.stack,[]);return result;}
const report={scope:'Offline typed execution of authored local NUI fixture only; no native compatibility acceptance',module:name,checks:[],passed:false};
const check=(value,name)=>{assert.ok(value,name);report.checks.push(name);};
try{
 check([...program.instructions.values()].filter(v=>v.op===4&&v.type===5).every(v=>v.value.length<=16000),'Authored constant strings stay within the tested native literal bound');
 await run('open');check(binds.get('count')===2000&&binds.get('names')?.length===2000&&binds.get('checks')?.length===2000,'All two thousand authored list rows initialize');
 check(watch.size===13,'All expected native bind watches register');
 binds.set('name','Native watched edit');await run('watch','name');check(binds.get('echo_name')==='Native watched edit'&&binds.get('echo')==='Native watched edit','Server echo callback reads canonical values');
 await run('click','next');check(windows.has('child')&&windows.has('toolbar'),'Click creates independent child and toolbar');
 await run('click','third');check(windows.has('grandchild'),'Resource-backed nested callback has valid ABI');
 await run('click','row',1999);check(calls.some(v=>v.type==='group'),'Indexed row callback reaches group replacement');
 await run('click','target');check(calls.some(v=>v.type==='target'),'Script targeting uses native API argument order');
 await vm.run(targetProgram,42);check(binds.get('target_ack')==='Native target selection accepted','Actual callback bytecode identifies the selected player');
 await run('click','toolbar_0');await vm.run(targetProgram,42);check(calls.some(v=>v.type==='cast'&&v.cheat===false),'Toolbar callback assigns the normal Light cast using all nine typed arguments');
 await run('click','image_button');check(calls.some(v=>v.type==='destroy')&&windows.has('toolbar'),'Toolbar token can retire and recreate');
 report.passed=true;
}catch(error){report.failure=error.message;throw error;}
finally{report.calls=calls.map(({layout,...row})=>row);await fs.writeFile(path.resolve('godot-client/reports',reportName),JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failure:report.failure}));}
