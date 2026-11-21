'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{spawn}=require('child_process');
const project=path.resolve(__dirname,'../..'),[label,suffix,steadyArg,...unsupported]=process.argv.slice(2);
if(unsupported.length||(steadyArg&&!/^--steady-ms=(10000|45000)$/.test(steadyArg)))throw Error('Only explicit 10s/45s steady window supported');
const steadyMs=steadyArg?.slice('--steady-ms='.length)??'10000';
if(!/^[a-z0-9-]+$/.test(label??'')||!/^[a-z0-9-]+$/.test(suffix??''))throw Error('Explicit fresh replay label/suffix required');
const root=path.join(project,'.cache/native-render-gap/replays',label),proof=JSON.parse(fs.readFileSync(path.join(root,'preparation.json'))),run='render-gap-'+label+'-'+suffix;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function launch(executable,args,name){
 const out=fs.openSync(path.join(root,run+'.'+name+'.stdout.log'),'wx'),err=fs.openSync(path.join(root,run+'.'+name+'.stderr.log'),'wx');
 const child=spawn(executable,args,{cwd:project,windowsHide:true,stdio:['ignore',out,err]});fs.closeSync(out);fs.closeSync(err);
 return new Promise(resolve=>{child.once('error',e=>resolve({exit:null,error:e.message}));child.once('close',exit=>resolve({exit}));});
}
async function main(){
 for(const name of ['base','driver','selection',...(proof.adapter?['adapter']:[])])if(sha(fs.readFileSync(proof[name].file))!==proof[name].sha256)throw Error('Replay preparation drift '+name);
 const adapter=require(proof.adapter?.file??'./replay-adapter.cjs');
 const selection=await adapter.readSelection(proof.selection.file,proof.selection.sha256);
 if(selection.renderGap.trainingOnly===true)throw Error('Instrumented PGO training cannot enter the FPS runner');
 const args=[proof.driver.file,'--capture=C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf','--generation=2','--movement-timing','--paced','--steady-ms='+steadyMs,'--production-selection='+proof.selection.file,'--production-selection-sha256='+proof.selection.sha256,'--run='+run,...(proof.profile?['--observe-profile=true']:[])];
 fs.writeFileSync(path.join(root,run+'.invocation.json'),JSON.stringify({run,args,variant:proof.variant,selection:proof.selection},null,2)+'\n',{flag:'wx'});
 const watcher=path.join(__dirname,'watch-module-v3.ps1');
 fs.writeFileSync(path.join(root,run+'.module-observer.json'),JSON.stringify({file:watcher,sha256:sha(fs.readFileSync(watcher))},null,2)+'\n',{flag:'wx'});
 const processes=await Promise.all([launch(process.execPath,args,'driver'),launch('pwsh.exe',['-NoProfile','-NonInteractive','-File',watcher,'-Run',run,'-Selection',proof.selection.file,'-SelectionSha256',proof.selection.sha256],'module')]);
 const report=JSON.parse(fs.readFileSync(path.join(project,'reports',run+'.json')));
 const audit=require(path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/audit-case.cjs')).audit(run,{workers:false,profile:proof.profile});
 let moduleProof=null;try{moduleProof=JSON.parse(fs.readFileSync(path.join(project,'reports',run+'.particle-module.json')));}catch{}
 await adapter.readSelection(proof.selection.file,proof.selection.sha256);
 const result={success:processes.every(p=>p.exit===0)&&audit.success&&report.renderGapVerification?.status==='observed'&&moduleProof?.success===true&&moduleProof.module===selection.particleLoop.module.file&&moduleProof.sha256===selection.particleLoop.module.sha256,run,variant:proof.variant,processes,auditFile:path.join(project,'.cache/native-presentation-parity/root/fps-max-v1',run+'.audit.json'),actualUse:report.renderGapVerification,moduleProof,sampledFps:audit.sampledFps,steady:audit.steady,world:audit.world,screenshot:audit.screenshot,scope:proof.profile?'Diagnostic attribution only; not profile-off FPS acceptance':'Profile-off matched replay; bounded visual inspection/repeated-pair acceptance remain separate'};
 fs.writeFileSync(path.join(root,run+'.result.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({...result,world:{...result.world,templates:undefined,baseScenery:undefined}}));if(!result.success)process.exitCode=1;
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
