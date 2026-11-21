'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawn,execFile}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'.cache/nwn62/packed-staged-a'),sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const engine=path.join(root,'.cache/nwn62/engine-shader-list-clean-e/candidate-probe/godot.windows.template_release.x86_64.exe'),report=path.join(out,'semantics-c.json'),log=path.join(out,'semantics-c.engine.log');
const pins={
 'systems/native_render/model_template.gd':'d17234ee13b8c8661a30ae86e7b57907fdf5e53cb4744937bc712c9e7bd63ac4',
 '.cache/nwn62/packed-staged-a/before/model_template.gd':'87de0c6a3ea8a5add6b213118107ea8092d2dddb28be3c0378a3af7c980ecad9',
 'systems/native_render/native_model_recipe.gd':'9a4d5f0bbf9bcb7868ad7a1b4bfb68c2179f32a0c29a77be3ce620ead62dfff2',
 'systems/native_data/asset_service.gd':'8636e25a90cdf06b9811328f1c5ac232afc7fb1ce6798b4a199804384c02ed6e',
 'systems/native_render/resource_pool.gd':'cb702ea11b45251078de8fa1b8cfd16a486f2dac030aabdd750a33a21e1f39b2',
 'tools/nwn62/packed-staged-semantics.gd':'cd4f12689a95abaa1b307af3f75e6203263c51bf24507d0cdb9c0dde12dc7dbb',
 '.cache/nwn62/engine-shader-list-clean-e/candidate-probe/godot.windows.template_release.x86_64.exe':'f8503d26e5f49fb2af1272dda13b2fbd0fdcd556ede28c36376521fddbb13e96'};
for(const [file,expected] of Object.entries(pins))assert.equal(sha(path.join(root,file)),expected,'Pinned input changed: '+file);
const args=['--headless','--path',root,'--script','res://tools/nwn62/packed-staged-semantics.gd','--log-file',log,'--','--model-template=packed-staged','--report='+report];
if(process.argv.includes('--verify-only')){console.log(JSON.stringify({verified:true,engine,engineSha256:sha(engine),args,sourcePins:pins,limitMs:180000,limitBytes:8*1024**3},null,2));process.exit(0);}
assert(!fs.existsSync(report)&&!fs.existsSync(log),'Fresh report/log required');
const child=spawn(engine,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']}),chunks=[];for(const s of [child.stdout,child.stderr])s.on('data',b=>chunks.push(b));
let peak=0,halt=null,checking=false;const begun=Date.now();const stop=why=>{if(halt)return;halt=why;execFile('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true},()=>{});};
const timer=setInterval(()=>{if(Date.now()-begun>180000)return stop('180-second timeout');if(checking)return;checking=true;execFile('pwsh',['-NoProfile','-Command',`$p=Get-Process -Id ${child.pid} -ErrorAction SilentlyContinue; if($p){[long]$p.PrivateMemorySize64}else{0}`],{windowsHide:true,timeout:5000},(err,stdout)=>{checking=false;if(err)return stop('Memory guard unavailable: '+err.message);const n=Number(stdout.trim())||0;peak=Math.max(peak,n);if(n>8*1024**3)stop('8 GiB private-memory limit');});},2000);
child.once('error',e=>{console.error(e);process.exitCode=1;});child.once('exit',code=>{clearInterval(timer);const output=Buffer.concat(chunks).toString();fs.writeFileSync(path.join(out,'semantics-c.console.log'),output,{flag:'wx'});const data=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;const result={exit:code,halt,peakPrivateBytes:peak,report:fs.existsSync(report)?sha(report):null,checks:data?.checks??0,failures:data?.failures??null,success:data?.success===true,engineSha256:sha(engine),sourceSha256:sha(path.join(root,'systems/native_render/model_template.gd'))};fs.writeFileSync(path.join(out,'semantics-c.receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));if(code!==0||halt||!data?.success)process.exitCode=1;});
