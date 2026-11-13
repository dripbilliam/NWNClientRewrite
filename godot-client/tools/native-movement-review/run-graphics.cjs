'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label,version,batch,variant,suffix]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^v[0-9]+$/.test(version??'')||!/^[a-z0-9-]+$/.test(batch??'')||!['control','candidate'].includes(variant)||!/^[a-z0-9-]+$/.test(suffix??''))throw Error('Explicit fresh graphical invocation required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','movement-native-review-'+label,'sparse-pending-'+version,'graphics-'+batch),file=path.join(root,variant,'private-selection.json'),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),expected=sha(fs.readFileSync(file)),run='fps-movement-'+label+'-'+version+'-'+batch+'-'+variant+'-'+suffix;
function launch(exe,args,name){const out=fs.openSync(path.join(root,run+'.'+name+'.stdout.log'),'wx'),err=fs.openSync(path.join(root,run+'.'+name+'.stderr.log'),'wx');const child=spawn(exe,args,{cwd:project,windowsHide:true,stdio:['ignore',out,err]});fs.closeSync(out);fs.closeSync(err);return new Promise(resolve=>{child.once('error',e=>resolve({exit:null,error:e.message}));child.once('close',exit=>resolve({exit}));});}
async function main(){
 const adapter=require('./replay-adapter.cjs'),selection=await adapter.readSelection(file,expected),proof=JSON.parse(fs.readFileSync(path.join(root,'driver-proof.json')));
 for(const name of ['base','driver'])if(sha(fs.readFileSync(proof[name].file))!==proof[name].sha256)throw Error('Replay driver drift');
 const args=[proof.driver.file,'--capture=C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf','--generation=2','--movement-timing','--paced','--steady-ms=10000','--production-selection='+file,'--production-selection-sha256='+expected,'--run='+run];
 fs.writeFileSync(path.join(root,run+'.invocation.json'),JSON.stringify({run,variant,args,file,sha256:expected},null,2)+'\n',{flag:'wx'});
 const processes=await Promise.all([launch(process.execPath,args,'driver'),launch('pwsh.exe',['-NoProfile','-NonInteractive','-File',path.join(__dirname,'../native-particle-loop/watch-module.ps1'),'-Run',run,'-Selection',file,'-SelectionSha256',expected],'module')]);
 const audit=require(path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/audit-case.cjs')).audit(run,{workers:false}),report=JSON.parse(fs.readFileSync(path.join(project,'reports',run+'.json')));
 const moduleFile=path.join(project,'reports',run+'.particle-module.json');let moduleProof=null;try{moduleProof=JSON.parse(fs.readFileSync(moduleFile));}catch{}
 await adapter.readSelection(file,expected);
 const result={success:processes.every(p=>p.exit===0)&&audit.success&&report.movementReviewVerification?.status==='observed'&&moduleProof?.success===true&&moduleProof.module===selection.particleLoop.module.file&&moduleProof.sha256===selection.particleLoop.module.sha256,run,variant,processes,auditFile:path.join(project,'.cache/native-presentation-parity/root/fps-max-v1',run+'.audit.json'),actualUse:report.movementReviewVerification,moduleProof,sampledFps:audit.sampledFps,steady:audit.steady,world:audit.world,screenshot:audit.screenshot,scope:'Private profile-off current-client versus planner-prototype replay. Same fidelity/authority/cleanup gates. Visual inspection and repeated-pair acceptance remain separate.'};
 fs.writeFileSync(path.join(root,run+'.result.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({...result,world:{...result.world,templates:undefined,baseScenery:undefined}}));if(!result.success)process.exitCode=1;
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
