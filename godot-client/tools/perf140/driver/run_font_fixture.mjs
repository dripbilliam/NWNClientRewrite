import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {hash} from './stage_library.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [label,mode,role]=process.argv.slice(2);
if(!/^native-perf140-font-upload-[a-z0-9-]+$/.test(label??'')||!['safe','separate'].includes(mode)||!['baseline','candidate'].includes(role))throw Error('Fresh label, thread mode and explicit engine role required');
const manifestFile=path.join(project,'.cache/native-140fps/render-agent/font-atlas-check-v4/manifest.json');
const manifestSha256='4ab8084ee9466071d7209259c0ee0372081d89d12bfd116a683462fcbc5b39e9';
if(hash(fs.readFileSync(manifestFile))!==manifestSha256)throw Error('Frozen fixture manifest differs');
const manifest=JSON.parse(fs.readFileSync(manifestFile));
function sourceDrift(){return manifest.pins.filter(p=>hash(fs.readFileSync(path.join(manifest.project,p.relative)))!==p.sha256).map(p=>p.relative);}
if(sourceDrift().length)throw Error('Frozen fixture source differs');
if(hash(fs.readFileSync(manifest.descriptorFile))!==manifest.descriptorSha256)throw Error('Engine descriptor differs');
const descriptor=JSON.parse(fs.readFileSync(manifest.descriptorFile));
const engine=descriptor.engines[role];
function engineValid(){return hash(fs.readFileSync(engine.path))===engine.sha256&&hash(fs.readFileSync(engine.buildReceipt))===engine.buildReceiptSha256&&hash(fs.readFileSync(engine.invocation))===engine.invocationSha256;}
if(!engineValid())throw Error('Private engine proof differs');
const folder=path.join(project,'.cache/native-140fps/root',label),report=path.join(project,'reports',label+'.json');
if(fs.existsSync(folder)||fs.existsSync(report))throw Error('Existing evidence preserved');
const helper=path.join(project,'tools/native-window-screen.ps1');
const screen=await new Promise((resolve,reject)=>{
  const child=spawn('pwsh.exe',['-NoProfile','-Command',`. '${helper.replaceAll("'","''")}'; Get-NativeSecondaryScreen`],{windowsHide:true,stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='';child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);child.once('error',reject);child.once('close',code=>code===0?resolve(Number(stdout.trim())):reject(Error(stderr)));
});
if(!Number.isInteger(screen)||screen<0)throw Error('Secondary monitor required');
fs.mkdirSync(folder);const app=path.join(folder,'appdata'),local=path.join(folder,'localappdata');fs.mkdirSync(app);fs.mkdirSync(local);
const log=path.join(folder,'engine.log');
const args=['--path',manifest.project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread',mode,'--screen',String(screen),'--resolution','320x240','--log-file',log,'--script',manifest.entry,'--','--report='+report];
const outcome=await new Promise(resolve=>{
  const child=spawn(engine.path,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:app,LOCALAPPDATA:local}});
  let stdout='',stderr='',error=null;child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);child.once('error',e=>error=e.message);
  const timer=setTimeout(()=>{error='Owned font fixture deadline';child.kill();},60000);
  child.once('close',(code,signal)=>{clearTimeout(timer);resolve({pid:child.pid,code,signal,error,stdout,stderr});});
});
fs.writeFileSync(path.join(folder,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(folder,'stderr.log'),outcome.stderr);
let proof=null;try{proof=JSON.parse(fs.readFileSync(report));}catch{}
const logs=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+outcome.stderr;
const clean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use/m.test(logs),changed=sourceDrift();
const runtimeMatched=proof?.main_on_render_thread===(mode==='safe')&&proof?.gated_separate_render_thread===(mode==='separate')&&proof?.rendering_method==='forward_plus'&&proof?.rendering_driver==='vulkan';
const completed=!outcome.signal&&!outcome.error&&clean&&!changed.length&&engineValid()&&runtimeMatched&&!!proof;
const expectedNegative=role==='baseline'&&mode==='separate';
const reproducedNegative=expectedNegative&&completed&&outcome.code===1&&proof.success===false&&proof.failures.some(x=>x.includes('exact published atlas bytes'));
const positivePass=!expectedNegative&&completed&&outcome.code===0&&proof.success===true;
const receipt={success:positivePass||reproducedNegative,positivePass,expectedNegative,reproducedNegative,completed,clean,changed,runtimeMatched,proof,manifestFile,manifestSha256,descriptorSha256:manifest.descriptorSha256,engineSha256:engine.sha256,requestedScreen:screen,requestedMode:mode,role,outcome:{...outcome,stdout:undefined,stderr:undefined},scope:'Offline actual font atlas dirty-upload pixels and ownership only; no FPS or production-error causation claim'};
fs.writeFileSync(path.join(folder,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:receipt.success,positivePass,reproducedNegative,clean,checks:proof?.checks,failures:proof?.failures,folder}));
if(!receipt.success)process.exitCode=1;
