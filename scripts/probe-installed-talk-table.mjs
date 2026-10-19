import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {decodeGffText} from '../src/gff_text.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-talk-table-v1.json',report={queries:[]};
try{
 const directory=path.join(install,'lang/en/data'),files=(await fs.readdir(directory)).filter(n=>/\.tlk$/i.test(n)).map(name=>({name,arrayBuffer:()=>fs.readFile(path.join(directory,name))}));
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{talkFiles:files,runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async args=>{const ordinal=s.vm.api.findIndex(r=>r.name==='GetStringByStrRef');assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'talk_table_probe'),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0].value;};
 const base=s.talkTable.base[0];assert.ok(base);let tested=0;
 // Compare actual installed entries at their file offsets, recording only
 // lengths/hashes/flags. No proprietary TLK strings are exported.
 for(const ref of[0,1,36,342,4848,7471,12345,84543,base.count1c-1]){const at=20+ref*40;if(ref>=base.count1c)continue;const view=new DataView(base.bytes.buffer,base.bytes.byteOffset,base.bytes.byteLength),flags=view.getUint32(at,true),offset=base.textOffset20+view.getUint32(at+28,true),length=view.getUint32(at+32,true),raw=flags&1?base.bytes.subarray(offset,offset+length):new Uint8Array(),expected=raw[0]===0?'':decodeGffText(raw);
  for(const gender of[0,1,2]){const args=gender===2?[ref]:[ref,gender],result=await invoke(args);assert.equal(result,expected);report.queries.push({ref,requestedGender:args[1]??0,length:result.length,sha256:createHash('sha256').update(result).digest('hex'),flags});tested++;}
 }
 assert.ok(tested>12);assert.equal(await invoke([0xffffffff,1]),'');assert.equal(s.talkTable.state.gender,1);assert.equal(await invoke([0x1000000]),'BadStrRef(16777216)');assert.equal(s.registry.nextObjectId[0],cursor);report.baseCount=base.count1c;report.femaleAliasesMale=s.talkTable.base[1]===base;report.cacheEntries=base.cache.size;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed English TLK text bytes, live native record cache and real parsed NCS dispatch. Complete original fetch/getter oracle is separate. No override ParseStr, full OpenFile resource/disk resolver, localized script presentation or whole client speech completion claim.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(`INSTALLED GETSTRINGBYSTRREF/TLK CACHE PASS (${tested} queries)`);
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
