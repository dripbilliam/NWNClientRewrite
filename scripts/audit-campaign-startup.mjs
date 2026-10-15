// Read-only installed-module smoke. Each worker has a fresh VM, ID registry,
// resolver and complete diagnostic journal. This is not a campaign playthrough.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

const [install,output,...options]=process.argv.slice(2);
if(!install||!output)throw new Error('Usage: node scripts/audit-campaign-startup.mjs INSTALL OUTPUT_DIRECTORY [--module=Prelude] [--require-ready] [--worker]');
const selected=options.find(v=>v.startsWith('--module='))?.slice(9);
const modules=selected?[selected]:['Prelude','Chapter1','Chapter1E','Chapter2','Chapter2E','Chapter3','Chapter4'];
await fs.mkdir(output,{recursive:true});
if(!options.includes('--worker')){
  const results=[];
  for(const module of modules){
    console.log(`Auditing ${module} (fresh session, authored entry/startup scripts)`);
    const exit=await new Promise((resolve,reject)=>{
      const child=spawn(process.execPath,[fileURLToPath(import.meta.url),install,output,`--module=${module}`,'--worker'],{stdio:'inherit'});
      child.on('error',reject);child.on('exit',(code,signal)=>resolve({code,signal}));
    });
    let report;
    try{report=JSON.parse(await fs.readFile(path.join(output,`${module}.json`),'utf8'));}
    catch(error){report={module,fatal:`Worker failed to produce a report: ${error.message}`};}
    results.push({...report,workerExit:exit});
  }
  const startupReady=results.every(r=>!r.fatal&&r.workerExit.code===0&&r.errors?.length===0&&r.missingOwners?.length===0);
  const aggregate={startupReady,limits:'Initialization and 12 simulated seconds at each authored entry, using a stock fighter. Later chapters start independently; no carried quest state. No rendered/UI, full playthrough, save/load or native parity acceptance.',modules:results};
  await fs.writeFile(path.join(output,'summary.json'),JSON.stringify(aggregate,null,2)+'\n');
  console.log(JSON.stringify(results.map(r=>({module:r.module,areas:r.areas,objects:r.objects,errors:r.errors?.length,missingOwners:r.missingOwners?.length,fatal:r.fatal})),null,2));
  if(results.some(r=>r.fatal||r.workerExit.code!==0)||options.includes('--require-ready')&&!startupReady)process.exitCode=1;
}else{
  let session,phase='initialize';
  const report={module:selected,phases:[],limits:'Startup integration only; diagnostic omissions do not pass readiness.'};
  const summarize=begin=>{
    const grouped=new Map();
    for(const r of runtimeDiagnostics.records.slice(begin)){
      const key=JSON.stringify([r.code,r.message,r.context.engineCall,r.context.script]);
      const previous=grouped.get(key);
      if(previous)previous.occurrences++;
      else grouped.set(key,{code:r.code,severity:r.severity,message:r.message,context:r.context,occurrences:1});
    }
    return [...grouped.values()];
  };
  let begin=0;
  try{
    session=await new ModuleSession(await openLocalModule(install,path.join(install,'data/nwm',`${selected}.nwm`)),{
      runStartupScripts:true,runNativeAI:true,serverPvpSetting:0,
      // Capture local combat presentation rather than deliberately selecting
      // the headless default's missing presentation callback.
      onCombatMessage:message=>{report.combatMessages=(report.combatMessages??0)+1;},
    }).initialize([],{character:await fs.readFile(path.join(install,'data/lcv/fighter.bic'))});
    report.areas=session.areas.size;report.objects=session.registry.objects.size;
    report.initialQueuedEvents=session.scheduler.events.length;
    report.phases.push({phase,diagnostics:summarize(begin)});begin=runtimeDiagnostics.records.length;
    phase='startup';
    const ifo=session.ifo;
    const area=String(ifo.Mod_Entry_Area??'').toLowerCase();
    const spawn=[Number(ifo.Mod_Entry_X??0),Number(ifo.Mod_Entry_Z??0),-Number(ifo.Mod_Entry_Y??0)];
    report.entry={area,spawn,scripts:Object.fromEntries(['Mod_OnModLoad','Mod_OnModStart','Mod_OnClientEntr'].map(key=>[key,ifo[key]??'']))};
    await session.enterArea(area,spawn);
    for(let ms=0;ms<=12000;ms+=100){if(ms)session.scheduler.advance(100);await session.scheduler.pump();}
    report.phases.push({phase,diagnostics:summarize(begin)});
    report.final={area:session.currentArea?.resRef,playerId:session.player.id,hp:session.player.stats.currentHP,
      queuedEvents:session.scheduler.events.length,conversation:session.conversation.state?.resRef??null};
  }catch(error){
    report.fatal={phase,message:error.message,stack:error.stack};
    runtimeDiagnostics.error(error,'audit.campaign-failed',{module:selected,phase});
    report.phases.push({phase,diagnostics:summarize(begin)});process.exitCode=1;
  }finally{
    const all=summarize(0);
    report.errors=all.filter(r=>r.severity==='error');
    report.missingOwners=all.filter(r=>r.code.includes('unimplemented')||r.code==='engine.partial');
    report.occurrences=runtimeDiagnostics.records.length;
    // Every occurrence remains available, including failures beyond short HUD
    // buffers; the summary's grouped counts do not replace the journal.
    await fs.writeFile(path.join(output,`${selected}.jsonl`),runtimeDiagnostics.jsonl());
    await fs.writeFile(path.join(output,`${selected}.json`),JSON.stringify(report,null,2)+'\n');
    console.log(JSON.stringify({module:selected,areas:report.areas,errors:report.errors.length,missingOwners:report.missingOwners.length,fatal:report.fatal?.message}));
  }
}
