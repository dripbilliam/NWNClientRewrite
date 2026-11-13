'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/cpu-midpoint-a'),project=path.join(stage,'fixture'),out=path.join(stage,'fixture-repeat-b');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const pins={gamma:'8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468',post:'539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b'};
assert.equal(sha(path.join(project,'systems/native_render/native_gamma_effect.gd')),pins.gamma);
assert.equal(sha(path.join(project,'systems/native_render/native_postprocess.gd')),pins.post);
const engine=path.join(root,'.tools/Godot_v4.7.2-stable_win64.exe');
assert(!fs.existsSync(out),'Preserve previous repeat');fs.mkdirSync(out,{recursive:true});
const runs=[];
for(const [index,mode] of ['off','on','on','off','off','on'].entries()){
 const name=String.fromCharCode(97+index)+'-'+mode,folder=path.join(out,name),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
 const report=path.join(folder,'report.json'),png=path.join(folder,'pixels.png'),log=path.join(folder,'engine.log');
 const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/nwn71/gamma_prewarm_pixels.gd','--','--report='+report,'--png='+png];
 const run=spawnSync(engine,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:45000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:'0',NWN71_CPU_MIDPOINT:mode==='on'?'1':'0'}});
 fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
 const value={name,mode,exit:run.status,error:run.error?.message??'',report:fs.existsSync(report)?{sha256:sha(report),value:JSON.parse(fs.readFileSync(report,'utf8'))}:null,png:fs.existsSync(png)?sha(png):null};runs.push(value);
 console.log(JSON.stringify({name,exit:value.exit,passed:value.report?.value.success,png:value.png,failures:value.report?.value.failures}));
}
const result={issue:'NWN-71',scope:'Small GPU repeat and shutdown stability; no FPS comparison',pins,engineSha:sha(engine),runs};
result.success=runs.length===6&&runs.every(run=>run.exit===0&&run.report?.value.success&&run.png===runs[0].png);
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:result.success,exits:runs.map(run=>run.exit),pixelAgreement:runs.every(run=>run.png===runs[0].png)}));
if(!result.success)process.exitCode=1;
