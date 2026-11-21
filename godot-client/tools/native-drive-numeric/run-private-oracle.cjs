'use strict';
// Headless frozen correctness only. No graphical client, replay, server or FPS.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const {readPrivateStage}=require('./prepare-private-stage.cjs');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function runPrivateOracle({file,sha256,output,script='native_oracle.gd'}){
 if(!['native_oracle.gd','owner_oracle.gd','cpu_microcomparison.gd'].includes(script))throw Error('Unsupported private correctness script');
 const selection=readPrivateStage(file,sha256);
 if(fs.existsSync(output))throw Error('Prior oracle evidence preserved');fs.mkdirSync(output,{recursive:true});
 const report=path.join(output,'report.json'),log=path.join(output,'engine.log');
 const args=['--headless','--path',selection.sourceProject,'--log-file',log,'--script','res://tools/native-drive-numeric/'+script,'--','--report='+report];
 if(selection.sidecar)args.push('--expect-module='+selection.expectedModule.file,'--expect-module-sha256='+selection.expectedModule.sha256);else args.push('--expect-absent');
 const child=spawnSync(selection.engine.executable,args,{cwd:selection.sourceProject,windowsHide:true,timeout:60000,encoding:'utf8',maxBuffer:4*1024*1024});
 fs.writeFileSync(path.join(output,'stdout.log'),child.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(output,'stderr.log'),child.stderr??'',{flag:'wx'});
 const text=[child.stdout,child.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR|(?:^|\s)ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|CrashHandler|Unhandled exception/.test(line));
 let value=null;try{value=JSON.parse(fs.readFileSync(report,'utf8'));}catch{}
 readPrivateStage(file,sha256);
 const identity=require(path.join(selection.originalProject,'tools/native-feature-manifest.cjs')).sourceIdentity;
 const unchanged=identity(selection.originalProject).sha256===selection.mainSource;
 const result={version:1,success:child.status===0&&!child.error&&errors.length===0&&value?.success===true&&unchanged,exit:child.status,error:child.error?.message??null,errors,unchanged,stage:{file,sha256},reportSha256:value?hash(report):null,checks:value?.checks,failures:value?.failures,nativePresent:value?.native_present,scope:script==='cpu_microcomparison.gd'?'Bounded private headless CPU microcomparison only. No FPS, live-stall acceptance or normal-client installation.':'Private actual-engine numeric frozen correctness only. No FPS/performance result or normal-client installation.'};
 fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
module.exports={runPrivateOracle};
if(require.main===module){const [file,sha256,output]=process.argv.slice(2);const result=runPrivateOracle({file,sha256,output});console.log(JSON.stringify(result));process.exitCode=result.success?0:1;}
