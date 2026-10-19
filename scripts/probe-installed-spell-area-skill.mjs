import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {nativeMessageField} from '../src/area_message_metadata.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-spell-area-skill-v1.json',report={areas:[],skills:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'spell_query_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0].value;};
 for(const area of s.areas.values()){
  const above=await invoke('GetIsAreaAboveGround',[area.id]),interior=await invoke('GetIsAreaInterior',[area.id]);assert.equal(above,((~area.flags)>>>1)&1);assert.equal(interior,Number((area.flags&3)!==0));report.areas.push({id:area.id,resRef:area.resRef,flags:area.flags,above,interior});
 }
 const area=s.areas.values().next().value,old=area.flags;report.liveFlags=[];
 try{for(const flags of[0,1,2,3,0x80000002]){area.flags=flags;assert.equal(nativeMessageField(area,8),flags);const above=await invoke('GetIsAreaAboveGround',[area.id]),interior=await invoke('GetIsAreaInterior',[area.id]);assert.equal(above,((~flags)>>>1)&1);assert.equal(interior,Number((flags&3)!==0));report.liveFlags.push({flags,above,interior});}}finally{area.flags=old;}
 for(const id of[s.player.id,0x12345678]){assert.equal(await invoke('GetIsAreaAboveGround',[id]),-1);assert.equal(await invoke('GetIsAreaInterior',[id]),0);}
 for(const skill of[0,1,2,3,100,101,102,255,256,-1]){
  const expected=await s.combat.canUseSkill(s.player,skill&255),result=await invoke('GetHasSkill',[skill,s.player.id]);assert.equal(result,Number(expected===1));assert.equal(await invoke('GetHasSkill',[skill,area.id]),0);assert.equal(await invoke('GetHasSkill',[skill,0x12345678]),0);report.skills.push({skill,narrowed:skill&255,result});
 }
 assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Real parsed NCS area/skill queries over installed canonical areas/PC and active class/skill rules. Live area flags share protocol aliases; no area fallback for creature IDs; no registry allocation. Skill dispatch is compared to the existing native-tested lower; independent wrapper semantics have their separate original-code oracle. No authored mount/Deck/Clone Fist spell completion claim.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED NCS AREA FLAGS, LIVE ALIASES AND DATA-DRIVEN SKILL ELIGIBILITY PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
