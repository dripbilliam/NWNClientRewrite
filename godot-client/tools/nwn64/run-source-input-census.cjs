'use strict';
// One bounded headless original-scene census. No GUI, FPS or native build.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),directory=path.join(root,'.cache/nwn64/source-input-b');
const stagedFile=path.join(directory,'staged.json'),staged=JSON.parse(fs.readFileSync(stagedFile));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run='nwn64-source-input-g4-b',reportFile=path.join(staged.project,'reports',run+'.json');
async function main(){
 assert(staged.private&&staged.accepted===false&&staged.production===false);
 assert(!fs.existsSync(reportFile));
 fs.mkdirSync(path.dirname(reportFile),{recursive:true});
 assert.equal(sha(staged.selection),staged.selectionSha256);
 for(const pin of staged.pins)assert.equal(sha(path.join(staged.project,pin.relative)),pin.sha256,'Private source changed '+pin.relative);
 const args=[staged.driver,'--capture='+staged.capture,'--generation=4','--production-selection='+staged.selection,'--production-selection-sha256='+staged.selectionSha256,'--engine=production-selection','--profiling=false','--observe-profile=false','--headless','--duration-ms=20000','--run='+run];
 const log=fs.createWriteStream(path.join(directory,run+'.driver.log'),{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:staged.project,windowsHide:true,stdio:['ignore','pipe','pipe']});
 let tail='';for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>{log.write(bytes);tail=(tail+bytes.toString()).slice(-8000);});
 const exit=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});await new Promise(resolve=>log.end(resolve));
 if(exit!==0)throw Error('Private replay failed '+exit+'\n'+tail);
 const report=JSON.parse(fs.readFileSync(reportFile));
 assert(report.success&&!report.engineOrLifetimeError&&report.sourceUnchanged&&report.driverUnchanged&&report.runtimeUnchanged&&report.exit===0,'Strict original replay failed');
 assert.equal(report.profilingRequested,false);
 const census=report.native?.private_source_input_census;
 assert(census?.success&&census.shared_members===919&&census.fast_members===919&&census.registered===919,'Original 919-source census absent '+JSON.stringify(census));
 assert.equal(sha(staged.selection),staged.selectionSha256);
 for(const pin of staged.pins)assert.equal(sha(path.join(staged.project,pin.relative)),pin.sha256,'Private source changed after run '+pin.relative);
 const output={issue:'NWN-64',private:true,accepted:false,production:false,source:stagedFile,sourceSha256:sha(stagedFile),report:reportFile,reportSha256:sha(reportFile),census,scope:'Actual generation4 original particles-enabled shared-presenter final-world identity/count census, headless profile-OFF. No timing/FPS, no callback-safe cache proof, no state or clock advance from the cold helper.'};
 const file=path.join(directory,'review.json');fs.writeFileSync(file,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),report:reportFile,census}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
