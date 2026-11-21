'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/cpu-midpoint-a'),project=path.join(stage,'fixture'),out=path.join(stage,'fixture-runs');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const before={gamma:'a0d92018181d096fb79d68cbfb851fc6ad8c3eaab2f9416b5aac9f6588ca3e3a',post:'0495dc4364e242ab9cdf6889988e14501de1d358e077b903adc941f6835913d2'};
assert.equal(sha(path.join(stage,'before/native_gamma_effect.gd')),before.gamma);
assert.equal(sha(path.join(stage,'before/native_postprocess.gd')),before.post);
const relativeGamma='systems/native_render/native_gamma_effect.gd',relativePost='systems/native_render/native_postprocess.gd';
const pins={gamma:sha(path.join(root,relativeGamma)),post:sha(path.join(root,relativePost))};
assert.equal(sha(path.join(project,relativeGamma)),pins.gamma);assert.equal(sha(path.join(project,relativePost)),pins.post);
const engine=path.join(root,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha=sha(engine);
assert(!fs.existsSync(out),'Preserve previous fixture');fs.mkdirSync(out,{recursive:true});
const runs=[];
for(const mode of ['off','on']){
 const folder=path.join(out,mode),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
 const report=path.join(folder,'report.json'),png=path.join(folder,'pixels.png'),log=path.join(folder,'engine.log');
 const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/nwn71/gamma_prewarm_pixels.gd','--','--report='+report,'--png='+png];
 const run=spawnSync(engine,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:45000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:'0',NWN71_CPU_MIDPOINT:mode==='on'?'1':'0'}});
 fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
 runs.push({mode,exit:run.status,signal:run.signal,error:run.error?.message??'',report:fs.existsSync(report)?{file:report,sha256:sha(report),value:JSON.parse(fs.readFileSync(report,'utf8'))}:null,png:fs.existsSync(png)?{file:png,sha256:sha(png)}:null});
 if(run.status!==0||!runs.at(-1).report?.value.success||!runs.at(-1).png)break;
}
const result={issue:'NWN-71',scope:'Small Forward+ Vulkan gamma and tonal output; no FPS timing',sourcePins:pins,beforePins:before,engineSha,runs,samePixels:runs.length===2&&runs[0].png?.sha256===runs[1].png?.sha256};
result.success=runs.length===2&&runs.every(run=>run.exit===0&&run.report?.value.success)&&result.samePixels;
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:result.success,samePixels:result.samePixels,runs:runs.map(run=>({mode:run.mode,exit:run.exit,error:run.error,failures:run.report?.value.failures,png:run.png?.sha256,snapshot:run.report?.value.snapshot}))}));
if(!result.success)process.exitCode=1;
