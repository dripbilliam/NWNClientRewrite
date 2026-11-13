'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/gamma-prewarm-a');
const manifest=JSON.parse(fs.readFileSync(path.join(stage,'manifest.json'),'utf8'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.equal(sha(manifest.engine.file),manifest.engine.sha256);
for(const [relative,digest] of Object.entries(manifest.sourceHashes))assert.equal(sha(path.join(manifest.project,relative)),digest);
const out=path.join(stage,'runs');assert(!fs.existsSync(out),'Preserve prior fixture results');fs.mkdirSync(out,{recursive:true});
const runs=[];
for(const mode of ['off','on']){
  const folder=path.join(out,mode),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
  const report=path.join(folder,'report.json'),png=path.join(folder,'pixels.png'),log=path.join(folder,'engine.log');
  const args=['--path',manifest.project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/nwn71/gamma_prewarm_pixels.gd','--','--report='+report,'--png='+png];
  const run=spawnSync(manifest.engine.file,args,{cwd:manifest.project,encoding:'utf8',windowsHide:true,timeout:45000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:mode==='on'?'1':'0'}});
  fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
  const value={mode,exit:run.status,signal:run.signal,error:run.error?.message??'',report:fs.existsSync(report)?{file:report,sha256:sha(report),value:JSON.parse(fs.readFileSync(report,'utf8'))}:null,png:fs.existsSync(png)?{file:png,sha256:sha(png),bytes:fs.statSync(png).size}:null};
  runs.push(value);
  if(run.status!==0||!value.report?.value.success||!value.png)break;
}
const result={schema:'nwn71-gamma-prewarm-gpu-v1',manifestSha256:sha(path.join(stage,'manifest.json')),runs,
  samePixels:runs.length===2&&runs[0].png?.sha256===runs[1].png?.sha256,
  scope:'Small authored GPU correctness; no FPS or original-area performance acceptance.'};
result.success=runs.length===2&&runs.every(r=>r.exit===0&&r.report?.value.success)&&result.samePixels;
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:result.success,runs:runs.map(r=>({mode:r.mode,exit:r.exit,error:r.error,failures:r.report?.value.failures,png:r.png?.sha256,prewarm:r.report?.value.snapshot.prewarm}))}));
if(!result.success)process.exitCode=1;
