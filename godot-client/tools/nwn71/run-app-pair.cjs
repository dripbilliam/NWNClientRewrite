'use strict';
// COORDINATOR EXECUTION ONLY. --verify-only performs source/data validation.
// Actual graphical measurements require an explicit all-worker quiet lease.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn,spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),arg=n=>process.argv.find(v=>v.startsWith('--'+n+'='))?.slice(n.length+3),planFile=path.resolve(root,arg('plan')??''),plan=JSON.parse(fs.readFileSync(planFile));
function verify(){
	for(const row of plan.immutable)assert.equal(hash(row.file),row.sha256,row.file);
	const pair=JSON.parse(fs.readFileSync(plan.pair)),staged=JSON.parse(fs.readFileSync(plan.staged)),helper=require(path.join(root,'tools/native-production-selection.cjs'));
	for(const mode of ['control','candidate'])for(const row of pair.pins[mode])assert.equal(hash(path.join(pair[mode],row.file)),row.sha256,mode+'/'+row.file);
	for(const selected of staged.selections){assert.equal(hash(selected.file),selected.sha256);const selection=JSON.parse(fs.readFileSync(selected.file));helper.validatePins(selection);helper.validatePreferencePins(selection);assert.equal(hash(selection.runtime.executable),'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');assert(!selection.flags.includes('--frame-pacing-metrics=on'));}
	return {verified:true,scope:plan.scope,selections:staged.selections.map(r=>({mode:r.mode,file:r.file,sha256:r.sha256})),noLaunches:true};
}
async function main(){
	const verified=verify();if(process.argv.includes('--verify-only')){console.log(JSON.stringify(verified));return;}
	const summary=path.join(path.dirname(planFile),'app-runs.json');assert(!fs.existsSync(summary),'Retain old run receipts');const results=[];
	for(const selected of JSON.parse(fs.readFileSync(plan.staged)).selections){
		verify();const mode=selected.mode,run=plan.outputPrefix+'-'+mode;assert(['control','candidate'].includes(mode));assert(!fs.readdirSync(path.join(root,'reports')).some(name=>name.startsWith(run+'.')),'Retain old report artifacts');
		const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture=.cache/loading-benchmark-worlds/arelith-archive-shaders-v1','--generation=4','--production-selection='+selected.file,'--production-selection-sha256='+selected.sha256,'--engine=production-selection','--profiling=false','--observe-profile=false','--steady-ms=10000','--settle-ms=5000','--preview','--run='+run];
		const log=fs.createWriteStream(path.join(path.dirname(planFile),mode+'.driver.log'),{flags:'wx'});console.log(JSON.stringify({starting:mode,run}));
		const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});let tail='',timedOut=false;
		for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>{log.write(bytes);tail=(tail+bytes.toString()).slice(-12000);});
		const timer=setTimeout(()=>{timedOut=true;if(process.platform==='win32')spawnSync('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});else child.kill();},180000);
		const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});clearTimeout(timer);await new Promise(resolve=>log.end(resolve));
		if(code!==0||timedOut){console.error(tail);throw Error(mode+' bounded graphical driver failed '+code+' timeout='+timedOut);}
		const file=path.join(root,'reports',run+'.json'),report=JSON.parse(fs.readFileSync(file));
		for(const field of ['success','sourceUnchanged','driverUnchanged','runtimeUnchanged','steadyCompleted','secondaryMonitorVerified'])assert.equal(report[field],true,mode+' '+field);
		assert.equal(report.engineOrLifetimeError,false);assert.equal(report.productionSelection.sha256,selected.sha256);assert.equal(report.productionWindowVerification.status,'observed');assert.equal(report.native.presentation_state.headless,false);
		const observerFile=path.join(root,'reports',run+'.native.nwn71-presentation.json'),observer=JSON.parse(fs.readFileSync(observerFile));
		assert.equal(observer.reason,'bounded_window_complete');assert.equal(observer.headless,false);assert.equal(observer.no_forced_draw_or_sync,true);assert(observer.rows.length>0&&observer.rows.length<=8);assert(observer.pipeline_monitors.length>0);assert(observer.visible_submissions>=3);
		for(const row of observer.rows){assert.equal(row.status,'completed');assert.equal(row.main_thread,true);assert.equal(row.world_visible,true);assert.equal(row.public_active,false);assert.equal(row.public_blocks_input,false);assert.equal(row.generation,4);assert(row.next_pre_draw_us>=row.pre_draw_us);}
		const preview=path.join(root,'reports',run+'.native.png');assert(fs.statSync(preview).size>0);verify();results.push({mode,run,success:true,report:file,reportSHA256:hash(file),observation:observerFile,observationSHA256:hash(observerFile),preview,previewSHA256:hash(preview),replayDisplay:report.replayDisplay});
		fs.writeFileSync(summary,JSON.stringify({scope:plan.scope,plan:planFile,planSHA256:hash(planFile),results},null,2)+'\n');console.log(JSON.stringify({finished:mode,run,observerRows:observer.rows.length}));
	}
	const reports=results.map(r=>JSON.parse(fs.readFileSync(r.report))),protocol=r=>crypto.createHash('sha256').update(JSON.stringify(r.native.protocol_objects)).digest('hex');assert.equal(protocol(reports[0]),protocol(reports[1]),'Final protocol bytes differ');
	assert.equal(reports[0].replayDisplay.screen,reports[1].replayDisplay.screen);assert.equal(reports[0].replayDisplay.primary,reports[1].replayDisplay.primary);
	const windows=reports.map(r=>r.native.performance_window);assert.deepEqual(windows[0].view_begin.viewport,windows[1].view_begin.viewport);assert.deepEqual(windows[0].view_begin.particle_visibility,windows[1].view_begin.particle_visibility);
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
