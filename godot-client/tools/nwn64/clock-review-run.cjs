'use strict';
// Untimed original-scene census. Each copied driver uses only its private reader.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label='clock-review-pair-a',runPrefix='nwn64-clock-scene-a',only='both',displayMode='headless',generationText='4']=process.argv.slice(2),generation=Number(generationText);assert(/^clock-review-[a-z0-9-]+$/.test(label)&&/^[a-z0-9][a-z0-9-]{0,59}$/.test(runPrefix)&&['both','accepted-control','clock-d-native'].includes(only)&&['headless','visual'].includes(displayMode)&&Number.isSafeInteger(generation)&&generation>=1&&generation<=16&&String(generation)===generationText);
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
(async()=>{
 const directory=path.join(project,'.cache/nwn64',label),stagedFile=path.join(directory,'staged.json'),staged=JSON.parse(fs.readFileSync(stagedFile)),output=path.join(directory,runPrefix+'-runs.json');assert(!fs.existsSync(output));assert.equal(sha(staged.proposal),staged.proposalSHA256);const proposal=JSON.parse(fs.readFileSync(staged.proposal)),results=[];
 for(const selected of staged.selections){if(only!=='both'&&selected.mode!==only)continue;assert.equal(sha(selected.file),selected.sha256);assert(selected.private&&selected.production===false&&selected.accepted===false&&selected.profiling==='false');
  const view=proposal.views.find(row=>row.mode===selected.mode);assert(view?.driverClosure);require('./clock-review-driver-closure.cjs').verifyClosure(view.project,view.driverClosure);
  const driverRoot=path.resolve(path.dirname(selected.driver),'..'),run=runPrefix+'-'+selected.mode,reportFile=path.join(driverRoot,'reports',run+'.json');assert(!fs.existsSync(reportFile));
  fs.mkdirSync(path.join(driverRoot,'reports'),{recursive:true});
  const args=[selected.driver,'--capture='+staged.capture,'--generation='+generation,'--production-selection='+selected.file,'--production-selection-sha256='+selected.sha256,'--engine=production-selection','--profiling=false','--observe-profile=false','--run='+run];
  if(displayMode==='headless')args.push('--headless','--duration-ms=20000');else args.push('--preview','--steady-ms=10000','--settle-ms=5000');
  const log=fs.createWriteStream(path.join(directory,run+'.driver.log'),{flags:'wx'});console.log(JSON.stringify({starting:selected.mode,run,private:true,production:false,selection:selected.sha256}));
  const child=spawn(process.execPath,args,{cwd:driverRoot,windowsHide:true,stdio:['ignore','pipe','pipe']});let tail='';for(const stream of[child.stdout,child.stderr])stream.on('data',bytes=>{log.write(bytes);tail=(tail+bytes.toString()).slice(-12000);});
  const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});await new Promise(resolve=>log.end(resolve));if(code!==0){console.error(tail);throw Error('Private census driver failed '+code);}
  const report=JSON.parse(fs.readFileSync(reportFile));assert(report.success&&report.profilingRequested===false&&!report.engineOrLifetimeError&&report.sourceUnchanged&&report.driverUnchanged&&report.runtimeUnchanged&&report.exit===0,'Strict private replay failed');
  require('./clock-review-driver-closure.cjs').verifyClosure(view.project,view.driverClosure);
  const census=report.native.private_clock_review;assert(census?.private&&census.accepted===false&&census.members>0&&census.fast_members>0&&census.clock_info&&!census.clock_info.error,'Actual shared presenter census missing');
  assert.equal(census.clock_read_native,selected.mode==='clock-d-native');
  const result={mode:selected.mode,report:reportFile,sha256:sha(reportFile),success:true,measurement:report.measurement,census,visibility:report.lastObservation.particle_visibility,particles:Object.fromEntries(Object.entries(report.native.world.native_particles).filter(([k,v])=>v===null||typeof v!=='object')),normalEnvironment:selected.environment,private:true,accepted:false,production:false};
  results.push(result);fs.writeFileSync(output,JSON.stringify({issue:'NWN-64',private:true,accepted:false,production:false,displayMode,generation,stagedFile,stagedSHA256:sha(stagedFile),results,scope:'Original particles-enabled generation'+generation+' actual shared-presenter clock-info census. Normal CoreE/core16/shared+pooled configuration; descriptor-declared private DLL and native-read selector only. '+(displayMode==='headless'?'Headless functional/binding evidence, no FPS or timing gain claim.':'Private graphical comparison; root separately evaluates matched steady windows/parity before any performance or promotion claim.')},null,2)+'\n');
  console.log(JSON.stringify({finished:selected.mode,success:true,census,report:reportFile}));
 }
 for(const pin of staged.globals)assert.equal(sha(path.join(project,pin.relative)),pin.sha256,'Global accepted selector/artifact changed');
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
