'use strict';
const fs=require('fs'),path=require('path'),{spawn}=require('child_process');
const project=path.resolve(__dirname,'../..'),[queue,...cases]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(queue??'')||!cases.length||cases.some(x=>!/^[-a-z0-9]+:[-a-z0-9]+$/.test(x)))throw Error('Fresh queue and stage:suffix pairs required');
const dir=path.join(project,'.cache/native-render-gap/queues',queue);if(fs.existsSync(dir))throw Error('Existing queue preserved');fs.mkdirSync(dir,{recursive:true});
const rows=[];
async function main(){
 for(const item of cases){
  const [label,suffix]=item.split(':'),started=new Date().toISOString();
  const out=fs.openSync(path.join(dir,label+'-'+suffix+'.stdout.log'),'wx'),err=fs.openSync(path.join(dir,label+'-'+suffix+'.stderr.log'),'wx');
  const child=spawn(process.execPath,[path.join(__dirname,'scene/normal-integration-c/run-replay.cjs'),label,suffix],{cwd:path.dirname(project),windowsHide:true,stdio:['ignore',out,err]});fs.closeSync(out);fs.closeSync(err);
  const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});
  const row={label,suffix,started,finished:new Date().toISOString(),exit};rows.push(row);
  fs.writeFileSync(path.join(dir,'progress.json'),JSON.stringify({sequential:true,rows},null,2)+'\n');
  console.log(JSON.stringify(row));
  // Each wrapper waits for its driver and module watcher, then checks child
  // exit, log closure, finish acknowledgment and workers. Never overlap runs.
  if(exit!==0)throw Error('Queue stopped after rejected run '+label+':'+suffix);
 }
 fs.writeFileSync(path.join(dir,'receipt.json'),JSON.stringify({success:true,sequential:true,rows},null,2)+'\n');
}
main().catch(e=>{fs.writeFileSync(path.join(dir,'failure.json'),JSON.stringify({success:false,error:e.stack,rows},null,2)+'\n');console.error(e.stack);process.exitCode=1;});
