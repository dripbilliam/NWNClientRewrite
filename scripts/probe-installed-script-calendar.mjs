import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-script-calendar-v1.json',report={queries:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};const start=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async(command)=>{const spec=s.vm.api[command];assert.equal(spec.name,{13:'GetCalendarYear',14:'GetCalendarMonth',15:'GetCalendarDay'}[command]);assert.equal(spec.args.length,0);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,0,command,0,0x20,0],13);const result=await s.vm.run(parseNcs(ncs,'calendar_runtime_'+spec.name),s.player.id);assert.equal(result.stack.length,1);assert.equal(result.stack[0].type,3);return result.stack[0].value;};
 report.moduleClock={day:s.worldTimer.time().day,calendar:[],startYear:s.ifo.Mod_StartYear,startMonth:s.ifo.Mod_StartMonth,startDay:s.ifo.Mod_StartDay};
 for(const command of[13,14,15])report.moduleClock.calendar.push(await invoke(command));assert.deepEqual(report.moduleClock.calendar,[s.ifo.Mod_StartYear,s.ifo.Mod_StartMonth,s.ifo.Mod_StartDay]);
 const oracle=JSON.parse(await fs.readFile('backups/animations/native-script-calendar-observations.json','utf8')),all=oracle.rows.filter(r=>r.case.push===1&&r.case.command===13),selected=[...all.filter(r=>r.case.paused===1&&[0,28,335,32767*336+335,32768*336,0xffffffff].includes(r.case.pausedDay)&&r.case.counter==='0'),...all.filter(r=>r.case.timeOffset===0xffffffff).slice(0,4),all.at(-1)];
 for(const state of selected){const c=state.case,timer=s.worldTimer;for(const name of['dayOffset','timeOffset','dayLength','paused','pausedDay'])timer[name]=c[name];timer.counter=BigInt(c.counter);const actual=[];
  for(const command of[13,14,15]){const expected=oracle.rows.find(r=>r.case.command===command&&r.case.push===1&&Object.keys(c).filter(k=>k!=='command').every(key=>r.case[key]===c[key]));assert.ok(expected);const result=await invoke(command);assert.equal(result,expected.output);actual.push(result);}
  report.queries.push({state:c,calendar:actual});
 }
 assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'||r.severity==='warning'),[]);report.validation='PASS';report.limits='Installed Prelude/cleric, module-authored date, actual parsed NCS commands13/14/15 and canonical IDs. Replays live paused/unsigned/offset/year-fallback timer states from independent original-code observations. No mount/summon full-script or saved-calendar acceptance claim.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,queries:report.queries.length,moduleClock:report.moduleClock,error:report.error}));
